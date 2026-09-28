#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-SRV-01 : pannes de l'équipe (R1 couches 2 et 3, R6 variante B).

.DESCRIPTION
    R1 couche 2 : le mot de passe d'efortin est changé sur le serveur seulement.
    R1 couche 3, selon -Variante :
      A  Refuser explicite (Modification) pour efortin sur le dossier 2026-021
      B  Héritage coupé sur 2026-021, AB-Conception retiré de l'ACL
      C  efortin retirée du groupe AB-Conception
      D  AB-Conception réduit à Lecture à la racine de Projets
      E  Permission de partage Projets réduite à Lecture (NTFS correct)
    R6 variante B (même lettre pour toute l'équipe) : verrou LibreOffice orphelin sur
    le registre des factures, laissé par le poste de Louis-Philippe.
    Tout ce qui est modifié est d'abord enregistré (état 'SRV-01') : Retrait-SRV-01.ps1
    remet exactement l'état d'avant.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$null = Start-LabLog -Name "Panne-SRV-01-$Variante"
$exitCode = 0
try {
    Assert-LabComputer -Expected 'AB-SRV-01' -Force:$Force
    $cfg = Get-ABConfig
    $r1 = $cfg.Pannes.R1
    $r6 = $cfg.Pannes.R6
    $existing = Get-LabState -Scenario 'SRV-01'
    if ($existing) {
        if ($existing.Variante -eq $Variante) { Write-LabOK "Panne $Variante déjà installée : rien à refaire."; return }
        throw "La panne $($existing.Variante) est installée. Lancer Retrait-SRV-01.ps1 avant d'installer $Variante."
    }

    $labPassword = ($cfg.Employes | Where-Object { $_.Compte -eq $r1.Compte }).MotDePasse
    $user = Get-LocalUser -Name $r1.Compte
    $projets = ($cfg.Partages | Where-Object { $_.Nom -eq 'Projets' }).Dossier
    $projet = Join-Path $projets $r1.DossierProjet
    if (-not (Test-Path -LiteralPath $projet)) { throw "Dossier absent : $projet. Lancer Setup-SRV-01.ps1." }
    $adminDir = ($cfg.Partages | Where-Object { $_.Nom -eq 'Administration' }).Dossier
    $registre = Join-Path $adminDir $r6.Registre
    $lock = Join-Path (Split-Path -Parent $registre) ('.~lock.' + (Split-Path -Leaf $registre) + '#')

    Write-LabStep 'Enregistrement de l''état d''origine'
    $state = [ordered]@{
        Variante = $Variante
        Date     = (Get-Date).ToString('s')
        Machine  = $env:COMPUTERNAME
        Couche2  = [ordered]@{
            Compte               = $r1.Compte
            PasswordWasLab       = (Test-ABLocalPassword -UserName $r1.Compte -Password $labPassword)
            PasswordNeverExpires = ($null -eq $user.PasswordExpires)
            UserMayChangePassword = $user.UserMayChangePassword
            Enabled              = $user.Enabled
        }
        Couche3  = [ordered]@{ Type = $null }
        R6       = $null
    }
    if (-not $state.Couche2.PasswordWasLab) { Write-LabWarn "Le mot de passe de $($r1.Compte) n'est pas le mot de passe LAB : Setup-SRV-01 non lancé?" }
    switch ($Variante) {
        { $_ -in 'A', 'B' } { $state.Couche3 = [ordered]@{ Type = 'Acl'; Acl = @(Get-ABAclSnapshot -Path $projet) } }
        'C' { $state.Couche3 = [ordered]@{ Type = 'Groupe'; Groupe = 'AB-Conception'; Membres = @(Get-ABGroupMemberSid -GroupSid (Get-LocalGroup -Name 'AB-Conception').SID.Value) } }
        'D' { $state.Couche3 = [ordered]@{ Type = 'Acl'; Acl = @(Get-ABAclSnapshot -Path $projets) } }
        'E' {
            $access = @(Get-SmbShareAccess -Name 'Projets' | ForEach-Object {
                    [ordered]@{ Sid = (ConvertTo-ABSidString -Identity $_.AccountName); Right = [string]$_.AccessRight; Type = [string]$_.AccessControlType }
                })
            $state.Couche3 = [ordered]@{ Type = 'Partage'; Partage = 'Projets'; Acces = $access }
        }
    }
    if ($Variante -eq 'B') {
        $r6State = [ordered]@{ Verrou = $lock; Existait = (Test-Path -LiteralPath $lock); Contenu = $null; Attributs = $null }
        if ($r6State.Existait) {
            $r6State.Contenu = [Convert]::ToBase64String([IO.File]::ReadAllBytes($lock))
            $r6State.Attributs = [string](Get-Item -LiteralPath $lock -Force).Attributes
        }
        $state.R6 = $r6State
    }
    if (-not (Save-LabState -Scenario 'SRV-01' -Data $state)) { throw "État déjà présent : installation interrompue." }
    Write-LabOK 'État enregistré.'

    Write-LabStep 'R1 couche 2 : mot de passe changé sur le serveur seulement'
    Set-LocalUser -Name $r1.Compte -Password (ConvertTo-SecureString $r1.MotDePassePanne -AsPlainText -Force)
    Write-LabOK $r1.Compte

    Write-LabStep "R1 couche 3 : variante $Variante"
    $userSid = Get-ABSid -Name $r1.Compte
    $conception = Get-ABSid -Name 'AB-Conception'
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    switch ($Variante) {
        'A' {
            $acl = Get-Acl -LiteralPath $projet
            $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($userSid, 'Modify', $inherit, 'None', 'Deny')))
            Set-Acl -LiteralPath $projet -AclObject $acl
        }
        'B' {
            $acl = Get-Acl -LiteralPath $projet
            $acl.SetAccessRuleProtection($true, $true)
            Set-Acl -LiteralPath $projet -AclObject $acl
            $acl = Get-Acl -LiteralPath $projet
            $acl.PurgeAccessRules($conception)
            Set-Acl -LiteralPath $projet -AclObject $acl
        }
        'C' { Remove-LocalGroupMember -Name 'AB-Conception' -Member $userSid.Value }
        'D' {
            $acl = Get-Acl -LiteralPath $projets
            $acl.PurgeAccessRules($conception)
            $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($conception, 'ReadAndExecute', $inherit, 'None', 'Allow')))
            Set-Acl -LiteralPath $projets -AclObject $acl
        }
        'E' {
            Set-ABShareAccess -Name 'Projets' -Entries @([pscustomobject]@{ Sid = (Get-ABSid -Name 'Utilisateurs authentifiés').Value; Right = 'Read'; Type = 'Allow' })
        }
    }
    Write-LabOK "Variante $Variante en place."

    if ($Variante -eq 'B') {
        Write-LabStep 'R6 variante B : verrou orphelin sur le registre des factures'
        # Format d'un verrou LibreOffice : nom,compte,poste,date,profil;  (UTF-8, fichier caché)
        $when = (Get-Date).AddDays(-2).Date.AddHours(16).AddMinutes(42)
        $content = '{0},{1},{2},{3},file:///C:/Users/{1}/AppData/Roaming/LibreOffice/4;' -f `
            $r6.VerrouNom, $r6.VerrouCompte, $r6.VerrouPoste, $when.ToString('dd.MM.yyyy HH:mm')
        [IO.File]::WriteAllText($lock, $content, (New-Object Text.UTF8Encoding($false)))
        $item = Get-Item -LiteralPath $lock -Force
        $item.Attributes = $item.Attributes -bor [IO.FileAttributes]::Hidden
        Set-LabItemTime -Path $lock -Created $when -Modified $when
        Write-LabOK (Split-Path -Leaf $lock)
    }
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
