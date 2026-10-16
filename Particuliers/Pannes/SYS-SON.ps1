#requires -version 5.1
# SYS-SON : service Audio Windows (Audiosrv) arrêté et désactivé (tout le poste).
$svc = 'Audiosrv'
$key = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{
            Start   = Get-LabRegistrySnapshot -Path $key -Name 'Start'
            Delayed = Get-LabRegistrySnapshot -Path $key -Name 'DelayedAutostart'
            Actif   = ((Get-Service -Name $svc).Status -eq 'Running')
        }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        Stop-Service -Name $svc -Force
        Set-Service -Name $svc -StartupType Disabled
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        # Par sc.exe, pas par le registre : le gestionnaire de services garde sa configuration
        # en mémoire et refuserait de démarrer un service qu'il croit encore désactivé (vu en VM).
        $mode = @{ 0 = 'boot'; 1 = 'system'; 2 = 'auto'; 3 = 'demand'; 4 = 'disabled' }[[int]$Etat.Start.Value]
        if ($mode -eq 'auto' -and $Etat.Delayed.Exists -and [int]$Etat.Delayed.Value -eq 1) { $mode = 'delayed-auto' }
        $out = & sc.exe config $svc start= $mode
        if ($LASTEXITCODE -ne 0) { throw "sc.exe config $svc start= $mode : $out" }
        Restore-LabRegistrySnapshot -Snapshot $Etat.Delayed
        if ($Etat.Actif) { Start-Service -Name $svc }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $s = Get-Service -Name $svc
        $start = (Get-LabRegistrySnapshot -Path $key -Name 'Start').Value
        $off = ($start -eq 4)
        @{ Ok = (-not $off); Detail = "Audio Windows : démarrage $($s.StartType), $($s.Status)" }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
