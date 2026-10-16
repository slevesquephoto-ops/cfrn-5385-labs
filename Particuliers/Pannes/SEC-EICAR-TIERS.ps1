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
        $null = $Ctx, $Etat
        Add-PartDefenderExclusion
        Install-PartEicarPersistence
        Write-PartEicarFile
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
        $p = Test-PartEicarPersistence
        $excl = Test-PartDefenderExclusion
        @{ Ok = (-not ($p.Tache -or $p.Generateur -or $excl)); Detail = "tâche: $($p.Tache), générateur: $($p.Generateur), exclusion: $excl" }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
