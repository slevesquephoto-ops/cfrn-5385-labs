#requires -version 5.1
<#
.SYNOPSIS
    Télécharge sur l'hôte les installeurs figés de AB-Config.psd1 dans tools\installeurs
    (méthode Local d'Install-ABSoftware.ps1 : VM par Push, vrais postes par clé USB).

.DESCRIPTION
    Pas besoin d'être administrateur : n'écrit que dans tools\installeurs (ignoré par Git).
    Un fichier déjà présent avec le bon SHA256 n'est pas retéléchargé.
    Un logiciel sans URL (DWG TrueView) est signalé : à déposer à la main.
    Code de sortie : 0 si tous les installeurs actifs sont présents et valides.

.EXAMPLE
    .\tools\Get-ABInstallers.ps1
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Push -Path .\tools\installeurs -Destination C:\Lab\tools
#>
[CmdletBinding()]
param(
    [string]$Destination
)

# $PSScriptRoot est vide dans les valeurs par défaut de param en 5.1 (lancement par -File)
if (-not $Destination) { $Destination = Join-Path $PSScriptRoot 'installeurs' }
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest est très lent avec la barre de progression
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Import-Module (Join-Path $PSScriptRoot '..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB\AB-Lab.psm1') -Force

if (-not (Test-Path -LiteralPath $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }

$exitCode = 0
foreach ($soft in ((Get-ABConfig).Logiciels | Where-Object { $_.Actif })) {
    $file = Join-Path $Destination $soft.Fichier
    if (-not $soft.Url) {
        if (Test-Path -LiteralPath $file) { Write-LabOK "$($soft.Nom) : présent (déposé à la main)." }
        else { Write-LabWarn "$($soft.Nom) : aucune URL. Déposer l'installeur ici : $file"; $exitCode = 1 }
        continue
    }
    $expected = $soft.Sha256.ToUpper()
    if ((Test-Path -LiteralPath $file) -and ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -eq $expected)) {
        Write-LabOK "$($soft.Nom) : déjà présent."
        continue
    }
    Write-LabStep "$($soft.Nom) $($soft.Version)"
    $tmp = "$file.part"
    try {
        Invoke-WebRequest -Uri $soft.Url -OutFile $tmp -UseBasicParsing
        $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
        if ($hash -ne $expected) { throw "SHA256 inattendu : $hash (attendu $expected)" }
        Move-Item -LiteralPath $tmp -Destination $file -Force
        Write-LabOK "$($soft.Fichier) ($([math]::Round((Get-Item -LiteralPath $file).Length / 1MB)) Mo)"
    } catch {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
        Write-LabWarn "$($soft.Nom) : $($_.Exception.Message)"
        $exitCode = 1
    }
}
exit $exitCode
