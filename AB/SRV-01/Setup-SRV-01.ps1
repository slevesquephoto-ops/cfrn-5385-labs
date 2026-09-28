#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-SRV-01 : serveur de fichiers d'Architecture Boréale (état propre).

.DESCRIPTION
    Politique de mots de passe, comptes et groupes, dossiers et données, NTFS, partages,
    SMB, pare-feu et IP fixe. Idempotent et correctif : relancé entre deux équipes,
    il remet exactement l'état de la spec (membres des groupes, ACL, partages, fichiers).
    Refuse de s'exécuter si une panne est installée (lancer Retrait-SRV-01.ps1 d'abord).

.PARAMETER Force
    Ignore le nom du poste (AB-SRV-01).
.PARAMETER SourceInstalleurs
    Dossier des installeurs (tools\installeurs) : l'installeur MSI de LibreOffice est
    copié dans Logiciels$ (source de réparation, R6-C).
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string]$SourceInstalleurs
)

# $PSScriptRoot est vide dans les valeurs par défaut de param en 5.1 (lancement par -File)
if (-not $SourceInstalleurs) { $SourceInstalleurs = Join-Path $PSScriptRoot '..\..\tools\installeurs' }
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'SRV-01'
$DataRoot = Join-Path $PSScriptRoot '..\data\SRV-01'
$Manifest = Join-Path $DataRoot 'manifeste-SRV-01.csv'

function Sync-ABShareContent {
    <#
    Rend le contenu de C:\AB conforme : arborescence de la config + fichiers du manifeste
    (copiés si absents ou différents, dates appliquées). Tout le reste est retiré
    (fichiers laissés par une équipe), sauf dans Logiciels$ (géré à part).
    #>
    param($Config)
    $expectedFiles = @{}
    $expectedDirs = @{}
    foreach ($p in $Config.Partages) {
        $expectedDirs[$p.Dossier.ToLower()] = $true
        foreach ($sub in $Config.Arborescence[$p.Nom]) { $expectedDirs[(Join-Path $p.Dossier $sub).ToLower()] = $true }
    }
    foreach ($d in $expectedDirs.Keys) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

    if (Test-Path -LiteralPath $Manifest) {
        $rows = Import-Csv -LiteralPath $Manifest -Delimiter ';' -Encoding UTF8
        foreach ($r in $rows) {
            $src = Join-Path $DataRoot $r.SourceRelative
            $dst = Join-Path 'C:\AB' $r.TargetRelative
            $expectedFiles[$dst.ToLower()] = $true
            $parent = Split-Path -Parent $dst
            while ($parent -and $parent.Length -gt 5) { $expectedDirs[$parent.ToLower()] = $true; $parent = Split-Path -Parent $parent }
            if (-not (Test-Path -LiteralPath (Split-Path -Parent $dst))) { New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null }
            $copy = -not (Test-Path -LiteralPath $dst)
            if (-not $copy) { $copy = (Get-FileHash -LiteralPath $src).Hash -ne (Get-FileHash -LiteralPath $dst).Hash }
            if ($copy) { Copy-Item -LiteralPath $src -Destination $dst -Force }
            Set-LabItemTime -Path $dst -Created ([datetime]$r.CreationTime) -Modified ([datetime]$r.LastWriteTime)
        }
        Write-LabOK "$($rows.Count) fichiers du manifeste synchronisés."
    } else {
        Write-LabWarn "Manifeste absent ($Manifest) : arborescence seulement (données à produire par tools\New-ABData.ps1)."
    }

    # Retrait de ce qui n'est pas prévu (Sauvegardes$ est vidé : décision de l'enseignant)
    foreach ($p in $Config.Partages | Where-Object { $_.Nom -ne 'Logiciels$' }) {
        $extra = Get-ChildItem -LiteralPath $p.Dossier -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending
        foreach ($i in $extra) {
            $key = $i.FullName.ToLower()
            if ($i.PSIsContainer) { if (-not $expectedDirs.ContainsKey($key)) { Remove-Item -LiteralPath $i.FullName -Recurse -Force; Write-LabOK "Retiré : $($i.FullName)" } }
            elseif (-not $expectedFiles.ContainsKey($key)) { Remove-Item -LiteralPath $i.FullName -Force; Write-LabOK "Retiré : $($i.FullName)" }
        }
    }
}

