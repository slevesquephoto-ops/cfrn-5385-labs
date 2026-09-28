@{
    # =======================================================================
    # Textes des requêtes ITFlow pré-créées (spec : R1, R3, R4, R5, R6; R2 non créée).
    # Lus plus tard par tools\ITFlow-AB.psm1 (création avec -WhatIf d'abord).
    # Même lettre de variante pour toutes les requêtes d'une équipe.
    # Rédigés dans la voix de l'employé, sans révéler la cause (règle de discrétion).
    # PieceJointe : relative à AB\data.
    # =======================================================================
    R6 = @{
        Contact  = 'ncote'
        Priorite = 'Moyenne'
        Variantes = @{
            A = @{
                Sujet       = 'LibreOffice ne veut plus démarrer normalement'
                Description = @'
Bonjour,

Depuis ce matin, quand j'ouvre LibreOffice pour faire mes factures, j'ai un message qui parle de « paramètres personnels verrouillés » et d'une autre instance. Je ne comprends pas ce que ça veut dire et j'ai peur de tout briser, alors j'ai cliqué sur Non et le logiciel s'est fermé.

Je n'ai rien changé. Pouvez-vous regarder ça rapidement? J'ai des factures à envoyer avant vendredi.

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
            }
            B = @{
                Sujet       = 'Impossible de modifier le registre des factures'
                Description = @'
Bonjour,

Quand j'ouvre le registre des factures (T:\Facturation\Registre-factures-2026.ods), LibreOffice me dit que le fichier est utilisé par Louis-Philippe et me propose seulement de l'ouvrir en lecture seule. Louis-Philippe est en congrès cette semaine et son ordinateur est fermé.

Je dois y inscrire les factures de septembre. Pouvez-vous m'aider?

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
            }
            C = @{
                Sujet       = 'LibreOffice ne s''ouvre plus du tout'
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
                Sujet       = 'Nos factures n''ont plus la même apparence'
                Description = @'
Bonjour,

La Coopérative de santé du Littoral m'a appelée : elle trouve que notre dernière facture « ne ressemble pas aux autres » et elle voulait s'assurer qu'elle venait bien de nous. En comparant, je vois que la police n'est plus la même et que les titres sont plus larges. Je n'ai pourtant pas touché au modèle (T:\Modèles\Facture-AB.ott).

Louis-Philippe tient beaucoup à notre charte graphique : tous les documents envoyés aux clients doivent être en Montserrat. Je joins une facture du mois d'août, qui a la bonne apparence, pour comparer.

Merci de corriger ça avant ma prochaine facturation.
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
                PieceJointe = 'ncote\fichiers\Documents\Facturation\2026\Facture 2026-0140 Chalet du Lac-Boréal.pdf'
            }
            E = @{
                Sujet       = 'Le numéro et la date ne se remplissent plus sur mes factures'
                Description = @'
Bonjour,

Quand je crée une nouvelle facture à partir du modèle (T:\Modèles\Facture-AB.ott), le numéro de facture et la date se remplissaient tout seuls. Depuis cette semaine, ils restent vides, et j'ai un message à propos des macros. Je dois tout taper à la main et j'ai peur de me tromper dans la numérotation.

Pouvez-vous rétablir ça, sans rendre mon ordinateur moins sécuritaire?

Merci,
Nathalie Côté
Adjointe administrative, Architecture Boréale
'@
            }
        }
    }
}
