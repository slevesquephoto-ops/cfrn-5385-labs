# cfrn-5385-labs

Outil d'automatisation des mises en situation de dépannage pour le **DEP 5385 Soutien
informatique** (Centre de formation Rimouski-Neigette). Il prépare des postes Windows avec
des clients fictifs crédibles et des pannes réalistes, que les élèves doivent diagnostiquer
et régler.

> ⚠️ **Avertissement.** Ces scripts modifient **volontairement** la configuration de Windows
> (réseau, comptes, stratégies, démarrage, sécurité) pour créer des pannes. À exécuter
> **uniquement** sur des postes de laboratoire ou des machines virtuelles, jamais sur un
> ordinateur personnel ou de production. Usage éducatif.

## Le problème réglé

Un groupe de 12 élèves doit pouvoir travailler en tout temps, chacun sur une panne à son
niveau. Il faut donc plusieurs ordinateurs préparés en même temps, chacun avec un profil
client complet et une panne différente. Fait à la main, cela demandait de 3 à 4 heures de
préparation par semaine, en dehors des heures de cours.

Avec cet outil, l'enseignant choisit un client et une ou plusieurs pannes dans un menu, et
le poste est prêt en quelques clics. Chaque panne se retire exactement, ce qui permet de
réutiliser les postes d'une équipe à l'autre.

## Deux mises en situation

### Clients particuliers : 37 pannes

Un client fictif « apporte » son ordinateur au comptoir. Le script crée son compte, un
profil complet et crédible (documents, photos, fond d'écran, favoris, logiciels), puis
installe la ou les pannes choisies. Fonctionne sur Windows 10 et 11.

| Catégorie | Pannes |
| --- | --- |
| Réseau | 7 (carte, IP, DNS, hosts, proxy, pare-feu, duplex) |
| Système | 9 (démarrage, disque, heure, imprimante, RAM, son, USB…) |
| Stratégies de groupe | 6 |
| Sécurité | 4 |
| Comptes | 3 |
| Accessibilité | 3 |
| Fichiers | 2 |
| Démarrage (BCD), navigateur, logiciel indésirable | 3 |

Les pannes sont autonomes et peuvent se superposer. Six clients fictifs aux profils variés
sont prévus (retraitée peu à l'aise, étudiant, travailleuse autonome, compte standard avec
un administrateur aidant, famille, « bidouilleur »), et la liste est ouverte.

### Architecture Boréale : cabinet d'architectes fictif

Mise en situation d'entreprise sur 5 machines (4 postes et 1 serveur de fichiers), pour
des équipes de 2 élèves en rotation. Elle couvre les compétences 462-507 (rétablissement et
optimisation de postes) et 462-373 (gestion de ressources).

- **Pannes en couches** : la deuxième n'apparaît qu'une fois la première réglée.
- **Variantes A à E** : chaque équipe reçoit une variante différente des mêmes requêtes.
- **Intégration ITFlow** : création automatique, par l'API, du client, des actifs et des
  requêtes de chaque équipe dans le logiciel de gestion de services TI utilisé en classe.

## Fonctionnement

Chaque machine ou panne suit le même contrat :

| Script | Rôle |
| --- | --- |
| `Setup` | Crée le profil client, les données, les lecteurs et l'interface |
| `Panne` | Sauvegarde l'état d'origine, puis installe la panne |
| `Retrait` | Restaure l'état exact sauvegardé (sans deviner) |
| `Verifier` | Contrôle l'état et produit un résultat JSON (`Propre` ou `Panne`) |

- **Consoles enseignant** (`Console-Particuliers.cmd`, `Console-AB.cmd`) : un menu qui
  reconnaît le poste et regroupe toutes les actions.
- **Idempotence** : relancer un script ne double ni ne casse rien.
- **Discrétion** : aucun indice visible par l'élève. Les journaux et l'état sont rangés
  dans un dossier réservé aux administrateurs.
- **Tests automatisés en VM Hyper-V** : boucle Setup → Vérifier → Panne → Vérifier →
  Retrait → Vérifier, avec des garde-fous (seules les VM de test sont acceptées, et les VM
  protégées sont refusées).
- **Secrets** : aucun dans le dépôt. Les identifiants des VM et la clé ITFlow sont chiffrés
  localement avec DPAPI. Les mots de passe des comptes clients sont fictifs.

## Développement assisté par IA

Projet développé en combinant deux IA : **ChatGPT** pour la direction et les discussions
techniques, **Claude Code** pour l'écriture du code. Mon rôle : définir les mises en
situation et les règles pédagogiques (spécifications dans `Particuliers/SPEC.md` et
`AB/SPEC.md`), imposer les règles de code (`CLAUDE.md`), réviser, et valider sur le vrai
matériel.

## Stack

Windows PowerShell 5.1 · Hyper-V (tests) · API REST ITFlow · PSScriptAnalyzer

## Structure

```
Particuliers/   Clients fictifs et 37 pannes
AB/             Architecture Boréale : un dossier par machine, spécification, notes
common/         Module de fonctions communes (registre, état, journaux, profils)
tools/          Données fictives, installeurs, module ITFlow, secrets (DPAPI)
tests/          Pilotage des VM de test et boucles de tests
```

Mise en route : `DEMARRAGE.md` (environnement de test) et `GUIDE-ENSEIGNANT.md` (vrai
matériel).
