#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-02 : poste de Louis-Philippe Gauthier (lpgauthier), architecte associé (état propre).

.DESCRIPTION
    Base commune (Initialize-ABPoste) : politique de mots de passe, ab-tech sans expiration,
    stratégies, logiciels vérifiés, fond d'écran AB, profil de lpgauthier RECRÉÉ à neuf
    (lecteurs, données, raccourcis). Ses données incluent les pièges de R3 : fichiers dans
    Bureau, Documents et Téléchargements, le dossier hors profil C:\Soumissions-LP et les
    favoris Edge.
    Refuse de s'exécuter si une panne est installée (lancer Retrait-PC-02.ps1 d'abord).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-02'
$null = Start-LabLog -Name "Setup-$Machine"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $state = Get-LabState -Scenario $Machine
    if ($state) { throw "Une panne est installée (variante $($state.Variante)). Lancer Retrait-$Machine.ps1 d'abord." }

    $shortcuts = @(@{ Nom = 'Soumissions'; Cible = 'C:\Soumissions-LP' }, @{ Nom = 'Direction (P)'; Cible = 'P:\' })
    $lo = Find-ABProgram 'soffice.exe'; if ($lo) { $shortcuts += @{ Nom = 'LibreOffice'; Cible = $lo } }
    $null = Initialize-ABPoste -Machine $Machine -Compte 'lpgauthier' -Raccourcis $shortcuts
    Write-LabOK 'Données de R3 en place (Bureau, Documents, Téléchargements, C:\Soumissions-LP, favoris Edge).'
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
