@{
    # =======================================================================
    # Pannes spontanées (clients particuliers) : configuration unique.
    # Source : Particuliers/SPEC.md. Lue par Particuliers-Lab.psm1 (Get-PartConfig).
    # Les mots de passe sont fictifs et documentés dans README-Clients.txt.
    # =======================================================================

    # Compte de l'enseignant (console, PowerShell Direct). Doit exister, être administrateur
    # et activé avant qu'un client soit placé : les comptes sans mot de passe sont alors désactivés.
    Administrateur = 'ab-tech'

    # Admin = $true : le client est administrateur de son ordinateur (cas typique d'un particulier).
    # Mot de passe « prénom + année + ! » : réaliste, et conforme à la politique AB (12, complexe)
    # si le client est placé sur un poste AB.
    Clients = @(
        @{ Compte = 'mbelanger'; NomComplet = 'Monique Bélanger'; Description = 'Retraitée'; Admin = $true; MotDePasse = 'Monique1952!' }
    )

    # Catalogue des pannes réalisées (Pannes\<Id>.ps1). Portee : Machine ou Profil.
    # Une panne de portée Machine n'est installée que pour un client à la fois.
    Pannes = @(
        @{
            Id = 'ACC-SOURIS'; Titre = 'Boutons de la souris inversés'; Portee = 'Profil'; Duree = '5 / 5'; Difficulte = 1
            Recit = 'Ma souris fonctionne à l''envers : le clic ouvre un menu et je ne peux plus rien sélectionner.'
            Cause = 'Boutons principal et secondaire inversés (HKCU\Control Panel\Mouse, SwapMouseButtons = 1).'
            Correction = 'Paramètres > Bluetooth et appareils > Souris > Bouton principal : Gauche.'
            Incompatibles = @()
        }
        @{
            Id = 'RES-PROXY'; Titre = 'Proxy fantôme'; Portee = 'Profil'; Duree = '10 / 20'; Difficulte = 2
            Recit = 'Aucun site ne s''ouvre, ça tourne dans le vide. Pourtant mon petit-fils dit que le Wi-Fi marche.'
            Cause = 'Serveur proxy 127.0.0.1:8080 dans le profil (restant d''un logiciel publicitaire désinstallé).'
            Correction = 'Paramètres > Réseau et Internet > Proxy : désactiver « Utiliser un serveur proxy ». Diagnostic : un autre compte navigue sans problème.'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-SON'; Titre = 'Service audio désactivé'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Je n''ai plus de son, même pas les petits bruits de Windows. J''ai monté le volume au maximum.'
            Cause = 'Service « Audio Windows » (Audiosrv) arrêté et désactivé.'
            Correction = 'services.msc : Audio Windows en démarrage Automatique, puis Démarrer. L''utilitaire de résolution des problèmes audio le signale aussi.'
            Incompatibles = @()
        }
        @{
            Id = 'RES-DNS'; Titre = 'Serveurs DNS invalides'; Portee = 'Machine'; Duree = '10 / 20'; Difficulte = 3
            Recit = 'L''icône dit que je suis connectée, mais aucune page ne s''ouvre.'
            Cause = 'Serveurs DNS manuels invalides (203.0.113.9/10) sur la carte de la connexion Internet.'
            Correction = 'Paramètres de la carte > IPv4 > DNS : revenir à « Automatique (DHCP) ». ping par IP fonctionne, ping par nom échoue.'
            Incompatibles = @('RES-IP', 'RES-CARTE')
        }
        @{
            Id = 'RES-HOSTS'; Titre = 'Détournement par le fichier hosts'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'Je n''arrive plus à aller sur la météo ni sur Radio-Canada, mais le reste fonctionne.'
            Cause = 'Entrées dans C:\Windows\System32\drivers\etc\hosts qui envoient des sites neutres vers 0.0.0.0.'
            Correction = 'Retirer les lignes ajoutées dans le fichier hosts, puis vider le cache DNS (ipconfig /flushdns).'
            Incompatibles = @()
        }
        @{
            Id = 'RES-CARTE'; Titre = 'Carte réseau désactivée'; Portee = 'Machine'; Duree = '5 / 10'; Difficulte = 1
            Recit = 'Plus d''Internet du tout, il y a un globe barré dans le coin.'
            Cause = 'Carte réseau de la connexion Internet désactivée.'
            Correction = 'Connexions réseau (ncpa.cpl) : clic droit sur la carte > Activer.'
            Incompatibles = @('RES-DNS', 'RES-IP')
        }
        @{
            Id = 'RES-IP'; Titre = 'IP fixe dans le mauvais sous-réseau'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'Ça dit « Internet limité » et rien ne fonctionne.'
            Cause = 'Adresse IP fixe 10.73.254.9/24 (hors du réseau local) sur la carte Internet.'
            Correction = 'Paramètres de la carte > IPv4 : revenir à « Automatique (DHCP) » pour l''adresse et le DNS.'
            Incompatibles = @('RES-DNS', 'RES-CARTE')
        }
        @{
            Id = 'RES-PAREFEU'; Titre = 'Pare-feu bloque Edge'; Portee = 'Machine'; Duree = '15 / 25'; Difficulte = 4
            Recit = 'Edge dit que je n''ai pas Internet, mais les mises à jour passent et un autre navigateur marche.'
            Cause = 'Règle de pare-feu sortante qui bloque msedge.exe (nom d''apparence normale).'
            Correction = 'Pare-feu Windows Defender > Règles de trafic sortant : trouver et supprimer la règle qui bloque Edge.'
            Incompatibles = @()
        }
    )
}
