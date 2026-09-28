#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-SRV-01 : contrôle l'état (contrat Verifier-*).

.DESCRIPTION
    Écrit une ligne JSON {"machine","attendu","ok","echecs","controles"} et termine avec 0
    si l'état observé correspond à -Attendu. Chaque contrôle décrit l'état PROPRE.
    En Panne, la variante (paramètre, sinon état enregistré) fixe EXACTEMENT les contrôles
    qui doivent échouer : une panne partielle ou un dégât collatéral fait échouer.

      Variante   Contrôles en échec attendus
      A          motdepasse-efortin, ntfs-descendants
      B          motdepasse-efortin, ntfs-descendants, r6-verrou
      C          motdepasse-efortin, groupes
      D          motdepasse-efortin, ntfs-racines
      E          motdepasse-efortin, partages
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Propre', 'Panne')][string]$Attendu,
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'SRV-01'
$cfg = Get-ABConfig
$r1 = $cfg.Pannes.R1
$checks = @()

function Add-Check([string]$Name, [string[]]$Problems, [string]$OkDetail) {
    $detail = $OkDetail
    if ($Problems) { $detail = $Problems -join '; ' }
    $script:checks += New-LabCheck -Name $Name -Passed (-not $Problems) -Detail $detail
}

# --- Réseau -----------------------------------------------------------------
$p = @()
$ip = $cfg.Reseau.Machines[$Machine]
$addr = Get-NetIPAddress -AddressFamily IPv4 -IPAddress $ip -ErrorAction SilentlyContinue
if (-not $addr) { $p += "IP $ip absente" }
elseif ($addr.PrefixOrigin -ne 'Manual' -or $addr.PrefixLength -ne $cfg.Reseau.Prefixe) { $p += "IP $ip non fixe ou mauvais masque" }
else {
    $prof = Get-NetConnectionProfile -InterfaceIndex $addr.InterfaceIndex -ErrorAction SilentlyContinue
    if (-not $prof -or $prof.NetworkCategory -ne 'Private') { $p += "profil réseau $($prof.NetworkCategory) (attendu Private)" }
}
$fw = @(Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' | Where-Object { $_.Profile -match 'Private|Any' -and $_.Direction -eq 'Inbound' })
if (-not $fw -or ($fw | Where-Object { $_.Enabled -ne 'True' })) { $p += 'règles « Partage de fichiers et d''imprimantes » désactivées' }
Add-Check 'reseau' $p "$ip/$($cfg.Reseau.Prefixe), profil Privé, pare-feu ouvert au partage"

# --- Comptes ------------------------------------------------------------------
$p = @()
$admins = (Get-ABSid -Name 'Administrateurs').Value
$adminMembers = @(Get-ABGroupMemberSid -GroupSid $admins)
$tech = Get-LocalUser -Name $cfg.Administrateur -ErrorAction SilentlyContinue
if (-not $tech) { $p += "$($cfg.Administrateur) absent" }
else {
    if ($adminMembers -notcontains $tech.SID.Value) { $p += "$($cfg.Administrateur) non administrateur" }
    if ($null -ne $tech.PasswordExpires) { $p += "$($cfg.Administrateur) : mot de passe qui expire" }
}
foreach ($e in $cfg.Employes) {
    $u = Get-LocalUser -Name $e.Compte -ErrorAction SilentlyContinue
    if (-not $u) { $p += "$($e.Compte) absent"; continue }
    if (-not $u.Enabled) { $p += "$($e.Compte) désactivé" }
    if ($adminMembers -contains $u.SID.Value) { $p += "$($e.Compte) administrateur" }
    if ($null -ne $u.PasswordExpires) { $p += "$($e.Compte) : mot de passe qui expire" }
    if ($e.Compte -ne $r1.Compte -and -not (Test-ABLocalPassword -UserName $e.Compte -Password $e.MotDePasse)) { $p += "$($e.Compte) : mot de passe LAB refusé" }
}
Add-Check 'comptes' $p "$($cfg.Employes.Count) employés standard + $($cfg.Administrateur) administrateur"

# --- R1 couche 2 --------------------------------------------------------------
$p = @()
$lab = ($cfg.Employes | Where-Object { $_.Compte -eq $r1.Compte }).MotDePasse
if (-not (Test-ABLocalPassword -UserName $r1.Compte -Password $lab)) {
    if (Test-ABLocalPassword -UserName $r1.Compte -Password $r1.MotDePassePanne) { $p += "$($r1.Compte) : mot de passe de panne (couche 2)" }
    else { $p += "$($r1.Compte) : mot de passe LAB refusé (autre mot de passe)" }
}
Add-Check 'motdepasse-efortin' $p "$($r1.Compte) : mot de passe LAB valide"

# --- Groupes ------------------------------------------------------------------
$p = @()
foreach ($g in $cfg.Groupes.Keys | Sort-Object) {
    $grp = Get-LocalGroup -Name $g -ErrorAction SilentlyContinue
    if (-not $grp) { $p += "$g absent"; continue }
    $want = @($cfg.Groupes[$g] | ForEach-Object { (Get-ABSid -Name $_).Value } | Sort-Object)
    $have = @(Get-ABGroupMemberSid -GroupSid $grp.SID.Value | Sort-Object)
    if (($want -join ',') -ne ($have -join ',')) {
        $missing = @($want | Where-Object { $have -notcontains $_ } | ForEach-Object { (New-Object Security.Principal.SecurityIdentifier($_)).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1] })
        $extra = @($have | Where-Object { $want -notcontains $_ } | ForEach-Object { ConvertTo-ABSidString -Identity $_ })
        $msg = "$g :"
        if ($missing) { $msg += " manque $($missing -join ', ')" }
        if ($extra) { $msg += " en trop $($extra -join ', ')" }
        if ($g -eq 'AB-Conception' -and $missing -contains $r1.Compte) { $msg += ' (variante C)' }
        $p += $msg
    }
}
Add-Check 'groupes' $p 'membres conformes'

