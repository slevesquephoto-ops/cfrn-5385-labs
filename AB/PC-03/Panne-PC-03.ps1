#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-03 : R1 couches 1 et 2 sur le poste d'Émilie (identiques pour toutes les variantes).

.DESCRIPTION
    Couche 1 : entrée dans le fichier hosts qui envoie AB-SRV-01 vers une mauvaise adresse,
               commentée « ancien serveur ». Ping par nom échoue, ping par IP fonctionne.
    Couche 2 : l'identifiant d'efortin pour AB-SRV-01 est mémorisé dans son Gestionnaire
               d'identification (mot de passe LAB). Avec le mot de passe changé sur le serveur
               (Panne-SRV-01), l'accès est refusé sans invite.
    -Variante (lettre de l'équipe) est enregistrée; la panne du poste ne varie pas.
    L'état d'origine (hosts, identifiants présents) est enregistré avant toute modification.
#>
[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante = 'A',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$null = Start-LabLog -Name "Panne-PC-03-$Variante"
$exitCode = 0
try {
    Assert-LabComputer -Expected 'AB-PC-03' -Force:$Force
    $cfg = Get-ABConfig
    $r1 = $cfg.Pannes.R1
    $emp = $cfg.Employes | Where-Object { $_.Compte -eq $r1.Compte }
    $server = $cfg.Reseau.Serveur
    $hostsFile = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (Get-LabState -Scenario 'PC-03') { Write-LabOK 'Panne déjà installée : rien à refaire.'; return }

    Write-LabStep 'Enregistrement de l''état d''origine'
    $targets = @(Get-ABUserCredentialTarget -Compte $emp.Compte -Password $emp.MotDePasse)
    $state = [ordered]@{
        Variante      = $Variante
        Date          = (Get-Date).ToString('s')
        Hosts         = [Convert]::ToBase64String([IO.File]::ReadAllBytes($hostsFile))
        Identifiant   = ($targets -contains $server)
    }
    if (-not (Save-LabState -Scenario 'PC-03' -Data $state)) { throw 'État déjà présent : installation interrompue.' }
    Write-LabOK 'État enregistré.'

    Write-LabStep 'R1 couche 1 : fichier hosts'
    Add-Content -LiteralPath $hostsFile -Value "$($r1.AncienneIP)`t$server`t# ancien serveur" -Encoding ASCII
    & ipconfig.exe /flushdns | Out-Null
    Write-LabOK "$server -> $($r1.AncienneIP)"

    Write-LabStep 'R1 couche 2 : identifiant mémorisé dans la session d''Émilie'
    Add-ABUserCredential -Compte $emp.Compte -Password $emp.MotDePasse -Target $server -UserName "$server\$($emp.Compte)" -Secret $emp.MotDePasse
    Write-LabOK "Identifiant $server mémorisé pour $($emp.Compte)."
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
