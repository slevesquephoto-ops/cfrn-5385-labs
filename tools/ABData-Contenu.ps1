#requires -version 5.1
<#
ABData-Contenu.ps1 - Définitions des données fictives d'Architecture Boréale.
Chargé (dot-source) par tools\New-ABData.ps1. Aucune donnée réelle : entreprises,
personnes et adresses fictives; courriels en .example.

Chaque fichier est un objet :
  Proprietaire  efortin | lpgauthier | jbouchard | ncote | SRV-01
  Cible         relative au profil (Desktop\, Documents\, Downloads\, Pictures\),
                absolue (C:\...), ou relative à C:\AB pour SRV-01
  Type          odt | ods | pdf | ott | dxf | png
  Modele        gabarit de contenu (voir New-ABData.ps1)
  P             paramètres du gabarit
  Cree/Modifie  dates (déterministes)
  Criticite     Critique | Importante | Standard (R3; Standard sur le serveur)
#>

$script:ABProjets = @{
    '2026-014' = @{ Code = '2026-014'; Nom = 'Chalet du Lac-Boréal'; Dossier = '2026-014 Chalet du Lac-Boréal'
        Client = 'Famille Tremblay-Roy'; Adresse = '87, chemin du Lac-Boréal'; Entrepreneur = 'Construction Fleuve-Bleu inc.'; Budget = 485000 }
    '2026-017' = @{ Code = '2026-017'; Nom = 'Clinique du Littoral'; Dossier = '2026-017 Clinique du Littoral'
        Client = 'Coopérative de santé du Littoral'; Adresse = '1200, boulevard du Littoral'; Entrepreneur = 'Bâtiments Mitis ltée'; Budget = 3250000 }
    '2026-021' = @{ Code = '2026-021'; Nom = 'Agrandissement Marina Pointe-Blanche'; Dossier = '2026-021 Agrandissement Marina Pointe-Blanche'
        Client = 'Municipalité de Pointe-Blanche'; Adresse = '4, rue du Quai'; Entrepreneur = 'Construction Fleuve-Bleu inc.'; Budget = 1870000 }
}

function script:D {
    <# Définition d'un fichier; dates « AAAA-MM-JJ HH:mm ». #>
    param([string]$Proprietaire, [string]$Cible, [string]$Type, [string]$Modele, [hashtable]$P = @{},
        [string]$Cree, [string]$Modifie, [string]$Criticite = 'Standard')
    if (-not $Modifie) { $Modifie = $Cree }
    [pscustomobject]@{ Proprietaire = $Proprietaire; Cible = $Cible; Type = $Type; Modele = $Modele; P = $P
        Cree = [datetime]::ParseExact($Cree, 'yyyy-MM-dd HH:mm', $null); Modifie = [datetime]::ParseExact($Modifie, 'yyyy-MM-dd HH:mm', $null); Criticite = $Criticite }
}

