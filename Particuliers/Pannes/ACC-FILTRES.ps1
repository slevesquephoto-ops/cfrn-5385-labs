#requires -version 5.1
# ACC-FILTRES : touches filtres activées dans le profil du client. Voir Particuliers-Config.psd1.
# Windows ignore alors les frappes brèves ou répétées : le clavier « ne répond plus comme avant ».
# HKCU\Control Panel\Accessibility\Keyboard Response : bit 0 de Flags = touches filtres actives.
$key = 'Control Panel\Accessibility\Keyboard Response'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Valeurs = @(Get-PartUserValue -Root $Ctx.Root -Key $key -Name 'Flags') }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $key) -Name 'Flags' -Value '127' -Type String
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        $v = Get-PartUserValue -Root $Ctx.Root -Key $key -Name 'Flags'
        $actives = $false
        if ($v.Exists) { $n = 0; if ([int]::TryParse("$($v.Value)", [ref]$n)) { $actives = (($n -band 1) -eq 1) } }
        $d = 'touches filtres : inactives'; if ($actives) { $d = 'touches filtres : actives' }
        @{ Ok = (-not $actives); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
