#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Console enseignant d'Architecture Boréale : lance les scripts du poste par un menu.

.DESCRIPTION
    À lancer sur le poste physique, de préférence par Console-AB.cmd (qui ouvre le menu
    en administrateur). Le poste est reconnu par son nom (AB-SRV-01, AB-PC-01 à AB-PC-04);
    la racine du dépôt est le dossier du script (ex. C:\CFRN-LAB(prof)), quel que soit
    son nom. Chaque action lance le script du dépôt dans un processus séparé, exactement
    comme à la main : tools\Set-ABPoste.ps1, puis AB\<poste>\Setup, Panne, Retrait, Verifier.

    La lettre de l'équipe (A à E) est demandée une fois puis mémorisée pour la session
    (option V pour la changer). Si une panne est déjà installée, sa lettre est reprise.

    Sans -Action : menu interactif. Avec -Action : exécute une seule action, sans
    confirmation, et sort avec son code (0 = réussi). Sert aux tests en VM.

.PARAMETER Action
    Installer, Setup, Panne, Retrait, VerifierPropre, VerifierPanne, VerifierR3 (PC-02)
    ou ToutVerifier.
.PARAMETER Variante
    Lettre de l'équipe, pour -Action Panne ou VerifierPanne.
.PARAMETER SansR5
    PC-01 seulement, avec -Action Panne : n'installe pas R5 (optionnelle).

.EXAMPLE
    .\Menu-AB.ps1
    .\Menu-AB.ps1 -Action ToutVerifier
    .\Menu-AB.ps1 -Action Panne -Variante C
