#requires -version 5.1
<#
.SYNOPSIS
    Teste la console Menu-AB.ps1 dans les VM de test (uniquement par Invoke-LabVM.ps1).

.DESCRIPTION
    Le dépôt est copié dans C:\CFRN-LAB(prof) (parenthèses comprises, comme sur les vrais
    postes). Chaque option du menu est lancée par -Action et son code de sortie est comparé
    au code attendu; le menu interactif est aussi piloté au clavier simulé sur PC-03.
    Deux VM à la fois au plus (RAM de l'hôte) : SRV-01 + PC-03, SRV-01 + PC-02, PC-01, PC-04.
    Résultats : tableau à l'écran et tests\logs\Test-MenuAB-<date>\resultats.md.

.EXAMPLE
    .\tests\Test-MenuAB.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$Dest = 'C:\CFRN-LAB(prof)'
$Menu = "$Dest\Menu-AB.ps1"
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $PSScriptRoot "logs\Test-MenuAB-$Stamp"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$cfg = Import-PowerShellDataFile (Join-Path $Repo 'AB\AB-Config.psd1')
$rows = New-Object System.Collections.Generic.List[object]

function Invoke-MenuStep {
    <# Lance une option du menu dans la VM; compare le code au code attendu; garde la sortie. #>
    param([string]$Machine, [string]$Etape, [string[]]$Arguments, [int]$CodeAttendu = 0, [string[]]$Contient = @())
    $out = & $Inv -VMName "AB-$Machine-T" -Action Run -ScriptPath $Menu -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    Save-StepOutput $Machine $Etape $out $code $CodeAttendu $Contient
}

function Invoke-GuestStep {
    param([string]$Machine, [string]$Etape, [string]$Script, [string[]]$Arguments = @(), [int]$CodeAttendu = 0, [string[]]$Contient = @())
    $out = & $Inv -VMName "AB-$Machine-T" -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    if ($Script -like '*MenuInteractif*') {
        $line = $out | Where-Object { $_ -like 'CODE=*' } | Select-Object -Last 1
        if ($line) { $code = [int]$line.Substring(5) }
    }
    Save-StepOutput $Machine $Etape $out $code $CodeAttendu $Contient
}

function Save-StepOutput($Machine, $Etape, $Out, $Code, $CodeAttendu, $Contient) {
    $file = Join-Path $LogDir ("{0}-{1:D2}-{2}.log" -f $Machine, $rows.Count, ($Etape -replace '[^\w-]', '_'))
    $Out | Set-Content -Path $file -Encoding UTF8
    $manque = @($Contient | Where-Object { -not ($Out -match [regex]::Escape($_)) })
    $ok = ($Code -eq $CodeAttendu) -and -not $manque
    $detail = ''
    if ($manque) { $detail = "texte absent : $($manque -join ' / ')" }
    $res = 'OK'; if (-not $ok) { $res = "ÉCHEC (code $Code)" }
    $rows.Add([pscustomobject]@{ Machine = $Machine; Etape = $Etape; Attendu = $CodeAttendu; Obtenu = $Code; Resultat = $res; Detail = $detail })
    $color = 'Green'; if (-not $ok) { $color = 'Red' }
    Write-Host ("{0,-7} {1,-48} attendu {2} obtenu {3}  {4} {5}" -f $Machine, $Etape, $CodeAttendu, $Code, $res, $detail) -ForegroundColor $color
}

function Initialize-MenuVM([string]$Machine) {
    $vm = "AB-$Machine-T"
    & $Inv -VMName $vm -Action Reset | Out-Null
    & $Inv -VMName $vm -Action Push -Destination $Dest -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB'), (Join-Path $Repo 'Menu-AB.ps1'), (Join-Path $Repo 'GUIDE-ENSEIGNANT.md') | Out-Null
    & $Inv -VMName $vm -Action Push -Destination "$Dest\tools" -Path (Join-Path $Repo 'tools\Set-ABPoste.ps1'), (Join-Path $Repo 'tools\Install-ABSoftware.ps1') | Out-Null
    & $Inv -VMName $vm -Action Push -Destination "$Dest\tests" -Path (Join-Path $PSScriptRoot 'Set-ABVMReseau.ps1'), (Join-Path $PSScriptRoot 'MenuInteractif-Invite.ps1'), (Join-Path $PSScriptRoot 'ABBackup-Invite.ps1') | Out-Null
    if ($Machine -eq 'SRV-01') {
        $lo = ($cfg.Logiciels | Where-Object { $_['DossierServeur'] }).Fichier
        & $Inv -VMName $vm -Action Push -Destination "$Dest\tools\installeurs" -Path (Join-Path $Repo "tools\installeurs\$lo") | Out-Null
    } else {
        & $Inv -VMName $vm -Action Run -ScriptPath "$Dest\tests\Set-ABVMReseau.ps1" -ArgumentList '-Poste', $Machine 6>$null | Out-Null
    }
    Write-Host "$vm prête ($Dest)." -ForegroundColor Cyan
}

function Stop-MenuVM([string]$Machine) { & $Inv -VMName "AB-$Machine-T" -Action Stop | Out-Null }

foreach ($pc in 'PC-01', 'PC-02', 'PC-03', 'PC-04') {
    if ((Get-VM -Name "AB-$pc-T" -ErrorAction SilentlyContinue).State -eq 'Running') { Stop-MenuVM $pc }
}

# Bloc 1 : SRV-01 (panne B, qui comprend R6-B) + PC-03
Initialize-MenuVM 'SRV-01'
Invoke-MenuStep 'SRV-01' 'Tout vérifier avant Setup (non conforme)' @('-Action', 'ToutVerifier') 1 @('RÉSULTAT : NON CONFORME')
Invoke-MenuStep 'SRV-01' 'Installer (verrou Windows)' @('-Action', 'Installer')
Invoke-MenuStep 'SRV-01' 'Setup' @('-Action', 'Setup')
Invoke-MenuStep 'SRV-01' 'Tout vérifier (propre)' @('-Action', 'ToutVerifier') 0 @('est propre')
Invoke-MenuStep 'SRV-01' 'Panne B' @('-Action', 'Panne', '-Variante', 'B')
Invoke-MenuStep 'SRV-01' 'Panne B relancée (idempotence)' @('-Action', 'Panne', '-Variante', 'B')
Invoke-MenuStep 'SRV-01' 'Tout vérifier (équipe B)' @('-Action', 'ToutVerifier', '-Variante', 'B') 0 @('prêt pour l''équipe (variante B)', '[PANNE]')
Invoke-MenuStep 'SRV-01' 'Vérifier Panne B' @('-Action', 'VerifierPanne', '-Variante', 'B')
Invoke-MenuStep 'SRV-01' 'Tout vérifier (équipe C, panne B : écart)' @('-Action', 'ToutVerifier', '-Variante', 'C') 1 @('pas celle de l''équipe (C)')
Invoke-MenuStep 'SRV-01' 'Setup refusé pendant la panne' @('-Action', 'Setup') 1

Initialize-MenuVM 'PC-03'
Invoke-MenuStep 'PC-03' 'Installer sans installeurs (refus)' @('-Action', 'Installer') 1 @('Aucun installeur')
Invoke-MenuStep 'PC-03' 'Setup' @('-Action', 'Setup') 0 @('Contrôles (attendu : Propre)')
Invoke-MenuStep 'PC-03' 'Panne B' @('-Action', 'Panne', '-Variante', 'B')
Invoke-MenuStep 'PC-03' 'Tout vérifier (équipe B)' @('-Action', 'ToutVerifier', '-Variante', 'B') 0 @('prêt pour l''équipe (variante B)')
Invoke-MenuStep 'PC-03' 'Vérifier Propre en panne (non conforme)' @('-Action', 'VerifierPropre') 1 @('[ÉCHEC]', 'NON CONFORME')
# Clavier simulé : 5 (tout vérifier), V -> C (changer), 5 (écart signalé), X (choix invalide), 0 (quitter)
Invoke-GuestStep 'PC-03' 'Menu interactif (5, V, 5, X, 0)' "$Dest\tests\MenuInteractif-Invite.ps1" @('-Saisies', '5||V|C|5||X|0') 0 @('Console enseignant', 'Variante de l''équipe', 'prêt pour l''équipe (variante B)', 'pas celle de l''équipe (C)')
Invoke-MenuStep 'PC-03' 'Retrait' @('-Action', 'Retrait')
Invoke-MenuStep 'PC-03' 'Retrait relancé (rien à retirer)' @('-Action', 'Retrait') 0 @('rien à retirer')
Invoke-MenuStep 'PC-03' 'Tout vérifier (propre)' @('-Action', 'ToutVerifier') 0 @('est propre')
Stop-MenuVM 'PC-03'

Invoke-MenuStep 'SRV-01' 'Retrait' @('-Action', 'Retrait')
Invoke-MenuStep 'SRV-01' 'Tout vérifier équipe B après retrait (écart)' @('-Action', 'ToutVerifier', '-Variante', 'B') 1 @('n''est pas installée')
Invoke-MenuStep 'SRV-01' 'Vérifier Propre' @('-Action', 'VerifierPropre')

# Bloc 2 : SRV-01 (propre) + PC-02 (R4, R3)
Initialize-MenuVM 'PC-02'
Invoke-MenuStep 'PC-02' 'Setup' @('-Action', 'Setup')
Invoke-MenuStep 'PC-02' 'Panne A' @('-Action', 'Panne', '-Variante', 'A')
Invoke-MenuStep 'PC-02' 'Tout vérifier (équipe A)' @('-Action', 'ToutVerifier', '-Variante', 'A') 0 @('prêt pour l''équipe (variante A)')
Invoke-MenuStep 'PC-02' 'Vérifier R3 sans sauvegarde' @('-Action', 'VerifierR3') 1 @('INCOMPLÈTE')
Invoke-GuestStep 'PC-02' 'Sauvegarde R3 (simule les élèves)' "$Dest\tests\ABBackup-Invite.ps1"
Invoke-MenuStep 'PC-02' 'Vérifier R3 après sauvegarde' @('-Action', 'VerifierR3') 0 @('COMPLÈTE')
Invoke-MenuStep 'PC-02' 'Retrait' @('-Action', 'Retrait')
Invoke-MenuStep 'PC-02' 'Tout vérifier (propre)' @('-Action', 'ToutVerifier') 0 @('est propre')
Stop-MenuVM 'PC-02'
Stop-MenuVM 'SRV-01'

# Bloc 3 : PC-01 (R5 optionnelle, R6)
Initialize-MenuVM 'PC-01'
Invoke-MenuStep 'PC-01' 'Setup' @('-Action', 'Setup')
Invoke-MenuStep 'PC-01' 'Panne A sans R5' @('-Action', 'Panne', '-Variante', 'A', '-SansR5')
Invoke-MenuStep 'PC-01' 'Tout vérifier (A, sans R5)' @('-Action', 'ToutVerifier', '-Variante', 'A') 0 @('sans R5', 'prêt pour l''équipe (variante A)')
Invoke-MenuStep 'PC-01' 'Retrait' @('-Action', 'Retrait')
Invoke-MenuStep 'PC-01' 'Panne D avec R5' @('-Action', 'Panne', '-Variante', 'D')
Invoke-MenuStep 'PC-01' 'Tout vérifier (D, avec R5)' @('-Action', 'ToutVerifier', '-Variante', 'D') 0 @('avec R5', 'prêt pour l''équipe (variante D)')
Invoke-MenuStep 'PC-01' 'Retrait' @('-Action', 'Retrait')
Invoke-MenuStep 'PC-01' 'Tout vérifier (propre)' @('-Action', 'ToutVerifier') 0 @('est propre')
Stop-MenuVM 'PC-01'

# Bloc 4 : PC-04 (R2 physique : rappels tirés du guide)
Initialize-MenuVM 'PC-04'
Invoke-MenuStep 'PC-04' 'Setup' @('-Action', 'Setup')
Invoke-MenuStep 'PC-04' 'Rappel R2 variante E' @('-Action', 'Panne', '-Variante', 'E') 0 @('mauvaise entrée')
Invoke-MenuStep 'PC-04' 'Rappel remise en état R2 variante A' @('-Action', 'Retrait', '-Variante', 'A') 0 @('Rebrancher le câble de données')
Invoke-MenuStep 'PC-04' 'Tout vérifier (équipe E)' @('-Action', 'ToutVerifier', '-Variante', 'E') 0 @('R2 est physique', 'est propre')
Stop-MenuVM 'PC-04'

# --- Résultats ------------------------------------------------------------------
$md = @("# Test de la console Menu-AB.ps1 ($Stamp)", '', "Dépôt copié dans ``$Dest`` sur chaque VM.", '', '| Machine | Étape | Code attendu | Code obtenu | Résultat | Détail |', '| --- | --- | ---: | ---: | --- | --- |')
foreach ($r in $rows) { $md += "| $($r.Machine) | $($r.Etape) | $($r.Attendu) | $($r.Obtenu) | $($r.Resultat) | $($r.Detail) |" }
$nbKo = @($rows | Where-Object { $_.Resultat -ne 'OK' }).Count
$md += '', "$($rows.Count) étapes, $nbKo en échec."
$md | Set-Content -Path (Join-Path $LogDir 'resultats.md') -Encoding UTF8
Write-Host ''
$md | ForEach-Object { Write-Host $_ }
