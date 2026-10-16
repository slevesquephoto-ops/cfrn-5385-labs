#requires -version 5.1
# RES-HOSTS : des sites neutres renvoyés vers une adresse morte dans le fichier hosts (tout le poste).
$hosts = Join-Path $env:windir 'System32\drivers\etc\hosts'
$sites = @('meteomedia.com', 'www.meteomedia.com', 'ici.radio-canada.ca')
$marque = '0.0.0.0'
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $null = $Ctx
        $contenu = ''
        if (Test-Path -LiteralPath $hosts) { $contenu = [Convert]::ToBase64String([IO.File]::ReadAllBytes($hosts)) }
        @{ Existe = (Test-Path -LiteralPath $hosts); Contenu = $contenu }
    }
    Installer = {
        param($Ctx, $Etat)
        $null = $Ctx, $Etat
        $lignes = @('', '# Controle parental - ne pas modifier')
        foreach ($s in $sites) { $lignes += "$marque`t$s" }
        if (-not (Test-Path -LiteralPath $hosts)) { New-Item -ItemType File -Path $hosts -Force | Out-Null }
        Add-Content -LiteralPath $hosts -Value $lignes -Encoding ASCII
    }
    Retirer = {
        param($Ctx, $Etat)
        $null = $Ctx
        if ($Etat.Existe) { [IO.File]::WriteAllBytes($hosts, [Convert]::FromBase64String([string]$Etat.Contenu)) }
        elseif (Test-Path -LiteralPath $hosts) { Remove-Item -LiteralPath $hosts -Force }
        Clear-DnsClientCache
    }
    Tester = {
        param($Ctx)
        $null = $Ctx
        $present = $false
        if (Test-Path -LiteralPath $hosts) {
            $present = [bool](Get-Content -LiteralPath $hosts | Where-Object { $_ -match [regex]::Escape($sites[0]) -and $_ -match '^\s*0\.0\.0\.0' })
        }
        $d = 'hosts propre'; if ($present) { $d = 'hosts détourne des sites' }
        @{ Ok = (-not $present); Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
