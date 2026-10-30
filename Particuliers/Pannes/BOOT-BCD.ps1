#requires -version 5.1
# BOOT-BCD : la machine ne démarre plus sur Windows. On agit sur l'entrée {default} du BCD :
#   1. recoveryenabled No  -> désactive la RÉPARATION AUTOMATIQUE de Windows. Sans ça, Windows
#      détecte l'échec au démarrage suivant, répare le BCD tout seul (WinRE) et redémarre : la
#      panne se soignerait d'elle-même (constaté en VM). C'est elle qui force l'élève à agir.
#   2. path <chargeur>.bak -> le chemin du chargeur est faux, winload est introuvable au
#      démarrage (erreur type 0xc000000e / 0xc0000225). L'écran de récupération reste affiché.
# Voir Particuliers-Config.psd1.
#
# HORS-SYSTÈME : une fois la machine redémarrée, PowerShell Direct ne répond plus. On ne redémarre
# donc PAS pendant les tests : on contrôle la configuration (le BCD). Le retrait restaure l'état
# exact (chemin ET recoveryenabled) et reste exécutable avant reboot, ou depuis Windows RE.
#
# On ne touche QUE path et recoveryenabled de {default} : jamais le store BCD complet, jamais la
# partition WinRE, jamais BitLocker. WinRE reste joignable (média d'installation / clé de
# récupération) : la machine n'est jamais irrécupérable, mais la réparation devient manuelle.
#
# Scriptblock (et non fonction nommée) : les closures capturent les variables, pas une fonction
# définie dans ce fichier, dont le scope a disparu quand le moteur appelle les blocs.
$lireLoader = {
    # Retourne @{ Path; Recovery } de l'entrée {default} ($null si absent).
    $out = & bcdedit /enum '{default}' 2>$null
    $path = $null; $rec = $null
    foreach ($l in $out) {
        if (-not $path -and $l -match '^\s*path\s+(.+?)\s*$') { $path = $Matches[1] }
        if ($l -match '^\s*recoveryenabled\s+(\S+)') { $rec = $Matches[1] }
    }
    @{ Path = $path; Recovery = $rec }
}
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        $l = & $lireLoader
        @{ Path = $l.Path; Recovery = $l.Recovery }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        $orig = $Etat.Path
        if (-not $orig) { throw "Chemin du chargeur {default} introuvable : installation annulée." }
        # 1) Couper la réparation automatique (sinon Windows répare le BCD tout seul au boot suivant).
        $o1 = & bcdedit /set '{default}' recoveryenabled No
        if ($LASTEXITCODE -ne 0) { throw "bcdedit recoveryenabled No : $o1" }
        # 2) Fausser le chemin du chargeur (d'apparence « reste d'un script de mise à jour » : .bak).
        $o2 = & bcdedit /set '{default}' path ($orig + '.bak')
        if ($LASTEXITCODE -ne 0) { throw "bcdedit /set path : $o2" }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        if ($Etat.Path) {
            $o = & bcdedit /set '{default}' path $Etat.Path
            if ($LASTEXITCODE -ne 0) { throw "bcdedit (restauration path) : $o" }
        }
        $rec = $Etat.Recovery; if (-not $rec) { $rec = 'Yes' }
        $o = & bcdedit /set '{default}' recoveryenabled $rec
        if ($LASTEXITCODE -ne 0) { throw "bcdedit (restauration recoveryenabled) : $o" }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $l = & $lireLoader
        $cheminOk = ($l.Path -match '(?i)\\winload\.(efi|exe)$')
        $recOk = ($l.Recovery -ine 'No')
        $normal = ($cheminOk -and $recOk)
        $d = "démarrage : normal (chargeur $($l.Path), réparation auto $($l.Recovery))"
        if (-not $normal) { $d = "démarrage : compromis (chargeur $($l.Path), réparation auto $($l.Recovery))" }
        @{ Ok = [bool]$normal; Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
