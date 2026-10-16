#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Console enseignant des pannes spontanées (clients particuliers).

.DESCRIPTION
    À lancer sur le poste de mise en situation, de préférence par Console-Particuliers.cmd
    (ouvre le menu en administrateur). Menu pour : choisir un client, installer ou retirer une
    panne du catalogue, vérifier l'état, consulter la fiche (récit / cause / correction) et
    nettoyer le client. S'appuie sur le moteur Particuliers\Particuliers-Lab.psm1, exactement
    comme Particuliers\Client.ps1.

.PARAMETER Client
    Compte du client à présélectionner (sinon, choix au démarrage).
#>
[CmdletBinding()]
param([string]$Client)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Import-Module (Join-Path $Root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $Root 'AB\AB-Lab.psm1') -Force
Import-Module (Join-Path $Root 'Particuliers\Particuliers-Lab.psm1') -Force

$script:Client = $Client

# --- Thèmes (préfixe d'Id -> titre de section) ---------------------------------
$script:Themes = [ordered]@{
    ACC = 'Accessibilité'; RES = 'Réseau'; SYS = 'Système et performance'; SEC = 'Sécurité'
    NAV = 'Navigateur'; PUP = 'Logiciels indésirables'; STRAT = 'Restrictions (stratégies)'
    CPT = 'Comptes'; FIC = 'Fichiers'
}
$script:OrdreThemes = @('RES', 'SYS', 'SEC', 'NAV', 'PUP', 'STRAT', 'CPT', 'FIC', 'ACC')

function Get-PartTheme([string]$Id) {
    $prefixe = ($Id -split '-')[0]
    if ($script:Themes.Contains($prefixe)) { return $script:Themes[$prefixe] }
    return 'Autres'
}

# --- Affichage et saisie -------------------------------------------------------
function Get-PartLargeur { try { return [Math]::Max(60, [Console]::WindowWidth - 1) } catch { return 100 } }

function Confirm-Part([string]$Question, [bool]$Defaut = $false) {
    $choix = '(o/N)'; if ($Defaut) { $choix = '(O/n)' }
    while ($true) {
        $r = (Read-Host "$Question $choix").Trim().ToLower()
        if (-not $r) { return $Defaut }
        if ($r -in 'o', 'oui') { return $true }
        if ($r -in 'n', 'non') { return $false }
    }
}

function Wait-PartRetour { $null = Read-Host '  Entrée pour revenir au menu' }

function Get-PartJournal([datetime]$Debut) {
    $dir = Get-LabDataPath -Child 'Logs'
    return Get-ChildItem -LiteralPath $dir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $Debut } | Sort-Object LastWriteTime | Select-Object -Last 1
}

function Test-PartPresent([string]$Compte) { return [bool](Get-LocalUser -Name $Compte -ErrorAction SilentlyContinue) }
function Get-PartInstalledId([string]$Compte) { return @(Get-PartInstalled -Compte $Compte | ForEach-Object { $_.Id }) }

# --- Catalogue -----------------------------------------------------------------
function Get-PartCatalogueOrdonne {
    $pannes = @((Get-PartConfig).Pannes)
    $ordonnees = @()
    foreach ($t in $script:OrdreThemes) {
        foreach ($p in $pannes) { if ((($p.Id -split '-')[0]) -eq $t) { $ordonnees += $p } }
    }
    foreach ($p in $pannes) { if ($script:OrdreThemes -notcontains (($p.Id -split '-')[0])) { $ordonnees += $p } }
    return $ordonnees
}

function Show-PartCatalogue([string]$Compte) {
    $installes = Get-PartInstalledId $Compte
    $liste = Get-PartCatalogueOrdonne
    $index = @()
    $themeCourant = ''
    $n = 0
    foreach ($p in $liste) {
        $theme = Get-PartTheme $p.Id
        if ($theme -ne $themeCourant) { Write-Host ''; Write-Host "  $theme" -ForegroundColor Cyan; $themeCourant = $theme }
        $n++
        $marque = ''; $col = 'Gray'
        if ($installes -contains $p.Id) { $marque = '  [installée]'; $col = 'Yellow' }
        Write-Host ('    {0,2}. {1,-14} {2,-7} diff {3}/5  {4}{5}' -f $n, $p.Id, $p.Portee, $p.Difficulte, $p.Titre, $marque) -ForegroundColor $col
        $index += $p
    }
    return $index
}