#>
[CmdletBinding()]
param(
    [ValidateSet('Installer', 'Setup', 'Panne', 'Retrait', 'VerifierPropre', 'VerifierPanne', 'VerifierR3', 'ToutVerifier')]
    [string]$Action,
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante,
    [switch]$SansR5
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Import-Module (Join-Path $Root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $Root 'AB\AB-Lab.psm1') -Force

$Postes = [ordered]@{
    'SRV-01' = @{ Compte = 'ab-tech'; Requetes = 'R1 (serveur), R6-B' }
    'PC-01'  = @{ Compte = 'ncote'; Requetes = 'R5, R6' }
    'PC-02'  = @{ Compte = 'lpgauthier'; Requetes = 'R3, R4' }
    'PC-03'  = @{ Compte = 'efortin'; Requetes = 'R1 (poste)' }
    'PC-04'  = @{ Compte = 'jbouchard'; Requetes = 'R2 (physique)' }
}
$script:Interactif = -not $Action
# Noms distincts des paramètres : $script:Variante serait la variable du paramètre,
# avec son ValidateSet (y mettre '' ou $null lève une erreur).
$script:Lettre = $Variante
$script:OmettreR5 = [bool]$SansR5
$script:DerniereJson = $null

# --- Affichage et saisie -------------------------------------------------------

function Write-ABLigne([string]$Texte) {
    # Sortie d'un script enfant : on remet les couleurs de Write-LabStep/OK/Warn
    if ($Texte -match '^\[OK\]') { Write-Host $Texte -ForegroundColor Green }
    elseif ($Texte -match '^\[ATTENTION\]') { Write-Host $Texte -ForegroundColor Yellow }
    elseif ($Texte -match '^=== ') { Write-Host $Texte -ForegroundColor Cyan }
    else { Write-Host $Texte }
}

function Get-ABLargeur {
    try { return [Math]::Max(60, [Console]::WindowWidth - 1) } catch { return 100 }
}

function Read-ABOui([string]$Question, [bool]$Defaut = $false) {
    if (-not $script:Interactif) { return $true }
    $choix = '(o/N)'; if ($Defaut) { $choix = '(O/n)' }
    while ($true) {
        $r = (Read-Host "$Question $choix").Trim().ToLower()
        if (-not $r) { return $Defaut }
        if ($r -in 'o', 'oui') { return $true }
        if ($r -in 'n', 'non') { return $false }
    }
}

function Read-ABVariante {
    while ($true) {
        $r = (Read-Host 'Lettre de l''équipe (A à E, Entrée pour annuler)').Trim().ToUpper()
        if (-not $r) { return $null }
        if ($r -in 'A', 'B', 'C', 'D', 'E') { return $r }
        Write-LabWarn 'Une seule lettre, de A à E.'
    }
}

function Get-ABVarianteEquipe {
    <# Retourne la lettre mémorisée; la demande (et la mémorise) la première fois. #>
    if ($script:Lettre) { return $script:Lettre }
    if (-not $script:Interactif) { throw 'Préciser -Variante.' }
    $script:Lettre = Read-ABVariante
    return $script:Lettre
}

function Get-ABEtat {
    <# État installé du poste, lu dans l'état enregistré par le script Panne. #>
    $st = Get-LabState -Scenario $Poste
    if ($Poste -eq 'PC-04') { return [pscustomobject]@{ Panne = $false; Variante = $null; Texte = 'aucune panne logicielle (R2 se prépare à la main)'; Couleur = 'Gray'; Etat = $null } }
    if (-not $st) { return [pscustomobject]@{ Panne = $false; Variante = $null; Texte = 'PROPRE (aucune panne installée)'; Couleur = 'Green'; Etat = $null } }
    $texte = "PANNE installée (variante $($st.Variante)"
    try { $texte += ', le ' + ([datetime]$st.Date).ToString('yyyy-MM-dd à HH:mm') } catch { $null = $_ }
    if ($Poste -eq 'PC-01') { if ($st.R5) { $texte += ', avec R5' } else { $texte += ', sans R5' } }
    return [pscustomobject]@{ Panne = $true; Variante = $st.Variante; Texte = "$texte)"; Couleur = 'Yellow'; Etat = $st }
}

function Get-ABR2 ([string]$Lettre) {
    <# Ligne de la variante R2 dans GUIDE-ENSEIGNANT.md (section 4), pour ne pas la recopier ici. #>
    $guide = Join-Path $Root 'GUIDE-ENSEIGNANT.md'
    if (-not (Test-Path -LiteralPath $guide)) { return $null }
    $section = $false
    foreach ($l in Get-Content -LiteralPath $guide -Encoding UTF8) {
        if ($l -match '^## ') { $section = ($l -match 'R2') }
        if ($section -and $l -match "^\|\s*$Lettre\s*\|") {
            $col = @($l.Trim('|').Split('|') | ForEach-Object { ($_ -replace '\*\*', '').Trim() })
            if ($col.Count -ge 4) { return [pscustomobject]@{ Manipulation = $col[1]; Symptome = $col[2]; Remise = $col[3] } }
        }
    }
    return $null
}

# --- Exécution des scripts du dépôt --------------------------------------------

function Invoke-ABScript {
    <#
    Lance un script du dépôt (powershell.exe -File, processus séparé) et affiche sa sortie
    au fil de l'eau. La ligne JSON d'un Verifier est retenue dans $script:DerniereJson.
    Retourne le code de sortie.
    #>
    param([Parameter(Mandatory)][string]$Chemin, [string[]]$Arguments = @())
    $script:DerniereJson = $null
    $path = Join-Path $Root $Chemin
    if (-not (Test-Path -LiteralPath $path)) { Write-LabWarn "Script introuvable : $path"; return 1 }
    Write-Host ("> {0} {1}" -f $Chemin, ($Arguments -join ' ')) -ForegroundColor DarkGray
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @Arguments | ForEach-Object {
        $l = [string]$_
        if ($l -like '{"machine"*') { $script:DerniereJson = $l } else { Write-ABLigne $l }
    }
    return $LASTEXITCODE
}

function Show-ABVerification {
    <# Présente la ligne JSON d'un Verifier : un contrôle par ligne, puis le verdict. #>
    param([int]$Code)
    if (-not $script:DerniereJson) { Write-LabWarn "Le Verifier n'a pas donné de résultat (code $Code). Voir le journal."; return $null }
    $r = $script:DerniereJson | ConvertFrom-Json
    $attendus = @(); if ($r.echecsAttendus) { $attendus = @($r.echecsAttendus) }
    $largeur = Get-ABLargeur
    Write-Host ''
    Write-Host ("  Contrôles (attendu : {0})" -f $r.attendu) -ForegroundColor Cyan
    foreach ($c in @($r.controles)) {
        $prevu = ($r.attendu -eq 'Panne' -and ($attendus.Count -eq 0 -or $attendus -contains $c.nom))
        if ($c.ok -and -not ($prevu -and $attendus.Count -gt 0)) { $tag = 'OK'; $couleur = 'Green'; $note = '' }
        elseif (-not $c.ok -and $prevu) { $tag = 'PANNE'; $couleur = 'Yellow'; $note = '' }
        elseif ($c.ok) { $tag = 'ÉCHEC'; $couleur = 'Red'; $note = 'panne attendue mais absente : ' }
        else { $tag = 'ÉCHEC'; $couleur = 'Red'; $note = '' }
        $detail = $note + [string]$c.detail
        $debut = '  [{0,-5}] {1,-20} ' -f $tag, $c.nom
        if ($debut.Length + $detail.Length -gt $largeur) { $detail = $detail.Substring(0, [Math]::Max(0, $largeur - $debut.Length - 3)) + '...' }
        Write-Host $debut -ForegroundColor $couleur -NoNewline
        Write-Host $detail
    }
    return $r
}

function Get-ABJournal([datetime]$Debut) {
    $dir = Get-LabDataPath -Child 'Logs'
    return Get-ChildItem -LiteralPath $dir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $Debut } | Sort-Object LastWriteTime | Select-Object -Last 1
}

