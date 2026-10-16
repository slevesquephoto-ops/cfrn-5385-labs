#requires -version 5.1
# FIC-CACHES : dossiers personnels du client marqués « cachés + système » (profil du client).
# Voir Particuliers-Config.psd1. Classique après une clé USB infectée. Les dossiers « disparaissent »
# tant qu'on n'affiche pas les éléments cachés ET protégés du système.
$cibles = @('Documents', 'Pictures', 'Desktop', 'Downloads')
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        # Attributs d'origine de chaque dossier existant (entier) : le retrait est alors exact.
        $etat = @()
        foreach ($c in $cibles) {
            $p = Join-Path $Ctx.Profil $c
            if (Test-Path -LiteralPath $p) {
                $etat += @{ Path = $p; Attrs = [int](Get-Item -LiteralPath $p -Force).Attributes }
            }
        }
        @{ Dossiers = $etat }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($d in @($Etat.Dossiers)) {
            if (Test-Path -LiteralPath $d.Path) {
                $i = Get-Item -LiteralPath $d.Path -Force
                $i.Attributes = [IO.FileAttributes]($i.Attributes -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System)
            }
        }
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        foreach ($d in @($Etat.Dossiers)) {
            if (Test-Path -LiteralPath $d.Path) {
                $i = Get-Item -LiteralPath $d.Path -Force
                $i.Attributes = [IO.FileAttributes]([int]$d.Attrs)
            }
        }
    }
    Tester = {
        param($Ctx)
        $caches = @()
        foreach ($c in $cibles) {
            $p = Join-Path $Ctx.Profil $c
            if (Test-Path -LiteralPath $p) {
                if ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::Hidden) { $caches += $c }
            }
        }
        $d = 'aucun dossier caché'; if ($caches.Count) { $d = "cachés : $($caches -join ', ')" }
        @{ Ok = ($caches.Count -eq 0); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
