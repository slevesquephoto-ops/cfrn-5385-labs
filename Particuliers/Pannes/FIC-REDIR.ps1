#requires -version 5.1
# FIC-REDIR : dossier Documents du client redirigé vers D:\Documents (inexistant). Profil du client.
# Voir Particuliers-Config.psd1. « Mon dossier Documents est introuvable. » La correction remet le
# chemin sous le profil. Deux valeurs : User Shell Folders (canonique) et Shell Folders (résolu).
$usf = 'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
$sf = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
$fausse = 'D:\Documents'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Valeurs = @(
                Get-PartUserValue -Root $Ctx.Root -Key $usf -Name 'Personal'
                Get-PartUserValue -Root $Ctx.Root -Key $sf -Name 'Personal'
            ) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $usf) -Name 'Personal' -Value $fausse -Type ExpandString
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $sf) -Name 'Personal' -Value $fausse -Type String
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        $v = Get-PartUserValue -Root $Ctx.Root -Key $usf -Name 'Personal'
        $redirige = ($v.Exists -and "$($v.Value)" -eq $fausse)
        @{ Ok = (-not $redirige); Detail = "Documents -> $($v.Value)" }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
