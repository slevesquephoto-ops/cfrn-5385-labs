#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-03 : contrôle l'état (contrat Verifier-*).

.DESCRIPTION
    Écrit une ligne JSON {"machine","attendu","ok","echecs","controles"}; code 0 si l'état
    observé correspond à -Attendu. Chaque contrôle décrit l'état PROPRE.
    Contrôles du poste : logiciels, Windows Update, politique de mots de passe, stratégies,
    fichier hosts, profil d'efortin (moteur commun).
    Les contrôles des pannes R1 (couches 1 et 2 sur le poste) viendront avec Panne-PC-03.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Propre', 'Panne')][string]$Attendu,
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-03'
$Compte = 'efortin'
$cfg = Get-ABConfig
$emp = $cfg.Employes | Where-Object { $_.Compte -eq $Compte }
$DataRoot = Join-Path $PSScriptRoot "..\data\$Compte"
$checks = @()

function Add-Check([string]$Name, [string[]]$Problems, [string]$OkDetail) {
    $detail = $OkDetail
    if ($Problems) { $detail = $Problems -join '; ' }
    $script:checks += New-LabCheck -Name $Name -Passed (-not $Problems) -Detail $detail
}

# Logiciels
$p = @()
foreach ($s in Get-ABSoftwareList -Poste $Machine) { if (-not (Test-ABSoftware -Logiciel $s)) { $p += "$($s.Nom) absent" } }
Add-Check 'logiciels' $p "$(@(Get-ABSoftwareList -Poste $Machine).Count) logiciels présents"

$checks += Test-ABWindowsUpdateLock -Machine $Machine
$checks += Test-ABPasswordPolicy -Machine $Machine

# Stratégies du poste et ab-tech
$p = @(Test-ABMachinePolicy)
$tech = Get-LocalUser -Name $cfg.Administrateur -ErrorAction SilentlyContinue
if (-not $tech -or $null -ne $tech.PasswordExpires) { $p += "$($cfg.Administrateur) : mot de passe qui expire" }
Add-Check 'strategies' $p 'première ouverture, LibreOffice, ab-tech conformes'

# hosts (R1 couche 1 : entrée « ancien serveur »)
$p = @()
$hosts = Get-Content -LiteralPath (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts')
$bad = @($hosts | Where-Object { $_ -notmatch '^\s*#' -and $_ -match [regex]::Escape($cfg.Reseau.Serveur) })
if ($bad) { $p += "hosts : $($bad -join ' | ')" }
Add-Check 'hosts' $p "aucune entrée pour $($cfg.Reseau.Serveur)"

# Profil d'efortin
$p = @(Test-ABUserProfile -Employe $emp -Wallpaper 'C:\Windows\Web\Wallpaper\AB\fond-AB.png' -DataRoot $DataRoot -Manifest (Join-Path $DataRoot "manifeste-$Compte.csv"))
Add-Check 'profil' $p "profil de $Compte complet (ruche, lecteurs $($emp.Lecteurs -join ', '), fond d'écran, données)"

exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks)
