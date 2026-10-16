#requires -version 5.1
<#
.SYNOPSIS
    Reproduction FONCTIONNELLE de PC-01 variante A sur deux équipes : ouvre vraiment
    LibreOffice dans la session de ncote et capture l'écran (uniquement par Invoke-LabVM.ps1).

.DESCRIPTION
    Pour chaque équipe : Setup -> Panne A -> ouverture de session automatique de ncote ->
    lancement de LibreOffice Writer -> capture (le message « verrouillé par un autre poste »
    doit apparaître) -> fermeture, Nettoyer, Retrait. On compare la capture de l'équipe 1
    (où ça « fonctionne ») à celle de l'équipe 2 (où l'enseignant dit que ça échoue).
    Captures : tests\logs\AB-PC-01-T\capture-*.png.

.EXAMPLE
    .\tests\Repro-PC01-A-LO.ps1
#>
[CmdletBinding()]
param([int]$Equipes = 2, [int]$AttenteBureau = 80)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$VM = 'AB-PC-01-T'
$Dir = 'C:\Lab\AB\PC-01'
$Compte = 'ncote'
$Captures = @()

function Invoke-Run([string]$Script, [string[]]$Arguments = @()) {
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
}
function Invoke-Session([string]$Etape, [string[]]$Extra = @()) {
    Invoke-Run 'C:\Lab\tests\ABSession-Invite.ps1' (@('-Etape', $Etape, '-Compte', $Compte) + $Extra)
}
function Wait-ABReboot {
    Start-Sleep -Seconds 20
    $deadline = (Get-Date).AddMinutes(5)
    do { $ok = $true; try { & $Inv -VMName $VM -Action Ping | Out-Null } catch { $ok = $false; Start-Sleep -Seconds 10 } } while (-not $ok -and (Get-Date) -lt $deadline)
    if (-not $ok) { throw "$VM ne répond plus après le redémarrage." }
}
function Get-LastCapture {
    $dir = Join-Path $Repo 'tests\logs\AB-PC-01-T'
    return (Get-ChildItem -LiteralPath $dir -Filter 'capture-*.png' | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
}

& $Inv -VMName $VM -Action Reset | Out-Null
& $Inv -VMName $VM -Action Push -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB') | Out-Null
& $Inv -VMName $VM -Action Push -Destination 'C:\Lab\tests' -Path (Join-Path $PSScriptRoot 'ABSession-Invite.ps1') | Out-Null

for ($i = 1; $i -le $Equipes; $i++) {
    Write-Host "########## Équipe $i : Setup + Panne A + ouverture de LibreOffice" -ForegroundColor Cyan
    $r = Invoke-Run "$Dir\Setup-PC-01.ps1"
    Write-Host ("Setup : code $($r.Code)") -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })
    $r = Invoke-Run "$Dir\Panne-PC-01.ps1" @('-Variante', 'A')
    Write-Host ("Panne A : code $($r.Code)") -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })

    $null = Invoke-Session 'Preparer'
    $null = Invoke-Session 'Redemarrer'
    Wait-ABReboot
    Write-Host "Attente du Bureau ($AttenteBureau s)..."
    Start-Sleep -Seconds $AttenteBureau
    $null = Invoke-Session 'LancerLibreOffice'
    Start-Sleep -Seconds 18
    & $Inv -VMName $VM -Action Capture | Out-Null
    $cap = Get-LastCapture
    $Captures += [pscustomobject]@{ Equipe = $i; Capture = $cap }
    Write-Host "Capture équipe $i : $cap" -ForegroundColor Cyan

    $null = Invoke-Session 'FermerLibreOffice'
    $null = Invoke-Session 'Nettoyer'
    $r = Invoke-Run "$Dir\Retrait-PC-01.ps1"
    Write-Host ("Retrait : code $($r.Code)") -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })
}

& $Inv -VMName $VM -Action Stop | Out-Null
Write-Host ''
$Captures | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
