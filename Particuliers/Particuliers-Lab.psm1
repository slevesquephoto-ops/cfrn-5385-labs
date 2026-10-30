#requires -version 5.1
<#
Particuliers-Lab.psm1 - Moteur des pannes spontanées (clients particuliers).
Client absent : compte, profil et données créés, puis la panne. Client présent : seulement
la panne (profil conservé). Chaque panne est un fichier Pannes\<Id>.ps1 qui retourne
@{ Sauvegarder; Installer; Retirer; Tester } (blocs qui reçoivent le contexte du client).
S'appuie sur common\Lab-Common.psm1 et AB\AB-Lab.psm1 (à importer avant, comme AB-Lab).
#>

Set-StrictMode -Version 2.0

$script:PartRoot = $PSScriptRoot
$script:PartConfig = $null
$script:PosteState = 'PART-Poste'

# ---------------------------------------------------------------------------
# Configuration et catalogue
# ---------------------------------------------------------------------------
function Get-PartConfig {
    if (-not $script:PartConfig) {
        $script:PartConfig = Import-PowerShellDataFile -Path (Join-Path $script:PartRoot 'Particuliers-Config.psd1')
    }
    return $script:PartConfig
}

function Get-PartClient {
    param([Parameter(Mandatory)][string]$Compte)
    $c = (Get-PartConfig).Clients | Where-Object { $_.Compte -eq $Compte } | Select-Object -First 1
    if (-not $c) { throw "Client inconnu : $Compte. Clients : $(((Get-PartConfig).Clients | ForEach-Object { $_.Compte }) -join ', ')." }
    return $c
}

function Get-PartPanne {
    <# Entrée du catalogue + blocs du fichier Pannes\<Id>.ps1 (propriété Blocs). #>
    param([Parameter(Mandatory)][string]$Id)
    $p = (Get-PartConfig).Pannes | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $p) { throw "Panne inconnue : $Id. Pannes : $(((Get-PartConfig).Pannes | ForEach-Object { $_.Id }) -join ', ')." }
    $file = Join-Path $script:PartRoot "Pannes\$Id.ps1"
    if (-not (Test-Path -LiteralPath $file)) { throw "Fichier de panne absent : $file" }
    $blocs = & $file
    foreach ($k in 'Sauvegarder', 'Installer', 'Retirer', 'Tester') {
        if (-not ($blocs.ContainsKey($k) -and $blocs[$k] -is [scriptblock])) { throw "$file : bloc $k absent." }
    }
    $p = $p.Clone()
    $p.Blocs = $blocs
    return $p
}

# ---------------------------------------------------------------------------
# États (un par panne installée : PART-<compte>-<Id>)
# ---------------------------------------------------------------------------
function Get-PartStateName { param([string]$Compte, [string]$Id) return "PART-$Compte-$Id" }

function Get-PartInstalled {
    <# Pannes installées : objets { Compte; Id } (tous les clients, ou un seul). #>
    param([string]$Compte)
    $dir = Get-LabDataPath -Child 'State'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter 'PART-*.json' -File -ErrorAction SilentlyContinue) {
        if ($f.BaseName -eq $script:PosteState) { continue }
        foreach ($c in (Get-PartConfig).Clients) {
            $prefix = "PART-$($c.Compte)-"
            if ($f.BaseName.StartsWith($prefix) -and (-not $Compte -or $Compte -eq $c.Compte)) {
                [pscustomobject]@{ Compte = $c.Compte; Id = $f.BaseName.Substring($prefix.Length) }
            }
        }
    }
}

function Test-PartABPanne {
    <# Vrai si une panne AB est installée sur ce poste (état SRV-01, PC-01 à PC-04). #>
    foreach ($m in 'SRV-01', 'PC-01', 'PC-02', 'PC-03', 'PC-04') { if (Get-LabState -Scenario $m) { return $true } }
    return $false
}

# ---------------------------------------------------------------------------
# Réseau : utilisé par les pannes RES-* (cartes de la connexion Internet, chemin d'Edge)
# ---------------------------------------------------------------------------
function Get-PartNetAdapter {
    <#
    Cartes qui portent la connexion Internet (passerelle IPv4 par défaut), sinon toutes les
    cartes matérielles « Up ». Objets { Index; Nom; Guid }. En VM, une seule carte.
    #>
    $idx = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway } | ForEach-Object { $_.InterfaceIndex })
    $cartes = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface })
    if (-not $idx) { $idx = @($cartes | Where-Object { $_.Status -eq 'Up' } | ForEach-Object { $_.ifIndex }) }
    return @($cartes | Where-Object { $idx -contains $_.ifIndex } |
            ForEach-Object { [pscustomobject]@{ Index = $_.ifIndex; Nom = $_.Name; Guid = $_.InterfaceGuid } })
}

