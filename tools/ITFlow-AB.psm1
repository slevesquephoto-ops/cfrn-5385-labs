#requires -version 5.1
<#
ITFlow-AB.psm1 - Accès limité à l'API ITFlow v1 pour préparer Architecture Boréale.

Ce module lit et crée : clients AB, lieux, contacts, actifs, requêtes.
Aucune suppression, aucun archivage, aucune soumission, aucune facture.

Depuis ITFlow v26.08, une clé API appartient à un UTILISATEUR et hérite de son
rôle et de ses accès aux clients. L'utilisateur ITFlow « Claude » voit tous les
clients SAUF ceux que l'enseignant lui refuse (règles de refus v26.08), ce qui
lui permet de voir les clients qu'il crée lui-même.

Secrets et configuration (créés par tools\Setup-LabSecrets.ps1, jamais dans le dépôt) :
  $HOME\.lab\itflow-config.json   { "BaseUrl": "...", "ClientsProteges": ["Garage du Fleuve*"] }
  $HOME\.lab\itflow-key.xml       la clé de l'utilisateur « Claude » (DPAPI)

Garde-fous :
  - refuse de fonctionner si la clé voit un client « protégé » (ex. les équipes GDF,
    qui servent de traces d'évaluation) : les règles de refus ne sont pas en place;
  - ne crée que des clients dont le nom commence par « Architecture Boréale »;
  - après Connect-ITFlowAB -Equipe X, chaque appel est limité au client de l'équipe.

Usage :
  Import-Module .\tools\ITFlow-AB.psm1 -Force
  Connect-ITFlowAB                          # vérifie la clé et les garde-fous
  New-ITFlowABClient -Equipe A -WhatIf      # crée « Architecture Boréale — Équipe A »
  Connect-ITFlowAB -Equipe A                # travaille dans ce client
  New-ITFlowABContact -Nom 'Émilie Fortin' -Courriel 'efortin@architecture-boreale.example' -WhatIf
#>

Set-StrictMode -Version 2.0

$script:SecretDir = Join-Path $HOME '.lab'
$script:Base = $null
$script:Key = $null
$script:Equipe = $null
$script:ClientId = $null
$script:ClientPrefix = 'Architecture Boréale'

$script:ReadModules = @('clients','contacts','locations','assets','tickets','networks','vendors','quotes','invoices','products')

function Get-ABClientName {
    param([Parameter(Mandatory)][string]$Equipe)
    return "$script:ClientPrefix — Équipe $Equipe"
}

function Connect-ITFlowAB {
    <#
    Sans -Equipe : charge la clé et vérifie les garde-fous (utile avant New-ITFlowABClient).
    Avec -Equipe : limite ensuite tous les appels au client de cette équipe.
    #>
    [CmdletBinding()]
    param([ValidateSet('A','B','C','D','E')][string]$Equipe)

    $cfgFile = Join-Path $script:SecretDir 'itflow-config.json'
    $keyFile = Join-Path $script:SecretDir 'itflow-key.xml'
    if (-not (Test-Path $cfgFile) -or -not (Test-Path $keyFile)) {
        throw "Configuration ITFlow absente. L'enseignant doit lancer tools\Setup-LabSecrets.ps1 -Partie ITFlow."
    }
    $cfg = Get-Content $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $protected = @()
    if ($cfg.PSObject.Properties.Name -contains 'ClientsProteges') { $protected = @($cfg.ClientsProteges) }
    if ($protected.Count -eq 0) {
        throw "Aucun client protégé dans itflow-config.json (ClientsProteges). Refusé par prudence."
    }

    $script:Base = $cfg.BaseUrl.TrimEnd('/')
    $script:Key = (Import-Clixml $keyFile).GetNetworkCredential().Password
    $script:Equipe = $null
    $script:ClientId = $null

    if ($script:Base -like 'http://*') {
        Write-Warning "ITFlow est joint en HTTP : acceptable sur le réseau interne de l'hôte seulement."
    }

    $clients = @(Invoke-ITFlowRead -Module clients -Data @{ limit = 500 })
    $seen = @($clients | Where-Object { $name = $_.client_name; @($protected | Where-Object { $name -like $_ }).Count -gt 0 })
    if ($seen.Count -gt 0) {
        $script:Key = $null
        throw "Refusé : l'utilisateur « Claude » voit $($seen.Count) client(s) protégé(s) ($((@($seen | ForEach-Object { $_.client_name })) -join ', ')). Ajouter des règles de refus dans ITFlow."
    }
    Write-Host "[OK] Clé valide. Clients visibles : $($clients.Count). Aucun client protégé visible."

    if (-not $Equipe) { return }
    $target = Get-ABClientName -Equipe $Equipe
    $mine = @($clients | Where-Object { $_.client_name -eq $target })
    if ($mine.Count -ne 1) {
        throw "Client « $target » introuvable ou en double ($($mine.Count)). Le créer avec New-ITFlowABClient -Equipe $Equipe."
    }
    $script:ClientId = [int]$mine[0].client_id
    $script:Equipe = $Equipe
    Write-Host "[OK] Équipe $Equipe : $target (client_id $script:ClientId)."
}

function Assert-Connected {
    if (-not $script:Key -or -not $script:ClientId) { throw "Appeler Connect-ITFlowAB -Equipe <A..E> d'abord." }
}

function New-ITFlowABClient {
    <# Crée le client « Architecture Boréale — Équipe X » s'il n'existe pas. #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateSet('A','B','C','D','E')][string]$Equipe,
        [string]$Notes = "Mise en situation #2 (507 + 373). Client fictif du DEP 5385, CFRN."
    )
    if (-not $script:Key) { throw "Appeler Connect-ITFlowAB d'abord." }
    $name = Get-ABClientName -Equipe $Equipe
    $existing = @(Invoke-ITFlowRead -Module clients -Data @{ client_name = $name })
    $existing = @($existing | Where-Object { $_.client_name -eq $name })
    if ($existing.Count -gt 0) { Write-Host "[=] Client déjà présent : $name"; return [int]$existing[0].client_id }
    $data = @{
        client_name = $name; client_type = 'Architecture'; client_currency_code = 'CAD'
        client_abbreviation = "AB$Equipe"; client_notes = $Notes
    }
    if ($PSCmdlet.ShouldProcess('ITFlow', "Créer le client : $name")) {
        $r = Invoke-ITFlowRaw -Module clients -Function create -Data $data
        $id = $r.data[0].insert_id
        Write-Host "[OK] Client créé : $name (id $id)"
        return $id
    }
}