# --- NTFS ---------------------------------------------------------------------
$p = @()
foreach ($s in $cfg.Partages) {
    if (-not (Test-Path -LiteralPath $s.Dossier)) { $p += "$($s.Dossier) absent"; continue }
    $acl = Get-Acl -LiteralPath $s.Dossier
    if (-not $acl.AreAccessRulesProtected) { $p += "$($s.Dossier) : héritage non coupé" }
    $want = Get-ABExpectedRootRule -Partage $s
    $have = Get-ABExplicitRule -Path $s.Dossier
    if (($want -join ',') -ne ($have -join ',')) {
        $msg = "$($s.Dossier) : règles différentes de la matrice"
        $conc = (Get-ABSid -Name 'AB-Conception').Value
        $readOnly = "$conc|$([int][Security.AccessControl.FileSystemRights]::ReadAndExecute)|Allow|3"
        if ($s.Nom -eq 'Projets' -and $have -contains $readOnly) { $msg += ' (AB-Conception en Lecture : variante D)' }
        $p += $msg
    }
}
Add-Check 'ntfs-racines' $p 'héritage coupé, règles de la matrice'

$p = @()
$userSid = (Get-ABSid -Name $r1.Compte).Value
foreach ($s in $cfg.Partages) {
    if (-not (Test-Path -LiteralPath $s.Dossier)) { continue }
    foreach ($i in Get-ChildItem -LiteralPath $s.Dossier -Recurse -Force) {
        $acl = Get-Acl -LiteralPath $i.FullName
        $explicit = @($acl.Access | Where-Object { -not $_.IsInherited })
        if (-not $acl.AreAccessRulesProtected -and -not $explicit) { continue }
        $msg = "$($i.FullName) :"
        if ($acl.AreAccessRulesProtected) { $msg += ' héritage coupé' }
        if ($explicit) { $msg += " $($explicit.Count) règle(s) explicite(s)" }
        if ($explicit | Where-Object { $_.AccessControlType -eq 'Deny' -and (ConvertTo-ABSidString -Identity $_.IdentityReference) -eq $userSid }) { $msg += " (Refuser pour $($r1.Compte) : variante A)" }
        elseif ($acl.AreAccessRulesProtected -and -not ($acl.Access | Where-Object { (ConvertTo-ABSidString -Identity $_.IdentityReference) -eq (Get-ABSid -Name 'AB-Conception').Value })) { $msg += ' (AB-Conception absent : variante B)' }
        $p += $msg
    }
}
Add-Check 'ntfs-descendants' $p 'tous les descendants en héritage pur'

