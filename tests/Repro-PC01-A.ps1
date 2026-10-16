#requires -version 5.1
<#
.SYNOPSIS
    Reproduit la rotation de PC-01 variante A sur DEUX équipes de suite (uniquement par
    Invoke-LabVM.ps1), pour trouver pourquoi la 2e équipe échoue.

.DESCRIPTION
    Reset, copie, puis pour chaque équipe : Setup -> Verifier Propre -> Panne A ->
    Verifier Panne A -> Retrait. Après chaque étape clé : code de sortie et sonde du
    verrou LibreOffice de ncote (Host=? dans le .lock). Capture à la fin de chaque panne.
    Sans serveur : le contrôle « profil » tolère les lecteurs non joignables (RemotePath
    lu dans la ruche, pas de ping), donc Propre doit passer quand même.

.EXAMPLE
    .\tests\Repro-PC01-A.ps1
#>
[CmdletBinding()]
param([int]$Equipes = 2)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$VM = 'AB-PC-01-T'
$Dir = 'C:\Lab\AB\PC-01'
$rows = New-Object System.Collections.Generic.List[object]

function Invoke-Run([string]$Script, [string[]]$Arguments = @()) {
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out; Json = ($out | Where-Object { $_ -like '{"machine"*' } | Select-Object -Last 1) }
}
function Add-Row([string]$Equipe, [string]$Etape, [int]$Code, [int]$Attendu, [string]$Detail) {
    $ok = ($Code -eq $Attendu)
    $res = 'OK'; if (-not $ok) { $res = "ÉCHEC" }
    $rows.Add([pscustomobject]@{ Equipe = $Equipe; Etape = $Etape; Attendu = $Attendu; Code = $Code; Resultat = $res; Detail = $Detail })
    $c = 'Green'; if (-not $ok) { $c = 'Red' }
    Write-Host ("Équipe {0}  {1,-22} attendu {2} obtenu {3}  {4}  {5}" -f $Equipe, $Etape, $Attendu, $Code, $res, $Detail) -ForegroundColor $c
}
# Sonde : lit le .lock de ncote dans la VM (Host=, et existence)
$sondeLock = @'
$ErrorActionPreference='SilentlyContinue'
$sid=(Get-LocalUser -Name ncote).SID.Value
$prof=(Get-CimInstance Win32_UserProfile -Filter "SID='$sid'").LocalPath
$lock=Join-Path $prof 'AppData\Roaming\LibreOffice\4\.lock'
if(Test-Path -LiteralPath $lock){ $h=@{}; foreach($l in Get-Content -LiteralPath $lock){ if($l -match '^(\w+)=(.*)$'){$h[$matches[1]]=$matches[2]} }; "LOCK Host=$($h['Host']) User=$($h['User'])" } else { "LOCK absent" }
$dir=Join-Path $prof 'AppData\Roaming\LibreOffice\4'
"LOROOT exists=$([bool](Test-Path -LiteralPath $dir))"
'@
$sondePath = Join-Path $env:TEMP 'claude-sonde-lock.ps1'
Set-Content -LiteralPath $sondePath -Value $sondeLock -Encoding UTF8
function Show-Lock([string]$Quand) {
    $r = Invoke-Run 'C:\Lab\tests\claude-sonde-lock.ps1'
    $txt = ($r.Output | Where-Object { $_ -like 'LOCK*' -or $_ -like 'LOROOT*' }) -join '  |  '
    Write-Host "    verrou ($Quand) : $txt" -ForegroundColor DarkCyan
    return $txt
}

& $Inv -VMName $VM -Action Reset | Out-Null
& $Inv -VMName $VM -Action Push -Path (Join-Path $Repo 'common'), (Join-Path $Repo 'AB') | Out-Null
& $Inv -VMName $VM -Action Push -Destination 'C:\Lab\tests' -Path $sondePath | Out-Null

for ($i = 1; $i -le $Equipes; $i++) {
    Write-Host "########## Équipe $i : PC-01 variante A" -ForegroundColor Cyan
    $r = Invoke-Run "$Dir\Setup-PC-01.ps1"
    # Setup lance son propre Verifier Propre; sans serveur, 'profil' peut échouer sur les lecteurs
    $j = if ($r.Json) { $r.Json | ConvertFrom-Json } else { $null }
    $ech = if ($j) { @($j.echecs) -join ',' } else { 'JSON absent' }
    Add-Row $i 'Setup (+Verif Propre)' $r.Code 0 "échecs Verif: $ech"
    Show-Lock 'après Setup' | Out-Null

    $r = Invoke-Run "$Dir\Panne-PC-01.ps1" @('-Variante', 'A')
    Add-Row $i 'Panne A' $r.Code 0 (($r.Output | Where-Object { $_ -like '`[ATTENTION`]*' }) -join ' | ')
    $lock = Show-Lock 'après Panne A'

    $r = Invoke-Run "$Dir\Verifier-PC-01.ps1" @('-Attendu', 'Panne', '-Variante', 'A')
    $j = if ($r.Json) { $r.Json | ConvertFrom-Json } else { $null }
    $ech = if ($j) { @($j.echecs) -join ',' } else { 'JSON absent' }
    Add-Row $i 'Verif Panne A' $r.Code 0 "échecs: $ech ; $lock"
    & $Inv -VMName $VM -Action Capture | Out-Null

    $r = Invoke-Run "$Dir\Retrait-PC-01.ps1"
    Add-Row $i 'Retrait' $r.Code 0 (($r.Output | Where-Object { $_ -like '`[ATTENTION`]*' }) -join ' | ')
    Show-Lock 'après Retrait' | Out-Null
}

& $Inv -VMName $VM -Action Stop | Out-Null
Write-Host ''
$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
if ($rows.Resultat -contains 'ÉCHEC') { exit 1 }
exit 0
