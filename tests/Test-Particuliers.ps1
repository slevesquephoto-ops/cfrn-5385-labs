#requires -version 5.1
<#
.SYNOPSIS
    Boucle de tests des pannes spontanées dans les VM PART-*-T (uniquement par Invoke-LabVM.ps1).

.DESCRIPTION
    Par VM : Reset (Propre), copie, comptes de départ, Verifier sur client absent (1).
    Pour chaque panne :
      empreinte E1 -> installation (1re : profil créé; suivantes : profil conservé)
      -> Verifier (0, seule la panne en échec) -> [RES-PROXY : proxy vu par le client]
      -> installation relancée (0) -> retrait (0) -> empreinte E2 = E1 (retrait exact)
      -> Verifier (0, propre) -> [RES-PROXY : plus de proxy].
    Puis : toutes les pannes ensemble -> Verifier (0) -> Retirer -Tout -> Verifier (0);
    travail de l'élève conservé; comptes sans mot de passe désactivés pendant la mise
    en situation; suppression du client -> comptes identiques à ceux du départ.
    Résultats : tableau à l'écran et tests\logs\Test-Particuliers-<date>\resultats.md.

.EXAMPLE
    .\tests\Test-Particuliers.ps1
    .\tests\Test-Particuliers.ps1 -VMs PART-W10-T -Pannes RES-PROXY
#>
[CmdletBinding()]
param(
    [string[]]$VMs = @('PART-W11-T', 'PART-W10-T'),
    [string]$Client = 'mbelanger',
    [string[]]$Pannes,
    [string]$Checkpoint = 'Propre',
    [switch]$Arreter
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Inv = Join-Path $PSScriptRoot 'Invoke-LabVM.ps1'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $PSScriptRoot "logs\Test-Particuliers-$Stamp"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Cfg = Import-PowerShellDataFile (Join-Path $RepoRoot 'Particuliers\Particuliers-Config.psd1')
if (-not $Pannes) { $Pannes = @($Cfg.Pannes | ForEach-Object { $_.Id }) }
$ClientPs1 = 'C:\Lab\Particuliers\Client.ps1'
$Sonde = 'C:\Lab\tests\PartSonde-Invite.ps1'

function Invoke-Step {
    param([string]$VM, [string]$Label, [string]$Script, [string[]]$Arguments = @())
    $out = & $Inv -VMName $VM -Action Run -ScriptPath $Script -ArgumentList $Arguments 2>&1 6>$null | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $LogDir "$VM-$Label.log") -Encoding UTF8
    return [pscustomobject]@{ Code = $code; Output = $out }
}
function Invoke-Client([string]$VM, [string]$Label, [string[]]$Arguments) { Invoke-Step $VM $Label $ClientPs1 (@('-Client', $Client) + $Arguments) }
function Invoke-Sonde([string]$VM, [string]$Label, [string]$Mode, [string]$Prefixe) {
    $r = Invoke-Step $VM $Label $Sonde @('-Mode', $Mode, '-Client', $Client)
    return @($r.Output | Where-Object { $_ -like "$Prefixe|*" })
}
function Get-Json($Output) {
    $line = $Output | Where-Object { $_ -like '{"machine"*' } | Select-Object -Last 1
    if ($line) { return ($line | ConvertFrom-Json) }
    return $null
}
function Test-Verif([string]$VM, [string]$Label, [string[]]$Echecs) {
    <# Verifier : code 0 et exactement ces contrôles en échec. Retourne 'OK' ou le détail. #>
    $r = Invoke-Client $VM $Label @('-Verifier')
    $j = Get-Json $r.Output
    $vus = @(); if ($j) { $vus = @($j.echecs) }
    if ($r.Code -eq 0 -and (($vus | Sort-Object) -join ',') -eq ((@($Echecs) | Sort-Object) -join ',')) { return 'OK' }
    return "ÉCHEC (code $($r.Code), échecs : $($vus -join ', '))"
}
function Test-Same([string[]]$A, [string[]]$B, [string]$Label) {
    if (($A -join "`n") -eq ($B -join "`n") -and $A.Count -gt 0) { return $true }
    Compare-Object $A $B | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" } |
        Set-Content -Path (Join-Path $LogDir "$Label-diff.txt") -Encoding UTF8
    return $false
}
function Mark([bool]$Ok) { if ($Ok) { 'OK' } else { 'ÉCHEC' } }

