#requires -version 5.1
# NAV-PIRATE : stratégies Edge détournant page d'accueil et moteur de recherche (tout le poste).
# Voir Particuliers-Config.psd1. Bandeau « Géré par votre organisation ». Page d'accueil = page LOCALE
# inoffensive « Recherche Express »; moteur par défaut factice (recherche-express.example, non résolu).
$edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$startKey = "$edge\RestoreOnStartupURLs"
$pageDir = Join-Path $env:ProgramData 'RechercheExpress'
$page = Join-Path $pageDir 'recherche-express.html'
$url = 'file:///' + ($page -replace '\\', '/')
# Valeurs de stratégie posées (path, nom, type, valeur).
$reglages = @(
    @{ P = $edge; N = 'HomepageLocation'; T = 'String'; V = $url }
    @{ P = $edge; N = 'HomepageIsNewTabPage'; T = 'DWord'; V = 0 }
    @{ P = $edge; N = 'ShowHomeButton'; T = 'DWord'; V = 1 }
    @{ P = $edge; N = 'RestoreOnStartup'; T = 'DWord'; V = 4 }
    @{ P = $edge; N = 'NewTabPageLocation'; T = 'String'; V = $url }
    @{ P = $edge; N = 'DefaultSearchProviderEnabled'; T = 'DWord'; V = 1 }
    @{ P = $edge; N = 'DefaultSearchProviderName'; T = 'String'; V = 'Recherche Express' }
    @{ P = $edge; N = 'DefaultSearchProviderSearchURL'; T = 'String'; V = 'https://recherche-express.example/search?q={searchTerms}' }
    @{ P = $edge; N = 'DefaultSearchProviderKeyword'; T = 'String'; V = 'recherche-express' }
    @{ P = $startKey; N = '1'; T = 'String'; V = $url }
)
$htmlPage = @"
<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Recherche Express</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:12%">
<h1>Recherche Express</h1><p>Votre nouvelle page de recherche.</p>
<p style="color:#888;font-size:small">(Page locale de laboratoire &mdash; aucune donnee envoyee.)</p>
</body></html>
"@
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        @{
            Valeurs         = @($reglages | ForEach-Object { Get-LabRegistrySnapshot -Path $_.P -Name $_.N })
            EdgeExistait    = [bool](Test-Path -LiteralPath $edge)
            StartExistait   = [bool](Test-Path -LiteralPath $startKey)
            Page            = $page
            PageCreee       = (-not (Test-Path -LiteralPath $page))
            DossierCree     = (-not (Test-Path -LiteralPath $pageDir))
        }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        if (-not (Test-Path -LiteralPath $pageDir)) { New-Item -ItemType Directory -Path $pageDir -Force | Out-Null }
        Set-Content -LiteralPath $page -Value $htmlPage -Encoding UTF8
        foreach ($r in $reglages) { Set-LabRegistryValue -Path $r.P -Name $r.N -Value $r.V -Type $r.T }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($v in @($Etat.Valeurs)) { Restore-LabRegistrySnapshot -Snapshot $v }
        if (-not $Etat.StartExistait -and (Test-Path -LiteralPath $startKey)) { Remove-Item -LiteralPath $startKey -Recurse -Force -ErrorAction SilentlyContinue }
        if (-not $Etat.EdgeExistait -and (Test-Path -LiteralPath $edge)) { Remove-Item -LiteralPath $edge -Recurse -Force -ErrorAction SilentlyContinue }
        if ($Etat.PageCreee -and (Test-Path -LiteralPath $Etat.Page)) { Remove-Item -LiteralPath $Etat.Page -Force }
        if ($Etat.DossierCree -and (Test-Path -LiteralPath $pageDir) -and -not @(Get-ChildItem -LiteralPath $pageDir -Force)) { Remove-Item -LiteralPath $pageDir -Force }
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $accueil = Get-LabRegistrySnapshot -Path $edge -Name 'HomepageLocation'
        $search = Get-LabRegistrySnapshot -Path $edge -Name 'DefaultSearchProviderName'
        $present = ($accueil.Exists -or $search.Exists)
        $d = 'Edge : aucune stratégie de détournement'; if ($present) { $d = "Edge détourné (accueil/moteur : $($search.Value))" }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
