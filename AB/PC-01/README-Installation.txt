Architecture Boréale — README d'installation
Machine : AB-PC-01 (Lenovo ThinkCentre M700) — Nathalie Côté

*** USAGE ENSEIGNANT — NE PAS DÉPOSER SUR LE POSTE ***
Les mots de passe ci-dessous sont fictifs (mise en situation), mais les élèves
ne doivent jamais voir ce fichier.

Comptes et mots de passe LAB
----------------------------
  Employé (utilisateur standard) : ncote / Nath!alieAB-2026   (Nathalie Côté)
  Administrateur                 : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)

Installation (une fois, PowerShell administrateur, employé NON connecté)
-----------------------------------------------------------------------
  1. tools\Set-ABPoste.ps1 -Poste PC-01 -Methode Local -SourceLocale <clé>\installeurs
  2. AB\PC-01\Setup-PC-01.ps1                          (profil, données, apparence)

Rotation entre deux équipes (X = lettre de l'équipe suivante, A à E)
-------------------------------------------------------------------
  AB\PC-01\Retrait-PC-01.ps1 ; AB\PC-01\Setup-PC-01.ps1 ; AB\PC-01\Panne-PC-01.ps1 -Variante X

Contrôle de l'état (n'ouvre aucune session, ne salit rien)
---------------------------------------------------------
  AB\PC-01\Verifier-PC-01.ps1 -Attendu Propre
  AB\PC-01\Verifier-PC-01.ps1 -Attendu Panne -Variante X

Requêtes de ce poste
--------------------
  R5 (lecteur S: disparu) et R6 (facturation impossible, selon la variante).

Voir aussi : GUIDE-ENSEIGNANT.md (préparation, rotation, liste de contrôle) et
             AB\NOTES-CORRECTION.md (ce que voient les élèves, corrections attendues).
