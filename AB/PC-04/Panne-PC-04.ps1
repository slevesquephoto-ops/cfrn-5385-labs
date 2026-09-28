#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-04 : R2 est une panne PHYSIQUE, préparée à la main (aucune action logicielle).

.DESCRIPTION
    Ce script n'installe rien : R2 (« Mon ordinateur ne démarre plus ») se prépare sur le
    matériel selon la variante de l'équipe (voir GUIDE-ENSEIGNANT.md). Présent pour
    respecter le contrat des scripts par machine et rappeler la marche à suivre.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante,
    [switch]$Force
)

Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Assert-LabComputer -Expected 'AB-PC-04' -Force:$Force
Write-LabWarn "R2 est une panne physique (variante $Variante) : à préparer sur le matériel, pas par script."
Write-LabStep 'Voir GUIDE-ENSEIGNANT.md, section « Pannes physiques R2 »'
exit 0