function Get-PartEdgePath {
    <# Chemin de msedge.exe, ou $null si Edge est absent. #>
    foreach ($r in ${env:ProgramFiles(x86)}, $env:ProgramFiles) {
        if (-not $r) { continue }
        $p = Join-Path $r 'Microsoft\Edge\Application\msedge.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Registre de la ruche du client : chemins RELATIFS (la racine change selon que la
# ruche est montée par le script ou déjà chargée par une session ouverte)
# ---------------------------------------------------------------------------
function Get-PartUserValue {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Name)
    $s = Get-LabRegistrySnapshot -Path (Join-Path $Root $Key) -Name $Name
    $value = $s.Value
    if ($s.Type -eq 'Binary' -and $null -ne $value) { $value = [Convert]::ToBase64String([byte[]]$value) }
    return [pscustomobject]@{ Key = $Key; Name = $Name; Exists = $s.Exists; Value = $value; Type = $s.Type }
}

function Restore-PartUserValue {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)]$Snapshot)
    $value = $Snapshot.Value
    if ($Snapshot.Type -eq 'Binary' -and $null -ne $value) { $value = [Convert]::FromBase64String([string]$value) }
    if ($Snapshot.Type -eq 'MultiString' -and $null -ne $value) { $value = [string[]]@($value) }
    Restore-LabRegistrySnapshot -Snapshot ([pscustomobject]@{
            Path = (Join-Path $Root $Snapshot.Key); Name = $Snapshot.Name; Exists = $Snapshot.Exists; Value = $value; Type = $Snapshot.Type
        })
}

# ---------------------------------------------------------------------------
# Poste : comptes sans mot de passe désactivés tant qu'un client est placé
# ---------------------------------------------------------------------------
function Test-PartBlankPassword {
    <#
    Vrai si le compte local a un mot de passe vide. LogonUser interactif avec "" :
    réussite, ou erreur 1327 (restriction des mots de passe vides) = mot de passe vide;
    1326 = mot de passe non vide. Compte comme UNE tentative ratée pour un compte
    protégé : appelé seulement à la mise en place du poste, jamais par le Verifier.
    #>
    param([Parameter(Mandatory)][string]$UserName)
    $token = [IntPtr]::Zero
    $ok = [ABNative.Logon]::LogonUser($UserName, $env:COMPUTERNAME, '', 2, 0, [ref]$token)
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($ok) { [void][ABNative.Logon]::CloseHandle($token); return $true }
    return ($err -eq 1327)
}

function Get-PartFirstLogonPolicy {
    @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'EnableFirstLogonAnimation'; Value = 0; Type = 'DWord' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'; Name = 'DisablePrivacyExperience'; Value = 1; Type = 'DWord' }
    )
}

function Get-PartAdministrateur {
    <# Nom court du compte administrateur « enseignant » à préserver (jamais désactivé : c'est
       l'accès de secours quand une panne punitive bloque la session du client). Si la config
       nomme un compte, on le prend ; sinon (valeur vide ou 'auto'), on prend le compte qui
       exécute ce script en élévation — l'enseignant lui-même, quel que soit le poste. #>
    $name = (Get-PartConfig).Administrateur
    if ($name -and $name -ne 'auto') { return $name }
    $cur = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    return ($cur -split '\\')[-1]
}

function Assert-PartAdministrateur {
    <# L'enseignant doit garder un accès administrateur. Compte local (nommé ou auto-détecté) :
       on vérifie qu'il est activé et administrateur. Compte non local (domaine, compte
       Microsoft) : on s'assure que la session courante est bien élevée en administrateur —
       c'est l'accès de secours de l'enseignant. #>
    $name = Get-PartAdministrateur
    $u = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
    if ($u) {
        if (-not $u.Enabled) { throw "Compte $name désactivé : le réactiver (administrateur) avant de placer un client." }
        $admins = (Get-ABSid -Name 'Administrateurs').Value
        if ((Get-ABGroupMemberSid -GroupSid $admins) -notcontains $u.SID.Value) { throw "$name n'est pas administrateur : impossible de placer un client sans risque." }
        return
    }
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Aucun compte administrateur de secours : lancer depuis une session administrateur de l'enseignant, ou nommer un compte dans Particuliers-Config.psd1 (clé Administrateur)."
    }
}

