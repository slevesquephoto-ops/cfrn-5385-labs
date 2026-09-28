#requires -version 5.1
<#
.SYNOPSIS
    Produit les données fictives d'Architecture Boréale dans AB\data (une seule fois, puis commit).

.DESCRIPTION
    1. Sur l'hôte : sources de chaque fichier défini dans tools\ABData-Contenu.ps1 :
       HTML (odt, pdf, ott), CSV (ods), SVG (plans pdf); DXF et PNG produits directement.
       Fond d'écran AB : AB\data\communs\fond-AB.png.
    2. Dans une VM de poste qui a LibreOffice (uniquement par Invoke-LabVM.ps1) :
       conversion sans interface (soffice --headless --convert-to), Montserrat installée
       le temps de la conversion (facture et modèle).
    3. Retour sur l'hôte : fichiers dans AB\data\<proprio>\fichiers\ et manifeste
       AB\data\<proprio>\manifeste-<proprio>.csv (format GDF, « ; », UTF-8 avec BOM) :
       SourceRelative;TargetRelative;CreationTime;LastWriteTime;Criticality

.EXAMPLE
    .\tools\New-ABData.ps1 -VMName AB-PC-03-T
    .\tools\New-ABData.ps1 -SourcesSeulement      # étape 1 seulement, pour relire les sources
#>
[CmdletBinding()]
param(
    [ValidatePattern('^AB-PC-0[1-4]-T$')][string]$VMName = 'AB-PC-03-T',
    [string]$Checkpoint = 'Propre',
    [switch]$SourcesSeulement
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $Repo 'tests\Invoke-LabVM.ps1'
Import-Module (Join-Path $Repo 'common\Lab-Common.psm1') -Force
Import-Module (Join-Path $Repo 'AB\AB-Lab.psm1') -Force
. (Join-Path $PSScriptRoot 'ABData-Contenu.ps1')
. (Join-Path $PSScriptRoot 'ABData-Macro.ps1')
Add-Type -AssemblyName System.Drawing

$Build = Join-Path $env:TEMP 'abdata'
$Out = Join-Path $Build 'sortie'
$Fr = [Globalization.CultureInfo]'fr-CA'
$Utf8Bom = New-Object Text.UTF8Encoding($true)
$Utf8 = New-Object Text.UTF8Encoding($false)

# ---------------------------------------------------------------------------
# Personnes et en-tête
# ---------------------------------------------------------------------------
$Personnes = @{}
foreach ($e in (Get-ABConfig).Employes) { $Personnes[$e.Compte] = $e }
$Adresse = '48, rue des Érables, Pointe-Blanche (Québec)  G0L 9Z9  ·  418 555-0100  ·  info@architecture-boreale.example'

function Format-Money([double]$v) { $v.ToString('N2', $Fr) + ' $' }
function Esc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }

