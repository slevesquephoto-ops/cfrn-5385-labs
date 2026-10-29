POSTES DES CLIENTS PARTICULIERS - IDENTIFIANTS (fictifs, LAB)
==============================================================

Client       Nom complet         Type             Mot de passe
-----------  ------------------  ---------------  ------------
mbelanger    Monique Bélanger    Administrateur   Monique1952!

Compte de l'enseignant : par défaut, celui qui lance Client.ps1 en administrateur
(peu importe son nom : ab-tech, un compte prof local, de domaine ou Microsoft).
Ce compte est préservé (jamais désactivé) : c'est l'accès de secours quand une panne
punitive bloque la session du client. Pour forcer un compte local précis, mettre son
nom dans Particuliers-Config.psd1 (clé Administrateur) ; vide = auto-détection.
Les autres comptes sans mot de passe du poste sont désactivés le temps du placement,
puis réactivés quand le dernier client est supprimé.