#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exécuté DANS la VM par tests\Test-ABSession.ps1 : étapes de la preuve d'ouverture de session.

.DESCRIPTION
    Preparer          Ouverture de session automatique UNE fois (mot de passe LAB, règle 8)
    Redemarrer        Redémarrage dans 5 s
    Preuves           Ligne JSON : session, explorer.exe, profil (non temporaire), écrans
                      d'accueil, fond d'écran et lecteurs dans la ruche chargée
    LancerLibreOffice Lance LibreOffice Writer DANS la session de l'employé (tâche interactive)
    Nettoyer          Ferme la session, retire l'ouverture automatique et le mot de passe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Preparer', 'Redemarrer', 'Preuves', 'LancerLibreOffice', 'Nettoyer')][string]$Etape,
    [Parameter(Mandatory)][string]$Compte
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
$emp = (Get-ABConfig).Employes | Where-Object { $_.Compte -eq $Compte }
$wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

switch ($Etape) {
    'Preparer' {
        Set-ItemProperty $wl -Name AutoAdminLogon -Value '1'
        Set-ItemProperty $wl -Name DefaultUserName -Value $Compte
        Set-ItemProperty $wl -Name DefaultDomainName -Value $env:COMPUTERNAME
        Set-ItemProperty $wl -Name DefaultPassword -Value $emp.MotDePasse
        New-ItemProperty $wl -Name AutoLogonCount -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Output 'Ouverture automatique prête (une fois).'
    }
    'Redemarrer' { & shutdown.exe /r /t 5 /c 'Preuve d''ouverture de session'; Write-Output 'Redémarrage dans 5 s.' }
    'Preuves' {
        $sid = (Get-LocalUser -Name $Compte).SID.Value
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $explorer = @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | ForEach-Object {
                $o = Invoke-CimMethod -InputObject $_ -MethodName GetOwner; "$($o.Domain)\$($o.User) (session $($_.SessionId))" })
        $prof = Get-CimInstance Win32_UserProfile -Filter "SID='$sid'"
        $temp = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Microsoft-Windows-User Profiles Service'; StartTime = $boot } -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -in 1511, 1515, 1508, 1500 } | ForEach-Object { $_.Id })
        $live = "Registry::HKEY_USERS\$sid"
        $drives = @()
        if (Test-Path "$live\Network") { $drives = @(Get-ChildItem "$live\Network" | ForEach-Object { "$($_.PSChildName): $((Get-ItemProperty $_.PSPath).RemotePath)" }) }
        [pscustomobject]@{
            sessions        = @(& quser.exe 2>$null | Select-Object -Skip 1 | ForEach-Object { $_.Trim() })
            explorer        = $explorer
            profil          = $prof.LocalPath
            charge          = [bool]$prof.Loaded
            evenementsTemp  = $temp
            accueil         = @(Get-Process -Name FirstLogonAnim -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
            fondEcran       = (Get-ItemProperty "$live\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue).Wallpaper
            lecteurs        = $drives
            motDePasseAuto  = [bool](Get-ItemProperty $wl).DefaultPassword
        } | ConvertTo-Json -Compress | Write-Output
    }
    'LancerLibreOffice' {
        $exe = Get-ChildItem 'C:\Program Files\LibreOffice\program' -Filter soffice.exe | Select-Object -First 1
        $name = 'CFRN-Lab-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
        # Tâche interactive : s'exécute dans la session ouverte de l'employé (aucun mot de passe)
        $principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$Compte" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $name -Action (New-ScheduledTaskAction -Execute $exe.FullName -Argument '--writer') -Principal $principal -Force | Out-Null
        Start-ScheduledTask -TaskName $name
        Start-Sleep -Seconds 3
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Output 'LibreOffice Writer lancé dans la session.'
    }
    'Nettoyer' {
        Close-ABUserSession -Compte $Compte
        Set-ItemProperty $wl -Name AutoAdminLogon -Value '0'
        foreach ($n in 'DefaultPassword', 'AutoLogonCount') { Remove-ItemProperty $wl -Name $n -ErrorAction SilentlyContinue }
        Write-Output "Nettoyé : DefaultPassword présent = $([bool](Get-ItemProperty $wl).DefaultPassword)"
    }
}