function Initialize-PartPoste {
    <#
    Première mise en place sur ce poste (état PART-Poste) : comptes activés sans mot de
    passe désactivés (sauf l'administrateur et les clients), première ouverture de session
    sans animation ni questions. Tout est enregistré pour Restore-PartPoste.
    #>
    if (Get-LabState -Scenario $script:PosteState) { return }
    Assert-PartAdministrateur
    $cfg = Get-PartConfig
    $exclus = @(Get-PartAdministrateur) + @($cfg.Clients | ForEach-Object { $_.Compte })
    $vides = @(Get-LocalUser | Where-Object { $_.Enabled -and $exclus -notcontains $_.Name } |
            Where-Object { Test-PartBlankPassword -UserName $_.Name } | ForEach-Object { $_.Name })
    $snaps = @(Get-PartFirstLogonPolicy | ForEach-Object { Get-LabRegistrySnapshot -Path $_.Path -Name $_.Name })
    $state = [ordered]@{ Date = (Get-Date).ToString('s'); ComptesDesactives = $vides; Strategies = $snaps }
    if (-not (Save-LabState -Scenario $script:PosteState -Data $state)) { throw 'État du poste déjà présent.' }
    foreach ($n in $vides) { Disable-LocalUser -Name $n; Write-LabOK "Compte sans mot de passe désactivé : $n" }
    foreach ($p in Get-PartFirstLogonPolicy) { Set-LabRegistryValue -Path $p.Path -Name $p.Name -Value $p.Value -Type $p.Type }
    Write-LabOK 'Poste prêt pour les clients (première ouverture de session sans animation).'
}

function Restore-PartPoste {
    <# Quand plus aucun client n'est sur le poste : comptes réactivés, stratégies restaurées. #>
    $st = Get-LabState -Scenario $script:PosteState
    if (-not $st) { return }
    $restants = @((Get-PartConfig).Clients | Where-Object { Get-LocalUser -Name $_.Compte -ErrorAction SilentlyContinue })
    if ($restants) { return }
    foreach ($n in @($st.ComptesDesactives)) {
        if (Get-LocalUser -Name $n -ErrorAction SilentlyContinue) { Enable-LocalUser -Name $n; Write-LabOK "Compte réactivé : $n" }
    }
    foreach ($s in @($st.Strategies)) { Restore-LabRegistrySnapshot -Snapshot $s }
    Remove-LabState -Scenario $script:PosteState
    Write-LabOK 'Aucun client restant : poste remis dans son état d''origine.'
}

function Test-PartPoste {
    $st = Get-LabState -Scenario $script:PosteState
    if (-not $st) { return (New-LabCheck -Name 'poste' -Passed $false -Detail 'poste jamais préparé (aucun client placé)') }
    $p = @()
    $admin = Get-PartAdministrateur
    $u = Get-LocalUser -Name $admin -ErrorAction SilentlyContinue
    if ($u -and -not $u.Enabled) { $p += "$admin désactivé" }
    foreach ($n in @($st.ComptesDesactives)) {
        $x = Get-LocalUser -Name $n -ErrorAction SilentlyContinue
        if ($x -and $x.Enabled) { $p += "$n (sans mot de passe) réactivé" }
    }
    $d = "comptes sans mot de passe désactivés : $(if (@($st.ComptesDesactives).Count) { @($st.ComptesDesactives) -join ', ' } else { 'aucun' })"
    if ($p) { $d = $p -join '; ' }
    return (New-LabCheck -Name 'poste' -Passed (-not $p) -Detail $d)
}

# ---------------------------------------------------------------------------
# Client : compte, profil, données (créés seulement s'ils manquent)
# ---------------------------------------------------------------------------
function Get-PartManifest {
    param([Parameter(Mandatory)][string]$Compte)
    $data = Join-Path $script:PartRoot "data\$Compte"
    return [pscustomobject]@{ Racine = $data; Fichier = (Join-Path $data "manifeste-$Compte.csv") }
}

function Get-PartProfilePath {
    param([Parameter(Mandatory)][string]$Compte)
    $u = Get-LocalUser -Name $Compte -ErrorAction SilentlyContinue
    if (-not $u) { return $null }
    $p = Get-CimInstance Win32_UserProfile -Filter "SID='$($u.SID.Value)'"
    if ($p) { return $p.LocalPath }
    return $null
}

function Set-PartClientAccount {
    <# Crée le compte du client (absent seulement) : groupes Utilisateurs (+ Administrateurs). #>
    param([Parameter(Mandatory)]$Client)
    if (Get-LocalUser -Name $Client.Compte -ErrorAction SilentlyContinue) { return $false }
    $secure = ConvertTo-SecureString $Client.MotDePasse -AsPlainText -Force
    New-LocalUser -Name $Client.Compte -Password $secure -FullName $Client.NomComplet -Description $Client.Description `
        -PasswordNeverExpires -AccountNeverExpires | Out-Null
    $sid = (Get-LocalUser -Name $Client.Compte).SID.Value
    $groupes = @('Utilisateurs'); if ($Client.Admin) { $groupes += 'Administrateurs' }
    foreach ($g in $groupes) {
        $gsid = (Get-ABSid -Name $g).Value
        if ((Get-ABGroupMemberSid -GroupSid $gsid) -notcontains $sid) { Add-LocalGroupMember -SID $gsid -Member $sid }
    }
    return $true
}

function Copy-PartMissingData {
    <# Copie les fichiers du manifeste ABSENTS du profil (jamais d'écrasement). Retourne le nombre copié. #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$ProfilePath)
    $m = Get-PartManifest -Compte $Compte
    if (-not (Test-Path -LiteralPath $m.Fichier)) { return 0 }
    $owner = "$env:COMPUTERNAME\$Compte"
    $n = 0
    foreach ($r in @(Import-Csv -LiteralPath $m.Fichier -Delimiter ';' -Encoding UTF8)) {
        $dst = Resolve-ABUserTarget -ProfilePath $ProfilePath -Target $r.TargetRelative
        if (Test-Path -LiteralPath $dst) { continue }
        $dir = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath (Join-Path $m.Racine $r.SourceRelative) -Destination $dst
        Set-LabItemTime -Path $dst -Created ([datetime]$r.CreationTime) -Modified ([datetime]$r.LastWriteTime)
        & icacls.exe $dst /setowner $owner /C /Q | Out-Null
        $n++
    }
    return $n
}

function Get-PartWallpaper {
    <# Fond d'écran du client : le chemin préféré s'il existe, sinon une image Windows intégrée
       choisie de façon déterministe par compte (différente d'un client à l'autre), sinon $null. #>
    param([string]$Prefere, [Parameter(Mandatory)][string]$Compte)
    if ($Prefere -and (Test-Path -LiteralPath $Prefere)) { return $Prefere }
    $cand = @(Get-ChildItem -Path 'C:\Windows\Web\Wallpaper' -Recurse -Include '*.jpg', '*.png' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName | Sort-Object)
    if (-not $cand) {
        $def = 'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
        if (Test-Path -LiteralPath $def) { return $def }
        return $null
    }
    $h = 0; foreach ($c in $Compte.ToCharArray()) { $h = (($h * 31) + [int]$c) -band 0x7fffffff }
    return $cand[$h % $cand.Count]
}

function Write-PartEdgeFavorites {
    <# Pré-remplit les favoris Edge (fichier Bookmarks du profil Default). N'écrase jamais un
       fichier existant (favoris déjà posés par l'élève). JSON écrit à la main pour garantir un
       tableau « children » même avec un seul favori, en UTF-8 sans BOM (lu par Edge). #>
    param([Parameter(Mandatory)][string]$ProfilePath, [object[]]$Favoris)
    if (-not $Favoris) { return $false }
    $dir = Join-Path $ProfilePath 'AppData\Local\Microsoft\Edge\User Data\Default'
    $file = Join-Path $dir 'Bookmarks'
    if (Test-Path -LiteralPath $file) { return $false }
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $id = 2
    $items = foreach ($f in $Favoris) {
        $nm = ($f.Nom -replace '\\', '\\\\' -replace '"', '\"')
        $u = ($f.Url -replace '\\', '\\\\' -replace '"', '\"')
        '{"date_added":"0","id":"' + $id + '","name":"' + $nm + '","type":"url","url":"' + $u + '"}'
        $id++
    }
    $barre = $items -join ','
    $json = '{"checksum":"","roots":{' +
        '"bookmark_bar":{"children":[' + $barre + '],"date_added":"0","date_modified":"0","id":"1","name":"Barre de favoris","type":"folder"},' +
        '"other":{"children":[],"date_added":"0","date_modified":"0","id":"100","name":"Autres favoris","type":"folder"},' +
        '"synced":{"children":[],"date_added":"0","date_modified":"0","id":"101","name":"Favoris mobiles","type":"folder"}},"version":1}'
    [IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

function Set-PartSimulatedApp {
    <# « Logiciel installé » propre au client : entrée Applications (HKCU Uninstall, dans la ruche),
       dossier d'installation et raccourci menu Démarrer, tous DANS le profil -> retirés avec lui.
       Inoffensif (aucun exécutable actif, juste de l'apparence). #>
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$ProfilePath, [Parameter(Mandatory)]$App)
    $key = Join-Path $Root "Software\Microsoft\Windows\CurrentVersion\Uninstall\$($App.Id)"
    $instDir = Join-Path $ProfilePath "AppData\Local\Programs\$($App.Id)"
    Set-LabRegistryValue -Path $key -Name 'DisplayName' -Value $App.Nom -Type String
    Set-LabRegistryValue -Path $key -Name 'DisplayVersion' -Value ([string]$App.Version) -Type String
    Set-LabRegistryValue -Path $key -Name 'Publisher' -Value $App.Editeur -Type String
    Set-LabRegistryValue -Path $key -Name 'InstallLocation' -Value $instDir -Type String
    Set-LabRegistryValue -Path $key -Name 'NoModify' -Value 1 -Type DWord
    Set-LabRegistryValue -Path $key -Name 'NoRepair' -Value 1 -Type DWord
    if (-not (Test-Path -LiteralPath $instDir)) { New-Item -ItemType Directory -Path $instDir -Force | Out-Null }
    Set-Content -LiteralPath (Join-Path $instDir 'lisezmoi.txt') -Value "$($App.Nom) $($App.Version) - $($App.Editeur)" -Encoding UTF8
    $lnk = Join-Path $ProfilePath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\$($App.Nom).lnk"
    New-ABShortcut -Path $lnk -Target (Join-Path $instDir 'lisezmoi.txt')
}

function Set-PartClientProfileExtras {
    <#
    Rend le profil crédible (au-delà des données) : fond d'écran, icônes du Bureau, favoris Edge,
    « logiciels installés » (mixte : raccourcis vers le réel présent + applis simulées). Idempotent.
    Tout vit dans le profil (ou sa ruche) : rien à nettoyer à part le retrait du client.
    #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$ProfilePath, [Parameter(Mandatory)]$Client)
    $wp = Get-PartWallpaper -Prefere ([string]$Client['FondEcran']) -Compte $Compte
    $apps = @(); if ($Client.Contains('Logiciels')) { $apps = @($Client.Logiciels) }
    Invoke-ABUserHive -Compte $Compte -ScriptBlock {
        param($Root)
        if ($wp) { Set-ABUserShellSetting -Root $Root -Wallpaper $wp }
        foreach ($a in $apps) { if ($a) { Set-PartSimulatedApp -Root $Root -ProfilePath $ProfilePath -App $a } }
    }
    # Raccourcis du Bureau (hors ruche). Cible : 'EDGE', 'LIBREOFFICE', ou chemin avec %PROFIL%.
    $raccourcis = @(); if ($Client.Contains('Raccourcis')) { $raccourcis = @($Client.Raccourcis) }
    foreach ($r in $raccourcis) {
        $cible = [string]$r.Cible
        if ($cible -eq 'EDGE') { $cible = Get-PartEdgePath }
        elseif ($cible -eq 'LIBREOFFICE') { $cible = Find-ABProgram -Exe 'soffice.exe' }
        else { $cible = $cible.Replace('%PROFIL%', $ProfilePath) }
        if (-not $cible) { continue }   # logiciel réel absent : on saute ce raccourci
        New-ABShortcut -Path (Join-Path $ProfilePath "Desktop\$($r.Nom).lnk") -Target $cible -Arguments ([string]$r['Arguments']) -Icon ([string]$r['Icone'])
    }
    $owner = "$env:COMPUTERNAME\$Compte"
    foreach ($glob in 'Desktop\*.lnk', 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\*.lnk') {
        $p = Join-Path $ProfilePath $glob
        if (Get-ChildItem -LiteralPath (Split-Path -Parent $p) -Filter (Split-Path -Leaf $p) -ErrorAction SilentlyContinue) {
            & icacls.exe $p /setowner $owner /C /Q | Out-Null
        }
    }
    # Favoris Edge (fichier Bookmarks du profil).
    $fav = @(); if ($Client.Contains('Favoris')) { $fav = @($Client.Favoris) }
    $null = Write-PartEdgeFavorites -ProfilePath $ProfilePath -Favoris $fav
}

function Initialize-PartClient {
    <# Place le client sur le poste s'il est absent; sinon ne touche à rien. Retourne le chemin du profil. #>
    param([Parameter(Mandatory)][string]$Compte)
    $client = Get-PartClient -Compte $Compte
    Clear-PartPendingProfile
    if (Get-PartPendingProfile | Where-Object { $_.Compte -eq $Compte }) {
        throw "L'ancien profil de $Compte est encore retenu par Windows : redémarrer le poste avant de replacer ce client."
    }
    Initialize-PartPoste
    if (Set-PartClientAccount -Client $client) { Write-LabOK "Compte créé : $Compte ($($client.NomComplet))" }
    $path = Get-PartProfilePath -Compte $Compte
    if ($path) {
        Write-LabOK "Client déjà présent : profil conservé ($path)."
    } else {
        $path = New-ABUserProfile -Compte $Compte
        Write-LabOK "Profil créé : $path"
    }
    $n = Copy-PartMissingData -Compte $Compte -ProfilePath $path
    if ($n) { Write-LabOK "$n fichiers de données copiés." }
    Set-PartClientProfileExtras -Compte $Compte -ProfilePath $path -Client $client
    Write-LabOK 'Profil enrichi : fond d''écran, icônes, favoris Edge, logiciels.'
    return $path
}

function Test-PartClient {
    param([Parameter(Mandatory)][string]$Compte)
    $p = @()
    $u = Get-LocalUser -Name $Compte -ErrorAction SilentlyContinue
    $path = $null
    if (-not $u) { $p += 'compte absent' }
    else {
        $path = Get-PartProfilePath -Compte $Compte
        if (-not $path) { $p += 'profil absent' }
        elseif (-not (Test-Path -LiteralPath (Join-Path $path 'NTUSER.DAT'))) { $p += 'NTUSER.DAT absent' }
    }
    $m = Get-PartManifest -Compte $Compte
    $nb = 0
    if ($path -and (Test-Path -LiteralPath $m.Fichier)) {
        $rows = @(Import-Csv -LiteralPath $m.Fichier -Delimiter ';' -Encoding UTF8)
        $nb = $rows.Count
        $manq = @($rows | Where-Object { -not (Test-Path -LiteralPath (Resolve-ABUserTarget -ProfilePath $path -Target $_.TargetRelative)) })
        if ($manq) { $p += "$($manq.Count) fichier(s) de données manquant(s)" }
    }
    $d = "compte et profil présents ($path), $nb fichiers de données"
    if ($p) { $d = $p -join '; ' }
    return (New-LabCheck -Name 'client' -Passed (-not $p) -Detail $d)
}

# ---------------------------------------------------------------------------
# Contexte passé aux blocs d'une panne
# ---------------------------------------------------------------------------
function Invoke-PartWithContext {
    <#
    Monte la ruche du client (ou utilise celle de sa session), exécute $ScriptBlock avec le contexte.
    Tolérant : si la ruche n'est pas montable (profil masqué/renommé par CPT-TEMP, par ex.),
    le contexte est fourni quand même avec Root = $null (aucun accès HKCU). Les pannes de portée
    Profil doivent alors échouer proprement; les pannes qui n'utilisent pas HKCU (CPT-TEMP) tournent.
    #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $client = Get-PartClient -Compte $Compte
    $hive = $null
    try { $hive = Mount-LabUserHive -UserName $Compte }
    catch { Write-LabWarn "Ruche de $Compte non montable ($($_.Exception.Message)). Contexte sans HKCU (Root = `$null)." }
    try {
        $root = $null; $session = $false
        if ($hive) { $root = $hive.Root; $session = (-not $hive.Loaded) }
        $ctx = [pscustomobject]@{
            Client = $client; Compte = $Compte; Sid = (Get-ABUserSid -Compte $Compte)
            Profil = (Get-PartProfilePath -Compte $Compte); Root = $root; SessionOuverte = $session
        }
        & $ScriptBlock $ctx
    } finally {
        if ($hive) { Dismount-LabUserHive -Hive $hive }
    }
}

