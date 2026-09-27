# cfrn-5385-labs — Consignes pour Claude Code

Tu travailles pour un enseignant du DEP 5385 Soutien informatique (CFRN, Rimouski).
Ce dépôt contient des scripts PowerShell qui préparent des mises en situation
sur des postes Windows 11 Pro : création des profils clients, installation de
pannes, retrait des pannes et vérification. Les élèves ne voient jamais ce dépôt.

Communique en français. Explique brièvement tes choix; l'enseignant relit tout.

## Où est l'information

| Fichier | Contenu |
| --- | --- |
| `AB/SPEC.md` | Spécification d'Architecture Boréale. **Source de vérité** : lis-la avant de coder. |
| `common/Lab-Common.psm1` | Fonctions communes. Utilise-les au lieu de recopier du code. |
| `tests/Invoke-LabVM.ps1` | **Seul** moyen de toucher aux VM de test. |
| `tools/ITFlow-AB.psm1` | **Seul** moyen de parler à ITFlow. |
| `DEMARRAGE.md` | Mise en place faite par l'enseignant (tu n'as rien à y faire). |

Ne change jamais une décision de `AB/SPEC.md` (noms, comptes, matrice des droits,
pannes, variantes) sans le demander. Si la spec est ambiguë, pose la question.

## Règles de code (non négociables)

1. **Windows PowerShell 5.1** est la cible (postes élèves). Pas de `??`, pas
   d'opérateur ternaire, pas de `&&`/`||`, pas de `ForEach-Object -Parallel`.
   Commence chaque script par `#requires -version 5.1` et `#requires -RunAsAdministrator`
   (sauf les scripts qui s'exécutent dans la session d'un utilisateur).
2. **Encodage UTF-8 avec BOM, fins de ligne CRLF** pour `.ps1`, `.psm1`, `.psd1`.
   Sans BOM, PowerShell 5.1 lit les accents de travers. `.gitattributes` gère le CRLF;
   le BOM, c'est à toi de le garder.
3. **Registre** : n'utilise jamais `New-Item -Force` sur une clé qui peut exister
   (ça la vide). Passe par `Set-LabRegistryValue`.
4. **Idempotence** : relancer un script ne doit rien doubler ni casser.
5. **Retrait exact** : un script Panne sauvegarde l'état d'origine de tout ce qu'il
   modifie (`Save-LabState`, `Get-LabRegistrySnapshot`) avant de le modifier. Le
   Retrait restaure depuis cet état, il ne devine pas.
6. **Discrétion** : aucun indice visible par l'élève (pas de fichier « panne » sur le
   bureau, pas de tâche nommée « Panne », pas de commentaire révélateur dans un
   fichier déposé sur le poste). Les journaux et l'état vont dans le dossier
   caché retourné par `Get-LabDataPath`.
7. **Messages** : `Write-LabStep`, `Write-LabOK`, `Write-LabWarn` (alias `Step`,
   `OK`, `Warn`). Tout script démarre `Start-LabLog` et finit `Stop-LabLog`.
8. Les mots de passe LAB en clair dans les scripts sont acceptés : ils sont fictifs
   et documentés dans le README de chaque poste, comme dans GDF.
9. Passe `Invoke-ScriptAnalyzer` sur tout fichier modifié; corrige les erreurs
   et les avertissements pertinents.

## Contrat des scripts par machine

Dans `AB/<MACHINE>/` (ex. `AB/PC-03/`) :

| Script | Rôle | Paramètres |
| --- | --- | --- |
| `Setup-<MACHINE>.ps1` | Profil client, données, lecteurs, interface | `-Force` |
| `Panne-<MACHINE>.ps1` | Installe la ou les pannes | `-Variante A..E` (obligatoire si la panne varie) |
| `Retrait-<MACHINE>.ps1` | Remet l'état exact d'après le Setup | aucun |
| `Verifier-<MACHINE>.ps1` | Contrôle l'état | `-Attendu Propre\|Panne` |

`Verifier-*` écrit une ligne JSON sur la sortie
(`{"machine":"PC-03","attendu":"Propre","ok":true,"controles":[...]}`) et
termine avec le code 0 si l'état observé correspond à `-Attendu`, 1 sinon.

Les actions qui doivent se faire dans la session d'un utilisateur (identifiants
`cmdkey`, lecteurs persistants, fond d'écran) passent par `Register-LabRunOnce`.

Attention : contrairement à GDF, les scripts AB **créent** les comptes. Un compte
neuf n'a pas encore de profil (`NTUSER.DAT`), donc `Mount-LabUserHive` échoue.
Propose une solution dans ton plan (ex. créer le profil par l'API Windows
`CreateProfile`, ou différer le travail HKCU au premier logon) et teste-la en VM.

## Tester : uniquement par tests/Invoke-LabVM.ps1

- VM de test : noms qui finissent par `-T` (`AB-SRV-01-T`, `AB-PC-03-T`, ...).
  Le script refuse tout autre nom. **Ne contourne jamais ce garde-fou** et
  n'utilise pas directement `Invoke-Command -VMName`, `Restore-VMCheckpoint`,
  `Stop-VM`, etc.
- Le point de contrôle de départ s'appelle `Propre`. Ne le supprime ni ne le remplace.
- Une autre VM tourne sur cet hôte (ITFlow). Tu ne dois jamais l'arrêter,
  la restaurer ni la modifier.
- Boucle attendue pour chaque machine et chaque variante :
  `Reset` → Setup → `Verifier -Attendu Propre` (0) → Panne → `Verifier -Attendu Panne` (0)
  → Retrait → `Verifier -Attendu Propre` (0).
  Écris cette boucle dans `tests/Test-AB.ps1` et présente les résultats en tableau.
- Les pannes physiques (R2) et l'ajout de RAM (R4) ne se testent pas en VM.

## ITFlow : uniquement par tools/ITFlow-AB.psm1

- La clé appartient à l'utilisateur ITFlow « Claude ». Il voit tous les clients
  sauf les clients protégés (ex. GDF) ; le module refuse de fonctionner s'il en
  voit un.
- `Connect-ITFlowAB` vérifie la clé; `New-ITFlowABClient -Equipe X` crée le client
  « Architecture Boréale — Équipe X »; `Connect-ITFlowAB -Equipe X` limite ensuite
  toutes les lectures et créations à ce client. Travaille équipe par équipe.
- Le module lit et crée seulement (clients AB, lieux, contacts, actifs, requêtes).
  Pas de suppression, pas d'archivage, pas de soumission ni de facture : ce sont
  les élèves qui les font.
- Lance d'abord avec `-WhatIf`, montre ce qui serait créé, puis attends mon accord.
- N'appelle jamais l'API avec `Invoke-RestMethod` directement, n'affiche jamais une
  clé et ne lis jamais le contenu de `~/.lab/`.
- Pour gérer ITFlow au-delà d'AB, ne modifie pas ce module : propose un module
  séparé et attends mon accord.

## Façon de travailler

- Une machine à la fois, dans cet ordre : SRV-01, PC-03, PC-02, PC-01, PC-04.
- Petits commits en français (`AB PC-03 : panne R1 couche 1 (hosts)`).
- Après chaque machine : résumé de ce qui a été fait, tableau des tests,
  et liste de ce que l'enseignant doit vérifier sur le vrai matériel.
- En cas de doute sur un comportement Windows (SMB, ACL, cmdkey, 24H2),
  écris un petit test dans la VM plutôt que de supposer.
