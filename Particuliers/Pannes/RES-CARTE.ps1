#requires -version 5.1
# RES-CARTE : carte réseau désactivée (tout le poste). En VM, PowerShell Direct passe par le
# bus (pas le réseau), donc la panne se teste sans perdre la main.
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Cartes = @(Get-PartNetAdapter | ForEach-Object { $_.Nom }) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($n in @($Etat.Cartes)) { Disable-NetAdapter -Name $n -Confirm:$false }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($n in @($Etat.Cartes)) { Enable-NetAdapter -Name $n -Confirm:$false }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $off = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface -and $_.Status -eq 'Disabled' } | ForEach-Object { $_.Name })
        $d = 'cartes actives'; if ($off) { $d = "carte désactivée : $($off -join ', ')" }
        @{ Ok = (-not $off); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
