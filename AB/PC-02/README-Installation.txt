Architecture Boréale — README d'installation
Machine : AB-PC-02 (Lenovo ThinkCentre M700) — Louis-Philippe Gauthier

*** USAGE ENSEIGNANT — NE PAS DÉPOSER SUR LE POSTE ***
Les mots de passe ci-dessous sont fictifs (mise en situation), mais les élèves
ne doivent jamais voir ce fichier.

Comptes et mots de passe LAB
----------------------------
  Employé (utilisateur standard) : lpgauthier / Loui!sAB-2026   (Louis-Philippe Gauthier)
  Administrateur                 : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)

Installation (une fois, PowerShell administrateur, employé NON connecté)
-----------------------------------------------------------------------
  1. tools\Set-ABPoste.ps1 -Poste PC-02 -Methode Local -SourceLocale <clé>\installeurs
  2. AB\PC-02\Setup-PC-02.ps1                          (profil, données, apparence)

Rotation entre deux équipes (X = lettre de l'équipe suivante, A à E)
-------------------------------------------------------------------
  AB\PC-02\Retrait-PC-02.ps1 ; AB\PC-02\Setup-PC-02.ps1 ; AB\PC-02\Panne-PC-02.ps1 -Variante X

Contrôle de l'état (n'ouvre aucune session, ne salit rien)
---------------------------------------------------------
  AB\PC-02\Verifier-PC-02.ps1 -Attendu Propre
  AB\PC-02\Verifier-PC-02.ps1 -Attendu Panne -Variante X
  AB\PC-02\Verifier-PC-02.ps1 -Attendu Propre -R3   (contrôle la sauvegarde de R3)

Requêtes de ce poste
--------------------
  R3 (sauvegarde avant congrès) et R4 (lenteur : logiciel + ajout de RAM).

Note R4 : la couche matérielle (ajout d'une barrette de RAM DDR4) est manuelle.
          Entre deux équipes, retirer la barrette ajoutée pour revenir à 8 Go.

Voir aussi : GUIDE-ENSEIGNANT.md (préparation, rotation, liste de contrôle) et
             AB\NOTES-CORRECTION.md (ce que voient les élèves, corrections attendues).
