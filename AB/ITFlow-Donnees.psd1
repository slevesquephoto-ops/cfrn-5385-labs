@{
    # =======================================================================
    # Données ITFlow d'Architecture Boréale, lues par tools\New-ITFlowABData.ps1.
    # Créées par équipe (A à E) via tools\ITFlow-AB.psm1 : un client par équipe,
    # lieux, contacts (les 4 employés), actifs (les 5 machines), requêtes.
    # Requêtes pré-créées : R1, R3, R4, R5, R6. R2 n'est PAS créée (les élèves
    # la créent à partir de l'appel de Jérémie). La lettre de variante est la même
    # pour toutes les requêtes d'une équipe; seule R6 change de symptôme par variante.
    # Réseau, fournisseur « Fournisseur CFRN » et identifiants : saisis à la main.
    # =======================================================================

    Lieux = @(
        @{ Nom = 'Bureaux';        Description = 'Bureaux à aire ouverte des architectes.'; Principal = $true }
        @{ Nom = 'Salle technique'; Description = 'Salle technique séparée (serveur de fichiers).'; Principal = $false }
    )

    # Téléphones fictifs des employés (le reste vient de AB-Config.psd1 : compte, nom, rôle, poste).
    Contacts = @{
        lpgauthier = @{ Telephone = '418 555-0102' }
        efortin    = @{ Telephone = '418 555-0103' }
        jbouchard  = @{ Telephone = '418 555-0104' }
        ncote      = @{ Telephone = '418 555-0101' }
    }

    # Actifs = les 5 machines. Le numéro de série est laissé vide : à compléter sur le
    # vrai matériel (Get-CimInstance Win32_BIOS | Select SerialNumber). Lieu : Bureaux pour
    # les postes, Salle technique pour le serveur. Contact : l'employé du poste.
    Actifs = @(
        @{ Machine = 'SRV-01'; Type = 'Server';  Fabricant = 'HP';     Modele = 'ProDesk 400 G5 Mini'; OS = 'Windows 11 Pro (25H2)'; Lieu = 'Salle technique'; Compte = '' }
        @{ Machine = 'PC-01';  Type = 'Desktop'; Fabricant = 'Lenovo'; Modele = 'ThinkCentre M700';    OS = 'Windows 11 Pro (24H2)'; Lieu = 'Bureaux';         Compte = 'ncote' }
        @{ Machine = 'PC-02';  Type = 'Desktop'; Fabricant = 'Lenovo'; Modele = 'ThinkCentre M700';    OS = 'Windows 11 Pro (24H2)'; Lieu = 'Bureaux';         Compte = 'lpgauthier' }
        @{ Machine = 'PC-03';  Type = 'Desktop'; Fabricant = 'Lenovo'; Modele = 'ThinkCentre M700';    OS = 'Windows 11 Pro (24H2)'; Lieu = 'Bureaux';         Compte = 'efortin' }
        @{ Machine = 'PC-04';  Type = 'Desktop'; Fabricant = 'Lenovo'; Modele = 'ThinkCentre M700';    OS = 'Windows 11 Pro (24H2)'; Lieu = 'Bureaux';         Compte = 'jbouchard' }
    )

    # Requêtes. Contact = compte de l'employé qui appelle; Poste = machine liée.
    # Textes dans la voix de l'employé, sans révéler la cause (règle de discrétion).
    Requetes = @{
        # R2 : normalement créée par les élèves (appel de Jérémie). Incluse ici pour pouvoir
        # cloner une équipe complète; New-ITFlowABData ne la crée qu'avec -AvecR2.
        R2 = @{
            Poste = 'PC-04'; Contact = 'jbouchard'; Priorite = 'High'
            Sujet = 'Mon ordinateur ne démarre plus ce matin'
            Description = @'
Bonjour,

Ce matin en arrivant, mon poste ne s'affiche pas correctement : l'écran reste noir, ou montre une image toute bleutée, alors que la tour a l'air allumée (les ventilateurs tournent). Je n'arrive pas à voir quoi que ce soit pour ouvrir ma session.

J'ai des rendus à livrer aujourd'hui. Je vous appelle parce que je ne peux même pas utiliser l'ordinateur. Pouvez-vous venir voir?

Jérémie Bouchard
Technicien en architecture, Architecture Boréale
'@
        }
        R1 = @{
            Poste = 'PC-03'; Contact = 'efortin'; Priorite = 'High'
            Sujet = 'Je n''ai plus accès aux plans de la marina'
            Description = @'
Bonjour,

Depuis ce matin, je ne peux plus ouvrir le dossier du projet 2026-021 (Agrandissement de la marina de Pointe-Blanche) sur le lecteur P:. J'ai un message d'accès refusé, et parfois le serveur semble carrément introuvable. Mes collègues, eux, arrivent à travailler.

J'ai une échéance cette semaine pour les plans du quai. Pouvez-vous regarder rapidement?

Merci,
Émilie Fortin
Architecte de projets, Architecture Boréale
'@
        }
        R3 = @{
            Poste = 'PC-02'; Contact = 'lpgauthier'; Priorite = 'Medium'
            Sujet = 'Copiez mes fichiers importants avant qu''on touche à mon ordinateur'
            Description = @'
Bonjour,

Je pars au congrès et on doit ajouter de la mémoire à mon ordinateur pendant mon absence. Avant d'y toucher, pouvez-vous mettre en lieu sûr tous mes fichiers importants : mes soumissions (dont celles dans C:\Soumissions-LP), le budget du cabinet, les contrats signés et mes dossiers confidentiels? J'aimerais aussi conserver mes favoris de navigateur.

Je ne voudrais rien perdre. Merci de me confirmer que tout est sauvegardé.

Louis-Philippe Gauthier
Architecte associé, Architecture Boréale
'@
        }
        R4 = @{
            Poste = 'PC-02'; Contact = 'lpgauthier'; Priorite = 'Medium'
            Sujet = 'Mon ordinateur est d''une lenteur insupportable'
            Description = @'
Bonjour,

Mon poste est devenu très lent, surtout au démarrage et quand j'ouvre plusieurs documents en même temps. Ça me fait perdre un temps fou. Est-ce qu'on peut le rendre plus rapide? Si ça prend plus de mémoire, je suis d'accord pour qu'on en ajoute.

Merci,
Louis-Philippe Gauthier
Architecte associé, Architecture Boréale
'@
        }
        R5 = @{
            Poste = 'PC-01'; Contact = 'ncote'; Priorite = 'Low'
            Sujet = 'Mon lecteur réseau S: a disparu'
            Description = @'
Bonjour,

Le lecteur S: que j'utilise tous les jours n'apparaît plus dans l'Explorateur (ou il a une croix rouge). Je ne peux plus accéder aux fichiers communs. Je n'ai rien changé.

Pouvez-vous le remettre? Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
        }
        R6 = @{
            Poste = 'PC-01'; Contact = 'ncote'; Priorite = 'Medium'
            # Symptôme différent par variante (voir AB/NOTES-CORRECTION.md et AB/SPEC.md).
            Variantes = @{
                A = @{
                    Sujet = 'LibreOffice ne veut plus démarrer normalement'
                    Description = @'
Bonjour,

Depuis ce matin, quand j'ouvre LibreOffice pour faire mes factures, j'ai un message qui parle de « paramètres personnels verrouillés » et d'une autre instance. Je ne comprends pas et j'ai peur de tout briser, alors j'ai cliqué sur Non et le logiciel s'est fermé.

Je n'ai rien changé. Pouvez-vous regarder? J'ai des factures à envoyer avant vendredi.

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
                }
                B = @{
                    Sujet = 'Impossible de modifier le registre des factures'
                    Description = @'
Bonjour,

Quand j'ouvre le registre des factures (T:\Facturation\Registre-factures-2026.ods), LibreOffice me dit que le fichier est utilisé par Louis-Philippe et me propose seulement de l'ouvrir en lecture seule. Louis-Philippe est en congrès et son ordinateur est fermé.

Je dois y inscrire les factures de septembre. Pouvez-vous m'aider?

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
                }
                C = @{
                    Sujet = 'LibreOffice ne s''ouvre plus du tout'
                    Description = @'
Bonjour,

Depuis hier, LibreOffice ne s'ouvre plus : il ne se passe rien quand je clique sur l'icône, ou j'ai une erreur. Je ne peux plus faire mes factures ni ouvrir le registre.

Je n'ai rien installé. Pouvez-vous le remettre en état?

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
                }
                D = @{
                    Sujet = 'Nos factures n''ont plus la même apparence'
                    Description = @'
Bonjour,

La Coopérative de santé du Littoral m'a appelée : elle trouve que notre dernière facture « ne ressemble pas aux autres » et voulait s'assurer qu'elle venait bien de nous. En comparant, je vois que la police n'est plus la même et que les titres sont plus larges. Je n'ai pourtant pas touché au modèle (T:\Modèles\Facture-AB.ott).

Louis-Philippe tient beaucoup à notre charte : tous les documents clients doivent être en Montserrat. Je joins une facture d'août qui a la bonne apparence, pour comparer (à ajouter à la requête).

Merci de corriger avant ma prochaine facturation.
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
                }
                E = @{
                    Sujet = 'Le numéro et la date ne se remplissent plus sur mes factures'
                    Description = @'
Bonjour,

Quand je crée une nouvelle facture à partir du modèle (T:\Modèles\Facture-AB.ott), le numéro et la date se remplissaient tout seuls. Depuis cette semaine, ils restent vides et j'ai un message à propos des macros. Je dois tout taper à la main et j'ai peur de me tromper dans la numérotation.

Pouvez-vous rétablir ça, sans rendre mon ordinateur moins sécuritaire?

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
                }
            }
        }
    }
}
