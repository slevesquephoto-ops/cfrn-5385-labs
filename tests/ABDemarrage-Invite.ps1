#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exécuté DANS AB-PC-02-T, session de lpgauthier ouverte : ce que R4 a réellement lancé.

.DESCRIPTION
    Ligne JSON : processus wscript.exe, powershell.exe et Windows Terminal de l'employé
    (ligne de commande, mémoire de travail et mémoire privée en Mo), valeurs Run de sa ruche (type et texte) et mémoire libre.
    Prouve que la couche logicielle de R4 s'exécute à l'ouverture de session (pas seulement
    qu'elle est présente).
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Compte)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
$r4 = (Get-ABConfig).Pannes.R4

$noms = @('wscript.exe', 'powershell.exe', 'WindowsTerminal.exe')
$procs = @()
foreach ($p in Get-CimInstance Win32_Process) {
    if ($noms -notcontains $p.Name) { continue }
    $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner
    if ($owner.User -ne $Compte) { continue }
    $procs += [ordered]@{
        nom       = $p.Name
        memoireMo = [int]($p.WorkingSetSize / 1MB)
        priveeMo  = [int]($p.PrivatePageCount / 1MB)
        commande  = $p.CommandLine
    }
}

$sid = Get-ABUserSid -Compte $Compte
$run = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Run"
$valeurs = @()
if (Test-Path -LiteralPath $run) {
    $key = Get-Item -LiteralPath $run
    foreach ($nom in $r4.Demarrage.Keys) {
        if ($key.GetValueNames() -contains $nom) {
            $valeurs += [ordered]@{ nom = $nom; type = [string]$key.GetValueKind($nom); texte = $key.GetValue($nom, $null, 'DoNotExpandEnvironmentNames') }
        }
    }
}
$os = Get-CimInstance Win32_OperatingSystem
[ordered]@{
    sessionChargee = (Test-Path -LiteralPath "Registry::HKEY_USERS\$sid")
    processus      = $procs
    run            = $valeurs
    memoireLibreMo = [int]($os.FreePhysicalMemory / 1KB)
    memoireTotaleMo = [int]($os.TotalVisibleMemorySize / 1KB)
} | ConvertTo-Json -Depth 4 -Compress