function Invoke-ABVerifier {
    param([ValidateSet('Propre', 'Panne')][string]$Attendu, [string]$Lettre, [switch]$R3)
    $a = @('-Attendu', $Attendu)
    if ($Lettre) { $a += @('-Variante', $Lettre) }
    if ($R3) { $a += '-R3' }
    $code = Invoke-ABScript -Chemin "AB\$Poste\Verifier-$Poste.ps1" -Arguments $a
    $r = Show-ABVerification -Code $code
    Write-Host ''
    if ($r -and $r.ok -and $code -eq 0) { Write-Host "  RÉSULTAT : CONFORME (attendu : $Attendu)" -ForegroundColor Green }
    else { Write-Host "  RÉSULTAT : NON CONFORME (attendu : $Attendu)" -ForegroundColor Red }
    if ($code -ne 0) { return 1 }
    return 0
}

# --- Actions -------------------------------------------------------------------

function Invoke-ABInstaller {
    if ($Poste -ne 'SRV-01') {
        $inst = Join-Path $Root 'tools\installeurs'
        if (-not (Get-ChildItem -LiteralPath $inst -File -ErrorAction SilentlyContinue)) {
            Write-LabWarn "Aucun installeur dans $inst (lancer tools\Get-ABInstallers.ps1 sur un poste avec Internet)."
            return 1
        }
    }
    $msg = 'Installer les logiciels et verrouiller la version de Windows (plusieurs minutes)?'
    if ($Poste -eq 'SRV-01') { $msg = 'Verrouiller la version de Windows du serveur?' }
    if (-not (Read-ABOui $msg)) { return $null }
    $a = @('-Poste', $Poste)
    if ($Poste -ne 'SRV-01') { $a += @('-Methode', 'Local') }
    return (Invoke-ABScript -Chemin 'tools\Set-ABPoste.ps1' -Arguments $a)
}

function Invoke-ABSetup {
    $qui = $Postes[$Poste].Compte
    $msg = "Setup de AB-$Poste : $qui doit être DÉCONNECTÉ (son profil est recréé). Continuer?"
    if ($Poste -eq 'SRV-01') { $msg = 'Setup du serveur (comptes, groupes, partages, données, IP fixe). Continuer?' }
    if (-not (Read-ABOui $msg)) { return $null }
    $code = Invoke-ABScript -Chemin "AB\$Poste\Setup-$Poste.ps1"
    if ($script:DerniereJson) { $null = Show-ABVerification -Code $code }
    return $code
}

function Show-ABR2 ([string]$Lettre, [switch]$Remise) {
    $r2 = Get-ABR2 $Lettre
    Write-Host ''
    Write-Host "  R2 variante $Lettre : panne PHYSIQUE, poste hors tension et débranché." -ForegroundColor Yellow
    if (-not $r2) { Write-LabWarn 'Variante introuvable dans GUIDE-ENSEIGNANT.md (section 4).'; return 1 }
    if ($Remise) { Write-Host "  Remise en état : $($r2.Remise)" }
    else {
        Write-Host "  Manipulation    : $($r2.Manipulation)"
        Write-Host "  Symptôme        : $($r2.Symptome)"
    }
    Write-Host '  Détails : GUIDE-ENSEIGNANT.md, section 4.' -ForegroundColor DarkGray
    return 0
}

