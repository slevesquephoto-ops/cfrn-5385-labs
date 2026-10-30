POSTES DES CLIENTS PARTICULIERS - IDENTIFIANTS (fictifs, LAB)
==============================================================

Client       Nom complet         Type             Mot de passe
-----------  ------------------  ---------------  ------------
mbelanger    Monique Bélanger    Administrateur   Monique1952!
jblais       Julien Blais        Administrateur   Julien1995!
bdionne      Benoît Dionne       Standard         Benoit1968!
mdionne      Marc Dionne         Administrateur   Marc1992!   (fils de Benoît, compte « aidant »)

« Aidant » : certains clients sont des comptes STANDARD (ex. bdionne). Un compte
administrateur distinct (son fils, mdionne) est alors créé en même temps sur la machine :
c'est l'accès admin « en fiction » que l'élève utilise pour réparer les pannes punitives.
Il est créé avec le client et retiré avec lui.

Compte de l'enseignant : par défaut, celui qui lance Client.ps1 en administrateur
(peu importe son nom : ab-tech, un compte prof local, de domaine ou Microsoft).
Ce compte est préservé (jamais désactivé) : c'est l'accès de secours quand une panne
punitive bloque la session du client. Pour forcer un compte local précis, mettre son
nom dans Particuliers-Config.psd1 (clé Administrateur) ; vide = auto-détection.
Les autres comptes sans mot de passe du poste sont désactivés le temps du placement,
puis réactivés quand le dernier client est supprimé.