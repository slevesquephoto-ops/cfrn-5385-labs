#requires -version 5.1
<#
.SYNOPSIS
    À lancer par l'ENSEIGNANT, jamais par Claude Code.
    Enregistre les identifiants des VM et les clés ITFlow dans $HOME\.lab,
    chiffrés avec DPAPI (lisibles seulement par ton compte, sur ce PC).

.EXAMPLE
    .\tools\Setup-LabSecrets.ps1            # tout
    .\tools\Setup-LabSecrets.ps1 -Partie VM
    .\tools\Setup-LabSecrets.ps1 -Partie ITFlow
#>
[CmdletBinding()]
param([ValidateSet('Tout','VM','ITFlow')][string]$Partie = 'Tout')

$ErrorActionPreference = 'Stop'
$dir = Join-Path $HOME '.lab'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# Seul ton compte (et SYSTEM) peut lire le dossier
& icacls.exe $dir /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" | Out-Null

if ($Partie -in 'Tout','VM') {
    Write-Host "`n=== Identifiant des VM de test ===" -ForegroundColor Cyan
    Write-Host "Compte administrateur local DANS les VM (ex. ab-tech)."
    $cred = Get-Credential -UserName 'ab-tech' -Message 'Compte admin des VM de test'
    $cred | Export-Clixml (Join-Path $dir 'ab-tech.xml')
    Write-Host "[OK] $dir\ab-tech.xml"
    Write-Host "Si une VM a un autre mot de passe : Get-Credential | Export-Clixml $dir\<NomVM>.xml"
}

if ($Partie -in 'Tout','ITFlow') {
    Write-Host "`n=== ITFlow ===" -ForegroundColor Cyan
    $base = Read-Host "Adresse d'ITFlow (ex. http://192.168.137.20)"
    Write-Host "Clients que « Claude » ne doit JAMAIS voir (motifs, ex. Garage du Fleuve*)."
    $prot = Read-Host "Motifs séparés par des virgules [Garage du Fleuve*]"
    if (-not $prot) { $prot = 'Garage du Fleuve*' }
    $list = @($prot.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    [ordered]@{ BaseUrl = $base.TrimEnd('/'); ClientsProteges = $list } | ConvertTo-Json |
        Set-Content (Join-Path $dir 'itflow-config.json') -Encoding UTF8

    $k = Read-Host "Clé API de l'utilisateur ITFlow « Claude »" -AsSecureString
    New-Object pscredential ('claude', $k) | Export-Clixml (Join-Path $dir 'itflow-key.xml')
    Write-Host "[OK] Clé enregistrée dans $dir\itflow-key.xml"
    Write-Host "Test : Import-Module .\tools\ITFlow-AB.psm1 -Force; Connect-ITFlowAB"
}
