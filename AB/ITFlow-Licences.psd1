@{
    # =======================================================================
    # Licences fictives d'Architecture Boréale, pour l'exercice de conformité.
    # Représentées dans ITFlow comme des ACTIFS de type « Autre » (le module
    # ITFlow-AB.psm1 ne donne pas accès à l'onglet Licences dédié; cette voie
    # reste visible côté élève et ne modifie pas le module). Créées par équipe
    # par tools\Add-ITFlowABLicences.ps1.
    #
    # Incohérence VOULUE : les 5 machines tournent réellement Windows 11, mais
    # l'inventaire montre 4 licences Windows 11 + 1 Windows Server 2019 (assignée
    # au « serveur » qui est en fait sous Windows 11). Clés fictives (aucune vraie
    # clé de produit). Dates au format AAAA-MM-JJ; Expiration vide = perpétuelle.
    # =======================================================================
    Licences = @(
        # --- Systèmes d'exploitation (l'incohérence) ---
        @{ Produit = 'Windows 11 Pro';       Editeur = 'Microsoft'; Machine = 'PC-01'; Cle = 'MSFT-W11P-FICTV-0001-XXXXX'; Sieges = 1; Achat = '2025-08-14'; Expiration = ''; Note = '' }
        @{ Produit = 'Windows 11 Pro';       Editeur = 'Microsoft'; Machine = 'PC-02'; Cle = 'MSFT-W11P-FICTV-0002-XXXXX'; Sieges = 1; Achat = '2025-08-14'; Expiration = ''; Note = '' }
        @{ Produit = 'Windows 11 Pro';       Editeur = 'Microsoft'; Machine = 'PC-03'; Cle = 'MSFT-W11P-FICTV-0003-XXXXX'; Sieges = 1; Achat = '2025-08-14'; Expiration = ''; Note = '' }
        @{ Produit = 'Windows 11 Pro';       Editeur = 'Microsoft'; Machine = 'PC-04'; Cle = 'MSFT-W11P-FICTV-0004-XXXXX'; Sieges = 1; Achat = '2025-08-14'; Expiration = ''; Note = '' }
        @{ Produit = 'Windows Server 2019';  Editeur = 'Microsoft'; Machine = 'SRV-01'; Cle = 'MSFT-WS19-FICTV-SRV1-XXXXX'; Sieges = 1; Achat = '2025-08-14'; Expiration = ''; Note = 'À VÉRIFIER : la machine AB-SRV-01 exécute en réalité Windows 11 Pro. Licence Server non conforme au parc.' }

        # --- Logiciels (fictivement achetés) ---
        @{ Produit = 'LibreOffice (support entreprise)'; Editeur = 'The Document Foundation'; Machine = ''; Portee = 'Site (5 postes)'; Cle = 'LO-ENT-FICTV-SITE-2026'; Sieges = 5; Achat = '2026-01-06'; Expiration = '2027-01-05'; Note = 'Contrat de support annuel (fictif).' }
        @{ Produit = 'Adobe Acrobat Pro';    Editeur = 'Adobe';  Machine = 'PC-01'; Cle = 'ADBE-ACRP-FICTV-P01'; Sieges = 1; Achat = '2026-02-01'; Expiration = '2027-01-31'; Note = 'Poste réception (facturation).' }
        @{ Produit = 'Adobe Acrobat Pro';    Editeur = 'Adobe';  Machine = 'PC-02'; Cle = 'ADBE-ACRP-FICTV-P02'; Sieges = 1; Achat = '2026-02-01'; Expiration = '2027-01-31'; Note = 'Poste associé.' }
        @{ Produit = 'LibreCAD (licence pro fictive)'; Editeur = 'LibreCAD Team'; Machine = 'PC-03'; Cle = 'LCAD-PRO-FICTV-P03'; Sieges = 1; Achat = '2025-09-10'; Expiration = ''; Note = '' }
        @{ Produit = 'FreeCAD (support pro fictif)';   Editeur = 'FreeCAD Team';  Machine = 'PC-04'; Cle = 'FCAD-PRO-FICTV-P04'; Sieges = 1; Achat = '2025-09-10'; Expiration = ''; Note = '' }
        @{ Produit = 'Blender Studio (abonnement fictif)'; Editeur = 'Blender'; Machine = 'PC-04'; Cle = 'BLND-STU-FICTV-P04'; Sieges = 1; Achat = '2026-01-15'; Expiration = '2027-01-14'; Note = '' }

        # --- Police de caractères (fictivement sous licence commerciale) ---
        @{ Produit = 'Montserrat (licence commerciale de police)'; Editeur = 'Fonderie (fictif)'; Machine = ''; Portee = 'Cabinet'; Cle = 'FONT-MONT-FICTV-DESK'; Sieges = 5; Achat = '2025-03-02'; Expiration = ''; Note = 'Charte graphique AB (en réalité sous licence libre OFL).' }
    )
}
