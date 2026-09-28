#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-04 : R2 est physique; le retrait se fait sur le matériel (aucune action logicielle).
#>
[CmdletBinding()]
param([switch]$Force)

Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Assert-LabComputer -Expected 'AB-PC-04' -Force:$Force
Write-LabOK 'R2 est une panne physique : le retrait (rebrancher, remettre l''ordre de démarrage) se fait sur le matériel.'
exit 0