$results = @()
$globaux = @()
foreach ($vm in $VMs) {
    Write-Host "`n########## $vm" -ForegroundColor Cyan
    & $Inv -VMName $vm -Action Reset -Checkpoint $Checkpoint | Out-Null
    & $Inv -VMName $vm -Action Push -Path (Join-Path $RepoRoot 'common'), (Join-Path $RepoRoot 'AB'), (Join-Path $RepoRoot 'Particuliers') | Out-Null
    & $Inv -VMName $vm -Action Push -Path (Join-Path $PSScriptRoot 'PartSonde-Invite.ps1') -Destination 'C:\Lab\tests' | Out-Null

    $comptes0 = Invoke-Sonde $vm '00-comptes' 'Comptes' 'CPT'
    $vides = @($comptes0 | Where-Object { $_ -like '*|True' -and $_ -notlike "CPT|$($Cfg.Administrateur)|*" })
    $r = Invoke-Client $vm '01-verif-absent' @('-Verifier')
    $g = [ordered]@{ VM = $vm; 'Client absent (Verifier 1)' = (Mark ($r.Code -eq 1)) }

    $premiere = $true
    foreach ($id in $Pannes) {
        Write-Host "--- $id" -ForegroundColor Cyan
        $row = [ordered]@{ VM = $vm; Panne = $id }
        $e1 = Invoke-Sonde $vm "$id-1-emp" 'Empreinte' 'EMP'
        $r = Invoke-Client $vm "$id-2-installer" @('-Panne', $id)
        $profil = 'profil conservé'; if ($premiere) { $profil = 'Profil créé' }
        $row.Installer = Mark ($r.Code -eq 0 -and ($r.Output -match [regex]::Escape($profil)))
        if ($premiere) {
            $c = Invoke-Sonde $vm "$id-2b-comptes" 'Comptes' 'CPT'
            $encore = @($vides | Where-Object { $c -contains $_ })
            $g['Comptes sans mot de passe désactivés'] = "$(Mark (-not $encore)) ($(@($vides | ForEach-Object { $_.Split('|')[1] }) -join ', '))"
            $m = Invoke-Sonde $vm "$id-2c-marque" 'Marque' 'MARQUE'
            $g['Marque élève créée'] = Mark ($m -contains 'MARQUE|False')
        }
        $row.VerifPanne = Test-Verif $vm "$id-3-verif" @($id)
        if ($id -eq 'RES-PROXY') {
            $p = Invoke-Sonde $vm "$id-3b-proxy" 'Proxy' 'PROXY'
            $row.Fonctionnel = "panne : $(Mark ($p -contains 'PROXY|http://127.0.0.1:8080/'))"
        }
        $r = Invoke-Client $vm "$id-4-installer2" @('-Panne', $id)
        $row.Relance = Mark ($r.Code -eq 0)
        $r = Invoke-Client $vm "$id-5-retirer" @('-Panne', $id, '-Retirer')
        $row.Retrait = Mark ($r.Code -eq 0)
        $e2 = Invoke-Sonde $vm "$id-6-emp" 'Empreinte' 'EMP'
        if ($premiere) { $row.Empreinte = 'n/a (profil créé)' } else { $row.Empreinte = Mark (Test-Same $e1 $e2 "$vm-$id-empreinte") }
        $row.VerifPropre = Test-Verif $vm "$id-7-verif" @()
        if ($id -eq 'RES-PROXY') {
            $p = Invoke-Sonde $vm "$id-7b-proxy" 'Proxy' 'PROXY'
            $row.Fonctionnel += " ; retrait : $(Mark ($p -contains 'PROXY|http://example.com/'))"
        }
        if ($premiere -and $Pannes.Count -gt 0) {
            # 1re panne : l'empreinte E1 précède la création du client; on refait un cycle sur le profil existant
            $e1 = Invoke-Sonde $vm "$id-8-emp" 'Empreinte' 'EMP'
            $r1 = Invoke-Client $vm "$id-9-installer" @('-Panne', $id)
            $r2 = Invoke-Client $vm "$id-10-retirer" @('-Panne', $id, '-Retirer')
            $e2 = Invoke-Sonde $vm "$id-11-emp" 'Empreinte' 'EMP'
            $row.Empreinte = "2e cycle : $(Mark ($r1.Code -eq 0 -and $r2.Code -eq 0 -and ($r1.Output -match 'profil conservé') -and (Test-Same $e1 $e2 "$vm-$id-empreinte")))"
        }
        $premiere = $false
        $results += [pscustomobject]$row
        ([pscustomobject]$row) | Format-List | Out-String | Write-Host
    }

    Write-Host '--- Pannes superposées' -ForegroundColor Cyan
    $e1 = Invoke-Sonde $vm 'pile-1-emp' 'Empreinte' 'EMP'
    $ok = $true
    foreach ($id in $Pannes) { $r = Invoke-Client $vm "pile-2-$id" @('-Panne', $id); $ok = $ok -and ($r.Code -eq 0) }
    $g['Pile : installation'] = Mark $ok
    $g['Pile : Verifier'] = Test-Verif $vm 'pile-3-verif' $Pannes
    $r = Invoke-Client $vm 'pile-4-tout' @('-Retirer', '-Tout')
    $e2 = Invoke-Sonde $vm 'pile-5-emp' 'Empreinte' 'EMP'
    $g['Pile : Retirer -Tout'] = Mark ($r.Code -eq 0 -and (Test-Same $e1 $e2 "$vm-pile-empreinte"))
    $g['Pile : Verifier propre'] = Test-Verif $vm 'pile-6-verif' @()
    $m = Invoke-Sonde $vm 'marque-2' 'Marque' 'MARQUE'
    $g['Travail élève conservé'] = Mark ($m -contains 'MARQUE|True')

    Write-Host '--- Suppression du client' -ForegroundColor Cyan
    $null = Invoke-Client $vm 'sup-0-panne' @('-Panne', $Pannes[0])
    $r = Invoke-Client $vm 'sup-1-supprimer' @('-Supprimer')
    $c = Invoke-Sonde $vm 'sup-2-comptes' 'Comptes' 'CPT'
    $g['Supprimer (avec panne) : comptes d''origine'] = Mark ($r.Code -eq 0 -and (Test-Same $comptes0 $c "$vm-comptes"))
    $enAttente = [bool]($r.Output -match 'retient encore le profil')
    $r = Invoke-Client $vm 'sup-3-verif' @('-Verifier')
    $g['Après suppression (Verifier 1)'] = Mark ($r.Code -eq 1)
    if ($enAttente) {
        # Profil retenu par Windows : replacer le client est refusé jusqu'au redémarrage,
        # puis le profil est supprimé au premier lancement qui suit.
        $r = Invoke-Client $vm 'sup-4-replacer' @('-Panne', $Pannes[0])
        $g['Profil en attente : replacer refusé'] = Mark ($r.Code -ne 0 -and ($r.Output -match 'redémarrer le poste'))
        $null = Invoke-Sonde $vm 'sup-5-redemarrer' 'Redemarrer' 'REDEMARRAGE'
        Start-Sleep -Seconds 20
        $deadline = (Get-Date).AddSeconds(300); $pret = $false
        while (-not $pret -and (Get-Date) -lt $deadline) {
            try { & $Inv -VMName $vm -Action Ping *> $null; $pret = $true } catch { Start-Sleep -Seconds 10 }
        }
        $r = Invoke-Step $vm 'sup-6-liste' $ClientPs1 @('-Liste')
        $pr = Invoke-Sonde $vm 'sup-7-profils' 'Profils' 'DIR'
        $g['Profil en attente : supprimé après redémarrage'] = Mark ($pret -and $r.Code -eq 0 -and ($pr -notcontains "DIR|$Client"))
    } else {
        $pr = Invoke-Sonde $vm 'sup-7-profils' 'Profils' 'DIR'
        $g['Profil supprimé'] = Mark ($pr -notcontains "DIR|$Client")
    }
    $globaux += [pscustomobject]$g
    ([pscustomobject]$g) | Format-List | Out-String | Write-Host
    if ($Arreter) { & $Inv -VMName $vm -Action Stop | Out-Null }
}

