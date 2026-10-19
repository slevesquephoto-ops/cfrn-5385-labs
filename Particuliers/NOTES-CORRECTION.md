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
| SEC-EICAR-DEF, SEC-EICAR-TIERS | présence/retrait OK (2026-10-13) ; **réapparition réparée + validée VM 2026-10-19** | idem | voir note |
| STRAT-BUREAU, STRAT-PANNEAU, STRAT-ARRET, STRAT-CMD | OK | OK | 2026-10-14 |
| SYS-SANSECHEC, SYS-DISQUE, SYS-RAM | OK | OK | 2026-10-16 |
| SYS-REDEMARRAGE | installe OK ; **retrait corrigé** → à retester | à retester | 2026-10-16 |
| SYS-DEMARRAGE | **renforcée** (voir note) → à retester | à retester | 2026-10-16 |
| SYS-IMPRIM, SYS-HEURE, SYS-USB, SEC-BOUCLE, STRAT-RUN, STRAT-TASKMGR | à tester | à tester | — |
| ACC-CLAVIER, ACC-FILTRES | à tester | à tester | — |
| CPT-MDP, CPT-ADMIN, FIC-CACHES, FIC-REDIR | à tester | à tester | — |
| NAV-PIRATE, PUP-FAUX, SEC-EXCL | à tester | à tester | — |
| RES-DUPLEX | s.o. (vrai matériel) — refus propre en VM constaté 2026-10-16 | s.o. (vrai matériel) | — |
| CPT-TEMP (à donner SEULE) | à tester | à tester | — |

## Points d'attention

- **STRAT-\*** (restrictions par stratégie) : la correction ne passe **pas** par un simple
  réglage. STRAT-PANNEAU bloque aussi l'application Paramètres; STRAT-BUREAU grise « Afficher
  les icônes du bureau ». L'élève doit passer par `gpedit.msc` ou le registre. Le changement
  prend effet après fermeture puis réouverture de session.
- **SEC-EICAR-TIERS** : l'exclusion Defender s'ajoute même avec la protection contre les
  falsifications active (constat W10 et W11, commit `eed298a`). Aucune préparation manuelle.
- **SEC-EICAR-DEF/TIERS — réapparition réparée et VALIDÉE sur PART-W11-T le 2026-10-19.**
  Symptôme signalé : à l'installation, l'EICAR est détecté une fois, puis **plus jamais** (tâche
  pourtant visible dans le Planificateur), même après tout un week-end. Diagnostic mené sur la VM
  (`tests/Invoke-LabVM.ps1`), **deux bugs cumulés** :
  1. **Générateur malformé (cause principale).** `Install-PartEicarPersistence` construisait le script
     générateur avec `$gen = @('…' + $EicarDrop + '…', '…', '…', '…(' + $codes + '…')`. En PowerShell,
     **la virgule a une priorité plus haute que `+`** : les éléments voisins étaient happés dans une
     seule concaténation, `$gen` se réduisait à **un seul élément** avec tout collé par des espaces.
     Le fichier `sync-store.ps1` sortait sur UNE ligne → erreur de syntaxe (`Jeton inattendu « $d »`)
     → l'action de la tâche échouait (`LastTaskResult=1`) à chaque exécution, donc aucune réapparition.
     La seule alerte vue venait du dépôt direct de l'installateur (`[IO.File]::WriteAllBytes`, qui, lui,
     marche). **Correctif** : parenthèses autour des éléments concaténés + écriture par
     `[IO.File]::WriteAllText(($gen -join "\`r\`n"), ASCII)`.
  2. **Répétition sans durée.** La tâche avait `-RepetitionInterval 5 min` **sans** `-RepetitionDuration` :
     PS 5.1 l'enregistre mais « Prochaine exécution » reste vide et la répétition ne part pas. **Correctif** :
     `-RepetitionDuration (New-TimeSpan -Days 365)`.
  Après correctifs (constat VM) : `LastTaskResult=0`, l'EICAR est réécrit, Defender le détecte à chaque
  cycle (`Virus:DOS/EICAR_Test_File`), « Prochaine exécution » renseignée (toutes les 5 min).
  Pourquoi le test auto ne l'avait pas vu : `Test-Particuliers` ne contrôle que présence/retrait via
  PowerShell Direct, jamais l'exécution réelle dans le temps. **À confirmer à la main** côté enseignant :
  session du client ouverte, laisser tourner 5-6 min → alertes Defender en boucle.
