#requires -version 5.1
<#
Lab-Common.psm1 - Fonctions communes aux mises en situation du DEP 5385.
Cible : Windows PowerShell 5.1 (postes élèves Windows 11 Pro).
Importer avec : Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
#>

Set-StrictMode -Version 2.0

# ---------------------------------------------------------------------------
# Messages
# ---------------------------------------------------------------------------
function Write-LabStep { param([Parameter(Mandatory)][string]$Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-LabOK   { param([Parameter(Mandatory)][string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-LabWarn { param([Parameter(Mandatory)][string]$Message) Write-Host "[ATTENTION] $Message" -ForegroundColor Yellow }

Set-Alias -Name Step -Value Write-LabStep
Set-Alias -Name OK   -Value Write-LabOK
Set-Alias -Name Warn -Value Write-LabWarn

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
function Test-LabAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-LabAdmin {
    if (-not (Test-LabAdmin)) { throw "Ce script doit être lancé dans un PowerShell administrateur." }
}

function Assert-LabComputer {
    <# Arrête le script si le poste n'est pas celui prévu, sauf avec -Force. #>
    param(
        [Parameter(Mandatory)][string]$Expected,
        [switch]$Force
    )
    if ($env:COMPUTERNAME -ne $Expected -and -not $Force) {
        throw "Ce script est prévu pour $Expected. Poste actuel : $env:COMPUTERNAME. Utiliser -Force si c'est volontaire."
    }
}

# ---------------------------------------------------------------------------
# Dossier de travail caché (journaux + état des pannes)
# ---------------------------------------------------------------------------
$script:LabDataRoot = 'C:\ProgramData\CFRN-Lab'
if ($env:ProgramData) { $script:LabDataRoot = Join-Path $env:ProgramData 'CFRN-Lab' }

function Get-LabDataPath {
    <# Retourne (et crée au besoin) le dossier caché de travail, ou un sous-dossier. #>
    param([string]$Child)
    if (-not (Test-Path $script:LabDataRoot)) {
        $dir = New-Item -ItemType Directory -Path $script:LabDataRoot -Force
        $dir.Attributes = $dir.Attributes -bor [IO.FileAttributes]::Hidden
    }
    if ($Child) {
        $path = Join-Path $script:LabDataRoot $Child
        if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
        return $path
    }
    return $script:LabDataRoot
}

function Start-LabLog {
    <# Démarre une transcription horodatée dans <data>\Logs. #>
    param([Parameter(Mandatory)][string]$Name)
    $logDir = Get-LabDataPath -Child 'Logs'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $file = Join-Path $logDir "$Name-$stamp.log"
    Start-Transcript -Path $file -Force | Out-Null
    return $file
}

function Stop-LabLog {
    try { Stop-Transcript | Out-Null } catch { Write-Verbose "Aucune transcription active." }
}

# ---------------------------------------------------------------------------
# État des pannes (pour un retrait exact)
# ---------------------------------------------------------------------------
function Get-LabStateFile {
    param([Parameter(Mandatory)][string]$Scenario)
    return (Join-Path (Get-LabDataPath -Child 'State') "$Scenario.json")
}

function Save-LabState {
    <#
    Enregistre un objet (hashtable ou PSCustomObject) pour un scénario.
    Ne remplace pas un état existant sauf avec -Overwrite : on ne veut jamais
    perdre l'état d'origine si la panne est installée deux fois.
    #>
    param(
        [Parameter(Mandatory)][string]$Scenario,
        [Parameter(Mandatory)]$Data,
        [switch]$Overwrite
    )
    $file = Get-LabStateFile -Scenario $Scenario
    if ((Test-Path $file) -and -not $Overwrite) {
        Write-LabWarn "État '$Scenario' déjà présent : conservé (installation répétée?)."
        return $false
    }
    $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $file -Encoding UTF8
    return $true
}

function Get-LabState {
    param([Parameter(Mandatory)][string]$Scenario)
    $file = Get-LabStateFile -Scenario $Scenario
    if (-not (Test-Path $file)) { return $null }
    return (Get-Content -Path $file -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Remove-LabState {
    param([Parameter(Mandatory)][string]$Scenario)
    $file = Get-LabStateFile -Scenario $Scenario
    if (Test-Path $file) { Remove-Item -Path $file -Force }
}

# ---------------------------------------------------------------------------
# Registre
# ---------------------------------------------------------------------------
function Set-LabRegistryValue {
    <#
    Écrit une valeur de registre sans jamais vider une clé existante.
    (New-Item -Force sur une clé existante la recrée vide.)
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()]$Value,
        [ValidateSet('String','ExpandString','DWord','QWord','Binary','MultiString')]
        [string]$Type = 'String'
    )
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Get-LabRegistrySnapshot {
    <#
    Capture l'état d'une valeur (existe? valeur? type?) pour pouvoir la restaurer.
    Le chemin est enregistré tel quel : utiliser HKLM:\... ou le chemin de ruche
    retourné par Mount-LabUserHive.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $snap = [ordered]@{ Path = $Path; Name = $Name; Exists = $false; Value = $null; Type = $null }
    if (Test-Path -LiteralPath $Path) {
        $key = Get-Item -LiteralPath $Path
        if ($key.GetValueNames() -contains $Name) {
            $snap.Exists = $true
            $snap.Value = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
            $snap.Type = $key.GetValueKind($Name).ToString()
        }
    }
    return [pscustomobject]$snap
}

function Restore-LabRegistrySnapshot {
    param([Parameter(Mandatory)]$Snapshot)
    if ($Snapshot.Exists) {
        Set-LabRegistryValue -Path $Snapshot.Path -Name $Snapshot.Name -Value $Snapshot.Value -Type $Snapshot.Type
    } elseif (Test-Path -LiteralPath $Snapshot.Path) {
        Remove-ItemProperty -LiteralPath $Snapshot.Path -Name $Snapshot.Name -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Ruche d'un utilisateur déconnecté
# ---------------------------------------------------------------------------
function Mount-LabUserHive {
    <#
    Donne accès au HKCU d'un utilisateur local. Si l'utilisateur est connecté,
    utilise sa ruche déjà chargée; sinon charge NTUSER.DAT.
    Retourne un objet { Root; Loaded; MountName }. Toujours appeler
    Dismount-LabUserHive dans un bloc finally.
    #>
    param([Parameter(Mandatory)][string]$UserName)
    $user = Get-LocalUser -Name $UserName -ErrorAction Stop
    $sid = $user.SID.Value
    $live = "Registry::HKEY_USERS\$sid"
    if (Test-Path $live) {
        return [pscustomobject]@{ Root = $live; Loaded = $false; MountName = $null }
    }
    $profilePath = (Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$sid'").LocalPath
    if (-not $profilePath) { throw "Aucun profil pour $UserName. Ouvrir une session une première fois." }
    $mount = "LAB_$UserName"
    & reg.exe load "HKU\$mount" (Join-Path $profilePath 'NTUSER.DAT') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Impossible de charger la ruche de $UserName (session ouverte?)." }
    return [pscustomobject]@{ Root = "Registry::HKEY_USERS\$mount"; Loaded = $true; MountName = $mount }
}

function Dismount-LabUserHive {
    param([Parameter(Mandatory)]$Hive)
    if (-not $Hive.Loaded) { return }
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    for ($i = 0; $i -lt 5; $i++) {
        & reg.exe unload "HKU\$($Hive.MountName)" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Milliseconds 500
    }
    Write-LabWarn "La ruche $($Hive.MountName) n'a pas pu être déchargée. Redémarrer avant la connexion de l'utilisateur."
}

function Register-LabRunOnce {
    <#
    Exécute un script au prochain logon de l'utilisateur, fenêtre cachée.
    Sert aux actions qui n'existent que dans la session : cmdkey, net use, fond d'écran.
    #>
    param(
        [Parameter(Mandatory)]$Hive,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ScriptPath
    )
    $runOnce = Join-Path $Hive.Root 'Software\Microsoft\Windows\CurrentVersion\RunOnce'
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Set-LabRegistryValue -Path $runOnce -Name $Name -Value $cmd -Type String
}

# ---------------------------------------------------------------------------
# Fichiers
# ---------------------------------------------------------------------------
function Set-LabItemTime {
    <# Applique des dates réalistes à un fichier ou un dossier. #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][datetime]$Created,
        [Parameter(Mandatory)][datetime]$Modified
    )
    $item = Get-Item -LiteralPath $Path -Force
    $item.CreationTime = $Created
    $item.LastWriteTime = $Modified
    $item.LastAccessTime = $Modified
}

function Get-LabFileHash {
    <# Hash SHA256 relatif d'un dossier, pour comparer une source et une sauvegarde. #>
    param([Parameter(Mandatory)][string]$Root)
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force | ForEach-Object {
        [pscustomobject]@{
            Relative = $_.FullName.Substring($rootFull.Length + 1)
            Hash     = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
}

# ---------------------------------------------------------------------------
# Résultat de vérification (contrat Verifier-*.ps1)
# ---------------------------------------------------------------------------
function New-LabCheck {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Detail = ''
    )
    return [pscustomobject]@{ nom = $Name; ok = $Passed; detail = $Detail }
}

function Complete-LabVerification {
    <#
    Écrit la ligne JSON du contrat et retourne le code de sortie attendu.
    $Checks : contrôles décrivant l'état PROPRE (ok = l'élément est propre).
    Attendu Propre : tous ok. Attendu Panne : au moins un contrôle non ok.
    Usage : exit (Complete-LabVerification -Machine 'PC-03' -Attendu $Attendu -Checks $checks)
    #>
    param(
        [Parameter(Mandatory)][string]$Machine,
        [Parameter(Mandatory)][ValidateSet('Propre','Panne')][string]$Attendu,
        [Parameter(Mandatory)][object[]]$Checks
    )
    $allClean = -not ($Checks | Where-Object { -not $_.ok })
    if ($Attendu -eq 'Propre') { $ok = [bool]$allClean } else { $ok = -not $allClean }
    $result = [pscustomobject]@{ machine = $Machine; attendu = $Attendu; ok = $ok; controles = $Checks }
    # Écrit directement sur la console pour ne pas polluer la valeur de retour
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 5 -Compress))
    if ($ok) { return 0 } else { return 1 }
}

Export-ModuleMember -Function * -Alias Step, OK, Warn
