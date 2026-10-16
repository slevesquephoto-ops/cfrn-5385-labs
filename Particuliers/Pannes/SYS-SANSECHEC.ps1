#requires -version 5.1
# SYS-SANSECHEC : démarrage forcé en mode sans échec (bcdedit safeboot minimal), tout le poste.
# Voir Particuliers-Config.psd1. On ne redémarre pas pendant les tests : on contrôle la configuration.
# Scriptblock (et non fonction nommée) : les closures capturent les variables, pas une fonction
# définie dans ce fichier, dont le scope a disparu quand le moteur appelle les blocs.
$lireSafeboot = {
    # Retourne la valeur 'safeboot' de l'entrée courante, ou $null si absente.
    $out = & bcdedit /enum '{current}' 2>$null
    $ligne = $out | Where-Object { $_ -match '^\s*safeboot\s+\S' } | Select-Object -First 1
    if ($ligne -and $ligne -match '^\s*safeboot\s+(\S+)') { return $Matches[1] }
    return $null
}
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Safeboot = (& $lireSafeboot) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        $out = & bcdedit /set '{current}' safeboot minimal
        if ($LASTEXITCODE -ne 0) { throw "bcdedit /set safeboot minimal : $out" }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        if ($Etat.Safeboot) {
            $out = & bcdedit /set '{current}' safeboot $Etat.Safeboot
        } else {
            $out = & bcdedit /deletevalue '{current}' safeboot
        }
        # /deletevalue sur une valeur absente renvoie une erreur : on l'ignore si c'est déjà propre.
        if ($LASTEXITCODE -ne 0 -and (& $lireSafeboot)) { throw "bcdedit (retrait safeboot) : $out" }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $v = & $lireSafeboot
        $d = 'démarrage : normal'; if ($v) { $d = "démarrage : mode sans échec ($v)" }
        @{ Ok = (-not $v); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
