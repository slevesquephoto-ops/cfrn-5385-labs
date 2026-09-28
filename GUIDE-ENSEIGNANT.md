# Architecture Boréale — Guide de l'enseignant

Ce guide couvre le **vrai matériel** (4 ThinkCentre M700 + 1 HP ProDesk comme serveur).
Les élèves ne voient jamais ce dépôt. Pour les tests en VM, voir `DEMARRAGE.md` et
`tests/`. Les notes de correction requête par requête sont dans `AB/NOTES-CORRECTION.md`.

## Les 5 machines

| Machine | Poste | Employé (compte) | IP | Requêtes |
| --- | --- | --- | --- | --- |
| AB-SRV-01 | HP ProDesk (25H2) | ab-tech (admin) | 192.168.50.10 (fixe) | R1 (serveur), R6-B |
| AB-PC-01 | M700 (24H2) | Nathalie Côté (ncote) | .21 | R5, R6 |
| AB-PC-02 | M700 (24H2) | Louis-Philippe Gauthier (lpgauthier) | .22 | R3, R4 |
| AB-PC-03 | M700 (24H2) | Émilie Fortin (efortin) | .23 | R1 (poste) |
| AB-PC-04 | M700 (24H2) | Jérémie Bouchard (jbouchard) | .24 | R2 (physique) |

Mots de passe LAB : dans `AB/AB-Config.psd1` et les `README-Installation.txt`. La lettre
de variante (A à E) est **la même pour toutes les requêtes d'une équipe**.

Tous les scripts se lancent **sur le poste concerné**, dans un **PowerShell administrateur**,
l'employé **non connecté** (les Setup recréent le profil) :

```powershell
powershell -ExecutionPolicy Bypass -File .\AB\<MACHINE>\<Script>-<MACHINE>.ps1
```

---

## 1. Préparation initiale des postes (une seule fois)

### a) Télécharger les installeurs (sur un poste avec Internet)

```powershell
.\tools\Get-ABInstallers.ps1        # remplit tools\installeurs (≈ 2 Go)
```

Déposer `AB-Config.psd1` : l'installeur complet de **DWG TrueView** est désactivé
(`Actif = $false`) — les plans s'ouvrent dans LibreCAD. Le laisser désactivé sauf si
vous fournissez son installeur hors ligne dans `tools\installeurs\DWGTrueView2027\`.

### b) Copier le dépôt et les installeurs sur chaque poste

Clé USB ou `git clone`, dans un dossier hors des profils (ex. `C:\Lab-CFRN`). Inclure
`tools\installeurs`.

### c) Sur chaque poste : logiciels et verrou de version Windows

```powershell
# Serveur (aucun logiciel, seulement le verrou 25H2) :
.\tools\Set-ABPoste.ps1 -Poste SRV-01

