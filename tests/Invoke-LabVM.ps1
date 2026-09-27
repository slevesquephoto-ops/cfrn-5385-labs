#requires -version 5.1
<#
.SYNOPSIS
    Seul point d'entrée vers les VM de test Hyper-V (PowerShell Direct).

.DESCRIPTION
    Garde-fous :
      1. Le nom de la VM doit finir par -T (ex. AB-PC-03-T).
      2. Une VM dont les notes contiennent [NE-PAS-TOUCHER] est toujours refusée.
    Aucune action ne supprime une VM, un commutateur ou un point de contrôle.

.EXAMPLE
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Status
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Ping
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Reset
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Push -Path .\common, .\AB
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Run -ScriptPath C:\Lab\AB\PC-03\Panne-PC-03.ps1 -ArgumentList '-Variante','A'
    .\tests\Invoke-LabVM.ps1 -VMName AB-PC-03-T -Action Pull -Source C:\ProgramData\CFRN-Lab\Logs
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z]{2,4}-[A-Za-z0-9-]+-T$')]
    [string]$VMName,

    [Parameter(Mandatory)]
    [ValidateSet('Status', 'Ping', 'Reset', 'Push', 'Run', 'Pull')]
    [string]$Action,

    # Push : dossiers ou fichiers locaux, copiés sous $Destination\<nom>
    [string[]]$Path,
    [string]$Destination = 'C:\Lab',

    # Run : script dans la VM, exécuté par powershell.exe -File (processus isolé)
    [string]$ScriptPath,
    [string[]]$ArgumentList = @(),

    # Pull : dossier ou fichier dans la VM, copié sous tests\logs\<VMName>\
    [string]$Source,

    [string]$Checkpoint = 'Propre',
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SecretDir = Join-Path $HOME '.lab'

# --- Garde-fous --------------------------------------------------------------
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) { throw "VM introuvable : $VMName" }
if ($vm.Notes -match '\[NE-PAS-TOUCHER\]') { throw "Refusé : $VMName est marquée [NE-PAS-TOUCHER]." }

function Get-GuestCredential {
    $specific = Join-Path $SecretDir "$VMName.xml"
    $default = Join-Path $SecretDir 'ab-tech.xml'
    if (Test-Path $specific) { return (Import-Clixml $specific) }
    if (Test-Path $default) { return (Import-Clixml $default) }
    throw "Aucun identifiant pour $VMName. Lancer tools\Setup-LabSecrets.ps1."
}

function Wait-GuestReady {
    param([pscredential]$Credential)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $null = Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
            return
        } catch {
            Start-Sleep -Seconds 5
        }
    }
    throw "La VM $VMName ne répond pas à PowerShell Direct après $TimeoutSeconds s."
}

function New-GuestSession {
    $cred = Get-GuestCredential
    if ($vm.State -ne 'Running') { throw "$VMName n'est pas démarrée (état : $($vm.State)). Utiliser -Action Reset." }
    return (New-PSSession -VMName $VMName -Credential $cred)
}

# --- Actions -----------------------------------------------------------------
switch ($Action) {

    'Status' {
        $vm | Select-Object Name, State, Uptime, Notes,
            @{ n = 'Checkpoints'; e = { (Get-VMSnapshot -VMName $VMName | Select-Object -ExpandProperty Name) -join ', ' } },
            @{ n = 'Heartbeat';   e = { (Get-VMIntegrationService -VMName $VMName | Where-Object Id -Match '84EAAE65' | Select-Object -ExpandProperty PrimaryStatusDescription) } } |
            Format-List
    }

    'Ping' {
        $cred = Get-GuestCredential
        Invoke-Command -VMName $VMName -Credential $cred -ScriptBlock {
            [pscustomobject]@{
                Ordinateur = $env:COMPUTERNAME
                Utilisateur = "$env:USERDOMAIN\$env:USERNAME"
                PowerShell = $PSVersionTable.PSVersion.ToString()
                Windows = (Get-CimInstance Win32_OperatingSystem).Caption
                Build = [Environment]::OSVersion.Version.Build
            }
        } | Select-Object Ordinateur, Utilisateur, PowerShell, Windows, Build | Format-List
    }

    'Reset' {
        $snap = Get-VMSnapshot -VMName $VMName -Name $Checkpoint -ErrorAction SilentlyContinue
        if (-not $snap) { throw "Point de contrôle '$Checkpoint' absent sur $VMName. L'enseignant doit le créer." }
        Write-Host "Restauration de $VMName au point '$Checkpoint'..."
        Restore-VMSnapshot -VMSnapshot $snap -Confirm:$false
        if ((Get-VM -Name $VMName).State -ne 'Running') { Start-VM -Name $VMName }
        Wait-GuestReady -Credential (Get-GuestCredential)
        Write-Host "[OK] $VMName prête."
    }

    'Push' {
        if (-not $Path) { throw "Push : préciser -Path." }
        $s = New-GuestSession
        try {
            Invoke-Command -Session $s -ScriptBlock {
                param($d) if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            } -ArgumentList $Destination
            foreach ($p in $Path) {
                $full = (Resolve-Path $p).Path
                $leaf = Split-Path -Leaf $full
                $target = Join-Path $Destination $leaf
                Invoke-Command -Session $s -ScriptBlock {
                    param($t) if (Test-Path $t) { Remove-Item -Path $t -Recurse -Force }
                } -ArgumentList $target
                Copy-Item -Path $full -Destination $target -ToSession $s -Recurse -Force
                Write-Host "[OK] $leaf -> $VMName`:$target"
            }
        } finally { Remove-PSSession $s }
    }

    'Run' {
        if (-not $ScriptPath) { throw "Run : préciser -ScriptPath (chemin dans la VM)." }
        $s = New-GuestSession
        try {
            $result = Invoke-Command -Session $s -ScriptBlock {
                param($script, $argsList)
                if (-not (Test-Path $script)) { throw "Script absent dans la VM : $script" }
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @argsList 2>&1 | ForEach-Object { "$_" }
                [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
            } -ArgumentList $ScriptPath, $ArgumentList
        } finally { Remove-PSSession $s }
        $result.Output | ForEach-Object { Write-Output $_ }
        Write-Host "--- Code de sortie : $($result.ExitCode)"
        exit $result.ExitCode
    }

    'Pull' {
        if (-not $Source) { throw "Pull : préciser -Source (chemin dans la VM)." }
        $local = Join-Path $RepoRoot "tests\logs\$VMName"
        if (-not (Test-Path $local)) { New-Item -ItemType Directory -Path $local -Force | Out-Null }
        $s = New-GuestSession
        try {
            Copy-Item -Path $Source -Destination $local -FromSession $s -Recurse -Force
        } finally { Remove-PSSession $s }
        Write-Host "[OK] $Source -> $local"
    }
}
