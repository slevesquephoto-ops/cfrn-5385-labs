# Architecture Boréale : notes de correction (enseignant)

Ce fichier accompagne `AB/SPEC.md`. Il décrit ce que les élèves voient et ce qu'on
attend d'eux, requête par requête. Les élèves ne voient jamais ce dépôt.

## Remise à zéro entre deux équipes

Sur chaque machine : `Retrait-<MACHINE>.ps1`, puis `Setup-<MACHINE>.ps1`, puis
`Panne-<MACHINE>.ps1 -Variante <lettre de l'équipe suivante>`. Temps mesurés en VM :
voir le dernier rapport de `tests/Test-ABEquipe.ps1`.

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

## R6 variante D : police de la charte désinstallée

**Contexte** : la charte graphique d'AB impose la police Montserrat (licence OFL, fournie
avec les scripts) pour tous les documents envoyés aux clients. Le modèle
`T:\Modèles\Facture-AB.ott` et les factures déjà émises l'utilisent.

**Requête ITFlow** (`AB/ITFlow-Requetes.psd1`, R6 D) : un client (la Coopérative de
santé du Littoral) remarque que la dernière facture « ne ressemble pas aux autres ».
Pièce jointe : une facture d'août correcte,
`AB/data/ncote/fichiers/Documents/Facturation/2026/Facture 2026-0140 Chalet du Lac-Boréal.pdf`
(en Montserrat).

**Ce que voient les élèves** : le modèle s'ouvre avec une police de remplacement; dans la
barre d'outils, le nom « Montserrat » s'affiche en italique sur fond jaune (police
absente). Les titres sont plus larges qu'à la facture de référence.

**Correction attendue** : réinstaller Montserrat **pour tous les utilisateurs** (clic
droit > Installer pour tous les utilisateurs, ou copie dans `C:\Windows\Fonts` en
administrateur), puis vérifier en comparant avec la facture de référence. L'installer
seulement pour Nathalie fonctionne pour elle, mais pas pour les autres employés.

## R6 variante E : sécurité des macros et modèle de facture

**Mise en place** : le modèle `Facture-AB.ott` contient une petite macro qui remplit le
numéro et la date de la facture à la création. La panne règle la sécurité des macros de
Nathalie à « Très élevé » et retire les emplacements de confiance.

**Ce que voit Nathalie** (capture en VM) : barre jaune « Macros désactivées — Les macros
de ce document sont désactivées en raison des paramètres de sécurité des macros »; le
numéro et la date restent vides.

**Correction attendue** : Outils > Options > LibreOffice > Sécurité > Sécurité des macros >
Sources de confiance > Emplacements de confiance : ajouter `\\AB-SRV-01\Administration`
et `T:\`, **sans baisser la sécurité** (Très élevé peut rester).

Le Verifier (`macros`) distingue les deux corrections :
- emplacements de confiance ajoutés, sécurité Élevé ou Très élevé : conforme (le détail
  indique « sécurité Très élevé conservée »);
- sécurité baissée à Moyen ou Bas : **échec**, même si la macro s'exécute (le détail
  l'indique en toutes lettres).

## R6 variante C : réparation de LibreOffice

- La réparation (Paramètres > Applications > LibreOffice > Modifier > Réparer, élevée avec
  `ab-tech`) va chercher l'installeur dans `\\AB-SRV-01\Logiciels$\LibreOffice`.
- `ab-tech` a un droit explicite de lecture sur `Logiciels$` : par le réseau, son jeton
  d'administrateur est filtré, et sans ce droit la réparation échoue (erreur 1706, vérifié).
- Si le réseau ou le serveur est en panne, la réparation échoue aussi (voir la spec).

## R6 variante A : profil LibreOffice verrouillé par un autre poste

**Mise en place** : le profil LibreOffice de Nathalie contient un verrou
(`%APPDATA%\LibreOffice\4\.lock`) laissé par son ancien poste, `AB-RECEPTION` (profil
recopié pendant que LibreOffice y était ouvert).

**Ce que voit Nathalie au démarrage de LibreOffice** (message exact de LibreOffice 26.8,
capture en VM) :

> Une autre instance de LibreOffice est en train d'accéder à vos paramètres personnels
> ou ces derniers sont verrouillés.
> Un accès simultané peut provoquer des incohérences dans vos paramètres personnels.
> Avant de continuer, assurez-vous que l'utilisateur « ncote » quitte bien LibreOffice
> sur l'hôte « AB-RECEPTION ».
>
> Voulez-vous vraiment continuer ?   [Oui] [Non]

Si elle répond Non, LibreOffice se ferme (c'est ce qu'elle décrit dans sa requête).

**Correction attendue : la démarche, pas seulement « Oui »**
1. Lire le message et relever les deux indices : le compte (`ncote`) et l'hôte
   (`AB-RECEPTION`).
2. Vérifier qu'aucun autre poste n'utilise ce profil : `AB-RECEPTION` n'existe plus
   (ancien poste de la réception; il ne répond pas au ping et n'est pas dans l'inventaire
   ITFlow), et Nathalie n'a pas de session ouverte ailleurs.
3. Ensuite seulement : supprimer le fichier `.lock` (profil fermé), ou répondre Oui en
   connaissance de cause. Documenter la cause dans la requête ITFlow.

Un élève qui clique sur Oui sans avoir vérifié règle le symptôme, mais pas la démarche :
à discuter (un accès simultané réel pourrait corrompre le profil).

Le Verifier (`profil-libreoffice`) accepte les deux corrections : le verrou est absent,
ou il a été repris par `AB-PC-01` quand LibreOffice a continué.

### Si le profil est ensuite réinitialisé (mode sans échec)

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
