#requires -version 5.1
# STRAT-TASKMGR : Gestionnaire des tâches bloqué par stratégie (profil du client). Voir Particuliers-Config.psd1.
$key = 'Software\Microsoft\Windows\CurrentVersion\Policies\System'
$name = 'DisableTaskMgr'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Valeurs = @(Get-PartUserValue -Root $Ctx.Root -Key $key -Name $name) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $key) -Name $name -Value 1 -Type DWord
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        $v = Get-PartUserValue -Root $Ctx.Root -Key $key -Name $name
        $bloque = ($v.Exists -and [int]$v.Value -eq 1)
        $d = 'Gestionnaire des tâches : accessible'; if ($bloque) { $d = 'Gestionnaire des tâches : bloqué (stratégie DisableTaskMgr)' }
        @{ Ok = (-not $bloque); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
