#requires -version 5.1
# SYS-USB : stockage de masse USB désactivé (service USBSTOR, tout le poste). Voir Particuliers-Config.psd1.
# Les claviers/souris USB (HID) restent fonctionnels : seules les clés et disques USB ne montent plus.
$key = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR'
$name = 'Start'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Start = Get-LabRegistrySnapshot -Path $key -Name $name }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        Set-LabRegistryValue -Path $key -Name $name -Value 4 -Type DWord   # 4 = désactivé
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        Restore-LabRegistrySnapshot -Snapshot $Etat.Start
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $v = Get-LabRegistrySnapshot -Path $key -Name $name
        $off = ($v.Exists -and [int]$v.Value -eq 4)
        $d = "stockage USB : démarrage $($v.Value)"; if ($off) { $d = 'stockage USB : désactivé (USBSTOR Start = 4)' }
        @{ Ok = (-not $off); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
