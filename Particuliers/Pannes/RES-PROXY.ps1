#requires -version 5.1
# RES-PROXY : proxy 127.0.0.1:8080 dans le profil du client. Voir Particuliers-Config.psd1.
# Windows lit le réglage binaire Connections\DefaultConnectionSettings (ProxyEnable et
# ProxyServer n'en sont qu'un reflet : seuls, ils sont ignorés, vu en VM). La panne écrit
# donc les deux, comme le fait l'écran Proxy des Paramètres.
$is = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$cn = "$is\Connections"
$proxy = '127.0.0.1:8080'
$exceptions = '<local>'
$valeurs = @(
    @{ Key = $is; Name = 'ProxyEnable' }
    @{ Key = $is; Name = 'ProxyServer' }
    @{ Key = $is; Name = 'ProxyOverride' }
    @{ Key = $cn; Name = 'DefaultConnectionSettings' }
    @{ Key = $cn; Name = 'SavedLegacySettings' }
)

$getFlag = {
    param([byte[]]$Blob)
    # Octets 8 à 11 : indicateurs (1 direct, 2 proxy manuel, 4 script, 8 détection auto)
    if (-not $Blob -or $Blob.Length -lt 12) { return $null }
    return [BitConverter]::ToInt32($Blob, 8)
}

$blocs = @{
    Sauvegarder = {
        param($Ctx)
        @{ Valeurs = @($valeurs | ForEach-Object { Get-PartUserValue -Root $Ctx.Root -Key $_.Key -Name $_.Name }) }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Etat
        $k = Join-Path $Ctx.Root $is
        Set-LabRegistryValue -Path $k -Name 'ProxyEnable' -Value 1 -Type DWord
        Set-LabRegistryValue -Path $k -Name 'ProxyServer' -Value $proxy -Type String
        Set-LabRegistryValue -Path $k -Name 'ProxyOverride' -Value $exceptions -Type String
        # Version et compteur repris du réglage existant (compteur + 1), sinon version 0x46
        $c = Join-Path $Ctx.Root $cn
        $old = (Get-LabRegistrySnapshot -Path $c -Name 'DefaultConnectionSettings').Value
        $version = 0x46; $compteur = 0
        if ($old -and $old.Length -ge 8) { $version = [BitConverter]::ToInt32($old, 0); $compteur = [BitConverter]::ToInt32($old, 4) + 1 }
        $p = [Text.Encoding]::ASCII.GetBytes($proxy)
        $e = [Text.Encoding]::ASCII.GetBytes($exceptions)
        $blob = New-Object System.Collections.Generic.List[byte]
        foreach ($n in $version, $compteur, 3, $p.Length) { $blob.AddRange([BitConverter]::GetBytes([int]$n)) }
        $blob.AddRange($p)
        $blob.AddRange([BitConverter]::GetBytes([int]$e.Length))
        $blob.AddRange($e)
        $blob.AddRange((New-Object byte[] 36))   # script de configuration (longueur 0) et champs de détection
        foreach ($n in 'DefaultConnectionSettings', 'SavedLegacySettings') { Set-LabRegistryValue -Path $c -Name $n -Value $blob.ToArray() -Type Binary }
    }
    Retirer = {
        param($Ctx, $Etat)
        foreach ($v in @($Etat.Valeurs)) { Restore-PartUserValue -Root $Ctx.Root -Snapshot $v }
    }
    Tester = {
        param($Ctx)
        # Le réglage binaire fait foi s'il existe (c'est lui que l'écran Proxy modifie)
        $blob = (Get-LabRegistrySnapshot -Path (Join-Path $Ctx.Root $cn) -Name 'DefaultConnectionSettings').Value
        $flag = & $getFlag $blob
        $en = Get-PartUserValue -Root $Ctx.Root -Key $is -Name 'ProxyEnable'
        $sv = Get-PartUserValue -Root $Ctx.Root -Key $is -Name 'ProxyServer'
        if ($null -ne $flag) { $actif = (($flag -band 2) -ne 0) } else { $actif = ($en.Exists -and [int]$en.Value -eq 1) }
        $d = 'aucun proxy'
        if ($actif) { $d = "proxy actif : $($sv.Value)" }
        @{ Ok = (-not $actif); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
