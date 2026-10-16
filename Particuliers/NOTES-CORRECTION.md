# Pannes spontanées (particuliers) : notes de correction (enseignant)

Ce fichier accompagne `Particuliers/SPEC.md`. Il garde la trace de ce qui a été validé
en VM et des points d'attention à la correction. Les élèves ne voient jamais ce dépôt.

## Journal de validation en VM

Boucle par panne (`tests/Test-Particuliers.ps1`) : installation → Verifier (panne) →
relance → retrait → **empreinte identique (retrait exact)** → Verifier (propre), puis lot
combiné et nettoyage du client. Rapports détaillés dans `tests/logs/` (non suivis par git).

| Pannes | PART-W10-T | PART-W11-T | Rapport |
| --- | --- | --- | --- |
| ACC-SOURIS, RES-PROXY, SYS-SON, RES-DNS, RES-HOSTS, RES-CARTE, RES-IP, RES-PAREFEU | OK | OK | 2026-10-13 |
| SEC-EICAR-DEF, SEC-EICAR-TIERS | OK | OK | 2026-10-13 |
| STRAT-BUREAU, STRAT-PANNEAU, STRAT-ARRET, STRAT-CMD | OK | OK | 2026-10-14 |
| SYS-IMPRIM, SYS-SANSECHEC, SYS-HEURE, SYS-DISQUE, SYS-DEMARRAGE | à tester | à tester | — |
| SYS-USB, SYS-RAM, SYS-REDEMARRAGE, SEC-BOUCLE, STRAT-RUN, STRAT-TASKMGR | à tester | à tester | — |
| ACC-CLAVIER, ACC-FILTRES | à tester | à tester | — |
| CPT-MDP, CPT-ADMIN, FIC-CACHES, FIC-REDIR | à tester | à tester | — |
| NAV-PIRATE, PUP-FAUX, SEC-EXCL | à tester | à tester | — |
| RES-DUPLEX | s.o. (vrai matériel) | s.o. (vrai matériel) | — |
| CPT-TEMP (à donner SEULE) | à tester | à tester | — |

## Points d'attention

- **STRAT-\*** (restrictions par stratégie) : la correction ne passe **pas** par un simple
  réglage. STRAT-PANNEAU bloque aussi l'application Paramètres; STRAT-BUREAU grise « Afficher
  les icônes du bureau ». L'élève doit passer par `gpedit.msc` ou le registre. Le changement
  prend effet après fermeture puis réouverture de session.
- **SEC-EICAR-TIERS** : l'exclusion Defender s'ajoute même avec la protection contre les
  falsifications active (constat W10 et W11, commit `eed298a`). Aucune préparation manuelle.
- Rappel de calibrage (voir SPEC) : viser une difficulté 3+. SYS-SON coupe le *service*
  audio — le panneau Son ne suffit pas, il faut `services.msc`.

## Lot système (à tester en VM)

- **SYS-DISQUE** : remplit le disque jusqu'à ~1 Go libre (`fsutil`, allocation instantanée).
  **À tester seule** (`-Pannes SYS-DISQUE`) : dans l'étape « pile » du test, l'installation
  simultanée des autres pannes pendant que le disque est quasi plein pourrait échouer.
  Fichier caché dans `AppData\Local\Temp\MediaCache` : l'élève doit afficher les éléments
  cachés **et** protégés du système.
- **SYS-HEURE** / **SYS-SANSECHEC** : en VM on ne contrôle que la *configuration* (le service
  d'intégration Hyper-V recorrige l'horloge; on ne redémarre pas en mode sans échec).
  SYS-HEURE recule la date de 3 jours sur matériel réel; PowerShell Direct passe par VMBus,
  donc l'écart d'horloge ne coupe pas la session de test.
- **SYS-SANSECHEC** désactive son, impression et réseau selon le mode : déclarée incompatible
  avec SYS-SON, SYS-IMPRIM et toutes les pannes réseau.
- **SYS-DEMARRAGE** : portée Machine (la clé Run HLKM et la tâche `MediaLibraryIndexer` sont
  communes au poste). Charges inoffensives (`Start-Sleep`). Trois emplacements à trouver :
  Run profil (HKCU), Run machine (HKLM), tâche planifiée — Autoruns les montre d'un coup.

## Lot « idées enseignant » (à tester en VM, sauf RES-DUPLEX)

- **Pannes punitives (SEC-BOUCLE, SYS-REDEMARRAGE)** : déclenchées à l'ouverture de session
  **du client seulement** (clé Run du profil / tâche `AtLogOn -User <client>`). Conséquence
  voulue : la session du client devient inutilisable, et l'élève doit réparer **depuis un autre
  compte ou Windows RE**. Un autre compte admin reste toujours propre (lesson recoverable).
  Comme le test automatisé passe par PowerShell Direct (aucun logon interactif), ces pannes
  **ne se déclenchent pas** pendant `Test-Particuliers` : le test ne vérifie que présence/retrait.
  Le vrai comportement punitif se teste à la main en ouvrant une session du client.
  - SYS-REDEMARRAGE : `shutdown /r /t 30`; le retrait fait aussi `shutdown /a`.
  - SEC-BOUCLE : lance `notepad.exe` en boucle (la calculatrice moderne est une app UWP
    **mono-instance** et ne se multiplierait pas). Changer `$appli`/`$intervalle` dans le script
    pour ajuster l'agressivité. Le retrait tue la boucle et les fenêtres ouvertes.
