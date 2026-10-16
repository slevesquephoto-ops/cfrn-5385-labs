# Pannes spontanées — Clients particuliers

Spécification de référence (brouillon du 2026-10-13, **à approuver par l'enseignant**).
Une fois approuvée, ce fichier fait foi : demander avant de changer un nom, un client,
une panne ou une règle.

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

- Mots de passe : fictifs, simples et réalistes pour un particulier, documentés dans
  `Particuliers/README-Clients.txt` (règle 8 du dépôt).
- Le compte `couellet` a pour nom complet « Famille Ouellet ».
- Données : 15 à 30 fichiers par client, générées une fois (`tools/New-PartData.ps1`,
  même méthode qu'AB : LibreOffice sans interface) et committées dans
  `Particuliers/data/<compte>/` avec un manifeste CSV au format AB.
- Fond d'écran propre à chaque client (une image de Windows différente par client).
- Copie des données : seulement les fichiers absents (jamais d'écrasement d'un profil
  existant).

## Catalogue des pannes

Portée : **M** = toute la machine, **P** = profil du client. Durées : rapide / normal.

### Réseau et Internet

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| RES-DNS | « L'icône dit que je suis connectée, mais aucune page ne s'ouvre. » | Serveurs DNS manuels invalides sur la carte active | M | 10 / 20 |
| RES-PROXY | « Aucun site ne s'ouvre, ça tourne dans le vide. » | Proxy `127.0.0.1:8080` dans le profil (restant d'un logiciel publicitaire) | P | 10 / 20 |
| RES-HOSTS | « Je n'arrive plus à aller sur la météo ni sur Radio-Canada. » | Entrées `hosts` qui envoient des sites neutres vers une adresse morte | M | 10 / 15 |
| RES-CARTE | « Plus d'Internet du tout, il y a un globe barré. » | Carte réseau désactivée | M | 5 / 10 |
| RES-IP | « Internet limité » | Adresse IP statique dans le mauvais sous-réseau | M | 10 / 15 |
| RES-PAREFEU | « Edge dit que je n'ai pas Internet, mais les mises à jour passent. » | Règle sortante du pare-feu qui bloque `msedge.exe`, au nom d'apparence normale | M | 15 / 25 |

### Navigateur et logiciels indésirables

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| NAV-PIRATE | « Ma page d'accueil a changé et mes recherches ne marchent plus. » | Stratégies Edge : page d'accueil vers une fausse page locale « Recherche Express », moteur de recherche `recherche-express.example` (« Géré par votre organisation ») | M | 15 / 25 |
| PUP-FAUX | « Un message me dit que j'ai plein de virus. » | Faux logiciel « OptimiseurPC Pro » : entrée dans Applications, démarrage automatique, tâche planifiée qui ouvre une page d'alerte locale | P+M | 20 / 30 |
| SEC-EXCL | (découverte en vérifiant l'antivirus) | Exclusion Microsoft Defender sur `C:\` | M | 10 / 15 — *à valider en VM (protection contre les falsifications)* |

### Système et performance

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| SYS-DISQUE | « Il me dit que mon disque est plein. » | Gros fichier dans un dossier temporaire caché du profil (laisse environ 1 Go libre) | P | 15 / 25 |
| SYS-DEMARRAGE | « Il est devenu très lent à démarrer. » | Éléments de démarrage inutiles (clés Run et tâche planifiée) | P+M | 15 / 20 |
| SYS-SANSECHEC | « C'est écrit Mode sans échec dans les coins. » | Démarrage forcé en mode sans échec (`bcdedit safeboot minimal`) | M | 10 / 15 |
| SYS-HEURE | « Aucun site sécurisé ne fonctionne, il parle de mon horloge. » | Date décalée et synchronisation de l'heure désactivée (simule la pile CMOS) | M | 15 / 20 |
| SYS-SON | « Je n'ai plus de son. » | Service Audio Windows désactivé | M | 10 / 15 |
| SYS-IMPRIM | « Je ne peux plus imprimer. » | Spouleur d'impression désactivé | M | 10 / 15 |

### Compte et fichiers

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| CPT-MDP | « J'ai oublié mon mot de passe. » | Mot de passe changé pour une valeur inconnue | P | 10 / 15 |
| CPT-ADMIN | « Je ne peux plus rien installer. » | Client retiré du groupe Administrateurs (clients administrateurs seulement) | P | 10 / 15 |
| CPT-TEMP | « Tous mes fichiers ont disparu! » (profil temporaire) | Inscription du profil (`ProfileList\<SID>`) renommée en `.bak` | P | 20 / 30 — *à valider en VM* |
| FIC-CACHES | « Mes dossiers ont disparu après avoir branché une clé. » | Dossiers du client marqués cachés et système | P | 10 / 15 |
| FIC-REDIR | « Mon dossier Documents est introuvable. » | Dossier Documents redirigé vers `D:\Documents` (inexistant) | P | 15 / 20 |

### Accessibilité et périphériques (rapides, pour réchauffer)

| ID | Ce que dit le client | Cause installée | Portée | Durée |
| --- | --- | --- | --- | --- |
| ACC-CLAVIER | « Mes é écrivent des / et mes ? des É. » | Disposition anglaise ajoutée et mise par défaut | P | 5 / 10 |
| ACC-FILTRES | « Mon clavier ne répond plus comme avant. » | Touches filtres activées | P | 5 / 10 |
| ACC-SOURIS | « Ma souris fonctionne à l'envers. » | Boutons de la souris inversés | P | 5 / 5 |

### Incompatibilités

- Une seule panne réseau qui modifie la carte à la fois : RES-DNS, RES-IP et RES-CARTE.
- CPT-ADMIN : seulement pour un client administrateur.
- CPT-TEMP masque les autres pannes de profil : à donner seule.
- SYS-SANSECHEC désactive le son, l'impression et le réseau selon le mode. Ne pas la
  combiner à SYS-SON, SYS-IMPRIM ou à une panne réseau.

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

## Ordre de travail

1. Approbation de ce fichier.
2. Moteur, `Client.ps1`, un client (mbelanger) et 3 pannes (ACC-SOURIS, RES-PROXY,
   SYS-SON), puis la boucle de tests.
3. Le reste du catalogue par lots, avec un commit par panne.
4. Données des 5 clients.
5. Console et `GUIDE-PARTICULIERS.md` (une fiche par panne).
6. Optionnel, avec accord : module ITFlow **séparé** pour créer ces clients.
