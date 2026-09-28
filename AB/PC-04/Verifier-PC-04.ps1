#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-04 : contrôle l'état (contrat Verifier-*).

.DESCRIPTION
    Écrit une ligne JSON {"machine","attendu","ok","echecs","controles"}; code 0 si l'état
    observé correspond à -Attendu. Chaque contrôle décrit l'état PROPRE.
    Communs (Test-ABPoste) : logiciels (dont LibreCAD, FreeCAD, Blender), windows-update,
    politique-mdp, strategies, profil.
    R2 est physique : « demarrage » est réussi du seul fait que le Verifier s'exécute;
    « ordre-demarrage » lit l'ordre UEFI si possible, sinon le signale en contrôle manuel
    (sans échouer). Il n'y a pas d'état « Panne » logiciel pour PC-04.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Propre', 'Panne')][string]$Attendu,
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$null = $Variante   # PC-04 n'a pas d'état de panne logiciel (R2 physique); accepté pour le contrat
$Machine = 'PC-04'
$checks = @(Test-ABPoste -Machine $Machine -Compte 'jbouchard')

# Le poste démarre : le Verifier tourne, donc le poste a démarré (R2 réglée)
$checks += New-LabCheck -Name 'demarrage' -Passed $true -Detail 'le poste a démarré (le contrôle s''exécute)'

# Disque en tête de l'ordre de démarrage (R2) : au mieux, sinon contrôle manuel
$boot = Get-ABBootOrder
if (-not $boot.Lisible) {
    $checks += New-LabCheck -Name 'ordre-demarrage' -Passed $true -Detail "CONTRÔLE MANUEL : $($boot.Detail)"
} else {
    $checks += New-LabCheck -Name 'ordre-demarrage' -Passed $boot.DisqueEnTete -Detail $boot.Detail
}

exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks)
