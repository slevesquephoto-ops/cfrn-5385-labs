#requires -version 5.1
# SEC-BOUCLE : faux logiciel malveillant qui, à l'ouverture de session DU CLIENT, lance en boucle une
# application inoffensive jusqu'à saturer la session (punitif). Profil du client. Voir Particuliers-Config.psd1.
# Persistance par clé Run du profil (HKCU) : se déclenche au logon du client seulement -> un autre compte
# ouvre normalement, et le test automatisé (PowerShell Direct, sans logon interactif) ne le déclenche pas.
# But pédagogique : trouver et retirer la persistance; comprendre qu'on répare depuis un autre compte / Windows RE.
# Note : la calculatrice moderne est une app UWP mono-instance (ne se multiplie pas). On lance donc notepad.exe
# (Win32, multi-instance), qui consomme réellement de la mémoire. Changer $appli pour une autre app Win32.
$runRel = 'Software\Microsoft\Windows\CurrentVersion\Run'
$runNom = 'MediaTools'
$scriptRel = 'AppData\Local\MediaTools\run.ps1'
$appli = 'notepad.exe'
$intervalle = 2   # secondes entre deux lancements (plus court = plus agressif)
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $script = Join-Path $Ctx.Profil $scriptRel
        @{
            Run         = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom
            Script      = $script
            Dossier     = (Split-Path -Parent $script)
            DossierCree = (-not (Test-Path -LiteralPath (Split-Path -Parent $script)))
        }
    }
    Installer = {
        param($Ctx, $Etat)
        if (-not (Test-Path -LiteralPath $Etat.Dossier)) { New-Item -ItemType Directory -Path $Etat.Dossier -Force | Out-Null }
        $contenu = "while (`$true) { Start-Process '$appli'; Start-Sleep -Seconds $intervalle }"
        Set-Content -LiteralPath $Etat.Script -Value $contenu -Encoding ASCII
        (Get-Item -LiteralPath $Etat.Script -Force).Attributes = 'Hidden'
        $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($Etat.Script)`""
        Set-LabRegistryValue -Path (Join-Path $Ctx.Root $runRel) -Name $runNom -Value $cmd -Type String
    }
    Retirer = {
        param($Ctx, $Etat)
        Restore-PartUserValue -Root $Ctx.Root -Snapshot $Etat.Run
        # Tuer la boucle (hôte PowerShell qui référence le script) et les fenêtres déjà ouvertes.
        $nomAppli = [IO.Path]::GetFileNameWithoutExtension($appli)
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and $_.CommandLine -like "*$($Etat.Script)*" } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Name $nomAppli -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $Etat.Script) { Remove-Item -LiteralPath $Etat.Script -Force }
        if ($Etat.DossierCree -and (Test-Path -LiteralPath $Etat.Dossier) -and -not @(Get-ChildItem -LiteralPath $Etat.Dossier -Force)) {
            Remove-Item -LiteralPath $Etat.Dossier -Force
        }
    }
    Tester = {
        param($Ctx)
        $run = Get-PartUserValue -Root $Ctx.Root -Key $runRel -Name $runNom
        $script = Test-Path -LiteralPath (Join-Path $Ctx.Profil $scriptRel)
        $present = ($run.Exists -or $script)
        $d = 'démarrage : aucun lanceur en boucle'; if ($present) { $d = 'démarrage : lanceur en boucle présent (clé Run + script caché)' }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
