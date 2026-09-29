Architecture Boréale — README d'installation
Machine : AB-PC-04 (Lenovo ThinkCentre M700) — Jérémie Bouchard

*** USAGE ENSEIGNANT — NE PAS DÉPOSER SUR LE POSTE ***
Les mots de passe ci-dessous sont fictifs (mise en situation), mais les élèves
ne doivent jamais voir ce fichier.

Comptes et mots de passe LAB
----------------------------
  Employé (utilisateur standard) : jbouchard / Jere!mieAB-2026   (Jérémie Bouchard)
  Administrateur                 : ab-tech / (votre mot de passe habituel, non stocké dans le dépôt)

Installation (une fois, PowerShell administrateur, employé NON connecté)
-----------------------------------------------------------------------
  1. tools\Set-ABPoste.ps1 -Poste PC-04 -Methode Local -SourceLocale <clé>\installeurs
  2. AB\PC-04\Setup-PC-04.ps1                          (profil, données, apparence)

Rotation entre deux équipes (X = lettre de l'équipe suivante, A à E)
-------------------------------------------------------------------
  Pas de script de panne (R2 physique). Remettre le matériel en état, puis au besoin :
    AB\PC-04\Setup-PC-04.ps1
  Préparer ensuite R2 de la nouvelle variante (voir GUIDE-ENSEIGNANT.md).

Contrôle de l'état (n'ouvre aucune session, ne salit rien)
---------------------------------------------------------
  AB\PC-04\Verifier-PC-04.ps1 -Attendu Propre
  AB\PC-04\Verifier-PC-04.ps1 -Attendu Panne -Variante X

Requêtes de ce poste
--------------------
  R2 (ne démarre plus) — PANNE PHYSIQUE, préparée à la main (aucun script).

Note R2 : pas de script de panne. Voir GUIDE-ENSEIGNANT.md, section « Pannes physiques R2 ».
          Le retrait (rebrancher, remettre l'ordre de démarrage) se fait sur le matériel.

Voir aussi : GUIDE-ENSEIGNANT.md (préparation, rotation, liste de contrôle) et
             AB\NOTES-CORRECTION.md (ce que voient les élèves, corrections attendues).
