#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-01 : poste de Nathalie Côté (ncote), adjointe administrative (état propre).

.DESCRIPTION
    Base commune (Initialize-ABPoste) : politique de mots de passe, ab-tech sans expiration,
    stratégies, logiciels vérifiés, fond d'écran AB, profil de ncote RECRÉÉ à neuf
    (lecteurs S: et T:, données, raccourcis).
    Propre au poste (R6) : police Montserrat du modèle de facture installée pour tous les
    utilisateurs, fonction « Microsoft Print to PDF » activée.
    Refuse de s'exécuter si une panne est installée (lancer Retrait-PC-01.ps1 d'abord).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-01'
$null = Start-LabLog -Name "Setup-$Machine"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $state = Get-LabState -Scenario $Machine
    if ($state) { throw "Une panne est installée (variante $($state.Variante)). Lancer Retrait-$Machine.ps1 d'abord." }

    Write-LabStep 'Police du modèle de facture (Montserrat)'
    Install-ABFont -Famille 'Montserrat'
    Write-LabOK 'Montserrat installée pour tous les utilisateurs.'

    Write-LabStep 'Impression en PDF'
    $f = Get-WindowsOptionalFeature -Online -FeatureName 'Printing-PrintToPDFServices-Features'
    if ($f.State -ne 'Enabled') { Enable-WindowsOptionalFeature -Online -FeatureName 'Printing-PrintToPDFServices-Features' -NoRestart | Out-Null }
    Write-LabOK 'Microsoft Print to PDF activée.'

    $shortcuts = @(@{ Nom = 'Facturation (T)'; Cible = 'T:\Facturation' }, @{ Nom = 'Commun (S)'; Cible = 'S:\' })
    $lo = Find-ABProgram 'soffice.exe'; if ($lo) { $shortcuts += @{ Nom = 'LibreOffice'; Cible = $lo } }
    $null = Initialize-ABPoste -Machine $Machine -Compte 'ncote' -Raccourcis $shortcuts
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
