#requires -version 5.1
# PUP-FAUX : faux logiciel « OptimiseurPC Pro » (profil + machine). Voir Particuliers-Config.psd1.
# Trois artefacts à trouver et nettoyer : entrée dans « Applications installées » (clé Uninstall HKLM),
# démarrage auto (clé Run du profil, HKCU) et tâche planifiée qui ouvre une page d'alerte LOCALE au logon.
$uninstall = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OptimiseurPCPro'
$runRel = 'Software\Microsoft\Windows\CurrentVersion\Run'
$runNom = 'OptimiseurPC Pro'
$tache = 'OptimiseurPCProAlerte'
$appDir = Join-Path $env:ProgramData 'OptimiseurPCPro'
$alerte = Join-Path $appDir 'alerte.html'
$htmlAlerte = @"
<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>OptimiseurPC Pro</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:10%;background:#300;color:#fff">
<h1>&#9888; Votre ordinateur est a risque</h1>
<p>OptimiseurPC Pro a detecte plusieurs problemes. Achetez la version complete pour les corriger.</p>
<p style="color:#f99;font-size:small">(Page locale de laboratoire &mdash; faux logiciel, aucune menace reelle.)</p>
</body></html>
"@
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{
            Run            = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom
            UninstExistait = [bool](Test-Path -LiteralPath $uninstall)
            DossierCree    = (-not (Test-Path -LiteralPath $appDir))
        }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        if (-not (Test-Path -LiteralPath $appDir)) { New-Item -ItemType Directory -Path $appDir -Force | Out-Null }
        Set-Content -LiteralPath $alerte -Value $htmlAlerte -Encoding UTF8
        # Entrée « Applications installées »
        Set-LabRegistryValue -Path $uninstall -Name 'DisplayName' -Value 'OptimiseurPC Pro' -Type String
        Set-LabRegistryValue -Path $uninstall -Name 'DisplayVersion' -Value '3.2.1' -Type String
        Set-LabRegistryValue -Path $uninstall -Name 'Publisher' -Value 'PC Optim Labs' -Type String
        Set-LabRegistryValue -Path $uninstall -Name 'InstallLocation' -Value $appDir -Type String
        Set-LabRegistryValue -Path $uninstall -Name 'NoModify' -Value 1 -Type DWord
        Set-LabRegistryValue -Path $uninstall -Name 'NoRepair' -Value 1 -Type DWord
        # Démarrage auto (profil) : pointe vers un exe absent -> inoffensif, mais visible dans Démarrage.
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $runRel) -Name $runNom -Value ('"{0}\OptimiseurPCPro.exe"' -f $appDir) -Type String
        # Tâche au logon DU CLIENT : ouvre la page d'alerte locale dans sa session.
        $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c start "" "{0}"' -f $alerte)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $Ctx.Compte
        $pr = New-ScheduledTaskPrincipal -UserId $Ctx.Compte -LogonType Interactive -RunLevel Limited
        $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $tache -Action $action -Trigger $trigger -Principal $pr -Settings $set -Force | Out-Null
    }
    Retirer = {
        param($Ctx, $Etat)
        Restore-PartUserValue -Root $Ctx.Root -Snapshot $Etat.Run
        Unregister-ScheduledTask -TaskName $tache -Confirm:$false -ErrorAction SilentlyContinue
        if (-not $Etat.UninstExistait -and (Test-Path -LiteralPath $uninstall)) { Remove-Item -LiteralPath $uninstall -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $alerte) { Remove-Item -LiteralPath $alerte -Force }
        if ($Etat.DossierCree -and (Test-Path -LiteralPath $appDir) -and -not @(Get-ChildItem -LiteralPath $appDir -Force)) { Remove-Item -LiteralPath $appDir -Force }
    }
    Tester = {
        param($Ctx)
        $run = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom
        $unin = Test-Path -LiteralPath $uninstall
        $t = [bool](Get-ScheduledTask -TaskName $tache -ErrorAction SilentlyContinue)
        $present = ($run.Exists -or $unin -or $t)
        $n = @(); if ($unin) { $n += 'Applications' }; if ($run.Exists) { $n += 'Démarrage' }; if ($t) { $n += 'tâche' }
        $d = 'aucun reste d''OptimiseurPC Pro'; if ($present) { $d = "OptimiseurPC Pro présent ($($n -join ', '))" }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