# ---------------------------------------------------------------------------
# Installer, retirer, vérifier
# ---------------------------------------------------------------------------
function Install-PartPanne {
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Id)
    $null = Get-PartClient -Compte $Compte
    $panne = Get-PartPanne -Id $Id
    $scenario = Get-PartStateName -Compte $Compte -Id $Id
    if (Get-LabState -Scenario $scenario) { Write-LabOK "$Id déjà installée pour $Compte : rien à refaire."; return }

    $installees = @(Get-PartInstalled)
    $miennes = @($installees | Where-Object { $_.Compte -eq $Compte } | ForEach-Object { $_.Id })
    foreach ($autre in $miennes) {
        $def = (Get-PartConfig).Pannes | Where-Object { $_.Id -eq $autre }
        if ($panne.Incompatibles -contains $autre -or ($def -and $def.Incompatibles -contains $Id)) { throw "$Id est incompatible avec $autre (déjà installée)." }
    }
    if ($panne.Portee -eq 'Machine') {
        $ailleurs = $installees | Where-Object { $_.Id -eq $Id -and $_.Compte -ne $Compte } | Select-Object -First 1
        if ($ailleurs) { throw "$Id touche tout le poste et est déjà installée pour $($ailleurs.Compte)." }
        if (Test-PartABPanne) { throw "Une panne AB est installée sur ce poste : $Id (portée Machine) refusée." }
    }

    Write-LabStep "Client $Compte"
    $null = Initialize-PartClient -Compte $Compte

    Write-LabStep "Panne $Id : $($panne.Titre)"
    $blocs = $panne.Blocs
    Invoke-PartWithContext -Compte $Compte -ScriptBlock {
        param($ctx)
        $etat = & $blocs.Sauvegarder $ctx
        $data = [ordered]@{ Compte = $Compte; Id = $Id; Date = (Get-Date).ToString('s'); Etat = $etat }
        if (-not (Save-LabState -Scenario $scenario -Data $data)) { throw 'État déjà présent : installation interrompue.' }
        $etat = (Get-LabState -Scenario $scenario).Etat   # relu : même forme qu'au retrait
        try {
            & $blocs.Installer $ctx $etat
            $t = & $blocs.Tester $ctx
            if ($t.Ok) { throw "panne non constatée après installation ($($t.Detail))." }
        } catch {
            Write-LabWarn "Échec de l'installation de $Id : $($_.Exception.Message) Retour à l'état d'origine."
            & $blocs.Retirer $ctx $etat
            Remove-LabState -Scenario $scenario
            throw
        }
        Write-LabOK "$Id installée ($($t.Detail))."
        if ($panne.Portee -eq 'Profil' -and $ctx.SessionOuverte) { Write-LabWarn "$Compte a une session ouverte : la panne apparaîtra à sa prochaine ouverture de session." }
    }
}

