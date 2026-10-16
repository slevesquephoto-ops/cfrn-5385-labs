#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Pannes spontanées : place un client particulier sur le poste et installe, retire ou
    vérifie ses pannes (voir Particuliers\SPEC.md).

.DESCRIPTION
    -Panne <Id>             Client absent : compte, profil et données créés, puis la panne.
                            Client présent : seulement la panne (profil conservé).
    -Panne <Id> -Retirer    Retire cette panne (état d'origine restauré).
    -Retirer -Tout          Retire toutes les pannes du client.
    -Verifier               Ligne JSON (contrat AB) et code 0 si l'état observé correspond
                            aux pannes installées : celles-ci présentes, les autres absentes.
    -Supprimer              Retire les pannes, puis le compte et le profil du client. Sans
                            client restant, le poste revient à son état d'origine (comptes
                            sans mot de passe réactivés).
    -Liste                  Clients, pannes du catalogue et pannes installées.

.EXAMPLE
    .\Client.ps1 -Client mbelanger -Panne RES-PROXY
    .\Client.ps1 -Client mbelanger -Panne RES-PROXY -Retirer
    .\Client.ps1 -Client mbelanger -Verifier
#>
[CmdletBinding(DefaultParameterSetName = 'Liste')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Panne')]
    [Parameter(Mandatory, ParameterSetName = 'Tout')]
    [Parameter(Mandatory, ParameterSetName = 'Verifier')]
    [Parameter(Mandatory, ParameterSetName = 'Supprimer')]
    [string]$Client,

    [Parameter(Mandatory, ParameterSetName = 'Panne')][string]$Panne,
    [Parameter(ParameterSetName = 'Panne')]
    [Parameter(Mandatory, ParameterSetName = 'Tout')][switch]$Retirer,
    [Parameter(Mandatory, ParameterSetName = 'Tout')][switch]$Tout,
    [Parameter(Mandatory, ParameterSetName = 'Verifier')][switch]$Verifier,
    [Parameter(Mandatory, ParameterSetName = 'Supprimer')][switch]$Supprimer,
    [Parameter(ParameterSetName = 'Liste')][switch]$Liste
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB\AB-Lab.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Particuliers-Lab.psm1') -Force

$mode = $PSCmdlet.ParameterSetName
$null = $Tout, $Verifier, $Supprimer, $Liste   # commutateurs qui choisissent seulement le mode

if ($mode -eq 'Verifier') {
    # Pas de journal ni de message : la sortie est la ligne JSON (lue par la console et les tests)
    $v = Get-PartVerification -Compte $Client
    $attendu = 'Propre'; if ($v.Attendues) { $attendu = 'Panne' }
    $params = @{ Machine = $env:COMPUTERNAME; Attendu = $attendu; Checks = $v.Checks }
    if ($v.Attendues) { $params.EchecsAttendus = $v.Attendues }
    exit (Complete-LabVerification @params)
}

if ($mode -eq 'Liste') {
    Clear-PartPendingProfile
    $cfg = Get-PartConfig
    $inst = @(Get-PartInstalled)
    Write-LabStep "Clients ($env:COMPUTERNAME)"
    foreach ($c in $cfg.Clients) {
        $etat = 'absent du poste'
        if (Get-LocalUser -Name $c.Compte -ErrorAction SilentlyContinue) { $etat = 'présent' }
        $p = @($inst | Where-Object { $_.Compte -eq $c.Compte } | ForEach-Object { $_.Id })
        $txt = 'aucune panne'; if ($p) { $txt = $p -join ', ' }
        Write-Host ("  {0,-10} {1,-22} {2,-16} {3}" -f $c.Compte, $c.NomComplet, $etat, $txt)
    }
    Write-LabStep 'Catalogue'
    foreach ($p in $cfg.Pannes) { Write-Host ("  {0,-12} {1,-8} {2}" -f $p.Id, $p.Portee, $p.Titre) }
    exit 0
}

$nom = "Client-$Client"
if ($Panne) { $nom += "-$Panne" }
$null = Start-LabLog -Name $nom
$exitCode = 0
try {
    Clear-PartPendingProfile
    switch ($mode) {
        'Panne' {
            if ($Retirer) { Remove-PartPanne -Compte $Client -Id $Panne }
            else { Install-PartPanne -Compte $Client -Id $Panne }
        }
        'Tout' {
            $ids = @(Get-PartInstalled -Compte $Client | ForEach-Object { $_.Id })
            if (-not $ids) { Write-LabOK "Aucune panne installée pour $Client." }
            foreach ($i in $ids) { Remove-PartPanne -Compte $Client -Id $i }
        }
        'Supprimer' { Remove-PartClient -Compte $Client }
    }
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
