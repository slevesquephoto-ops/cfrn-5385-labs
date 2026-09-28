#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-01 : retire R5 et R6 depuis l'état enregistré par Panne-PC-01.ps1.

.DESCRIPTION
    R5 : RemotePath de S: remis à sa valeur d'origine. R6-C : soffice.bin remis depuis la
    sauvegarde (sauf si les élèves ont réparé). R6-D : Montserrat réinstallée pour tous.
    Sans état : rien à faire. Le Setup suivant recrée de toute façon le profil de ncote.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force

$Machine = 'PC-01'
$Compte = 'ncote'
$null = Start-LabLog -Name "Retrait-$Machine"
$exitCode = 0
try {
    Assert-LabComputer -Expected "AB-$Machine" -Force:$Force
    $state = Get-LabState -Scenario $Machine
    if (-not $state) { Write-LabOK 'Aucune panne installée : rien à retirer.'; return }

    if ($state.R5) {
        Write-LabStep 'R5 : lecteur S:'
        $r5 = $state.R5
        Invoke-ABUserHive -Compte $Compte -ScriptBlock {
            param($Root)
            $k = Join-Path $Root 'Network\S'
            if ($r5.Exists) { Set-LabRegistryValue -Path $k -Name 'RemotePath' -Value $r5.Value -Type String }
            else { Remove-ItemProperty -LiteralPath $k -Name 'RemotePath' -ErrorAction SilentlyContinue }
        }
        Write-LabOK "S: -> $($r5.Value)"
    }

    if ($state.R6) {
        Write-LabStep "R6 : variante $($state.Variante)"
        switch ($state.R6.Type) {
            'LibreOffice' {
                $soffice = 'C:\Program Files\LibreOffice\program\soffice.bin'
                $backup = Join-Path (Get-LabDataPath -Child 'State') 'PC-01-soffice.bin'
                if (-not (Test-Path -LiteralPath $soffice)) { Move-Item -LiteralPath $backup -Destination $soffice -Force; Write-LabOK 'soffice.bin remis.' }
                else { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue; Write-LabOK 'LibreOffice déjà réparé par les élèves.' }
            }
            'Police' { Install-ABFont -Famille 'Montserrat'; Write-LabOK 'Montserrat réinstallée pour tous les utilisateurs.' }
            'Fichier' {
                # A : verrou du profil; E : registrymodifications.xcu (octet pour octet)
                $f = $state.R6.Fichier
                if ($f.Existe) { [IO.File]::WriteAllBytes($f.Chemin, [Convert]::FromBase64String($f.Contenu)); & icacls.exe $f.Chemin /setowner "$env:COMPUTERNAME\$Compte" /C /Q | Out-Null }
                elseif (Test-Path -LiteralPath $f.Chemin) { Remove-Item -LiteralPath $f.Chemin -Force }
                Write-LabOK "$(Split-Path -Leaf $f.Chemin) remis dans son état d'origine."
            }
        }
    }

    Remove-LabState -Scenario $Machine
    Write-LabOK 'Panne retirée.'
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
