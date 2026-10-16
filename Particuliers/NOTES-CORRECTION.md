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

## Points d'attention

- **STRAT-\*** (restrictions par stratégie) : la correction ne passe **pas** par un simple
  réglage. STRAT-PANNEAU bloque aussi l'application Paramètres; STRAT-BUREAU grise « Afficher
  les icônes du bureau ». L'élève doit passer par `gpedit.msc` ou le registre. Le changement
  prend effet après fermeture puis réouverture de session.
- **SEC-EICAR-TIERS** : l'exclusion Defender s'ajoute même avec la protection contre les
  falsifications active (constat W10 et W11, commit `eed298a`). Aucune préparation manuelle.
- Rappel de calibrage (voir SPEC) : viser une difficulté 3+. SYS-SON coupe le *service*
  audio — le panneau Son ne suffit pas, il faut `services.msc`.
