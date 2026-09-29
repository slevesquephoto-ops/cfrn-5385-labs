#requires -version 5.1
<#
.SYNOPSIS
    Prépare les données ITFlow d'Architecture Boréale (5 équipes) via tools\ITFlow-AB.psm1.

.DESCRIPTION
    Par équipe : le client « Architecture Boréale — Équipe X », 2 lieux, 4 contacts (les
    employés), 5 actifs (les machines) et 5 requêtes (R1, R3, R4, R5, R6 selon la variante
    de l'équipe). R2 n'est pas créée (les élèves la créent à partir de l'appel).

    Par défaut : APERÇU seulement (n'appelle pas l'API, ne crée rien) — c'est ce que montre
    « -WhatIf ». Pour créer réellement : -Executer (le module vérifie d'abord les garde-fous
    avec Connect-ITFlowAB, refuse s'il voit un client protégé, et est idempotent).

    Le module et l'API ne gèrent PAS la visibilité des clients : dans ITFlow, un client
    n'est visible que des utilisateurs qui y ont accès (les administrateurs, et l'utilisateur
    « Claude » via les règles de refus). Les élèves ne voient rien tant que l'enseignant ne
    leur attribue pas l'accès par équipe. Aucune action de ce script là-dessus.

.EXAMPLE
    .\tools\New-ITFlowABData.ps1                       # aperçu des 5 équipes
    .\tools\New-ITFlowABData.ps1 -Equipes A            # aperçu de l'équipe A
    .\tools\New-ITFlowABData.ps1 -Equipes A -Executer  # crée réellement l'équipe A
#>
[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string[]]$Equipes = @('A', 'B', 'C', 'D', 'E'),
    # Force le texte de R6 sur cette variante pour toutes les équipes (pour cloner une équipe
    # à l'identique). Par défaut, chaque équipe prend sa propre lettre.
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$VarianteR6,
    # Inclut aussi R2 (l'appel de Jérémie). Par défaut R2 n'est pas créée (les élèves la créent).
    [switch]$AvecR2,
    [switch]$Executer
)

$ErrorActionPreference = 'Stop'
$cfg = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\AB\AB-Config.psd1')
$itf = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\AB\ITFlow-Donnees.psd1')
$domaine = $cfg.Entreprise.Domaine
$employes = @{}
foreach ($e in $cfg.Employes) { $employes[$e.Compte] = $e }
$ContactPrincipal = 'lpgauthier'

function Get-Courriel([string]$Compte) { "$Compte@$domaine" }

function Get-PlanEquipe([string]$Equipe) {
    # Contacts (les 4 employés)
    $contacts = foreach ($e in $cfg.Employes) {
        [pscustomobject]@{
            Compte = $e.Compte; Nom = $e.NomComplet; Titre = $e.Role
            Courriel = Get-Courriel $e.Compte; Telephone = $itf.Contacts[$e.Compte].Telephone
            Lieu = 'Bureaux'; Principal = ($e.Compte -eq $ContactPrincipal)
        }
    }
    # Actifs (les 5 machines)
    $actifs = foreach ($a in $itf.Actifs) {
        [pscustomobject]@{
            Nom = "AB-$($a.Machine)"; Type = $a.Type; Fabricant = $a.Fabricant; Modele = $a.Modele
            OS = $a.OS; IP = $cfg.Reseau.Machines[$a.Machine]; Lieu = $a.Lieu; Compte = $a.Compte
        }
    }
    # Requêtes (R1, R3, R4, R5, R6 selon la variante; R2 si -AvecR2)
    $codes = @('R1', 'R3', 'R4', 'R5', 'R6')
    if ($AvecR2) { $codes = @('R1', 'R2', 'R3', 'R4', 'R5', 'R6') }
    $r6variante = $Equipe; if ($VarianteR6) { $r6variante = $VarianteR6 }
    $requetes = foreach ($code in $codes) {
        $r = $itf.Requetes[$code]
        $sujet = $r.Sujet; $desc = $r.Description
        if ($code -eq 'R6') { $sujet = $r.Variantes[$r6variante].Sujet; $desc = $r.Variantes[$r6variante].Description }
        [pscustomobject]@{
            Code = $code; Sujet = $sujet; Details = $desc; Priorite = $r.Priorite
            Contact = $r.Contact; Poste = "AB-$($r.Poste)"
        }
    }
    return [pscustomobject]@{
        Equipe = $Equipe; Client = "$($cfg.Entreprise.Nom) — Équipe $Equipe"
        Lieux = $itf.Lieux; Contacts = $contacts; Actifs = $actifs; Requetes = $requetes
    }
}

function Show-Plan($plan) {
    Write-Host "`n=== Équipe $($plan.Equipe) : $($plan.Client) ===" -ForegroundColor Cyan
    Write-Host "  Lieux ($($plan.Lieux.Count)) : $(($plan.Lieux | ForEach-Object { "$($_.Nom)$(if ($_.Principal) { ' [principal]' })" }) -join ', ')"
    Write-Host "  Contacts ($($plan.Contacts.Count)) :"
    foreach ($c in $plan.Contacts) { Write-Host ("     {0,-11} {1,-26} {2,-38} {3}{4}" -f $c.Compte, $c.Nom, $c.Courriel, $c.Telephone, $(if ($c.Principal) { '  [principal]' })) }
    Write-Host "  Actifs ($($plan.Actifs.Count)) :"
    foreach ($a in $plan.Actifs) { Write-Host ("     {0,-10} {1,-8} {2,-24} {3,-14} {4,-16} {5}" -f $a.Nom, $a.Type, "$($a.Fabricant) $($a.Modele)", $a.IP, $a.Lieu, $(if ($a.Compte) { $a.Compte } else { '(sans contact)' })) }
    Write-Host "  Requêtes ($($plan.Requetes.Count)) :"
    foreach ($r in $plan.Requetes) { Write-Host ("     [{0,-6}] {1}  {2}  ({3} / {4})" -f $r.Priorite, $r.Code, $r.Sujet, $r.Contact, $r.Poste) }
}

function Invoke-CreationEquipe($plan) {
    Write-Host "`n### Création — équipe $($plan.Equipe)" -ForegroundColor Green
    $null = New-ITFlowABClient -Equipe $plan.Equipe
    Connect-ITFlowAB -Equipe $plan.Equipe

    $lieuId = @{}
    foreach ($l in $plan.Lieux) { $lieuId[$l.Nom] = New-ITFlowABLocation -Nom $l.Nom -Description $l.Description -Principal:$l.Principal }
    $contactId = @{}
    foreach ($c in $plan.Contacts) {
        $contactId[$c.Compte] = New-ITFlowABContact -Nom $c.Nom -Courriel $c.Courriel -Titre $c.Titre -Telephone $c.Telephone -LieuId ([int]$lieuId[$c.Lieu]) -Principal:$c.Principal
    }
    $assetId = @{}
    foreach ($a in $plan.Actifs) {
        $cid = 0; if ($a.Compte -and $contactId[$a.Compte]) { $cid = [int]$contactId[$a.Compte] }
        $note = 'Numéro de série à compléter sur le matériel.'
        $assetId[$a.Nom] = New-ITFlowABAsset -Nom $a.Nom -Type $a.Type -Fabricant $a.Fabricant -Modele $a.Modele -OS $a.OS -IP $a.IP -Notes $note -LieuId ([int]$lieuId[$a.Lieu]) -ContactId $cid
    }
    foreach ($r in $plan.Requetes) {
        $cid = 0; if ($contactId[$r.Contact]) { $cid = [int]$contactId[$r.Contact] }
        $aid = 0; if ($assetId[$r.Poste]) { $aid = [int]$assetId[$r.Poste] }
        $null = New-ITFlowABTicket -Sujet $r.Sujet -Details $r.Details -Priorite $r.Priorite -ContactId $cid -ActifId $aid
    }
}

# ---------------------------------------------------------------------------
$plans = foreach ($eq in $Equipes) { Get-PlanEquipe -Equipe $eq }
foreach ($p in $plans) { Show-Plan $p }

$nbReq = 5; if ($AvecR2) { $nbReq = 6 }
$parEquipe = 1 + $itf.Lieux.Count + $cfg.Employes.Count + $itf.Actifs.Count + $nbReq
Write-Host "`nTotal : $($Equipes.Count) équipe(s) × (1 client + $($itf.Lieux.Count) lieux + $($cfg.Employes.Count) contacts + $($itf.Actifs.Count) actifs + $nbReq requêtes) = $($parEquipe * $Equipes.Count) objets." -ForegroundColor Yellow
if ($VarianteR6) { Write-Host "R6 forcée sur la variante $VarianteR6 pour toutes les équipes (clonage)." }
if (-not $AvecR2) { Write-Host "R2 n'est pas créée (les élèves la créent)." }
Write-Host 'Numéros de série et identifiants : à compléter à la main.'

if (-not $Executer) {
    Write-Host "`nAperçu seulement : rien n'a été créé. Pour créer réellement, relancer avec -Executer (équipe par équipe conseillé)." -ForegroundColor Yellow
    return
}

Import-Module (Join-Path $PSScriptRoot 'ITFlow-AB.psm1') -Force
Connect-ITFlowAB   # garde-fous : refuse si un client protégé est visible
foreach ($p in $plans) { Invoke-CreationEquipe $p }
Write-Host "`n[OK] Création terminée pour : $($Equipes -join ', ')." -ForegroundColor Green
