#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    TESTS SEULEMENT (exécuté dans une VM de poste) : IP fixe du poste sur AB-Lab-Interne.

.DESCRIPTION
    En classe, les postes reçoivent leur adresse par réservation DHCP du routeur AB
    (192.168.50.21 à .24). En VM, le commutateur interne n'a pas de DHCP : ce script
    donne au poste l'adresse que le routeur lui réserverait, et classe le réseau Privé.
    Les scripts de production (AB\PC-0x) ne touchent jamais à l'IP des postes.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('PC-01', 'PC-02', 'PC-03', 'PC-04')][string]$Poste)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $root 'AB\AB-Lab.psm1') -Force
$cfg = Get-ABConfig
if ($env:COMPUTERNAME -ne "AB-$Poste") { throw "Prévu pour AB-$Poste (poste actuel : $env:COMPUTERNAME)." }

$ip = $cfg.Reseau.Machines[$Poste]
$adapter = @(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' })
if ($adapter.Count -ne 1) { throw "Il faut exactement une carte réseau active (trouvé : $($adapter.Count))." }
$idx = $adapter[0].ifIndex
if (-not (Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -IPAddress $ip -ErrorAction SilentlyContinue)) {
    Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
    New-NetIPAddress -InterfaceIndex $idx -IPAddress $ip -PrefixLength $cfg.Reseau.Prefixe -DefaultGateway $cfg.Reseau.Passerelle | Out-Null
}
Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $cfg.Reseau.Dns
$deadline = (Get-Date).AddSeconds(120)
while ($true) {
    try {
        $prof = Get-NetConnectionProfile -InterfaceIndex $idx -ErrorAction Stop
        if ($prof.NetworkCategory -ne 'Private') { Set-NetConnectionProfile -InterfaceIndex $idx -NetworkCategory Private -ErrorAction Stop }
        break
    } catch {
        if ((Get-Date) -gt $deadline) { throw "Profil réseau non classé Privé après 2 min." }
        Start-Sleep -Seconds 5
    }
}
Write-Output "AB-$Poste : $ip/$($cfg.Reseau.Prefixe), réseau Privé."
