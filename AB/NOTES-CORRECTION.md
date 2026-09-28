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