function New-Html([string]$Title, [string]$Body, [string]$Font = 'Liberation Sans') {
    # Police de la charte (Montserrat) : l'import HTML de LibreOffice respecte <font face>,
    # pas toujours le CSS; chaque bloc de texte reçoit donc sa balise (vérifié sur le modèle).
    if ($Font -ne 'Liberation Sans') {
        $Body = [regex]::Replace($Body, '(<(p|td|th|h1|h2|li)(\s[^>]*)?>)', "`$1<font face=`"$Font`">")
        $Body = [regex]::Replace($Body, '(</(p|td|th|h1|h2|li)>)', '</font>$1')
    }
    @"
<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>$(Esc $Title)</title>
<style>body{font-family:'$Font',Arial,sans-serif;font-size:11pt;color:#222} h1{font-size:16pt;color:#1d4e5f} h2{font-size:13pt;color:#1d4e5f}
.entete{border-bottom:2px solid #1d4e5f;margin-bottom:18pt} .entete b{font-size:15pt;color:#1d4e5f} .petit{font-size:8pt;color:#555}
table{border-collapse:collapse;width:100%} td,th{border:1px solid #999;padding:3pt 6pt;text-align:left} th{background:#dfe9ec}</style></head>
<body><div class="entete"><font face="$Font"><b>Architecture Boréale</b></font><br><span class="petit">$(Esc $Adresse)</span></div>
$Body
</body></html>
"@
}

function Get-HtmlBody($d) {
    $p = $d.P
    switch ($d.Modele) {
        'lettre' {
            $auteur = $Personnes[$p.De]
            $proj = ''
            if ($p.Projet) { $proj = "<p><b>Projet :</b> $(Esc $p.Projet.Code) $(Esc $p.Projet.Nom)</p>" }
            $corps = ($p.Corps | ForEach-Object { "<p>$(Esc $_)</p>" }) -join "`n"
            return "<p>Pointe-Blanche, le $(Esc $p.Date)</p><p>$(Esc $p.A)<br>$(Esc $p.Societe)</p><p><b>Objet : $(Esc $p.Objet)</b></p>$proj<p>Madame, Monsieur,</p>$corps<p>Veuillez agréer nos salutations distinguées.</p><p><br>$(Esc $auteur.NomComplet)<br>$(Esc $auteur.Role)<br>$($auteur.Compte)@architecture-boreale.example</p>"
        }
        'compte-rendu' {
            $pr = $p.Projet
            $points = @("Avancement : travaux conformes à l'échéancier révisé, sauf les points ci-dessous.", "Sécurité : rappel du port du harnais sur les quais et les toitures.", "Dessins d'atelier : en attente pour les garde-corps et les portes extérieures.", "Prochaine réunion : dans deux semaines, même heure.")
            return "<h1>Compte rendu de chantier</h1><p><b>Projet :</b> $(Esc $pr.Code) $(Esc $pr.Nom)<br><b>Date :</b> $(Esc $p.Date)<br><b>Entrepreneur :</b> $(Esc $pr.Entrepreneur)</p><p><b>Présents :</b> Émilie Fortin (AB), chargé de projet et surintendant ($(Esc $pr.Entrepreneur)), représentant du client</p><table><tr><th>No</th><th>Point</th><th>Responsable</th></tr>" +
                ((0..($points.Count - 1) | ForEach-Object { "<tr><td>$($_ + 1)</td><td>$(Esc $points[$_])</td><td>$(@('Entrepreneur','Entrepreneur','AB','AB')[$_])</td></tr>" }) -join '') + '</table>'
        }
        { $_ -in 'note', 'note-pdf' } { return "<h1>$(Esc $p.Titre)</h1><ul>" + (($p.Puces | ForEach-Object { "<li>$(Esc $_)</li>" }) -join '') + '</ul>' }
        'avis' { return "<h1>Avis de modification $(Esc $p.Numero)</h1><p><b>Projet :</b> $(Esc $p.Projet.Code) $(Esc $p.Projet.Nom)<br><b>Date :</b> $(Esc $p.Date)</p><h2>$(Esc $p.Objet)</h2><p>$(Esc $p.Detail)</p><p><b>Incidence sur le coût :</b> $(Format-Money $p.Montant) (avant taxes)</p><p>Émis par : Émilie Fortin, architecte</p>" }
        'contrat' {
            $pr = $p.Projet
            return "<h1>Contrat de services professionnels</h1><p><b>Entre :</b> $(Esc $pr.Client) (le client)<br><b>Et :</b> Architecture Boréale, représentée par Louis-Philippe Gauthier, architecte associé</p><p><b>Projet :</b> $(Esc $pr.Code) $(Esc $pr.Nom), $(Esc $pr.Adresse)</p><h2>1. Mandat</h2><p>Services d'architecture complets : esquisse, projet préliminaire, plans et devis, appel d'offres et surveillance des travaux.</p><h2>2. Honoraires</h2><p>Forfait de $(Format-Money ($pr.Budget * 0.085)) (avant taxes), facturé selon l'avancement des étapes.</p><h2>3. Signatures</h2><p>Signé à Pointe-Blanche, le $(Esc $p.Date).</p><p>__________________________ pour le client<br>__________________________ Louis-Philippe Gauthier, architecte</p>"
        }
        'evaluation' { return "<h1>Évaluation annuelle 2026 (confidentiel)</h1><p><b>Employé :</b> $(Esc $p.Nom)<br><b>Poste :</b> $(Esc $p.Poste)<br><b>Évaluateur :</b> Louis-Philippe Gauthier</p><table><tr><th>Critère</th><th>Appréciation</th></tr><tr><td>Qualité du travail</td><td>Dépasse les attentes</td></tr><tr><td>Respect des échéances</td><td>Répond aux attentes</td></tr><tr><td>Relations avec les clients</td><td>Dépasse les attentes</td></tr><tr><td>Objectif 2027</td><td>Formation sur la modélisation des données du bâtiment</td></tr></table>" }
        'agenda' { return "<h1>Agenda de Louis-Philippe : $(Esc $p.Mois)</h1><table><tr><th>Date</th><th>Rendez-vous</th></tr><tr><td>Lundi, 9 h</td><td>Réunion d'équipe</td></tr><tr><td>Mardi, 14 h</td><td>Chantier de la marina</td></tr><tr><td>Jeudi, 10 h</td><td>Coopérative de santé du Littoral</td></tr><tr><td>Vendredi, 13 h 30</td><td>Comptable</td></tr></table>" }
        'presentation' { return "<h1>$(Esc $p.Titre)</h1><p><i>$(Esc $p.Sous)</i></p>" + ((1..$p.Diapos.Count | ForEach-Object { "<h2>$_. $(Esc $p.Diapos[$_ - 1])</h2><p>Contenu de la diapositive $_.</p>" }) -join '') }
        'politique-mdp' {
            $pol = (Get-ABConfig).PolitiqueMotsDePasse
            return "<h1>Politique de mots de passe d'Architecture Boréale</h1><p>En vigueur le 15 septembre 2026. S'applique aux comptes de tous les employés, sur les postes et sur le serveur AB-SRV-01.</p><table><tr><th>Règle</th><th>Valeur</th></tr><tr><td>Longueur minimale</td><td>$($pol.LongueurMinimale) caractères</td></tr><tr><td>Complexité</td><td>Au moins trois types parmi : majuscules, minuscules, chiffres, symboles; ne doit pas contenir le nom du compte</td></tr><tr><td>Expiration</td><td>Aucune (pas de changement périodique)</td></tr><tr><td>Historique</td><td>Les $($pol.Historique) derniers mots de passe ne peuvent pas être réutilisés</td></tr><tr><td>Verrouillage</td><td>Désactivé sur le serveur; paramètres par défaut de Windows sur les postes</td></tr></table><h2>Réinitialisation</h2><p>Un mot de passe n'est réinitialisé qu'à la demande de l'employé, et le même mot de passe doit être en place sur son poste et sur le serveur. Le technicien confirme l'identité de l'employé avant toute réinitialisation.</p>"
        }
        'facture' {
            $rows = ''; $total = 0.0
            foreach ($l in $p.Lignes) { $rows += "<tr><td>$(Esc $l[0])</td><td style='text-align:right'>$(Format-Money $l[1])</td></tr>"; $total += $l[1] }
            $tps = [math]::Round($total * 0.05, 2); $tvq = [math]::Round($total * 0.09975, 2)
            $proj = ''
            if ($p['Projet']) { $proj = "<br><b>Projet :</b> $(Esc $p.Projet.Code) $(Esc $p.Projet.Nom)" }
            return "<h1>Facture $(Esc $p.Numero)</h1><p><b>Émise par :</b> $(Esc $p.Emetteur)<br><b>Client :</b> $(Esc $p.Client)$proj<br><b>Date :</b> $(Esc $p.Date)</p><table><tr><th>Description</th><th>Montant</th></tr>$rows<tr><td>TPS (5 %)</td><td style='text-align:right'>$(Format-Money $tps)</td></tr><tr><td>TVQ (9,975 %)</td><td style='text-align:right'>$(Format-Money $tvq)</td></tr><tr><th>Total</th><th style='text-align:right'>$(Format-Money ($total + $tps + $tvq))</th></tr></table><p class='petit'>Payable dans les 30 jours. TPS 000000000 RT0001 et TVQ 0000000000 TQ0001 (numéros fictifs).</p>"
        }
        'modele-facture' { return "<h1><font face='Montserrat'>FACTURE</font></h1><p><font face='Montserrat'><b>No :</b> 2026-0___<br><b>Date :</b> ____________<br><b>Client :</b> ______________________________<br><b>Projet :</b> ______________________________</font></p><table><tr><th><font face='Montserrat'>Description</font></th><th><font face='Montserrat'>Montant</font></th></tr><tr><td><font face='Montserrat'>Honoraires professionnels</font></td><td></td></tr><tr><td><font face='Montserrat'>Frais</font></td><td></td></tr><tr><td><font face='Montserrat'>TPS (5 %)</font></td><td></td></tr><tr><td><font face='Montserrat'>TVQ (9,975 %)</font></td><td></td></tr><tr><th><font face='Montserrat'>TOTAL</font></th><th></th></tr></table><p class='petit'><font face='Montserrat'>Payable dans les 30 jours. Merci de votre confiance.</font></p>" }
        default { throw "Gabarit HTML inconnu : $($d.Modele)" }
    }
}

