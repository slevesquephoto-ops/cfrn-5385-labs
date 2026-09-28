#requires -version 5.1
<#
.SYNOPSIS
    Boucle de tests d'une machine AB dans sa VM de test (uniquement par Invoke-LabVM.ps1).

.DESCRIPTION
    Pour chaque variante :
      Reset (Propre) -> Setup -> Verifier Propre (0) -> empreinte E1
      -> Panne -> Verifier Panne -Variante (0) -> Retrait -> Verifier Propre (0)
      -> empreinte E2, identique à E1 (retrait exact).
    À la première variante, en plus (idempotence et garde-fous) : Setup relancé (même
    empreinte), Panne relancée (0), Setup refusé pendant la panne, autre variante refusée,
    Retrait relancé (0).
    Résultats : tableau à l'écran et tests\logs\Test-AB-<machine>-<date>\resultats.md.

.EXAMPLE
    .\tests\Test-AB.ps1 -Machine SRV-01
    .\tests\Test-AB.ps1 -Machine SRV-01 -Variantes A, C
#>
[CmdletBinding()]
param(
    [ValidateSet('SRV-01')][string]$Machine = 'SRV-01',
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string[]]$Variantes = @('A', 'B', 'C', 'D', 'E'),
    [string]$Checkpoint = 'Propre',
    [switch]$Arreter
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$VM = "AB-$Machine-T"
$Dir = "C:\Lab\AB\$Machine"
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $PSScriptRoot "logs\Test-AB-$Machine-$Stamp"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
Import-Module (Join-Path $RepoRoot 'AB\AB-Lab.psm1') -Force -ErrorAction SilentlyContinue

function Invoke-Step {
    <# Lance un script dans la VM; retourne { Code; Output } et garde la sortie dans le journal. #>
    param([string]$Label, [string]$Script, [string[]]$Arguments = @())
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $LogDir "$Label.log") -Encoding UTF8
    return [pscustomobject]@{ Code = $code; Output = $out }
}

function Get-Json($Output) {
    $line = $Output | Where-Object { $_ -like '{"machine"*' } | Select-Object -Last 1
    if ($line) { return ($line | ConvertFrom-Json) }
    return $null
}

function Get-Empreinte([string]$Label) {
    $r = Invoke-Step -Label $Label -Script 'C:\Lab\tests\Get-ABEmpreinte.ps1' -Arguments @('-Machine', $Machine)
    return @($r.Output | Where-Object { $_ -like 'EMP|*' })
}

function Test-Same([string[]]$A, [string[]]$B, [string]$Label) {
    if (($A -join "`n") -eq ($B -join "`n") -and $A.Count -gt 0) { return $true }
    Compare-Object $A $B | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" } |
        Set-Content -Path (Join-Path $LogDir "$Label-diff.txt") -Encoding UTF8
    return $false
}

function Mark([bool]$Ok) { if ($Ok) { 'OK' } else { 'ÉCHEC' } }

