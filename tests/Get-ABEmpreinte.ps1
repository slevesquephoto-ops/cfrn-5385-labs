#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Empreinte complète de l'état d'une machine AB (exécutée DANS la VM par Test-AB.ps1).

.DESCRIPTION
    Une ligne « EMP|... » par élément : ACL (SDDL) et héritage de tout C:\AB, membres des
    groupes AB, options et validité du mot de passe LAB des comptes, partages et leurs
    accès, politique de mots de passe, verrous LibreOffice. Test-AB.ps1 compare
    l'empreinte prise après le Setup à celle prise après le Retrait : elles doivent être
    identiques (retrait exact). Les dates de changement de mot de passe sont exclues.
#>
[CmdletBinding()]
param([ValidateSet('SRV-01')][string]$Machine = 'SRV-01')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
$cfg = Get-ABConfig

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("EMP|machine|$Machine")
foreach ($s in $cfg.Partages) {
    if (-not (Test-Path -LiteralPath $s.Dossier)) { $lines.Add("EMP|absent|$($s.Dossier)"); continue }
    foreach ($a in Get-ABAclSnapshot -Path $s.Dossier) {
        $item = Get-Item -LiteralPath $a.Path -Force
        $size = ''
        if (-not $item.PSIsContainer) { $size = $item.Length }
        $lines.Add("EMP|acl|$($a.Path)|$($a.Protected)|$($a.Sddl)|$size|$($item.Attributes)")
    }
    $share = Get-SmbShare -Name $s.Nom -ErrorAction SilentlyContinue
    if ($share) { $lines.Add("EMP|partage|$($s.Nom)|$($share.Path)|$((Get-ABShareAccess -Name $s.Nom) -join ',')") }
}
foreach ($g in $cfg.Groupes.Keys | Sort-Object) {
    $grp = Get-LocalGroup -Name $g -ErrorAction SilentlyContinue
    if ($grp) { $lines.Add("EMP|groupe|$g|$((Get-ABGroupMemberSid -GroupSid $grp.SID.Value | Sort-Object) -join ',')") }
}
foreach ($e in $cfg.Employes) {
    $u = Get-LocalUser -Name $e.Compte -ErrorAction SilentlyContinue
    if (-not $u) { $lines.Add("EMP|compte|$($e.Compte)|absent"); continue }
    $lines.Add("EMP|compte|$($e.Compte)|$($u.Enabled)|$($null -eq $u.PasswordExpires)|$($u.UserMayChangePassword)|lab=$(Test-ABLocalPassword -UserName $e.Compte -Password $e.MotDePasse)")
}
$pol = Get-ABSecurityPolicy
$lines.Add("EMP|politique|$((@('MinimumPasswordLength','PasswordComplexity','PasswordHistorySize','LockoutBadCount','MaximumPasswordAge') | ForEach-Object { "$_=$($pol[$_])" }) -join ',')")
$lines.Add("EMP|etat|$([bool](Get-LabState -Scenario 'SRV-01'))")
$lines | ForEach-Object { Write-Output $_ }
