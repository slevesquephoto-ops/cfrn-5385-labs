#requires -version 5.1
<#
.SYNOPSIS
    Reproduction FIDÈLE de PC-01 variante A sur deux équipes, SERVEUR ALLUMÉ, en listant les
    lecteurs réellement présents dans la session de ncote (uniquement par Invoke-LabVM.ps1).

.DESCRIPTION
    SRV-01 (propre, partages joignables) + PC-01 sur AB-Lab-Interne. Pour chaque équipe :
    Setup PC-01 -> Panne A -> ouverture de session de ncote -> rapport des lecteurs
    (net use, Get-SmbMapping) + capture -> Nettoyer -> Retrait.
    But : voir si S: (\\AB-SERVEUR\Commun, mauvais serveur) apparaît à l'équipe 1 mais
    disparaît à l'équipe 2, comme sur le vrai matériel.
    Rapports : tests\logs\Repro-PC01-R5-<date>\equipe<N>.txt ; captures : logs\AB-PC-01-T\.

.EXAMPLE
    .\tests\Repro-PC01-R5.ps1
#>
[CmdletBinding()]
param([int]$Equipes = 2, [int]$AttenteBureau = 85)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$Compte = 'ncote'
$cfg = Import-PowerShellDataFile (Join-Path $Repo 'AB\AB-Config.psd1')
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $PSScriptRoot "logs\Repro-PC01-R5-$Stamp"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Invoke-Run([string]$VM, [string]$Script, [string[]]$Arguments = @()) {
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
}
function Invoke-Session([string]$Etape, [string[]]$Extra = @()) {
    Invoke-Run 'AB-PC-01-T' 'C:\Lab\tests\ABSession-Invite.ps1' (@('-Etape', $Etape, '-Compte', $Compte) + $Extra)
}
function Wait-ABReboot([string]$VM) {
    Start-Sleep -Seconds 20
    $deadline = (Get-Date).AddMinutes(5)
    do { $ok = $true; try { & $Inv -VMName $VM -Action Ping | Out-Null } catch { $ok = $false; Start-Sleep -Seconds 10 } } while (-not $ok -and (Get-Date) -lt $deadline)
    if (-not $ok) { throw "$VM ne répond plus après le redémarrage." }
}

foreach ($pc in 'PC-02', 'PC-03', 'PC-04') {
    if ((Get-VM -Name "AB-$pc-T" -ErrorAction SilentlyContinue).State -eq 'Running') { & $Inv -VMName "AB-$pc-T" -Action Stop | Out-Null }
}

# Serveur : propre, partages joignables
Write-Host 'Préparation du serveur AB-SRV-01-T...' -ForegroundColor Cyan
& $Inv -VMName 'AB-SRV-01-T' -Action Reset | Out-Null
& $Inv -VMName 'AB-SRV-01-T' -Action Push -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB') | Out-Null
$lo = ($cfg.Logiciels | Where-Object { $_['DossierServeur'] }).Fichier
& $Inv -VMName 'AB-SRV-01-T' -Action Push -Destination 'C:\Lab\tools\installeurs' -Path (Join-Path $Repo "tools\installeurs\$lo") | Out-Null
$r = Invoke-Run 'AB-SRV-01-T' 'C:\Lab\AB\SRV-01\Setup-SRV-01.ps1'
Write-Host "Setup SRV-01 : code $($r.Code)" -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })

# Poste
Write-Host 'Préparation du poste AB-PC-01-T...' -ForegroundColor Cyan
& $Inv -VMName 'AB-PC-01-T' -Action Reset | Out-Null
& $Inv -VMName 'AB-PC-01-T' -Action Push -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB') | Out-Null
& $Inv -VMName 'AB-PC-01-T' -Action Push -Destination 'C:\Lab\tests' -Path (Join-Path $PSScriptRoot 'Set-ABVMReseau.ps1'), (Join-Path $PSScriptRoot 'ABSession-Invite.ps1'), (Join-Path $PSScriptRoot 'ABDrives-Invite.ps1') | Out-Null
$null = Invoke-Run 'AB-PC-01-T' 'C:\Lab\tests\Set-ABVMReseau.ps1' @('-Poste', 'PC-01')

for ($i = 1; $i -le $Equipes; $i++) {
    Write-Host "########## Équipe $i : Setup + Panne A + session ncote" -ForegroundColor Cyan
    $r = Invoke-Run 'AB-PC-01-T' 'C:\Lab\AB\PC-01\Setup-PC-01.ps1'
    Write-Host "Setup PC-01 : code $($r.Code)" -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })
    $r = Invoke-Run 'AB-PC-01-T' 'C:\Lab\AB\PC-01\Panne-PC-01.ps1' @('-Variante', 'A')
    Write-Host "Panne A : code $($r.Code)" -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })

    $null = Invoke-Session 'Preparer'
    $null = Invoke-Session 'Redemarrer'
    Wait-ABReboot 'AB-PC-01-T'
    Write-Host "Attente du Bureau ($AttenteBureau s)..."
    Start-Sleep -Seconds $AttenteBureau

    $r = Invoke-Run 'AB-PC-01-T' 'C:\Lab\tests\ABDrives-Invite.ps1' @('-Mode', 'Collect', '-Compte', $Compte)
    $rapport = Join-Path $LogDir "equipe$i.txt"
    $r.Output | Set-Content -LiteralPath $rapport -Encoding UTF8
    & $Inv -VMName 'AB-PC-01-T' -Action Capture | Out-Null
    Write-Host "----- Lecteurs dans la session, équipe $i -----" -ForegroundColor Yellow
    $r.Output | Where-Object { $_ -match 'OK|Unavailable|->|:\s|net use|SmbMapping|RAPPORT' } | ForEach-Object { Write-Host "    $_" }

    $null = Invoke-Session 'Nettoyer'
    $r = Invoke-Run 'AB-PC-01-T' 'C:\Lab\AB\PC-01\Retrait-PC-01.ps1'
    Write-Host "Retrait : code $($r.Code)" -ForegroundColor $(if ($r.Code -eq 0) { 'Green' } else { 'Red' })
}

& $Inv -VMName 'AB-PC-01-T' -Action Stop | Out-Null
& $Inv -VMName 'AB-SRV-01-T' -Action Stop | Out-Null
Write-Host ''
Write-Host "Rapports détaillés : $LogDir" -ForegroundColor Cyan