- **SYS-RAM** : `truncatememory` (bcdedit), test de config sans redémarrer. Plancher **3072 Mo** :
  en dessous, Windows 11 peut refuser de démarrer (et un boot raté en VM couperait PowerShell Direct).
- **SYS-USB** : `USBSTOR\Start = 4`. N'affecte pas les clés déjà énumérées par une session en cours;
  effet net au rebranchement. Clavier/souris HID intacts.
- **STRAT-RUN / STRAT-TASKMGR** : mêmes patrons que les STRAT déjà validées.
- **RES-DUPLEX** : **vrai matériel seulement**. La carte virtuelle Hyper-V n'expose pas la propriété
  `*SpeedDuplex` : la panne refuse alors proprement (ne pas l'inclure dans un run VM). Sur le poste,
  vérifier les libellés exacts des valeurs (« 10 Mbps Half Duplex », « Auto Negotiation ») : ils
  varient selon le pilote.

## Lot « plan d'origine » (à tester en VM)

- **ACC-CLAVIER** : disposition « États-Unis » placée en tête de `HKCU\Keyboard Layout\Preload`
  (entrée « 1 »). Effet réel après réouverture de session. Le test automatisé vérifie l'état du
  registre; le vrai « é → / » se confirme à la main sur matériel.
- **ACC-FILTRES** : touches filtres actives (`Keyboard Response\Flags`, bit 0).
- **CPT-MDP** : mot de passe du client remplacé; le retrait remet le mot de passe fictif documenté.
  Le test vérifie la restauration par `LogonUser` (le mot de passe documenté rouvre la session).
  Réparation depuis un AUTRE compte administrateur.
- **CPT-ADMIN** : client retiré des Administrateurs (clients admin seulement). Réparation depuis un
  autre compte admin.
- **FIC-CACHES** : dossiers Documents/Images/Bureau/Téléchargements marqués « caché + système ».
  L'élève doit afficher les éléments cachés **et** protégés.
- **FIC-REDIR** : Documents redirigé vers `D:\Documents` (User Shell Folders + Shell Folders, valeur
  `Personal`).
- **NAV-PIRATE** : stratégies Edge (HKLM\SOFTWARE\Policies\Microsoft\Edge). Page d'accueil et moteur
  détournés vers une page LOCALE inoffensive (`%ProgramData%\RechercheExpress`). Bandeau « Géré par
  votre organisation ». Vérifier `edge://policy`.
- **PUP-FAUX** : faux « OptimiseurPC Pro » à 3 endroits (Applications/Uninstall, Run du profil, tâche
  `OptimiseurPCProAlerte` au logon du client qui ouvre une page d'alerte locale `%ProgramData%\OptimiseurPCPro`).
  La tâche est déclenchée par le logon du client : elle ne s'ouvre pas sous PowerShell Direct.
- **SEC-EXCL** : exclusion Defender sur `C:\` (comme SEC-EICAR-TIERS, exige la protection contre les
  falsifications désactivée). Déclarée incompatible avec SEC-EICAR-TIERS.

## CPT-TEMP (profil temporaire) — moteur ajusté

Mécanisme : renommer `HKLM\...\ProfileList\<SID>` en `<SID>.bak` force un profil temporaire au
prochain logon. Cela fait disparaître le profil de `Win32_UserProfile`, ce qui empêchait
`Mount-LabUserHive` (appelé par le moteur à chaque opération) de retrouver le profil au retrait.

**Décision (enseignant) : ajuster le moteur.** `Invoke-PartWithContext` tolère désormais une ruche
non montable : il la monte si possible, sinon fournit le contexte avec `Root = $null` et ne démonte
rien. Le chemin normal est inchangé (aucune régression attendue sur les autres pannes). CPT-TEMP
n'utilise pas HKCU : au retrait, le moteur fournit `Root = $null`, le bloc Retirer renomme `.bak`
à l'envers, et la panne se nettoie proprement.

Points d'attention pour le test :
- **À DONNER SEULE.** CPT-TEMP est déclarée incompatible avec les 17 pannes de portée Profil (une fois
  l'inscription renommée, le moteur ne peut plus monter la ruche pour une autre panne de profil).
  Dans `Test-Particuliers`, la tester avec `-Pannes CPT-TEMP` (ne pas l'inclure dans un lot « pile »).
- L'installation refuse si la **session du client est ouverte** (il faut la fermer d'abord).
- Le changement du moteur touche le chemin commun à toutes les pannes : **revalider en VM** au moins
  une panne de profil déjà OK (ex. ACC-SOURIS) en plus de CPT-TEMP, pour confirmer l'absence de
  régression.

## Idée en attente

- **ACC-ENVERS** (prank « tout à l'envers » : rotation 180° + souris inversée + capture en fond
  d'écran) : à faire; exige la session interactive du client (tâche au logon) et de l'affichage,
  donc vrai matériel seulement. Non commencée.
