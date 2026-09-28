#requires -version 5.1
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Installe les logiciels d'un poste AB (section « Logiciels » de AB/SPEC.md).

.DESCRIPTION
    Idempotent : un logiciel déjà détecté n'est pas réinstallé.
    Méthodes :
      Local  : installeurs de -SourceLocale (tools\installeurs par défaut), SHA256 vérifié.
      Winget : winget install, version figée, arguments silencieux du manifeste (+ --custom).
      Auto   : pour chaque logiciel, Local si son installeur est présent, sinon Winget.
    Chaque installeur a au plus -TimeoutMinutes : un installeur qui attend une fenêtre
    invisible est arrêté au lieu de bloquer le script.
    Après l'installation : mises à jour d'Acrobat coupées, raccourcis du Bureau public retirés.
    Journaux : <Get-LabDataPath>\Logs (transcription) et Logs\Install (MSI, winget).
    Code de sortie : 0 si tous les logiciels prévus sont présents, 1 sinon.

.EXAMPLE
    .\tools\Install-ABSoftware.ps1 -Poste PC-03 -Methode Local
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('PC-01', 'PC-02', 'PC-03', 'PC-04')][string]$Poste,
    [ValidateSet('Auto', 'Winget', 'Local')][string]$Methode = 'Auto',
    [string]$SourceLocale,
    [ValidateRange(5, 120)][int]$TimeoutMinutes = 30,
    [switch]$Force
)

# $PSScriptRoot est vide dans les valeurs par défaut de param en 5.1 (lancement par -File)
if (-not $SourceLocale) { $SourceLocale = Join-Path $PSScriptRoot 'installeurs' }
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\common\Lab-Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\AB\AB-Lab.psm1') -Force

# Codes de sortie d'installeur considérés comme réussis (3010/1641 : redémarrage requis)
$SuccessCodes = @(0, 3010, 1641)
$script:TimeoutMs = $TimeoutMinutes * 60 * 1000
$RebootCodes = @(3010, 1641)

function Get-WingetPath {
    <# Chemin de winget.exe utilisable, ou $null. PowerShell Direct n'a pas toujours l'alias. #>
    $candidates = @()
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += $cmd.Source }
    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($pkg) { $candidates += (Join-Path $pkg.InstallLocation 'winget.exe') }
    foreach ($c in $candidates) {
        if (-not (Test-Path -LiteralPath $c)) { continue }
        $v = & $c --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) { return $c }
    }
    return $null
}

function Stop-ProcessTree {
    param([int]$ProcessId)
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" | ForEach-Object { Stop-ProcessTree -ProcessId $_.ProcessId }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Wait-Installer {
    <#
    Attend la fin d'un processus d'installation, au plus -TimeoutMinutes.
    Un installeur qui attend une fenêtre invisible (session non interactive) est
    arrêté avec ses enfants au lieu de bloquer le script : code -2.
    #>
    param([Diagnostics.Process]$Process, [string]$Name)
    $null = $Process.Handle   # sans ce handle, ExitCode reste vide en 5.1 (Start-Process sans -Wait)
    if (-not $Process.WaitForExit($script:TimeoutMs)) {
        Write-LabWarn "$Name : aucune fin après $($script:TimeoutMs / 60000) min (fenêtre en attente?). Installation arrêtée."
        Stop-ProcessTree -ProcessId $Process.Id
        return -2
    }
    return $Process.ExitCode
}

