# Démarrage — à faire par l'enseignant

Environ 45 minutes, une seule fois. Chaque étape a sa vérification : ne passe à la
suivante que si elle réussit.

## 1. Droits Hyper-V sans administrateur

Dans un PowerShell **administrateur** :

```powershell
Add-LocalGroupMember -SID S-1-5-32-578 -Member $env:USERNAME
```

Déconnecte-toi, reconnecte-toi, puis dans un terminal **normal** :

```powershell
Get-VM          # doit lister tes VM sans erreur
```

## 2. Protéger la VM ITFlow

```powershell
Set-VM -Name '<nom de ta VM ITFlow>' -Notes '[NE-PAS-TOUCHER] Serveur ITFlow de la classe'
Checkpoint-VM -Name '<nom de ta VM ITFlow>' -SnapshotName 'Avant-API-AB'
```

`Invoke-LabVM.ps1` refuse toute VM marquée `[NE-PAS-TOUCHER]`, même si son nom
finissait par `-T`.

## 3. Préparer les VM de test

Pour chaque VM (`AB-SRV-01-T`, `AB-PC-03-T` au minimum; les autres plus tard) :

1. Windows 11 Pro installé, nom d'ordinateur **sans** le `-T` (ex. `AB-PC-03`) :
   les scripts vérifient le nom du poste.
2. Compte `ab-tech` administrateur local, même mot de passe partout.
3. Carte réseau sur un commutateur **interne** (ex. `AB-Lab-Interne`), pour que
   SRV-01 et PC-03 se voient comme dans la vraie salle.
4. Pas de mises à jour de fonctionnalités en cours, session fermée.
5. Sur l'hôte :

```powershell
Set-VM -Name AB-PC-03-T -CheckpointType Standard -AutomaticCheckpointsEnabled $false
Stop-VM -Name AB-PC-03-T          # ou laisse-la démarrée : le point inclura la mémoire
Checkpoint-VM -Name AB-PC-03-T -SnapshotName Propre
```

Le point `Propre` doit être pris **avant** tout script AB, avec seulement le
compte `ab-tech` sur la VM : les comptes des employés sont créés par les scripts.

## 4. Enregistrer les secrets

Depuis la racine du dépôt :

```powershell
.\tools\Setup-LabSecrets.ps1 -Partie VM
.\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Ping      # doit afficher AB-PC-03
.\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Reset     # doit revenir « prête »
```

## 5. ITFlow

Depuis la v26.08, une clé API appartient à un utilisateur et hérite de son rôle
et de ses accès aux clients. On crée un utilisateur dédié, **Claude**, qui peut
créer des clients mais ne voit jamais les clients protégés (les équipes GDF, qui
servent de traces d'évaluation).

1. Crée un **rôle** « Claude » : lecture et écriture sur Clients, Contacts, Lieux,
   Actifs et Requêtes. Aucun accès à la facturation, aux soumissions, aux
   identifiants (Credentials) ni à l'administration.
2. Crée l'utilisateur **Claude** avec ce rôle, un courriel fictif
   (ex. `claude@cfrn-lab.example`) et un long mot de passe aléatoire que tu ne
   notes nulle part : personne ne s'y connecte.
3. Dans ses accès aux clients, utilise des **règles de refus** (nouveauté v26.08)
   pour chaque client GDF et tout autre client sensible, plutôt qu'une liste
   d'autorisations : avec une liste d'autorisations, il ne verrait pas les
   clients qu'il crée lui-même.
4. Crée sa clé API, avec une expiration.
5. Évite la journalisation des clés dans Apache : voir la page *api_apache-logging*
   de la documentation d'ITFlow.
6. Enregistre la clé et les clients protégés (motifs, ex. `Garage du Fleuve*`) :

```powershell
.\tools\Setup-LabSecrets.ps1 -Partie ITFlow
Import-Module .\tools\ITFlow-AB.psm1 -Force
Connect-ITFlowAB                          # « Aucun client protégé visible »
```

7. **Test de création** (le point clé à vérifier) :

```powershell
New-ITFlowABClient -Equipe A -WhatIf
New-ITFlowABClient -Equipe A
Connect-ITFlowAB -Equipe A                # doit trouver le client qu'il vient de créer
```

Si la création est refusée, le rôle ou les accès aux clients de l'utilisateur ne
le permettent pas : crée alors les 5 clients à la main, le reste fonctionne pareil.
Si `Connect-ITFlowAB -Equipe A` ne trouve pas le client créé, c'est qu'une liste
d'autorisations est active : passe aux règles de refus.

Si le module voit un client protégé, il refuse de fonctionner : c'est voulu.
Toutes les actions apparaîtront au nom de « Claude » dans les journaux d'audit.

Si ITFlow est sur le *Default Switch*, son adresse peut changer au redémarrage :
donne-lui une IP fixe ou relance `-Partie ITFlow` au besoin.

## 6. Dépôt Git privé

```powershell
git init -b main
git add .
git commit -m "Squelette cfrn-5385-labs : module commun, garde-fous VM et ITFlow, spec AB"
gh repo create slevesquephoto-ops/cfrn-5385-labs --private --source . --push
```

## 7. Lancer Claude Code

```powershell
claude
```

1. Accepte la confiance du dossier.
2. `/status` : la ligne *Setting sources* doit inclure les réglages du projet.
3. `/permissions` : vérifie que les règles `deny` sont bien là.
4. Colle la première demande ci-dessous.

La première fois qu'il lance `.\tests\Invoke-LabVM.ps1`, réponds
« Yes, and don't ask again » : la règle exacte sera enregistrée pour toi seul.

### Première demande à coller

```text
Lis CLAUDE.md et AB/SPEC.md au complet, puis common/Lab-Common.psm1 et tests/Invoke-LabVM.ps1.

Avant d'écrire du code :
1. Vérifie que tu peux joindre les VM : Invoke-LabVM.ps1 -Action Status puis -Action Ping sur AB-SRV-01-T et AB-PC-03-T.
2. Fais-moi un plan pour AB/SRV-01 (Setup, Panne -Variante A..E, Retrait, Verifier) :
   liste des fonctions, ordre des opérations, ce que la Panne sauvegarde dans l'état,
   et comment le Verifier détecte chaque variante.
3. Liste tes questions sur la spec.

N'écris aucun script avant que j'approuve le plan.
```

Ensuite, une machine à la fois : SRV-01, PC-03, PC-02, PC-01, PC-04, puis les
données ITFlow (avec `-WhatIf` d'abord).

## À savoir

- Les règles de `.claude/settings.json` filtrent le texte des commandes; ce n'est
  pas une frontière de sécurité absolue. Les vrais garde-fous sont dans
  `Invoke-LabVM.ps1` (nom `-T`, notes `[NE-PAS-TOUCHER]`) et dans les clés ITFlow
  limitées à un client.
- La mise à jour ITFlow v26.08 supprime toutes les clés API : à recréer ensuite.
- Sur les vrais M700 : `git clone` du dépôt (ou clé USB), puis
  `powershell -ExecutionPolicy Bypass -File .\AB\PC-03\Setup-PC-03.ps1`.
