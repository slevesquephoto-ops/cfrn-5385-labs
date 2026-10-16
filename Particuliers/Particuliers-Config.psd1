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
            Id = 'ACC-CLAVIER'; Titre = 'Disposition de clavier anglaise par défaut'; Portee = 'Profil'; Duree = '5 / 10'; Difficulte = 1
            Recit = 'Mes « é » écrivent des « / » et mes « ? » des « É ». Le clavier tape de travers.'
            Cause = 'Disposition « États-Unis » (QWERTY) ajoutée et placée par défaut dans le profil (HKCU\Keyboard Layout\Preload, entrée « 1 » = 00000409).'
            Correction = 'Paramètres > Heure et langue > Langue et région : remettre « Français (Canada) » / la bonne disposition en premier, ou retirer la disposition anglaise. Prend effet à la réouverture de session.'
            Incompatibles = @()
        }
        @{
            Id = 'ACC-FILTRES'; Titre = 'Touches filtres activées'; Portee = 'Profil'; Duree = '5 / 10'; Difficulte = 1
            Recit = 'Mon clavier ne répond plus comme avant : il faut que j''appuie longtemps sur une touche et les lettres ne se répètent plus.'
            Cause = 'Touches filtres activées dans le profil (HKCU\Control Panel\Accessibility\Keyboard Response, Flags bit 0).'
            Correction = 'Paramètres > Accessibilité > Clavier : désactiver « Touches filtres ». Maintenir Maj droite 8 s rouvre aussi la boîte de dialogue.'
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
            Id = 'RES-DUPLEX'; Titre = 'Carte réseau en 10 Mbps half-duplex'; Portee = 'Machine'; Duree = '15 / 25'; Difficulte = 4
            Recit = 'Internet est devenu extrêmement lent, les pages mettent une éternité à charger, mais je suis bien connectée.'
            Cause = 'Propriété Vitesse/Duplex de la carte forcée à « 10 Mbps Half Duplex » au lieu de l''auto-négociation.'
            Correction = 'Gestionnaire de périphériques > carte réseau > Avancé > Vitesse et duplex : « Négociation automatique ». VRAI MATÉRIEL seulement (carte virtuelle Hyper-V sans cette propriété).'
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
        @{
            Id = 'SEC-BOUCLE'; Titre = 'Faux malware : lanceur en boucle au démarrage'; Portee = 'Profil'; Duree = '20 / 30'; Difficulte = 3
            Recit = 'Quand j''ouvre ma session, des fenêtres s''ouvrent sans arrêt et l''ordinateur devient inutilisable. Un « nettoyeur » que j''ai téléchargé l''aurait fait.'
            Cause = 'Clé Run du profil qui lance au logon un script caché bouclant sur une application (remplit la mémoire). Punitif : ne se déclenche qu''à l''ouverture de session du client.'
            Correction = 'Se connecter avec un AUTRE compte (ou Windows RE), retirer la clé Run et le script caché, puis fermer les fenêtres ouvertes. La session du client redevient utilisable.'
            Incompatibles = @()
        }

        # --- Navigateur et sécurité ---
        @{
            Id = 'NAV-PIRATE'; Titre = 'Navigateur détourné (Edge)'; Portee = 'Machine'; Duree = '15 / 25'; Difficulte = 3
            Recit = 'Ma page d''accueil a changé toute seule et mes recherches passent par un drôle de moteur « Recherche Express ».'
            Cause = 'Stratégies Edge (HKLM\SOFTWARE\Policies\Microsoft\Edge) : page d''accueil vers une page locale « Recherche Express » et moteur par défaut factice. Bandeau « Géré par votre organisation ».'
            Correction = 'Supprimer les stratégies Edge (clé HKLM\SOFTWARE\Policies\Microsoft\Edge ou via gpedit) puis rouvrir Edge. Vérifier edge://policy et edge://settings/searchEngines.'
            Incompatibles = @()
        }
        @{
            Id = 'PUP-FAUX'; Titre = 'Faux logiciel « OptimiseurPC Pro »'; Portee = 'Profil'; Duree = '20 / 30'; Difficulte = 4
            Recit = 'Un logiciel « OptimiseurPC Pro » s''ouvre au démarrage et me dit que j''ai plein de virus, il veut que je paie.'
            Cause = 'Faux logiciel indésirable à trois endroits : entrée dans « Applications installées » (clé Uninstall), démarrage automatique (clé Run du profil) et tâche planifiée ouvrant une page d''alerte locale à l''ouverture de session.'
            Correction = 'Désinstaller / supprimer l''entrée Applications, retirer l''élément de démarrage (Gestionnaire des tâches > Démarrage) et la tâche planifiée (Autoruns les montre tous). Supprimer le dossier dans ProgramData.'
            Incompatibles = @()
        }
        @{
            Id = 'SEC-EXCL'; Titre = 'Exclusion Defender sur tout le disque'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'Mon ordinateur agit bizarrement, mais Windows Defender dit que tout va bien et ne trouve jamais rien.'
            Cause = 'Exclusion Microsoft Defender ajoutée sur C:\ : l''antivirus ne scanne plus rien. Se découvre en vérifiant les paramètres de l''antivirus.'
            Correction = 'Sécurité Windows > Protection contre les virus et menaces > Gérer les paramètres > Exclusions : retirer C:\. (Protection contre les falsifications à désactiver pour modifier les exclusions.)'
            Incompatibles = @('SEC-EICAR-TIERS')
        }

        # --- Comptes et fichiers ---
        @{
            Id = 'CPT-MDP'; Titre = 'Mot de passe oublié / changé'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'J''ai oublié mon mot de passe et je n''arrive plus à ouvrir ma session.'
            Cause = 'Mot de passe du client remplacé par une valeur inconnue.'
            Correction = 'Depuis un autre compte administrateur : gestion des comptes locaux (lusrmgr.msc ou net user) pour redéfinir un mot de passe. Le client le changera ensuite.'
            Incompatibles = @()
        }
        @{
            Id = 'CPT-ADMIN'; Titre = 'Client retiré des Administrateurs'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Je ne peux plus rien installer ni changer les réglages : tout me demande un mot de passe administrateur.'
            Cause = 'Compte du client retiré du groupe Administrateurs (clients administrateurs seulement).'
            Correction = 'Depuis un autre compte administrateur : Paramètres > Comptes, ou lusrmgr.msc, pour remettre le client dans le groupe Administrateurs.'
            Incompatibles = @()
        }
        @{
            Id = 'FIC-CACHES'; Titre = 'Dossiers personnels cachés'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Mes dossiers Documents, Images et Bureau ont disparu après avoir branché une clé USB.'
            Cause = 'Dossiers personnels du profil marqués « cachés + système » (effet typique d''une clé USB infectée).'
            Correction = 'Explorateur > Affichage : montrer les éléments masqués ET décocher « Masquer les fichiers protégés du système d''exploitation », puis retirer les attributs caché/système (Propriétés ou attrib -h -s).'
            Incompatibles = @()
        }
        @{
            Id = 'FIC-REDIR'; Titre = 'Documents redirigé vers un lecteur absent'; Portee = 'Profil'; Duree = '15 / 20'; Difficulte = 3
            Recit = 'Mon dossier Documents est introuvable, Windows dit qu''un emplacement n''est pas disponible.'
            Cause = 'Dossier Documents redirigé vers D:\Documents (lecteur inexistant) dans le profil (User Shell Folders / Shell Folders, valeur Personal).'
            Correction = 'Propriétés du dossier Documents > Emplacement > Restaurer les valeurs par défaut, ou corriger la valeur Personal dans le registre pour revenir sous le profil.'
            Incompatibles = @()
        }
        @{
            Id = 'CPT-TEMP'; Titre = 'Profil temporaire (inscription renommée)'; Portee = 'Profil'; Duree = '20 / 30'; Difficulte = 5
            Recit = 'Tous mes fichiers ont disparu, mon bureau est vide et Windows dit « Vous êtes connecté avec un profil temporaire ».'
            Cause = 'Inscription du profil (HKLM\...\ProfileList\<SID>) renommée en « <SID>.bak » : Windows ouvre un profil temporaire. Les données sont intactes sur le disque.'
            Correction = 'Planificateur hors session (autre compte) : dans ProfileList, renommer « <SID>.bak » en « <SID> » (retirer le .bak), vérifier ProfileImagePath, puis rouvrir la session du client. À DONNER SEULE.'
            Incompatibles = @('ACC-SOURIS', 'ACC-CLAVIER', 'ACC-FILTRES', 'RES-PROXY', 'SEC-BOUCLE', 'PUP-FAUX', 'CPT-MDP', 'CPT-ADMIN', 'FIC-CACHES', 'FIC-REDIR', 'SYS-DISQUE', 'STRAT-BUREAU', 'STRAT-PANNEAU', 'STRAT-ARRET', 'STRAT-CMD', 'STRAT-RUN', 'STRAT-TASKMGR')
        }

        # --- Système et performance ---
        @{
            Id = 'SYS-IMPRIM'; Titre = 'Spouleur d''impression désactivé'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Je ne peux plus imprimer : rien ne sort et la file d''attente ne s''ouvre même pas.'
            Cause = 'Service « Spouleur d''impression » (Spooler) arrêté et désactivé.'
            Correction = 'services.msc : Spouleur d''impression en démarrage Automatique, puis Démarrer.'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-SANSECHEC'; Titre = 'Démarrage en mode sans échec'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'C''est écrit « Mode sans échec » dans les quatre coins et plus rien ne marche comme avant.'
            Cause = 'Démarrage forcé en mode sans échec (bcdedit : safeboot minimal sur l''entrée courante).'
            Correction = 'msconfig > Démarrer > décocher « Démarrage sécurisé », ou bcdedit /deletevalue {current} safeboot, puis redémarrer.'
            Incompatibles = @('SYS-SON', 'SYS-IMPRIM', 'RES-DNS', 'RES-PROXY', 'RES-HOSTS', 'RES-CARTE', 'RES-IP', 'RES-PAREFEU')
        }
        @{
            Id = 'SYS-HEURE'; Titre = 'Date erronée (2016), synchro coupée'; Portee = 'Machine'; Duree = '15 / 20'; Difficulte = 3
            Recit = 'J''ai voulu régler l''heure moi-même et maintenant la date est en 2016; rien ne se corrige tout seul et aucun site sécurisé ne fonctionne.'
            Cause = 'Synchronisation automatique de l''heure désactivée (service W32Time désactivé, Type NoSync) et date reculée à 2016 par une mauvaise manipulation : l''horloge est antérieure à la validité des certificats HTTPS.'
            Correction = 'Paramètres > Heure et langue > Date et heure : activer « Régler l''heure automatiquement » (relance W32Time) puis « Synchroniser maintenant »; au besoin corriger la date à la main. Panne LOGICIELLE : à ne pas confondre avec une pile CMOS morte (défaut matériel), qui ne se corrige pas ainsi.'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-DISQUE'; Titre = 'Disque presque plein'; Portee = 'Profil'; Duree = '15 / 25'; Difficulte = 3
            Recit = 'Windows me dit sans arrêt que mon disque est plein, mais je n''ai pourtant rien installé de gros.'
            Cause = 'Gros fichier dans un dossier temporaire caché du profil (AppData\Local\Temp\MediaCache), laisse ~1 Go libre.'
            Correction = 'Afficher les éléments cachés et protégés, trouver le gros fichier dans le dossier temporaire du profil et le supprimer. Nettoyage de disque / Stockage pour confirmer l''espace repris.'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-DEMARRAGE'; Titre = 'Démarrage lent (éléments inutiles)'; Portee = 'Machine'; Duree = '15 / 20'; Difficulte = 4
            Recit = 'Mon ordinateur est devenu très lent à démarrer et à ouvrir ma session.'
            Cause = 'Plusieurs éléments de démarrage inutiles mais inoffensifs, répartis à quatre endroits : clé Run du profil (HKCU, deux valeurs), clé Run de la machine (HKLM, qui lance une charge CPU bornée rendant la session poussive), le dossier Démarrage du profil, et une tâche planifiée à l''ouverture de session.'
            Correction = 'Gestionnaire des tâches > Démarrage (clés Run + dossier Démarrage) ET Planificateur de tâches (tâche MediaLibraryIndexer) : aucun outil seul ne montre tout. Autoruns les regroupe. Désactiver puis supprimer chaque élément, et vider le dossier Démarrage du profil.'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-USB'; Titre = 'Clés USB bloquées'; Portee = 'Machine'; Duree = '10 / 15'; Difficulte = 3
            Recit = 'Ma clé USB n''est plus reconnue sur cet ordinateur, mais mon clavier et ma souris USB fonctionnent.'
            Cause = 'Service de stockage de masse USB désactivé (USBSTOR Start = 4). Les périphériques HID (clavier, souris) ne sont pas touchés.'
            Correction = 'Remettre HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR\Start = 3, rebrancher la clé. (Stratégies d''accès aux disques amovibles aussi à vérifier si présentes.)'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-RAM'; Titre = 'Mémoire maximale bridée'; Portee = 'Machine'; Duree = '15 / 20'; Difficulte = 4
            Recit = 'Mon ordinateur rame, le Gestionnaire des tâches ne montre que 3 Go de mémoire alors que j''en ai 16.'
            Cause = 'Mémoire maximale bridée au démarrage (bcdedit truncatememory, ce que coche msconfig > Démarrer > Options avancées > Mémoire maximale).'
            Correction = 'msconfig > Démarrer > Options avancées : décocher « Mémoire maximale », ou bcdedit /deletevalue {current} truncatememory, puis redémarrer.'
            Incompatibles = @()
        }
        @{
            Id = 'SYS-REDEMARRAGE'; Titre = 'Redémarrage forcé au logon (punitif)'; Portee = 'Machine'; Duree = '15 / 25'; Difficulte = 4
            Recit = 'Dès que j''ouvre ma session, l''ordinateur redémarre tout seul au bout de quelques secondes. Impossible de travailler.'
            Cause = 'Tâche planifiée déclenchée à l''ouverture de session DU CLIENT qui lance shutdown /r (reste d''un script de mise à jour mal effacé).'
            Correction = 'Se connecter avec un AUTRE compte, ou démarrer dans Windows RE, pour désactiver et supprimer la tâche (Planificateur de tâches). shutdown /a annule le redémarrage déjà armé.'
            Incompatibles = @()
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
        @{
            Id = 'STRAT-RUN'; Titre = 'Commande Exécuter bloquée (stratégie)'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Mon raccourci Windows + R n''ouvre plus la petite fenêtre « Exécuter ».'
            Cause = 'Stratégie NoRun = 1 (HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer).'
            Correction = 'gpedit.msc > Configuration utilisateur > Modèles d''administration > Menu Démarrer et barre des tâches > « Supprimer le menu Exécuter... » : Non configuré. Ou supprimer la valeur NoRun dans le registre.'
            Incompatibles = @()
        }
        @{
            Id = 'STRAT-TASKMGR'; Titre = 'Gestionnaire des tâches bloqué (stratégie)'; Portee = 'Profil'; Duree = '10 / 15'; Difficulte = 2
            Recit = 'Quand j''essaie d''ouvrir le Gestionnaire des tâches, un message dit qu''il a été désactivé par mon administrateur.'
            Cause = 'Stratégie DisableTaskMgr = 1 (HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System).'
            Correction = 'gpedit.msc > Configuration utilisateur > Modèles d''administration > Système > Options Ctrl+Alt+Suppr > « Supprimer le Gestionnaire des tâches » : Non configuré. Ou supprimer la valeur DisableTaskMgr dans le registre.'
            Incompatibles = @()
        }
    )
}
