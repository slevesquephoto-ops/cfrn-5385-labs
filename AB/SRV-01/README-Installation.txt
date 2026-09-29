Architecture Boréale — README d'installation
Machine : AB-SRV-01 (HP ProDesk 400 G5 Mini) — serveur de fichiers

*** USAGE ENSEIGNANT — NE PAS DÉPOSER SUR LE POSTE ***
Les mots de passe ci-dessous sont fictifs (mise en situation), mais les élèves
ne doivent jamais voir ce fichier.

Comptes et mots de passe LAB
----------------------------
  Administrateur : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)
  Comptes des employés (mêmes identifiants que sur les postes, pour les partages) :
    jbouchard   Jere!mieAB-2026    Jérémie Bouchard
    ncote       Nath!alieAB-2026   Nathalie Côté
    lpgauthier  Loui!sAB-2026      Louis-Philippe Gauthier
    efortin     Emil!ieAB-2026     Émilie Fortin

Installation (une fois, PowerShell administrateur, employé NON connecté)
-----------------------------------------------------------------------
  1. tools\Set-ABPoste.ps1 -Poste SRV-01           (verrou de version Windows)
  2. AB\SRV-01\Setup-SRV-01.ps1                    (comptes, groupes, partages, données, IP fixe)

Rotation entre deux équipes (X = lettre de l'équipe suivante, A à E)
-------------------------------------------------------------------
  AB\SRV-01\Retrait-SRV-01.ps1 ; AB\SRV-01\Setup-SRV-01.ps1 ; AB\SRV-01\Panne-SRV-01.ps1 -Variante X

Contrôle de l'état (n'ouvre aucune session, ne salit rien)
---------------------------------------------------------
  AB\SRV-01\Verifier-SRV-01.ps1 -Attendu Propre
  AB\SRV-01\Verifier-SRV-01.ps1 -Attendu Panne -Variante X

Requêtes de ce poste
--------------------
  R1 (accès refusé aux projets, côté serveur) et R6 variante B (verrou du registre des factures).

Voir aussi : GUIDE-ENSEIGNANT.md (préparation, rotation, liste de contrôle) et
             AB\NOTES-CORRECTION.md (ce que voient les élèves, corrections attendues).
