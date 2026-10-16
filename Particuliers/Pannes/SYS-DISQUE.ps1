#requires -version 5.1
# SYS-DISQUE : gros fichier dans un dossier temporaire caché du profil, laisse ~1 Go libre (profil du client).
# Voir Particuliers-Config.psd1. fsutil alloue la taille instantanément (pas d'écriture octet par octet).
$sousChemin = 'AppData\Local\Temp\MediaCache'   # d'apparence normale (cache multimédia)
$nomFichier = 'cache.dat'
$libreVise = 1GB                                 # espace laissé libre
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $dossier = Join-Path $Ctx.Profil $sousChemin
        @{ Dossier = $dossier; Fichier = (Join-Path $dossier $nomFichier); DossierCree = (-not (Test-Path -LiteralPath $dossier)) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        $lettre = (Split-Path -Qualifier $Etat.Fichier).TrimEnd(':')
        $libre = (Get-PSDrive -Name $lettre).Free
        $taille = [long]($libre - $libreVise)
        if ($taille -lt 1GB) { throw "disque déjà presque plein ($([math]::Round($libre/1GB,1)) Go libres) : SYS-DISQUE sans effet utile." }
        if (-not (Test-Path -LiteralPath $Etat.Dossier)) { New-Item -ItemType Directory -Path $Etat.Dossier -Force | Out-Null }
        $out = & fsutil file createnew "$($Etat.Fichier)" $taille
        if ($LASTEXITCODE -ne 0) { throw "fsutil file createnew : $out" }
        (Get-Item -LiteralPath $Etat.Dossier -Force).Attributes = 'Hidden, System'
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        if (Test-Path -LiteralPath $Etat.Fichier) { Remove-Item -LiteralPath $Etat.Fichier -Force }
        if ($Etat.DossierCree -and (Test-Path -LiteralPath $Etat.Dossier) -and -not @(Get-ChildItem -LiteralPath $Etat.Dossier -Force)) {
            Remove-Item -LiteralPath $Etat.Dossier -Force
        }
    }
    Tester = {
        param($Ctx)
        $dossier = Join-Path $Ctx.Profil $sousChemin
        $fichier = Join-Path $dossier $nomFichier
        $present = (Test-Path -LiteralPath $fichier)
        $lettre = (Split-Path -Qualifier $dossier).TrimEnd(':')
        $libre = [math]::Round((Get-PSDrive -Name $lettre).Free / 1GB, 1)
        $d = "disque : $libre Go libres"; if ($present) { $d = "disque : $libre Go libres, gros fichier présent" }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