function Invoke-ITFlowRaw {
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][ValidateSet('read','create')][string]$Function,
        [hashtable]$Data = @{}
    )
    if (-not $script:Key) { throw "Appeler Connect-ITFlowAB d'abord." }
    $uri = "$script:Base/api/v1/$Module/$Function.php"
    try {
        if ($Function -eq 'read') {
            $query = @("api_key=$([uri]::EscapeDataString($script:Key))")
            foreach ($k in $Data.Keys) { $query += "$k=$([uri]::EscapeDataString([string]$Data[$k]))" }
            $resp = Invoke-RestMethod -Method Get -Uri ($uri + '?' + ($query -join '&'))
        } else {
            $body = @{ api_key = $script:Key }
            foreach ($k in $Data.Keys) { $body[$k] = $Data[$k] }
            $json = $body | ConvertTo-Json -Depth 4
            $bytes = [Text.Encoding]::UTF8.GetBytes($json)
            $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $bytes -ContentType 'application/json; charset=utf-8'
        }
    } catch {
        # Ne jamais laisser la clé apparaître dans un message d'erreur
        $msg = $_.Exception.Message -replace [regex]::Escape($script:Key), '***'
        throw "Appel ITFlow $Module/$Function échoué : $msg"
    }
    if ("$($resp.success)" -ne 'True') {
        throw "ITFlow $Module/$Function : $($resp.message)"
    }
    return $resp
}

function Invoke-ITFlowRead {
    param([Parameter(Mandatory)][string]$Module, [hashtable]$Data = @{})
    try {
        return (Invoke-ITFlowRaw -Module $Module -Function read -Data $Data).data
    } catch {
        if ($_.Exception.Message -match 'No resource') { return @() }
        throw
    }
}

function Invoke-ITFlowCall {
    <# Appel limité au client de l'équipe connectée. #>
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][ValidateSet('read','create')][string]$Function,
        [hashtable]$Data = @{}
    )
    Assert-Connected
    $d = @{}
    foreach ($k in $Data.Keys) { $d[$k] = $Data[$k] }
    $d['client_id'] = $script:ClientId
    if ($Function -eq 'create') { return (Invoke-ITFlowRaw -Module $Module -Function create -Data $d) }

    $rows = @(Invoke-ITFlowRead -Module $Module -Data $d)
    # Double sécurité : ne garder que les lignes du client de l'équipe
    return @($rows | Where-Object {
        $row = $_
        $field = @($row.PSObject.Properties.Name | Where-Object { $_ -match '_client_id$' }) | Select-Object -First 1
        if (-not $field) { $true } else { [int]$row.$field -eq $script:ClientId }
    })
}

function Get-ITFlowAB {
    <# Lecture limitée au client de l'équipe. Ex. : Get-ITFlowAB -Module assets -Filtre @{ asset_name = 'AB-PC-03' } #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Module,
        [hashtable]$Filtre = @{},
        [int]$Limite = 200
    )
    if ($script:ReadModules -notcontains $Module) { throw "Module non autorisé en lecture : $Module" }
    $f = @{ limit = $Limite }
    foreach ($k in $Filtre.Keys) { $f[$k] = $Filtre[$k] }
    return (Invoke-ITFlowCall -Module $Module -Function read -Data $f)
}

