#requires -version 5.1
# SYS-RAM : mémoire maximale bridée au démarrage (bcdedit truncatememory, ce qu'écrit msconfig). Tout le poste.
# Voir Particuliers-Config.psd1. On ne redémarre pas pendant les tests : on contrôle la configuration.
# Plancher à 3072 Mo : en dessous, Windows 11 peut refuser de démarrer (et en VM, un boot raté couperait
# PowerShell Direct, donc plus de retrait possible).
$limiteMo = 3072
$octets = [long]$limiteMo * 1MB
# Scriptblock capturé en variable (pas une fonction nommée : le scope du fichier a disparu
# quand le moteur appelle les blocs).
$lireTruncate = {
    $out = & bcdedit /enum '{current}' 2>$null
    $ligne = $out | Where-Object { $_ -match '^\s*truncatememory\s+\S' } | Select-Object -First 1
    if ($ligne -and $ligne -match '^\s*truncatememory\s+(\S+)') { return $Matches[1] }
    return $null
}
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Truncate = (& $lireTruncate) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        $out = & bcdedit /set '{current}' truncatememory $octets
        if ($LASTEXITCODE -ne 0) { throw "bcdedit /set truncatememory $octets : $out" }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        if ($Etat.Truncate) {
            $out = & bcdedit /set '{current}' truncatememory $Etat.Truncate
        } else {
            $out = & bcdedit /deletevalue '{current}' truncatememory
        }
        if ($LASTEXITCODE -ne 0 -and (& $lireTruncate)) { throw "bcdedit (retrait truncatememory) : $out" }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $v = & $lireTruncate
        $d = 'mémoire max : non bridée'; if ($v) { $d = "mémoire max : bridée (truncatememory $v)" }
        @{ Ok = (-not $v); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
