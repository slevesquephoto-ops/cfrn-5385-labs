#requires -version 5.1
# SEC-EXCL : exclusion Microsoft Defender sur C:\ (tout le poste). Voir Particuliers-Config.psd1.
# Defender ne scanne plus rien : « tout va bien » alors que l'ordinateur agit bizarrement.
# Se découvre en vérifiant les paramètres de l'antivirus. Exige la protection contre les
# falsifications désactivée pour poser et retirer l'exclusion (comme SEC-EICAR-TIERS).
$exclu = 'C:\'
$lire = {
    try { return (@((Get-MpPreference -ErrorAction Stop).ExclusionPath) -contains $exclu) }
    catch { return $false }
}
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Existait = [bool](& $lire) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        try { Add-MpPreference -ExclusionPath $exclu -ErrorAction Stop }
        catch { throw "Impossible d'ajouter l'exclusion Defender (protection contre les falsifications active?). La désactiver, puis réessayer. Détail : $($_.Exception.Message)" }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        # Ne retirer que si on l'a bien ajoutée (elle n'existait pas avant).
        if (-not $Etat.Existait) { Remove-MpPreference -ExclusionPath $exclu -ErrorAction SilentlyContinue }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $present = [bool](& $lire)
        $d = 'aucune exclusion sur C:\'; if ($present) { $d = 'exclusion Defender sur C:\ active' }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
