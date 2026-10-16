#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exécuté DANS AB-PC-01-T : liste les lecteurs réseau RÉELLEMENT présents dans la session
    de l'employé (pas seulement la valeur de registre).

.DESCRIPTION
    -Mode Collect : enregistre une tâche interactive qui relance ce script en -Mode Write
                    dans la session ouverte de l'employé, attend, puis affiche le rapport.
    -Mode Write   : écrit le rapport (net use, Get-SmbMapping) dans le fichier partagé.
    Les lecteurs mappés sont propres à la session de logon : seul -Mode Write, exécuté dans
    la session de l'employé, les voit. -Mode Collect tourne en tant que SYSTEM et ne verrait rien.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Collect', 'Write')][string]$Mode,
    [Parameter(Mandatory)][string]$Compte
)

$rapport = 'C:\ProgramData\CFRN-Lab\drives-report.txt'

if ($Mode -eq 'Write') {
    $lignes = @("=== $(Get-Date -Format s) session=$env:USERNAME ===", '--- net use ---')
    $lignes += (& net.exe use 2>&1 | ForEach-Object { "$_" })
    $lignes += '--- Get-SmbMapping ---'
    $lignes += (Get-SmbMapping -ErrorAction SilentlyContinue | ForEach-Object { "$($_.LocalPath) -> $($_.RemotePath) [$($_.Status)]" })
    $lignes += '--- Get-PSDrive (FileSystem) ---'
    $lignes += (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name): $($_.DisplayRoot)" })
    Set-Content -LiteralPath $rapport -Value $lignes -Encoding UTF8
    return
}

# Collect : relance -Mode Write dans la session de l'employé (tâche interactive)
Remove-Item -LiteralPath $rapport -ErrorAction SilentlyContinue
$nom = 'CFRN-Drives-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$Compte" -LogonType Interactive -RunLevel Limited
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Write -Compte $Compte"
Register-ScheduledTask -TaskName $nom -Action $action -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $nom
$deadline = (Get-Date).AddSeconds(30)
while (-not (Test-Path -LiteralPath $rapport) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
Start-Sleep -Seconds 2
Unregister-ScheduledTask -TaskName $nom -Confirm:$false
if (Test-Path -LiteralPath $rapport) { Get-Content -LiteralPath $rapport }
else { "RAPPORT ABSENT (la tâche interactive n'a pas écrit : session de $Compte ouverte?)" }