function Remove-PartPanne {
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Id)
    $scenario = Get-PartStateName -Compte $Compte -Id $Id
    $st = Get-LabState -Scenario $scenario
    if (-not $st) { Write-LabOK "$Id n'est pas installée pour $Compte : rien à retirer."; return }
    $panne = Get-PartPanne -Id $Id
    $blocs = $panne.Blocs
    Write-LabStep "Retrait de $Id ($Compte)"
    Invoke-PartWithContext -Compte $Compte -ScriptBlock {
        param($ctx)
        & $blocs.Retirer $ctx $st.Etat
        $t = & $blocs.Tester $ctx
        if (-not $t.Ok) { throw "$Id encore présente après le retrait ($($t.Detail))." }
        Remove-LabState -Scenario $scenario
        Write-LabOK "$Id retirée ($($t.Detail))."
    }
}

function Remove-PartClient {
    <#
    Retire toutes les pannes du client, puis son compte et son profil; poste restauré s'il
    n'en reste aucun. Profil retenu par Windows (ruche chargée sans session : vu en VM) :
    le compte est supprimé quand même et le profil est mis en attente (Clear-PartPendingProfile).
    #>
    param([Parameter(Mandatory)][string]$Compte)
    $null = Get-PartClient -Compte $Compte
    foreach ($i in @(Get-PartInstalled -Compte $Compte)) { Remove-PartPanne -Compte $Compte -Id $i.Id }
    Write-LabStep "Suppression du client $Compte"
    $u = Get-LocalUser -Name $Compte -ErrorAction SilentlyContinue
    if ($u) {
        $path = Get-PartProfilePath -Compte $Compte
        try {
            Remove-ABUserProfile -Compte $Compte
        } catch {
            Add-PartPendingProfile -Compte $Compte -Sid $u.SID.Value -Chemin $path
            Write-LabWarn "Windows retient encore le profil de $Compte : il sera supprimé au prochain lancement après un redémarrage du poste."
        }
        Remove-LocalUser -Name $Compte
        Write-LabOK "Compte $Compte supprimé."
    } else { Write-LabOK "$Compte absent du poste." }
    Restore-PartPoste
}

