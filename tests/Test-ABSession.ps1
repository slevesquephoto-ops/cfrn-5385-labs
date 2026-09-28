#requires -version 5.1
<#
.SYNOPSIS
    Preuve qu'un employé peut VRAIMENT ouvrir une session après le Setup (sans l'enseignant).

.DESCRIPTION
    À lancer après un Setup de poste réussi (le profil existe). Uniquement par Invoke-LabVM.ps1 :
      1. ouverture de session automatique une fois, redémarrage;
      2. preuves (session, explorer.exe de l'employé, profil non temporaire, pas d'animation,
         fond d'écran et lecteurs dans la ruche) + capture du Bureau;
      3. LibreOffice Writer lancé dans la session + capture (aucune fenêtre d'accueil attendue);
      4. fermeture de session et retrait de l'ouverture automatique.
    Captures : tests\logs\<VM>\capture-*.png.

.EXAMPLE
    .\tests\Test-ABSession.ps1 -VMName AB-PC-03-T -Compte efortin
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^AB-PC-0[1-4]-T$')][string]$VMName,
    [Parameter(Mandatory)][string]$Compte,
    [int]$AttenteBureau = 75,
    # Le serveur est joignable : les lecteurs doivent répondre dans la session
    [switch]$Reseau
)

$ErrorActionPreference = 'Stop'
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$Guest = 'C:\Lab\tests\ABSession-Invite.ps1'
function Invoke-GuestStep([string]$Etape) { & $Inv -VMName $VMName -Action Run -ScriptPath $Guest -ArgumentList '-Etape', $Etape, '-Compte', $Compte 6>$null }

& $Inv -VMName $VMName -Action Push -Path (Join-Path $PSScriptRoot 'ABSession-Invite.ps1') -Destination 'C:\Lab\tests' | Out-Null
Invoke-GuestStep Preparer
Invoke-GuestStep Redemarrer
Start-Sleep -Seconds 20
$deadline = (Get-Date).AddMinutes(5)
do { $ok = $true; try { & $Inv -VMName $VMName -Action Ping | Out-Null } catch { $ok = $false; Start-Sleep -Seconds 10 } } while (-not $ok -and (Get-Date) -lt $deadline)
if (-not $ok) { throw "$VMName ne répond plus après le redémarrage." }
Write-Host "Attente du Bureau ($AttenteBureau s)..."
Start-Sleep -Seconds $AttenteBureau
& $Inv -VMName $VMName -Action Capture
$preuves = (Invoke-GuestStep Preuves | Where-Object { $_ -like '{*' } | Select-Object -Last 1) | ConvertFrom-Json
$lecteurs = @(Invoke-GuestStep Lecteurs)
Write-Host "Lecteurs dans la session : $(($lecteurs | Where-Object { $_ -match '^[A-Z]: ' }) -join ' ; ')"
Invoke-GuestStep LancerLibreOffice
Start-Sleep -Seconds 25
& $Inv -VMName $VMName -Action Capture
Invoke-GuestStep Nettoyer

$attendu = "$($VMName.Substring(0, $VMName.Length - 2))\$Compte"
$verdicts = [ordered]@{
    'Session ouverte'           = [bool]($preuves.sessions | Where-Object { $_ -like "$Compte*" })
    'explorer.exe de l''employé' = [bool]($preuves.explorer | Where-Object { $_ -like "$attendu*" })
    'Profil normal, chargé'     = ($preuves.profil -eq "C:\Users\$Compte" -and $preuves.charge -and -not $preuves.evenementsTemp)
    'Pas d''animation d''accueil' = (-not $preuves.accueil)
    'Fond d''écran AB'           = ($preuves.fondEcran -like '*fond-AB.png')
}
if ($Reseau) {
    $verdicts['Lecteurs réseau accessibles'] = (@($lecteurs | Where-Object { $_ -match '^[A-Z]: ' }).Count -gt 0) -and -not ($lecteurs | Where-Object { $_ -match '^[A-Z]: ECHEC' })
}
$verdicts.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Preuve = $_.Key; Resultat = $(if ($_.Value) { 'OK' } else { 'ÉCHEC' }) } } | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Lecteurs dans la ruche : $($preuves.lecteurs -join ', ')"
if ($verdicts.Values -contains $false) { exit 1 }
exit 0