# Chaque poste élève (logiciels depuis la clé, verrou 24H2) :
.\tools\Set-ABPoste.ps1 -Poste PC-01 -Methode Local -SourceLocale C:\Lab-CFRN\tools\installeurs
#   … PC-02, PC-03, PC-04 de même.
```

Vérifier la fin : « Tous les logiciels de AB-<poste> sont présents. »

### d) Sur chaque machine : créer comptes, profils, données, partages

Dans l'ordre **SRV-01, PC-03, PC-02, PC-01, PC-04** :

```powershell
.\AB\SRV-01\Setup-SRV-01.ps1        # comptes, groupes, partages, données, IP fixe, Logiciels$
.\AB\PC-03\Setup-PC-03.ps1          # profil efortin
.\AB\PC-02\Setup-PC-02.ps1          # profil lpgauthier (+ données R3)
.\AB\PC-01\Setup-PC-01.ps1          # profil ncote (+ police, macros)
.\AB\PC-04\Setup-PC-04.ps1          # profil jbouchard
```

Chaque Setup finit par sa propre vérification (ligne JSON, `"ok":true`).

### e) ITFlow

Voir `DEMARRAGE.md` (utilisateur « Claude », clé API) et `tools/ITFlow-AB.psm1`. Les
requêtes R1, R3, R4, R5 et R6 sont pré-créées par équipe (textes dans
`AB/ITFlow-Requetes.psd1`) ; **R2 n'est pas créée** (les élèves la créent à partir de
l'appel de Jérémie).

---

## 2. Installer les pannes pour la première équipe

Sur chaque machine, avec `-Variante` = la lettre de l'équipe (ex. `A`) :

```powershell
.\AB\SRV-01\Panne-SRV-01.ps1 -Variante A     # R1 couches 2-3, + R6-B si variante B
.\AB\PC-03\Panne-PC-03.ps1  -Variante A      # R1 couches 1-2
.\AB\PC-02\Panne-PC-02.ps1  -Variante A      # R4 (lenteur logicielle)
.\AB\PC-01\Panne-PC-01.ps1  -Variante A      # R5 + R6 selon la variante
```

Puis **R2 sur PC-04, à la main** (section 4) et, pour R4, préparer la couche matérielle
(section 5).

Contrôle : sur chaque machine, `Verifier-<MACHINE>.ps1 -Attendu Panne -Variante A` doit
donner `"ok":true`.

---

## 3. Rotation entre deux équipes (≈ 2 à 3 min de scripts)

La règle : **Retrait, puis Setup, puis Panne** avec la variante de l'équipe suivante.
Ordre des machines : SRV-01, PC-03, PC-02, PC-01, PC-04. Employés non connectés.

Sur chaque machine (exemple : équipe suivante = variante **B**) :

```powershell
.\AB\SRV-01\Retrait-SRV-01.ps1 ; .\AB\SRV-01\Setup-SRV-01.ps1 ; .\AB\SRV-01\Panne-SRV-01.ps1 -Variante B
.\AB\PC-03\Retrait-PC-03.ps1  ; .\AB\PC-03\Setup-PC-03.ps1  ; .\AB\PC-03\Panne-PC-03.ps1  -Variante B
.\AB\PC-02\Retrait-PC-02.ps1  ; .\AB\PC-02\Setup-PC-02.ps1  ; .\AB\PC-02\Panne-PC-02.ps1  -Variante B
.\AB\PC-01\Retrait-PC-01.ps1  ; .\AB\PC-01\Setup-PC-01.ps1  ; .\AB\PC-01\Panne-PC-01.ps1  -Variante B
```

Temps mesurés en VM (scripts seuls, hors ouverture de session) : SRV-01 ≈ 20 s (IP déjà
fixe), PC-03 ≈ 40 s, PC-02 ≈ 25 s, PC-01 ≈ 15 s. En classe, les machines tournent en
parallèle : compter **moins de 3 minutes**, plus le temps d'ouvrir les sessions.

**PC-04** : pas de script de panne (R2 est physique). Entre deux équipes : remettre le
matériel en état, relancer `Setup-PC-04.ps1` seulement si le profil a été touché, puis
préparer R2 de la nouvelle variante (section 4).

**PC-02, couche matérielle de R4** : si l'équipe précédente a ajouté une barrette de RAM,
la **retirer** pour remettre le poste à 8 Go (section 5) avant l'équipe suivante.

Après la rotation, sur chaque machine :
`Verifier-<MACHINE>.ps1 -Attendu Panne -Variante B` → `"ok":true`.

---

## 4. Pannes physiques R2 (AB-PC-04, à préparer à la main)

Poste **hors tension et débranché** avant toute manipulation. Une seule panne par
équipe, selon la variante.

| Variante | Manipulation | Symptôme attendu | Remise en état |
| --- | --- | --- | --- |
| A | Débrancher le **câble de données SATA** du disque | « Aucun périphérique amorçable » | Rebrancher le câble de données |
| B | Sortir une **barrette de RAM à moitié** de son support | Bips au démarrage, aucun affichage | Réenclencher la barrette |
| C | Débrancher le **câble d'alimentation SATA** du disque | « Aucun périphérique amorçable » | Rebrancher l'alimentation |
| D | Dans l'UEFI, **retirer le disque de l'ordre de démarrage** (le mettre après le réseau) | Démarre sur le réseau (PXE) ou reste dans l'UEFI | Remettre le disque en tête (voir ci-dessous) |
| E | Mettre l'écran sur la **mauvaise entrée**, brancher un **câble VGA défectueux** et régler un **affichage nocturne** | Écran noir alors que le poste fonctionne | Bonne entrée, bon câble, désactiver l'affichage nocturne |

- Variante D : après remise en état, `Verifier-PC-04.ps1 -Attendu Propre` doit indiquer
  `ordre-demarrage` = « Windows Boot Manager » en tête. Si le contrôle est marqué
  « CONTRÔLE MANUEL », vérifier l'ordre dans l'UEFI (F1/F12 au démarrage sur M700).
- Variante E : aucune trace logicielle ; c'est un diagnostic matériel (câble, entrée,
  paramètres d'affichage).

---

## 5. Couche matérielle de R4 (RAM) — AB-PC-02

R4 a deux couches : la lenteur logicielle (installée par `Panne-PC-02.ps1`) et le manque
de mémoire. Les élèves, dans le cycle 373, **commandent et ajoutent une barrette DDR4**
pour passer de 8 à 16 Go.

- Le `Verifier-PC-02.ps1` **rapporte** la RAM installée (contrôle `ram`) sans jamais
  échouer là-dessus : la quantité varie selon que la barrette a été ajoutée ou non.
- **Entre deux équipes** : retirer la barrette ajoutée pour revenir à 8 Go, sinon
  l'équipe suivante ne verra pas le manque de mémoire. Poste hors tension et débranché.

---

## Liste de contrôle — rotation d'équipe (à imprimer)

```
Équipe suivante : ____    Variante : ____    Date/heure : ____________

Avant (matériel, postes hors tension) :
  [ ] PC-02 : barrette de RAM ajoutée retirée (retour à 8 Go)
  [ ] PC-04 : R2 précédente remise en état (câbles, RAM, UEFI, écran)

Scripts (PowerShell admin sur chaque poste, employé non connecté) :
  [ ] SRV-01 : Retrait → Setup → Panne -Variante ____
  [ ] PC-03  : Retrait → Setup → Panne -Variante ____
  [ ] PC-02  : Retrait → Setup → Panne -Variante ____
  [ ] PC-01  : Retrait → Setup → Panne -Variante ____
  [ ] PC-04  : Setup si nécessaire

Pannes physiques :
  [ ] PC-04 : R2 variante ____ préparée (voir section 4)

Vérification (chaque machine : Verifier -Attendu Panne -Variante ____ → "ok":true) :
  [ ] SRV-01   [ ] PC-03   [ ] PC-02   [ ] PC-01   [ ] PC-04

ITFlow :
  [ ] Requêtes R1, R3, R4, R5, R6 présentes pour l'équipe (R2 créée par les élèves)

Prêt pour l'équipe. Remettre cette feuille dans le cartable.
```