# ---------------------------------------------------------------------------
# Profils retenus par Windows au moment de la suppression d'un client
# ---------------------------------------------------------------------------
$script:PendingState = 'PART-ProfilsEnAttente'

function Add-PartPendingProfile {
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Sid, [string]$Chemin)
    $list = @()
    $st = Get-LabState -Scenario $script:PendingState
    if ($st) { $list = @($st.Profils) }
    $list += [pscustomobject]@{ Compte = $Compte; Sid = $Sid; Chemin = $Chemin }
    $null = Save-LabState -Scenario $script:PendingState -Data @{ Profils = $list } -Overwrite
}

function Get-PartPendingProfile {
    $st = Get-LabState -Scenario $script:PendingState
    if ($st) { return @($st.Profils) }
    return @()
}

function Clear-PartPendingProfile {
    <# Supprime les profils en attente que Windows a enfin libérés (après un redémarrage). #>
    $list = @(Get-PartPendingProfile)
    if (-not $list) { return }
    $reste = @()
    foreach ($e in $list) {
        $p = Get-CimInstance Win32_UserProfile -Filter "SID='$($e.Sid)'"
        if ($p -and $p.Loaded) { $reste += $e; continue }
        if ($p) { Remove-CimInstance -InputObject $p }
        if ($e.Chemin -and (Test-Path -LiteralPath $e.Chemin)) { Remove-Item -LiteralPath $e.Chemin -Recurse -Force }
        Write-LabOK "Ancien profil de $($e.Compte) supprimé ($($e.Chemin))."
    }
    if ($reste) { $null = Save-LabState -Scenario $script:PendingState -Data @{ Profils = $reste } -Overwrite }
    else { Remove-LabState -Scenario $script:PendingState }
}

