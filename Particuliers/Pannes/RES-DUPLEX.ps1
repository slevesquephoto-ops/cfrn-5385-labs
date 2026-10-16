#requires -version 5.1
# RES-DUPLEX : carte réseau forcée en 10 Mbps half-duplex au lieu de l'auto-négociation (tout le poste).
# Voir Particuliers-Config.psd1. Crée des lenteurs réseau marquées. VRAI MATÉRIEL seulement : la carte
# virtuelle Hyper-V n'expose pas la propriété Vitesse/Duplex, la panne refuse alors de s'installer.
# Scriptblock capturé en variable (pas de fonction nommée : le scope du fichier a disparu à l'appel des blocs).
$prop = {
    # Propriété Vitesse/Duplex de la carte Internet, ou $null si la carte ne l'expose pas.
    $nic = @(Get-PartNetAdapter)[0]
    if (-not $nic) { return $null }
    Get-NetAdapterAdvancedProperty -Name $nic.Nom -RegistryKeyword '*SpeedDuplex' -ErrorAction SilentlyContinue
}
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        $p = & $prop
        if (-not $p) { throw "Carte sans propriété Vitesse/Duplex (carte virtuelle?) : RES-DUPLEX non applicable sur ce poste." }
        @{ Nic = $p.Name; Valeur = "$($p.RegistryValue)" }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        $p = & $prop
        $cible = @($p.ValidDisplayValues | Where-Object { $_ -match '10' -and $_ -match 'Half' })[0]
        if (-not $cible) { throw "Aucune valeur « 10 Mbps Half Duplex » sur cette carte ($($p.DisplayName))." }
        Set-NetAdapterAdvancedProperty -Name $Etat.Nic -RegistryKeyword '*SpeedDuplex' -DisplayValue $cible
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        # Rétablir la valeur d'origine (0 = auto-négociation sur l'immense majorité des cartes).
        Set-NetAdapterAdvancedProperty -Name $Etat.Nic -RegistryKeyword '*SpeedDuplex' -RegistryValue $Etat.Valeur
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $p = & $prop
        if (-not $p) { return @{ Ok = $true; Detail = 'carte sans propriété Vitesse/Duplex' } }
        $auto = ("$($p.RegistryValue)" -eq '0' -or $p.DisplayValue -match 'Auto')
        @{ Ok = $auto; Detail = "Vitesse/Duplex : $($p.DisplayValue)" }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