function New-ITFlowRecord {
    param(
        [Parameter(Mandatory)][ValidateSet('locations','contacts','assets','tickets')][string]$Module,
        [Parameter(Mandatory)][hashtable]$Data,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)]$Cmdlet
    )
    if ($Cmdlet.ShouldProcess("ITFlow équipe $script:Equipe", "Créer $Module : $Label")) {
        $r = Invoke-ITFlowCall -Module $Module -Function create -Data $Data
        $id = $r.data[0].insert_id
        Write-Host "[OK] $Module créé : $Label (id $id)"
        return $id
    }
}

function New-ITFlowABLocation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Nom,
        [string]$Description = '',
        [switch]$Principal
    )
    Assert-Connected
    $existing = Get-ITFlowAB -Module locations | Where-Object { $_.location_name -eq $Nom }
    if ($existing) { Write-Host "[=] Lieu déjà présent : $Nom"; return $existing[0].location_id }
    $data = @{ location_name = $Nom; location_description = $Description; location_primary = [int][bool]$Principal }
    New-ITFlowRecord -Module locations -Data $data -Label $Nom -Cmdlet $PSCmdlet
}

function New-ITFlowABContact {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Nom,
        [Parameter(Mandatory)][string]$Courriel,
        [string]$Titre = '',
        [string]$Telephone = '',
        [string]$Notes = '',
        [int]$LieuId = 0,
        [switch]$Principal
    )
    Assert-Connected
    $existing = Get-ITFlowAB -Module contacts -Filtre @{ contact_email = $Courriel }
    if ($existing) { Write-Host "[=] Contact déjà présent : $Nom"; return $existing[0].contact_id }
    $data = @{
        contact_name = $Nom; contact_email = $Courriel; contact_title = $Titre
        contact_phone = $Telephone; contact_notes = $Notes; contact_primary = [int][bool]$Principal
    }
    if ($LieuId) { $data.contact_location_id = $LieuId }
    New-ITFlowRecord -Module contacts -Data $data -Label $Nom -Cmdlet $PSCmdlet
}

function New-ITFlowABAsset {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Nom,
        [ValidateSet('Desktop','Server','Laptop','Router','Printer','Other')][string]$Type = 'Desktop',
        [string]$Fabricant = '',
        [string]$Modele = '',
        [string]$NumeroSerie = '',
        [string]$OS = '',
        [string]$IP = '',
        [string]$MAC = '',
        [string]$Notes = '',
        [int]$LieuId = 0,
        [int]$ContactId = 0
    )
    Assert-Connected
    $existing = Get-ITFlowAB -Module assets -Filtre @{ asset_name = $Nom }
    if ($existing) { Write-Host "[=] Actif déjà présent : $Nom"; return $existing[0].asset_id }
    $data = @{
        asset_name = $Nom; asset_type = $Type; asset_make = $Fabricant; asset_model = $Modele
        asset_serial = $NumeroSerie; asset_os = $OS; asset_ip = $IP; asset_mac = $MAC
        asset_notes = $Notes; asset_status = 'Deployed'
    }
    if ($LieuId) { $data.asset_location_id = $LieuId }
    if ($ContactId) { $data.asset_contact_id = $ContactId }
    New-ITFlowRecord -Module assets -Data $data -Label $Nom -Cmdlet $PSCmdlet
}

function New-ITFlowABTicket {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Sujet,
        [Parameter(Mandatory)][string]$Details,
        [ValidateSet('Low','Medium','High')][string]$Priorite = 'Medium',
        [int]$ContactId = 0,
        [int]$ActifId = 0
    )
    Assert-Connected
    $existing = Get-ITFlowAB -Module tickets | Where-Object { $_.ticket_subject -eq $Sujet }
    if ($existing) { Write-Host "[=] Requête déjà présente : $Sujet"; return $existing[0].ticket_id }
    $data = @{ ticket_subject = $Sujet; ticket_details = $Details; ticket_priority = $Priorite; ticket_billable = 1 }
    if ($ContactId) { $data.ticket_contact_id = $ContactId }
    if ($ActifId) { $data.ticket_asset_id = $ActifId }
    New-ITFlowRecord -Module tickets -Data $data -Label $Sujet -Cmdlet $PSCmdlet
}

Export-ModuleMember -Function Connect-ITFlowAB, New-ITFlowABClient, Get-ITFlowAB, New-ITFlowABLocation, New-ITFlowABContact, New-ITFlowABAsset, New-ITFlowABTicket
