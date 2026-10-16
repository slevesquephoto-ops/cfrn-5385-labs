#requires -version 5.1
# ACC-SOURIS : boutons de la souris inversés (profil du client). Voir Particuliers-Config.psd1.
$key = 'Control Panel\Mouse'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Valeurs = @(Get-PartUserValue -Root $Ctx.Root -Key $key -Name 'SwapMouseButtons') }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $key) -Name 'SwapMouseButtons' -Value '1' -Type String
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        $v = Get-PartUserValue -Root $Ctx.Root -Key $key -Name 'SwapMouseButtons'
        $inverse = ($v.Exists -and "$($v.Value)" -eq '1')
        $d = 'bouton principal : gauche'; if ($inverse) { $d = 'bouton principal : droit (inversé)' }
        @{ Ok = (-not $inverse); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
