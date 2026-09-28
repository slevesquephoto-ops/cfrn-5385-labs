#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-03 : retire R1 couches 1 et 2 depuis l'état enregistré par Panne-PC-03.ps1.

.DESCRIPTION
    Fichier hosts remis octet pour octet; identifiant AB-SRV-01 retiré du Gestionnaire
    d'identification d'efortin s'il n'y était pas avant la panne. Sans état : rien à faire.
    Le Setup suivant recrée de toute façon le profil d'efortin à neuf.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$null = Start-LabLog -Name 'Retrait-PC-03'
$exitCode = 0
try {
    Assert-LabComputer -Expected 'AB-PC-03' -Force:$Force
    $state = Get-LabState -Scenario 'PC-03'
    if (-not $state) { Write-LabOK 'Aucune panne installée : rien à retirer.'; return }
    $cfg = Get-ABConfig
    $emp = $cfg.Employes | Where-Object { $_.Compte -eq $cfg.Pannes.R1.Compte }
    $server = $cfg.Reseau.Serveur

    Write-LabStep 'R1 couche 1 : fichier hosts'
    [IO.File]::WriteAllBytes((Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'), [Convert]::FromBase64String($state.Hosts))
    & ipconfig.exe /flushdns | Out-Null
    Write-LabOK 'hosts restauré.'

    Write-LabStep 'R1 couche 2 : identifiant mémorisé'
    if (-not $state.Identifiant) {
        if ((Get-ABUserCredentialTarget -Compte $emp.Compte -Password $emp.MotDePasse) -contains $server) {
            Remove-ABUserCredential -Compte $emp.Compte -Password $emp.MotDePasse -Target $server
        }
        Write-LabOK "Identifiant $server retiré."
    } else { Write-LabOK "Identifiant $server présent avant la panne : conservé." }

    Remove-LabState -Scenario 'PC-03'
    Write-LabOK 'Panne retirée.'
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