# ---------------------------------------------------------------------------
# Tableaux (CSV « ; », nombres en notation anglaise, importés en fr-CA par LibreOffice)
# ---------------------------------------------------------------------------
function Get-CsvRow($d) {
    $p = $d.P
    switch ($d.Modele) {
        'devis' {
            $pr = $p.Projet; $b = [double]$pr.Budget
            $items = @(@('Organisation de chantier', 0.06), @('Fondations', 0.14), @('Structure', 0.21), @('Enveloppe', 0.18), @('Toiture', 0.08), @('Finitions intérieures', 0.12), @('Mécanique', 0.11), @('Électricité', 0.07), @('Aménagement extérieur', 0.03))
            $rows = @(, @('Poste', 'Description', 'Montant ($)'))
            $f = 1 + 0.015 * ($p.Revision - 1); $t = 0; $i = 0
            foreach ($it in $items) { $i++; $v = [math]::Round($b * $it[1] * $f, 0); $t += $v; $rows += , @("$i", $it[0], "$v") }
            $rows += , @('', "Total (révision $($p.Revision))", "$t")
            return , (@(, @("Devis estimatif : $($pr.Code) $($pr.Nom)", '', '')) + $rows)
        }
        'soumission' { return , @(@("Soumission $($p.Numero) : $($p.Projet)", '', ''), @('Client', $p.Client, ''), @('Étape', 'Pourcentage', 'Honoraires ($)'), @('Concept', '15', [string]([math]::Round($p.Honoraires * 0.15))), @('Plans préliminaires', '20', [string]([math]::Round($p.Honoraires * 0.20))), @('Plans et devis', '40', [string]([math]::Round($p.Honoraires * 0.40))), @('Appel d''offres', '5', [string]([math]::Round($p.Honoraires * 0.05))), @('Surveillance', '20', [string]([math]::Round($p.Honoraires * 0.20))), @('Total', '100', [string]$p.Honoraires)) }
        'budget' {
            $k = 1.0; if ($p['Reel']) { $k = 0.97 }
            $lines = @(@('Honoraires facturés', 780000), @('Salaires et charges', -452000), @('Loyer', -42000), @('Logiciels et informatique', -18500), @('Assurances professionnelles', -14200), @('Formation et congrès', -9800), @('Déplacements', -12600))
            $rows = @(@("Budget du cabinet $($p.Annee)", ''), @('Poste', 'Montant ($)')); $t = 0
            foreach ($l in $lines) { $v = [math]::Round($l[1] * $k); $t += $v; $rows += , @($l[0], "$v") }
            $rows += , @('Résultat', "$t"); return , $rows
        }
        'tresorerie' { return , @(@('Prévisions de trésorerie : T4 2026', '', '', ''), @('Mois', 'Encaissements', 'Décaissements', 'Solde'), @('Octobre', '68500', '52300', '16200'), @('Novembre', '71200', '51900', '35500'), @('Décembre', '54800', '63400', '26900')) }
        'honoraires' { return , @(@('Projet', 'Honoraires prévus', 'Facturé au 2026-09-18', 'Reste'), @('2026-014 Chalet du Lac-Boréal', '41225', '39100', '2125'), @('2026-017 Clinique du Littoral', '276250', '118400', '157850'), @('2026-021 Agrandissement Marina Pointe-Blanche', '158950', '87600', '71350')) }
        'deficiences' { return , @(@('No', 'Emplacement', 'Déficience', 'Statut'), @('1', 'Séjour', 'Retouche de peinture au plafond', 'Corrigée'), @('2', 'Chambre 2', 'Porte frotte au seuil', 'À corriger'), @('3', 'Terrasse', 'Garde-corps : vis manquantes', 'À corriger'), @('4', 'Salle de bain', 'Joint de silicone du bain', 'Corrigée'), @('5', 'Extérieur', 'Solin au-dessus de la porte d''entrée', 'À corriger')) }
        'feuille-temps' { return , @(@("Feuille de temps : $($p.Nom), $($p.Mois)", '', '', ''), @('Semaine', '2026-021 Marina', '2026-017 Clinique', '2026-014 Chalet'), @('1er au 5', '22', '10', '3'), @('8 au 12', '25', '8', '2'), @('15 au 19', '20', '12', '3'), @('22 au 26', '24', '9', '2')) }
        'frais' { return , @(@('Date', 'Déplacement', 'Km', 'Montant ($)'), @('2026-06-03', 'Chantier du chalet', '84', '48.72'), @('2026-08-13', 'Chantier de la marina', '46', '26.68'), @('2026-08-20', 'Chantier de la marina', '46', '26.68'), @('2026-09-17', 'Chantier de la marina', '46', '26.68')) }
        'tableau' { return , (@(, [string[]]$p.Colonnes) + @($p.Lignes | ForEach-Object { , [string[]]$_ })) }
        'comptes-clients' { return , @(@('Facture', 'Client', 'Date', 'Montant ($)', 'Payée'), @('2026-0135', 'Coopérative de santé du Littoral', '2026-06-01', '9163.48', 'Oui'), @('2026-0136', 'Municipalité de Pointe-Blanche', '2026-06-17', '9870.00', 'Oui'), @('2026-0137', 'Famille Tremblay-Roy', '2026-07-03', '4950.00', 'Oui'), @('2026-0138', 'Coopérative de santé du Littoral', '2026-07-19', '6215.40', 'Oui'), @('2026-0139', 'Municipalité de Pointe-Blanche', '2026-08-04', '11492.60', 'Non'), @('2026-0140', 'Famille Tremblay-Roy', '2026-08-20', '3680.20', 'Non'), @('2026-0141', 'Coopérative de santé du Littoral', '2026-08-15', '8841.75', 'Non (rappel envoyé)'), @('2026-0142', 'Municipalité de Pointe-Blanche', '2026-09-21', '12310.90', 'Non')) }
        'fournisseurs' { return , @(@('Fournisseur (fictif)', 'Service', 'Téléphone', 'Courriel'), @('Fournisseur CFRN', 'Soutien informatique', '418 555-0199', 'soutien@fournisseur-cfrn.example'), @('Bureautique du Fleuve', 'Photocopieur, traceur', '418 555-0131', 'service@bureautique-fleuve.example'), @('Reprographie Boréale', 'Impression de plans', '418 555-0144', 'plans@repro-boreale.example'), @('Ingénierie Littoral Conseil', 'Structure', '418 555-0163', 'kdionne@ilc.example'), @('Papeterie des Érables', 'Fournitures', '418 555-0152', 'commandes@papeterie-erables.example')) }
        'registre-factures' { return , @(@('Numéro', 'Date', 'Client', 'Projet', 'Montant avant taxes ($)', 'Statut'), @('2026-0135', '2026-06-01', 'Coopérative de santé du Littoral', '2026-017', '7970.00', 'Payée'), @('2026-0136', '2026-06-17', 'Municipalité de Pointe-Blanche', '2026-021', '8584.50', 'Payée'), @('2026-0137', '2026-07-03', 'Famille Tremblay-Roy', '2026-014', '4305.29', 'Payée'), @('2026-0138', '2026-07-19', 'Coopérative de santé du Littoral', '2026-017', '5406.00', 'Payée'), @('2026-0139', '2026-08-04', 'Municipalité de Pointe-Blanche', '2026-021', '9995.75', 'À recevoir'), @('2026-0140', '2026-08-20', 'Famille Tremblay-Roy', '2026-014', '3200.87', 'À recevoir'), @('2026-0141', '2026-08-15', 'Coopérative de santé du Littoral', '2026-017', '7690.15', 'En retard'), @('2026-0142', '2026-09-21', 'Municipalité de Pointe-Blanche', '2026-021', '10707.46', 'À recevoir')) }
        default { throw "Gabarit CSV inconnu : $($d.Modele)" }
    }
}

