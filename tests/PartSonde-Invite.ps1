#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Sonde des pannes spontanées, exécutée DANS la VM par Test-Particuliers.ps1.

.DESCRIPTION
    -Mode Empreinte : une ligne « EMP|... » par réglage touché par les pannes (ruche du
                      client, service audio, comptes locaux). Comparée avant la première
                      panne et après le dernier retrait : identique = retrait exact.
    -Mode Comptes   : « CPT|nom|activé » pour chaque compte local.
    -Mode Proxy     : proxy réellement vu par le client (tâche sous son identité) :
                      « PROXY|<uri> » (http://example.com/ = aucun proxy).
    -Mode Profils   : « DIR|<dossier> » de C:\Users et « PRF|<chemin>|<chargé> » des profils.
    -Mode Redemarrer: redémarre la VM dans 5 s (Test-Particuliers attend son retour).
    -Mode Marque    : simule le travail d'un élève dans le profil (Documents\Notes du
                      technicien.txt) : « MARQUE|<existait déjà> », créée si absente.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Empreinte', 'Comptes', 'Proxy', 'Marque', 'Profils', 'Redemarrer', 'Defender', 'EicarForceDrop', 'EicarGuard')][string]$Mode,
    [string]$Client = 'mbelanger'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
Import-Module (Join-Path $root 'Particuliers\Particuliers-Lab.psm1') -Force