function Invoke-Installer {
    <# Lance un installeur et retourne son code de sortie. #>
    param([string]$FilePath, [string]$Arguments, [string]$Type, [string]$Name)
    if ($Type -eq 'msi') {
        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$FilePath`" $Arguments" -PassThru -WindowStyle Hidden
    } else {
        $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    }
    return (Wait-Installer -Process $p -Name $Name)
}

function Install-ViaLocal {
    param($Logiciel, [string]$LogFile)
    $file = Join-Path $SourceLocale $Logiciel.Fichier
    if (-not (Test-Path -LiteralPath $file)) {
        Write-LabWarn "$($Logiciel.Nom) : installeur absent ($file). Lancer tools\Get-ABInstallers.ps1 sur l'hôte."
        return -1
    }
    if ($Logiciel.Sha256) {
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        if ($hash -ne $Logiciel.Sha256.ToUpper()) {
            Write-LabWarn "$($Logiciel.Nom) : SHA256 inattendu ($hash). Installation refusée."
            return -1
        }
    }
    $installArgs = $Logiciel.Arguments.Replace('{LOG}', $LogFile)
    Write-Verbose "$file $installArgs"
    return (Invoke-Installer -FilePath $file -Arguments $installArgs -Type $Logiciel.Type -Name $Logiciel.Nom)
}

function Install-ViaWinget {
    param($Logiciel, [string]$LogFile, [string]$Winget)
    $wingetLog = [IO.Path]::ChangeExtension($LogFile, '.winget.log')
    # Arguments silencieux du manifeste, sans --override ni --installer-type (voir AB-Config.psd1).
    # --scope machine seulement si la config le demande (WingetScope). Une installation
    # partie par utilisateur est vue absente (détection HKLM seulement) : l'erreur remonte.
    $installArgs = @(
        'install', '--id', $Logiciel.WingetId, '--exact', '--version', $Logiciel.Version,
        '--source', 'winget', '--silent',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity',
        '--log', $wingetLog
    )
    if ($Logiciel['WingetScope']) { $installArgs += @('--scope', $Logiciel['WingetScope']) }
    if ($Logiciel['WingetCustom']) { $installArgs += @('--custom', $Logiciel['WingetCustom']) }
    # Arguments cités à la manière de CommandLineToArgvW (l'override contient des guillemets)
    $line = ($installArgs | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        }) -join ' '
    # La sortie (barres de progression) va dans un fichier, pas à la console
    $out = [IO.Path]::ChangeExtension($LogFile, '.winget-sortie.txt')
    $p = Start-Process -FilePath $Winget -ArgumentList $line -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $out -RedirectStandardError "$out.err"
    return (Wait-Installer -Process $p -Name $Logiciel.Nom)
}

function Remove-PublicShortcut {
    param([string[]]$Patterns)
    $desktop = Join-Path $env:PUBLIC 'Desktop'
    foreach ($pat in $Patterns) {
        Get-ChildItem -LiteralPath $desktop -Filter $pat -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Write-LabOK "Raccourci public retiré : $($_.Name)"
        }
    }
}

# ---------------------------------------------------------------------------
$null = Start-LabLog -Name "Install-ABSoftware-$Poste"
$exitCode = 0
try {
    Assert-LabAdmin
    Assert-LabComputer -Expected "AB-$Poste" -Force:$Force
    $installLogDir = Get-LabDataPath -Child 'Logs\Install'
    $list = Get-ABSoftwareList -Poste $Poste
    Write-LabStep "Logiciels prévus pour AB-$Poste : $(($list | ForEach-Object { $_.Nom }) -join ', ')"

    $winget = $null
    if ($Methode -ne 'Local') {
        $winget = Get-WingetPath
        if ($winget) {
            Write-LabOK "winget : $winget ($(& $winget --version))"
        } elseif ($Methode -eq 'Winget') {
            throw "winget ne répond pas dans cette session. Utiliser -Methode Local."
        } else {
            Write-LabWarn "winget ne répond pas : méthode Local."
        }
    }

    $results = @()
    $rebootNeeded = $false
    foreach ($soft in $list) {
        Write-LabStep $soft.Nom
        $before = Test-ABSoftware -Logiciel $soft
        $action = 'Déjà présent'
        $code = $null
        if (-not $before) {
            $safeName = $soft.Nom -replace '[^\w.-]', '_'
            $log = Join-Path $installLogDir "$safeName-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            # Auto : l'installeur local vérifié d'abord (prévisible), winget sinon
            $useLocal = ($Methode -eq 'Local') -or (-not $winget) -or
                (($Methode -eq 'Auto') -and (Test-Path -LiteralPath (Join-Path $SourceLocale $soft.Fichier)))
            if (-not $useLocal -and $soft['Winget'] -eq $false) {
                Write-LabWarn "$($soft.Nom) : jamais par winget (raison dans AB-Config.psd1). Installeur local requis."
                $useLocal = $true
            }
            if ($useLocal) {
                $action = 'Local'
                $code = Install-ViaLocal -Logiciel $soft -LogFile $log
            } else {
                $action = 'Winget'
                $code = Install-ViaWinget -Logiciel $soft -LogFile $log -Winget $winget
            }
            if ($RebootCodes -contains $code) { $rebootNeeded = $true }
            if ($SuccessCodes -notcontains $code) { Write-LabWarn "$($soft.Nom) : code de sortie $code (journal : $log)" }
        }
        $after = Test-ABSoftware -Logiciel $soft
        if ($after) {
            Write-LabOK "$($after.DisplayName) $($after.Version)"
            if ($after.Version -and -not $after.Version.TrimStart('v').StartsWith(($soft.Version -split '\.')[0])) {
                Write-LabWarn "Version installée $($after.Version), version figée $($soft.Version)."
            }
        } else {
            Write-LabWarn "$($soft.Nom) introuvable après l'installation."
            $exitCode = 1
        }
        if ($soft.Raccourcis) { Remove-PublicShortcut -Patterns $soft.Raccourcis }
        $version = $null
        if ($after) { $version = $after.Version }
        $results += [pscustomobject]@{ Logiciel = $soft.Nom; Action = $action; Code = $code; Present = [bool]$after; Version = $version }
    }

    # Mises à jour automatiques coupées (état stable d'une équipe à l'autre)
    Write-LabStep 'Mises à jour des logiciels'
    $acrobat = $list | Where-Object { $_.Nom -eq 'Adobe Acrobat Reader' }
    if ($acrobat -and (Test-ABSoftware -Logiciel $acrobat)) {
        Disable-ABAcrobatUpdate
        if (Test-ABAcrobatUpdateDisabled) { Write-LabOK 'Acrobat : mises à jour coupées.' } else { Write-LabWarn 'Acrobat : mises à jour encore actives.'; $exitCode = 1 }
    }
    $lo = $list | Where-Object { $_.Nom -eq 'LibreOffice' }
    if ($lo) {
        $loFound = Test-ABSoftware -Logiciel $lo
        if ($loFound -and $loFound.ProductCode) {
            $loLog = Join-Path $installLogDir "LibreOffice-sans-maj-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            Disable-ABLibreOfficeUpdate -ProductCode $loFound.ProductCode -LogFile $loLog
            if (Test-ABLibreOfficeUpdateDisabled -ProductCode $loFound.ProductCode) {
                Write-LabOK 'LibreOffice : fonction de mise à jour retirée.'
            } else {
                Write-LabWarn "LibreOffice : la fonction de mise à jour est encore installée (journal : $loLog)."
                $exitCode = 1
            }
            # Source de réparation sur le serveur (R6-C), ajoutée par SOURCELIST à l'installation
            $sources = Get-ABMsiSourceList -ProductCode $loFound.ProductCode
            if ($lo['DossierServeur'] -and -not ($sources -match 'Logiciels\$')) {
                Write-LabWarn "LibreOffice : source réseau absente de la liste MSI ($($sources -join ' ; '))."
                $exitCode = 1
            } else {
                Write-LabOK "LibreOffice : sources MSI = $($sources -join ' ; ')"
            }
        }
    }

    Write-LabStep 'Résumé'
    $results | Format-Table -AutoSize | Out-String | Write-Host
    if ($rebootNeeded) { Write-LabWarn 'Un redémarrage est requis avant de prendre le point de contrôle.' }
    if ($exitCode -eq 0) { Write-LabOK "Tous les logiciels de AB-$Poste sont présents." }
} catch {
    Write-LabWarn $_.Exception.Message
    $exitCode = 1
} finally {
    Stop-LabLog
}
exit $exitCode
