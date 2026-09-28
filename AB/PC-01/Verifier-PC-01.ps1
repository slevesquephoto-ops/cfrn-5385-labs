#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-01 : contrôle l'état (contrat Verifier-*).

.DESCRIPTION
    Écrit une ligne JSON {"machine","attendu","ok","echecs","controles"}; code 0 si l'état
    observé correspond à -Attendu. Chaque contrôle décrit l'état PROPRE.
    Communs (Test-ABPoste) : logiciels, windows-update, politique-mdp, strategies, profil
    (dont S: vers \\AB-SRV-01\Commun, R5).
    R6 sur le poste : police (Montserrat), impression-pdf, libreoffice (programme complet),
    profil-libreoffice (verrou d'un autre poste), macros (sécurité et emplacements de
    confiance; une sécurité baissée est un échec, même si la macro s'exécute).
    En Panne : profil (R5, sauf -SansR5) + profil-libreoffice (A), libreoffice (C),
    police (D) ou macros (E); B : sur le serveur.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Propre', 'Panne')][string]$Attendu,
    [ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-01'
$Compte = 'ncote'
$checks = @(Test-ABPoste -Machine $Machine -Compte $Compte)

function Add-Check([string]$Name, [string[]]$Problems, [string]$OkDetail) {
    $detail = $OkDetail
    if ($Problems) { $detail = $Problems -join '; ' }
    $script:checks += New-LabCheck -Name $Name -Passed (-not $Problems) -Detail $detail
}

Add-Check 'police' @(Test-ABFont -Famille 'Montserrat') 'Montserrat installée pour tous les utilisateurs'

$p = @()
if ((Get-WindowsOptionalFeature -Online -FeatureName 'Printing-PrintToPDFServices-Features').State -ne 'Enabled') { $p += 'fonction « Microsoft Print to PDF » désactivée' }
Add-Check 'impression-pdf' $p 'Microsoft Print to PDF activée'

$p = @()
$lo = (Get-ABConfig).Logiciels | Where-Object { $_.Nom -eq 'LibreOffice' }
$found = Test-ABSoftware -Logiciel $lo
if (-not $found) { $p += 'LibreOffice non installé' }
elseif (-not (Test-Path -LiteralPath 'C:\Program Files\LibreOffice\program\soffice.bin')) { $p += 'soffice.bin absent (installation endommagée)' }
Add-Check 'libreoffice' $p 'programme LibreOffice complet'

# R6-A : profil LibreOffice verrouillé par un autre poste
$p = @()
$lock = Get-ABLibreOfficeLock -Compte $Compte
if ($lock -and $lock.Poste -and $lock.Poste -ne $env:COMPUTERNAME) { $p += "profil LibreOffice verrouillé par « $($lock.Poste) » ($($lock.Chemin))" }
Add-Check 'profil-libreoffice' $p 'profil LibreOffice non verrouillé par un autre poste'

# R6-E : sécurité des macros. Deux corrections possibles, distinguées :
#   conforme     : emplacements de confiance ajoutés, sécurité conservée (Élevé ou Très élevé)
#   non conforme : sécurité baissée (Moyen ou Bas) : échec, même si la macro s'exécute
$p = @()
$want = @((Get-ABConfig).Pannes.R6.EmplacementsConfiance)
$mc = Get-ABLibreOfficeMacroConfig -Compte $Compte
$noms = @{ 0 = 'Bas'; 1 = 'Moyen'; 2 = 'Élevé'; 3 = 'Très élevé' }
$missing = @($want | Where-Object { $mc.Emplacements -notcontains $_ })
if ($mc.Niveau -lt 2) { $p += "sécurité des macros BAISSÉE à « $($noms[$mc.Niveau]) » : correction non conforme (remettre Élevé ou Très élevé et ajouter les emplacements de confiance)" }
if ($missing) { $p += "sécurité « $($noms[$mc.Niveau]) », emplacement(s) de confiance manquant(s) : $($missing -join ', ') (macro de numérotation bloquée)" }
$ok = "sécurité « $($noms[$mc.Niveau]) », emplacements de confiance présents"
if ($mc.Niveau -eq 3) { $ok += ' (sécurité Très élevé conservée : correction conforme)' }
Add-Check 'macros' $p $ok

# En Panne : échecs attendus exacts. R5 (S: vers \\AB-SERVEUR) fait échouer « profil ».
if ($Attendu -eq 'Panne') {
    $st = Get-LabState -Scenario $Machine
    if (-not $Variante -and $st) { $Variante = $st.Variante }
    if ($Variante) {
        $expected = @()
        if (-not $st -or $st.R5) { $expected += 'profil' }
        switch ($Variante) { 'A' { $expected += 'profil-libreoffice' } 'C' { $expected += 'libreoffice' } 'D' { $expected += 'police' } 'E' { $expected += 'macros' } }
        exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks -EchecsAttendus $expected)
    }
}
exit (Complete-LabVerification -Machine $Machine -Attendu $Attendu -Checks $checks)
