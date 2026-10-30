# Pannes spontanées — Clients particuliers

Spécification de référence (**approuvée par l'enseignant le 2026-10-13**).
Ce fichier fait foi : demander avant de changer un nom, un client, une panne ou une règle.

## Principe

Un client fictif (particulier) « apporte » son ordinateur au comptoir. L'enseignant
choisit, sur n'importe quel poste du labo, **un client et une ou plusieurs pannes**.

- Le client est absent du poste : le script crée son compte, son profil complet, ses
  données, **puis** installe la panne.
- Le client est présent : le script ne fait **que** installer ou retirer la panne (le
  profil, les données et ce que les élèves y ont fait sont conservés).
- Chaque panne est autonome (installation, retrait exact, vérification) et peut se
  superposer à d'autres pannes du même client, sauf incompatibilité déclarée.

## Postes visés

- Postes variés du labo, **Windows 10 et Windows 11** (Pro ou Famille), nom quelconque.
  Aucun contrôle de nom de poste (contrairement à AB).
- Accès à Internet : oui.
- Les postes AB peuvent aussi servir. Garde-fou : une panne de portée **Machine** est
  refusée si une panne AB est installée sur le poste.
- **Aucun réseau social** dans les récits, les sites visés ou les pages déposées.
  Seulement des sites neutres (météo, nouvelles, encyclopédie) et des pages locales.

## Clients fictifs

| Compte | Client | Type de compte | Données typiques |
| --- | --- | --- | --- |
| mbelanger | Monique Bélanger, retraitée, peu à l'aise en informatique | Administrateur | Photos des petits-enfants, recettes, lettres, budget |
| tgagnon | Thomas Gagnon, étudiant au cégep | Administrateur | Travaux scolaires, notes de cours, musique |
| sroy | Sylvie Roy, couturière à son compte | Administrateur | Factures, soumissions, comptabilité (`.ods`), patrons |
| bdionne | Benoît Dionne, pêcheur côtier | Standard (son fils est l'administrateur) | Photos du bateau, documents d'immatriculation, permis |
| couellet | Famille Ouellet (compte partagé) | Administrateur | Un peu de tout, en désordre |
| jblais | Julien Blais, expérimentateur qui bidouille partout et ne sait pas réparer ensuite | Administrateur | Tweaks de registre, notes d'overclock, outils téléchargés, « à réparer » |

La liste de clients est **ouverte** : on en ajoute au besoin (objectif pédagogique = beaucoup de
profils variés). Chaque nouveau client = un jeu de données dans `tools/New-PartData.ps1` + son
entrée dans `Particuliers-Config.psd1` (compte, type, données, fond d'écran, raccourcis, favoris,
logiciels).

**Comptes standard et « aidant ».** Un client peut être un compte **standard** (`Admin = $false`,
ex. bdionne). Dans ce cas, un champ `Aidant` crée **en plus** un compte **administrateur** distinct
sur la machine (ex. son fils mdionne) : c'est l'accès admin « en fiction » que l'élève utilise pour
réparer les pannes punitives quand la session du client est bloquée. L'aidant (compte + profil) est
créé avec le client et retiré avec lui (sauf s'il est partagé par un autre client encore présent).

- Mots de passe : fictifs, simples et réalistes pour un particulier, documentés dans
  `Particuliers/README-Clients.txt` (règle 8 du dépôt).
- Le compte `couellet` a pour nom complet « Famille Ouellet ».
- Données : 15 à 30 fichiers par client, générées une fois (`tools/New-PartData.ps1`,
  même méthode qu'AB : LibreOffice sans interface) et committées dans
  `Particuliers/data/<compte>/` avec un manifeste CSV au format AB.
- Fond d'écran propre à chaque client (une image de Windows différente par client).
- Copie des données : seulement les fichiers absents (jamais d'écrasement d'un profil
  existant).

### Profil crédible (enrichissement)

Au-delà des données, le profil du client est rendu crédible à sa création
(`Set-PartClientProfileExtras`, réutilise la mécanique AB). Champs par client dans la config :

- `FondEcran` : chemin précis, sinon une image Windows intégrée choisie de façon déterministe
  par compte (différente d'un client à l'autre).
- `Raccourcis` (Bureau) : `@{ Nom; Cible }` où `Cible` vaut `EDGE`, `LIBREOFFICE` (logiciel
  **réel**, raccourci sauté s'il est absent) ou un chemin avec le jeton `%PROFIL%`.
- `Favoris` : marque-pages Edge (`@{ Nom; Url }`) écrits dans le fichier `Bookmarks` du profil.
  Sites neutres uniquement (règle du dépôt). Jamais écrasés s'ils existent déjà.
- `Logiciels` (mixte) : **réels** = raccourcis vers l'existant (Edge, LibreOffice) ; **simulés**
  = `@{ Id; Nom; Version; Editeur }` → entrée « Applications installées » (HKCU Uninstall),
  dossier d'installation et raccourci menu Démarrer, tous **dans le profil** (inoffensifs,
  retirés avec le client). Aucun gros installeur réseau.

Les données sont générées par `tools/New-PartData.ps1 -Compte <compte>` (textes légers + photos
d'espace réservé, aucune personne réelle) et committées dans `data/<compte>/` avec le manifeste.

## Catalogue des pannes

Portée : **M** = toute la machine, **P** = profil du client. Durées : rapide / normal.

Difficulté (champ `Difficulte`, 1 à 5) : sert à la « panne au hasard » de la console et
au dosage par l'enseignant. Repère de calibrage : une panne qui se corrige par un simple
réglage bien visible reste **1–2** (ex. ACC-SOURIS, RES-CARTE). On vise la plupart des
pannes à **3+**, soit en cachant le bon chemin de correction, soit en désactivant le
réglage évident (ex. une restriction par stratégie qu'on ne défait qu'au registre). Note :
SYS-SON coupe le **service** audio — le panneau Son ne suffit pas, il faut `services.msc`.

### Réseau et Internet

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| RES-DNS | « L'icône dit que je suis connectée, mais aucune page ne s'ouvre. » | Serveurs DNS manuels invalides sur la carte active | M | 10 / 20 |
| RES-PROXY | « Aucun site ne s'ouvre, ça tourne dans le vide. » | Proxy `127.0.0.1:8080` dans le profil (restant d'un logiciel publicitaire) | P | 10 / 20 |
| RES-HOSTS | « Je n'arrive plus à aller sur la météo ni sur Radio-Canada. » | Entrées `hosts` qui envoient des sites neutres vers une adresse morte | M | 10 / 15 |
| RES-CARTE | « Plus d'Internet du tout, il y a un globe barré. » | Carte réseau désactivée | M | 5 / 10 |
| RES-IP | « Internet limité » | Adresse IP statique dans le mauvais sous-réseau | M | 10 / 15 |
| RES-PAREFEU | « Edge dit que je n'ai pas Internet, mais les mises à jour passent. » | Règle sortante du pare-feu qui bloque `msedge.exe`, au nom d'apparence normale | M | 15 / 25 |
| RES-DUPLEX | « Internet est devenu extrêmement lent, mais je suis connectée. » | Carte réseau forcée en 10 Mbps half-duplex au lieu de l'auto-négociation | M | 15 / 25 — *vrai matériel seulement (carte virtuelle Hyper-V sans cette propriété)* |

### Navigateur et logiciels indésirables

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| NAV-PIRATE | « Ma page d'accueil a changé et mes recherches ne marchent plus. » | Stratégies Edge : page d'accueil vers une fausse page locale « Recherche Express », moteur de recherche `recherche-express.example` (« Géré par votre organisation ») | M | 15 / 25 |
| PUP-FAUX | « Un message me dit que j'ai plein de virus. » | Faux logiciel « OptimiseurPC Pro » : entrée dans Applications, démarrage automatique, tâche planifiée qui ouvre une page d'alerte locale | P+M | 20 / 30 |
| SEC-EXCL | (découverte en vérifiant l'antivirus) | Exclusion Microsoft Defender sur `C:\` | M | 10 / 15 — *à valider en VM (protection contre les falsifications)* |
| SEC-BOUCLE | « Des fenêtres s'ouvrent sans arrêt à l'ouverture de ma session. » | Faux « nettoyeur » : clé Run du profil qui lance au logon un script caché bouclant sur une appli (sature la session). Punitif, déclenché au logon du client seulement | P | 20 / 30 |

### Simulation d'infection (fichier de test EICAR)

Fichier de test antivirus standard EICAR : inoffensif, reconnu par tous les antivirus,
redéposé par une tâche planifiée à l'ouverture de session et toutes les 5 minutes.
Rien de nuisible ne s'exécute. Dans le code, la chaîne n'est jamais écrite en clair : elle
est reconstruite à partir de codes d'octets à l'exécution, donc aucun fichier du dépôt ni le
script générateur ne portent la signature (seul le fichier déposé déclenche l'antivirus).

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| SEC-EICAR-DEF | « Mon antivirus trouve un virus, je le supprime et il revient! » | Tâche planifiée qui redépose EICAR; **Defender reste actif** et le met en quarantaine à chaque fois | M | 20 / 35 |
| SEC-EICAR-TIERS | « Mon ordinateur agit bizarrement, mais Defender dit que tout va bien. » | Même mécanisme, mais le **dossier de dépôt est exclu de Defender** : l'élève doit installer un autre antivirus | M | 25 / 40 — *validé en VM (W10 et W11)* |

- Les deux variantes sont incompatibles entre elles (même tâche, même dossier).
- But pédagogique : comprendre que supprimer le fichier ne suffit pas; trouver et retirer
  la tâche qui le relance. SEC-EICAR-TIERS pousse en plus à évaluer un antivirus tiers.
- SEC-EICAR-TIERS ajoute une exclusion Defender. Constat en VM (W10 et W11, commit
  `eed298a`) : l'exclusion s'ajoute **même avec la protection contre les falsifications
  active**; aucune préparation manuelle n'est donc requise. Le Retrait la remet comme avant.

### Système et performance

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| SYS-DISQUE | « Il me dit que mon disque est plein. » | Gros fichier dans un dossier temporaire caché du profil (laisse environ 1 Go libre) | P | 15 / 25 |
| SYS-DEMARRAGE | « Il est devenu très lent à démarrer. » | Éléments de démarrage inutiles (clés Run et tâche planifiée) | P+M | 15 / 20 |
| SYS-SANSECHEC | « C'est écrit Mode sans échec dans les coins. » | Démarrage forcé en mode sans échec (`bcdedit safeboot minimal`) | M | 10 / 15 |
| SYS-HEURE | « J'ai réglé l'heure moi-même, la date est en 2016 et aucun site sécurisé ne fonctionne. » | Synchro automatique coupée (W32Time désactivé, NoSync) + date reculée à 2016 par mauvaise manipulation. Panne **logicielle** ≠ pile CMOS morte (défaut matériel, fiche physique à part) | M | 15 / 20 |
| SYS-SON | « Je n'ai plus de son. » | Service Audio Windows désactivé | M | 10 / 15 |
| SYS-IMPRIM | « Je ne peux plus imprimer. » | Spouleur d'impression désactivé | M | 10 / 15 |
| SYS-USB | « Ma clé USB n'est pas reconnue, mais mon clavier USB marche. » | Stockage de masse USB désactivé (service `USBSTOR` Start = 4); HID intacts | M | 10 / 15 |
| SYS-RAM | « Mon PC rame, je ne vois que 3 Go sur 16. » | Mémoire maximale bridée au démarrage (`bcdedit truncatememory`, comme msconfig); plancher 3072 Mo | M | 15 / 20 |
| SYS-REDEMARRAGE | « Mon PC redémarre tout seul peu après l'ouverture de session. » | Tâche déclenchée au logon **du client** qui lance `shutdown /r`. Punitif : réparer depuis un autre compte ou Windows RE | M | 15 / 25 |

### Démarrage pré-système (pannes « hors-système »)

Nouvelle catégorie. Symptôme partagé, raconté presque pareil par le client :
**« Je n'arrive plus à atteindre Windows au démarrage. »** Plusieurs causes possibles
derrière le même écran d'échec — c'est tout l'intérêt pédagogique (même symptôme,
diagnostic différent). Préfixe `BOOT-`.

Ces pannes sont d'une **nature différente** des autres : une fois actives, la machine ne
démarre plus sur Windows, donc **PowerShell Direct et le moteur ne peuvent plus agir** (ni
retirer, ni vérifier depuis l'OS). Règles valables pour toute panne `BOOT-` :

- **Installation** : scriptable normalement (prend effet au prochain démarrage). La panne
  **sauvegarde l'état d'origine** (snapshot BCD) avant de le modifier, comme les autres
  (retrait exact).
- **Retrait** : le bloc `Retirer` restaure l'état exact, mais il n'est exécutable que
  **tant que l'OS démarre encore** (avant reboot) ou **depuis Windows RE** (store BCD hors
  ligne). En usage réel, le retrait **est l'exercice de l'élève, en WinRE**.
- **Garde-fou obligatoire** : ne jamais rendre la machine **irrécupérable** (pas de
  suppression du store BCD complet, pas de wipe de la partition WinRE, pas de BitLocker).
  WinRE doit rester joignable par média d'installation / clé de récupération. En revanche,
  désactiver la **réparation automatique** (`recoveryenabled No`) est permis et même
  nécessaire : sans ça, Windows répare le BCD tout seul au démarrage suivant et la panne se
  soigne d'elle-même (constat VM). C'est ce qui force l'élève à réparer à la main.
- **Vérification en VM** : on contrôle seulement la **configuration** (lecture du BCD avant
  reboot), comme SYS-SANSECHEC et SYS-HEURE.
- **Test réel du symptôme** : installer → redémarrer la VM → `Capture` (capture d'écran)
  pour confirmer l'écran d'erreur / l'entrée WinRE → `Reset` au point `Propre`. La boucle
  automatique install→vérif→retrait→vérif **ne s'applique pas**.
- **Portée M, incompatible avec tout** (machine non démarrable) : **à donner seule**, comme
  CPT-TEMP.

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| BOOT-BCD | « Quand j'allume, je n'atteins plus Windows : un écran bleu avec un code d'erreur, ça n'avance pas. » | Entrée `{default}` du BCD : réparation automatique coupée (`recoveryenabled No`) **et** chemin du chargeur (`path`) faussé → `winload` introuvable au démarrage (écran « Récupération », code `0xc000000f` — fichier manquant), qui reste affiché. Réparation en Windows RE | M | 25 / 40 — *hors-système : vérif. config en VM, symptôme réel (OS bloqué) confirmé en VM* |

Correction attendue (BOOT-BCD) : démarrer dans **Windows RE** (média d'installation / clé de
récupération ; la réparation auto étant coupée, elle ne part plus seule) → **Réparation du
démarrage**. Si insuffisant, invite de commandes WinRE : `bootrec /scanos` puis
`bootrec /rebuildbcd`, ou `bcdedit /set {default} path \Windows\system32\winload.efi` (`.exe`
en BIOS hérité) **et** `bcdedit /set {default} recoveryenabled Yes`. À distinguer d'une panne
matérielle (disque absent) : ici le disque et Windows sont intacts, seule l'entrée de démarrage
est fausse.

Membres à venir de la même famille (même récit, autre cause — **non spécifiés, à caler plus
tard**) : p. ex. entrée `{default}` **supprimée** (`bootrec /rebuildbcd`), fichier de
démarrage introuvable, ou sélection de démarrage faussée. Chacun s'ajoutera comme une ligne
`BOOT-<…>` quand tu voudras.

### Compte et fichiers

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| CPT-MDP | « J'ai oublié mon mot de passe. » | Mot de passe changé pour une valeur inconnue | P | 10 / 15 |
| CPT-ADMIN | « Je ne peux plus rien installer. » | Client retiré du groupe Administrateurs (clients administrateurs seulement) | P | 10 / 15 |
| CPT-TEMP | « Tous mes fichiers ont disparu! » (profil temporaire) | Inscription du profil (`ProfileList\<SID>`) renommée en `.bak` | P | 20 / 30 — *à valider en VM* |
| FIC-CACHES | « Mes dossiers ont disparu après avoir branché une clé. » | Dossiers du client marqués cachés et système | P | 10 / 15 |
| FIC-REDIR | « Mon dossier Documents est introuvable. » | Dossier Documents redirigé vers `D:\Documents` (inexistant) | P | 15 / 20 |

### Restrictions par stratégie (registre, plus coriaces)

Restes d'un faux « optimiseur » ou « contrôle parental » installé par le client. Portée
**P** (ruche du client). La correction ne passe pas par un simple réglage : il faut
`gpedit.msc` ou le registre. Toutes compatibles entre elles et avec les autres pannes.

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| STRAT-BUREAU | « Mon bureau est vide, toutes mes icônes ont disparu. » | `NoDesktop = 1` (Policies\Explorer) : masque tous les éléments du bureau | P | 10 / 15 |
| STRAT-PANNEAU | « Le Panneau de configuration est bloqué par mon administrateur. » | `NoControlPanel = 1` (Policies\Explorer) : bloque Panneau de configuration **et** Paramètres | P | 10 / 15 |
| STRAT-ARRET | « Je ne trouve plus comment éteindre l'ordinateur. » | `NoClose = 1` (Policies\Explorer) : retire Arrêter / Redémarrer du menu Démarrer | P | 10 / 15 |
| STRAT-CMD | « L'invite de commandes ne s'ouvre plus. » | `DisableCMD = 2` (Policies\Microsoft\Windows\System) : cmd bloqué, scripts permis | P | 10 / 15 |
| STRAT-RUN | « Windows + R n'ouvre plus la fenêtre Exécuter. » | `NoRun = 1` (Policies\Explorer) | P | 10 / 15 |
| STRAT-TASKMGR | « Le Gestionnaire des tâches a été désactivé par l'administrateur. » | `DisableTaskMgr = 1` (Policies\System) | P | 10 / 15 |

### Accessibilité et périphériques (rapides, pour réchauffer)

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| ACC-CLAVIER | « Mes é écrivent des / et mes ? des É. » | Disposition anglaise ajoutée et mise par défaut | P | 5 / 10 |
| ACC-FILTRES | « Mon clavier ne répond plus comme avant. » | Touches filtres activées | P | 5 / 10 |
| ACC-SOURIS | « Ma souris fonctionne à l'envers. » | Boutons de la souris inversés | P | 5 / 5 |

### Incompatibilités

- Une seule panne réseau qui modifie la carte à la fois : RES-DNS, RES-IP et RES-CARTE.
- SEC-EICAR-DEF et SEC-EICAR-TIERS : jamais ensemble (même tâche, même dossier de dépôt).
- CPT-ADMIN : seulement pour un client administrateur.
- CPT-TEMP masque les autres pannes de profil : à donner seule.
- SYS-SANSECHEC désactive le son, l'impression et le réseau selon le mode. Ne pas la
  combiner à SYS-SON, SYS-IMPRIM ou à une panne réseau.
- Pannes `BOOT-*` (démarrage pré-système) : machine non démarrable → **à donner seules**,
  incompatibles avec toutes les autres pannes.

### Exclues

- Associations de fichiers (`.pdf`, `.txt`, navigateur par défaut) : protégées par
  Windows (UserChoice, UCPD).
- Tout vrai logiciel malveillant et toute page externe : les « menaces » sont des pages
  locales inoffensives.
- Pannes physiques (RAM, disque, pile CMOS, câbles) : fiche manuelle à part, comme R2.

## Discrétion

- Rien de visible ne contient « Panne », « Particulier », « Labo » ou « CFRN » : noms
  de tâches, règles, entrées et fichiers d'apparence normale.
- État et journaux dans le dossier caché de `Get-LabDataPath`, un état par panne
  (`PART-<compte>-<ID>`).

## Scripts

```
Particuliers/
  Particuliers-Config.psd1   # clients + catalogue (récit, cause, correction, durée, portée)
  Particuliers-Lab.psm1      # moteur : profil si absent, installer, retirer, vérifier
  Pannes/<ID>.ps1            # une panne : Sauvegarder, Installer, Retirer, Tester
  Client.ps1                 # point d'entrée unique
  README-Clients.txt         # mots de passe fictifs
  data/<compte>/             # données + manifeste
```

```powershell
.\Client.ps1 -Client mbelanger -Panne RES-PROXY            # profil si absent, puis la panne
.\Client.ps1 -Client mbelanger -Panne RES-PROXY -Retirer   # retire cette panne seulement
.\Client.ps1 -Client mbelanger -Retirer -Tout              # retire toutes ses pannes
.\Client.ps1 -Client mbelanger -Verifier                   # JSON, code 0 si conforme
.\Client.ps1 -Client mbelanger -Supprimer                  # retire les pannes, puis compte et profil
```

- `-Verifier` contrôle l'état **attendu d'après les pannes installées** : chaque panne
  installée doit être présente et les autres absentes. Même ligne JSON qu'AB, avec
  `"machine"` égal au nom du poste et `"client"` égal au compte.
- Code commun réutilisé tel quel en important `AB/AB-Lab.psm1` (création du profil par
  `CreateProfile`, ruche, exécution en tant qu'utilisateur, raccourcis). Aucun
  changement à AB.
- Ruche déjà chargée (le client a une session ouverte) : écriture directe dans
  `HKU\<SID>` plutôt que de monter le fichier.
- Compatible Windows PowerShell 5.1, Windows 10 et 11. Une panne qui ne s'applique pas
  à l'édition ou à la version refuse de s'installer avec un message clair.

## Console (Menu-AB.ps1)

Même console et même lanceur `Console-AB.cmd`.

- **Poste non AB** : premier écran « 1. Pannes spontanées (particuliers) /
  2. C'est un poste AB à renommer ».
- **Poste AB** : option supplémentaire « P. Pannes spontanées (particuliers) ».

Sous-menu :

```
  Pannes spontanées — <POSTE>                     Windows 11 Pro 24H2
  Client : Monique Bélanger (mbelanger) · profil présent
  Pannes installées : RES-PROXY, ACC-SOURIS
  ----------------------------------------------------------------------
    1. Choisir le client
    2. Installer une panne (crée le client au besoin)
    3. Panne au hasard (compatible, selon la difficulté)
    4. Retirer une panne
    5. Retirer toutes les pannes du client
    6. Vérifier le client
    7. Fiche de la panne (récit, symptôme, correction)
    8. Tous les clients du poste (résumé)
    S. Supprimer le client du poste (avec confirmation)
    R. Mots de passe des clients
    0. Retour
```

## Tests en VM

- VM `PART-W11-T` (et `PART-W10-T` si possible), point de contrôle `Propre` : Windows
  à jour, aucun client, Internet par le commutateur de la VM.
- `tests/Test-Particuliers.ps1`, pour chaque panne :
  `Reset` → panne (client absent : profil créé) → Verifier (0) → retrait → Verifier (0)
  → **réinstallation sur le profil existant** (profil non recréé, données conservées)
  → retrait → Verifier (0).
- Limites connues, à confirmer :
  - **SYS-HEURE** : la synchronisation d'heure de Hyper-V corrige la date. On contrôle
    seulement la configuration.
  - **SYS-SANSECHEC** : PowerShell Direct ne répond peut-être plus en mode sans échec.
    On teste seulement la configuration de démarrage, sans redémarrer.
  - **SYS-SON** : pas de carte son. On contrôle seulement l'état du service.
  - **BOOT-*** (ex. BOOT-BCD) : hors-système. On ne vérifie que la configuration de
    démarrage (BCD) avant reboot; le symptôme réel se confirme par `Capture` après
    redémarrage, puis `Reset`. Pas de boucle automatique install→vérif→retrait→vérif.

## Ordre de travail

1. Approbation de ce fichier.
2. Moteur, `Client.ps1`, un client (mbelanger) et 3 pannes (ACC-SOURIS, RES-PROXY,
   SYS-SON), puis la boucle de tests.
3. Le reste du catalogue par lots, avec un commit par panne.
4. Données des 5 clients.
5. Console et `GUIDE-PARTICULIERS.md` (une fiche par panne).
6. Optionnel, avec accord : module ITFlow **séparé** pour créer ces clients.
