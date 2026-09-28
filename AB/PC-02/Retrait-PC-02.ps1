#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-02 : retire R4 couche logicielle depuis l'état enregistré par Panne-PC-02.ps1.

.DESCRIPTION
    Arrête le processus gourmand, retire la tâche planifiée, restaure les valeurs Run
    d'origine et supprime le dossier des scripts déposés. Sans état : rien à faire.
    Le Setup suivant recrée de toute façon le profil de lpgauthier à neuf.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-02'
$null = Start-LabLog -Name "Retrait-$Machine"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $state = Get-LabState -Scenario $Machine
    if (-not $state) { Write-LabOK 'Aucune panne installée : rien à retirer.'; return }

    Write-LabStep 'R4 : démarrage encombré et processus gourmand'
    Remove-ABStartupClutter -State $state.R4
    Write-LabOK 'Éléments de démarrage et processus gourmand retirés.'

    Remove-LabState -Scenario $Machine
    Write-LabOK 'Panne retirée.'
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