function Sync-ABSoftwareShare {
    <# Logiciels$ : l'installeur de chaque logiciel qui a un DossierServeur, SHA256 vérifié; rien d'autre. #>
    param($Config)
    $root = ($Config.Partages | Where-Object { $_.Nom -eq 'Logiciels$' }).Dossier
    $expected = @{}
    foreach ($soft in $Config.Logiciels | Where-Object { $_.Actif -and $_['DossierServeur'] }) {
        $dir = Join-Path $root $soft.DossierServeur
        $dst = Join-Path $dir $soft.Fichier
        $expected[$dir.ToLower()] = $true
        $expected[$dst.ToLower()] = $true
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $ok = (Test-Path -LiteralPath $dst) -and ((Get-FileHash -LiteralPath $dst).Hash -eq $soft.Sha256.ToUpper())
        if (-not $ok) {
            $src = Join-Path $SourceInstalleurs $soft.Fichier
            if (-not (Test-Path -LiteralPath $src)) { Write-LabWarn "$($soft.Nom) : installeur absent ($src) : Logiciels$ incomplet."; continue }
            Copy-Item -LiteralPath $src -Destination $dst -Force
            if ((Get-FileHash -LiteralPath $dst).Hash -ne $soft.Sha256.ToUpper()) { throw "$($soft.Nom) : SHA256 inattendu après copie." }
        }
        Write-LabOK "Logiciels$\$($soft.DossierServeur)\$($soft.Fichier)"
    }
    Get-ChildItem -LiteralPath $root -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        if (-not $expected.ContainsKey($_.FullName.ToLower())) { Remove-Item -LiteralPath $_.FullName -Recurse -Force; Write-LabOK "Retiré : $($_.FullName)" }
    }
}

