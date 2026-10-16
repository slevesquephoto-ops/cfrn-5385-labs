#requires -version 5.1
# SYS-DEMARRAGE : ouverture de session lente et désagréable (profil + machine).
# Voir Particuliers-Config.psd1. Plusieurs emplacements de démarrage à trouver, répartis entre
# des outils différents pour forcer l'élève à chercher au-delà du seul Gestionnaire des tâches :
#   - clé Run du profil (HKCU), DEUX valeurs ;
#   - clé Run de la machine (HKLM), UNE valeur qui lance une charge CPU bornée (session poussive) ;
#   - un fichier dans le dossier Démarrage du profil ;
#   - une tâche planifiée à l'ouverture de session.
# Noms d'apparence normale (règle de discrétion). Toutes les charges sont inoffensives et bornées
# dans le temps (elles se terminent seules), le retrait supprime chaque élément et chaque fichier.
$runRel      = 'Software\Microsoft\Windows\CurrentVersion\Run'
$runNom1     = 'MediaAgent'
$runNom2     = 'UpdateNotifier'
$hklmRun     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$hklmNom     = 'CloudSyncHelper'
$tache       = 'MediaLibraryIndexer'
$vbsRel      = 'AppData\Local\MediaAgent\agent.vbs'                                              # profil, caché
$startupRel  = 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\SyncCheck.vbs'     # profil, dossier Démarrage
$machineDir  = Join-Path $env:ProgramData 'MediaAgent'
$machineScript = Join-Path $machineDir 'sync-agent.ps1'
# Charge CPU bornée (~75 s) : la session reste utilisable mais nettement poussive au démarrage.
$chargeScript = @'
$fin = (Get-Date).AddSeconds(75)
while ((Get-Date) -lt $fin) { $null = [math]::Sqrt([double](Get-Random)) }
'@
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $vbs = Join-Path $Ctx.Profil $vbsRel
        $startup = Join-Path $Ctx.Profil $startupRel
        $vbsDir = Split-Path -Parent $vbs
        @{
            Run1        = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom1
            Run2        = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom2
            RunHKLM     = Get-LabRegistrySnapshot -Path $hklmRun -Name $hklmNom
            Vbs         = $vbs
            VbsDir      = $vbsDir
            VbsDirCree  = (-not (Test-Path -LiteralPath $vbsDir))
            Startup     = $startup
            StartupCree = (-not (Test-Path -LiteralPath $startup))
            MachineDir  = $machineDir
            MachineScript = $machineScript
            MachineDirCree = (-not (Test-Path -LiteralPath $machineDir))
        }
    }
    Installer = {
        param($Ctx, $Etat)
        # Fichiers de charge (profil + machine)
        if (-not (Test-Path -LiteralPath $Etat.VbsDir)) { New-Item -ItemType Directory -Path $Etat.VbsDir -Force | Out-Null }
        Set-Content -LiteralPath $Etat.Vbs -Value 'WScript.Sleep 20000' -Encoding ASCII
        (Get-Item -LiteralPath $Etat.Vbs -Force).Attributes = 'Hidden'
        Set-Content -LiteralPath $Etat.Startup -Value 'WScript.Sleep 15000' -Encoding ASCII
        if (-not (Test-Path -LiteralPath $Etat.MachineDir)) { New-Item -ItemType Directory -Path $Etat.MachineDir -Force | Out-Null }
        Set-Content -LiteralPath $Etat.MachineScript -Value $chargeScript -Encoding ASCII
        # Clé Run du profil : deux valeurs
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $runRel) -Name $runNom1 -Value ('wscript.exe "{0}"' -f $Etat.Vbs) -Type String
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $runRel) -Name $runNom2 -Value 'powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 30"' -Type String
        # Clé Run de la machine : charge CPU bornée
        Set-LabRegistryValue -Path $hklmRun -Name $hklmNom -Value ('powershell.exe -NoProfile -WindowStyle Hidden -File "{0}"' -f $Etat.MachineScript) -Type String
        # Tâche planifiée au logon : attente supplémentaire (effet « indexation »)
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 45"'
        $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $set = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $tache -Action $action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Principal $pr -Settings $set -Force | Out-Null
    }
    Retirer = {
        param($Ctx, $Etat)
        Restore-PartUserValue -Root $Ctx.Root -Snapshot $Etat.Run1
        Restore-PartUserValue -Root $Ctx.Root -Snapshot $Etat.Run2
        Restore-LabRegistrySnapshot -Snapshot $Etat.RunHKLM
        Unregister-ScheduledTask -TaskName $tache -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $Etat.Vbs) { Remove-Item -LiteralPath $Etat.Vbs -Force }
        if ($Etat.StartupCree -and (Test-Path -LiteralPath $Etat.Startup)) { Remove-Item -LiteralPath $Etat.Startup -Force }
        if (Test-Path -LiteralPath $Etat.MachineScript) { Remove-Item -LiteralPath $Etat.MachineScript -Force }
        if ($Etat.VbsDirCree -and (Test-Path -LiteralPath $Etat.VbsDir) -and -not @(Get-ChildItem -LiteralPath $Etat.VbsDir -Force)) {
            Remove-Item -LiteralPath $Etat.VbsDir -Force
        }
        if ($Etat.MachineDirCree -and (Test-Path -LiteralPath $Etat.MachineDir) -and -not @(Get-ChildItem -LiteralPath $Etat.MachineDir -Force)) {
            Remove-Item -LiteralPath $Etat.MachineDir -Force
        }
    }
    Tester = {
        param($Ctx)
        $run1 = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom1
        $run2 = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom2
        $hklm = Get-LabRegistrySnapshot -Path $hklmRun -Name $hklmNom
        $t = [bool](Get-ScheduledTask -TaskName $tache -ErrorAction SilentlyContinue)
        $vbs = Test-Path -LiteralPath (Join-Path $Ctx.Profil $vbsRel)
        $startup = Test-Path -LiteralPath (Join-Path $Ctx.Profil $startupRel)
        $script = Test-Path -LiteralPath $machineScript
        $present = ($run1.Exists -or $run2.Exists -or $hklm.Exists -or $t -or $vbs -or $startup -or $script)
        $n = @()
        if ($run1.Exists -or $run2.Exists) { $n += 'Run(profil)' }
        if ($hklm.Exists) { $n += 'Run(machine)' }
        if ($startup) { $n += 'dossier Démarrage' }
        if ($t) { $n += 'tâche' }
        $d = 'démarrage : aucun élément inutile'; if ($present) { $d = "démarrage : éléments inutiles ($($n -join ', '))" }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
