#requires -version 5.1
# RES-DNS : serveurs DNS manuels invalides sur la ou les cartes Internet (tout le poste).
$bad = @('203.0.113.9', '203.0.113.10')   # TEST-NET-3 (RFC 5737) : routables nulle part
$ifKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Cartes = @(Get-PartNetAdapter | ForEach-Object {
                    [pscustomobject]@{ Index = $_.Index; Nom = $_.Nom
                        NameServer = (Get-LabRegistrySnapshot -Path (Join-Path $ifKey $_.Guid) -Name 'NameServer')
                    } }) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($c in @($Etat.Cartes)) { Set-DnsClientServerAddress -InterfaceIndex $c.Index -ServerAddresses $bad }
        Clear-DnsClientCache
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($c in @($Etat.Cartes)) {
            $ns = $c.NameServer
            if ($ns.Exists -and $ns.Value) { Set-DnsClientServerAddress -InterfaceIndex $c.Index -ServerAddresses ($ns.Value -split '[ ,]+') }
            else { Set-DnsClientServerAddress -InterfaceIndex $c.Index -ResetServerAddresses }
        }
        Clear-DnsClientCache
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $touche = @()
        foreach ($c in Get-PartNetAdapter) {
            $dns = @((Get-DnsClientServerAddress -InterfaceIndex $c.Index -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
            if ($dns | Where-Object { $bad -contains $_ }) { $touche += $c.Nom }
        }
        $d = 'DNS normal'; if ($touche) { $d = "DNS invalide sur $($touche -join ', ')" }
        @{ Ok = (-not $touche); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