function Get-PartVerification {
    <#
    Contrôles du client : poste, client, puis chaque panne du catalogue (ok = propre).
    Retourne { Checks; Attendues } : Attendues = pannes installées qui doivent être en échec
    (celles du client, et les pannes de portée Machine installées pour un autre client).
    #>
    param([Parameter(Mandatory)][string]$Compte)
    $checks = @(Test-PartPoste)
    $c = Test-PartClient -Compte $Compte
    $checks += $c
    $installees = @(Get-PartInstalled)
    $attendues = @()
    foreach ($i in $installees) {
        if ($i.Compte -eq $Compte) { $attendues += $i.Id; continue }
        $def = (Get-PartConfig).Pannes | Where-Object { $_.Id -eq $i.Id }
        if ($def -and $def.Portee -eq 'Machine') { $attendues += $i.Id }
    }
    if ($c.ok -or (Get-PartProfilePath -Compte $Compte)) {
        $pannes = @((Get-PartConfig).Pannes | ForEach-Object { Get-PartPanne -Id $_.Id })
        $checks += Invoke-PartWithContext -Compte $Compte -ScriptBlock {
            param($ctx)
            foreach ($p in $pannes) {
                try {
                    $t = & $p.Blocs.Tester $ctx
                    New-LabCheck -Name $p.Id -Passed ([bool]$t.Ok) -Detail ([string]$t.Detail)
                } catch {
                    # Tester non exécutable (ex. ruche non montable quand CPT-TEMP est actif) : non propre.
                    New-LabCheck -Name $p.Id -Passed $false -Detail "non vérifiable : $($_.Exception.Message)"
                }
            }
        }
    }
    return [pscustomobject]@{ Checks = $checks; Attendues = @($attendues | Sort-Object -Unique) }
}

# ---------------------------------------------------------------------------
# EICAR : simulation de virus inoffensive (fichier de test antivirus standard).
# Rien de nuisible ne s'exécute : on écrit un fichier de test que tout antivirus
# reconnaît. La « réapparition » est une tâche planifiée (comme SYS-DEMARRAGE).
# ---------------------------------------------------------------------------
$script:EicarTask = 'Optimisation du stockage'
$script:EicarGen = Join-Path $env:ProgramData 'Microsoft\DeviceSync\sync-store.ps1'
$script:EicarDrop = Join-Path $env:ProgramData 'MediaCache\update.bin'
$script:EicarIntervalMinutes = 1   # cadence de réapparition (l'enseignant peut ajuster)

function Test-PartConsoleUserIs {
    <# Vrai si l'utilisateur de la session console active est $Compte (nom court, insensible à la
       casse). Sert à ne jamais déposer l'EICAR sous un autre profil que le client (ex. ab-tech).
       Renvoie faux si personne n'est au console (écran de verrouillage, session réseau). #>
    param([Parameter(Mandatory)][string]$Compte)
    try { $u = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName } catch { return $false }
    if (-not $u) { return $false }
    return ((($u -split '\\')[-1]) -ieq $Compte)
}

