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
