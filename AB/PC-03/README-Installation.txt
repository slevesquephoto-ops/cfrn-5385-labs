Architecture Boréale — README d'installation
Machine : AB-PC-03 (Lenovo ThinkCentre M700) — Émilie Fortin

*** USAGE ENSEIGNANT — NE PAS DÉPOSER SUR LE POSTE ***
Les mots de passe ci-dessous sont fictifs (mise en situation), mais les élèves
ne doivent jamais voir ce fichier.

Comptes et mots de passe LAB
----------------------------
  Employé (utilisateur standard) : efortin / Emil!ieAB-2026   (Émilie Fortin)
  Administrateur                 : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)

Installation (une fois, PowerShell administrateur, employé NON connecté)
-----------------------------------------------------------------------
  1. tools\Set-ABPoste.ps1 -Poste PC-03 -Methode Local -SourceLocale <clé>\installeurs
  2. AB\PC-03\Setup-PC-03.ps1                          (profil, données, apparence)

Rotation entre deux équipes (X = lettre de l'équipe suivante, A à E)
-------------------------------------------------------------------
  AB\PC-03\Retrait-PC-03.ps1 ; AB\PC-03\Setup-PC-03.ps1 ; AB\PC-03\Panne-PC-03.ps1 -Variante X

Contrôle de l'état (n'ouvre aucune session, ne salit rien)
---------------------------------------------------------
  AB\PC-03\Verifier-PC-03.ps1 -Attendu Propre
  AB\PC-03\Verifier-PC-03.ps1 -Attendu Panne -Variante X

Requêtes de ce poste
--------------------
  R1 (accès refusé aux plans de la marina, côté poste).

Voir aussi : GUIDE-ENSEIGNANT.md (préparation, rotation, liste de contrôle) et
             AB\NOTES-CORRECTION.md (ce que voient les élèves, corrections attendues).