function ConvertTo-CsvText($rows) {
    ($rows | ForEach-Object { ($_ | ForEach-Object { '"' + ([string]$_).Replace('"', '""') + '"' }) -join ';' }) -join "`r`n"
}

# ---------------------------------------------------------------------------
# Géométrie des plans (unités : mm réels), rendue en SVG (PDF) ou en DXF
# ---------------------------------------------------------------------------
function Get-PlanGeometry([string]$Forme) {
    $g = New-Object System.Collections.Generic.List[object]
    function PLine([double]$x1, [double]$y1, [double]$x2, [double]$y2, $layer = 'A-MUR') { $g.Add(@{ K = 'L'; X1 = $x1; Y1 = $y1; X2 = $x2; Y2 = $y2; Layer = $layer }) }
    function PRect([double]$x, [double]$y, [double]$w, [double]$h, $layer = 'A-MUR') { PLine $x $y ($x + $w) $y $layer; PLine ($x + $w) $y ($x + $w) ($y + $h) $layer; PLine ($x + $w) ($y + $h) $x ($y + $h) $layer; PLine $x ($y + $h) $x $y $layer }
    function PCirc([double]$x, [double]$y, [double]$r, $layer = 'A-MUR') { $g.Add(@{ K = 'C'; X = $x; Y = $y; R = $r; Layer = $layer }) }
    function PText([double]$x, [double]$y, $t, [double]$h = 350, $layer = 'A-TEXTE') { $g.Add(@{ K = 'T'; X = $x; Y = $y; T = $t; H = $h; Layer = $layer }) }
    switch ($Forme) {
        'chalet' {
            PRect 0 0 14000 9000; PLine 6000 0 6000 9000; PLine 6000 4500 14000 4500; PLine 10000 4500 10000 9000
            PRect 6000 0 3000 2500 'A-MUR'
            PText 1500 4500 'Séjour'; PText 7000 1200 'Salle de bain'; PText 10500 2000 'Cuisine'; PText 6800 6700 'Chambre 1'; PText 10800 6700 'Chambre 2'
            foreach ($x in 1500, 3500) { PRect $x -150 1200 300 'A-FENETRE' }; PRect 11000 8850 1400 300 'A-FENETRE'
        }
        { $_ -in 'clinique', 'clinique2' } {
            PRect 0 0 36000 18000; PLine 0 8000 36000 8000; PLine 0 10000 36000 10000
            for ($i = 0; $i -lt 6; $i++) { PLine ($i * 6000) 0 ($i * 6000) 8000; PLine ($i * 6000) 10000 ($i * 6000) 18000 }
            $n = 0
            for ($i = 0; $i -lt 6; $i++) { $n++; PText ($i * 6000 + 1200) 4000 "Examen $n"; $n++; PText ($i * 6000 + 1200) 14000 "Examen $n" }
            PText 14000 8700 'Corridor'
            if ($Forme -eq 'clinique') { PText 1200 8700 'Accueil' 450 } else { PText 1200 8700 'Administration' 450 }
        }
        'marina' {
            PLine 0 12000 8000 13500 'A-SITE'; PLine 8000 13500 20000 13000 'A-SITE'; PLine 20000 13000 40000 14500 'A-SITE'
            PRect 4000 15000 16000 15000; PText 8000 22000 'Pavillon d''accueil' 600
            PRect 12000 1000 2400 11000 'A-QUAI'; for ($y = 2000; $y -lt 12000; $y += 1800) { PRect 14400 $y 6000 600 'A-QUAI'; PRect 6000 $y 6000 600 'A-QUAI' }
            PRect 24000 3000 2400 9500 'A-QUAI'; PText 27000 7000 'Quai flottant (36 emplacements)' 500
            PText 1000 11000 'Fleuve Saint-Laurent' 700
        }
        'elevation' {
            PLine -2000 0 22000 0 'A-SITE'; PRect 0 0 20000 6000; PLine 0 6000 10000 10000; PLine 10000 10000 20000 6000
            for ($x = 1500; $x -lt 20000; $x += 3500) { PRect $x 2000 1800 2200 'A-FENETRE' }
            PRect 9000 0 2000 3200 'A-PORTE'; PText 0 -1200 'Élévation principale' 500
        }
        'coupe' {
            PLine -1000 0 16000 0 'A-SITE'; PRect 0 -1500 15000 1500; PRect 0 0 400 6000; PRect 14600 0 400 6000; PLine 0 6000 7500 9500; PLine 7500 9500 15000 6000
            PLine 400 3000 14600 3000; PText 5000 1500 'Rez-de-chaussée'; PText 5000 4300 'Étage'; PText 16500 6000 'Toiture : membrane, isolant R-41'
        }
        'detail' {
            PLine -500 3000 12000 3000 'A-SITE'; PRect 0 2400 12000 600 'A-QUAI'
            for ($x = 1000; $x -le 11000; $x += 2500) { PCirc $x 1200 110 'A-QUAI'; PLine ($x - 110) 1200 ($x - 110) -3000 'A-QUAI'; PLine ($x + 110) 1200 ($x + 110) -3000 'A-QUAI' }
            PText 0 4200 'Détail : pieux d''acier galvanisé 219 mm (AM-04)' 400
        }
        default { PRect 0 0 10000 8000 }
    }
    return $g
}

