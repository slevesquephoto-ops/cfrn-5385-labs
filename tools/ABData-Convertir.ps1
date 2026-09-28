#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exécuté DANS une VM de poste par tools\New-ABData.ps1 : convertit les sources des
    données fictives avec LibreOffice sans interface.

.DESCRIPTION
    Installe Montserrat pour la machine (la VM est remise à Propre ensuite), puis, pour
    chaque ligne de conversions.csv : soffice --headless --convert-to. Les sources
    (HTML, CSV, SVG) sont retirées à la fin. Code de sortie 1 si une conversion manque.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Build)

$ErrorActionPreference = 'Stop'
$soffice = 'C:\Program Files\LibreOffice\program\soffice.com'
if (-not (Test-Path $soffice)) { throw "LibreOffice absent de cette VM." }

# Montserrat, le temps de la conversion (modèle et factures)
foreach ($f in Get-ChildItem (Join-Path $Build 'polices') -Filter *.ttf) {
    $dst = Join-Path $env:windir "Fonts\$($f.Name)"
    if (-not (Test-Path $dst)) { Copy-Item $f.FullName $dst }
    $nom = $f.BaseName -replace '^Montserrat-', 'Montserrat ' -replace 'Regular$', ''
    New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name "$($nom.Trim()) (TrueType)" -Value $f.Name -PropertyType String -Force | Out-Null
}

$profil = 'file:///C:/Lab/lo-conversion'
$out = Join-Path $Build 'sortie'
$rows = Import-Csv (Join-Path $Build 'conversions.csv') -Delimiter ';' -Encoding UTF8
$fail = 0
foreach ($r in $rows) {
    $src = Join-Path $out $r.Source
    $argList = @("-env:UserInstallation=$profil", '--headless', '--norestore', '--nolockcheck')
    if ($r.InFiltre) { $argList += "--infilter=$($r.InFiltre)" }
    $argList += @('--convert-to', $r.Filtre, '--outdir', (Split-Path -Parent $src), $src)
    $p = Start-Process -FilePath $soffice -ArgumentList ($argList | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -PassThru -WindowStyle Hidden
    if (-not $p.WaitForExit(120000)) { $p | Stop-Process -Force; Get-Process soffice* -ErrorAction SilentlyContinue | Stop-Process -Force }
    if (-not (Test-Path -LiteralPath (Join-Path $out $r.Sortie))) { Write-Output "ÉCHEC : $($r.Sortie)"; $fail++ }
}
Get-ChildItem $out -Recurse -Include *.html, *.csv, *.svg | Remove-Item -Force
Write-Output "Conversions : $($rows.Count - $fail) réussies, $fail échecs."
if ($fail) { exit 1 }
exit 0
