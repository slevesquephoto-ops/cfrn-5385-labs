#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Clone une VM Hyper-V : export temporaire, import en copie avec nouvel ID,
    renommage de la VM et de son disque, suppression de l'export.
    Option : renomme aussi l'ordinateur dans l'invite Windows (PowerShell Direct).

.EXAMPLE
    .\Cloner-VM.ps1 -Source "AB-PC-03-T" -Nouveau "AB-PC-01-T"

.EXAMPLE
    .\Cloner-VM.ps1 -Source "AB-PC-03-T" -Nouveau "AB-PC-01-T" -RenommerInvite

.NOTES
    Script volontairement sans accents : PowerShell 5.1 lit les .ps1 UTF-8
    sans BOM comme de l'ANSI, ce qui brouille les caracteres accentues.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Nouveau,
    [string]$Racine        = "D:\Ordinateurs",
    [string]$DossierExport = "D:\Export",
    [switch]$RenommerInvite,
    [int]$DelaiDemarrageSec = 300
)

$ErrorActionPreference = 'Stop'

$Dest       = Join-Path $Racine $Nouveau
$ExportTemp = Join-Path $DossierExport ("clone-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

# ---------------------------------------------------------------- Verifications
$vmSource = @(Get-VM -Name $Source -ErrorAction SilentlyContinue)
if ($vmSource.Count -eq 0) { throw "VM source '$Source' introuvable. Lancez Get-VM pour voir les noms exacts." }
if ($vmSource.Count -gt 1) { throw "Plusieurs VM portent le nom '$Source'. Renommez-en une avant de continuer." }
$vmSource = $vmSource[0]

if (Get-VM -Name $Nouveau -ErrorAction SilentlyContinue) { throw "Une VM nommee '$Nouveau' existe deja." }
if (Test-Path $Dest) { throw "Le dossier de destination '$Dest' existe deja." }
if ($RenommerInvite -and $Nouveau.Length -gt 15) {
    throw "'$Nouveau' depasse 15 caracteres : invalide comme nom d'ordinateur Windows (limite NetBIOS)."
}

$aDesCheckpoints = [bool](Get-VMSnapshot -VM $vmSource)
if ($aDesCheckpoints) {
    Write-Warning "La VM source a des points de controle. Ils seront copies aussi, et le VHDX du clone ne sera PAS renomme (la chaine .avhdx casserait)."
}

# Espace disque : l'export puis l'import copient les disques deux fois sur le meme volume
$tailleDisques = (Get-VMHardDiskDrive -VM $vmSource |
    Where-Object Path |
    ForEach-Object { (Get-VHD -Path $_.Path).FileSize } |
    Measure-Object -Sum).Sum
$lecteur = (Split-Path $Racine -Qualifier).TrimEnd(':')
$libre   = (Get-PSDrive -Name $lecteur).Free
if ($libre -lt (2 * $tailleDisques)) {
    throw ("Espace insuffisant sur {0}: : {1:N1} Go libres, environ {2:N1} Go requis." -f $lecteur, ($libre / 1GB), (2 * $tailleDisques / 1GB))
}

# ---------------------------------------------------------------- 1. Export
Write-Host "[1/4] Export de '$Source' vers $ExportTemp ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $ExportTemp -Force | Out-Null
Export-VM -VM $vmSource -Path $ExportTemp

# ---------------------------------------------------------------- 2. Import en copie
Write-Host "[2/4] Import en copie avec nouvel ID vers $Dest ..." -ForegroundColor Cyan
$vmcx = @(Get-ChildItem (Join-Path $ExportTemp "$Source\Virtual Machines\*.vmcx"))
if ($vmcx.Count -ne 1) { throw "Attendu 1 fichier .vmcx dans l'export, trouve $($vmcx.Count). Export conserve dans $ExportTemp." }

$clone = Import-VM -Path $vmcx[0].FullName -Copy -GenerateNewId `
    -VirtualMachinePath $Dest `
    -VhdDestinationPath (Join-Path $Dest "Virtual Hard Disks")

# ---------------------------------------------------------------- 3. Renommage VM + disques
Write-Host "[3/4] Renommage de la VM et des disques ..." -ForegroundColor Cyan
Rename-VM -VM $clone -NewName $Nouveau
$clone = Get-VM -Id $clone.Id

if (-not $aDesCheckpoints) {
    $disques = @(Get-VMHardDiskDrive -VM $clone | Where-Object Path)
    $i = 0
    foreach ($d in $disques) {
        $ext = [IO.Path]::GetExtension($d.Path)
        $nom = if ($disques.Count -eq 1) { "$Nouveau$ext" } else { "$Nouveau-$i$ext" }
        $nouveauChemin = Join-Path (Split-Path $d.Path -Parent) $nom
        if ($d.Path -ne $nouveauChemin) {
            Rename-Item -Path $d.Path -NewName $nom
            Set-VMHardDiskDrive -VMHardDiskDrive $d -Path $nouveauChemin
        }
        $i++
    }
}

# ---------------------------------------------------------------- 4. Nettoyage
Write-Host "[4/4] Suppression de l'export temporaire ..." -ForegroundColor Cyan
Remove-Item -Path $ExportTemp -Recurse -Force

# ---------------------------------------------------------------- Option : nom dans l'invite
if ($RenommerInvite) {
    Write-Host "Demarrage du clone pour renommer l'ordinateur dans l'invite ..." -ForegroundColor Cyan
    Start-VM -VM $clone

    $limite = (Get-Date).AddSeconds($DelaiDemarrageSec)
    do {
        Start-Sleep -Seconds 5
        $etat = (Get-VM -Id $clone.Id).Heartbeat
    } until ("$etat" -like 'Ok*' -or (Get-Date) -gt $limite)

    if ("$etat" -notlike 'Ok*') {
        Write-Warning "L'invite ne repond pas apres $DelaiDemarrageSec s. Renommez-le manuellement (Rename-Computer)."
    }
    else {
        $cred = Get-Credential -Message "Compte administrateur LOCAL de l'invite '$Nouveau'"
        Invoke-Command -VMId $clone.Id -Credential $cred -ScriptBlock {
            Rename-Computer -NewName $using:Nouveau -Force -Restart
        }
        Write-Host "Invite renomme en '$Nouveau', redemarrage en cours." -ForegroundColor Green
    }
}

# ---------------------------------------------------------------- Resume
Write-Host "`nClone termine :" -ForegroundColor Green
Get-VM -Id $clone.Id | Select-Object Name, Id, State, Path | Format-List
Get-VMHardDiskDrive -VM $clone | Select-Object ControllerType, Path | Format-Table -AutoSize
Write-Host "Source pour comparaison (ID different attendu) :"
Get-VM -Id $vmSource.Id | Select-Object Name, Id | Format-List
