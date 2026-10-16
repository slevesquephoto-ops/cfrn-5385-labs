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
    [Parameter(Mandatory)][ValidateSet('Empreinte', 'Comptes', 'Proxy', 'Marque', 'Profils', 'Redemarrer')][string]$Mode,
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
    'Marque' {
        $f = Join-Path (Get-PartProfilePath -Compte $Client) 'Documents\Notes du technicien.txt'
        $existait = Test-Path -LiteralPath $f
        if (-not $existait) { Set-Content -LiteralPath $f -Value 'Travail en cours' -Encoding UTF8 }
        "MARQUE|$existait"
    }
    'Empreinte' {
        foreach ($u in Get-LocalUser) { "EMP|compte|$($u.Name)|$($u.Enabled)" }
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Services\Audiosrv'
        foreach ($n in 'Start', 'DelayedAutostart') { $s = Get-LabRegistrySnapshot -Path $k -Name $n; "EMP|audiosrv|$n|$($s.Exists)|$($s.Value)" }
        "EMP|audiosrv|etat|$((Get-Service Audiosrv).Status)"
        $is = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        $vals = @(
            @($is, 'ProxyEnable'), @($is, 'ProxyServer'), @($is, 'ProxyOverride'),
            @("$is\Connections", 'DefaultConnectionSettings'), @("$is\Connections", 'SavedLegacySettings'),
            @('Control Panel\Mouse', 'SwapMouseButtons')
        )
        if (Get-LocalUser -Name $Client -ErrorAction SilentlyContinue) {
            $hive = Mount-LabUserHive -UserName $Client
            try {
                foreach ($v in $vals) {
                    $s = Get-PartUserValue -Root $hive.Root -Key $v[0] -Name $v[1]
                    "EMP|ruche|$($v[0])|$($v[1])|$($s.Exists)|$($s.Type)|$($s.Value)"
                }
            } finally { Dismount-LabUserHive -Hive $hive }
        } else { "EMP|ruche|client absent" }
    }
}
