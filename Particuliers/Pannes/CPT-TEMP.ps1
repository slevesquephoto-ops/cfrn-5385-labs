#requires -version 5.1
# CPT-TEMP : profil temporaire forcé pour le client (profil du client). Voir Particuliers-Config.psd1.
# L'inscription du profil (HKLM\...\ProfileList\<SID>) est renommée en « <SID>.bak » : à sa prochaine
# ouverture de session, Windows ne retrouve plus le profil et ouvre un PROFIL TEMPORAIRE. « Tous mes
# fichiers ont disparu! » Les données restent sur le disque (dossier du profil intact).
# À DONNER SEULE : incompatible avec les autres pannes de profil (le moteur ne peut plus monter la ruche).
# Le moteur (Invoke-PartWithContext) tolère la ruche non montable au retrait (Root = $null) et cette
# panne n'utilise pas HKCU : elle se retire proprement en renommant la clé à l'envers.
$base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Sid = $Ctx.Sid }
    }
    Installer = {
        param($Ctx, $Etat)
        if ($Ctx.SessionOuverte) { throw 'Session du client ouverte : fermer la session avant de forcer le profil temporaire.' }
        $cle = Join-Path $base $Etat.Sid
        $bak = "$cle.bak"
        if (-not (Test-Path -LiteralPath $cle)) { throw "Inscription de profil introuvable pour le SID $($Etat.Sid)." }
        if (Test-Path -LiteralPath $bak) { throw "Une inscription « .bak » existe déjà pour $($Etat.Sid) : intervention manuelle requise." }
        Rename-Item -LiteralPath $cle -NewName "$($Etat.Sid).bak"
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        $cle = Join-Path $base $Etat.Sid
        $bak = "$cle.bak"
        # Remettre l'inscription d'origine. Si un vrai profil a été recréé entre-temps, ne pas écraser.
        if ((Test-Path -LiteralPath $bak) -and -not (Test-Path -LiteralPath $cle)) {
            Rename-Item -LiteralPath $bak -NewName $Etat.Sid
        }
    }
    Tester = {
        param($Ctx)
        $cle = Join-Path $base $Ctx.Sid
        $bak = "$cle.bak"
        $panne = ((Test-Path -LiteralPath $bak) -or -not (Test-Path -LiteralPath $cle))
        $d = 'inscription de profil normale'; if ($panne) { $d = 'inscription de profil renommée (.bak) : profil temporaire au prochain logon' }
        @{ Ok = (-not $panne); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