function Get-PlanBound($g) {
    $xs = @(); $ys = @()
    foreach ($e in $g) {
        switch ($e.K) { 'L' { $xs += $e.X1, $e.X2; $ys += $e.Y1, $e.Y2 } 'C' { $xs += ($e.X - $e.R), ($e.X + $e.R); $ys += ($e.Y - $e.R), ($e.Y + $e.R) } 'T' { $xs += $e.X, ($e.X + $e.T.Length * $e.H * 0.6); $ys += $e.Y, ($e.Y + $e.H) } }
    }
    @{ MinX = ($xs | Measure-Object -Minimum).Minimum; MaxX = ($xs | Measure-Object -Maximum).Maximum; MinY = ($ys | Measure-Object -Minimum).Minimum; MaxY = ($ys | Measure-Object -Maximum).Maximum }
}

function New-PlanSvg($d) {
    $p = $d.P; $g = Get-PlanGeometry $p.Forme; $b = Get-PlanBound $g
    $W = 420; $H = 297; $zone = @{ X = 15; Y = 15; W = 390; H = 215 }
    $s = [math]::Min($zone.W / ($b.MaxX - $b.MinX), $zone.H / ($b.MaxY - $b.MinY))
    $tx = { param($x) [math]::Round($zone.X + ($x - $b.MinX) * $s, 2) }
    $ty = { param($y) [math]::Round($zone.Y + $zone.H - ($y - $b.MinY) * $s, 2) }
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append("<?xml version=""1.0"" encoding=""UTF-8""?>`n<svg xmlns=""http://www.w3.org/2000/svg"" width=""${W}mm"" height=""${H}mm"" viewBox=""0 0 $W $H"">`n<rect x=""0"" y=""0"" width=""$W"" height=""$H"" fill=""white""/>`n<rect x=""5"" y=""5"" width=""410"" height=""287"" fill=""none"" stroke=""black"" stroke-width=""0.7""/>`n")
    foreach ($e in $g) {
        $col = @{ 'A-MUR' = '#000'; 'A-FENETRE' = '#0a7ea4'; 'A-PORTE' = '#b8860b'; 'A-SITE' = '#2e7d32'; 'A-QUAI' = '#5d4037'; 'A-TEXTE' = '#000' }[$e.Layer]
        if (-not $col) { $col = '#000' }
        switch ($e.K) {
            'L' { [void]$sb.Append("<line x1=""$(& $tx $e.X1)"" y1=""$(& $ty $e.Y1)"" x2=""$(& $tx $e.X2)"" y2=""$(& $ty $e.Y2)"" stroke=""$col"" stroke-width=""0.5""/>`n") }
            'C' { [void]$sb.Append("<circle cx=""$(& $tx $e.X)"" cy=""$(& $ty $e.Y)"" r=""$([math]::Max(0.6, $e.R * $s))"" fill=""none"" stroke=""$col"" stroke-width=""0.4""/>`n") }
            'T' { [void]$sb.Append("<text x=""$(& $tx $e.X)"" y=""$(& $ty $e.Y)"" font-family=""Liberation Sans"" font-size=""$([math]::Max(2.5, [math]::Min(6, $e.H * $s)))"">$(Esc $e.T)</text>`n") }
        }
    }
    # Cartouche
    [void]$sb.Append("<rect x=""5"" y=""237"" width=""410"" height=""55"" fill=""#f4f8f9"" stroke=""black"" stroke-width=""0.5""/>`n")
    [void]$sb.Append("<text x=""10"" y=""250"" font-family=""Liberation Sans"" font-size=""7"" font-weight=""bold"" fill=""#1d4e5f"">Architecture Boréale</text>`n")
    [void]$sb.Append("<text x=""10"" y=""258"" font-family=""Liberation Sans"" font-size=""3.5"">$(Esc $Adresse)</text>`n")
    [void]$sb.Append("<text x=""10"" y=""270"" font-family=""Liberation Sans"" font-size=""5"">Projet : $(Esc $p.Projet.Code) $(Esc $p.Projet.Nom)</text>`n")
    [void]$sb.Append("<text x=""10"" y=""278"" font-family=""Liberation Sans"" font-size=""4"">Client : $(Esc $p.Projet.Client)</text>`n")
    [void]$sb.Append("<text x=""250"" y=""262"" font-family=""Liberation Sans"" font-size=""9"" font-weight=""bold"">$(Esc $p.Feuille)</text>`n")
    [void]$sb.Append("<text x=""250"" y=""274"" font-family=""Liberation Sans"" font-size=""5"">$(Esc $p.Titre)</text>`n")
    [void]$sb.Append("<text x=""250"" y=""284"" font-family=""Liberation Sans"" font-size=""4"">Révision $(Esc $p.Rev)  ·  Échelle : aucune (fictif)  ·  Dessiné : J. Bouchard  ·  Vérifié : É. Fortin</text>`n")
    [void]$sb.Append('</svg>')
    return $sb.ToString()
}