function Invoke-ABPanne {
    $lettre = Get-ABVarianteEquipe
    if (-not $lettre) { return $null }
    if ($Poste -eq 'PC-04') { return (Show-ABR2 $lettre) }
    $a = @('-Variante', $lettre)
    if ($Poste -eq 'PC-01') {
        $avecR5 = -not $script:OmettreR5
        if ($script:Interactif) { $avecR5 = Read-ABOui 'Inclure R5 (lecteur S:, requête optionnelle)?' $true }
        if (-not $avecR5) { $a += '-SansR5' }
    }
    if (-not (Read-ABOui "Installer la panne variante $lettre sur AB-$Poste?")) { return $null }
    return (Invoke-ABScript -Chemin "AB\$Poste\Panne-$Poste.ps1" -Arguments $a)
}

function Invoke-ABRetrait {
    if ($Poste -eq 'PC-04') {
        $lettre = Get-ABVarianteEquipe
        if (-not $lettre) { return $null }
        return (Show-ABR2 $lettre -Remise)
    }
    $etat = Get-ABEtat
    if (-not $etat.Panne) { Write-LabOK 'Aucune panne installée : rien à retirer.'; return 0 }
    if (-not (Read-ABOui "Retirer la panne (variante $($etat.Variante)) de AB-$Poste?")) { return $null }
    return (Invoke-ABScript -Chemin "AB\$Poste\Retrait-$Poste.ps1")
}

function Invoke-ABToutVerifier {
    <# Vérifie l'état réellement installé et le compare à la lettre de l'équipe. #>
    $etat = Get-ABEtat
    Write-Host ''
    Write-Host "  TOUT VÉRIFIER — AB-$Poste" -ForegroundColor Cyan
    Write-Host '  État installé  : ' -NoNewline; Write-Host $etat.Texte -ForegroundColor $etat.Couleur
    $equipe = '(pas choisie)'; if ($script:Lettre) { $equipe = $script:Lettre }
    Write-Host "  Variante équipe : $equipe"
    $remarques = @()
    if ($Poste -eq 'PC-04') {
        Write-Host '  R2 est physique : aucun contrôle logiciel ne la voit (contrôle visuel, section 4 du guide).' -ForegroundColor DarkGray
        $code = Invoke-ABVerifier -Attendu Propre
    } elseif ($etat.Panne) {
        if ($script:Lettre -and $script:Lettre -ne $etat.Variante) {
            $remarques += "La panne installée est la variante $($etat.Variante), pas celle de l'équipe ($($script:Lettre)) : option 4 puis 2 puis 3."
        }
        $code = Invoke-ABVerifier -Attendu Panne -Lettre $etat.Variante
    } else {
        if ($script:Lettre) { $remarques += "La panne de l'équipe ($($script:Lettre)) n'est pas installée : option 3." }
        $code = Invoke-ABVerifier -Attendu Propre
    }
    Write-Host ''
    if ($code -eq 0 -and -not $remarques) {
        if ($etat.Panne) { Write-Host "  => AB-$Poste est prêt pour l'équipe (variante $($etat.Variante))." -ForegroundColor Green }
        else { Write-Host "  => AB-$Poste est propre." -ForegroundColor Green }
    } elseif ($code -ne 0) {
        Write-Host '  => À corriger : voir les lignes ÉCHEC ci-dessus (souvent : Setup à relancer, ou serveur éteint).' -ForegroundColor Red
    }
    foreach ($r in $remarques) { Write-Host "  => $r" -ForegroundColor Yellow }
    if ($remarques) { return 1 }
    return $code
}

function Invoke-ABVerifierR3 {
    $etat = Get-ABEtat
    $attendu = 'Propre'; if ($etat.Panne) { $attendu = 'Panne' }
    $null = Invoke-ABVerifier -Attendu $attendu -Lettre $etat.Variante -R3
    $r = $null; if ($script:DerniereJson) { $r = $script:DerniereJson | ConvertFrom-Json }
    $c = $null; if ($r) { $c = @($r.controles) | Where-Object { $_.nom -eq 'sauvegarde-r3' } }
    Write-Host ''
    if ($c -and $c.ok) { Write-Host '  => Sauvegarde R3 : COMPLÈTE.' -ForegroundColor Green; return 0 }
    Write-Host '  => Sauvegarde R3 : INCOMPLÈTE ou absente (voir sauvegarde-r3 ci-dessus).' -ForegroundColor Red
    return 1
}

