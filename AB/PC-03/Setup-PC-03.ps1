#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-03 : poste d'Émilie Fortin (efortin), architecte de projets (état propre).

.DESCRIPTION
    Politique de mots de passe, ab-tech sans expiration, stratégies de première ouverture
    et de LibreOffice, logiciels vérifiés (installés avant Propre par tools\Set-ABPoste.ps1),
    fichier hosts sans entrée pour le serveur, puis profil d'efortin RECRÉÉ à neuf par le
    moteur commun (Initialize-ABEmployeeProfile) : fond d'écran AB, lecteurs P: R: S:,
    données du manifeste, raccourcis. Aucune session à ouvrir à la main.
    Refuse de s'exécuter si une panne est installée (lancer Retrait-PC-03.ps1 d'abord).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-03'
$Compte = 'efortin'
$DataRoot = Join-Path $PSScriptRoot "..\data\$Compte"
$Manifest = Join-Path $DataRoot "manifeste-$Compte.csv"
$WallpaperSrc = Join-Path $PSScriptRoot '..\data\communs\fond-AB.png'
$Wallpaper = 'C:\Windows\Web\Wallpaper\AB\fond-AB.png'
$HostsFile = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

function Find-ABProgram([string]$Exe) {
    foreach ($root in $env:ProgramFiles, ${env:ProgramFiles(x86)}) {
        if (-not $root) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Filter $Exe -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$null = Start-LabLog -Name 'Setup-PC-03'
$exitCode = 0
try {
    Assert-LabComputer -Expected 'AB-PC-03' -Force:$Force
    $state = Get-LabState -Scenario $Machine
    if ($state) { throw "Une panne est installée (variante $($state.Variante)). Lancer Retrait-PC-03.ps1 d'abord." }
    $cfg = Get-ABConfig
    $emp = $cfg.Employes | Where-Object { $_.Compte -eq $Compte }

    Write-LabStep 'Politique de mots de passe et comptes'
    Set-ABPasswordPolicy -Machine $Machine
    Set-ABAdminAccount
    Write-LabOK "$((Test-ABPasswordPolicy -Machine $Machine).detail); $($cfg.Administrateur) sans expiration."

    Write-LabStep 'Stratégies du poste (première ouverture, LibreOffice)'
    Set-ABMachinePolicy
    Write-LabOK 'Sans animation ni questions de confidentialité; LibreOffice sans conseils ni « Quoi de neuf ».'

    Write-LabStep 'Logiciels'
    foreach ($s in Get-ABSoftwareList -Poste $Machine) {
        $found = Test-ABSoftware -Logiciel $s
        if (-not $found) { throw "$($s.Nom) absent : lancer tools\Set-ABPoste.ps1 -Poste $Machine avant le point Propre." }
        Write-LabOK "$($found.DisplayName) $($found.Version)"
    }

    Write-LabStep 'Fichier hosts'
    $lines = @(Get-Content -LiteralPath $HostsFile)
    $clean = @($lines | Where-Object { $_ -notmatch [regex]::Escape($cfg.Reseau.Serveur) })
    if ($clean.Count -ne $lines.Count) {
        Set-Content -LiteralPath $HostsFile -Value $clean -Encoding ASCII
        Write-LabOK "Entrées pour $($cfg.Reseau.Serveur) retirées."
    } else { Write-LabOK "Aucune entrée pour $($cfg.Reseau.Serveur)." }

    Write-LabStep 'Fond d''écran AB'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Wallpaper) | Out-Null
    Copy-Item -LiteralPath $WallpaperSrc -Destination $Wallpaper -Force
    Write-LabOK $Wallpaper

    Write-LabStep "Profil de $($emp.NomComplet) ($Compte)"
    $shortcuts = @(@{ Nom = 'Projets (P)'; Cible = 'P:\' })
    $lo = Find-ABProgram 'soffice.exe'
    if ($lo) { $shortcuts += @{ Nom = 'LibreOffice'; Cible = $lo } }
    $cad = Find-ABProgram 'LibreCAD.exe'
    if ($cad) { $shortcuts += @{ Nom = 'LibreCAD'; Cible = $cad } }
    $path = Initialize-ABEmployeeProfile -Employe $emp -Wallpaper $Wallpaper -DataRoot $DataRoot -Manifest $Manifest -Raccourcis $shortcuts
    Write-LabOK "Profil prêt : $path"
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}

if ($exitCode -eq 0) {
    Write-LabStep 'Vérification'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verifier-PC-03.ps1') -Attendu Propre
    $exitCode = $LASTEXITCODE
}
exit $exitCode