switch ($Mode) {
    'Comptes' {
        foreach ($u in Get-LocalUser) { "CPT|$($u.Name)|$($u.Enabled)" }
    }
    'Proxy' {
        $pw = (Get-PartClient -Compte $Client).MotDePasse
        $cmd = 'powershell.exe -NoProfile -Command "[System.Net.WebRequest]::GetSystemWebProxy().GetProxy(''http://example.com/'').AbsoluteUri"'
        $r = Invoke-ABAsUserCommand -Compte $Client -Password $pw -Command $cmd
        "PROXY|$(($r.Output | Where-Object { $_ } | Select-Object -Last 1))"
    }
    'Profils' {
        foreach ($d in Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force) { "DIR|$($d.Name)" }
        foreach ($p in Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special }) { "PRF|$($p.LocalPath)|$($p.Loaded)" }
    }
    'Redemarrer' {
        & shutdown.exe /r /t 5 /f
        'REDEMARRAGE|ok'
    }
    'EicarForceDrop' {
        # Dépôt EICAR inconditionnel (hors garde console) : sert UNIQUEMENT à tester la réaction de
        # l'antivirus / la survie du fichier. La garde « client seulement » est vérifiée par EicarGuard.
        Write-PartEicarFile
        "EICARDROP|$(Test-Path -LiteralPath (Join-Path $env:ProgramData 'MediaCache\update.bin'))"
    }
    'EicarGuard' {
        # Exécute le générateur déposé TEL QUEL. Sous PowerShell Direct / ab-tech (pas le client au
        # console), il ne doit RIEN déposer. On nettoie un éventuel dépôt préalable d'abord.
        $drop = Join-Path $env:ProgramData 'MediaCache\update.bin'
        if (Test-Path -LiteralPath $drop) { Remove-Item -LiteralPath $drop -Force -ErrorAction SilentlyContinue }
        $gen = Join-Path $env:ProgramData 'Microsoft\DeviceSync\sync-store.ps1'
        if (Test-Path -LiteralPath $gen) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gen; Start-Sleep -Seconds 1 }
        "EICARGUARD|$(Test-Path -LiteralPath $drop)"
    }
    'Defender' {
        try {
            $s = Get-MpComputerStatus -ErrorAction Stop
            "DEF|tamper|$($s.IsTamperProtected)"
            "DEF|realtime|$($s.RealTimeProtectionEnabled)"
        } catch { "DEF|status|indisponible : $($_.Exception.Message)" }
        "DEF|tache|$((Test-PartEicarPersistence).Tache)"
        "DEF|generateur|$((Test-PartEicarPersistence).Generateur)"
        "DEF|drop|$(Test-Path -LiteralPath (Join-Path $env:ProgramData 'MediaCache\update.bin'))"
        "DEF|exclusion|$(Test-PartDefenderExclusion)"
        foreach ($t in @(Get-MpThreat -ErrorAction SilentlyContinue)) { "DEF|threat|$($t.ThreatName)" }
    }
    'Marque' {
        $f = Join-Path (Get-PartProfilePath -Compte $Client) 'Documents\Notes du technicien.txt'
        $existait = Test-Path -LiteralPath $f
        if (-not $existait) { Set-Content -LiteralPath $f -Value 'Travail en cours' -Encoding UTF8 }
        "MARQUE|$existait"
    }
    'Empreinte' {
        foreach ($u in Get-LocalUser) { "EMP|compte|$($u.Name)|$($u.Enabled)" }
        $hostsFile = Join-Path $env:windir 'System32\drivers\etc\hosts'
        if (Test-Path -LiteralPath $hostsFile) { "EMP|hosts|$((Get-FileHash -LiteralPath $hostsFile -Algorithm SHA256).Hash)" } else { 'EMP|hosts|absent' }
        "EMP|parefeu|$([bool](Get-NetFirewallRule -DisplayName 'Microsoft Edge (connexions sortantes)' -ErrorAction SilentlyContinue))"
        $p = Test-PartEicarPersistence
        "EMP|eicar|tache|$($p.Tache)|gen|$($p.Generateur)|exclusion|$(Test-PartDefenderExclusion)"
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Services\Audiosrv'
        foreach ($n in 'Start', 'DelayedAutostart') { $s = Get-LabRegistrySnapshot -Path $k -Name $n; "EMP|audiosrv|$n|$($s.Exists)|$($s.Value)" }
        "EMP|audiosrv|etat|$((Get-Service Audiosrv).Status)"
        $spk = 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler'
        foreach ($n in 'Start', 'DelayedAutostart') { $s = Get-LabRegistrySnapshot -Path $spk -Name $n; "EMP|spooler|$n|$($s.Exists)|$($s.Value)" }
        "EMP|spooler|etat|$((Get-Service Spooler).Status)"
        $w32 = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
        "EMP|w32time|Start|$((Get-LabRegistrySnapshot -Path $w32 -Name 'Start').Value)"
        "EMP|w32time|Type|$((Get-LabRegistrySnapshot -Path "$w32\Parameters" -Name 'Type').Value)"
        $bcd = & bcdedit /enum '{current}' 2>$null
        "EMP|bcd|safeboot|$([bool]($bcd | Where-Object { $_ -match '^\s*safeboot\s+\S' }))"
        "EMP|bcd|truncatememory|$([bool]($bcd | Where-Object { $_ -match '^\s*truncatememory\s+\S' }))"
        "EMP|usbstor|Start|$((Get-LabRegistrySnapshot -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR' -Name 'Start').Value)"
        "EMP|run|CloudSyncHelper|$((Get-LabRegistrySnapshot -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'CloudSyncHelper').Exists)"
        "EMP|tache|MediaLibraryIndexer|$([bool](Get-ScheduledTask -TaskName 'MediaLibraryIndexer' -ErrorAction SilentlyContinue))"
        "EMP|tache|SystemUpdateFinalize|$([bool](Get-ScheduledTask -TaskName 'SystemUpdateFinalize' -ErrorAction SilentlyContinue))"
        "EMP|tache|OptimiseurPCProAlerte|$([bool](Get-ScheduledTask -TaskName 'OptimiseurPCProAlerte' -ErrorAction SilentlyContinue))"
        "EMP|edge|home|$((Get-LabRegistrySnapshot -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'HomepageLocation').Exists)"
        "EMP|edge|search|$((Get-LabRegistrySnapshot -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'DefaultSearchProviderName').Exists)"
        "EMP|pup|uninstall|$([bool](Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OptimiseurPCPro'))"
        "EMP|fichier|rechercheexpress|$(Test-Path -LiteralPath (Join-Path $env:ProgramData 'RechercheExpress\recherche-express.html'))"
        "EMP|fichier|optimiseur|$(Test-Path -LiteralPath (Join-Path $env:ProgramData 'OptimiseurPCPro\alerte.html'))"
        "EMP|defender|exclC|$(try { @((Get-MpPreference -ErrorAction Stop).ExclusionPath) -contains 'C:\' } catch { 'na' })"
        "EMP|fichier|syncagent|$(Test-Path -LiteralPath (Join-Path $env:ProgramData 'MediaAgent\sync-agent.ps1'))"
        $is = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        $vals = @(
            @($is, 'ProxyEnable'), @($is, 'ProxyServer'), @($is, 'ProxyOverride'),
            @("$is\Connections", 'DefaultConnectionSettings'), @("$is\Connections", 'SavedLegacySettings'),
            @('Control Panel\Mouse', 'SwapMouseButtons'),
            @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoDesktop'),
            @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoControlPanel'),
            @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoClose'),
            @('Software\Policies\Microsoft\Windows\System', 'DisableCMD'),
            @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoRun'),
            @('Software\Microsoft\Windows\CurrentVersion\Policies\System', 'DisableTaskMgr'),
            @('Software\Microsoft\Windows\CurrentVersion\Run', 'MediaAgent'),
            @('Software\Microsoft\Windows\CurrentVersion\Run', 'UpdateNotifier'),
            @('Software\Microsoft\Windows\CurrentVersion\Run', 'MediaTools'),
            @('Software\Microsoft\Windows\CurrentVersion\Run', 'OptimiseurPC Pro'),
            @('Keyboard Layout\Preload', '1'), @('Keyboard Layout\Preload', '2'),
            @('Keyboard Layout\Preload', '3'), @('Keyboard Layout\Preload', '4'),
            @('Keyboard Layout\Preload', '5'), @('Keyboard Layout\Preload', '6'),
            @('Control Panel\Accessibility\Keyboard Response', 'Flags'),
            @('Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders', 'Personal'),
            @('Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Personal')
        )
        if (Get-LocalUser -Name $Client -ErrorAction SilentlyContinue) {
            $hive = Mount-LabUserHive -UserName $Client
            try {
                foreach ($v in $vals) {
                    $s = Get-PartUserValue -Root $hive.Root -Key $v[0] -Name $v[1]
                    "EMP|ruche|$($v[0])|$($v[1])|$($s.Exists)|$($s.Type)|$($s.Value)"
                }
            } finally { Dismount-LabUserHive -Hive $hive }
            $gsid = (Get-ABSid -Name 'Administrateurs').Value
            $csid = (Get-LocalUser -Name $Client).SID.Value
            "EMP|admin|$Client|$([bool]((Get-ABGroupMemberSid -GroupSid $gsid) -contains $csid))"
            "EMP|profillist|$([bool](Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$csid"))"
            $prof = Get-PartProfilePath -Compte $Client
            if ($prof) {
                "EMP|fichier|cache|$(Test-Path -LiteralPath (Join-Path $prof 'AppData\Local\Temp\MediaCache\cache.dat'))"
                "EMP|fichier|agent|$(Test-Path -LiteralPath (Join-Path $prof 'AppData\Local\MediaAgent\agent.vbs'))"
                "EMP|fichier|startup|$(Test-Path -LiteralPath (Join-Path $prof 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\SyncCheck.vbs'))"
                "EMP|fichier|boucle|$(Test-Path -LiteralPath (Join-Path $prof 'AppData\Local\MediaTools\run.ps1'))"
                foreach ($c in 'Documents', 'Pictures', 'Desktop', 'Downloads') {
                    $pp = Join-Path $prof $c
                    if (Test-Path -LiteralPath $pp) { "EMP|attr|$c|$([int](Get-Item -LiteralPath $pp -Force).Attributes)" } else { "EMP|attr|$c|absent" }
                }
            }
        } else { "EMP|ruche|client absent" }
    }
}