function Invoke-ABAction([string]$Nom) {
    switch ($Nom) {
        'Installer' { return (Invoke-ABInstaller) }
        'Setup' { return (Invoke-ABSetup) }
        'Panne' { return (Invoke-ABPanne) }
        'Retrait' { return (Invoke-ABRetrait) }
        'VerifierPropre' { return (Invoke-ABVerifier -Attendu Propre) }
        'VerifierPanne' {
            $lettre = Get-ABVarianteEquipe
            if (-not $lettre) { return $null }
            return (Invoke-ABVerifier -Attendu Panne -Lettre $lettre)
        }
        'VerifierR3' { return (Invoke-ABVerifierR3) }
        'ToutVerifier' { return (Invoke-ABToutVerifier) }
    }
}

# --- Poste courant ---------------------------------------------------------------

function Select-ABPosteARenommer {
    <# Poste pas encore nommé AB-... : propose de le renommer (les scripts l'exigent). #>
    Write-LabWarn "Ce poste s'appelle $env:COMPUTERNAME. Les scripts AB exigent le nom de la machine (AB-PC-03, ...)."
    $noms = @($Postes.Keys)
    for ($i = 0; $i -lt $noms.Count; $i++) { Write-Host ("  {0}. AB-{1}" -f ($i + 1), $noms[$i]) }
    $r = (Read-Host 'Quelle machine est-ce? (numéro, Entrée pour quitter)').Trim()
    if ($r -notmatch '^[1-5]$') { return }
    $nom = 'AB-' + $noms[[int]$r - 1]
    if (-not (Read-ABOui "Renommer ce poste en $nom (redémarrage nécessaire)?")) { return }
    Rename-Computer -NewName $nom -Force
    Write-LabOK "Poste renommé en $nom au prochain démarrage."
    if (Read-ABOui 'Redémarrer maintenant?') { Restart-Computer -Force }
}

$Poste = $null
if ($env:COMPUTERNAME -match '^AB-(SRV-01|PC-0[1-4])$') { $Poste = $Matches[1] }
if (-not $Poste) {
    if (-not $script:Interactif) { Write-LabWarn "Poste non reconnu : $env:COMPUTERNAME (attendu AB-SRV-01 ou AB-PC-01 à 04)."; exit 1 }
    Select-ABPosteARenommer
    exit 1
}

if (-not $script:Interactif) {
    $code = Invoke-ABAction $Action
    if ($null -eq $code) { $code = 1 }
    exit $code
}

# --- Menu interactif -----------------------------------------------------------------

$depart = Get-ABEtat
if ($depart.Variante) { $script:Lettre = $depart.Variante }
$cfg = Get-ABConfig
$employe = $cfg.Employes | Where-Object { $_.Compte -eq $Postes[$Poste].Compte }
$qui = 'Serveur de fichiers (ab-tech)'
if ($employe) { $qui = "$($employe.NomComplet) ($($employe.Compte))" }