function Set-ABShare {
    <# Crée ou corrige un partage : chemin, puis accès = Utilisateurs authentifiés : Contrôle total. #>
    param($Partage)
    $auth = Get-ABSid -Name 'Utilisateurs authentifiés'
    $share = Get-SmbShare -Name $Partage.Nom -ErrorAction SilentlyContinue
    if ($share -and $share.Path.TrimEnd('\') -ne $Partage.Dossier.TrimEnd('\')) {
        Remove-SmbShare -Name $Partage.Nom -Force
        $share = $null
    }
    if (-not $share) {
        New-SmbShare -Name $Partage.Nom -Path $Partage.Dossier -FullAccess $auth.Translate([Security.Principal.NTAccount]).Value | Out-Null
    }
    $expected = @("$($auth.Value)|Full|Allow")
    if ((@(Get-ABShareAccess -Name $Partage.Nom) -join ',') -ne ($expected -join ',')) {
        Set-ABShareAccess -Name $Partage.Nom -Entries @([pscustomobject]@{ Sid = $auth.Value; Right = 'Full'; Type = 'Allow' })
    }
    Write-LabOK "\\AB-SRV-01\$($Partage.Nom) -> $($Partage.Dossier)"
}

function Set-ABServerNetwork {
    <# IP fixe, profil Privé, règles « Partage de fichiers et d'imprimantes ». PowerShell Direct (VMBus) n'en dépend pas. #>
    param($Config)
    $ip = $Config.Reseau.Machines[$Machine]
    $adapters = @(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' })
    if ($adapters.Count -ne 1) { throw "Il faut exactement une carte réseau active (trouvé : $($adapters.Count))." }
    $idx = $adapters[0].ifIndex
    $current = Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $done = $current | Where-Object { $_.IPAddress -eq $ip -and $_.PrefixLength -eq $Config.Reseau.Prefixe -and $_.PrefixOrigin -eq 'Manual' }
    if (-not $done -or @($current).Count -ne 1) {
        Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled
        $current | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false
        New-NetIPAddress -InterfaceIndex $idx -IPAddress $ip -PrefixLength $Config.Reseau.Prefixe -DefaultGateway $Config.Reseau.Passerelle | Out-Null
        Write-LabOK "IP fixe $ip/$($Config.Reseau.Prefixe) sur $($adapters[0].Name)"
    } else {
        Write-LabOK "IP fixe $ip déjà en place."
    }
    Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $Config.Reseau.Dns
    # Le changement d'IP crée un nouveau réseau (« Identification... », puis « Réseau non
    # identifié » en VM, Public par défaut) : Windows refuse de le classer tant que
    # l'identification n'est pas terminée. On réessaie jusqu'à 2 minutes (vérifié en VM).
    $deadline = (Get-Date).AddSeconds(120)
    $done = $false
    while (-not $done) {
        try {
            $prof = Get-NetConnectionProfile -InterfaceIndex $idx -ErrorAction Stop
            if ($prof.NetworkCategory -ne 'Private') { Set-NetConnectionProfile -InterfaceIndex $idx -NetworkCategory Private -ErrorAction Stop }
            $done = $true
        } catch {
            if ((Get-Date) -gt $deadline) { throw "Profil réseau non classé Privé après 2 min : $($_.Exception.Message)" }
            Start-Sleep -Seconds 5
        }
    }
    # Règles des profils Privé (sous Windows 11, souvent communes à Privé et Public; celles du seul profil Domaine restent fermées)
    Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' | Where-Object { $_.Profile -match 'Private|Any' } | Enable-NetFirewallRule
    Write-LabOK 'Profil réseau Privé, partage de fichiers autorisé par le pare-feu.'
}

# ---------------------------------------------------------------------------
$null = Start-LabLog -Name 'Setup-SRV-01'
$exitCode = 0
try {
    Assert-LabComputer -Expected 'AB-SRV-01' -Force:$Force
    $state = Get-LabState -Scenario 'SRV-01'
    if ($state) { throw "Une panne est installée (variante $($state.Variante)). Lancer Retrait-SRV-01.ps1 d'abord." }
    $cfg = Get-ABConfig

    Write-LabStep 'Politique de mots de passe'
    Set-ABPasswordPolicy -Machine $Machine
    Write-LabOK (Test-ABPasswordPolicy -Machine $Machine).detail

    Write-LabStep 'Comptes'
    Set-ABAdminAccount
    Write-LabOK "$($cfg.Administrateur) : administrateur, mot de passe sans expiration (mot de passe inchangé)."
    foreach ($e in $cfg.Employes) { Set-ABEmployeeAccount -Employe $e; Write-LabOK "$($e.Compte) ($($e.NomComplet))" }

    Write-LabStep 'Groupes'
    foreach ($g in $cfg.Groupes.Keys | Sort-Object) {
        Set-ABGroupMembership -Group $g -Members $cfg.Groupes[$g]
        Write-LabOK "$g : $($cfg.Groupes[$g] -join ', ')"
    }

    Write-LabStep 'Dossiers et données'
    if (-not (Test-Path -LiteralPath 'C:\AB')) { New-Item -ItemType Directory -Path 'C:\AB' | Out-Null }
    Sync-ABShareContent -Config $cfg
    Sync-ABSoftwareShare -Config $cfg

    Write-LabStep 'NTFS'
    foreach ($p in $cfg.Partages) {
        Set-ABRootAcl -Partage $p
        Reset-ABChildAcl -Path $p.Dossier
        Write-LabOK "$($p.Dossier) : $(($p.Droits.Keys | ForEach-Object { "$_ $($p.Droits[$_])" }) -join ', ')"
    }

    Write-LabStep 'Partages'
    foreach ($p in $cfg.Partages) { Set-ABShare -Partage $p }

    Write-LabStep 'SMB'
    $smb = Get-SmbServerConfiguration
    if (-not $smb.RequireSecuritySignature) { Set-SmbServerConfiguration -RequireSecuritySignature $true -Force }
    if ($smb.EnableSMB1Protocol) { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force }
    Write-LabOK 'Signature exigée, SMB1 désactivé.'

    Write-LabStep 'Réseau'
    Set-ABServerNetwork -Config $cfg
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}

if ($exitCode -eq 0) {
    Write-LabStep 'Vérification'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verifier-SRV-01.ps1') -Attendu Propre
    $exitCode = $LASTEXITCODE
}
exit $exitCode
