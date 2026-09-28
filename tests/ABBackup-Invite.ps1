#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exécuté DANS AB-PC-02-T (en tant qu'ab-tech) : simule la sauvegarde R3 que fait
    Louis-Philippe, pour tester Verifier-PC-02 -R3.

.DESCRIPTION
    Copie vers \\AB-SRV-01\Sauvegardes$\lpgauthier\<AAAA-MM-JJ> les fichiers du manifeste de
    lpgauthier (par défaut ceux « Critique »). -SansFavoris omet les favoris Edge, pour
    montrer que le Verifier -R3 détecte le piège oublié.
#>
[CmdletBinding()]
param([switch]$SansFavoris)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
$cfg = Get-ABConfig
$compte = $cfg.Pannes.R3.Compte
$prof = (Get-CimInstance Win32_UserProfile -Filter "SID='$((Get-LocalUser -Name $compte).SID.Value)'").LocalPath
$manifest = Join-Path $root "AB\data\$compte\manifeste-$compte.csv"
$dest = "\\$($cfg.Reseau.Serveur)\$($cfg.Pannes.R3.Partage)\$compte\$(Get-Date -Format 'yyyy-MM-dd')"

$n = 0
foreach ($r in Import-Csv -LiteralPath $manifest -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Criticality -eq $cfg.Pannes.R3.Criticite }) {
    if ($SansFavoris -and $r.TargetRelative -match 'Edge') { continue }
    $src = Resolve-ABUserTarget -ProfilePath $prof -Target $r.TargetRelative
    if (-not (Test-Path -LiteralPath $src)) { Write-LabWarn "source absente : $src"; continue }
    # Cible absolue (C:\Soumissions-LP\...) -> relative, sinon Join-Path la refuse
    $rel = $r.TargetRelative -replace '^([A-Za-z]):\\', '$1\'
    $dst = Join-Path $dest $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $n++
}
Write-LabOK "$n fichiers Critique copiés vers $dest$(if ($SansFavoris) { ' (favoris Edge omis)' })."