- **SEC-EICAR — ciblage client + escalade (2026-10-19, validé PART-W11-T).** À la demande de
  l'enseignant :
  - **Cadence** : répétition portée à **1 minute** (`$script:EicarIntervalMinutes` dans le module,
    ajustable).
  - **Jamais sous ab-tech.** Le générateur (SYSTEM) ne dépose l'EICAR que si l'utilisateur de la
    session **console active** est le client (`Win32_ComputerSystem.UserName`). Sous ab-tech, écran de
    verrouillage ou session réseau → **no-op**. Le dépôt initial (`Write-PartEicarFile -Compte`) suit
    la même garde : installer depuis ab-tech ne déclenche aucune alerte. Constat VM : console =
    `PART-W11\ab-tech` → aucun dépôt. (On a retiré le déclencheur `-AtLogOn -User <client>` : il
    exigeait un compte résoluble à l'installation ; la garde dans l'action suffit au ciblage.)
  - **Escalade douce si l'élève traîne.** Un compteur discret (`index.dat` dans le dossier de dépôt)
    compte les cycles passés DANS la session du client ; après 5 cycles, le générateur dépose
    plusieurs copies (`update.bin`, `update1.bin`, … **plafonné à 4**) pour densifier les alertes.
    Tout reste dans le même dossier caché ; le retrait supprime le dossier **récursivement** (copies +
    compteur). Rien de nuisible : toujours le fichier de test EICAR standard (68 octets). Constat VM :
    cycles 1-5 = 1 copie, 6 = 2, 7 = 3 ; Defender détecte la rafale.
  - **Discrétion** : tâche et script générateur `Hidden`, noms anodins (`Optimisation du stockage`,
    `MediaCache`, `DeviceSync`). La tâche n'apparaît qu'en cochant « Afficher les tâches cachées ».
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
- **SYS-DEMARRAGE** (renforcée le 2026-10-16) : la première version (petits `Start-Sleep`) ne se
  faisait pas sentir (constat enseignant en VM). Désormais **quatre** emplacements à trouver, répartis
  entre outils différents pour que l'élève travaille > 2 min :
  - clé Run du **profil** (HKCU), **deux** valeurs (`MediaAgent` → `agent.vbs`, `UpdateNotifier`) ;
  - clé Run de la **machine** (HKLM, `CloudSyncHelper`) qui lance `%ProgramData%\MediaAgent\sync-agent.ps1`,
    une **charge CPU bornée (~75 s)** : la session reste utilisable mais nettement poussive au démarrage ;
  - le **dossier Démarrage** du profil (`...\Startup\SyncCheck.vbs`) — invisible dans le Planificateur ;
  - la tâche planifiée `MediaLibraryIndexer` au logon (attente 45 s, effet « indexation »).
  Le Gestionnaire des tâches > Démarrage montre les Run + le dossier Démarrage mais **pas** la tâche ;
  il faut aussi le Planificateur. Autoruns regroupe tout. Toutes les charges se terminent seules et le
  retrait supprime chaque valeur, fichier et dossier créés (retrait exact). Portée Machine pour HKLM +
  tâche ; les éléments HKCU et les fichiers du profil sont propres au client.
- **SYS-REDEMARRAGE** (retrait corrigé le 2026-10-16) : le retrait supprime d'abord la tâche, puis
  annule un éventuel redémarrage armé. L'appel `shutdown /a` passait par `& shutdown.exe /a 2>$null`,
  dont la redirection de stderr est promue en *NativeCommandError* par PowerShell 5.1 quand aucun arrêt
  n'est en cours → le moteur croyait le retrait échoué (« le système n'est pas en cours d'arrêt »). La
  tâche était pourtant déjà retirée. Corrigé en passant par `cmd /c 'shutdown /a >nul 2>nul'` (cmd avale
  le flux, PowerShell ne voit aucune erreur).

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

## Panne physique : pile CMOS morte (vrai matériel seulement)

Exercice **matériel**, non scriptable (comme les R2 d'AB / RES-DUPLEX). Insérer une pile CMOS morte
dans le poste.

- **Symptôme** : à chaque démarrage, l'heure et la date sont fausses (souvent une date très ancienne),
  et l'écart **revient après chaque extinction** malgré une remise à l'heure. Messages d'erreur de
  certificat sur les sites HTTPS.
- **Correction attendue** : remplacer la pile CMOS, régler l'heure dans le BIOS/UEFI, puis vérifier que
  « Régler l'heure automatiquement » est activé dans Windows.
- **Distinction clé à valoriser à la correction** : cette panne se répare en **changeant la pile**;
  SYS-HEURE (logicielle) se répare en **réactivant la synchro** et ne bougerait pas si on changeait la
  pile. L'élève doit reconnaître lequel des deux cas il a devant lui (l'heure qui *revient* fausse après
  extinction = pile; l'heure fausse mais *stable* avec synchro coupée = logiciel).

## Idée en attente

- **ACC-ENVERS** (prank « tout à l'envers » : rotation 180° + souris inversée + capture en fond
  d'écran) : à faire; exige la session interactive du client (tâche au logon) et de l'affichage,
  donc vrai matériel seulement. Non commencée.
