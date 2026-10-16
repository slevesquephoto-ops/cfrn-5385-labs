#requires -version 5.1
# STRAT-ARRET : commandes Arrêter / Redémarrer retirées du menu Démarrer par stratégie (profil du client). Voir Particuliers-Config.psd1.
$key = 'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$name = 'NoClose'
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
        $retire = ($v.Exists -and [int]$v.Value -eq 1)
        $d = 'menu Démarrer : Arrêter / Redémarrer présents'; if ($retire) { $d = 'menu Démarrer : Arrêter / Redémarrer retirés (stratégie NoClose)' }
        @{ Ok = (-not $retire); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
