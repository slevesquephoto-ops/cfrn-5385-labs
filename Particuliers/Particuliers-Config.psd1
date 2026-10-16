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
        @{
            Id = 'SEC-EICAR-DEF'; Titre = 'Fausse infection (Defender actif)'; Portee = 'Machine'; Duree = '20 / 35'; Difficulte = 4
            Recit = 'Mon antivirus arrête pas de me dire qu''il a trouvé un virus, je le supprime et il revient!'
            Cause = 'Fichier de test EICAR (inoffensif) redéposé par une tâche planifiée à l''ouverture de session et toutes les 5 min; Microsoft Defender le met en quarantaine à chaque fois.'
            Correction = 'Reconnaître que Defender fait son travail, trouver la tâche planifiée qui relance le dépôt (Planificateur de tâches / Autoruns), la supprimer avec son script, puis vider la quarantaine.'
            Incompatibles = @('SEC-EICAR-TIERS')
        }
        @{
            Id = 'SEC-EICAR-TIERS'; Titre = 'Fausse infection (dossier exclu de Defender)'; Portee = 'Machine'; Duree = '25 / 40'; Difficulte = 5
            Recit = 'Mon ordinateur agit bizarrement, mais Windows Defender dit que tout va bien.'
            Cause = 'Même fichier de test EICAR et même tâche de réapparition, mais le dossier de dépôt est exclu de Defender : il ne voit rien.'
            Correction = 'Installer et lancer un autre antivirus (ex. Malwarebytes) pour détecter le fichier, retirer l''exclusion dans Defender, puis supprimer la tâche et son script. (Exige la protection contre les falsifications désactivée pour l''installation.)'
            Incompatibles = @('SEC-EICAR-DEF')
        }

        # --- Restrictions par stratégie (restes d'un faux « optimiseur » ou « contrôle parental ») ---
        # Portée Profil : valeurs de stratégie dans la ruche du client. La correction passe par
        # gpedit.msc ou le registre (pas un simple réglage), d'où une difficulté plus élevée.
        @{
            Id = 'STRAT-BUREAU'; Titre = 'Icônes du bureau masquées (stratégie)'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'Mon bureau est complètement vide, toutes mes icônes ont disparu. Clic droit « Afficher les icônes du bureau » ne change rien.'
            Cause = 'Stratégie NoDesktop = 1 (HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer) : reste d''un faux optimiseur.'
            Correction = 'gpedit.msc > Configuration utilisateur > Modèles d''administration > Bureau > « Masquer et désactiver tous les éléments du Bureau » : Non configuré. Ou supprimer la valeur NoDesktop dans le registre, puis fermer la session.'
            Incompatibles = @()
        }
        @{
            Id = 'STRAT-PANNEAU'; Titre = 'Panneau de configuration bloqué (stratégie)'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'Quand je clique sur le Panneau de configuration, un message dit que c''est bloqué par mon administrateur. Les Paramètres ne s''ouvrent plus non plus.'
            Cause = 'Stratégie NoControlPanel = 1 (HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer) : bloque le Panneau de configuration et l''application Paramètres.'
            Correction = 'gpedit.msc > Configuration utilisateur > Modèles d''administration > Panneau de configuration > « Interdire l''accès au Panneau de configuration et à l''application Paramètres du PC » : Non configuré. Ou supprimer la valeur NoControlPanel dans le registre.'
            Incompatibles = @()
        }
        @{
            Id = 'STRAT-ARRET'; Titre = 'Arrêter / Redémarrer retirés (stratégie)'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Je ne trouve plus comment éteindre l''ordinateur, le bouton a disparu du menu Démarrer.'
            Cause = 'Stratégie NoClose = 1 (HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer) : retire les commandes Arrêter / Redémarrer du menu Démarrer.'
            Correction = 'gpedit.msc > Configuration utilisateur > Modèles d''administration > Menu Démarrer et barre des tâches > « Supprimer et empêcher l''accès aux commandes Arrêter... » : Non configuré. Ou supprimer la valeur NoClose dans le registre. (Arrêt possible entre-temps par Alt+F4 sur le bureau ou shutdown /s.)'
            Incompatibles = @()
        }
        @{
            Id = 'STRAT-CMD'; Titre = 'Invite de commandes désactivée (stratégie)'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Mon petit-fils veut m''aider à distance mais l''invite de commandes ne s''ouvre plus : « L''invite de commandes a été désactivée par votre administrateur ».'
            Cause = 'Stratégie DisableCMD = 2 (HKCU\Software\Policies\Microsoft\Windows\System) : cmd.exe interactif bloqué, scripts encore permis.'
            Correction = 'gpedit.msc > Configuration utilisateur > Modèles d''administration > Système > « Empêcher l''accès à l''invite de commandes » : Non configuré. Ou supprimer la valeur DisableCMD dans le registre. (Le diagnostic se fait par PowerShell, non visé par cette stratégie.)'
            Incompatibles = @()
        }
    )
}
