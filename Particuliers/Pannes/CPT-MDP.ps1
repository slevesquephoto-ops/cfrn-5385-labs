#requires -version 5.1
# CPT-MDP : mot de passe du client changé pour une valeur inconnue (profil du client).
# Voir Particuliers-Config.psd1. « J'ai oublié mon mot de passe. » Le retrait remet le mot de passe
# fictif documenté du client. La réparation se fait depuis un autre compte administrateur.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Mots de passe LAB fictifs et documentés (CLAUDE.md §8).')]
param()
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        # On ne peut pas lire un mot de passe : on garde celui, fictif et documenté, du catalogue.
        @{ MotDePasse = (Get-PartClient -Compte $Ctx.Compte).MotDePasse }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        $inconnu = "Bloque$(Get-Random -Minimum 100000 -Maximum 999999)!Zz"
        Set-LocalUser -Name $Ctx.Compte -Password (ConvertTo-SecureString $inconnu -AsPlainText -Force)
    }
    Retirer = {
        param($Ctx, $Etat)
        Set-LocalUser -Name $Ctx.Compte -Password (ConvertTo-SecureString $Etat.MotDePasse -AsPlainText -Force)
    }
    Tester = {
        param($Ctx)
        # Vrai = le mot de passe documenté ouvre la session (donc rétabli). LogonUser interactif (type 2).
        $pw = (Get-PartClient -Compte $Ctx.Compte).MotDePasse
        $token = [IntPtr]::Zero
        $ok = [ABNative.Logon]::LogonUser($Ctx.Compte, $env:COMPUTERNAME, $pw, 2, 0, [ref]$token)
        if ($ok) { [void][ABNative.Logon]::CloseHandle($token) }
        $d = 'mot de passe du client : inconnu'; if ($ok) { $d = 'mot de passe du client : rétabli' }
        @{ Ok = [bool]$ok; Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
