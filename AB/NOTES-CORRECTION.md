# Architecture Boréale : notes de correction (enseignant)

Ce fichier accompagne `AB/SPEC.md`. Il décrit ce que les élèves voient et ce qu'on
attend d'eux, requête par requête. Les élèves ne voient jamais ce dépôt.

## LibreOffice : premier lancement (tous les postes)

Décision : aucun employé ne voit de fenêtre de bienvenue au premier lancement.

- Stratégie **machine** (HKLM, verrouillée), posée par le Setup de chaque poste
  (`Set-ABMachinePolicy`) :
  - `org.openoffice.Office.Common/Misc/ShowTipOfTheDay` = false (conseils du jour);
  - `org.openoffice.Office.UI.Infobar/Enabled/WhatsNew` = false (barre « Quoi de neuf »);
  - `org.openoffice.Setup/Product/WhatsNew` = false.
- Les nœuds ont été lus dans `main.xcd` de la version installée (26.8.0.3).
- La vérification de mise à jour est retirée à l'installation (fonction MSI
  `gm_o_Onlineupdate`) : aucune invite de mise à jour pendant la mise en situation.

## R1 : « Je n'ai plus accès aux plans de la marina » (vérifié en VM, couche par couche)

| Couche corrigée | Ce que voit l'élève ensuite |
| --- | --- |
| (aucune) | `\\AB-SRV-01\Projets` : « Nom de réseau introuvable ». `ping AB-SRV-01` échoue (192.168.50.12), `ping 192.168.50.10` répond. |
| 1. Ligne « ancien serveur » retirée du fichier hosts | « Nom d'utilisateur ou mot de passe incorrect » (erreur 1326). **Juste après la correction, Windows peut encore répondre « Nom de réseau introuvable » pendant quelques secondes** (cache du client SMB) : réessayer après 20 secondes. |
| 2. Mot de passe d'Émilie remis sur le serveur (et identifiant mémorisé mis à jour ou retiré) | Le partage s'ouvre, mais le dossier `2026-021` répond « Accès refusé » (couche 3, variante A dans l'essai). |
| 3. Droits corrigés selon la variante | Émilie ouvre et lit ses plans. |

- La correction attendue de la couche 2 : Émilie n'a jamais demandé de changement, donc on remet son mot de passe habituel sur le serveur, en respectant la « Politique de mots de passe AB » (dans `Commun`). La réinitialisation par un administrateur accepte l'ancien mot de passe même si l'historique en garde 5 (vérifié).
- Le Retrait remet tout en place même après les corrections des élèves (vérifié).

## R6 variante C : réparation de LibreOffice

- La réparation (Paramètres > Applications > LibreOffice > Modifier > Réparer, élevée avec
  `ab-tech`) va chercher l'installeur dans `\\AB-SRV-01\Logiciels$\LibreOffice`.
- `ab-tech` a un droit explicite de lecture sur `Logiciels$` : par le réseau, son jeton
  d'administrateur est filtré, et sans ce droit la réparation échoue (erreur 1706, vérifié).
- Si le réseau ou le serveur est en panne, la réparation échoue aussi (voir la spec).

## R6 variante A : profil utilisateur LibreOffice corrompu

**Ce que les élèves verront après la réinitialisation du profil** (mode sans échec >
« Réinitialiser le profil utilisateur », ou renommer
`%APPDATA%\LibreOffice\4\user`) :

- LibreOffice redémarre normalement, **sans fenêtre d'accueil ni conseil du jour** :
  la stratégie est dans HKLM, elle survit à la réinitialisation du profil.
- Le **Centre de démarrage est vide** : la liste des documents récents de Nathalie a
  disparu (elle devra rouvrir `T:\Facturation\Registre-factures-2026.ods` et le
  modèle `T:\Modèles\Facture-AB.ott` par Fichier > Ouvrir).
- Les **options personnelles sont perdues** (nom d'utilisateur dans Outils > Options >
  LibreOffice > Données d'identité, autocorrection personnalisée, barres d'outils).

Point de discussion : réinitialiser un profil règle la panne, mais efface aussi des
réglages de l'utilisateur. Le bon réflexe est de **renommer** l'ancien profil plutôt
que de le supprimer, puis de récupérer ce qui est utile (par exemple
`registrymodifications.xcu`, la liste des récents) si la personne y tient.
