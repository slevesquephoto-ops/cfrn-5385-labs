#requires -version 5.1
<#
.SYNOPSIS
    Preuve que R4 (lenteur) s'EXÉCUTE à l'ouverture de session de lpgauthier (uniquement par
    Invoke-LabVM.ps1).

.DESCRIPTION
    Reset de AB-PC-02-T, Setup, Panne, puis vraie ouverture de session (ABSession-Invite) :
      - scripts .vbs exécutés sans erreur (aucun wscript.exe bloqué sur un message d'erreur);
      - processus gourmand en cours, avec au moins MemoireMo de mémoire de travail;
      - valeurs Run de type ExpandString (%APPDATA% développé par Windows).
    Puis Retrait et Verifier Propre. Capture du Bureau : tests\logs\AB-PC-02-T\capture-*.png.

.EXAMPLE
    .\tests\Test-ABR4Session.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante = 'A',
    [int]$AttenteBureau = 90
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$VM = 'AB-PC-02-T'
$Compte = 'lpgauthier'
$r4 = (Import-PowerShellDataFile (Join-Path $Repo 'AB\AB-Config.psd1')).Pannes.R4
$rows = New-Object System.Collections.Generic.List[object]

function Invoke-Guest([string]$Script, [string[]]$Arguments = @()) {
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
}
function Add-Row([string]$Etape, [bool]$Ok, [string]$Detail = '') {
    $res = 'ÉCHEC'; if ($Ok) { $res = 'OK' }
    $rows.Add([pscustomobject]@{ Etape = $Etape; Resultat = $res; Detail = $Detail })
    $c = 'Red'; if ($Ok) { $c = 'Green' }
    Write-Host ("{0,-46} {1,-6} {2}" -f $Etape, $res, $Detail) -ForegroundColor $c
}
function Wait-ABVM {
    Start-Sleep -Seconds 20
    $deadline = (Get-Date).AddMinutes(5)
    do { $ok = $true; try { & $Inv -VMName $VM -Action Ping | Out-Null } catch { $ok = $false; Start-Sleep -Seconds 10 } } while (-not $ok -and (Get-Date) -lt $deadline)
    if (-not $ok) { throw "$VM ne répond plus après le redémarrage." }
}

& $Inv -VMName $VM -Action Reset | Out-Null
& $Inv -VMName $VM -Action Push -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB') | Out-Null
& $Inv -VMName $VM -Action Push -Destination 'C:\Lab\tests' -Path (Join-Path $PSScriptRoot 'ABSession-Invite.ps1'), (Join-Path $PSScriptRoot 'ABDemarrage-Invite.ps1'), (Join-Path $PSScriptRoot 'Set-ABVMReseau.ps1') | Out-Null
$null = Invoke-Guest 'C:\Lab\tests\Set-ABVMReseau.ps1' @('-Poste', 'PC-02')

$r = Invoke-Guest 'C:\Lab\AB\PC-02\Setup-PC-02.ps1'
Add-Row 'Setup' (($r.Output -join "`n") -match 'Profil de lpgauthier|Données de R3') "code $($r.Code) (Verifier sans serveur : lecteurs non joignables)"
$r = Invoke-Guest 'C:\Lab\AB\PC-02\Panne-PC-02.ps1' @('-Variante', $Variante)
Add-Row "Panne $Variante" ($r.Code -eq 0)

$null = Invoke-Guest 'C:\Lab\tests\ABSession-Invite.ps1' @('-Etape', 'Preparer', '-Compte', $Compte)
$null = Invoke-Guest 'C:\Lab\tests\ABSession-Invite.ps1' @('-Etape', 'Redemarrer', '-Compte', $Compte)
Wait-ABVM
Write-Host "Attente du Bureau et des éléments de démarrage ($AttenteBureau s)..."
Start-Sleep -Seconds $AttenteBureau
& $Inv -VMName $VM -Action Capture | Out-Null

$r = Invoke-Guest 'C:\Lab\tests\ABDemarrage-Invite.ps1' @('-Compte', $Compte)
$json = $r.Output | Where-Object { $_ -like '{*' } | Select-Object -Last 1
$p = $json | ConvertFrom-Json
Add-Row 'Session de lpgauthier ouverte' ([bool]$p.sessionChargee)
$types = @($p.run | ForEach-Object { "$($_.nom)=$($_.type)" })
Add-Row 'Valeurs Run en ExpandString' (@($p.run).Count -eq $r4.Demarrage.Count -and -not ($p.run | Where-Object { $_.nom -ne 'IndexationDocuments' -and $_.type -ne 'ExpandString' })) ($types -join ', ')
$wscript = @($p.processus | Where-Object { $_.nom -eq 'wscript.exe' })
Add-Row 'Aucun wscript.exe resté ouvert (erreur VBS)' ($wscript.Count -eq 0) (($wscript | ForEach-Object { $_.commande }) -join ' | ')
$gourmand = @($p.processus | Where-Object { $_.nom -eq 'powershell.exe' -and $_.commande -match [regex]::Escape($r4.ScriptGourmand) })
$mo = 0; if ($gourmand) { $mo = ($gourmand | Measure-Object memoireMo -Maximum).Maximum }
Add-Row 'Processus gourmand en cours' ($mo -ge [int]($r4.MemoireMo * 0.9)) "$mo Mo (attendu ≥ $($r4.MemoireMo)); mémoire libre $($p.memoireLibreMo) / $($p.memoireTotaleMo) Mo"

$null = Invoke-Guest 'C:\Lab\tests\ABSession-Invite.ps1' @('-Etape', 'Nettoyer', '-Compte', $Compte)
$r = Invoke-Guest 'C:\Lab\AB\PC-02\Retrait-PC-02.ps1'
Add-Row 'Retrait' ($r.Code -eq 0)
$r = Invoke-Guest 'C:\Lab\AB\PC-02\Verifier-PC-02.ps1' @('-Attendu', 'Propre')
$j = ($r.Output | Where-Object { $_ -like '{"machine"*' } | Select-Object -Last 1) | ConvertFrom-Json
$autres = @($j.echecs | Where-Object { $_ -ne 'profil' })
Add-Row 'R4 retirée (demarrage propre)' (@($j.echecs) -notcontains 'demarrage') "échecs : $(@($j.echecs) -join ', ') (profil = lecteurs sans serveur)"
& $Inv -VMName $VM -Action Stop | Out-Null

Write-Host ''
$rows | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
Write-Host "Détail brut : $json"
if ($rows.Resultat -contains 'ÉCHEC' -or $autres) { exit 1 }
exit 0
