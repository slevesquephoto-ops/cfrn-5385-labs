#requires -version 5.1
<#
.SYNOPSIS
    Test dédié des pannes EICAR (SEC-EICAR-DEF et SEC-EICAR-TIERS) dans une VM PART-*-T,
    uniquement par Invoke-LabVM.ps1. Sonde le comportement réel de Microsoft Defender.

.DESCRIPTION
    Reset, copie, puis :
      - état de Defender (protection contre les falsifications, temps réel);
      - SEC-EICAR-DEF : installer -> Verifier panne -> la tâche et le générateur sont là,
        Defender a détecté la menace -> attendre, la tâche persiste -> retrait -> Verifier
        propre -> empreinte identique;
      - SEC-EICAR-TIERS : installer (exige la protection contre les falsifications désactivée)
        -> le fichier survit (dossier exclu) -> retrait -> l'exclusion est retirée.
    Résultats : tableau et tests\logs\Test-PartEicar-<date>\resultats.md.

.EXAMPLE
    .\tests\Test-PartEicar.ps1 -VMs PART-W11-T
#>
[CmdletBinding()]
param(
    [string[]]$VMs = @('PART-W11-T', 'PART-W10-T'),
    [string]$Client = 'mbelanger',
    [string]$Checkpoint = 'Propre',
    [switch]$Arreter
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $PSScriptRoot "logs\Test-PartEicar-$Stamp"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$ClientPs1 = 'C:\Lab\Particuliers\Client.ps1'
$Sonde = 'C:\Lab\tests\PartSonde-Invite.ps1'

function Invoke-Step {
    param([string]$VM, [string]$Label, [string]$Script, [string[]]$Arguments = @())
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $LogDir "$VM-$Label.log") -Encoding UTF8
    return [pscustomobject]@{ Code = $code; Output = $out }
}
function Invoke-Client([string]$VM, [string]$Label, [string[]]$Arguments) { Invoke-Step $VM $Label $ClientPs1 (@('-Client', $Client) + $Arguments) }
function Invoke-Sonde([string]$VM, [string]$Label, [string]$Mode, [string]$Prefixe) {
    $r = Invoke-Step $VM $Label $Sonde @('-Mode', $Mode, '-Client', $Client)
    return @($r.Output | Where-Object { $_ -like "$Prefixe|*" })
}
function Get-Json($Output) {
    $line = $Output | Where-Object { $_ -like '{"machine"*' } | Select-Object -Last 1
    if ($line) { return ($line | ConvertFrom-Json) }
    return $null
}
function Test-Verif([string]$VM, [string]$Label, [string[]]$Echecs) {
    $r = Invoke-Client $VM $Label @('-Verifier')
    $j = Get-Json $r.Output
    $vus = @(); if ($j) { $vus = @($j.echecs) }
    if ($r.Code -eq 0 -and (($vus | Sort-Object) -join ',') -eq ((@($Echecs) | Sort-Object) -join ',')) { return 'OK' }
    return "ÉCHEC (code $($r.Code), échecs : $($vus -join ', '))"
}
function Field([string[]]$Lines, [string]$Key) {
    $l = $Lines | Where-Object { $_ -like "DEF|$Key|*" } | Select-Object -First 1
    if ($l) { return ($l -split '\|')[2] }
    return $null
}
function Mark([bool]$Ok) { if ($Ok) { 'OK' } else { 'ÉCHEC' } }

