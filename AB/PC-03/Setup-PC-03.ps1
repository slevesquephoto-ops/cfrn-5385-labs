#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-03 : poste d'Émilie Fortin (efortin), architecte de projets (état propre).

.DESCRIPTION
    Base commune (Initialize-ABPoste) : politique de mots de passe, ab-tech sans expiration,
    stratégies de première ouverture et de LibreOffice, logiciels vérifiés, fond d'écran AB,
    profil d'efortin RECRÉÉ à neuf (lecteurs P: R: S:, données, raccourcis).
    Propre au poste : fichier hosts sans entrée pour le serveur (R1 couche 1).
    Refuse de s'exécuter si une panne est installée (lancer Retrait-PC-03.ps1 d'abord).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-03'
$null = Start-LabLog -Name "Setup-$Machine"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $state = Get-LabState -Scenario $Machine
    if ($state) { throw "Une panne est installée (variante $($state.Variante)). Lancer Retrait-$Machine.ps1 d'abord." }
    $server = (Get-ABConfig).Reseau.Serveur

    Write-LabStep 'Fichier hosts'
    $hostsFile = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $lines = @(Get-Content -LiteralPath $hostsFile)
    $clean = @($lines | Where-Object { $_ -notmatch [regex]::Escape($server) })
    if ($clean.Count -ne $lines.Count) {
        Set-Content -LiteralPath $hostsFile -Value $clean -Encoding ASCII
        & ipconfig.exe /flushdns | Out-Null
        Write-LabOK "Entrées pour $server retirées."
    } else { Write-LabOK "Aucune entrée pour $server." }

    $shortcuts = @(@{ Nom = 'Projets (P)'; Cible = 'P:\' })
    $lo = Find-ABProgram 'soffice.exe'; if ($lo) { $shortcuts += @{ Nom = 'LibreOffice'; Cible = $lo } }
    $cad = Find-ABProgram 'LibreCAD.exe'; if ($cad) { $shortcuts += @{ Nom = 'LibreCAD'; Cible = $cad } }
    $null = Initialize-ABPoste -Machine $Machine -Compte 'efortin' -Raccourcis $shortcuts
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}

if ($exitCode -eq 0) {
    Write-LabStep 'Vérification'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Verifier-$Machine.ps1") -Attendu Propre
    $exitCode = $LASTEXITCODE
}
exit $exitCode
