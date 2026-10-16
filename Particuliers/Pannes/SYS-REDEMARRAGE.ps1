#requires -version 5.1
# SYS-REDEMARRAGE : redémarrage forcé peu après l'ouverture de session DU CLIENT (punitif). Tout le poste.
# Voir Particuliers-Config.psd1. Récit : un script lié à une mise à jour s'est mal effacé.
# But pédagogique : la session du client redémarre avant qu'on puisse réparer -> l'élève doit passer
# par un AUTRE compte ou par Windows RE pour désactiver la tâche. La tâche est déclenchée par le logon
# du client seulement : les autres comptes ouvrent normalement. Elle ne se déclenche donc pas pendant
# le test automatisé (PowerShell Direct n'ouvre pas de session interactive) : le test ne vérifie que la
# présence/retrait exact.
$tache = 'SystemUpdateFinalize'   # nom d'apparence normale
$delai = 30                        # secondes avant le redémarrage
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Tache = $tache }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        $action = New-ScheduledTaskAction -Execute 'shutdown.exe' -Argument "/r /t $delai /c `"Finalisation de l'installation des mises a jour.`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $Ctx.Compte
        $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $set = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $tache -Action $action -Trigger $trigger -Principal $pr -Settings $set -Force | Out-Null
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        Unregister-ScheduledTask -TaskName $tache -Confirm:$false -ErrorAction SilentlyContinue
        # Annule un redémarrage éventuellement armé. On passe par cmd pour avaler le flux d'erreur de
        # shutdown quand aucun arrêt n'est en cours : sinon PowerShell 5.1 promeut ce stderr en
        # NativeCommandError et le moteur croit (à tort) que le retrait a échoué.
        & cmd.exe /c 'shutdown /a >nul 2>nul'
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $present = [bool](Get-ScheduledTask -TaskName $tache -ErrorAction SilentlyContinue)
        $d = 'aucun redémarrage programmé au logon'; if ($present) { $d = "redémarrage forcé au logon du client (tâche $tache)" }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