function Get-ABDataDefinition {
    $m = $script:ABProjets['2026-021']; $c = $script:ABProjets['2026-017']; $h = $script:ABProjets['2026-014']
    $defs = New-Object System.Collections.Generic.List[object]
    $add = { param($d) $defs.Add($d) }

    # ======================= efortin (Émilie Fortin, architecte de projets) =======================
    $o = 'efortin'; $dm = "Documents\$($m.Dossier)"; $dc = "Documents\$($c.Dossier)"; $dh = "Documents\$($h.Dossier)"
    foreach ($r in @(@(1, '2026-05-20 10:12', '2026-05-28 16:40'), @(2, '2026-07-08 09:05', '2026-07-15 15:22'), @(3, '2026-08-26 13:30', '2026-09-10 11:48'))) {
        & $add (D $o "$dm\Devis\Devis 2026-021 rév. $($r[0]).ods" ods devis @{ Projet = $m; Revision = $r[0] } $r[1] $r[2])
    }
    & $add (D $o "$dm\Correspondance\2026-05-06 Lettre Municipalité - dépôt du concept.odt" odt lettre @{ Projet = $m; De = 'efortin'; A = 'Mme Sylvie Gagnon, directrice générale'; Societe = $m.Client
            Objet = 'Dépôt du concept préliminaire'; Date = '6 mai 2026'
            Corps = @('Nous avons le plaisir de vous transmettre le concept préliminaire de l''agrandissement de la marina, conforme au programme approuvé par le conseil le 14 avril dernier.', 'Le concept prévoit un pavillon d''accueil de 240 m², un quai flottant de 36 emplacements et le réaménagement de l''aire de mise à l''eau.', 'Nous vous proposons une rencontre de présentation au cours de la semaine du 19 mai.') } '2026-05-06 09:20' '2026-05-06 11:05')
    & $add (D $o "$dm\Correspondance\2026-08-14 Lettre entrepreneur - retard des fondations.odt" odt lettre @{ Projet = $m; De = 'efortin'; A = 'M. Patrick Ouellet, chargé de projet'; Societe = $m.Entrepreneur
            Objet = 'Retard des travaux de fondation du pavillon'; Date = '14 août 2026'
            Corps = @('Lors de la visite de chantier du 13 août, nous avons constaté que le coffrage des semelles du pavillon n''était pas terminé, alors que l''échéancier prévoyait le coulage le 8 août.', 'Nous vous demandons de nous transmettre, d''ici le 21 août, un échéancier révisé indiquant les mesures prises pour récupérer ce retard.', 'Nous vous rappelons que la fenêtre de travaux dans l''eau se termine le 30 septembre.') } '2026-08-14 14:02' '2026-08-14 16:31')
    & $add (D $o "$dm\Correspondance\2026-09-02 Avis de modification AM-04.pdf" pdf avis @{ Projet = $m; Numero = 'AM-04'; Date = '2 septembre 2026'
            Objet = 'Remplacement des pieux du quai no 3'; Detail = 'Les pieux de bois traité du quai no 3 sont remplacés par des pieux d''acier galvanisé de 219 mm, conformément à la recommandation de l''ingénieur en structure (rapport ILC-2026-118).'; Montant = 38450 } '2026-09-02 10:15' '2026-09-02 10:15')
    foreach ($cr in @(@('2026-08-20', '20 août 2026'), @('2026-09-03', '3 septembre 2026'), @('2026-09-17', '17 septembre 2026'))) {
        & $add (D $o "$dm\Comptes rendus\Compte rendu de chantier $($cr[0]).odt" odt compte-rendu @{ Projet = $m; Date = $cr[1] } "$($cr[0]) 16:10" "$($cr[0]) 17:25")
    }
    & $add (D $o "$dm\Plans\A-101 Plan d'implantation rév. D.pdf" pdf plan-pdf @{ Projet = $m; Feuille = 'A-101'; Titre = 'Plan d''implantation'; Rev = 'D'; Forme = 'marina' } '2026-07-30 11:00' '2026-08-27 15:12')
    & $add (D $o "$dm\Plans\A-201 Élévations du quai rév. C.pdf" pdf plan-pdf @{ Projet = $m; Feuille = 'A-201'; Titre = 'Élévations du quai'; Rev = 'C'; Forme = 'elevation' } '2026-07-30 11:05' '2026-08-27 15:14')
    & $add (D $o "$dc\Plans\A-101 Plan rez-de-chaussée rév. B.pdf" pdf plan-pdf @{ Projet = $c; Feuille = 'A-101'; Titre = 'Plan du rez-de-chaussée'; Rev = 'B'; Forme = 'clinique' } '2026-03-18 10:00' '2026-04-29 14:20')
    & $add (D $o "$dc\Plans\A-102 Plan de l'étage rév. B.pdf" pdf plan-pdf @{ Projet = $c; Feuille = 'A-102'; Titre = 'Plan de l''étage'; Rev = 'B'; Forme = 'clinique2' } '2026-03-18 10:05' '2026-04-29 14:25')
    & $add (D $o "$dc\Devis\Devis 2026-017 rév. 2.ods" ods devis @{ Projet = $c; Revision = 2 } '2026-04-02 09:30' '2026-05-12 13:15')
    & $add (D $o "$dc\Correspondance\2026-04-11 Lettre Coopérative - programme fonctionnel.odt" odt lettre @{ Projet = $c; De = 'efortin'; A = 'Dr Marc-André Lévesque, président'; Societe = $c.Client
            Objet = 'Programme fonctionnel et technique'; Date = '11 avril 2026'
            Corps = @('À la suite de notre rencontre du 8 avril, vous trouverez ci-joint la version révisée du programme fonctionnel.', 'Les principaux changements touchent le nombre de salles d''examen (passé de 10 à 12) et l''ajout d''une salle de prélèvements au rez-de-chaussée.', 'Merci de nous faire part de vos commentaires d''ici le 25 avril.') } '2026-04-11 10:40' '2026-04-11 14:02')
    & $add (D $o "$dc\Programme fonctionnel - notes.odt" odt note @{ Titre = 'Clinique du Littoral : notes sur le programme'; Puces = @('12 salles d''examen, dont 2 adaptées', 'Salle de prélèvements près de l''entrée', 'Accès universel : ascenseur et salle de bain adaptée à chaque étage', 'Stationnement de 48 places, dont 4 réservées', 'Prévoir l''agrandissement possible vers le nord') } '2026-03-09 15:00' '2026-04-14 09:10')
    & $add (D $o "$dh\Compte rendu de chantier 2026-06-03.odt" odt compte-rendu @{ Projet = $h; Date = '3 juin 2026' } '2026-06-03 15:40' '2026-06-04 08:55')
    & $add (D $o "$dh\Liste des déficiences.ods" ods deficiences @{ Projet = $h } '2026-06-10 13:00' '2026-07-02 10:30')
    & $add (D $o "$dh\Plans\A-301 Coupe type.pdf" pdf plan-pdf @{ Projet = $h; Feuille = 'A-301'; Titre = 'Coupe type'; Rev = 'A'; Forme = 'coupe' } '2026-02-11 09:00' '2026-02-19 16:45')
    & $add (D $o 'Documents\Administratif\Feuille de temps septembre 2026.ods' ods feuille-temps @{ Nom = 'Émilie Fortin'; Mois = 'septembre 2026' } '2026-09-01 08:30' '2026-09-25 17:05')
    & $add (D $o 'Documents\Administratif\Frais de déplacement 2026.ods' ods frais @{ Nom = 'Émilie Fortin' } '2026-01-15 09:00' '2026-09-18 16:20')
    & $add (D $o 'Desktop\À faire cette semaine.odt' odt note @{ Titre = 'À faire cette semaine'; Puces = @('Marina : relancer Fleuve-Bleu pour l''échéancier révisé', 'Marina : vérifier les dessins d''atelier des garde-corps', 'Clinique : réponse aux commentaires du Dr Lévesque', 'Chalet : visite finale avec la famille Tremblay-Roy (jeudi)', 'Envoyer la feuille de temps à Nathalie') } '2026-09-21 08:10' '2026-09-25 16:50')
    & $add (D $o 'Desktop\Coordonnées chantier Marina.odt' odt note @{ Titre = 'Chantier de la marina : coordonnées'; Puces = @('Chargé de projet (Fleuve-Bleu) : Patrick Ouellet, 418 555-0142', 'Surintendant : Guy Pelletier, 418 555-0187', 'Municipalité : Sylvie Gagnon, 418 555-0110', 'Ingénieur en structure (ILC) : Karine Dionne, 418 555-0163') } '2026-06-15 09:00' '2026-08-18 10:22')

    # ======================= lpgauthier (Louis-Philippe Gauthier, associé) =======================
    $o = 'lpgauthier'
    & $add (D $o 'C:\Soumissions-LP\Soumission 2026-023 Centre communautaire.ods' ods soumission @{ Numero = '2026-023'; Projet = 'Centre communautaire de Pointe-Blanche'; Client = 'Municipalité de Pointe-Blanche'; Honoraires = 212000 } '2026-08-28 19:40' '2026-09-24 22:15' 'Critique')
    & $add (D $o 'C:\Soumissions-LP\Soumission 2026-024 Résidence Bérubé.ods' ods soumission @{ Numero = '2026-024'; Projet = 'Résidence Bérubé-Morin'; Client = 'M. et Mme Bérubé-Morin'; Honoraires = 38500 } '2026-09-05 20:10' '2026-09-19 21:30' 'Critique')
    & $add (D $o 'C:\Soumissions-LP\Soumission 2026-025 Caserne de Pointe-Blanche.ods' ods soumission @{ Numero = '2026-025'; Projet = 'Caserne de pompiers de Pointe-Blanche'; Client = 'Municipalité de Pointe-Blanche'; Honoraires = 164000 } '2026-09-12 18:55' '2026-09-26 17:40' 'Critique')
    & $add (D $o 'C:\Soumissions-LP\Lettre de présentation - Centre communautaire.odt' odt lettre @{ Projet = $null; De = 'lpgauthier'; A = 'Mme Sylvie Gagnon, directrice générale'; Societe = 'Municipalité de Pointe-Blanche'
            Objet = 'Appel de propositions : services professionnels en architecture, centre communautaire'; Date = '24 septembre 2026'
            Corps = @('Architecture Boréale est heureuse de soumettre sa proposition pour la conception du futur centre communautaire.', 'Notre équipe connaît bien votre milieu : nous réalisons actuellement l''agrandissement de la marina et avons conçu la Clinique du Littoral.', 'Vous trouverez ci-joints notre méthodologie, notre échéancier et notre offre d''honoraires.') } '2026-09-20 21:05' '2026-09-24 22:40' 'Importante')
    & $add (D $o 'C:\Soumissions-LP\Échéancier des soumissions automne 2026.ods' ods tableau @{ Colonnes = @('Soumission', 'Client', 'Dépôt', 'Statut'); Lignes = @(@('2026-023 Centre communautaire', 'Municipalité de Pointe-Blanche', '2026-10-02', 'En rédaction'), @('2026-024 Résidence Bérubé-Morin', 'Particulier', '2026-09-30', 'À réviser'), @('2026-025 Caserne', 'Municipalité de Pointe-Blanche', '2026-10-16', 'Démarrée')) } '2026-08-25 09:00' '2026-09-26 17:55' 'Importante')
    & $add (D $o 'Documents\Direction\Budget du cabinet 2026.ods' ods budget @{ Annee = 2026 } '2025-11-20 20:00' '2026-09-15 21:10' 'Critique')
    & $add (D $o 'Documents\Direction\Budget du cabinet 2025 - réel.ods' ods budget @{ Annee = 2025; Reel = $true } '2024-11-18 19:30' '2026-01-28 20:45' 'Importante')
    & $add (D $o 'Documents\Direction\Prévisions de trésorerie T4 2026.ods' ods tresorerie @{ } '2026-09-01 20:15' '2026-09-22 21:50' 'Critique')
    foreach ($ct in @(@($m, '2026-03-02', 'Critique'), @($c, '2026-01-20', 'Critique'), @($h, '2025-11-04', 'Importante'))) {
        $d0 = [datetime]$ct[1]
        & $add (D $o "Documents\Contrats\Contrat $($ct[0].Code) $($ct[0].Nom) - signé.pdf" pdf contrat @{ Projet = $ct[0]; Date = $d0.ToString('d MMMM yyyy', [Globalization.CultureInfo]'fr-CA') } "$($ct[1]) 14:00" "$($ct[1]) 14:00" $ct[2])
    }
    & $add (D $o 'Documents\Confidentiel\Évaluation annuelle - Jérémie Bouchard.odt' odt evaluation @{ Nom = 'Jérémie Bouchard'; Poste = 'Technicien en architecture' } '2026-06-10 19:00' '2026-06-18 20:30' 'Critique')
    & $add (D $o 'Documents\Confidentiel\Évaluation annuelle - Émilie Fortin.odt' odt evaluation @{ Nom = 'Émilie Fortin'; Poste = 'Architecte de projets' } '2026-06-11 19:15' '2026-06-19 21:05' 'Critique')
    & $add (D $o 'Documents\Confidentiel\Offre d''association - brouillon.odt' odt note @{ Titre = 'Offre d''association (brouillon, confidentiel)'; Puces = @('Proposer à Émilie une participation de 20 % au 1er janvier 2027', 'Valeur des parts selon l''évaluation du comptable (à venir)', 'Clause de non-concurrence : 2 ans, Bas-Saint-Laurent', 'En parler d''abord avec le comptable (rencontre du 8 octobre)') } '2026-08-30 21:40' '2026-09-20 22:05' 'Critique')
    & $add (D $o 'Documents\Congrès 2026\Conférence - Architecture et climat nordique.pdf' pdf presentation @{ Titre = 'Architecture et climat nordique'; Sous = 'Congrès 2026 : conférence de Louis-Philippe Gauthier, architecte'; Diapos = @('Concevoir pour 180 jours de gel', 'Enveloppe : ponts thermiques et étanchéité à l''air', 'Cas : Chalet du Lac-Boréal', 'Cas : Agrandissement Marina Pointe-Blanche', 'Leçons apprises') } '2026-08-15 20:00' '2026-09-26 23:10' 'Critique')
    & $add (D $o 'Documents\Congrès 2026\Notes de conférence.odt' odt note @{ Titre = 'Notes de conférence'; Puces = @('Ouvrir avec la photo du quai en février', 'Chiffres : 22 % d''économie de chauffage au chalet', 'Ne pas dépasser 35 minutes', 'Remercier la Municipalité de Pointe-Blanche') } '2026-09-10 21:00' '2026-09-26 23:20' 'Importante')
    & $add (D $o 'Documents\Projets\Honoraires 2026 par projet.ods' ods honoraires @{ } '2026-01-08 19:30' '2026-09-18 20:40' 'Importante')
    & $add (D $o 'Desktop\Présentation client - Clinique du Littoral.pdf' pdf presentation @{ Titre = 'Clinique du Littoral'; Sous = 'Présentation du concept au conseil d''administration'; Diapos = @('Programme : 12 salles d''examen', 'Implantation et accès', 'Plan du rez-de-chaussée', 'Échéancier et budget') } '2026-04-20 19:00' '2026-05-04 22:30' 'Importante')
    & $add (D $o 'Desktop\Liste d''appels.odt' odt note @{ Titre = 'Liste d''appels'; Puces = @('Comptable : rencontre du 8 octobre', 'Sylvie Gagnon : dépôt de la soumission du centre communautaire', 'Assureur : renouvellement responsabilité professionnelle', 'Hôtel du congrès : confirmer l''arrivée') } '2026-09-22 08:00' '2026-09-26 17:10')
    & $add (D $o 'Downloads\Programme du congrès 2026.pdf' pdf note-pdf @{ Titre = 'Congrès 2026 : programme'; Puces = @('Jeudi 9 h : ouverture', 'Jeudi 14 h : Architecture et climat nordique (L.-P. Gauthier)', 'Vendredi 9 h : table ronde sur le bois massif', 'Vendredi 16 h : clôture') } '2026-09-03 12:40' '2026-09-03 12:40')
    & $add (D $o 'Downloads\Formulaire d''inscription au congrès.pdf' pdf note-pdf @{ Titre = 'Formulaire d''inscription'; Puces = @('Nom : Louis-Philippe Gauthier', 'Cabinet : Architecture Boréale', 'Statut : conférencier', 'Courriel : lpgauthier@architecture-boreale.example') } '2026-06-02 21:15' '2026-06-02 21:15')
    & $add (D $o 'Downloads\Catalogue fenêtres 2026.pdf' pdf note-pdf @{ Titre = 'Fenêtres Nordiques : catalogue 2026 (fictif)'; Puces = @('Série Boréa : triple vitrage, U = 0,80', 'Série Littoral : cadre en aluminium hybride', 'Délais de livraison : 8 à 10 semaines') } '2026-05-11 13:20' '2026-05-11 13:20')
    & $add (D $o 'Downloads\Facture hôtel congrès.pdf' pdf facture @{ Numero = 'H-55821'; Emetteur = 'Hôtel du Havre (fictif)'; Client = 'Louis-Philippe Gauthier'; Date = '26 septembre 2026'; Lignes = @(@('Chambre, 2 nuits', 398.00), @('Stationnement', 36.00)) } '2026-09-26 18:05' '2026-09-26 18:05' 'Importante')
    # Favoris Edge : piège de R3 (hors profil Documents; Critique = exigé par Verifier -R3)
    & $add (D $o 'AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks' edge favoris @{ Favoris = @(
                @('Clients', @(@('Municipalité de Pointe-Blanche', 'https://pointe-blanche.example'), @('Coopérative de santé du Littoral', 'https://coop-littoral.example'), @('Ordre des architectes du Québec', 'https://oaq.example'))),
                @('Fournisseurs', @(@('Fenêtres Nordiques', 'https://fenetres-nordiques.example'), @('Ingénierie Littoral Conseil', 'https://ilc.example'))),
                @('Congrès 2026', @(@('Programme du congrès', 'https://congres-architecture.example/2026'), @('Hôtel du Havre', 'https://hotel-du-havre.example')))
            ) } '2026-01-10 08:30' '2026-09-26 22:45' 'Critique')

    # ======================= jbouchard (Jérémie Bouchard, technicien) =======================
    $o = 'jbouchard'
    foreach ($pl in @(
            @($m, 'A-101', 'Plan d''implantation', 'marina', '2026-06-02 08:40', '2026-08-26 16:10'), @($m, 'A-201', 'Élévations du quai rév. C', 'elevation', '2026-06-09 09:15', '2026-08-27 11:30'), @($m, 'A-501', 'Détails du quai', 'detail', '2026-07-14 10:00', '2026-09-09 15:45'),
            @($c, 'A-101', 'Plan rez-de-chaussée', 'clinique', '2026-02-24 08:30', '2026-04-28 16:00'), @($c, 'A-102', 'Plan de l''étage', 'clinique2', '2026-02-26 09:00', '2026-04-28 16:20'), @($c, 'A-301', 'Coupes', 'coupe', '2026-03-10 10:30', '2026-05-05 14:10'),
            @($h, 'A-101', 'Plan du chalet', 'chalet', '2025-10-06 08:45', '2026-01-22 15:30'), @($h, 'A-201', 'Élévations du chalet', 'elevation', '2025-10-14 09:20', '2026-01-22 15:50'))) {
        & $add (D $o "Documents\Plans\$($pl[0].Code)\$($pl[1]) $($pl[2]).dxf" dxf plan-dxf @{ Projet = $pl[0]; Feuille = $pl[1]; Titre = $pl[2]; Forme = $pl[3] } $pl[4] $pl[5])
    }
    foreach ($s in @(@('Portes et fenêtres', 'portes'), @('Mobilier', 'mobilier'), @('Cartouche AB', 'cartouche'), @('Flèches et annotations', 'annotations'))) {
        & $add (D $o "Documents\Bibliothèque de symboles\$($s[0]).dxf" dxf symboles-dxf @{ Famille = $s[1] } '2025-03-17 10:00' '2026-02-05 14:30')
    }
    & $add (D $o 'Documents\Normes\Calques et épaisseurs de trait.ods' ods tableau @{ Colonnes = @('Calque', 'Couleur', 'Épaisseur (mm)', 'Usage'); Lignes = @(@('A-MUR', 'Blanc', '0,50', 'Murs coupés'), @('A-PORTE', 'Jaune', '0,25', 'Portes'), @('A-FENETRE', 'Cyan', '0,25', 'Fenêtres'), @('A-COTE', 'Vert', '0,18', 'Cotes'), @('A-TEXTE', 'Blanc', '0,18', 'Textes'), @('A-HACHURE', 'Gris', '0,09', 'Hachures')) } '2025-02-10 09:00' '2025-09-02 11:15')
    & $add (D $o 'Documents\Suivi des dessins 2026.ods' ods tableau @{ Colonnes = @('Projet', 'Feuille', 'Révision', 'Date', 'Émis pour'); Lignes = @(@('2026-021', 'A-101', 'D', '2026-08-27', 'Construction'), @('2026-021', 'A-201', 'C', '2026-08-27', 'Construction'), @('2026-021', 'A-501', 'B', '2026-09-09', 'Construction'), @('2026-017', 'A-101', 'B', '2026-04-29', 'Appel d''offres'), @('2026-017', 'A-102', 'B', '2026-04-29', 'Appel d''offres'), @('2026-014', 'A-101', 'E', '2026-01-22', 'Construction')) } '2026-01-05 08:30' '2026-09-24 16:40')
    foreach ($rd in @(@('2026-014 Chalet - vue du lac au crépuscule', 'chalet-soir', '2026-01-28 15:00'), @('2026-014 Chalet - entrée', 'chalet-jour', '2026-01-29 11:20'), @('2026-017 Clinique - façade principale', 'clinique', '2026-05-01 14:45'), @('2026-021 Marina - vue aérienne', 'marina', '2026-06-20 10:10'), @('2026-021 Marina - pavillon d''accueil', 'pavillon', '2026-06-22 16:30'))) {
        & $add (D $o "Pictures\Rendus\$($rd[0]).png" png rendu @{ Scene = $rd[1]; Titre = $rd[0] } $rd[2] $rd[2])
    }
    & $add (D $o 'Pictures\Références\Revêtement de bois brûlé.png' png rendu @{ Scene = 'texture'; Titre = 'Bois brûlé' } '2025-11-12 13:05' '2025-11-12 13:05')
    & $add (D $o 'Desktop\Normes de dessin AB.pdf' pdf note-pdf @{ Titre = 'Normes de dessin d''Architecture Boréale'; Puces = @('Unités : millimètres; échelles 1:100 (plans) et 1:20 (détails)', 'Cartouche AB obligatoire sur chaque feuille', 'Nom des fichiers : <projet> <feuille> <titre>', 'Calques : voir « Calques et épaisseurs de trait »', 'Révisions : lettre + nuage + tableau des révisions') } '2025-02-10 10:00' '2025-09-02 11:30')
    & $add (D $o 'Desktop\Raccourcis clavier LibreCAD.odt' odt note @{ Titre = 'Raccourcis clavier LibreCAD'; Puces = @('li : ligne', 'rc : rectangle', 'ci : cercle', 'mv : déplacer', 'co : copier', 'tm : ajuster') } '2025-03-03 09:30' '2025-03-03 09:30')

    # ======================= ncote (Nathalie Côté, adjointe administrative) =======================
    $o = 'ncote'
    $clients = @(@('Coopérative de santé du Littoral', $c), @('Municipalité de Pointe-Blanche', $m), @('Famille Tremblay-Roy', $h))
    for ($i = 135; $i -le 142; $i++) {
        $cl = $clients[$i % 3]; $d0 = ([datetime]'2026-06-01').AddDays(($i - 135) * 16)
        $num = "2026-0$i"
        & $add (D $o "Documents\Facturation\2026\Facture $num $($cl[1].Nom).pdf" pdf facture @{ Numero = $num; Emetteur = 'Architecture Boréale'; Client = $cl[0]; Projet = $cl[1]; Date = $d0.ToString('d MMMM yyyy', [Globalization.CultureInfo]'fr-CA')
                Lignes = @(@("Honoraires professionnels, projet $($cl[1].Code), étape $((($i - 135) % 4) + 1)", [double](4200 + (($i * 373) % 9000))), @('Frais de reprographie', [double](85 + ($i % 7) * 12))) } ($d0.ToString('yyyy-MM-dd') + ' 10:15') ($d0.ToString('yyyy-MM-dd') + ' 10:40') 'Importante')
    }
    & $add (D $o 'Documents\Facturation\2026\Suivi des comptes clients.ods' ods comptes-clients @{ } '2026-01-05 08:20' '2026-09-25 15:45' 'Critique')
    & $add (D $o 'Documents\Facturation\2026\Dépôts bancaires septembre.ods' ods tableau @{ Colonnes = @('Date', 'Client', 'Facture', 'Montant'); Lignes = @(@('2026-09-04', 'Coopérative de santé du Littoral', '2026-0138', '6 215,40 $'), @('2026-09-11', 'Municipalité de Pointe-Blanche', '2026-0136', '9 870,00 $'), @('2026-09-23', 'Famille Tremblay-Roy', '2026-0137', '4 950,00 $')) } '2026-09-04 11:00' '2026-09-23 14:30')
    & $add (D $o 'Documents\Facturation\2025\Récapitulatif des factures 2025.ods' ods tableau @{ Colonnes = @('Mois', 'Nombre de factures', 'Total'); Lignes = @(@('Janvier', '9', '48 320 $'), @('Avril', '11', '61 905 $'), @('Juillet', '8', '39 410 $'), @('Octobre', '12', '72 880 $'), @('Décembre', '10', '55 140 $')) } '2025-01-31 16:00' '2026-01-09 10:25')
    & $add (D $o 'Documents\Facturation\Relances\Relance - Coopérative de santé du Littoral.odt' odt lettre @{ Projet = $c; De = 'ncote'; A = 'Service des comptes fournisseurs'; Societe = $c.Client
            Objet = 'Rappel : facture 2026-0141'; Date = '22 septembre 2026'
            Corps = @('Sauf erreur de notre part, la facture 2026-0141 datée du 15 août 2026 demeure impayée.', 'Nous vous serions reconnaissants de bien vouloir en effectuer le paiement dans les meilleurs délais.', 'Si le paiement a déjà été fait, veuillez ne pas tenir compte de ce rappel.') } '2026-09-22 09:30' '2026-09-22 09:55')
    & $add (D $o 'Documents\Fournisseurs\Liste des fournisseurs 2026.ods' ods fournisseurs @{ } '2026-01-12 10:00' '2026-08-20 11:35')
    & $add (D $o 'Documents\Fournisseurs\Contrat d''entretien du photocopieur.pdf' pdf note-pdf @{ Titre = 'Contrat d''entretien : photocopieur (fictif)'; Puces = @('Fournisseur : Bureautique du Fleuve (fictif)', 'Durée : 1er mars 2026 au 28 février 2027', '3 visites préventives par année', 'Coût : 0,012 $ par page noir et blanc') } '2026-02-24 14:00' '2026-02-24 14:00')
    & $add (D $o 'Documents\Agenda\Agenda de Louis-Philippe - septembre 2026.odt' odt agenda @{ Mois = 'septembre 2026' } '2026-08-28 09:00' '2026-09-25 16:10')
    & $add (D $o 'Documents\Agenda\Agenda de Louis-Philippe - octobre 2026.odt' odt agenda @{ Mois = 'octobre 2026' } '2026-09-18 10:20' '2026-09-25 16:15')
    & $add (D $o 'Documents\Bureau\Procédure d''accueil des clients.odt' odt note @{ Titre = 'Accueil des clients'; Puces = @('Accueillir le client et offrir un café', 'Prévenir l''architecte responsable par téléphone (poste 2x)', 'Réserver la salle de réunion dans l''agenda partagé', 'Remettre la carte du stationnement visiteurs') } '2025-04-08 10:00' '2026-02-17 11:40')
    & $add (D $o 'Documents\Bureau\Inventaire des fournitures.ods' ods tableau @{ Colonnes = @('Article', 'Quantité', 'Seuil de commande'); Lignes = @(@('Papier 8½ x 11 (caisses)', '4', '2'), @('Papier 11 x 17 (rames)', '6', '3'), @('Cartouches traceur (noir)', '1', '2'), @('Tubes à plans', '12', '10')) } '2026-01-06 09:10' '2026-09-15 14:05')
    & $add (D $o 'Documents\Bureau\Congés 2026.ods' ods tableau @{ Colonnes = @('Employé', 'Du', 'Au', 'Motif'); Lignes = @(@('Jérémie Bouchard', '2026-07-20', '2026-08-07', 'Vacances'), @('Émilie Fortin', '2026-08-24', '2026-08-28', 'Vacances'), @('Louis-Philippe Gauthier', '2026-10-01', '2026-10-02', 'Congrès'), @('Nathalie Côté', '2026-07-06', '2026-07-17', 'Vacances')) } '2026-01-14 10:30' '2026-09-02 09:45')
    & $add (D $o 'Documents\Courrier\Modèle de lettre AB.odt' odt lettre @{ Projet = $null; De = 'ncote'; A = '[Nom du destinataire]'; Societe = '[Entreprise]'; Objet = '[Objet]'; Date = '[Date]'; Corps = @('[Texte de la lettre]') } '2025-03-02 09:00' '2025-03-02 09:30')
    & $add (D $o 'Desktop\Numéros utiles.odt' odt note @{ Titre = 'Numéros utiles'; Puces = @('Soutien informatique : Fournisseur CFRN (fictif), 418 555-0199', 'Propriétaire de l''immeuble : 418 555-0120', 'Traiteur (réunions) : 418 555-0175', 'Messagerie (plans) : 418 555-0158') } '2025-05-12 09:00' '2026-06-03 10:10')
    & $add (D $o 'Desktop\Tâches de la réception.odt' odt note @{ Titre = 'Tâches de la réception'; Puces = @('Lundi : dépôt bancaire', 'Mercredi : relances des comptes à plus de 30 jours', 'Vendredi : sauvegarde du registre des factures', 'Fin de mois : factures d''honoraires') } '2025-06-02 08:45' '2026-03-30 09:20')

    # ======================= SRV-01 (partages, relatif à C:\AB) =======================
    $o = 'SRV-01'
    foreach ($p in @($m, $c, $h)) {
        $base = "Projets\$($p.Dossier)"
        & $add (D $o "$base\Plans\A-101 Plan principal.pdf" pdf plan-pdf @{ Projet = $p; Feuille = 'A-101'; Titre = 'Plan principal'; Rev = 'C'; Forme = @{ '2026-021' = 'marina'; '2026-017' = 'clinique'; '2026-014' = 'chalet' }[$p.Code] } '2026-03-02 09:00' '2026-08-27 15:30')
        & $add (D $o "$base\Plans\A-201 Élévations.pdf" pdf plan-pdf @{ Projet = $p; Feuille = 'A-201'; Titre = 'Élévations'; Rev = 'B'; Forme = 'elevation' } '2026-03-02 09:10' '2026-08-27 15:35')
        & $add (D $o "$base\Plans\A-101 Plan principal.dxf" dxf plan-dxf @{ Projet = $p; Feuille = 'A-101'; Titre = 'Plan principal'; Forme = @{ '2026-021' = 'marina'; '2026-017' = 'clinique'; '2026-014' = 'chalet' }[$p.Code] } '2026-03-02 09:00' '2026-08-27 15:30')
        & $add (D $o "$base\Devis\Devis $($p.Code).ods" ods devis @{ Projet = $p; Revision = 3 } '2026-03-15 10:00' '2026-09-10 11:50')
        & $add (D $o "$base\Correspondance\Compte rendu de chantier 2026-09-17.odt" odt compte-rendu @{ Projet = $p; Date = '17 septembre 2026' } '2026-09-17 16:10' '2026-09-17 17:25')
    }
    $r6 = (Get-ABConfig).Pannes.R6
    & $add (D $o "Administration\$($r6.Registre)" ods registre-factures @{ } '2026-01-05 08:20' '2026-09-25 15:50')
    & $add (D $o "Administration\$($r6.Modele)" ott modele-facture @{ } '2025-03-02 10:00' '2026-01-08 09:15')
    & $add (D $o 'Administration\Fournisseurs\Liste des fournisseurs 2026.ods' ods fournisseurs @{ } '2026-01-12 10:00' '2026-08-20 11:35')
    & $add (D $o 'Direction\Budget\Budget du cabinet 2026.ods' ods budget @{ Annee = 2026 } '2025-11-20 20:00' '2026-09-15 21:10')
    & $add (D $o "Direction\Contrats\Contrat $($m.Code) $($m.Nom) - signé.pdf" pdf contrat @{ Projet = $m; Date = '2 mars 2026' } '2026-03-02 14:00' '2026-03-02 14:00')
    & $add (D $o "Direction\Contrats\Contrat $($c.Code) $($c.Nom) - signé.pdf" pdf contrat @{ Projet = $c; Date = '20 janvier 2026' } '2026-01-20 14:00' '2026-01-20 14:00')
    & $add (D $o 'Archives\2024\2024-009 Garage municipal - plans finaux.pdf' pdf plan-pdf @{ Projet = @{ Code = '2024-009'; Nom = 'Garage municipal'; Client = 'Municipalité de Pointe-Blanche'; Adresse = '30, rue de l''Église' }; Feuille = 'A-101'; Titre = 'Plan final'; Rev = 'F'; Forme = 'clinique' } '2024-05-14 10:00' '2024-11-29 16:00')
    & $add (D $o 'Archives\2024\2024-012 Résidence Saint-Pierre - plans finaux.pdf' pdf plan-pdf @{ Projet = @{ Code = '2024-012'; Nom = 'Résidence Saint-Pierre'; Client = 'M. et Mme Saint-Pierre'; Adresse = '11, rang du Fleuve' }; Feuille = 'A-101'; Titre = 'Plan final'; Rev = 'E'; Forme = 'chalet' } '2024-03-04 09:00' '2024-09-12 15:20')
    & $add (D $o 'Archives\2025\2025-006 Bibliothèque de quartier - plans finaux.pdf' pdf plan-pdf @{ Projet = @{ Code = '2025-006'; Nom = 'Bibliothèque de quartier'; Client = 'Municipalité de Pointe-Blanche'; Adresse = '215, avenue des Pins' }; Feuille = 'A-101'; Titre = 'Plan final'; Rev = 'D'; Forme = 'clinique2' } '2025-02-10 09:30' '2025-10-30 14:50')
    & $add (D $o 'Archives\2025\Registre des factures 2025.ods' ods tableau @{ Colonnes = @('Mois', 'Nombre de factures', 'Total'); Lignes = @(@('Janvier', '9', '48 320 $'), @('Avril', '11', '61 905 $'), @('Juillet', '8', '39 410 $'), @('Octobre', '12', '72 880 $'), @('Décembre', '10', '55 140 $')) } '2025-01-31 16:00' '2026-01-09 10:25')
    & $add (D $o 'Commun\Politiques\Politique de mots de passe AB.odt' odt politique-mdp @{ } '2026-09-01 09:00' '2026-09-15 10:30')
    & $add (D $o 'Commun\Politiques\Politique de mots de passe AB.pdf' pdf politique-mdp @{ } '2026-09-15 10:35' '2026-09-15 10:35')
    & $add (D $o 'Commun\Procédures\Procédure de sauvegarde.odt' odt note @{ Titre = 'Procédure de sauvegarde'; Puces = @('Les partages du serveur sont sauvegardés chaque nuit (Sauvegardes$)', 'Avant toute intervention sur un poste, copier les fichiers importants de l''utilisateur', 'Destination : \\AB-SRV-01\Sauvegardes$\<compte>\<AAAA-MM-JJ>', 'Seul le compte ab-tech peut écrire dans Sauvegardes$', 'Vérifier la copie (nombre de fichiers et empreintes) avant de toucher au poste') } '2025-09-08 10:00' '2026-03-11 15:20')
    & $add (D $o 'Commun\Procédures\Numéros d''urgence.odt' odt note @{ Titre = 'Numéros d''urgence'; Puces = @('Urgence : 911', 'Soutien informatique : 418 555-0199', 'Propriétaire de l''immeuble : 418 555-0120') } '2025-05-12 09:00' '2025-05-12 09:20')
    & $add (D $o 'Commun\Logo AB.png' png logo @{ } '2025-01-20 10:00' '2025-01-20 10:00')

    return $defs
}
