#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-04 : poste de Jérémie Bouchard (jbouchard), technicien en architecture (état propre).

.DESCRIPTION
    Base commune (Initialize-ABPoste) : politique de mots de passe, ab-tech sans expiration,
    stratégies, logiciels vérifiés (dont LibreCAD, FreeCAD, Blender), fond d'écran AB,
    profil de jbouchard RECRÉÉ à neuf (lecteurs, données de dessin, raccourcis).
    Aucune panne installée par script : R2 est physique (préparée à la main).
    Refuse de s'exécuter si une panne logicielle est marquée (lancer Retrait-PC-04.ps1).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-04'
$null = Start-LabLog -Name "Setup-$Machine"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force

    $shortcuts = @(@{ Nom = 'Projets (P)'; Cible = 'P:\' })
    foreach ($p in @('LibreCAD.exe', 'FreeCAD.exe', 'soffice.exe')) {
        $exe = Find-ABProgram $p
        if ($exe) { $shortcuts += @{ Nom = [IO.Path]::GetFileNameWithoutExtension($p); Cible = $exe } }
    }
    $null = Initialize-ABPoste -Machine $Machine -Compte 'jbouchard' -Raccourcis $shortcuts
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
