#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Préparation unique d'une machine AB, avant le point de contrôle Propre (VM)
    ou avant la première équipe (vrai matériel).

.DESCRIPTION
    1. Verrouille Windows sur la version de AB-Config.psd1 (TargetReleaseVersion) :
       aucune mise à jour de fonctionnalités, les mises à jour de sécurité continuent.
    2. Sur les postes (PC-01..PC-04) : tools\Install-ABSoftware.ps1.
    Idempotent. Code de sortie 0 si tout est conforme.

.EXAMPLE
    .\tools\Set-ABPoste.ps1 -Poste PC-03 -Methode Local
    .\tools\Set-ABPoste.ps1 -Poste SRV-01
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('SRV-01', 'PC-01', 'PC-02', 'PC-03', 'PC-04')][string]$Poste,
    [ValidateSet('Auto', 'Winget', 'Local')][string]$Methode = 'Auto',
    [string]$SourceLocale,
    [ValidateRange(5, 120)][int]$TimeoutMinutes = 30,
    [switch]$Force
)

# $PSScriptRoot est vide dans les valeurs par défaut de param en 5.1 (lancement par -File)
if (-not $SourceLocale) { $SourceLocale = Join-Path $PSScriptRoot 'installeurs' }
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB\AB-Lab.psm1') -Force

$null = Start-LabLog -Name "Set-ABPoste-$Poste"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Poste" -Force:$Force

    Write-LabStep 'Windows Update : version verrouillée'
    Set-ABWindowsUpdateLock
    $check = Test-ABWindowsUpdateLock
    if ($check.ok) { Write-LabOK $check.detail } else { Write-LabWarn $check.detail; $exitCode = 1 }
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}

if ($Poste -ne 'SRV-01') {
    # Processus séparé : Install-ABSoftware a sa propre transcription et son code de sortie
    $installArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'Install-ABSoftware.ps1'),
        '-Poste', $Poste, '-Methode', $Methode, '-SourceLocale', $SourceLocale, '-TimeoutMinutes', $TimeoutMinutes)
    if ($Force) { $installArgs += '-Force' }
    & powershell.exe @installArgs
    if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
}
exit $exitCode