$results | Format-Table -AutoSize -Wrap | Out-String -Width 250 | Write-Host
$globaux | Format-List | Out-String -Width 250 | Write-Host
$md = @("# Test-Particuliers ($Stamp), client $Client", '', '| VM | Panne | Installer | Vérif. panne | Relance | Retrait | Empreinte | Vérif. propre | Fonctionnel |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
foreach ($r in $results) {
    $f = ''; if ($r.PSObject.Properties['Fonctionnel']) { $f = $r.Fonctionnel }
    $md += "| $($r.VM) | $($r.Panne) | $($r.Installer) | $($r.VerifPanne) | $($r.Relance) | $($r.Retrait) | $($r.Empreinte) | $($r.VerifPropre) | $f |"
}
foreach ($g in $globaux) {
    $md += ''; $md += "## $($g.VM)"; $md += ''
    foreach ($p in $g.PSObject.Properties) { if ($p.Name -ne 'VM') { $md += "- $($p.Name) : $($p.Value)" } }
}
$md | Set-Content -Path (Join-Path $LogDir 'resultats.md') -Encoding UTF8
Write-Host "Journaux : $LogDir"
$tout = @($results) + @($globaux)
if ($tout | Where-Object { ($_.PSObject.Properties.Value -join ' ') -match 'ÉCHEC' }) { exit 1 }
exit 0
