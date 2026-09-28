#requires -version 5.1
<#
.SYNOPSIS
    Répétition de bout en bout pour UNE équipe, chronométrée (uniquement par Invoke-LabVM.ps1).

.DESCRIPTION
    SRV-01, PC-03 et PC-01 : Setup, Panne (-Variante), Verifier (panne détectée), Retrait,
    Verifier (propre). Accès d'Émilie à P:\2026-021 vérifié depuis PC-03 en panne et après.
    La RAM de l'hôte ne permet que deux VM : les postes passent l'un après l'autre à côté
    du serveur. Temps séparés : préparation des VM (Reset, copie : n'existe pas en classe)
    et scripts (ce que fait l'enseignant entre deux équipes).

.EXAMPLE
    .\tests\Test-ABEquipe.ps1 -Variante A
#>
[CmdletBinding()]
param([ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante = 'A')

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $PSScriptRoot "logs\Test-ABEquipe-$Stamp"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$cfg = Import-PowerShellDataFile (Join-Path $Repo 'AB\AB-Config.psd1')
$rows = New-Object System.Collections.Generic.List[object]
$total = [Diagnostics.Stopwatch]::StartNew()

function Invoke-TimedStep {
    <# Lance un script dans une VM, chronomètre, garde la sortie; retourne { Code; Secondes; Json; Detail }. #>
    param([string]$Machine, [string]$Etape, [string]$Script, [string[]]$Arguments = @(), [int]$CodeAttendu = 0)
    $vm = "AB-$Machine-T"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & $Inv -VMName $vm -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    $code = $LASTEXITCODE; $sw.Stop()
    $out | Set-Content -Path (Join-Path $LogDir "$Machine-$Etape.log") -Encoding UTF8
    $json = $out | Where-Object { $_ -like '{*' } | Select-Object -Last 1
    $detail = ''
    if ($json) { $j = $json | ConvertFrom-Json; if ($null -ne $j.echecs) { $detail = "échecs : $(@($j.echecs) -join ', ')" } elseif ($j.detail) { $detail = $j.detail } }
    $ok = ($code -eq $CodeAttendu)
    $rows.Add([pscustomobject]@{ Machine = $Machine; Etape = $Etape; Secondes = [int]$sw.Elapsed.TotalSeconds; Resultat = $(if ($ok) { 'OK' } else { "ÉCHEC ($code)" }); Detail = $detail })
    Write-Host ("{0,-7} {1,-22} {2,5} s  {3}  {4}" -f $Machine, $Etape, [int]$sw.Elapsed.TotalSeconds, $(if ($ok) { 'OK' } else { "ÉCHEC ($code)" }), $detail)
    return [pscustomobject]@{ Code = $code; Json = $json }
}

function Test-Access([string]$Etape, [bool]$Attendu) {
    $r = Invoke-TimedStep -Machine 'PC-03' -Etape $Etape -Script 'C:\Lab\tests\ABAcces-Invite.ps1'
    $ok = $r.Json -and (($r.Json | ConvertFrom-Json).ok -eq $Attendu)
    $rows[$rows.Count - 1].Resultat = $(if ($ok) { 'OK' } else { 'ÉCHEC' })
}

function Initialize-TestVM([string]$Machine, [string[]]$Extra = @()) {
    <# Préparation VM (hors chronométrage de l'enseignant) : Reset, copie, IP de test. #>
    $vm = "AB-$Machine-T"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $Inv -VMName $vm -Action Reset | Out-Null
    & $Inv -VMName $vm -Action Push -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB') | Out-Null
    & $Inv -VMName $vm -Action Push -Path (@(Join-Path $PSScriptRoot 'Set-ABVMReseau.ps1') + $Extra) -Destination 'C:\Lab\tests' | Out-Null
    if ($Machine -eq 'SRV-01') {
        $lo = ($cfg.Logiciels | Where-Object { $_['DossierServeur'] }).Fichier
        & $Inv -VMName $vm -Action Push -Path (Join-Path $Repo "tools\installeurs\$lo") -Destination 'C:\Lab\tools\installeurs' | Out-Null
    } else {
        & $Inv -VMName $vm -Action Run -ScriptPath 'C:\Lab\tests\Set-ABVMReseau.ps1' -ArgumentList '-Poste', $Machine 6>$null | Out-Null
    }
    $sw.Stop()
    $rows.Add([pscustomobject]@{ Machine = $Machine; Etape = 'Préparation VM'; Secondes = [int]$sw.Elapsed.TotalSeconds; Resultat = 'OK'; Detail = 'Reset, copie, IP de test (pas en classe)' })
    Write-Host ("{0,-7} {1,-22} {2,5} s" -f $Machine, 'Préparation VM', [int]$sw.Elapsed.TotalSeconds)
}

function Invoke-MachineCycle([string]$Machine, [switch]$Acces, [switch]$GarderPanne) {
    $d = "C:\Lab\AB\$Machine"
    $null = Invoke-TimedStep $Machine 'Setup' "$d\Setup-$Machine.ps1"
    $null = Invoke-TimedStep $Machine 'Panne' "$d\Panne-$Machine.ps1" @('-Variante', $Variante)
    $null = Invoke-TimedStep $Machine 'Verifier (panne)' "$d\Verifier-$Machine.ps1" @('-Attendu', 'Panne', '-Variante', $Variante)
    if ($Acces) { Test-Access 'Accès Émilie (panne)' $false }
}

function Invoke-MachineRemoval([string]$Machine) {
    $d = "C:\Lab\AB\$Machine"
    $null = Invoke-TimedStep $Machine 'Retrait' "$d\Retrait-$Machine.ps1"
    $null = Invoke-TimedStep $Machine 'Verifier (propre)' "$d\Verifier-$Machine.ps1" @('-Attendu', 'Propre')
}

# Deux VM à la fois au plus (RAM de l'hôte) : les postes AB encore démarrés sont arrêtés
foreach ($pc in 'PC-01', 'PC-02', 'PC-03', 'PC-04') {
    if ((Get-VM -Name "AB-$pc-T" -ErrorAction SilentlyContinue).State -eq 'Running') { & $Inv -VMName "AB-$pc-T" -Action Stop | Out-Null; Write-Host "AB-$pc-T arrêtée (RAM)." }
}

Write-Host "########## Équipe $Variante : SRV-01 + PC-03" -ForegroundColor Cyan
Initialize-TestVM 'SRV-01'
Invoke-MachineCycle 'SRV-01'
Initialize-TestVM 'PC-03' @(Join-Path $PSScriptRoot 'ABAcces-Invite.ps1')
Invoke-MachineCycle 'PC-03' -Acces
Invoke-MachineRemoval 'PC-03'
Invoke-MachineRemoval 'SRV-01'
Test-Access 'Accès Émilie (propre)' $true
& $Inv -VMName 'AB-PC-03-T' -Action Stop | Out-Null

Write-Host "########## Équipe $Variante : PC-01" -ForegroundColor Cyan
Initialize-TestVM 'PC-01'
Invoke-MachineCycle 'PC-01'
Invoke-MachineRemoval 'PC-01'
& $Inv -VMName 'AB-PC-01-T' -Action Stop | Out-Null
$total.Stop()

# --- Résultats ------------------------------------------------------------------
$md = @("# Test de bout en bout : équipe $Variante ($Stamp)", '', '| Machine | Étape | Durée (s) | Résultat | Détail |', '| --- | --- | ---: | --- | --- |')
foreach ($r in $rows) { $md += "| $($r.Machine) | $($r.Etape) | $($r.Secondes) | $($r.Resultat) | $($r.Detail) |" }
$md += '', '## Remise à zéro entre deux équipes (Retrait, puis Setup, puis Panne), par machine', '', '| Machine | Retrait | Setup | Panne | Total | Avec les deux Verifier |', '| --- | ---: | ---: | ---: | ---: | ---: |'
foreach ($m in 'SRV-01', 'PC-03', 'PC-01') {
    $get = { param($e) ($rows | Where-Object { $_.Machine -eq $m -and $_.Etape -eq $e } | Select-Object -First 1).Secondes }
    $ret = & $get 'Retrait'; $set = & $get 'Setup'; $pan = & $get 'Panne'; $v1 = & $get 'Verifier (panne)'; $v2 = & $get 'Verifier (propre)'
    $md += "| $m | $ret | $set | $pan | $($ret + $set + $pan) | $($ret + $set + $pan + $v1 + $v2) |"
}
$md += '', "Durée totale de la répétition (VM comprises) : $([int]$total.Elapsed.TotalMinutes) min $($total.Elapsed.Seconds) s."
$md | Set-Content -Path (Join-Path $LogDir 'resultats.md') -Encoding UTF8
$md | ForEach-Object { Write-Host $_ }
Write-Host "Journaux : $LogDir"
if ($rows | Where-Object { $_.Resultat -ne 'OK' }) { exit 1 }
exit 0
