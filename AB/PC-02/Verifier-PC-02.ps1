#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-02 : contrôle l'état (contrat Verifier-*).

.DESCRIPTION
    Écrit une ligne JSON {"machine","attendu","ok","echecs","controles"}; code 0 si l'état
    observé correspond à -Attendu. Chaque contrôle décrit l'état PROPRE.
    Communs (Test-ABPoste) : logiciels, windows-update, politique-mdp, strategies, profil.
    R4 : demarrage (aucun élément de démarrage inutile ni processus gourmand), ram (RAM
    installée, rapportée sans échouer : la couche matérielle est manuelle).
    -R3 : sauvegarde-r3 (fichiers « Critique » de lpgauthier présents, par hash, dans
    \\AB-SRV-01\Sauvegardes$\lpgauthier\<date>).
    En Panne, échec attendu : demarrage.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Propre', 'Panne')][string]$Attendu,
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante,
    [switch]$R3
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-02'
$Compte = 'lpgauthier'
$checks = @(Test-ABPoste -Machine $Machine -Compte $Compte)

function Add-Check([string]$Name, [string[]]$Problems, [string]$OkDetail) {
    $detail = $OkDetail
    if ($Problems) { $detail = $Problems -join '; ' }
    $script:checks += New-LabCheck -Name $Name -Passed (-not $Problems) -Detail $detail
}

# R4 couche logicielle
Add-Check 'demarrage' @(Test-ABStartupClutter -Compte $Compte) 'démarrage propre, aucun processus fictif'

# RAM : rapportée sans échouer (la couche matérielle de R4 est manuelle)
$checks += New-LabCheck -Name 'ram' -Passed $true -Detail "$(Get-ABInstalledMemoryGo) Go de RAM installés (contrôle informatif)"

# -R3 : sauvegarde des fichiers « Critique » de lpgauthier
if ($R3) {
    $prof = (Get-CimInstance Win32_UserProfile -Filter "SID='$((Get-LocalUser -Name $Compte).SID.Value)'").LocalPath
    $manifest = Join-Path $PSScriptRoot "..\data\$Compte\manifeste-$Compte.csv"
    Add-Check 'sauvegarde-r3' @(Test-ABBackup -Compte $Compte -ProfilePath $prof -Manifest $manifest) 'fichiers Critique sauvegardés dans Sauvegardes$'
}

if ($Attendu -eq 'Panne') {
    if (-not $Variante) { $st = Get-LabState -Scenario $Machine; if ($st) { $Variante = $st.Variante } }
    if ($Variante) { exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks -EchecsAttendus @('demarrage')) }
}
exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks)
