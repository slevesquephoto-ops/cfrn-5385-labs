#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-SRV-01 : retire les pannes installées par Panne-SRV-01.ps1.

.DESCRIPTION
    Restaure depuis l'état enregistré (aucune supposition) : ACL, membres du groupe ou
    accès du partage (R1 couche 3), verrou R6-B, puis mot de passe et options du compte
    (R1 couche 2 : le mot de passe LAB de la config, l'ancien n'étant pas lisible).
    Sans état : rien à faire. Ce que les élèves ont changé ailleurs est corrigé par le
    Setup suivant (cycle Retrait, Setup, Panne).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$null = Start-LabLog -Name 'Retrait-SRV-01'
$exitCode = 0
try {
    Assert-LabComputer -Expected 'AB-SRV-01' -Force:$Force
    $state = Get-LabState -Scenario 'SRV-01'
    if (-not $state) { Write-LabOK 'Aucune panne installée : rien à retirer.'; return }
    $cfg = Get-ABConfig

    Write-LabStep "R1 couche 3 (variante $($state.Variante))"
    switch ($state.Couche3.Type) {
        'Acl' { Restore-ABAclSnapshot -Snapshot @($state.Couche3.Acl) }
        'Groupe' {
            $gsid = (Get-LocalGroup -Name $state.Couche3.Groupe).SID.Value
            $wanted = @($state.Couche3.Membres)
            $current = @(Get-ABGroupMemberSid -GroupSid $gsid)
            foreach ($s in $wanted) { if ($current -notcontains $s) { Add-LocalGroupMember -SID $gsid -Member $s } }
            foreach ($s in $current) { if ($wanted -notcontains $s) { Remove-LocalGroupMember -SID $gsid -Member $s } }
        }
        'Partage' { Set-ABShareAccess -Name $state.Couche3.Partage -Entries @($state.Couche3.Acces) }
        default { throw "Type de couche 3 inconnu dans l'état : $($state.Couche3.Type)" }
    }
    Write-LabOK 'Restauré.'

    if ($state.R6) {
        Write-LabStep 'R6 variante B : verrou'
        if ($state.R6.Existait) {
            [IO.File]::WriteAllBytes($state.R6.Verrou, [Convert]::FromBase64String($state.R6.Contenu))
            (Get-Item -LiteralPath $state.R6.Verrou -Force).Attributes = [IO.FileAttributes]$state.R6.Attributs
        } elseif (Test-Path -LiteralPath $state.R6.Verrou) {
            Remove-Item -LiteralPath $state.R6.Verrou -Force
        }
        Write-LabOK 'Verrou retiré.'
    }

    Write-LabStep 'R1 couche 2 : mot de passe'
    $c2 = $state.Couche2
    $lab = ($cfg.Employes | Where-Object { $_.Compte -eq $c2.Compte }).MotDePasse
    if (-not $c2.PasswordWasLab) { Write-LabWarn "Avant la panne, le mot de passe n'était pas le mot de passe LAB : remis au mot de passe LAB." }
    Set-LocalUser -Name $c2.Compte -Password (ConvertTo-SecureString $lab -AsPlainText -Force) `
        -PasswordNeverExpires ([bool]$c2.PasswordNeverExpires) -UserMayChangePassword ([bool]$c2.UserMayChangePassword)
    if ($c2.Enabled) { Enable-LocalUser -Name $c2.Compte } else { Disable-LocalUser -Name $c2.Compte }
    Write-LabOK $c2.Compte

    Remove-LabState -Scenario 'SRV-01'
    Write-LabOK 'Panne retirée.'
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
