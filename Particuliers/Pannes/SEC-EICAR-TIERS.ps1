#requires -version 5.1
# SEC-EICAR-TIERS : même fausse infection (fichier de test EICAR, réapparition au démarrage
# et toutes les 5 min), mais le dossier de dépôt est EXCLU de Microsoft Defender. Le fichier
# survit donc, et l'élève doit installer et lancer un AUTRE antivirus pour le détecter, puis
# trouver et retirer la persistance ET l'exclusion. Exige que la protection contre les
# falsifications de Defender soit désactivée sur le poste (sinon l'exclusion est refusée).
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ TacheDeja = (Test-PartEicarPersistence).Tache; ExclusionDeja = (Test-PartDefenderExclusion) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        Add-PartDefenderExclusion
        Install-PartEicarPersistence -Compte $Ctx.Compte
        Write-PartEicarFile -Compte $Ctx.Compte   # dépôt initial SEULEMENT si le client est au console
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        Remove-PartEicarPersistence
        if (-not $Etat.ExclusionDeja) { Remove-PartDefenderExclusion }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        # DEF vs TIERS : TIERS se distingue par la présence de l'exclusion Defender.
        $p = Test-PartEicarPersistence
        $excl = Test-PartDefenderExclusion
        $present = (($p.Tache -or $p.Generateur) -and $excl)
        @{ Ok = (-not $present); Detail = "tâche: $($p.Tache), générateur: $($p.Generateur), exclusion: $excl" }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
