#requires -version 5.1
# SEC-EICAR-DEF : fausse infection (fichier de test EICAR) qui réapparaît au démarrage et
# toutes les 5 minutes. Microsoft Defender reste ACTIF : il met chaque dépôt en quarantaine.
# L'élève voit l'antivirus réagir sans relâche et doit trouver la tâche qui relance la
# « menace », puis la supprimer. Rien de nuisible ne s'exécute (fichier de test standard).
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ TacheDeja = (Test-PartEicarPersistence).Tache }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        Install-PartEicarPersistence
        Write-PartEicarFile   # premier dépôt; Defender le détectera, la tâche le remet
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        Remove-PartEicarPersistence
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        # DEF vs TIERS : même tâche, mais DEF n'ajoute PAS d'exclusion Defender (le dossier
        # reste surveillé). On la distingue par l'absence d'exclusion.
        $p = Test-PartEicarPersistence
        $excl = Test-PartDefenderExclusion
        $present = (($p.Tache -or $p.Generateur) -and -not $excl)
        @{ Ok = (-not $present); Detail = "tâche: $($p.Tache), générateur: $($p.Generateur), exclusion: $excl" }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