function New-Dxf($g, [string]$Titre) {
    $layers = @{ 'A-MUR' = 7; 'A-FENETRE' = 4; 'A-PORTE' = 2; 'A-SITE' = 3; 'A-QUAI' = 30; 'A-TEXTE' = 7; 'A-COTE' = 3 }
    $o = New-Object Text.StringBuilder
    function P([string]$code, $val) { [void]$o.Append("$code`r`n$val`r`n") }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    P 0 SECTION; P 2 HEADER; P 9 '$ACADVER'; P 1 AC1009; P 9 '$DWGCODEPAGE'; P 3 ANSI_1252; P 9 '$INSUNITS'; P 70 4; P 0 ENDSEC
    P 0 SECTION; P 2 TABLES
    P 0 TABLE; P 2 LTYPE; P 70 1; P 0 LTYPE; P 2 CONTINUOUS; P 70 0; P 3 'Solid line'; P 72 65; P 73 0; P 40 '0.0'; P 0 ENDTAB
    P 0 TABLE; P 2 LAYER; P 70 $layers.Count
    foreach ($k in $layers.Keys | Sort-Object) { P 0 LAYER; P 2 $k; P 70 0; P 62 $layers[$k]; P 6 CONTINUOUS }
    P 0 ENDTAB; P 0 ENDSEC
    P 0 SECTION; P 2 ENTITIES
    foreach ($e in $g) {
        switch ($e.K) {
            'L' { P 0 LINE; P 8 $e.Layer; P 10 ($e.X1.ToString($inv)); P 20 ($e.Y1.ToString($inv)); P 30 '0.0'; P 11 ($e.X2.ToString($inv)); P 21 ($e.Y2.ToString($inv)); P 31 '0.0' }
            'C' { P 0 CIRCLE; P 8 $e.Layer; P 10 ($e.X.ToString($inv)); P 20 ($e.Y.ToString($inv)); P 30 '0.0'; P 40 ($e.R.ToString($inv)) }
            'T' { P 0 TEXT; P 8 $e.Layer; P 10 ($e.X.ToString($inv)); P 20 ($e.Y.ToString($inv)); P 30 '0.0'; P 40 ($e.H.ToString($inv)); P 1 $e.T }
        }
    }
    if ($Titre) { P 0 TEXT; P 8 'A-TEXTE'; P 10 '0.0'; P 20 '-2500.0'; P 30 '0.0'; P 40 '500.0'; P 1 "Architecture Boréale - $Titre" }
    P 0 ENDSEC; P 0 EOF
    return $o.ToString()
}

function Get-SymbolGeometry([string]$Famille) {
    $g = New-Object System.Collections.Generic.List[object]
    function PLine([double]$x1, [double]$y1, [double]$x2, [double]$y2, $layer = 'A-MUR') { $g.Add(@{ K = 'L'; X1 = $x1; Y1 = $y1; X2 = $x2; Y2 = $y2; Layer = $layer }) }
    function PCirc([double]$x, [double]$y, [double]$r, $layer = 'A-MUR') { $g.Add(@{ K = 'C'; X = $x; Y = $y; R = $r; Layer = $layer }) }
    function PText([double]$x, [double]$y, $t, [double]$h = 120, $layer = 'A-TEXTE') { $g.Add(@{ K = 'T'; X = $x; Y = $y; T = $t; H = $h; Layer = $layer }) }
    switch ($Famille) {
        'portes' { foreach ($i in 0..3) { $x = $i * 1500; $w = 760 + $i * 50; PLine $x 0 ($x + $w) 0 'A-PORTE'; PLine $x 0 $x $w 'A-PORTE'; PText $x -300 "Porte $w" } ; foreach ($i in 0..2) { $x = $i * 2000; PLine $x 2000 ($x + 1200 + $i * 300) 2000 'A-FENETRE'; PLine $x 2100 ($x + 1200 + $i * 300) 2100 'A-FENETRE'; PText $x 2300 "Fenêtre $(1200 + $i * 300)" } }
        'mobilier' { PLine 0 0 1800 0; PLine 1800 0 1800 900; PLine 1800 900 0 900; PLine 0 900 0 0; PText 0 1000 'Bureau 1800 x 900'; PCirc 3000 450 450; PText 2600 1000 'Table ronde 900'; PLine 4500 0 6500 0; PLine 6500 0 6500 1500; PLine 6500 1500 4500 1500; PLine 4500 1500 4500 0; PText 4500 1600 'Lit double' }
        'cartouche' { PLine 0 0 18000 0; PLine 18000 0 18000 5500; PLine 18000 5500 0 5500; PLine 0 5500 0 0; PLine 12000 0 12000 5500; PText 300 4500 'Architecture Boréale' 600; PText 300 3500 'Projet :' 300; PText 300 2600 'Client :' 300; PText 12300 4300 'Feuille' 300; PText 12300 3000 'Révision' 300; PText 12300 1700 'Échelle' 300 }
        'annotations' { PLine 0 0 1500 0 'A-COTE'; PLine 1500 0 1300 100 'A-COTE'; PLine 1500 0 1300 -100 'A-COTE'; PText 0 200 'Flèche'; PCirc 3000 0 300 'A-COTE'; PText 2800 -60 'A1' 150; PLine 4500 0 6500 0 'A-COTE'; PLine 4500 -150 4500 150 'A-COTE'; PLine 6500 -150 6500 150 'A-COTE'; PText 5200 150 '2000' }
    }
    return $g
}

