#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-03 : contrôle l'état (contrat Verifier-*).

.DESCRIPTION
    Écrit une ligne JSON {"machine","attendu","ok","echecs","controles"}; code 0 si l'état
    observé correspond à -Attendu. Chaque contrôle décrit l'état PROPRE.
    Communs (Test-ABPoste) : logiciels, windows-update, politique-mdp, strategies, profil.
    R1 sur le poste : hosts et resolution (couche 1), identifiant (couche 2, lu dans la
    session d'efortin par une tâche ponctuelle).
    En Panne (panne identique pour toutes les variantes), échecs attendus exacts :
    hosts, resolution, identifiant.
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
$server = $cfg.Reseau.Serveur
$checks = @(Test-ABPoste -Machine $Machine -Compte $Compte)

function Add-Check([string]$Name, [string[]]$Problems, [string]$OkDetail) {
    $detail = $OkDetail
    if ($Problems) { $detail = $Problems -join '; ' }
    $script:checks += New-LabCheck -Name $Name -Passed (-not $Problems) -Detail $detail
}

# R1 couche 1 : fichier hosts et résolution du nom (échoue aussi si le serveur est éteint)
$hosts = Get-Content -LiteralPath (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts')
$bad = @($hosts | Where-Object { $_ -notmatch '^\s*#' -and $_ -match [regex]::Escape($server) })
$p = @(); if ($bad) { $p += "hosts : $($bad -join ' | ')" }
Add-Check 'hosts' $p "aucune entrée pour $server"

$p = @()
$want = $cfg.Reseau.Machines['SRV-01']
try {
    $got = @([Net.Dns]::GetHostAddresses($server) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.IPAddressToString })
    if ($got -notcontains $want) { $p += "$server -> $($got -join ', ') (attendu $want)" }
} catch { $p += "$server introuvable (serveur éteint ou réseau absent?)" }
Add-Check 'resolution' $p "$server -> $want"

# R1 couche 2 : identifiant mémorisé dans la session d'efortin
$p = @()
if ((Get-ABUserCredentialTarget -Compte $emp.Compte -Password $emp.MotDePasse) -contains $server) { $p += "identifiant mémorisé pour $server dans le Gestionnaire d'identification de $Compte" }
Add-Check 'identifiant' $p "aucun identifiant mémorisé pour $server"

if ($Attendu -eq 'Panne') {
    if (-not $Variante) { $st = Get-LabState -Scenario $Machine; if ($st) { $Variante = $st.Variante } }
    if ($Variante) { exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks -EchecsAttendus @('hosts', 'resolution', 'identifiant')) }
}
exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks)