# --- Partages -----------------------------------------------------------------
$p = @()
$auth = (Get-ABSid -Name 'Utilisateurs authentifiés').Value
foreach ($s in $cfg.Partages) {
    $share = Get-SmbShare -Name $s.Nom -ErrorAction SilentlyContinue
    if (-not $share) { $p += "$($s.Nom) absent"; continue }
    if ($share.Path.TrimEnd('\') -ne $s.Dossier.TrimEnd('\')) { $p += "$($s.Nom) -> $($share.Path)" }
    $have = Get-ABShareAccess -Name $s.Nom
    if (($have -join ',') -ne "$auth|Full|Allow") {
        $msg = "$($s.Nom) : accès $($have -join ', ')"
        if ($s.Nom -eq 'Projets' -and ($have -join ',') -eq "$auth|Read|Allow") { $msg += ' (partage en Lecture : variante E)' }
        $p += $msg
    }
}
Add-Check 'partages' $p "$($cfg.Partages.Count) partages, Utilisateurs authentifiés : Contrôle total"

# --- SMB, politique, Windows Update --------------------------------------------
$p = @()
$smb = Get-SmbServerConfiguration
if (-not $smb.RequireSecuritySignature) { $p += 'signature SMB non exigée' }
if ($smb.EnableSMB1Protocol) { $p += 'SMB1 activé' }
Add-Check 'smb-serveur' $p 'signature exigée, SMB1 désactivé'
$checks += Test-ABPasswordPolicy -Machine $Machine
$checks += Test-ABWindowsUpdateLock -Machine $Machine

# --- Données --------------------------------------------------------------------
$p = @()
foreach ($s in $cfg.Partages) {
    foreach ($sub in $cfg.Arborescence[$s.Nom]) { if (-not (Test-Path -LiteralPath (Join-Path $s.Dossier $sub))) { $p += "dossier absent : $(Join-Path $s.Dossier $sub)" } }
}
$dataRoot = Join-Path $PSScriptRoot '..\data\SRV-01'
$manifest = Join-Path $dataRoot 'manifeste-SRV-01.csv'
$okDetail = 'arborescence conforme (manifeste absent)'
if (Test-Path -LiteralPath $manifest) {
    $rows = @(Import-Csv -LiteralPath $manifest -Delimiter ';' -Encoding UTF8)
    foreach ($r in $rows) {
        $dst = Join-Path 'C:\AB' $r.TargetRelative
        if (-not (Test-Path -LiteralPath $dst)) { $p += "fichier absent : $dst" }
        elseif ((Get-FileHash -LiteralPath $dst).Hash -ne (Get-FileHash -LiteralPath (Join-Path $dataRoot $r.SourceRelative)).Hash) { $p += "fichier modifié : $dst" }
    }
    $okDetail = "arborescence et $($rows.Count) fichiers conformes"
}
$backup = ($cfg.Partages | Where-Object { $_.Nom -eq 'Sauvegardes$' }).Dossier
if (Get-ChildItem -LiteralPath $backup -Force -ErrorAction SilentlyContinue) { $p += 'Sauvegardes$ non vide' }
$swRoot = ($cfg.Partages | Where-Object { $_.Nom -eq 'Logiciels$' }).Dossier
foreach ($soft in $cfg.Logiciels | Where-Object { $_.Actif -and $_['DossierServeur'] }) {
    $f = Join-Path (Join-Path $swRoot $soft.DossierServeur) $soft.Fichier
    if (-not (Test-Path -LiteralPath $f)) { $p += "installeur absent : $f" }
    elseif ((Get-FileHash -LiteralPath $f).Hash -ne $soft.Sha256.ToUpper()) { $p += "installeur altéré : $f" }
}
Add-Check 'donnees' $p $okDetail

# --- R6 variante B ----------------------------------------------------------------
$p = @()
$adminDir = ($cfg.Partages | Where-Object { $_.Nom -eq 'Administration' }).Dossier
foreach ($l in Get-ChildItem -LiteralPath $adminDir -Recurse -Force -Filter '.~lock.*#' -ErrorAction SilentlyContinue) {
    $p += "verrou LibreOffice : $($l.FullName) (variante B)"
}
Add-Check 'r6-verrou' $p 'aucun verrou LibreOffice orphelin'

# --- Résultat -------------------------------------------------------------------
$expected = $null
if ($Attendu -eq 'Panne') {
    if (-not $Variante) { $st = Get-LabState -Scenario 'SRV-01'; if ($st) { $Variante = $st.Variante } }
    $map = @{
        'A' = @('motdepasse-efortin', 'ntfs-descendants')
        'B' = @('motdepasse-efortin', 'ntfs-descendants', 'r6-verrou')
        'C' = @('motdepasse-efortin', 'groupes')
        'D' = @('motdepasse-efortin', 'ntfs-racines')
        'E' = @('motdepasse-efortin', 'partages')
    }
    if ($Variante) { $expected = $map[$Variante] }
}
if ($expected) { exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks -EchecsAttendus $expected) }
exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks)
