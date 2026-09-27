# Architecture Boréale — Mise en situation #2 (507 + 373)

Spécification de référence pour les scripts. Copie du document de conception
du 27 septembre 2026. En cas d'écart, le document de conception de l'enseignant
fait foi; demander avant de changer quoi que ce soit ici.

## Vue d'ensemble

- **Compétences** : 462-507 Rétablissement et optimisation de postes, et 462-373 Gestion de ressources (soumission, commande, facture) en parallèle.
- **Format** : 5 équipes de 2 (A à E), en rotation. Une demi-journée par équipe; minimum visé de 1 h pour une équipe rapide.
- **Matériel** : 4 Lenovo ThinkCentre M700 (DIMM DDR4, 8 Go, Windows 11 Pro, Intel 6e génération) et 1 HP ProDesk 400 G5 Mini comme serveur de fichiers.
- **Principe** : pannes en couches. La deuxième couche n'apparaît qu'une fois la première réglée.
- **Réinitialisation entre équipes** : Retrait, puis Setup, puis Panne avec la variante de l'équipe suivante.

## L'entreprise

Cabinet d'architectes fictif de 4 employés : bureaux à aire ouverte, serveur de fichiers dans une salle technique séparée. Tous les employés sont utilisateurs Windows **standard**; seul `ab-tech` est administrateur.

| Personne | Rôle | Poste | Compte | Données typiques |
| --- | --- | --- | --- | --- |
| Louis-Philippe Gauthier | Architecte associé, propriétaire | AB-PC-02 | lpgauthier | Projets, budget du cabinet, contrats clients, dossiers confidentiels |
| Émilie Fortin | Architecte de projets | AB-PC-03 | efortin | Plans, devis, correspondance de chantier |
| Jérémie Bouchard | Technicien en architecture (dessin) | AB-PC-04 | jbouchard | Plans, rendus, bibliothèques de symboles |
| Nathalie Côté | Adjointe administrative, réception | AB-PC-01 | ncote | Facturation clients, agenda, fournisseurs |
| (aucun) | Serveur de fichiers | AB-SRV-01 | ab-tech (admin) | Partages de l'entreprise |

Projets fictifs communs : `2026-014 Chalet du Lac-Boréal`, `2026-017 Clinique du Littoral`, `2026-021 Agrandissement Marina Pointe-Blanche`.

Courriels fictifs : `<compte>@architecture-boreale.example` (domaine réservé, jamais routable).

Mots de passe LAB : même modèle que GDF, documentés dans un `README-Installation.txt` par poste.

## Infrastructure

| Machine | Matériel | Adresse IP | Attribution |
| --- | --- | --- | --- |
| Routeur AB | À confirmer | 192.168.50.1 | Fixe |
| AB-SRV-01 | HP ProDesk 400 G5 Mini | 192.168.50.10 | Fixe (configurée sur le serveur par Setup) |
| AB-PC-01 à 04 | ThinkCentre M700 | 192.168.50.21 à .24 | Réservation DHCP (routeur) |

- **Groupe de travail, pas de domaine** : chaque employé a un compte local sur son poste *et* un compte identique (même nom, même mot de passe) sur AB-SRV-01.
- **Windows 11 sur Intel 6e génération** : non supporté par Microsoft. Aucune mise à jour de fonctionnalités pendant la mise en situation.
- **SMB (24H2)** : signature exigée, accès invité bloqué. Les partages fonctionnent avec des comptes authentifiés, jamais en invité. À vérifier avec `Get-SmbClientConfiguration` / `Get-SmbServerConfiguration`.
- **En VM de test** : le commutateur interne Hyper-V remplace le routeur. Le Setup du serveur ne doit pas casser l'accès PowerShell Direct.

## Comptes, groupes et partages (AB-SRV-01)

Les droits sont portés par **NTFS**. Chaque partage donne *Utilisateurs authentifiés : Contrôle total* au niveau du partage; le dossier restreint réellement.

**Groupes locaux du serveur**

| Groupe | Membres |
| --- | --- |
| AB-Direction | lpgauthier |
| AB-Conception | lpgauthier, efortin, jbouchard |
| AB-Administration | ncote |
| AB-Tous | les 4 employés |

**Matrice des partages (NTFS)**

| Partage | Dossier | Lecteur | AB-Direction | AB-Conception | AB-Administration | AB-Tous |
| --- | --- | --- | --- | --- | --- | --- |
| Projets | C:\AB\Projets | P: | Modification | Modification | Lecture | aucun |
| Administration | C:\AB\Administration | T: | Modification | aucun | Modification | aucun |
| Direction$ (caché) | C:\AB\Direction | aucun | Modification | aucun | aucun | aucun |
| Archives | C:\AB\Archives | R: | Modification | Lecture | Lecture | aucun |
| Commun | C:\AB\Commun | S: | (via AB-Tous) | (via AB-Tous) | (via AB-Tous) | Modification |
| Sauvegardes$ (caché) | C:\AB\Sauvegardes | aucun | aucun | aucun | aucun | aucun |

- **Héritage** coupé à la racine de chaque partage. Administrateurs et SYSTEM : Contrôle total partout.
- **Sauvegardes$** : accessible seulement avec `ab-tech`; destination de R3.
- **Lecteurs réseau** : mappés de façon persistante par le Setup de chaque poste, selon les groupes de la personne.
- **Données fictives** : sous-dossiers par projet avec plans PDF, devis, correspondance; dates réalistes via manifeste CSV (`;` comme séparateur, même format que GDF : `SourceRelative;TargetRelative;CreationTime;LastWriteTime;Criticality`).

## Requêtes et pannes