function Show-PartFiche($p) {
    Write-Host ''
    Write-Host ('  {0} — {1}' -f $p.Id, $p.Titre) -ForegroundColor White
    Write-Host ('  Portée : {0}    Difficulté : {1}/5    Durée (pose / diag) : {2}' -f $p.Portee, $p.Difficulte, $p.Duree)
    if ($p.Incompatibles -and @($p.Incompatibles).Count) {
        Write-Host ('  Incompatible avec : {0}' -f (@($p.Incompatibles) -join ', ')) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  Ce que dit le client :' -ForegroundColor Cyan
    Write-Host ('    « {0} »' -f $p.Recit)
    Write-Host '  Cause installée :' -ForegroundColor Cyan
    Write-Host ('    {0}' -f $p.Cause)
    Write-Host '  Correction attendue :' -ForegroundColor Cyan
    Write-Host ('    {0}' -f $p.Correction)
    Write-Host ''
}

# --- Clients -------------------------------------------------------------------
function Select-PartClient {
    $clients = @((Get-PartConfig).Clients)
    Clear-Host
    Write-Host '  Clients' -ForegroundColor Cyan
    for ($i = 0; $i -lt $clients.Count; $i++) {
        $c = $clients[$i]
        $etat = 'absent'; if (Test-PartPresent $c.Compte) { $etat = 'présent' }
        $ids = Get-PartInstalledId $c.Compte
        $p = 'aucune panne'; if ($ids) { $p = $ids -join ', ' }
        Write-Host ('    {0}. {1,-10} {2,-22} {3,-9} {4}' -f ($i + 1), $c.Compte, $c.NomComplet, $etat, $p)
    }
    $r = (Read-Host '  Numéro du client (Entrée = 1)').Trim()
    if ($r -match '^\d+$' -and [int]$r -ge 1 -and [int]$r -le $clients.Count) { return $clients[[int]$r - 1].Compte }
    return $clients[0].Compte
}

function Show-PartCompte {
    Write-Host ''
    Write-Host '  Comptes (mots de passe fictifs documentés)' -ForegroundColor Cyan
    foreach ($c in (Get-PartConfig).Clients) {
        $role = 'standard'; if ($c.Admin) { $role = 'admin' }
        Write-Host ('    {0,-10} {1,-22} {2,-9} {3}' -f $c.Compte, $c.NomComplet, $role, $c.MotDePasse)
    }
    Write-Host ('    {0,-10} {1}' -f (Get-PartConfig).Administrateur, '(compte enseignant / administrateur)')
}

# --- Actions -------------------------------------------------------------------
function Invoke-PartInstaller([string]$Compte) {
    $index = @(Show-PartCatalogue $Compte)
    Write-Host ''
    $r = (Read-Host '  Numéro de la panne à installer (Entrée = annuler)').Trim()
    if (-not $r -or $r -notmatch '^\d+$') { return $null }
    $i = [int]$r; if ($i -lt 1 -or $i -gt $index.Count) { return $null }
    $p = $index[$i - 1]
    Show-PartFiche $p
    if (-not (Confirm-Part ('Installer {0} pour {1}?' -f $p.Id, $Compte))) { return $null }
    $null = Start-LabLog -Name "Client-$Compte-$($p.Id)"
    $code = 0
    try { Install-PartPanne -Compte $Compte -Id $p.Id } catch { Write-LabWarn $_.Exception.Message; $code = 1 } finally { Stop-LabLog }
    return $code
}

function Invoke-PartRetirer([string]$Compte) {
    $ids = Get-PartInstalledId $Compte
    if (-not $ids) { Write-LabOK 'Aucune panne installée pour ce client.'; return 0 }
    Write-Host ''
    for ($i = 0; $i -lt $ids.Count; $i++) {
        $def = (Get-PartConfig).Pannes | Where-Object { $_.Id -eq $ids[$i] }
        Write-Host ('    {0}. {1,-14} {2}' -f ($i + 1), $ids[$i], $def.Titre)
    }
    $r = (Read-Host '  Numéro à retirer (T = toutes, Entrée = annuler)').Trim()
    if (-not $r) { return $null }
    if ($r -match '^[tT]$') {
        if (-not (Confirm-Part "Retirer TOUTES les pannes de $Compte?")) { return $null }
        $null = Start-LabLog -Name "Client-$Compte-RetraitTout"
        $code = 0
        try { foreach ($id in $ids) { Remove-PartPanne -Compte $Compte -Id $id } } catch { Write-LabWarn $_.Exception.Message; $code = 1 } finally { Stop-LabLog }
        return $code
    }
    if ($r -notmatch '^\d+$') { return $null }
    $i = [int]$r; if ($i -lt 1 -or $i -gt $ids.Count) { return $null }
    $id = $ids[$i - 1]
    if (-not (Confirm-Part "Retirer $id de $Compte?")) { return $null }
    $null = Start-LabLog -Name "Client-$Compte-$id"
    $code = 0
    try { Remove-PartPanne -Compte $Compte -Id $id } catch { Write-LabWarn $_.Exception.Message; $code = 1 } finally { Stop-LabLog }
    return $code
}

function Invoke-PartVerifier([string]$Compte) {
    Write-Host ''
    Write-Host "  VÉRIFICATION — $Compte" -ForegroundColor Cyan
    $v = Get-PartVerification -Compte $Compte
    $attendues = @(); if ($v.Attendues) { $attendues = @($v.Attendues) }
    $largeur = Get-PartLargeur
    $conforme = $true
    foreach ($c in @($v.Checks)) {
        $estPanne = ($attendues -contains $c.nom)
        if ($estPanne) {
            if (-not $c.ok) { $tag = 'PANNE'; $col = 'Yellow'; $note = '' }
            else { $tag = 'ÉCHEC'; $col = 'Red'; $note = 'panne attendue mais absente : '; $conforme = $false }
        } else {
            if ($c.ok) { $tag = 'OK'; $col = 'Green'; $note = '' }
            else { $tag = 'ÉCHEC'; $col = 'Red'; $note = ''; $conforme = $false }
        }
        $detail = $note + [string]$c.detail
        $debut = '  [{0,-5}] {1,-16} ' -f $tag, $c.nom
        if ($debut.Length + $detail.Length -gt $largeur) { $detail = $detail.Substring(0, [Math]::Max(0, $largeur - $debut.Length - 3)) + '...' }
        Write-Host $debut -ForegroundColor $col -NoNewline
        Write-Host $detail
    }
    Write-Host ''
    $attendu = 'Propre'; if ($attendues.Count) { $attendu = 'Panne' }
    if ($conforme) { Write-Host "  => Conforme (attendu : $attendu)." -ForegroundColor Green }
    else { Write-Host '  => Non conforme : voir les lignes ÉCHEC.' -ForegroundColor Red }
    return 0
}

function Invoke-PartFiche([string]$Compte) {
    $index = @(Show-PartCatalogue $Compte)
    Write-Host ''
    $r = (Read-Host '  Numéro de la panne (Entrée = annuler)').Trim()
    if (-not $r -or $r -notmatch '^\d+$') { return $null }
    $i = [int]$r; if ($i -lt 1 -or $i -gt $index.Count) { return $null }
    Show-PartFiche $index[$i - 1]
    return 0
}

function Invoke-PartSupprimer([string]$Compte) {
    if (-not (Test-PartPresent $Compte)) { Write-LabOK "$Compte n'est pas sur le poste."; return 0 }
    Write-Host '  Cette action retire toutes les pannes PUIS supprime le compte et le profil du client.' -ForegroundColor Yellow
    if (-not (Confirm-Part "Supprimer complètement $Compte du poste?")) { return $null }
    $null = Start-LabLog -Name "Client-$Compte-Supprimer"
    $code = 0
    try { Remove-PartClient -Compte $Compte } catch { Write-LabWarn $_.Exception.Message; $code = 1 } finally { Stop-LabLog }
    return $code
}

function Invoke-PartMenuAction([string]$Nom, [string]$Compte) {
    switch ($Nom) {
        'Installer' { return (Invoke-PartInstaller $Compte) }
        'Retirer' { return (Invoke-PartRetirer $Compte) }
        'Verifier' { return (Invoke-PartVerifier $Compte) }
        'Fiche' { return (Invoke-PartFiche $Compte) }
        'Supprimer' { return (Invoke-PartSupprimer $Compte) }
    }
}

# --- Menu ----------------------------------------------------------------------
function Show-PartMenu {
    $c = (Get-PartConfig).Clients | Where-Object { $_.Compte -eq $script:Client } | Select-Object -First 1
    $present = 'absent'; $colP = 'DarkGray'; if (Test-PartPresent $script:Client) { $present = 'présent'; $colP = 'Green' }
    $ids = Get-PartInstalledId $script:Client
    $pann = 'aucune'; $colPann = 'Green'; if ($ids) { $pann = $ids -join ', '; $colPann = 'Yellow' }
    $trait = '=' * 70
    Clear-Host
    Write-Host $trait -ForegroundColor DarkCyan
    Write-Host ('  Pannes spontanées — Console enseignant'.PadRight(56) + $env:COMPUTERNAME) -ForegroundColor White
    $nom = $script:Client; if ($c) { $nom = "$($c.NomComplet) ($($c.Compte))" }
    Write-Host "  Client : $nom"
    Write-Host '  Présence : ' -NoNewline; Write-Host $present -ForegroundColor $colP
    Write-Host '  Pannes installées : ' -NoNewline; Write-Host $pann -ForegroundColor $colPann
    Write-Host "  Dépôt : $Root"
    if (Test-PartABPanne) { Write-Host '  ATTENTION : une panne AB est installée (les pannes de portée Machine seront refusées).' -ForegroundColor Yellow }
    Write-Host $trait -ForegroundColor DarkCyan

    $items = @()
    $items += @{ Section = 'PANNES'; Cle = '1'; Texte = 'Installer une panne (catalogue)'; Action = 'Installer' }
    $items += @{ Section = ''; Cle = '2'; Texte = 'Retirer une panne (ou toutes)'; Action = 'Retirer' }
    $items += @{ Section = 'VÉRIFICATION / CORRECTION'; Cle = '3'; Texte = 'Vérifier l''état du client'; Action = 'Verifier' }
    $items += @{ Section = ''; Cle = '4'; Texte = 'Fiche d''une panne (récit / cause / correction)'; Action = 'Fiche' }
    $items += @{ Section = 'CLIENT'; Cle = '5'; Texte = 'Supprimer le client du poste (nettoyage complet)'; Action = 'Supprimer' }
    $items += @{ Section = ''; Cle = 'C'; Texte = 'Changer de client'; Action = '#Client' }
    $items += @{ Section = 'AUTRES'; Cle = 'M'; Texte = 'Afficher les comptes et mots de passe'; Action = '#Comptes' }
    $items += @{ Section = ''; Cle = 'J'; Texte = 'Ouvrir le dernier journal'; Action = '#Journal' }
    if (Test-Path -LiteralPath (Join-Path $Root 'Menu-AB.ps1')) { $items += @{ Section = ''; Cle = 'A'; Texte = 'Ouvrir la console AB'; Action = '#AB' } }
    $items += @{ Section = ''; Cle = '0'; Texte = 'Quitter'; Action = '#Quitter' }

    foreach ($i in $items) {
        if ($i.Section) { Write-Host ''; Write-Host "  $($i.Section)" -ForegroundColor Cyan }
        Write-Host ('    {0}. {1}' -f $i.Cle, $i.Texte)
    }
    Write-Host ('-' * 70) -ForegroundColor DarkCyan
    return $items
}

# --- Client de départ ----------------------------------------------------------
$noms = @((Get-PartConfig).Clients | ForEach-Object { $_.Compte })
if (-not $script:Client -or $noms -notcontains $script:Client) { $script:Client = Select-PartClient }

while ($true) {
    $items = Show-PartMenu
    $choix = (Read-Host '  Choix').Trim().ToUpper()
    $item = $items | Where-Object { $_.Cle -eq $choix } | Select-Object -First 1
    if (-not $item) { continue }
    if ($item.Action -eq '#Quitter') { exit 0 }
    if ($item.Action -eq '#Client') { $script:Client = Select-PartClient; continue }
    if ($item.Action -eq '#Comptes') { Show-PartCompte; Wait-PartRetour; continue }
    if ($item.Action -eq '#Journal') {
        $log = Get-PartJournal ([datetime]::MinValue)
        if ($log) { Start-Process -FilePath notepad.exe -ArgumentList ('"' + $log.FullName + '"') }
        else { Write-LabWarn 'Aucun journal pour le moment.'; Wait-PartRetour }
        continue
    }
    if ($item.Action -eq '#AB') {
        Start-Process -FilePath powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $Root 'Menu-AB.ps1') + '"')
        continue
    }
    Write-Host ''
    $debut = Get-Date
    try { $code = Invoke-PartMenuAction $item.Action $script:Client } catch { Write-LabWarn $_.Exception.Message; $code = 1 }
    Write-Host ''
    if ($null -eq $code) { Write-Host '  Annulé.' -ForegroundColor DarkGray }
    elseif ($code -eq 0) { Write-Host '  Terminé : réussi.' -ForegroundColor Green }
    else {
        Write-Host '  Terminé : à vérifier (voir messages).' -ForegroundColor Red
        $log = Get-PartJournal $debut
        if ($log -and (Confirm-Part "Ouvrir le journal ($($log.Name))?")) { Start-Process -FilePath notepad.exe -ArgumentList ('"' + $log.FullName + '"') }
    }
    Wait-PartRetour
}
