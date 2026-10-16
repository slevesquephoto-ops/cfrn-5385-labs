#requires -version 5.1
# STRAT-CMD : invite de commandes désactivée par stratégie (profil du client). Voir Particuliers-Config.psd1.
# DisableCMD = 2 : cmd.exe interactif bloqué, mais les scripts .bat/.cmd restent permis
# (choix réaliste d'un « optimiseur » : l'élève voit le message de blocage sans casser l'ouverture de session).
$key = 'Software\Policies\Microsoft\Windows\System'
$name = 'DisableCMD'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Valeurs = @(Get-PartUserValue -Root $Ctx.Root -Key $key -Name $name) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $key) -Name $name -Value 2 -Type DWord
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        $v = Get-PartUserValue -Root $Ctx.Root -Key $key -Name $name
        $bloque = ($v.Exists -and [int]$v.Value -in @(1, 2))
        $d = 'invite de commandes : permise'; if ($bloque) { $d = "invite de commandes : désactivée (stratégie DisableCMD = $($v.Value))" }
        @{ Ok = (-not $bloque); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