# ---------------------------------------------------------------------------
# Images (System.Drawing)
# ---------------------------------------------------------------------------
function Save-Png([System.Drawing.Bitmap]$Bmp, [string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $Bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png); $Bmp.Dispose()
}

function New-Gradient($G, $W, $H, $c1, $c2) {
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point(0, $H)), $c1, $c2)
    $G.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
}

function New-RenduPng([string]$Scene, [string]$Titre, [string]$Path) {
    $W = 1600; $H = 1000
    $bmp = New-Object System.Drawing.Bitmap($W, $H); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $C = { param($h) [System.Drawing.ColorTranslator]::FromHtml($h) }
    switch ($Scene) {
        'chalet-soir' { New-Gradient $g $W 620 (& $C '#2b1b4a') (& $C '#f28c38') }
        'texture' { New-Gradient $g $W $H (& $C '#1b1b1b') (& $C '#3a2a1e') }
        default { New-Gradient $g $W 620 (& $C '#6fa8dc') (& $C '#d9ecf7') }
    }
    if ($Scene -eq 'texture') {
        $pen = New-Object System.Drawing.Pen((& $C '#4a3626'), 6)
        for ($x = -1000; $x -lt $W; $x += 38) { $g.DrawLine($pen, $x, 0, $x + 900, $H) }
    } else {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((& $C '#2f5d50'))), 0, 600, $W, 400)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((& $C '#3d6f8f'))), 0, 760, $W, 240)
        $wall = New-Object System.Drawing.SolidBrush((& $C '#3b2f2a')); $glass = New-Object System.Drawing.SolidBrush((& $C '#f6d98b'))
        if ($Scene -like 'chalet*') { $g.FillRectangle($wall, 520, 400, 560, 230); $g.FillPolygon($wall, [System.Drawing.Point[]]@((New-Object System.Drawing.Point(480, 410)), (New-Object System.Drawing.Point(800, 230)), (New-Object System.Drawing.Point(1120, 410)))); $g.FillRectangle($glass, 600, 450, 400, 140) }
        elseif ($Scene -eq 'clinique') { $g.FillRectangle((New-Object System.Drawing.SolidBrush((& $C '#e8e4dc'))), 300, 330, 1000, 300); for ($x = 340; $x -lt 1280; $x += 120) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((& $C '#5b8fb0'))), $x, 380, 80, 90); $g.FillRectangle((New-Object System.Drawing.SolidBrush((& $C '#5b8fb0'))), $x, 500, 80, 90) } }
        else { $g.FillRectangle($wall, 560, 420, 480, 200); $g.FillRectangle($glass, 600, 460, 400, 110); $pen = New-Object System.Drawing.Pen((& $C '#8d6e63'), 10); for ($x = 150; $x -lt 1500; $x += 180) { $g.DrawLine($pen, $x, 800, $x, 960) }; $g.DrawLine($pen, 100, 800, 1500, 800) }
    }
    $f = New-Object System.Drawing.Font('Segoe UI', 18); $g.DrawString("Architecture Boréale  ·  $Titre  ·  rendu préliminaire", $f, [System.Drawing.Brushes]::White, 30, 950)
    $g.Dispose(); Save-Png $bmp $Path
}

function New-LogoPng([string]$Path, [int]$W = 800, [int]$H = 400, [switch]$Fond) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $C = { param($h) [System.Drawing.ColorTranslator]::FromHtml($h) }
    if ($Fond) { New-Gradient $g $W $H (& $C '#0b1f2a') (& $C '#1d4e5f') } else { $g.Clear([System.Drawing.Color]::White) }
    $s = $H / 400.0
    $aur = New-Object System.Drawing.Pen((& $C '#5ce1b0'), [float](10 * $s))
    $g.DrawBezier($aur, [float](60 * $s), [float](180 * $s), [float](200 * $s), [float](60 * $s), [float](360 * $s), [float](220 * $s), [float](520 * $s), [float](90 * $s))
    $mont = New-Object System.Drawing.SolidBrush((& $C '#1d4e5f')); if ($Fond) { $mont = New-Object System.Drawing.SolidBrush((& $C '#0e2f3b')) }
    $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float](60 * $s), [float](300 * $s))), (New-Object System.Drawing.PointF([float](200 * $s), [float](170 * $s))), (New-Object System.Drawing.PointF([float](290 * $s), [float](250 * $s))), (New-Object System.Drawing.PointF([float](380 * $s), [float](150 * $s))), (New-Object System.Drawing.PointF([float](540 * $s), [float](300 * $s))))
    $g.FillPolygon($mont, $pts)
    $txt = [System.Drawing.Brushes]::White; if (-not $Fond) { $txt = New-Object System.Drawing.SolidBrush((& $C '#1d4e5f')) }
    $g.DrawString('Architecture Boréale', (New-Object System.Drawing.Font('Segoe UI Semibold', [float](30 * $s))), $txt, [float](60 * $s), [float](315 * $s))
    $g.Dispose(); Save-Png $bmp $Path
}

# ---------------------------------------------------------------------------
# 1. Sources
# ---------------------------------------------------------------------------
function Get-OutRelative($d) {
    $t = $d.Cible
    if ($t -match '^([A-Za-z]):\\(.*)$') { $t = "$($Matches[1])\$($Matches[2])" }
    return "$($d.Proprietaire)\$t"
}

