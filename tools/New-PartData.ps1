#requires -version 5.1
<#
.SYNOPSIS
    Génère les données d'un client particulier (fichiers légers + manifeste), committées dans
    Particuliers/data/<compte>/. Copiées ensuite dans le profil par Copy-PartMissingData.

.DESCRIPTION
    Contenu réaliste et inoffensif (recettes, lettres, budget, photos d'espace réservé). Aucune
    dépendance LibreOffice : textes simples et images générées (System.Drawing). Le manifeste a
    les colonnes SourceRelative;TargetRelative;CreationTime;LastWriteTime (format AB), lues par
    Copy-PartMissingData. Les photos sont des images d'espace réservé (dégradé + légende), pas de
    vraies personnes. Relancer écrase proprement le dossier du client.

.EXAMPLE
    .\tools\New-PartData.ps1 -Compte mbelanger
#>
[CmdletBinding()]
param([string]$Compte = 'mbelanger')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$RepoRoot = Split-Path -Parent $PSScriptRoot
$DataRoot = Join-Path $RepoRoot "Particuliers\data\$Compte"

function Write-Utf8([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Path, ($Text -replace "`r?`n", "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
}

function New-PlaceholderPhoto {
    # Image d'espace réservé : dégradé + légende centrée. Aucune personne réelle.
    param([string]$Path, [string]$Legende, [System.Drawing.Color]$C1, [System.Drawing.Color]$C2)
    $w = 1280; $h = 853
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $C1, $C2, 45.0
    $g.FillRectangle($brush, $rect)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $font = New-Object System.Drawing.Font 'Segoe UI', 46, ([System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 0, 0, 0))
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.DrawString($Legende, $font, $shadow, (New-Object System.Drawing.RectangleF 3, 3, $w, $h), $sf)
    $g.DrawString($Legende, $font, $white, (New-Object System.Drawing.RectangleF 0, 0, $w, $h), $sf)
    $g.Dispose()
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $bmp.Dispose()
}

# --- Jeux de données par client -------------------------------------------------
$sets = @{
    mbelanger = {
        $textes = @(
            @{ S = 'Recettes\tarte-aux-pommes.txt'; T = 'Documents\Recettes\tarte-aux-pommes.txt'; C = '2023-09-14'; M = '2024-10-02'
               X = "TARTE AUX POMMES DE GRAND-MAMAN`n`nPâte :`n- 2 tasses de farine`n- 1 tasse de beurre froid`n- 1 pincée de sel`n- eau glacée`n`nGarniture :`n- 6 pommes Cortland`n- 3/4 tasse de sucre`n- 1 c. à thé de cannelle`n`nCuire à 375°F environ 45 minutes." }
            @{ S = 'Recettes\pouding-chomeur.txt'; T = 'Documents\Recettes\pouding-chomeur.txt'; C = '2023-11-03'; M = '2023-11-03'
               X = "POUDING CHÔMEUR`n`nGâteau :`n- 1 tasse de farine`n- 1 tasse de sucre`n- 1 c. à thé de poudre à pâte`n- 1/2 tasse de lait`n`nSirop :`n- 2 tasses de cassonade`n- 1 1/2 tasse d'eau bouillante`n- 1/4 tasse de beurre`n`nVerser le sirop chaud sur la pâte, cuire à 350°F 35 min." }
            @{ S = 'Recettes\soupe-aux-pois.txt'; T = 'Documents\Recettes\soupe-aux-pois.txt'; C = '2024-01-20'; M = '2024-02-11'
               X = "SOUPE AUX POIS`n`n- 2 tasses de pois jaunes secs`n- 1 oignon`n- 2 carottes`n- un morceau de lard salé`n- herbes salées`n`nMijoter 2 à 3 heures." }
            @{ S = 'Recettes\sauce-a-spaghetti.txt'; T = 'Documents\Recettes\sauce-a-spaghetti.txt'; C = '2024-03-05'; M = '2024-09-28'
               X = "SAUCE À SPAGHETTI`n`n- 1 lb boeuf haché`n- 2 boîtes de tomates`n- 1 oignon, 2 gousses d'ail`n- 1 branche de céleri`n- origan, basilic`n`nMijoter au moins 1 heure. En congeler la moitié." }
            @{ S = 'Recettes\pain-aux-bananes.txt'; T = 'Documents\Recettes\pain-aux-bananes.txt'; C = '2024-05-18'; M = '2024-05-18'
               X = "PAIN AUX BANANES`n`n- 3 bananes très mûres`n- 1/2 tasse de beurre`n- 1 tasse de sucre`n- 2 oeufs`n- 1 1/2 tasse de farine`n- 1 c. à thé de bicarbonate`n`nCuire à 350°F 55 à 60 minutes." }
            @{ S = 'Lettres\lettre-a-ma-soeur.txt'; T = 'Documents\Lettres\lettre-a-ma-soeur.txt'; C = '2024-06-22'; M = '2024-06-22'
               X = "Ma chère Jeanne,`n`nJ'espère que tu vas bien depuis notre dernier appel. Ici tout va bien, le jardin donne beaucoup de tomates cette année. Les petits sont venus au chalet la fin de semaine passée, quel bonheur.`n`nJe t'embrasse,`nMonique" }
            @{ S = 'Lettres\note-rendez-vous.txt'; T = 'Documents\Lettres\note-rendez-vous.txt'; C = '2025-01-09'; M = '2025-01-09'
               X = "Rendez-vous`n`n- Dr Tremblay : 14 février, 10h30`n- Optométriste : 3 mars, 9h00`n- Pharmacie : renouveler la prescription avant le 20 février" }
            @{ S = 'budget-mensuel.csv'; T = 'Documents\budget-mensuel.csv'; C = '2025-01-02'; M = '2025-02-01'
               X = "Poste;Montant`nLoyer;825`nÉpicerie;340`nÉlectricité;95`nTéléphone;48`nInternet;55`nMédicaments;40`nLoisirs;60`nÉpargne;100" }
            @{ S = 'liste-epicerie.txt'; T = 'Documents\liste-epicerie.txt'; C = '2025-02-15'; M = '2025-02-15'
               X = "Épicerie`n`n- lait`n- oeufs`n- pain`n- pommes`n- café`n- fromage`n- papier essuie-tout" }
            @{ S = 'numeros-importants.txt'; T = 'Documents\numeros-importants.txt'; C = '2023-08-01'; M = '2024-12-10'
               X = "Numéros importants`n`n- Pierre (fils) : 418-555-0142`n- Clinique médicale : 418-555-0190`n- Pharmacie : 418-555-0177`n- Voisine Lise : 418-555-0133" }
        )
        $photos = @(
            @{ S = 'Photos\noel-2023.jpg'; T = 'Pictures\noel-2023.jpg'; C = '2023-12-25'; M = '2023-12-25'; L = 'Noël 2023'; A = 'Firebrick'; B = 'DarkGreen' }
            @{ S = 'Photos\jardin.jpg'; T = 'Pictures\jardin.jpg'; C = '2024-07-11'; M = '2024-07-11'; L = 'Mon jardin'; A = 'YellowGreen'; B = 'SeaGreen' }
            @{ S = 'Photos\chalet-ete.jpg'; T = 'Pictures\chalet-ete.jpg'; C = '2024-08-03'; M = '2024-08-03'; L = 'Chalet, été 2024'; A = 'SkyBlue'; B = 'SteelBlue' }
            @{ S = 'Photos\petits-enfants.jpg'; T = 'Pictures\petits-enfants.jpg'; C = '2024-10-14'; M = '2024-10-14'; L = 'Les petits-enfants'; A = 'Orange'; B = 'Crimson' }
        )
        @{ Textes = $textes; Photos = $photos }
    }

    jblais = {
        $textes = @(
            @{ S = 'Trucs\tweaks-registre.txt'; T = 'Documents\Trucs\tweaks-registre.txt'; C = '2024-11-02'; M = '2025-02-20'
               X = "MES TWEAKS DE REGISTRE (a garder!)`n`n- Afficher les extensions de fichiers : HideFileExt = 0`n- Menu demarrer classique : essaye plusieurs cles, pas sur que ca marche`n- Desactiver la telemetrie : touche plein de trucs dans Policies`n- Accelerer le menu : MenuShowDelay = 0`n`nATTENTION : noter ce que je change AVANT, sinon je m'y retrouve plus..." }
            @{ S = 'Trucs\notes-overclock.txt'; T = 'Documents\Trucs\notes-overclock.txt'; C = '2024-12-10'; M = '2024-12-10'
               X = "Overclock / performance`n`n- Mode haute performance dans les options d'alimentation`n- Desactiver les effets visuels (SystemPropertiesPerformance)`n- Jouer dans msconfig > Demarrer (j'ai peut-etre trop coche de choses)`n- Memoire max dans msconfig : a NE PAS toucher, ca a deja mal tourne" }
            @{ S = 'Trucs\commandes-utiles.txt'; T = 'Documents\Trucs\commandes-utiles.txt'; C = '2025-01-15'; M = '2025-01-15'
               X = "Commandes que j'utilise`n`n- sfc /scannow (repare les fichiers systeme)`n- ipconfig /flushdns`n- chkdsk`n- services.msc (pour activer/desactiver des services)`n- regedit`n- msconfig`n- bcdedit (dangereux parait-il)" }
            @{ S = 'Trucs\raccourcis-clavier.txt'; T = 'Documents\Trucs\raccourcis-clavier.txt'; C = '2024-10-05'; M = '2024-10-05'
               X = "Raccourcis pratiques`n`n- Win + R : executer`n- Win + X : menu systeme`n- Ctrl + Maj + Echap : gestionnaire des taches`n- Win + Pause : infos systeme" }
            @{ S = 'a-reparer.txt'; T = 'Documents\a-reparer.txt'; C = '2025-02-18'; M = '2025-03-01'
               X = "CHOSES QUE J'AI BRISEES (a reparer quand j'aurai le temps)`n`n1. Le son ne marche plus depuis que j'ai joue dans les services.`n2. Le demarrage est super lent, j'ai mis plein d'affaires au demarrage.`n3. Une de mes modifs a bloque le panneau de configuration je pense.`n4. J'ai change un truc de reseau, des fois ca marche pas.`n`nNote a moi-meme : ARRETER de tout changer sans noter avant !!!" }
            @{ S = 'liste-logiciels.txt'; T = 'Documents\liste-logiciels.txt'; C = '2024-09-20'; M = '2025-01-30'
               X = "Logiciels installes`n`n- WinTweaker (optimisation)`n- GameBooster FX`n- Benchmark Studio`n- LibreOffice`n- Edge`n`nA essayer : un autre nettoyeur, un gestionnaire de demarrage" }
            @{ S = 'Downloads\wintweaker-lisezmoi.txt'; T = 'Downloads\wintweaker-lisezmoi.txt'; C = '2024-09-20'; M = '2024-09-20'
               X = "WinTweaker 5.0 - Lisez-moi`n`nOptimisez votre PC en un clic ! Nettoie, accelere, booste.`n(Fichier de laboratoire - logiciel fictif, aucune fonction reelle.)" }
            @{ S = 'Downloads\guide-boost-fps.txt'; T = 'Downloads\guide-boost-fps.txt'; C = '2024-12-01'; M = '2024-12-01'
               X = "Guide : plus de FPS dans mes jeux`n`n1. Mode haute performance`n2. Fermer les applis en arriere-plan`n3. Mettre a jour les pilotes`n4. Baisser les details graphiques`n(Trouve sur un forum, pas tout teste.)" }
            @{ S = 'Downloads\autoruns-notes.txt'; T = 'Downloads\autoruns-notes.txt'; C = '2025-01-22'; M = '2025-01-22'
               X = "Notes sur Autoruns`n`nOutil qui montre TOUT ce qui demarre avec Windows (plus complet que le gestionnaire des taches). Pratique pour voir ce que j'ai ajoute... et retirer." }
        )
        $photos = @(
            @{ S = 'Captures\benchmark.jpg'; T = 'Pictures\benchmark.jpg'; C = '2024-12-11'; M = '2024-12-11'; L = 'Benchmark avant/apres'; A = 'MidnightBlue'; B = 'DarkCyan' }
            @{ S = 'Captures\mon-setup.jpg'; T = 'Pictures\mon-setup.jpg'; C = '2025-01-05'; M = '2025-01-05'; L = 'Mon setup'; A = 'Indigo'; B = 'DeepPink' }
        )
        @{ Textes = $textes; Photos = $photos }
    }

    bdionne = {
        $textes = @(
            @{ S = 'Bateau\immatriculation.txt'; T = 'Documents\Bateau\immatriculation.txt'; C = '2022-04-12'; M = '2022-04-12'
               X = "IMMATRICULATION DU BATEAU`n`nNom : Le Grand Large`nNumero : QC-4821-AB`nLongueur : 8,5 m`nAnnee : 2016`nPort d'attache : Rimouski`n`n(Renouveler l'immatriculation avant le 30 avril chaque annee.)" }
            @{ S = 'Bateau\permis-peche.txt'; T = 'Documents\Bateau\permis-peche.txt'; C = '2023-03-01'; M = '2025-02-28'
               X = "PERMIS DE PECHE`n`nTitulaire : Benoit Dionne`nType : peche cotiere`nEspeces : maquereau, hareng`nValide jusqu'au : 31 mars`n`nGarder une copie a bord en tout temps." }
            @{ S = 'Bateau\assurance-bateau.txt'; T = 'Documents\Bateau\assurance-bateau.txt'; C = '2024-05-10'; M = '2024-05-10'
               X = "ASSURANCE DU BATEAU`n`nAssureur : Assurances Maritimes du Golfe`nPolice : MAR-55210`nCouverture : collision, incendie, vol`nRenouvellement : 10 mai`nTelephone : 418-555-0150" }
            @{ S = 'depenses-carburant.csv'; T = 'Documents\depenses-carburant.csv'; C = '2025-01-05'; M = '2025-03-02'
               X = "Date;Litres;Montant`n2025-01-08;120;198`n2025-01-22;140;231`n2025-02-05;110;182`n2025-02-19;150;248`n2025-03-01;130;215" }
            @{ S = 'contacts-port.txt'; T = 'Documents\contacts-port.txt'; C = '2023-06-15'; M = '2024-11-20'
               X = "Contacts`n`n- Capitainerie du port : 418-555-0160`n- Mecanicien (moteur) : 418-555-0171`n- Poissonnerie (acheteur) : 418-555-0182`n- Marc (mon fils) : 418-555-0199`n- Garde cotiere (urgence) : 1-800-565-1582" }
            @{ S = 'liste-equipement.txt'; T = 'Documents\liste-equipement.txt'; C = '2024-04-02'; M = '2024-04-02'
               X = "Equipement a verifier avant la saison`n`n- Gilets de sauvetage (x4)`n- Fusees de detresse`n- Radio VHF`n- GPS / sondeur`n- Pompe de cale`n- Trousse de premiers soins`n- Ancre et cordages" }
        )
        $photos = @(
            @{ S = 'Photos\mon-bateau.jpg'; T = 'Pictures\mon-bateau.jpg'; C = '2024-06-20'; M = '2024-06-20'; L = 'Le Grand Large'; A = 'Navy'; B = 'CadetBlue' }
            @{ S = 'Photos\prise-du-jour.jpg'; T = 'Pictures\prise-du-jour.jpg'; C = '2024-07-15'; M = '2024-07-15'; L = 'La prise du jour'; A = 'Teal'; B = 'SlateGray' }
            @{ S = 'Photos\quai-matin.jpg'; T = 'Pictures\quai-matin.jpg'; C = '2024-08-09'; M = '2024-08-09'; L = 'Le quai au matin'; A = 'DarkSlateBlue'; B = 'LightSteelBlue' }
        )
        @{ Textes = $textes; Photos = $photos }
    }
}

if (-not $sets.ContainsKey($Compte)) { throw "Aucun jeu de données défini pour '$Compte'. Clients connus : $(($sets.Keys) -join ', ')." }

if (Test-Path -LiteralPath $DataRoot) { Remove-Item -LiteralPath $DataRoot -Recurse -Force }
New-Item -ItemType Directory -Path $DataRoot -Force | Out-Null

$data = & $sets[$Compte]
$manifest = @('SourceRelative;TargetRelative;CreationTime;LastWriteTime')

foreach ($t in $data.Textes) {
    Write-Utf8 (Join-Path $DataRoot $t.S) $t.X
    $manifest += "$($t.S);$($t.T);$($t.C);$($t.M)"
}
foreach ($p in $data.Photos) {
    New-PlaceholderPhoto -Path (Join-Path $DataRoot $p.S) -Legende $p.L -C1 ([System.Drawing.Color]::FromName($p.A)) -C2 ([System.Drawing.Color]::FromName($p.B))
    $manifest += "$($p.S);$($p.T);$($p.C);$($p.M)"
}

$manPath = Join-Path $DataRoot "manifeste-$Compte.csv"
[IO.File]::WriteAllText($manPath, (($manifest -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

Write-Host "[OK] $Compte : $($data.Textes.Count) textes + $($data.Photos.Count) photos -> $DataRoot"
Write-Host "[OK] Manifeste : $manPath"