function Get-PartEicarByte {
    <#
    Octets du fichier de test EICAR, assemblés par morceaux : aucun fichier source (ni le
    script générateur déposé) ne contient la chaîne complète, et rien n'est reconstitué
    comme un script (AMSI n'a rien à signaler). Seul le fichier écrit déclenche l'antivirus.
    #>
    $parts = @('X5O!P%@AP[4\PZX54(P', '^)7CC)7}', '$EICAR', '-STANDARD-ANTIVIRUS-', 'TEST-FILE!$H+H*')
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($p in $parts) { $bytes.AddRange([Text.Encoding]::ASCII.GetBytes($p)) }
    return $bytes.ToArray()
}

function Get-PartEicarDropFolder { return (Split-Path -Parent $script:EicarDrop) }

function Write-PartEicarFile {
    <# Dépôt initial. Si $Compte est fourni, on ne dépose QUE si le client est l'utilisateur
       console actif : l'enseignant qui installe depuis ab-tech ne déclenche donc aucune alerte. #>
    param([string]$Compte)
    if ($Compte -and -not (Test-PartConsoleUserIs -Compte $Compte)) { return }
    $dir = Get-PartEicarDropFolder
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllBytes($script:EicarDrop, (Get-PartEicarByte))
}

function Install-PartEicarPersistence {
    <#
    Dépose le générateur (script caché) et une tâche planifiée (SYSTEM). Le générateur est écrit
    comme un here-string (chaîne unique avec vrais retours de ligne : aucun piège de tableau).

    Portée client : le générateur ne fait RIEN si l'utilisateur de la session console active n'est
    pas $Compte. Ab-tech (ou l'écran de verrouillage) ne voit donc jamais l'EICAR, même si la tâche
    SYSTEM tourne en fond.

    Escalade douce : un compteur discret (index.dat) compte les cycles passés DANS la session du
    client ; après 5 cycles, le générateur dépose plusieurs copies (plafonné à 4) pour densifier les
    alertes si l'élève traîne. Tout reste dans le même dossier caché (retrait = suppression du dossier).
    #>
    param([Parameter(Mandatory)][string]$Compte)
    $codes = (Get-PartEicarByte | ForEach-Object { [int]$_ }) -join ','
    $dropDir = Get-PartEicarDropFolder
    # Here-string : $Compte / $dropDir / $codes sont injectés à l'installation ; tout le reste
    # (préfixé d'un accent grave) reste littéral et s'exécute au moment de la tâche.
    $gen = @"
`$client = '$Compte'
try { `$u = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName } catch { `$u = `$null }
if (-not `$u) { return }
if (((`$u -split '\\')[-1]) -ine `$client) { return }
`$d = '$dropDir'
if (-not (Test-Path -LiteralPath `$d)) { New-Item -ItemType Directory -Path `$d -Force | Out-Null }
`$cf = Join-Path `$d 'index.dat'
`$n = 0
if (Test-Path -LiteralPath `$cf) { `$raw = (Get-Content -LiteralPath `$cf -ErrorAction SilentlyContinue | Select-Object -First 1); [void][int]::TryParse(`$raw, [ref]`$n) }
`$n++
Set-Content -LiteralPath `$cf -Value `$n -Encoding ASCII
`$copies = 1
if (`$n -gt 5) { `$copies = [Math]::Min(4, `$n - 4) }
`$bytes = [byte[]]@($codes)
for (`$i = 0; `$i -lt `$copies; `$i++) {
    if (`$i -eq 0) { `$f = Join-Path `$d 'update.bin' } else { `$f = Join-Path `$d ('update' + `$i + '.bin') }
    [IO.File]::WriteAllBytes(`$f, `$bytes)
}
"@
    $dir = Split-Path -Parent $script:EicarGen
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($script:EicarGen, $gen, (New-Object System.Text.ASCIIEncoding))
    (Get-Item -LiteralPath $script:EicarGen -Force).Attributes = 'Hidden'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($script:EicarGen)`""
    # Un seul déclencheur : répétition SYSTEM toutes les N minutes. Le ciblage « client uniquement »
    # est assuré par la GARDE dans l'action (pas par un déclencheur -User, qui exigerait que le compte
    # soit résoluble à l'installation). -RepetitionDuration est obligatoire, sinon « Prochaine
    # exécution » reste vide et la répétition ne démarre pas.
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $script:EicarIntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365)
    $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $set = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $script:EicarTask -Action $action -Trigger $trigger -Principal $pr -Settings $set -Force | Out-Null
}

function Remove-PartEicarPersistence {
    <# Retire la tâche, le générateur et le dossier de dépôt (nettoyage exact). #>
    Unregister-ScheduledTask -TaskName $script:EicarTask -Confirm:$false -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $script:EicarGen) { Remove-Item -LiteralPath $script:EicarGen -Force }
    $gdir = Split-Path -Parent $script:EicarGen
    if ((Test-Path -LiteralPath $gdir) -and -not @(Get-ChildItem -LiteralPath $gdir -Force)) { Remove-Item -LiteralPath $gdir -Force }
    # Suppression récursive du dossier de dépôt : il nous appartient entièrement et peut contenir
    # plusieurs copies (update*.bin) plus le compteur index.dat.
    $ddir = Get-PartEicarDropFolder
    if (Test-Path -LiteralPath $ddir) { Remove-Item -LiteralPath $ddir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Test-PartEicarPersistence {
    <# { Tache; Generateur } : vrai si le mécanisme de réapparition est en place. #>
    return [pscustomobject]@{
        Tache      = [bool](Get-ScheduledTask -TaskName $script:EicarTask -ErrorAction SilentlyContinue)
        Generateur = (Test-Path -LiteralPath $script:EicarGen)
    }
}

function Test-PartDefenderExclusion {
    <# Vrai si le dossier de dépôt est exclu de Microsoft Defender. #>
    try { return (@((Get-MpPreference -ErrorAction Stop).ExclusionPath) -contains (Get-PartEicarDropFolder)) }
    catch { return $false }
}

function Add-PartDefenderExclusion {
    try { Add-MpPreference -ExclusionPath (Get-PartEicarDropFolder) -ErrorAction Stop }
    catch { throw "Impossible d'ajouter l'exclusion Defender (protection contre les falsifications active?). La désactiver sur le poste, puis réessayer. Détail : $($_.Exception.Message)" }
}

function Remove-PartDefenderExclusion {
    Remove-MpPreference -ExclusionPath (Get-PartEicarDropFolder) -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function *
