@{
    # =======================================================================
    # Architecture Boréale : configuration unique (source : AB/SPEC.md).
    # Lue par AB/AB-Lab.psm1 (Get-ABConfig). Les mots de passe LAB sont
    # fictifs et documentés dans les README-Installation.txt du dépôt.
    # Le mot de passe de ab-tech n'est PAS ici : il reste dans ~/.lab.
    # =======================================================================

    Entreprise = @{
        Nom         = 'Architecture Boréale'
        Abreviation = 'AB'
        Domaine     = 'architecture-boreale.example'
    }

    Reseau = @{
        Prefixe    = 24
        Passerelle = '192.168.50.1'
        Dns        = @('192.168.50.1')
        Machines   = @{
            'SRV-01' = '192.168.50.10'
            'PC-01'  = '192.168.50.21'
            'PC-02'  = '192.168.50.22'
            'PC-03'  = '192.168.50.23'
            'PC-04'  = '192.168.50.24'
        }
    }

    Administrateur = 'ab-tech'

    Employes = @(
        @{ Compte = 'lpgauthier'; NomComplet = 'Louis-Philippe Gauthier'; Role = 'Architecte associé, propriétaire';    Poste = 'PC-02'; MotDePasse = 'Loui!sAB-2026' }
        @{ Compte = 'efortin';    NomComplet = 'Émilie Fortin';           Role = 'Architecte de projets';               Poste = 'PC-03'; MotDePasse = 'Emil!ieAB-2026' }
        @{ Compte = 'jbouchard';  NomComplet = 'Jérémie Bouchard';        Role = 'Technicien en architecture (dessin)'; Poste = 'PC-04'; MotDePasse = 'Jere!mieAB-2026' }
        @{ Compte = 'ncote';      NomComplet = 'Nathalie Côté';           Role = 'Adjointe administrative, réception';  Poste = 'PC-01'; MotDePasse = 'Nath!alieAB-2026' }
    )

    Groupes = @{
        'AB-Direction'      = @('lpgauthier')
        'AB-Conception'     = @('lpgauthier', 'efortin', 'jbouchard')
        'AB-Administration' = @('ncote')
        'AB-Tous'           = @('lpgauthier', 'efortin', 'jbouchard', 'ncote')
    }

    # Droits NTFS à la racine de chaque partage : Modification ou Lecture.
    # Administrateurs et SYSTEM : Contrôle total partout (ajoutés par le Setup).
    Partages = @(
        @{ Nom = 'Projets';        Dossier = 'C:\AB\Projets';        Lecteur = 'P'; Droits = @{ 'AB-Direction' = 'Modification'; 'AB-Conception' = 'Modification'; 'AB-Administration' = 'Lecture' } }
        @{ Nom = 'Administration'; Dossier = 'C:\AB\Administration'; Lecteur = 'T'; Droits = @{ 'AB-Direction' = 'Modification'; 'AB-Administration' = 'Modification' } }
        @{ Nom = 'Direction$';     Dossier = 'C:\AB\Direction';      Lecteur = '';  Droits = @{ 'AB-Direction' = 'Modification' } }
        @{ Nom = 'Archives';       Dossier = 'C:\AB\Archives';       Lecteur = 'R'; Droits = @{ 'AB-Direction' = 'Modification'; 'AB-Conception' = 'Lecture'; 'AB-Administration' = 'Lecture' } }
        @{ Nom = 'Commun';         Dossier = 'C:\AB\Commun';         Lecteur = 'S'; Droits = @{ 'AB-Tous' = 'Modification' } }
        # ab-tech explicite : par le réseau, son jeton d'administrateur local est filtré (UAC).
        @{ Nom = 'Sauvegardes$';   Dossier = 'C:\AB\Sauvegardes';    Lecteur = '';  Droits = @{ 'ab-tech' = 'Modification' } }
        # Source MSI de LibreOffice (R6-C) : LibreOffice\<installeur>, copié par Setup-SRV-01.
        @{ Nom = 'Logiciels$';     Dossier = 'C:\AB\Logiciels';      Lecteur = '';  Droits = @{ 'AB-Tous' = 'Lecture' } }
    )

    # Politique de mots de passe AB (stratégie de sécurité locale).
    # Verrouillage : 0 = désactivé (SRV-01, décision R1); absent = défaut Windows (postes).
    PolitiqueMotsDePasse = @{
        LongueurMinimale = 12
        Complexite       = 1
        Historique       = 5
        Verrouillage     = @{ 'SRV-01' = 0 }
    }

    Pannes = @{
        R1 = @{
            Compte              = 'efortin'
            MotDePassePanne     = 'Marina#Direction26'
            DossierProjet       = '2026-021'
        }
    }

    # Verrouillage de la version de Windows (les mises à jour de sécurité restent actives).
    # Version par machine : le vrai HP (SRV-01) est en 25H2, les M700 en 24H2.
    WindowsUpdate = @{
        ProductVersion = 'Windows 11'
        Version        = @{
            'SRV-01' = '25H2'
            'PC-01'  = '24H2'
            'PC-02'  = '24H2'
            'PC-03'  = '24H2'
            'PC-04'  = '24H2'
        }
    }

    # -----------------------------------------------------------------------
    # Logiciels (installés une seule fois avant le point Propre).
    #   Actif      : $false retire le logiciel de toutes les installations et vérifications.
    #   WingetCustom : arguments AJOUTÉS aux arguments silencieux du manifeste (--custom).
    #   WingetScope  : 'machine' pour imposer --scope machine (FreeCAD s'installe sinon par
    #                utilisateur). Pas par défaut : winget 1.6 rejette alors les manifestes
    #                sans portée déclarée (Blender).
    #                Pas de --override ni de --installer-type : winget 1.6 choisit parfois un autre
    #                installeur (EXE de 7-Zip au lieu du MSI) et applique le type aux dépendances
    #                (VCRedist), vérifié en VM.
    #   Winget     : $false = jamais par winget (installeur non silencieux).
    #   Pas de REMOVE=... dans les arguments d'un MSI : dès qu'une propriété de sélection
    #   de fonctions est présente, MSI n'installe plus la sélection par défaut (installation
    #   « réussie » de rien du tout, vérifié en VM). La vérification des mises à jour de
    #   LibreOffice est retirée APRÈS l'installation (Disable-ABLibreOfficeUpdate).
    #   Detection  : expression régulière sur le DisplayName (clés Uninstall de HKLM).
    #   Arguments  : arguments silencieux de la méthode Local. Pour un MSI : ce qui suit « msiexec /i <fichier> ».
    #                {LOG} est remplacé par un fichier journal.
    #   Fichier    : nom de l'installeur dans tools\installeurs (méthode Local).
    #   Raccourcis : raccourcis du Bureau public à retirer après l'installation.
    # -----------------------------------------------------------------------
    Logiciels = @(
        @{
            Nom        = 'LibreOffice'
            Actif      = $true
            Postes     = @('PC-01', 'PC-02', 'PC-03', 'PC-04')
            WingetId   = 'TheDocumentFoundation.LibreOffice'
            # Jamais par winget : winget efface l'installeur, or MSI exige la source pour
            # retirer la fonction de mise à jour et pour réparer (R6-C), vérifié en VM.
            Winget     = $false
            Version    = '26.8.0.3'
            Type       = 'msi'
            Detection  = '^LibreOffice [\d.]+$'
            Arguments  = '/qn /norestart ALLUSERS=1 ISCHECKFORPRODUCTUPDATES=0 QUICKSTART=0 CREATEDESKTOPLINK=0 RebootYesNo=No SOURCELIST=\\AB-SRV-01\Logiciels$\LibreOffice /l*v "{LOG}"'
            Url        = 'https://download.documentfoundation.org/libreoffice/stable/26.8.0/win/x86_64/LibreOffice_26.8.0_Win_x86-64.msi'
            Sha256     = '4aa6c6e1895f4055104effcb556bd3362d20c6ad707c149543304f395ef9db95'
            Fichier    = 'LibreOffice_26.8.0_Win_x86-64.msi'
            Raccourcis = @('LibreOffice*.lnk')
            # Copié par Setup-SRV-01 dans C:\AB\Logiciels\<DossierServeur> (source de réparation, R6-C)
            DossierServeur = 'LibreOffice'
        }
        @{
            Nom        = 'Adobe Acrobat Reader'
            Actif      = $true
            Postes     = @('PC-01', 'PC-02', 'PC-03', 'PC-04')
            WingetId   = 'Adobe.Acrobat.Reader.64-bit'
            Version    = '26.002.21931'
            Type       = 'exe'
            Detection  = '^Adobe Acrobat'
            Arguments  = '/sAll /rs /msi EULA_ACCEPT=YES /l*v "{LOG}"'
            Url        = 'https://ardownload3.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2600221931/AcroRdrDCx642600221931_MUI.exe'
            Sha256     = 'd5f1db0c2f685c54e8e968ee20358dd8ac90cde76c3ecbe52257ba27b03761d7'
            Fichier    = 'AcroRdrDCx642600221931_MUI.exe'
            Raccourcis = @('Adobe Acrobat*.lnk', 'Acrobat Reader*.lnk')
        }
        @{
            Nom        = '7-Zip'
            Actif      = $true
            Postes     = @('PC-01', 'PC-02', 'PC-03', 'PC-04')
            WingetId   = '7zip.7zip'
            Version    = '26.03'
            Type       = 'msi'
            Detection  = '^7-Zip'
            Arguments  = '/qn /norestart ALLUSERS=1 /l*v "{LOG}"'
            Url        = 'https://www.7-zip.org/a/7z2603-x64.msi'
            Sha256     = 'c0680064d698a62dd4a5a47f403db356a6531a5473e4c4b1d090ea2590513926'
            Fichier    = '7z2603-x64.msi'
            Raccourcis = @()
        }
        @{
            # Installeur complet hors ligne à déposer à la main dans tools\installeurs\DWGTrueView2027\
            # (le paquet winget n'est qu'une amorce web graphique). Actif = $false pour le retirer.
            Nom        = 'Autodesk DWG TrueView 2027'
            Actif      = $false   # retiré (spec) : installeur hors ligne non disponible
            Postes     = @('PC-02', 'PC-03', 'PC-04')
            WingetId   = 'Autodesk.DWGTrueView.2027'
            Winget     = $false
            Version    = '1.0.0.0'
            Type       = 'exe'
            Detection  = '^(Autodesk )?DWG TrueView 2027'
            Arguments  = '--silent'
            Url        = ''
            Sha256     = ''
            Fichier    = 'DWGTrueView2027\Setup.exe'
            Raccourcis = @('DWG TrueView*.lnk')
        }
        @{
            Nom        = 'LibreCAD'
            Actif      = $true
            Postes     = @('PC-03', 'PC-04')
            WingetId   = 'LibreCAD.LibreCAD'
            Version    = '2.2.1.5'
            Type       = 'exe'
            Detection  = '^LibreCAD'
            Arguments  = '/S'
            Url        = 'https://github.com/LibreCAD/LibreCAD/releases/download/v2.2.1.5/LibreCAD-v2.2.1.5-win64-msvc.exe'
            Sha256     = '738912fea40aca934689444af9c5cd281572417983cc081c204fe6c779f6941d'
            Fichier    = 'LibreCAD-v2.2.1.5-win64-msvc.exe'
            Raccourcis = @('LibreCAD*.lnk')
        }
        @{
            Nom        = 'FreeCAD'
            Actif      = $true
            Postes     = @('PC-04')
            WingetId   = 'FreeCAD.FreeCAD'
            WingetScope = 'machine'
            Version    = '1.1.3'
            Type       = 'exe'
            Detection  = '^FreeCAD'
            Arguments  = '/S /AllUsers'
            Url        = 'https://github.com/FreeCAD/FreeCAD/releases/download/1.1.3/FreeCAD_1.1.3-Windows-x86_64-py311-installer.exe'
            Sha256     = '3de56676dedb7c68f4da9734c79abeaff9bbbf09f6a2c01df72a82beeee81c11'
            Fichier    = 'FreeCAD_1.1.3-Windows-x86_64-py311-installer.exe'
            Raccourcis = @('FreeCAD*.lnk')
        }
        @{
            Nom        = 'Blender'
            Actif      = $true
            Postes     = @('PC-04')
            WingetId   = 'BlenderFoundation.Blender.LTS.4.5'
            Version    = '4.5.10'
            Type       = 'msi'
            Detection  = '^Blender'
            Arguments  = '/qn /norestart ALLUSERS=1 /l*v "{LOG}"'
            Url        = 'https://download.blender.org/release/Blender4.5/blender-4.5.10-windows-x64.msi'
            Sha256     = '38a3f6eed2da970ed14721f8312a8187487a35bb69a1f88bffaadb4e0612c957'
            Fichier    = 'blender-4.5.10-windows-x64.msi'
            Raccourcis = @('Blender*.lnk')
        }
    )
}