$results = @()
$first = $true
foreach ($v in $Variantes) {
    Write-Host "`n########## $Machine variante $v" -ForegroundColor Cyan
    $row = [ordered]@{ Variante = $v }
    & $Inv -VMName $VM -Action Reset -Checkpoint $Checkpoint | Out-Null
    & $Inv -VMName $VM -Action Push -Path (Join-Path $RepoRoot 'common'), (Join-Path $RepoRoot 'AB') | Out-Null
    & $Inv -VMName $VM -Action Push -Path (Join-Path $PSScriptRoot 'Get-ABEmpreinte.ps1') -Destination 'C:\Lab\tests' | Out-Null
    if ($Machine -eq 'SRV-01') {
        # Source de réparation de LibreOffice pour Logiciels$ (seulement ce fichier : 358 Mo)
        $lo = (Get-ABConfig).Logiciels | Where-Object { $_['DossierServeur'] } | Select-Object -First 1
        & $Inv -VMName $VM -Action Push -Path (Join-Path $RepoRoot "tools\installeurs\$($lo.Fichier)") -Destination 'C:\Lab\tools\installeurs' | Out-Null
    }

    $r = Invoke-Step "$v-1-Setup" "$Dir\Setup-$Machine.ps1"
    $row.Setup = Mark ($r.Code -eq 0)
    $r = Invoke-Step "$v-2-VerifPropre" "$Dir\Verifier-$Machine.ps1" @('-Attendu', 'Propre')
    $row.VerifPropre = Mark ($r.Code -eq 0)
    $e1 = Get-Empreinte "$v-3-Empreinte1"

    $idem = @()
    if ($first) {
        $r = Invoke-Step "$v-3b-Setup2" "$Dir\Setup-$Machine.ps1"
        $e1b = Get-Empreinte "$v-3c-Empreinte1b"
        $idem += "Setup x2 : $(Mark ($r.Code -eq 0 -and (Test-Same $e1 $e1b "$v-setup2")))"
    }

    $r = Invoke-Step "$v-4-Panne" "$Dir\Panne-$Machine.ps1" @('-Variante', $v)
    $row.Panne = Mark ($r.Code -eq 0)
    if ($first) {
        $r2 = Invoke-Step "$v-4b-Panne2" "$Dir\Panne-$Machine.ps1" @('-Variante', $v)
        $idem += "Panne x2 : $(Mark ($r2.Code -eq 0))"
        $other = @('A', 'B', 'C', 'D', 'E') | Where-Object { $_ -ne $v } | Select-Object -First 1
        $r3 = Invoke-Step "$v-4c-PanneAutre" "$Dir\Panne-$Machine.ps1" @('-Variante', $other)
        $idem += "Panne $other refusée : $(Mark ($r3.Code -ne 0))"
        $r4 = Invoke-Step "$v-4d-SetupPendantPanne" "$Dir\Setup-$Machine.ps1"
        $idem += "Setup refusé pendant la panne : $(Mark ($r4.Code -ne 0))"
    }
    $r = Invoke-Step "$v-5-VerifPanne" "$Dir\Verifier-$Machine.ps1" @('-Attendu', 'Panne', '-Variante', $v)
    $row.VerifPanne = Mark ($r.Code -eq 0)
    $j = Get-Json $r.Output
    $row.Echecs = ''
    if ($j) { $row.Echecs = (@($j.echecs) -join ', ') }

    $r = Invoke-Step "$v-6-Retrait" "$Dir\Retrait-$Machine.ps1"
    $row.Retrait = Mark ($r.Code -eq 0)
    $r = Invoke-Step "$v-7-VerifPropre" "$Dir\Verifier-$Machine.ps1" @('-Attendu', 'Propre')
    $row.VerifPropre2 = Mark ($r.Code -eq 0)
    $e2 = Get-Empreinte "$v-8-Empreinte2"
    $row.Empreinte = Mark (Test-Same $e1 $e2 "$v-empreinte")
    $row.Lignes = $e1.Count
    if ($first) {
        $r = Invoke-Step "$v-9-Retrait2" "$Dir\Retrait-$Machine.ps1"
        $idem += "Retrait x2 : $(Mark ($r.Code -eq 0))"
    }
    $row.Idempotence = $idem -join ' ; '
    $results += [pscustomobject]$row
    $first = $false
    ([pscustomobject]$row) | Format-List | Out-String | Write-Host
}

if ($Arreter) { & $Inv -VMName $VM -Action Stop | Out-Null }

$table = $results | Format-Table -AutoSize -Wrap | Out-String -Width 250
Write-Host $table
$md = @("# Test-AB $Machine ($Stamp)", '', '| Variante | Setup | Vérif. propre | Panne | Vérif. panne | Échecs observés | Retrait | Vérif. propre | Empreinte | Idempotence |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
foreach ($r in $results) { $md += "| $($r.Variante) | $($r.Setup) | $($r.VerifPropre) | $($r.Panne) | $($r.VerifPanne) | $($r.Echecs) | $($r.Retrait) | $($r.VerifPropre2) | $($r.Empreinte) ($($r.Lignes) lignes) | $($r.Idempotence) |" }
$md | Set-Content -Path (Join-Path $LogDir 'resultats.md') -Encoding UTF8
Write-Host "Journaux : $LogDir"
$failed = $results | Where-Object { ($_.PSObject.Properties.Value -join ' ') -match 'ÉCHEC' }
if ($failed) { exit 1 }
exit 0
