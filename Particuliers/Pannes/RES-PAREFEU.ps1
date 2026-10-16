#requires -version 5.1
# RES-PAREFEU : règle de pare-feu sortante qui bloque Microsoft Edge (tout le poste).
# Nom d'apparence normale : rien n'indique une panne.
$regle = 'Microsoft Edge (connexions sortantes)'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{ Edge = (Get-PartEdgePath) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        if (-not $Etat.Edge) { throw 'Microsoft Edge introuvable sur ce poste.' }
        if (-not (Get-NetFirewallRule -DisplayName $regle -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $regle -Direction Outbound -Program $Etat.Edge -Action Block -Profile Any -Enabled True | Out-Null
        }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        Get-NetFirewallRule -DisplayName $regle -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $present = [bool](Get-NetFirewallRule -DisplayName $regle -ErrorAction SilentlyContinue)
        $d = 'pare-feu propre'; if ($present) { $d = 'règle sortante bloque Edge' }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
