#requires -version 5.1
# SYS-DEMARRAGE : éléments de démarrage inutiles qui ralentissent l'ouverture de session (profil + machine).
# Voir Particuliers-Config.psd1. Trois emplacements distincts à trouver : clé Run du profil (HKCU),
# clé Run de la machine (HKLM) et tâche planifiée. Rien de nuisible : de petits délais inertes.
# Noms d'apparence normale (règle de discrétion). Charges inoffensives (Start-Sleep).
$runRel = 'Software\Microsoft\Windows\CurrentVersion\Run'
$runNom = 'MediaAgent'
$hklmRun = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$hklmNom = 'CloudSyncHelper'
$tache = 'MediaLibraryIndexer'
$scriptRel = 'AppData\Local\MediaAgent\agent.vbs'
$charge = 'powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 10"'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $dossier = Split-Path -Parent (Join-Path $Ctx.Profil $scriptRel)
        @{
            RunHKCU     = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom
            RunHKLM     = Get-LabRegistrySnapshot -Path $hklmRun -Name $hklmNom
            Script      = (Join-Path $Ctx.Profil $scriptRel)
            Dossier     = $dossier
            DossierCree = (-not (Test-Path -LiteralPath $dossier))
        }
    }
    Installer = {
        param($Ctx, $Etat)
        if (-not (Test-Path -LiteralPath $Etat.Dossier)) { New-Item -ItemType Directory -Path $Etat.Dossier -Force | Out-Null }
        Set-Content -LiteralPath $Etat.Script -Value 'WScript.Sleep 15000' -Encoding ASCII
        (Get-Item -LiteralPath $Etat.Script -Force).Attributes = 'Hidden'
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $runRel) -Name $runNom -Value ('wscript.exe "{0}"' -f $Etat.Script) -Type String
        Set-LabRegistryValue -Path $hklmRun -Name $hklmNom -Value $charge -Type String
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 10"'
        $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $set = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $tache -Action $action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Principal $pr -Settings $set -Force | Out-Null
    }
    Retirer = {
        param($Ctx, $Etat)
        Restore-PartUserValue -Root $Ctx.Root -Snapshot $Etat.RunHKCU
        Restore-LabRegistrySnapshot -Snapshot $Etat.RunHKLM
        Unregister-ScheduledTask -TaskName $tache -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $Etat.Script) { Remove-Item -LiteralPath $Etat.Script -Force }
        if ($Etat.DossierCree -and (Test-Path -LiteralPath $Etat.Dossier) -and -not @(Get-ChildItem -LiteralPath $Etat.Dossier -Force)) {
            Remove-Item -LiteralPath $Etat.Dossier -Force
        }
    }
    Tester = {
        param($Ctx)
        $hkcu = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom
        $hklm = Get-LabRegistrySnapshot -Path $hklmRun -Name $hklmNom
        $t = [bool](Get-ScheduledTask -TaskName $tache -ErrorAction SilentlyContinue)
        $script = Test-Path -LiteralPath (Join-Path $Ctx.Profil $scriptRel)
        $present = ($hkcu.Exists -or $hklm.Exists -or $t -or $script)
        $n = @(); if ($hkcu.Exists) { $n += 'Run(profil)' }; if ($hklm.Exists) { $n += 'Run(machine)' }; if ($t) { $n += 'tâche' }; if ($script) { $n += 'script' }
        $d = 'démarrage : aucun élément inutile'; if ($present) { $d = "démarrage : éléments inutiles ($($n -join ', '))" }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
