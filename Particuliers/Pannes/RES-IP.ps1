#requires -version 5.1
# RES-IP : adresse IP fixe dans le mauvais sous-réseau (tout le poste). Restauration DHCP
# (cas courant d'un particulier) ou adresse fixe d'origine.
$badIp = '10.73.254.9'; $badPrefix = 24
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        $cartes = foreach ($a in Get-PartNetAdapter) {
            $dhcp = (Get-NetIPInterface -InterfaceIndex $a.Index -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
            $ip = Get-NetIPAddress -InterfaceIndex $a.Index -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1
            $gw = Get-NetRoute -InterfaceIndex $a.Index -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1
            $adr = $null; $pfx = $null; $pas = $null
            if ($ip) { $adr = $ip.IPAddress; $pfx = $ip.PrefixLength }
            if ($gw) { $pas = $gw.NextHop }
            [pscustomobject]@{ Index = $a.Index; Nom = $a.Nom; Dhcp = "$dhcp"; Adresse = $adr; Prefixe = $pfx; Passerelle = $pas }
        }
        @{ Cartes = @($cartes) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($c in @($Etat.Cartes)) {
            Get-NetIPAddress -InterfaceIndex $c.Index -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Remove-NetIPAddress -Confirm:$false
            Get-NetRoute -InterfaceIndex $c.Index -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false
            Set-NetIPInterface -InterfaceIndex $c.Index -AddressFamily IPv4 -Dhcp Disabled
            New-NetIPAddress -InterfaceIndex $c.Index -AddressFamily IPv4 -IPAddress $badIp -PrefixLength $badPrefix | Out-Null
        }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($c in @($Etat.Cartes)) {
            Get-NetIPAddress -InterfaceIndex $c.Index -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $badIp } | Remove-NetIPAddress -Confirm:$false
            if ($c.Dhcp -eq 'Enabled') {
                Set-NetIPInterface -InterfaceIndex $c.Index -AddressFamily IPv4 -Dhcp Enabled
                Set-DnsClientServerAddress -InterfaceIndex $c.Index -ResetServerAddresses
                & ipconfig.exe /renew | Out-Null
            } elseif ($c.Adresse) {
                New-NetIPAddress -InterfaceIndex $c.Index -AddressFamily IPv4 -IPAddress $c.Adresse -PrefixLength $c.Prefixe -DefaultGateway $c.Passerelle | Out-Null
            }
        }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $touche = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $badIp })
        $d = 'adressage normal'; if ($touche) { $d = "IP fixe erronée : $badIp" }
        @{ Ok = (-not $touche); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