function Show-ABMenu {
    $etat = Get-ABEtat
    $x = '?'; if ($script:Lettre) { $x = $script:Lettre }
    $trait = '=' * 70
    Clear-Host
    Write-Host $trait -ForegroundColor DarkCyan
    Write-Host ('  Architecture Boréale — Console enseignant'.PadRight(56) + "AB-$Poste") -ForegroundColor White
    Write-Host "  $qui   ·   Requêtes du poste : $($Postes[$Poste].Requetes)"
    Write-Host "  Dépôt : $Root"
    Write-Host '  État  : ' -NoNewline; Write-Host $etat.Texte -ForegroundColor $etat.Couleur
    Write-Host '  Variante de l''équipe : ' -NoNewline
    if ($script:Lettre) { Write-Host $script:Lettre -ForegroundColor Cyan } else { Write-Host '(pas encore choisie)' -ForegroundColor DarkGray }
    Write-Host $trait -ForegroundColor DarkCyan

    $items = @()
    $installer = 'Logiciels + verrou de version Windows   (Set-ABPoste)'
    $setup = 'Setup : profil, données et apparence'
    if ($Poste -eq 'SRV-01') {
        $installer = 'Verrou de version Windows               (Set-ABPoste)'
        $setup = 'Setup : comptes, partages, données, IP fixe'
    }
    $items += @{ Section = 'INSTALLATION (une seule fois)'; Cle = '1'; Texte = $installer; Action = 'Installer' }
    $items += @{ Section = 'PRÉPARATION D''UNE ÉQUIPE'; Cle = '2'; Texte = $setup; Action = 'Setup' }
    if ($Poste -eq 'PC-04') {
        $items += @{ Section = ''; Cle = '3'; Texte = "Préparer R2 variante $x   (rappel : panne physique)"; Action = 'Panne' }
        $items += @{ Section = ''; Cle = '4'; Texte = "Remettre R2 variante $x en état   (rappel)"; Action = 'Retrait' }
    } else {
        $items += @{ Section = ''; Cle = '3'; Texte = "Installer la panne   (variante $x)"; Action = 'Panne' }
        $items += @{ Section = ''; Cle = '4'; Texte = 'Retirer la panne'; Action = 'Retrait' }
    }
    $items += @{ Section = 'VÉRIFICATION'; Cle = '5'; Texte = 'Tout vérifier   (résumé de l''état du poste)'; Action = 'ToutVerifier' }
    $items += @{ Section = ''; Cle = '6'; Texte = 'Vérifier « Propre »'; Action = 'VerifierPropre' }
    if ($Poste -ne 'PC-04') { $items += @{ Section = ''; Cle = '7'; Texte = "Vérifier « Panne »   (variante $x)"; Action = 'VerifierPanne' } }
    if ($Poste -eq 'PC-02') { $items += @{ Section = ''; Cle = '8'; Texte = 'Vérifier la sauvegarde R3 faite par les élèves'; Action = 'VerifierR3' } }
    $items += @{ Section = 'AUTRES'; Cle = 'V'; Texte = 'Changer la variante de l''équipe'; Action = '#Variante' }
    $items += @{ Section = ''; Cle = 'R'; Texte = 'Ouvrir le README du poste (mots de passe)'; Action = '#Readme' }
    $items += @{ Section = ''; Cle = 'J'; Texte = 'Ouvrir le dernier journal'; Action = '#Journal' }
    if (Test-Path -LiteralPath (Join-Path $Root 'Menu-Particuliers.ps1')) { $items += @{ Section = ''; Cle = 'P'; Texte = 'Ouvrir la console des pannes Particuliers'; Action = '#Particuliers' } }
    $items += @{ Section = ''; Cle = '0'; Texte = 'Quitter'; Action = '#Quitter' }

    foreach ($i in $items) {
        if ($i.Section) { Write-Host ''; Write-Host "  $($i.Section)" -ForegroundColor Cyan }
        Write-Host ("    {0}. {1}" -f $i.Cle, $i.Texte)
    }
    Write-Host ('-' * 70) -ForegroundColor DarkCyan
    return $items
}

while ($true) {
    $items = Show-ABMenu
    $choix = (Read-Host '  Choix').Trim().ToUpper()
    $item = $items | Where-Object { $_.Cle -eq $choix } | Select-Object -First 1
    if (-not $item) { continue }
    # if plutôt que switch : dans un switch, « continue » ne relance pas la boucle while
    if ($item.Action -eq '#Quitter') { exit 0 }
    if ($item.Action -eq '#Variante') {
        $v = Read-ABVariante
        if ($v) { $script:Lettre = $v }
        continue
    }
    if ($item.Action -eq '#Readme') {
        $readme = Join-Path $Root "AB\$Poste\README-Installation.txt"
        if (Test-Path -LiteralPath $readme) { Start-Process -FilePath notepad.exe -ArgumentList "`"$readme`"" }
        continue
    }
    if ($item.Action -eq '#Journal') {
        $log = Get-ABJournal ([datetime]::MinValue)
        if ($log) { Start-Process -FilePath notepad.exe -ArgumentList "`"$($log.FullName)`"" }
        else { Write-LabWarn 'Aucun journal pour le moment.'; $null = Read-Host '  Entrée pour revenir au menu' }
        continue
    }
    if ($item.Action -eq '#Particuliers') {
        Start-Process -FilePath powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $Root 'Menu-Particuliers.ps1') + '"')
        continue
    }
    Write-Host ''
    $debut = Get-Date
    try {
        $code = Invoke-ABAction $item.Action
    } catch {
        Write-LabWarn $_.Exception.Message
        $code = 1
    }
    Write-Host ''
    if ($null -eq $code) { Write-Host '  Annulé.' -ForegroundColor DarkGray }
    elseif ($code -eq 0) { Write-Host '  Terminé : réussi (code 0).' -ForegroundColor Green }
    else {
        Write-Host "  Terminé : ÉCHEC (code $code)." -ForegroundColor Red
        $log = Get-ABJournal $debut
        if ($log -and (Read-ABOui "Ouvrir le journal ($($log.Name))?")) { Start-Process -FilePath notepad.exe -ArgumentList "`"$($log.FullName)`"" }
    }
    $null = Read-Host '  Entrée pour revenir au menu'
}
