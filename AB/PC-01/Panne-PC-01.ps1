#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    AB-PC-01 : R5 (lecteur S: vers l'ancien serveur) et R6 selon -Variante (poste de Nathalie).

.DESCRIPTION
    R5 (optionnelle, installée sauf -SansR5) : S: mappé de façon persistante vers
        \\AB-SERVEUR\Commun, l'ancien nom du serveur (ruche de ncote).
    R6 selon -Variante (même lettre que les autres requêtes de l'équipe) :
      A  Profil LibreOffice de Nathalie verrouillé par son ancien poste (AB-RECEPTION) :
         LibreOffice demande au démarrage s'il doit continuer (vérifié en VM).
      B  sur le serveur (Panne-SRV-01 : verrou du registre des factures). Rien ici.
      C  Installation de LibreOffice endommagée : soffice.bin retiré (réparation depuis
         \\AB-SRV-01\Logiciels$, vérifiée en VM).
      D  Police Montserrat du modèle de facture désinstallée (fichiers et registre).
      E  Sécurité des macros « Très élevé » sans emplacement de confiance : la macro de
         numérotation du modèle de facture est bloquée (barre « Macros désactivées »).
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
    $loRoot = Get-ABLibreOfficeRoot -Compte $Compte
    $lockFile = Join-Path $loRoot '.lock'
    $xcu = Join-Path $loRoot 'user\registrymodifications.xcu'
    function Get-FileState([string]$p) {
        $s = [ordered]@{ Chemin = $p; Existe = (Test-Path -LiteralPath $p); Contenu = $null }
        if ($s.Existe) { $s.Contenu = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) }
        return $s
    }
    switch ($Variante) {
        'A' { $state.R6 = [ordered]@{ Type = 'Fichier'; Fichier = (Get-FileState $lockFile) } }
        'C' { $state.R6 = [ordered]@{ Type = 'LibreOffice'; Present = (Test-Path -LiteralPath $soffice) } }
        'D' { $state.R6 = [ordered]@{ Type = 'Police'; Ecarts = @(Test-ABFont -Famille 'Montserrat') } }
        'E' { $state.R6 = [ordered]@{ Type = 'Fichier'; Fichier = (Get-FileState $xcu) } }
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
        'A' {
            # Format du verrou d'une installation utilisateur de LibreOffice (…\LibreOffice\4\.lock)
            $r6 = (Get-ABConfig).Pannes.R6
            $when = (Get-Date).AddDays(-3).ToString('ddd MMM dd HH:mm:ss yyyy', [Globalization.CultureInfo]::InvariantCulture)
            if (-not (Test-Path -LiteralPath $loRoot)) { New-Item -ItemType Directory -Path $loRoot -Force | Out-Null }
            Set-Content -LiteralPath $lockFile -Encoding ASCII -Value @('[Lockdata]', "User=$Compte", "Host=$($r6.VerrouProfilPoste)", "Stamp=$([guid]::NewGuid().ToString('N'))", "Time=$when", 'IPCServer=true')
            & icacls.exe $lockFile /setowner "$env:COMPUTERNAME\$Compte" /C /Q | Out-Null
            Write-LabOK "Profil LibreOffice de $Compte verrouillé par $($r6.VerrouProfilPoste)."
        }
        'B' { Write-LabOK 'R6-B : verrou posé sur le serveur par Panne-SRV-01.' }
        'E' {
            Set-ABLibreOfficeMacroConfig -Compte $Compte -Niveau 3 -Emplacements @()
            Write-LabOK 'Sécurité des macros « Très élevé », aucun emplacement de confiance.'
        }
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
