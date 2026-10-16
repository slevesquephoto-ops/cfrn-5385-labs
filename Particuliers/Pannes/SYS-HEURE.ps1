#requires -version 5.1
# SYS-HEURE : synchronisation automatique de l'heure coupée + date erronée (mauvaise manipulation du client), tout le poste.
# Voir Particuliers-Config.psd1. En VM, le service d'intégration Hyper-V recorrige l'horloge :
# on vérifie seulement la configuration (service W32Time et Type de synchronisation).
$svc = 'W32Time'
$key = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
$param = "$key\Parameters"
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{
            Start = Get-LabRegistrySnapshot -Path $key -Name 'Start'
            Type  = Get-LabRegistrySnapshot -Path $param -Name 'Type'
            Actif = ((Get-Service -Name $svc).Status -eq 'Running')
        }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        # Couper la synchronisation : service désactivé + Type NoSync (« Régler l'heure automatiquement » Off).
        Set-LabRegistryValue -Path $param -Name 'Type' -Value 'NoSync' -Type String
        if ((Get-Service -Name $svc).Status -eq 'Running') { Stop-Service -Name $svc -Force }
        $out = & sc.exe config $svc start= disabled
        if ($LASTEXITCODE -ne 0) { throw "sc.exe config $svc start= disabled : $out" }
        # Date reculée à 2016 (mauvaise manipulation) : avant la validité des certificats actuels ->
        # sur matériel réel, les sites HTTPS tombent en erreur de certificat et l'écart persiste (synchro coupée).
        Set-Date -Date '2016-01-01 08:00:00' | Out-Null
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        $mode = @{ 0 = 'boot'; 1 = 'system'; 2 = 'auto'; 3 = 'demand'; 4 = 'disabled' }[[int]$Etat.Start.Value]
        $out = & sc.exe config $svc start= $mode
        if ($LASTEXITCODE -ne 0) { throw "sc.exe config $svc start= $mode : $out" }
        Restore-LabRegistrySnapshot -Snapshot $Etat.Type
        if ($Etat.Actif) { Start-Service -Name $svc -ErrorAction SilentlyContinue }
        # Resynchroniser l'horloge (sans effet notable en VM, déjà corrigée par Hyper-V).
        & w32tm /resync /force 2>$null | Out-Null
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $start = (Get-LabRegistrySnapshot -Path $key -Name 'Start').Value
        $type = (Get-LabRegistrySnapshot -Path $param -Name 'Type').Value
        $coupe = ([int]$start -eq 4 -or "$type" -eq 'NoSync')
        $d = "synchro de l'heure : active (Type $type)"; if ($coupe) { $d = "synchro de l'heure : coupée (W32Time start $start, Type $type)" }
        @{ Ok = (-not $coupe); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
