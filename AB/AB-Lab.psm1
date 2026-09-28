#requires -version 5.1
<#
AB-Lab.psm1 - Fonctions propres à Architecture Boréale, partagées par les scripts
AB (Setup, Panne, Retrait, Verifier) et par tools\Install-ABSoftware.ps1.
S'appuie sur common\Lab-Common.psm1 (à importer avant).
Import : Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force
#>

Set-StrictMode -Version 2.0

$script:ABConfigPath = Join-Path $PSScriptRoot 'AB-Config.psd1'
$script:ABConfig = $null

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
function Get-ABConfig {
    <# Retourne la configuration AB (AB-Config.psd1), lue une seule fois. #>
    if (-not $script:ABConfig) {
        $script:ABConfig = Import-PowerShellDataFile -Path $script:ABConfigPath
    }
    return $script:ABConfig
}

function Get-ABSoftwareList {
    <# Logiciels actifs prévus pour un poste (PC-01..PC-04). #>
    param([Parameter(Mandatory)][string]$Poste)
    @((Get-ABConfig).Logiciels | Where-Object { $_.Actif -and ($_.Postes -contains $Poste) })
}

# ---------------------------------------------------------------------------
# Logiciels installés (clés Uninstall de HKLM, 64 et 32 bits)
# ---------------------------------------------------------------------------
function Get-ABInstalledProgram {
    <# Liste { DisplayName; DisplayVersion; KeyName; UninstallString } des programmes installés pour la machine. #>
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root) {
            $name = $key.GetValue('DisplayName', $null)
            if (-not $name) { continue }
            [pscustomobject]@{
                DisplayName     = [string]$name
                DisplayVersion  = [string]$key.GetValue('DisplayVersion', '')
                KeyName         = $key.PSChildName
                UninstallString = [string]$key.GetValue('UninstallString', '')
            }
        }
    }
}

function Test-ABSoftware {
    <#
    Cherche un logiciel de la config. Retourne $null s'il est absent, sinon
    { Nom; DisplayName; Version; ProductCode } (ProductCode : GUID si MSI).
    #>
    param([Parameter(Mandatory)]$Logiciel)
    $found = Get-ABInstalledProgram | Where-Object { $_.DisplayName -match $Logiciel.Detection } | Select-Object -First 1
    if (-not $found) { return $null }
    $code = $null
    if ($found.KeyName -match '^\{[0-9A-Fa-f-]{36}\}$') { $code = $found.KeyName }
    [pscustomobject]@{ Nom = $Logiciel.Nom; DisplayName = $found.DisplayName; Version = $found.DisplayVersion; ProductCode = $code }
}

# ---------------------------------------------------------------------------
# Mises à jour des logiciels (coupées pour garder un état stable entre équipes)
# ---------------------------------------------------------------------------
$script:AcrobatPolicyKeys = @(
    'HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown',
    'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
)

function Disable-ABAcrobatUpdate {
    <# Stratégie bUpdater=0, service et tâche de mise à jour d'Adobe désactivés. #>
    foreach ($k in $script:AcrobatPolicyKeys) { Set-LabRegistryValue -Path $k -Name 'bUpdater' -Value 0 -Type DWord }
    $svc = Get-Service -Name 'AdobeARMservice' -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne 'Stopped') { Stop-Service -Name $svc.Name -Force }
        Set-Service -Name $svc.Name -StartupType Disabled
    }
    Get-ScheduledTask -TaskName 'Adobe Acrobat Update Task' -ErrorAction SilentlyContinue |
        Where-Object { $_.State -ne 'Disabled' } | Disable-ScheduledTask | Out-Null
}

function Test-ABAcrobatUpdateDisabled {
    foreach ($k in $script:AcrobatPolicyKeys) {
        $s = Get-LabRegistrySnapshot -Path $k -Name 'bUpdater'
        if (-not $s.Exists -or $s.Value -ne 0) { return $false }
    }
    $svc = Get-Service -Name 'AdobeARMservice' -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -ne 'Disabled') { return $false }
    $task = Get-ScheduledTask -TaskName 'Adobe Acrobat Update Task' -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') { return $false }
    return $true
}

