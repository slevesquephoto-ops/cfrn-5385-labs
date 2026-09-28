#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-02 : R4 couche logicielle (lenteur) dans la session de Louis-Philippe.

.DESCRIPTION
    Dépose des éléments de démarrage inutiles (valeurs Run et une tâche planifiée) et un
    processus fictif qui retient de la mémoire, dans la session de lpgauthier. Noms
    plausibles, aucun indice « panne ». La couche matérielle (ajout de RAM) est manuelle.
    -Variante (lettre de l'équipe) est enregistrée; la couche logicielle ne varie pas.
    L'état d'origine (valeurs Run, tâche, dossier de scripts) est enregistré avant.
    R3 n'est pas une panne installée : c'est la sauvegarde que fait Louis-Philippe (élèves);
    Verifier-PC-02 -R3 la contrôle.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-02'
$null = Start-LabLog -Name "Panne-$Machine-$Variante"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $existing = Get-LabState -Scenario $Machine
    if ($existing) {
        if ($existing.Variante -eq $Variante) { Write-LabOK "Panne $Variante déjà installée : rien à refaire."; return }
        throw "La panne $($existing.Variante) est installée. Lancer Retrait-$Machine.ps1 avant d'installer $Variante."
    }
    $compte = (Get-ABConfig).Pannes.R4.Compte

    Write-LabStep 'R4 : démarrage encombré et processus gourmand'
    $clutter = Add-ABStartupClutter -Compte $compte
    $state = [ordered]@{ Variante = $Variante; Date = (Get-Date).ToString('s'); R4 = $clutter }
    if (-not (Save-LabState -Scenario $Machine -Data $state)) {
        Remove-ABStartupClutter -State $clutter
        throw 'État déjà présent : panne annulée.'
    }
    Write-LabOK "Éléments de démarrage et processus gourmand installés pour $compte."
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
