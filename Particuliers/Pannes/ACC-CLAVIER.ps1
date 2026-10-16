#requires -version 5.1
# ACC-CLAVIER : disposition anglaise (US) ajoutée et mise par défaut dans le profil du client.
# Voir Particuliers-Config.psd1. Les « é » tapent alors des « / », etc. Effet après réouverture de session.
# HKCU\Keyboard Layout\Preload : les entrées « 1 », « 2 »... listent les dispositions, « 1 » = active.
$key = 'Keyboard Layout\Preload'
$usKlid = '00000409'              # disposition « États-Unis » (QWERTY)
$slots = @('1', '2', '3', '4', '5', '6')
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        # Instantané de chaque emplacement possible (absents compris) : le retrait est alors exact.
        @{ Valeurs = @($slots | ForEach-Object { Get-PartUserValue -Root $Ctx.Root -Key $key -Name $_ }) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        $full = Join-Path $Ctx.Root $key
        # Dispositions actuelles dans l'ordre, puis l'anglais placé en tête (donc par défaut).
        $actuelles = @()
        foreach ($s in $slots) {
            $v = Get-PartUserValue -Root $Ctx.Root -Key $key -Name $s
            if ($v.Exists -and "$($v.Value)") { $actuelles += "$($v.Value)" }
        }
        $liste = @($usKlid) + @($actuelles | Where-Object { $_ -ne $usKlid })
        for ($i = 0; $i -lt $slots.Count; $i++) {
            $nom = $slots[$i]
            if ($i -lt $liste.Count) {
                Set-LabRegistryValue -Path $full -Name $nom -Value $liste[$i] -Type String
            } elseif (Test-Path -LiteralPath $full) {
                Remove-ItemProperty -LiteralPath $full -Name $nom -ErrorAction SilentlyContinue
            }
        }
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        $v = Get-PartUserValue -Root $Ctx.Root -Key $key -Name '1'
        $anglais = ($v.Exists -and "$($v.Value)" -eq $usKlid)
        $d = "disposition par défaut : $($v.Value)"
        if (-not $v.Exists) { $d = 'disposition par défaut : (aucune)' }
        @{ Ok = (-not $anglais); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