function Disable-ABLibreOfficeUpdate {
    <#
    Retire la fonction MSI de mise à jour de LibreOffice (gm_o_Onlineupdate) du
    produit DÉJÀ installé. Pas à l'installation : REMOVE=... sur une installation
    neuve fait ignorer la sélection par défaut (rien n'est installé, vérifié en VM).
    ISCHECKFORPRODUCTUPDATES=0 seul laisse la fonction installée (vérifié en VM).
    #>
    param([Parameter(Mandatory)][string]$ProductCode, [Parameter(Mandatory)][string]$LogFile)
    if (Test-ABLibreOfficeUpdateDisabled -ProductCode $ProductCode) { return }
    $p = Start-Process -FilePath 'msiexec.exe' -Wait -PassThru -WindowStyle Hidden `
        -ArgumentList "/i $ProductCode REMOVE=gm_o_Onlineupdate /qn /norestart /l*v `"$LogFile`""
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { Write-LabWarn "LibreOffice : retrait de la mise à jour, code $($p.ExitCode)." }
}

function Test-ABLibreOfficeUpdateDisabled {
    <# Vrai si la fonction MSI de vérification des mises à jour (gm_o_Onlineupdate) n'est pas installée. #>
    param([Parameter(Mandatory)][string]$ProductCode)
    $installer = New-Object -ComObject WindowsInstaller.Installer
    try {
        $state = $installer.FeatureState($ProductCode, 'gm_o_Onlineupdate')
    } catch {
        return $true   # fonction inexistante dans ce paquet : rien à vérifier
    }
    # 3 = locale, 4 = par défaut : installée ; 2 = absente ; -1 = inconnue
    return ($state -ne 3 -and $state -ne 4)
}

function ConvertTo-ABPackedGuid {
    <# {GUID} MSI -> forme « compressée » des clés Installer\Products (chaque segment inversé). #>
    param([Parameter(Mandatory)][string]$Guid)
    $g = $Guid.Trim('{}').Replace('-', '')
    $rev = { param($s) -join ($s.ToCharArray()[($s.Length - 1)..0]) }
    $out = (& $rev $g.Substring(0, 8)) + (& $rev $g.Substring(8, 4)) + (& $rev $g.Substring(12, 4))
    for ($i = 16; $i -lt 32; $i += 2) { $out += $g[$i + 1] + $g[$i] }
    return $out.ToUpper()
}

function Get-ABMsiSourceList {
    <# Sources réseau et locales enregistrées pour un produit MSI installé pour la machine. #>
    param([Parameter(Mandatory)][string]$ProductCode)
    $key = "HKLM:\SOFTWARE\Classes\Installer\Products\$(ConvertTo-ABPackedGuid -Guid $ProductCode)\SourceList"
    if (-not (Test-Path -LiteralPath $key)) { return @() }
    $net = Join-Path $key 'Net'
    $sources = @()
    if (Test-Path -LiteralPath $net) {
        $k = Get-Item -LiteralPath $net
        foreach ($n in $k.GetValueNames()) { $sources += [string]$k.GetValue($n, $null, 'DoNotExpandEnvironmentNames') }
    }
    return @($sources | ForEach-Object { $_.TrimEnd('\') })
}

# ---------------------------------------------------------------------------
# Windows Update : version de Windows verrouillée (sécurité toujours active)
# ---------------------------------------------------------------------------
$script:WUPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$script:WUAUKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

function Get-ABWindowsTargetVersion {
    <# Version de Windows verrouillée pour une machine (SRV-01, PC-01..PC-04). #>
    param([Parameter(Mandatory)][string]$Machine)
    $v = (Get-ABConfig).WindowsUpdate.Version[$Machine]
    if (-not $v) { throw "Aucune version Windows prévue pour $Machine dans AB-Config.psd1." }
    return $v
}

function Set-ABWindowsUpdateLock {
    param([Parameter(Mandatory)][string]$Machine)
    $wu = (Get-ABConfig).WindowsUpdate
    Set-LabRegistryValue -Path $script:WUPolicyKey -Name 'TargetReleaseVersion' -Value 1 -Type DWord
    Set-LabRegistryValue -Path $script:WUPolicyKey -Name 'ProductVersion' -Value $wu.ProductVersion -Type String
    Set-LabRegistryValue -Path $script:WUPolicyKey -Name 'TargetReleaseVersionInfo' -Value (Get-ABWindowsTargetVersion -Machine $Machine) -Type String
}

function Test-ABWindowsUpdateLock {
    <# Retourne un contrôle New-LabCheck 'windows-update'. #>
    param([Parameter(Mandatory)][string]$Machine)
    $wu = @{ ProductVersion = (Get-ABConfig).WindowsUpdate.ProductVersion; TargetReleaseVersionInfo = (Get-ABWindowsTargetVersion -Machine $Machine) }
    $problems = @()
    $trv = Get-LabRegistrySnapshot -Path $script:WUPolicyKey -Name 'TargetReleaseVersion'
    $pv = Get-LabRegistrySnapshot -Path $script:WUPolicyKey -Name 'ProductVersion'
    $tri = Get-LabRegistrySnapshot -Path $script:WUPolicyKey -Name 'TargetReleaseVersionInfo'
    if (-not $trv.Exists -or $trv.Value -ne 1) { $problems += 'TargetReleaseVersion absent' }
    if (-not $pv.Exists -or $pv.Value -ne $wu.ProductVersion) { $problems += "ProductVersion différent de '$($wu.ProductVersion)'" }
    if (-not $tri.Exists -or $tri.Value -ne $wu.TargetReleaseVersionInfo) { $problems += "TargetReleaseVersionInfo différent de '$($wu.TargetReleaseVersionInfo)'" }
    # Les mises à jour de sécurité doivent rester actives
    $noAuto = Get-LabRegistrySnapshot -Path $script:WUAUKey -Name 'NoAutoUpdate'
    if ($noAuto.Exists -and $noAuto.Value -eq 1) { $problems += 'NoAutoUpdate=1 (mises à jour de sécurité coupées)' }
    $current = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    $detail = "Windows $current, verrou $($wu.TargetReleaseVersionInfo)"
    if ($current -ne $wu.TargetReleaseVersionInfo) { $problems += "version installée $current différente de $($wu.TargetReleaseVersionInfo)" }
    if ($problems) { $detail = $detail + ' : ' + ($problems -join '; ') }
    return (New-LabCheck -Name 'windows-update' -Passed ($problems.Count -eq 0) -Detail $detail)
}

Export-ModuleMember -Function *