Write-LabStep 'Sources'
if (Test-Path $Build) { Remove-Item $Build -Recurse -Force }
New-Item -ItemType Directory -Path $Out -Force | Out-Null
$defs = Get-ABDataDefinition
$conv = @()
foreach ($d in $defs) {
    $rel = Get-OutRelative $d
    $final = Join-Path $Out $rel
    $dir = Split-Path -Parent $final
    $base = [IO.Path]::GetFileNameWithoutExtension($final)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    switch ($d.Type) {
        { $_ -in 'odt', 'ott' -or ($_ -eq 'pdf' -and $d.Modele -notin 'plan-pdf') } {
            # Charte d'AB : Montserrat pour le modèle et pour les factures émises par AB (R6-D)
            $font = 'Liberation Sans'
            if ($d.Modele -eq 'modele-facture' -or ($d.Modele -eq 'facture' -and $d.P.Emetteur -eq 'Architecture Boréale')) { $font = 'Montserrat' }
            $src = Join-Path $dir "$base.html"
            [IO.File]::WriteAllText($src, (New-Html -Title $base -Body (Get-HtmlBody $d) -Font $font), $Utf8)
            $filter = @{ odt = 'odt:writer8'; ott = 'ott:writer8_template'; pdf = 'pdf:writer_pdf_Export' }[$d.Type]
            $conv += [pscustomobject]@{ Source = "$(Split-Path -Parent $rel)\$base.html"; Filtre = $filter; InFiltre = 'HTML (StarWriter)'; Sortie = $rel }
        }
        'ods' {
            $src = Join-Path $dir "$base.csv"
            [IO.File]::WriteAllText($src, (ConvertTo-CsvText (Get-CsvRow $d)), $Utf8)
            $conv += [pscustomobject]@{ Source = "$(Split-Path -Parent $rel)\$base.csv"; Filtre = 'ods:calc8'; InFiltre = 'CSV:59,34,76,1,,1033'; Sortie = $rel }
        }
        { $_ -eq 'pdf' -and $d.Modele -eq 'plan-pdf' } {
            $src = Join-Path $dir "$base.svg"
            [IO.File]::WriteAllText($src, (New-PlanSvg $d), $Utf8)
            $conv += [pscustomobject]@{ Source = "$(Split-Path -Parent $rel)\$base.svg"; Filtre = 'pdf:draw_pdf_Export'; InFiltre = ''; Sortie = $rel }
        }
        'dxf' {
            if ($d.Modele -eq 'symboles-dxf') { $txt = New-Dxf (Get-SymbolGeometry $d.P.Famille) $base }
            else { $txt = New-Dxf (Get-PlanGeometry $d.P.Forme) "$($d.P.Projet.Code) $($d.P.Feuille) $($d.P.Titre)" }
            [IO.File]::WriteAllText($final, $txt, [Text.Encoding]::GetEncoding(1252))
        }
        'png' {
            if ($d.Modele -eq 'logo') { New-LogoPng -Path $final } else { New-RenduPng -Scene $d.P.Scene -Titre $d.P.Titre -Path $final }
        }
        default { throw "Type inconnu : $($d.Type)" }
    }
}
# Liste de conversion (UTF-8 avec BOM, lue par ABData-Convertir.ps1 dans la VM)
$lines = @('Source;Filtre;InFiltre;Sortie') + ($conv | ForEach-Object { "$($_.Source);$($_.Filtre);$($_.InFiltre);$($_.Sortie)" })
[IO.File]::WriteAllLines((Join-Path $Build 'conversions.csv'), $lines, $Utf8Bom)
Copy-Item (Join-Path $Repo 'AB\data\polices\Montserrat') (Join-Path $Build 'polices') -Recurse
$communs = Join-Path $Repo 'AB\data\communs'
New-Item -ItemType Directory -Force -Path $communs | Out-Null
New-LogoPng -Path (Join-Path $communs 'fond-AB.png') -W 1920 -H 1080 -Fond
Write-LabOK "$($defs.Count) fichiers définis, $($conv.Count) conversions LibreOffice, fond d'écran AB."
if ($SourcesSeulement) { Write-LabOK "Sources : $Build"; return }

# ---------------------------------------------------------------------------
# 2. Conversion dans la VM
# ---------------------------------------------------------------------------
Write-LabStep "Conversion dans $VMName"
& $Inv -VMName $VMName -Action Reset -Checkpoint $Checkpoint | Out-Null
& $Inv -VMName $VMName -Action Push -Path $Build, (Join-Path $PSScriptRoot 'ABData-Convertir.ps1') | Out-Null
& $Inv -VMName $VMName -Action Run -ScriptPath 'C:\Lab\ABData-Convertir.ps1' -ArgumentList '-Build', 'C:\Lab\abdata'
if ($LASTEXITCODE -ne 0) { throw "Conversion incomplète dans $VMName." }
$pulled = Join-Path $Repo "tests\logs\$VMName\sortie"
if (Test-Path $pulled) { Remove-Item $pulled -Recurse -Force }
& $Inv -VMName $VMName -Action Pull -Source 'C:\Lab\abdata\sortie' | Out-Null
& $Inv -VMName $VMName -Action Stop | Out-Null

# ---------------------------------------------------------------------------
# 3. AB\data et manifestes
# ---------------------------------------------------------------------------
Write-LabStep 'AB\data'
foreach ($owner in ($defs | Select-Object -ExpandProperty Proprietaire -Unique)) {
    $root = Join-Path $Repo "AB\data\$owner"
    if (Test-Path (Join-Path $root 'fichiers')) { Remove-Item (Join-Path $root 'fichiers') -Recurse -Force }
    $manifest = @('SourceRelative;TargetRelative;CreationTime;LastWriteTime;Criticality')
    foreach ($d in $defs | Where-Object { $_.Proprietaire -eq $owner }) {
        $rel = Get-OutRelative $d
        $src = Join-Path $pulled $rel
        if (-not (Test-Path -LiteralPath $src)) { throw "Fichier non produit : $rel" }
        $inner = $rel.Substring($owner.Length + 1)
        $dst = Join-Path $root "fichiers\$inner"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
        # Modèle de facture : macro de numérotation automatique (R6-E)
        if ($d.Modele -eq 'modele-facture') { Add-ABTemplateMacro -Path $dst }
        $manifest +="fichiers\$inner;$($d.Cible);$($d.Cree.ToString('yyyy-MM-dd HH:mm:ss'));$($d.Modifie.ToString('yyyy-MM-dd HH:mm:ss'));$($d.Criticite)"
    }
    [IO.File]::WriteAllLines((Join-Path $root "manifeste-$owner.csv"), $manifest, $Utf8Bom)
    Write-LabOK "$owner : $($manifest.Count - 1) fichiers"
}