$results = @()
foreach ($vm in $VMs) {
    Write-Host "`n########## $vm" -ForegroundColor Cyan
    & $Inv -VMName $vm -Action Reset -Checkpoint $Checkpoint | Out-Null
    & $Inv -VMName $vm -Action Push -Path (Join-Path $RepoRoot 'common'), (Join-Path $RepoRoot 'AB'), (Join-Path $RepoRoot 'Particuliers') | Out-Null
    & $Inv -VMName $vm -Action Push -Path (Join-Path $PSScriptRoot 'PartSonde-Invite.ps1') -Destination 'C:\Lab\tests' | Out-Null

    $d0 = Invoke-Sonde $vm 'defender-depart' 'Defender' 'DEF'
    $tamper = Field $d0 'tamper'
    $realtime = Field $d0 'realtime'
    Write-Host "    Defender : protection falsifications=$tamper, temps réel=$realtime"

    # --- SEC-EICAR-DEF : Defender actif ---
    Write-Host '--- SEC-EICAR-DEF' -ForegroundColor Cyan
    $row = [ordered]@{ VM = $vm; Panne = 'SEC-EICAR-DEF'; Tamper = $tamper }
    $e1 = Invoke-Sonde $vm 'def-emp1' 'Empreinte' 'EMP'
    $r = Invoke-Client $vm 'def-installer' @('-Panne', 'SEC-EICAR-DEF')
    $row.Installer = Mark ($r.Code -eq 0)
    $row.VerifPanne = Test-Verif $vm 'def-verif' @('SEC-EICAR-DEF')
    $d1 = Invoke-Sonde $vm 'def-sonde1' 'Defender' 'DEF'
    Start-Sleep -Seconds 25
    $d2 = Invoke-Sonde $vm 'def-sonde2' 'Defender' 'DEF'
    $row.Persistance = Mark ((Field $d2 'tache') -eq 'True' -and (Field $d2 'generateur') -eq 'True')
    $menace = ($d1 + $d2) | Where-Object { $_ -like 'DEF|threat|*' } | Select-Object -First 1
    $row.DefenderVoit = Mark ([bool]$menace)
    $r = Invoke-Client $vm 'def-retirer' @('-Panne', 'SEC-EICAR-DEF', '-Retirer')
    $row.Retrait = Mark ($r.Code -eq 0)
    $row.VerifPropre = Test-Verif $vm 'def-verif2' @()
    $e2 = Invoke-Sonde $vm 'def-emp2' 'Empreinte' 'EMP'
    $row.Empreinte = Mark ((($e1 | Sort-Object) -join "`n") -eq (($e2 | Sort-Object) -join "`n"))
    $results += [pscustomobject]$row
    ([pscustomobject]$row) | Format-List | Out-String | Write-Host

    # --- SEC-EICAR-TIERS : dossier exclu de Defender ---
    Write-Host '--- SEC-EICAR-TIERS' -ForegroundColor Cyan
    $row = [ordered]@{ VM = $vm; Panne = 'SEC-EICAR-TIERS'; Tamper = $tamper }
    $e1 = Invoke-Sonde $vm 'tiers-emp1' 'Empreinte' 'EMP'
    $r = Invoke-Client $vm 'tiers-installer' @('-Panne', 'SEC-EICAR-TIERS')
    if ($r.Code -ne 0 -and ($r.Output -match 'falsifications')) {
        $row.Installer = 'BLOQUÉ (protection falsifications)'
        $row.VerifPanne = 'n/a'; $row.FichierSurvit = 'n/a'; $row.Retrait = 'n/a'; $row.VerifPropre = 'n/a'; $row.Empreinte = 'n/a'
    } else {
        $row.Installer = Mark ($r.Code -eq 0)
        $row.VerifPanne = Test-Verif $vm 'tiers-verif' @('SEC-EICAR-TIERS')
        Start-Sleep -Seconds 25
        $d = Invoke-Sonde $vm 'tiers-sonde' 'Defender' 'DEF'
        $row.FichierSurvit = Mark ((Field $d 'drop') -eq 'True' -and (Field $d 'exclusion') -eq 'True')
        $r = Invoke-Client $vm 'tiers-retirer' @('-Panne', 'SEC-EICAR-TIERS', '-Retirer')
        $row.Retrait = Mark ($r.Code -eq 0)
        $row.VerifPropre = Test-Verif $vm 'tiers-verif2' @()
        $e2 = Invoke-Sonde $vm 'tiers-emp2' 'Empreinte' 'EMP'
        $row.Empreinte = Mark ((($e1 | Sort-Object) -join "`n") -eq (($e2 | Sort-Object) -join "`n"))
    }
    $results += [pscustomobject]$row
    ([pscustomobject]$row) | Format-List | Out-String | Write-Host
    if ($Arreter) { & $Inv -VMName $vm -Action Stop | Out-Null }
}

$results | Format-Table -AutoSize -Wrap | Out-String -Width 250 | Write-Host
$md = @("# Test-PartEicar ($Stamp), client $Client", '', '| VM | Panne | Tamper | Installer | Vérif. panne | Persistance | Defender voit | Fichier survit | Retrait | Vérif. propre | Empreinte |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
foreach ($r in $results) {
    $f = { param($n) if ($r.PSObject.Properties[$n]) { $r.$n } else { '' } }
    $md += "| $($r.VM) | $($r.Panne) | $($r.Tamper) | $($r.Installer) | $($r.VerifPanne) | $(& $f 'Persistance') | $(& $f 'DefenderVoit') | $(& $f 'FichierSurvit') | $($r.Retrait) | $($r.VerifPropre) | $($r.Empreinte) |"
}
$md | Set-Content -Path (Join-Path $LogDir 'resultats.md') -Encoding UTF8
Write-Host "Journaux : $LogDir"
if ($results | Where-Object { ($_.PSObject.Properties.Value -join ' ') -match 'ÉCHEC' }) { exit 1 }
exit 0
