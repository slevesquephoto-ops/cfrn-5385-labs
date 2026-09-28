#requires -version 5.1
<#
.SYNOPSIS
    Exécuté DANS AB-PC-03-T : « Émilie ouvre P:\2026-021 » avec un PSCredential d'efortin (spec R1).

.DESCRIPTION
    Lecteur temporaire vers \\AB-SRV-01\Projets avec l'identité d'efortin, liste du dossier
    du projet et lecture d'un fichier, puis déconnexion. Lecture seule : aucune trace dans
    les partages. Écrit une ligne JSON { ok; detail }.
#>
[CmdletBinding()]
param([string]$Compte = 'efortin')

$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
$cfg = Get-ABConfig
$emp = $cfg.Employes | Where-Object { $_.Compte -eq $Compte }
$share = "\\$($cfg.Reseau.Serveur)\Projets"
$cred = New-Object PSCredential("$($cfg.Reseau.Serveur)\$Compte", (ConvertTo-SecureString $emp.MotDePasse -AsPlainText -Force))
$result = [ordered]@{ ok = $false; detail = '' }
try {
    New-PSDrive -Name ABACCES -PSProvider FileSystem -Root $share -Credential $cred -ErrorAction Stop | Out-Null
    $dir = Join-Path 'ABACCES:\' $cfg.Pannes.R1.DossierProjet
    $files = @(Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction Stop)
    if (-not $files) { throw "aucun fichier dans $dir" }
    $bytes = [IO.File]::ReadAllBytes((Convert-Path -LiteralPath $files[0].PSPath)).Length
    $result.ok = $true
    $result.detail = "$($files.Count) fichiers visibles, $($files[0].Name) lu ($bytes octets)"
} catch {
    $result.detail = $_.Exception.Message
} finally {
    Remove-PSDrive -Name ABACCES -ErrorAction SilentlyContinue
}
[pscustomobject]$result | ConvertTo-Json -Compress | Write-Output
