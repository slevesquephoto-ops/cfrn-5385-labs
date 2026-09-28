#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-01 : R5 (lecteur S: vers l'ancien serveur) et R6 selon -Variante (poste de Nathalie).

.DESCRIPTION
    R5 (optionnelle, installée sauf -SansR5) : S: mappé de façon persistante vers
        \\AB-SERVEUR\Commun, l'ancien nom du serveur (ruche de ncote).
    R6 selon -Variante (même lettre que les autres requêtes de l'équipe) :
      A  EN ATTENTE DE DÉCISION : la corruption du profil LibreOffice n'a pas de symptôme
         (vérifié en VM). Rien d'installé pour R6.
      B  sur le serveur (Panne-SRV-01 : verrou du registre des factures). Rien ici.
      C  Installation de LibreOffice endommagée : soffice.bin retiré (réparation depuis
         \\AB-SRV-01\Logiciels$, vérifiée en VM).
      D  Police Montserrat du modèle de facture désinstallée (fichiers et registre).
      E  EN ATTENTE DE DÉCISION : « Microsoft Print to PDF » ne se réactive pas de façon
         fiable (0x800f0922, vérifié en VM). Rien d'installé pour R6.
    Tout ce qui est modifié est enregistré avant (état 'PC-01') pour un retrait exact.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('A', 'B', 'C', 'D', 'E')][string]$Variante,
    [switch]$SansR5,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-01'
$Compte = 'ncote'
$null = Start-LabLog -Name "Panne-$Machine-$Variante"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $existing = Get-LabState -Scenario $Machine
    if ($existing) {
        if ($existing.Variante -eq $Variante) { Write-LabOK "Panne $Variante déjà installée : rien à refaire."; return }
        throw "La panne $($existing.Variante) est installée. Lancer Retrait-$Machine.ps1 avant d'installer $Variante."
    }
    $soffice = 'C:\Program Files\LibreOffice\program\soffice.bin'
    $backup = Join-Path (Get-LabDataPath -Child 'State') 'PC-01-soffice.bin'

    Write-LabStep 'Enregistrement de l''état d''origine'
    $state = [ordered]@{ Variante = $Variante; Date = (Get-Date).ToString('s'); R5 = $null; R6 = $null }
    if (-not $SansR5) {
        $state.R5 = Invoke-ABUserHive -Compte $Compte -ScriptBlock {
            param($Root)
            Get-LabRegistrySnapshot -Path (Join-Path $Root 'Network\S') -Name 'RemotePath'
        } | Select-Object Exists, Value
    }
    switch ($Variante) {
        'C' { $state.R6 = [ordered]@{ Type = 'LibreOffice'; Present = (Test-Path -LiteralPath $soffice) } }
        'D' { $state.R6 = [ordered]@{ Type = 'Police'; Ecarts = @(Test-ABFont -Famille 'Montserrat') } }
    }
    if (-not (Save-LabState -Scenario $Machine -Data $state)) { throw 'État déjà présent : installation interrompue.' }
    Write-LabOK 'État enregistré.'

    if (-not $SansR5) {
        Write-LabStep 'R5 : lecteur S: vers l''ancien serveur'
        Invoke-ABUserHive -Compte $Compte -ScriptBlock {
            param($Root)
            Set-LabRegistryValue -Path (Join-Path $Root 'Network\S') -Name 'RemotePath' -Value '\\AB-SERVEUR\Commun' -Type String
        }
        Write-LabOK 'S: -> \\AB-SERVEUR\Commun'
    }

    Write-LabStep "R6 : variante $Variante"
    switch ($Variante) {
        { $_ -in 'A', 'E' } { Write-LabWarn "R6-$Variante en attente de décision (voir le rapport) : rien d'installé pour R6." }
        'B' { Write-LabOK 'R6-B : verrou posé sur le serveur par Panne-SRV-01.' }
        'C' {
            if (-not (Test-Path -LiteralPath $soffice)) { throw 'soffice.bin déjà absent : Setup ou réparation à faire d''abord.' }
            Move-Item -LiteralPath $soffice -Destination $backup -Force
            Write-LabOK 'soffice.bin retiré (installation endommagée).'
        }
        'D' {
            foreach ($f in Get-ABFontList -Famille 'Montserrat') {
                Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $f.Nom -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath (Join-Path $env:windir "Fonts\$($f.Fichier)") -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-ABFont -Famille 'Montserrat')) { throw 'Montserrat encore installée.' }
            Write-LabOK 'Montserrat désinstallée.'
        }
    }
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