| Requête | Poste | Canal | Rapide | Normal |
| --- | --- | --- | --- | --- |
| R1 Accès refusé aux projets | AB-PC-03 + serveur | Courriel, requête ITFlow | 25 min | 60 min |
| R2 Ne démarre plus | AB-PC-04 | Appel (l'enseignant joue Jérémie) | 10 min | 30 min |
| R3 Sauvegarde avant congrès | AB-PC-02 | Courriel, requête ITFlow | 15 min | 30 min |
| R4 Lenteur, ajout de RAM | AB-PC-02 | Requête ITFlow + cycle 373 | 20 min | 50 min |
| R5 (optionnelle) Lecteur S: disparu | AB-PC-01 | Courriel | 5 min | 15 min |

R3 doit précéder R4 (sauvegarder avant d'ouvrir le boîtier).

### R1 : « Je n'ai plus accès aux plans de la marina » (Émilie)

Trois couches, chacune masquée par la précédente :

1. **Résolution de nom** (PC-03) : une entrée dans `C:\Windows\System32\drivers\etc\hosts` envoie AB-SRV-01 vers une mauvaise adresse, commentée « ancien serveur ». Ping par nom échoue, ping par IP fonctionne.
2. **Mot de passe désynchronisé** (SRV-01 + PC-03) : le mot de passe d'`efortin` est changé sur le serveur seulement, et l'ancien est mémorisé dans le Gestionnaire d'identification du poste (`cmdkey`, dans la session d'efortin). Accès refusé sans invite.
3. **Droits sur `P:\2026-021`** (SRV-01), selon la variante :

| Variante | Cause | Notion |
| --- | --- | --- |
| A | Refuser explicite pour efortin sur 2026-021 | Refuser l'emporte sur Autoriser |
| B | Héritage coupé sur 2026-021, AB-Conception absent de l'ACL | Héritage et ACL explicites |
| C | efortin retirée du groupe AB-Conception | Les droits passent par les groupes |
| D | AB-Conception réduit à Lecture sur Projets | Ouvrir sans pouvoir enregistrer |
| E | Permission de *partage* Projets réduite à Lecture (NTFS correct) | Le plus restrictif des deux l'emporte |

### R2 : « Mon ordinateur ne démarre plus ce matin » (Jérémie)

Panne **physique**, préparée à la main (aucun script de panne).

| Variante | Panne | Symptôme |
| --- | --- | --- |
| A | Câble de données SATA débranché | Aucun périphérique amorçable |
| B | Barrette de RAM à moitié sortie | Bips, aucun affichage |
| C | Câble d'alimentation SATA du disque débranché | Aucun périphérique amorçable |
| D | Disque retiré de l'ordre de démarrage UEFI | Démarre sur le réseau ou l'UEFI |
| E | Écran sur la mauvaise entrée, câble vidéo VGA défectueux et affichage nocturne | Écran noir, poste en fait fonctionnel |

### R3 : « Copiez mes fichiers importants avant qu'on touche à mon ordinateur » (Louis-Philippe)

- Destination : `\\AB-SRV-01\Sauvegardes$\lpgauthier\AAAA-MM-JJ`, avec `ab-tech`.
- Pièges prévus par le Setup de PC-02 : fichiers dans Bureau, Documents et Téléchargements, un dossier hors profil `C:\Soumissions-LP`, et les favoris Edge.
- Vérification : comparaison des hash du manifeste avec la destination.

### R4 : « Mon ordinateur est d'une lenteur insupportable » (Louis-Philippe)

- Couche logicielle (script) : éléments de démarrage inutiles (clés Run et une tâche planifiée) et un processus fictif qui retient de la mémoire.
- Couche matérielle : 8 Go insuffisants; ajout de RAM DIMM DDR4 (manuel).
- Cycle 373 dans ITFlow par les élèves.

### R5 (optionnelle) : « Mon lecteur S: a disparu » (Nathalie)

S: est mappé de façon persistante vers `\\AB-SERVEUR\Commun`, l'ancien nom du serveur.

## Scripts par machine

| Machine | Setup | Panne | Vérifier (état propre) |
| --- | --- | --- | --- |
| SRV-01 | IP fixe, comptes, groupes, dossiers, NTFS, partages, données | R1 couche 2 (mot de passe efortin) + couche 3 selon `-Variante` | ACL, groupes, partages et mot de passe conformes |
| PC-01 | Profil ncote, lecteurs S: et T: | R5 : S: vers \\AB-SERVEUR | S: pointe vers \\AB-SRV-01\Commun |
| PC-02 | Profil lpgauthier, données dont C:\Soumissions-LP et favoris Edge | R4 : démarrage encombré, processus gourmand | Démarrage propre, pas de processus fictif; `-R3` : hash des fichiers à destination |
| PC-03 | Profil efortin, lecteurs P:, R:, S: | R1 couches 1 et 2 (hosts, ancien identifiant mémorisé) | Résolution correcte, identifiant correct |
| PC-04 | Profil jbouchard | aucune (panne physique) | Poste démarré, disque en tête de l'ordre de démarrage |

La vérification « Émilie ouvre `P:\2026-021` » se fait depuis PC-03 avec un `PSCredential` d'efortin, sans laisser de trace.

## ITFlow (préparé par tools\ITFlow-AB.psm1)

Un client par équipe : « Architecture Boréale — Équipe A » à « E », créés par `New-ITFlowABClient` (ou à la main si l'API le refuse).

- Lieux : Bureaux (principal), Salle technique.
- Contacts : les 4 employés.
- Actifs : les 5 machines (numéros de série réels lus sur le matériel).
- Requêtes pré-créées : R1, R3, R4, R5. **R2 n'est pas créée** (les élèves la créent à partir de l'appel).
- Réseau, fournisseur « Fournisseur CFRN » et identifiant ab-tech : saisis à la main (non disponibles ou non souhaités par l'API).
