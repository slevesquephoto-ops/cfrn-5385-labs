#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exécuté DANS une VM de test : pilote le menu interactif Menu-AB.ps1 au clavier simulé.

.DESCRIPTION
    Les saisies (séparées par « | ») sont envoyées sur l'entrée standard du menu, comme si
    l'enseignant les tapait. La sortie du menu est affichée, puis « CODE=<code> ».
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Saisies)

$menu = Join-Path (Split-Path -Parent $PSScriptRoot) 'Menu-AB.ps1'
$Saisies.Split('|') | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $menu
Write-Output "CODE=$LASTEXITCODE"
