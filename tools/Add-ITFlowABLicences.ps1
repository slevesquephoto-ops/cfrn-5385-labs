#requires -version 5.1
<#
.SYNOPSIS
    Ajoute les licences fictives (AB\ITFlow-Licences.psd1) au client ITFlow d'une équipe,
    représentées comme des actifs de type « Autre » (via tools\ITFlow-AB.psm1).

.DESCRIPTION
    Le module ITFlow-AB ne donne pas accès à l'onglet Licences dédié d'ITFlow; on
    représente chaque licence par un actif « Licence — <produit> (<machine>) » de type
    Other, avec l'éditeur, la clé fictive, les sièges, les dates et la machine dans les
    notes. Visible côté élève, sans modifier le module.

    Par défaut : APERÇU (aucun appel API). Pour créer réellement : -Executer (idempotent :
    un actif de même nom n'est pas recréé).

.EXAMPLE
    .\tools\Add-ITFlowABLicences.ps1 -Equipes A            # aperçu
    .\tools\Add-ITFlowABLicences.ps1 -Equipes A -Executer  # crée pour l'équipe A
#>
[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string[]]$Equipes = @('A', 'B', 'C', 'D', 'E'),
    [switch]$Executer
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$cfg = Import-PowerShellDataFile (Join-Path $repo 'AB\AB-Config.psd1')
$lic = (Import-PowerShellDataFile (Join-Path $repo 'AB\ITFlow-Licences.psd1')).Licences

function Get-LicenceNom($l) {
    if ($l.Machine) { "Licence — $($l.Produit) (AB-$($l.Machine))" } else { "Licence — $($l.Produit)" }
}
function Get-LicenceNotes($l) {
    $lignes = @("Éditeur : $($l.Editeur)", "Clé (fictive) : $($l.Cle)", "Sièges : $($l.Sieges)")
    if ($l.Machine) { $lignes += "Machine : AB-$($l.Machine)" } elseif ($l['Portee']) { $lignes += "Portée : $($l.Portee)" }
    $lignes += "Acheté : $($l.Achat)"
    $lignes += "Expiration : $(if ($l.Expiration) { $l.Expiration } else { 'perpétuelle' })"
    if ($l['Note']) { $lignes += $l.Note }
    return ($lignes -join "`n")
}

Write-Host "Licences ($($lic.Count)) à créer par équipe (actifs de type Autre) :" -ForegroundColor Cyan
foreach ($l in $lic) {
    $exp = if ($l.Expiration) { $l.Expiration } else { 'perpétuelle' }
    Write-Host ("  {0,-52} {1,-10} exp. {2}{3}" -f (Get-LicenceNom $l), $l.Editeur, $exp, $(if ($l['Note']) { '  [!]' }))
}
Write-Host "`nÉquipes visées : $($Equipes -join ', ')"
Write-Host 'Incohérence : 5 machines en Windows 11 réel, mais 4 licences Windows 11 + 1 Windows Server 2019 (AB-SRV-01).'

if (-not $Executer) {
    Write-Host "`nAperçu seulement : rien n'a été créé. Relancer avec -Executer pour créer." -ForegroundColor Yellow
    return
}

Import-Module (Join-Path $PSScriptRoot 'ITFlow-AB.psm1') -Force
Connect-ITFlowAB
foreach ($eq in $Equipes) {
    Write-Host "`n### Licences — équipe $eq" -ForegroundColor Green
    Connect-ITFlowAB -Equipe $eq
    # Lieu Bureaux (pour rattacher les licences), s'il existe
    $lieu = Get-ITFlowAB -Module locations | Where-Object { $_.location_name -eq 'Bureaux' } | Select-Object -First 1
    $lieuId = 0; if ($lieu) { $lieuId = [int]$lieu.location_id }
    foreach ($l in $lic) {
        $null = New-ITFlowABAsset -Nom (Get-LicenceNom $l) -Type 'Other' -Fabricant $l.Editeur -Modele $l.Produit `
            -NumeroSerie $l.Cle -Notes (Get-LicenceNotes $l) -LieuId $lieuId
    }
}
Write-Host "`n[OK] Licences créées pour : $($Equipes -join ', ')." -ForegroundColor Green
