#requires -version 5.1
<#
.SYNOPSIS
    Génère AB\<MACHINE>\README-Installation.txt pour chaque machine (usage enseignant).

.DESCRIPTION
    Comptes et mots de passe LAB (fictifs, depuis AB-Config.psd1), étapes d'installation,
    rotation entre équipes et requêtes du poste. À GARDER DANS LE DÉPÔT : ne jamais déposer
    sur un poste (les élèves ne doivent pas voir les mots de passe).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$cfg = Import-PowerShellDataFile (Join-Path $repo 'AB\AB-Config.psd1')
$emp = @{}; foreach ($e in $cfg.Employes) { $emp[$e.Poste] = $e }
$utf8Bom = New-Object Text.UTF8Encoding($true)

# Requêtes par machine (résumé; textes complets dans AB\ITFlow-Donnees.psd1)
$requetes = @{
    'SRV-01' = 'R1 (accès refusé aux projets, côté serveur) et R6 variante B (verrou du registre des factures).'
    'PC-01'  = 'R5 (lecteur S: disparu) et R6 (facturation impossible, selon la variante).'
    'PC-02'  = 'R3 (sauvegarde avant congrès) et R4 (lenteur : logiciel + ajout de RAM).'
    'PC-03'  = 'R1 (accès refusé aux plans de la marina, côté poste).'
    'PC-04'  = 'R2 (ne démarre plus) — PANNE PHYSIQUE, préparée à la main (aucun script).'
}
$notes = @{
    'PC-02' = "`r`nNote R4 : la couche matérielle (ajout d'une barrette de RAM DDR4) est manuelle." +
              "`r`n          Entre deux équipes, retirer la barrette ajoutée pour revenir à 8 Go."
    'PC-04' = "`r`nNote R2 : pas de script de panne. Voir GUIDE-ENSEIGNANT.md, section « Pannes physiques R2 »." +
              "`r`n          Le retrait (rebrancher, remettre l'ordre de démarrage) se fait sur le matériel."
}

foreach ($machine in 'SRV-01', 'PC-01', 'PC-02', 'PC-03', 'PC-04') {
    $poste = "AB-$machine"
    $lignes = New-Object System.Collections.Generic.List[string]
    $add = { param($t) $lignes.Add($t) }

    & $add 'Architecture Boréale — README d''installation'
    if ($machine -eq 'SRV-01') { & $add "Machine : $poste (HP ProDesk 400 G5 Mini) — serveur de fichiers" }
    else { & $add "Machine : $poste (Lenovo ThinkCentre M700) — $($emp[$machine].NomComplet)" }
    & $add ''
    & $add '*** USAGE ENSEIGNANT — NE PAS DÉPOSER SUR LE POSTE ***'
    & $add 'Les mots de passe ci-dessous sont fictifs (mise en situation), mais les élèves'
    & $add 'ne doivent jamais voir ce fichier.'
    & $add ''
    & $add 'Comptes et mots de passe LAB'
    & $add '----------------------------'
    if ($machine -eq 'SRV-01') {
        & $add '  Administrateur : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)'
        & $add '  Comptes des employés (mêmes identifiants que sur les postes, pour les partages) :'
        foreach ($e in $cfg.Employes | Sort-Object Compte) {
            & $add ("    {0,-11} {1,-18} {2}" -f $e.Compte, $e.MotDePasse, $e.NomComplet)
        }
    } else {
        $e = $emp[$machine]
        & $add ("  Employé (utilisateur standard) : {0} / {1}   ({2})" -f $e.Compte, $e.MotDePasse, $e.NomComplet)
        & $add '  Administrateur                 : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)'
    }
    & $add ''
    & $add 'Installation (une fois, PowerShell administrateur, employé NON connecté)'
    & $add '-----------------------------------------------------------------------'
    if ($machine -eq 'SRV-01') {
        & $add '  1. tools\Set-ABPoste.ps1 -Poste SRV-01           (verrou de version Windows)'
        & $add '  2. AB\SRV-01\Setup-SRV-01.ps1                    (comptes, groupes, partages, données, IP fixe)'
    } else {
        & $add ("  1. tools\Set-ABPoste.ps1 -Poste {0} -Methode Local -SourceLocale <clé>\installeurs" -f $machine)
        & $add ("  2. AB\{0}\Setup-{0}.ps1                          (profil, données, apparence)" -f $machine)
    }
    & $add ''
    & $add 'Rotation entre deux équipes (X = lettre de l''équipe suivante, A à E)'
    & $add '-------------------------------------------------------------------'
    if ($machine -eq 'PC-04') {
        & $add '  Pas de script de panne (R2 physique). Remettre le matériel en état, puis au besoin :'
        & $add '    AB\PC-04\Setup-PC-04.ps1'
        & $add '  Préparer ensuite R2 de la nouvelle variante (voir GUIDE-ENSEIGNANT.md).'
    } else {
        & $add ("  AB\{0}\Retrait-{0}.ps1 ; AB\{0}\Setup-{0}.ps1 ; AB\{0}\Panne-{0}.ps1 -Variante X" -f $machine)
    }
    & $add ''
    & $add 'Contrôle de l''état (n''ouvre aucune session, ne salit rien)'
    & $add '---------------------------------------------------------'
    & $add ("  AB\{0}\Verifier-{0}.ps1 -Attendu Propre" -f $machine)
    & $add ("  AB\{0}\Verifier-{0}.ps1 -Attendu Panne -Variante X" -f $machine)
    if ($machine -eq 'PC-02') { & $add '  AB\PC-02\Verifier-PC-02.ps1 -Attendu Propre -R3   (contrôle la sauvegarde de R3)' }
    & $add ''
    & $add 'Requêtes de ce poste'
    & $add '--------------------'
    & $add "  $($requetes[$machine])"
    if ($notes.ContainsKey($machine)) { & $add $notes[$machine] }
    & $add ''
    & $add 'Voir aussi : GUIDE-ENSEIGNANT.md (préparation, rotation, liste de contrôle) et'
    & $add '             AB\NOTES-CORRECTION.md (ce que voient les élèves, corrections attendues).'

    $path = Join-Path $repo "AB\$machine\README-Installation.txt"
    [IO.File]::WriteAllText($path, (($lignes -join "`r`n") + "`r`n"), $utf8Bom)
    Write-Host "[OK] $path"
}
