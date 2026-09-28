#requires -version 5.1
<#
AB-Lab.psm1 - Fonctions propres à Architecture Boréale, partagées par les scripts
AB (Setup, Panne, Retrait, Verifier) et par tools\Install-ABSoftware.ps1.
S'appuie sur common\Lab-Common.psm1 (à importer avant).
Import : Import-Module (Join-Path $PSScriptRoot '..\AB-Lab.psm1') -Force
#>

Set-StrictMode -Version 2.0

$script:ABConfigPath = Join-Path $PSScriptRoot 'AB-Config.psd1'
$script:ABConfig = $null

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
function Get-ABConfig {
    <# Retourne la configuration AB (AB-Config.psd1), lue une seule fois. #>
    if (-not $script:ABConfig) {
        $script:ABConfig = Import-PowerShellDataFile -Path $script:ABConfigPath
    }
    return $script:ABConfig
}

function Get-ABSoftwareList {
    <# Logiciels actifs prévus pour un poste (PC-01..PC-04). #>
    param([Parameter(Mandatory)][string]$Poste)
    @((Get-ABConfig).Logiciels | Where-Object { $_.Actif -and ($_.Postes -contains $Poste) })
}

# ---------------------------------------------------------------------------
# Logiciels installés (clés Uninstall de HKLM, 64 et 32 bits)
# ---------------------------------------------------------------------------
function Get-ABInstalledProgram {
    <# Liste { DisplayName; DisplayVersion; KeyName; UninstallString } des programmes installés pour la machine. #>
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root) {
            $name = $key.GetValue('DisplayName', $null)
            if (-not $name) { continue }
            [pscustomobject]@{
                DisplayName     = [string]$name
                DisplayVersion  = [string]$key.GetValue('DisplayVersion', '')
                KeyName         = $key.PSChildName
                UninstallString = [string]$key.GetValue('UninstallString', '')
            }
        }
    }
}

function Test-ABSoftware {
    <#
    Cherche un logiciel de la config. Retourne $null s'il est absent, sinon
    { Nom; DisplayName; Version; ProductCode } (ProductCode : GUID si MSI).
    #>
    param([Parameter(Mandatory)]$Logiciel)
    $found = Get-ABInstalledProgram | Where-Object { $_.DisplayName -match $Logiciel.Detection } | Select-Object -First 1
    if (-not $found) { return $null }
    $code = $null
    if ($found.KeyName -match '^\{[0-9A-Fa-f-]{36}\}$') { $code = $found.KeyName }
    [pscustomobject]@{ Nom = $Logiciel.Nom; DisplayName = $found.DisplayName; Version = $found.DisplayVersion; ProductCode = $code }
}

# ---------------------------------------------------------------------------
# Mises à jour des logiciels (coupées pour garder un état stable entre équipes)
# ---------------------------------------------------------------------------
$script:AcrobatPolicyKeys = @(
    'HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown',
    'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
)

function Disable-ABAcrobatUpdate {
    <# Stratégie bUpdater=0, service et tâche de mise à jour d'Adobe désactivés. #>
    foreach ($k in $script:AcrobatPolicyKeys) { Set-LabRegistryValue -Path $k -Name 'bUpdater' -Value 0 -Type DWord }
    $svc = Get-Service -Name 'AdobeARMservice' -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne 'Stopped') { Stop-Service -Name $svc.Name -Force }
        Set-Service -Name $svc.Name -StartupType Disabled
    }
    Get-ScheduledTask -TaskName 'Adobe Acrobat Update Task' -ErrorAction SilentlyContinue |
        Where-Object { $_.State -ne 'Disabled' } | Disable-ScheduledTask | Out-Null
}

function Test-ABAcrobatUpdateDisabled {
    foreach ($k in $script:AcrobatPolicyKeys) {
        $s = Get-LabRegistrySnapshot -Path $k -Name 'bUpdater'
        if (-not $s.Exists -or $s.Value -ne 0) { return $false }
    }
    $svc = Get-Service -Name 'AdobeARMservice' -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -ne 'Disabled') { return $false }
    $task = Get-ScheduledTask -TaskName 'Adobe Acrobat Update Task' -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') { return $false }
    return $true
}

function Disable-ABLibreOfficeUpdate {
    <#
    Retire la fonction MSI de mise à jour de LibreOffice (gm_o_Onlineupdate) du
    produit DÉJÀ installé. Pas à l'installation : REMOVE=... sur une installation
    neuve fait ignorer la sélection par défaut (rien n'est installé, vérifié en VM).
    ISCHECKFORPRODUCTUPDATES=0 seul laisse la fonction installée (vérifié en VM).
    #>
    param([Parameter(Mandatory)][string]$ProductCode, [Parameter(Mandatory)][string]$LogFile)
    if (Test-ABLibreOfficeUpdateDisabled -ProductCode $ProductCode) { return }
    $p = Start-Process -FilePath 'msiexec.exe' -Wait -PassThru -WindowStyle Hidden `
        -ArgumentList "/i $ProductCode REMOVE=gm_o_Onlineupdate /qn /norestart /l*v `"$LogFile`""
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { Write-LabWarn "LibreOffice : retrait de la mise à jour, code $($p.ExitCode)." }
}

function Test-ABLibreOfficeUpdateDisabled {
    <# Vrai si la fonction MSI de vérification des mises à jour (gm_o_Onlineupdate) n'est pas installée. #>
    param([Parameter(Mandatory)][string]$ProductCode)
    $installer = New-Object -ComObject WindowsInstaller.Installer
    try {
        $state = $installer.FeatureState($ProductCode, 'gm_o_Onlineupdate')
    } catch {
        return $true   # fonction inexistante dans ce paquet : rien à vérifier
    }
    # 3 = locale, 4 = par défaut : installée ; 2 = absente ; -1 = inconnue
    return ($state -ne 3 -and $state -ne 4)
}

function ConvertTo-ABPackedGuid {
    <# {GUID} MSI -> forme « compressée » des clés Installer\Products (chaque segment inversé). #>
    param([Parameter(Mandatory)][string]$Guid)
    $g = $Guid.Trim('{}').Replace('-', '')
    $rev = { param($s) -join ($s.ToCharArray()[($s.Length - 1)..0]) }
    $out = (& $rev $g.Substring(0, 8)) + (& $rev $g.Substring(8, 4)) + (& $rev $g.Substring(12, 4))
    for ($i = 16; $i -lt 32; $i += 2) { $out += $g[$i + 1] + $g[$i] }
    return $out.ToUpper()
}

function Get-ABMsiSourceList {
    <# Sources réseau et locales enregistrées pour un produit MSI installé pour la machine. #>
    param([Parameter(Mandatory)][string]$ProductCode)
    $key = "HKLM:\SOFTWARE\Classes\Installer\Products\$(ConvertTo-ABPackedGuid -Guid $ProductCode)\SourceList"
    if (-not (Test-Path -LiteralPath $key)) { return @() }
    $net = Join-Path $key 'Net'
    $sources = @()
    if (Test-Path -LiteralPath $net) {
        $k = Get-Item -LiteralPath $net
        foreach ($n in $k.GetValueNames()) { $sources += [string]$k.GetValue($n, $null, 'DoNotExpandEnvironmentNames') }
    }
    return @($sources | ForEach-Object { $_.TrimEnd('\') })
}

# ---------------------------------------------------------------------------
# Windows Update : version de Windows verrouillée (sécurité toujours active)
# ---------------------------------------------------------------------------
$script:WUPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$script:WUAUKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

function Get-ABWindowsTargetVersion {
    <# Version de Windows verrouillée pour une machine (SRV-01, PC-01..PC-04). #>
    param([Parameter(Mandatory)][string]$Machine)
    $v = (Get-ABConfig).WindowsUpdate.Version[$Machine]
    if (-not $v) { throw "Aucune version Windows prévue pour $Machine dans AB-Config.psd1." }
    return $v
}

function Set-ABWindowsUpdateLock {
    param([Parameter(Mandatory)][string]$Machine)
    $wu = (Get-ABConfig).WindowsUpdate
    Set-LabRegistryValue -Path $script:WUPolicyKey -Name 'TargetReleaseVersion' -Value 1 -Type DWord
    Set-LabRegistryValue -Path $script:WUPolicyKey -Name 'ProductVersion' -Value $wu.ProductVersion -Type String
    Set-LabRegistryValue -Path $script:WUPolicyKey -Name 'TargetReleaseVersionInfo' -Value (Get-ABWindowsTargetVersion -Machine $Machine) -Type String
}

function Test-ABWindowsUpdateLock {
    <# Retourne un contrôle New-LabCheck 'windows-update'. #>
    param([Parameter(Mandatory)][string]$Machine)
    $wu = @{ ProductVersion = (Get-ABConfig).WindowsUpdate.ProductVersion; TargetReleaseVersionInfo = (Get-ABWindowsTargetVersion -Machine $Machine) }
    $problems = @()
    $trv = Get-LabRegistrySnapshot -Path $script:WUPolicyKey -Name 'TargetReleaseVersion'
    $pv = Get-LabRegistrySnapshot -Path $script:WUPolicyKey -Name 'ProductVersion'
    $tri = Get-LabRegistrySnapshot -Path $script:WUPolicyKey -Name 'TargetReleaseVersionInfo'
    if (-not $trv.Exists -or $trv.Value -ne 1) { $problems += 'TargetReleaseVersion absent' }
    if (-not $pv.Exists -or $pv.Value -ne $wu.ProductVersion) { $problems += "ProductVersion différent de '$($wu.ProductVersion)'" }
    if (-not $tri.Exists -or $tri.Value -ne $wu.TargetReleaseVersionInfo) { $problems += "TargetReleaseVersionInfo différent de '$($wu.TargetReleaseVersionInfo)'" }
    # Les mises à jour de sécurité doivent rester actives
    $noAuto = Get-LabRegistrySnapshot -Path $script:WUAUKey -Name 'NoAutoUpdate'
    if ($noAuto.Exists -and $noAuto.Value -eq 1) { $problems += 'NoAutoUpdate=1 (mises à jour de sécurité coupées)' }
    $current = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    $detail = "Windows $current, verrou $($wu.TargetReleaseVersionInfo)"
    if ($current -ne $wu.TargetReleaseVersionInfo) { $problems += "version installée $current différente de $($wu.TargetReleaseVersionInfo)" }
    if ($problems) { $detail = $detail + ' : ' + ($problems -join '; ') }
    return (New-LabCheck -Name 'windows-update' -Passed ($problems.Count -eq 0) -Detail $detail)
}

# ---------------------------------------------------------------------------
# Identités (SID : Windows est en français, aucun nom localisé en dur)
# ---------------------------------------------------------------------------
$script:WellKnownSid = @{
    'Administrateurs'           = 'S-1-5-32-544'
    'Utilisateurs'              = 'S-1-5-32-545'
    'SYSTEM'                    = 'S-1-5-18'
    'Utilisateurs authentifiés' = 'S-1-5-11'
    'Tout le monde'             = 'S-1-1-0'
}

function Get-ABSid {
    <# SID (objet) d'un nom connu (table ci-dessus) ou d'un compte/groupe local. #>
    param([Parameter(Mandatory)][string]$Name)
    if ($script:WellKnownSid.ContainsKey($Name)) { return (New-Object Security.Principal.SecurityIdentifier($script:WellKnownSid[$Name])) }
    $acct = New-Object Security.Principal.NTAccount($env:COMPUTERNAME, $Name)
    return $acct.Translate([Security.Principal.SecurityIdentifier])
}

function ConvertTo-ABSidString {
    <# SID texte d'une IdentityReference ou d'un nom de compte ; le texte d'origine si inconnu. #>
    param([Parameter(Mandatory)]$Identity)
    try {
        if ($Identity -is [Security.Principal.IdentityReference]) { return $Identity.Translate([Security.Principal.SecurityIdentifier]).Value }
        return (New-Object Security.Principal.NTAccount([string]$Identity)).Translate([Security.Principal.SecurityIdentifier]).Value
    } catch { return [string]$Identity }
}

# ---------------------------------------------------------------------------
# Comptes locaux
# ---------------------------------------------------------------------------
if (-not ('ABNative.Logon' -as [type])) {
    Add-Type -Namespace ABNative -Name Logon -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool LogonUser(string user, string domain, string password, int logonType, int provider, out IntPtr token);
[DllImport("kernel32.dll")]
public static extern bool CloseHandle(IntPtr handle);
'@
}

function Test-ABLocalPassword {
    <#
    Vrai si le mot de passe ouvre une session RÉSEAU pour ce compte local (LogonUser,
    type 3) : même vérification qu'un accès SMB, aucun profil chargé, aucune trace visible.
    Un échec compte comme tentative ratée : sans effet sur SRV-01 (verrouillage désactivé).
    #>
    param([Parameter(Mandatory)][string]$UserName, [Parameter(Mandatory)][string]$Password)
    $token = [IntPtr]::Zero
    $ok = [ABNative.Logon]::LogonUser($UserName, $env:COMPUTERNAME, $Password, 3, 0, [ref]$token)
    if ($ok) { [void][ABNative.Logon]::CloseHandle($token) }
    return $ok
}

function Set-ABEmployeeAccount {
    <#
    Crée ou remet à l'état LAB le compte local d'un employé (entrée Employes de la config) :
    utilisateur standard, mot de passe LAB, sans expiration, activé.
    #>
    param([Parameter(Mandatory)]$Employe)
    $secure = ConvertTo-SecureString $Employe.MotDePasse -AsPlainText -Force
    $user = Get-LocalUser -Name $Employe.Compte -ErrorAction SilentlyContinue
    if (-not $user) {
        New-LocalUser -Name $Employe.Compte -Password $secure -FullName $Employe.NomComplet -Description $Employe.Role `
            -PasswordNeverExpires -AccountNeverExpires | Out-Null
    } else {
        Set-LocalUser -Name $Employe.Compte -Password $secure -FullName $Employe.NomComplet -Description $Employe.Role `
            -PasswordNeverExpires $true -AccountNeverExpires
        Enable-LocalUser -Name $Employe.Compte
    }
    Set-LocalUser -Name $Employe.Compte -UserMayChangePassword $true
    $sid = (Get-LocalUser -Name $Employe.Compte).SID.Value
    $users = Get-ABSid -Name 'Utilisateurs'
    if (-not (Get-ABGroupMemberSid -GroupSid $users.Value | Where-Object { $_ -eq $sid })) { Add-LocalGroupMember -SID $users.Value -Member $sid }
    $admins = Get-ABSid -Name 'Administrateurs'
    if (Get-ABGroupMemberSid -GroupSid $admins.Value | Where-Object { $_ -eq $sid }) { Remove-LocalGroupMember -SID $admins.Value -Member $sid }
}

function Set-ABAdminAccount {
    <# ab-tech : administrateur, mot de passe sans expiration. Son mot de passe n'est JAMAIS modifié (PowerShell Direct). #>
    $name = (Get-ABConfig).Administrateur
    $user = Get-LocalUser -Name $name -ErrorAction Stop
    Set-LocalUser -Name $name -PasswordNeverExpires $true
    $admins = Get-ABSid -Name 'Administrateurs'
    if (-not (Get-ABGroupMemberSid -GroupSid $admins.Value | Where-Object { $_ -eq $user.SID.Value })) { Add-LocalGroupMember -SID $admins.Value -Member $user.SID.Value }
}

function Get-ABGroupMemberSid {
    <# SID des membres directs d'un groupe local (ADSI : Get-LocalGroupMember échoue sur un SID orphelin). #>
    param([Parameter(Mandatory)][string]$GroupSid)
    $name = (New-Object Security.Principal.SecurityIdentifier($GroupSid)).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1]
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$name,group"
    foreach ($m in @($group.Invoke('Members'))) {
        $bytes = [byte[]]$m.GetType().InvokeMember('objectSid', 'GetProperty', $null, $m, $null)
        (New-Object Security.Principal.SecurityIdentifier($bytes, 0)).Value
    }
}

function Set-ABGroupMembership {
    <# Crée le groupe local au besoin et impose EXACTEMENT la liste des membres (comptes locaux). #>
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Members)
    if (-not (Get-LocalGroup -Name $Group -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $Group -Description "Architecture Boréale" | Out-Null
    }
    $gsid = (Get-LocalGroup -Name $Group).SID.Value
    $wanted = @($Members | ForEach-Object { (Get-ABSid -Name $_).Value })
    $current = @(Get-ABGroupMemberSid -GroupSid $gsid)
    foreach ($s in $wanted) { if ($current -notcontains $s) { Add-LocalGroupMember -SID $gsid -Member $s } }
    foreach ($s in $current) { if ($wanted -notcontains $s) { Remove-LocalGroupMember -SID $gsid -Member $s } }
}

# ---------------------------------------------------------------------------
# Politique de mots de passe AB (stratégie de sécurité locale, secedit)
# ---------------------------------------------------------------------------
function Get-ABPasswordPolicyTarget {
    param([Parameter(Mandatory)][string]$Machine)
    $p = (Get-ABConfig).PolitiqueMotsDePasse
    $t = [ordered]@{
        MinimumPasswordLength = [int]$p.LongueurMinimale
        PasswordComplexity    = [int]$p.Complexite
        PasswordHistorySize   = [int]$p.Historique
    }
    if ($p.Verrouillage.ContainsKey($Machine)) { $t['LockoutBadCount'] = [int]$p.Verrouillage[$Machine] }
    return $t
}

function Get-ABSecurityPolicy {
    <# Valeurs [System Access] actuelles (secedit /export). #>
    $file = Join-Path $env:TEMP "ab-secpol-$PID.inf"
    & secedit.exe /export /cfg $file /areas SECURITYPOLICY /quiet | Out-Null
    $values = @{}
    foreach ($line in (Get-Content -LiteralPath $file -Encoding Unicode)) {
        if ($line -match '^\s*(\w+)\s*=\s*(-?\d+)\s*$') { $values[$Matches[1]] = [int]$Matches[2] }
    }
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    return $values
}

function Set-ABPasswordPolicy {
    param([Parameter(Mandatory)][string]$Machine)
    $target = Get-ABPasswordPolicyTarget -Machine $Machine
    $inf = Join-Path $env:TEMP "ab-secpol-set-$PID.inf"
    $db = Join-Path $env:TEMP "ab-secpol-$PID.sdb"
    $lines = @('[Unicode]', 'Unicode=yes', '[Version]', 'signature="$CHICAGO$"', 'Revision=1', '[System Access]')
    foreach ($k in $target.Keys) { $lines += "$k = $($target[$k])" }
    Set-Content -LiteralPath $inf -Value $lines -Encoding Unicode
    & secedit.exe /configure /db $db /cfg $inf /areas SECURITYPOLICY /quiet | Out-Null
    $code = $LASTEXITCODE
    Remove-Item -LiteralPath $inf, $db -Force -ErrorAction SilentlyContinue
    if ($code -ne 0) { throw "secedit /configure a échoué (code $code)." }
}

function Test-ABPasswordPolicy {
    <# Contrôle New-LabCheck 'politique-mdp'. #>
    param([Parameter(Mandatory)][string]$Machine)
    $target = Get-ABPasswordPolicyTarget -Machine $Machine
    $current = Get-ABSecurityPolicy
    $diff = @()
    foreach ($k in $target.Keys) { if ($current[$k] -ne $target[$k]) { $diff += "$k=$($current[$k]) (attendu $($target[$k]))" } }
    $detail = 'conforme'
    if ($diff) { $detail = $diff -join '; ' }
    return (New-LabCheck -Name 'politique-mdp' -Passed ($diff.Count -eq 0) -Detail $detail)
}

# ---------------------------------------------------------------------------
# NTFS
# ---------------------------------------------------------------------------
$script:SyncRight = [int][Security.AccessControl.FileSystemRights]::Synchronize

function ConvertTo-ABFileRight {
    param([Parameter(Mandatory)][ValidateSet('Modification', 'Lecture', 'ControleTotal')][string]$Level)
    switch ($Level) {
        'Modification'  { [Security.AccessControl.FileSystemRights]::Modify }
        'Lecture'       { [Security.AccessControl.FileSystemRights]::ReadAndExecute }
        'ControleTotal' { [Security.AccessControl.FileSystemRights]::FullControl }
    }
}

function Get-ABExpectedRootRule {
    <# Règles attendues à la racine d'un partage : « SID|droits|type|héritage » triées. #>
    param([Parameter(Mandatory)]$Partage)
    # Même normalisation que Get-ABExplicitRule : sans le bit Synchronize (inclus dans FullControl)
    $full = [int][Security.AccessControl.FileSystemRights]::FullControl -band (-bnot $script:SyncRight)
    $rules = @(
        "$((Get-ABSid -Name 'Administrateurs').Value)|$full|Allow|3",
        "$((Get-ABSid -Name 'SYSTEM').Value)|$full|Allow|3"
    )
    foreach ($k in $Partage.Droits.Keys) {
        $rights = [int](ConvertTo-ABFileRight -Level $Partage.Droits[$k]) -band (-bnot $script:SyncRight)
        $rules += "$((Get-ABSid -Name $k).Value)|$rights|Allow|3"
    }
    return @($rules | Sort-Object)
}

function Get-ABExplicitRule {
    <# Règles explicites d'un dossier, normalisées comme Get-ABExpectedRootRule. #>
    param([Parameter(Mandatory)][string]$Path)
    $acl = Get-Acl -LiteralPath $Path
    @($acl.Access | Where-Object { -not $_.IsInherited } | ForEach-Object {
            $rights = [int]$_.FileSystemRights -band (-bnot $script:SyncRight)
            "$(ConvertTo-ABSidString -Identity $_.IdentityReference)|$rights|$($_.AccessControlType)|$([int]$_.InheritanceFlags)"
        } | Sort-Object)
}

function Set-ABRootAcl {
    <# Racine d'un partage : héritage coupé, Administrateurs et SYSTEM en Contrôle total, droits de la config. #>
    param([Parameter(Mandatory)]$Partage)
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner((Get-ABSid -Name 'Administrateurs'))
    $entries = @(@{ Sid = (Get-ABSid -Name 'Administrateurs'); Rights = 'ControleTotal' }, @{ Sid = (Get-ABSid -Name 'SYSTEM'); Rights = 'ControleTotal' })
    foreach ($k in $Partage.Droits.Keys) { $entries += @{ Sid = (Get-ABSid -Name $k); Rights = $Partage.Droits[$k] } }
    foreach ($e in $entries) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($e.Sid, (ConvertTo-ABFileRight -Level $e.Rights), $inherit, 'None', 'Allow')))
    }
    Set-Acl -LiteralPath $Partage.Dossier -AclObject $acl
}

function Reset-ABChildAcl {
    <# Tous les descendants d'un dossier en héritage pur (aucune règle explicite). #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1)) { return }
    & icacls.exe (Join-Path $Path '*') /reset /T /C /Q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls /reset a échoué sur $Path (code $LASTEXITCODE)." }
}

function Get-ABAclSnapshot {
    <# SDDL (partie Accès) et héritage d'un dossier et de tous ses descendants, parents d'abord. #>
    param([Parameter(Mandatory)][string]$Path)
    $items = @(Get-Item -LiteralPath $Path -Force) + @(Get-ChildItem -LiteralPath $Path -Recurse -Force)
    foreach ($i in $items) {
        $acl = Get-Acl -LiteralPath $i.FullName
        [pscustomobject]@{ Path = $i.FullName; Sddl = $acl.GetSecurityDescriptorSddlForm('Access'); Protected = $acl.AreAccessRulesProtected }
    }
}

function Restore-ABAclSnapshot {
    <# Remet exactement les SDDL enregistrés par Get-ABAclSnapshot (parents d'abord). #>
    param([Parameter(Mandatory)][object[]]$Snapshot)
    foreach ($s in $Snapshot) {
        if (-not (Test-Path -LiteralPath $s.Path)) { Write-LabWarn "Absent, non restauré : $($s.Path)"; continue }
        $acl = Get-Acl -LiteralPath $s.Path
        $acl.SetSecurityDescriptorSddlForm($s.Sddl, 'Access')
        Set-Acl -LiteralPath $s.Path -AclObject $acl
    }
}

# ---------------------------------------------------------------------------
# Partages SMB
# ---------------------------------------------------------------------------
function Get-ABShareAccess {
    <# Accès d'un partage : « SID|droit|type » triés. #>
    param([Parameter(Mandatory)][string]$Name)
    @(Get-SmbShareAccess -Name $Name | ForEach-Object {
            "$(ConvertTo-ABSidString -Identity $_.AccountName)|$($_.AccessRight)|$($_.AccessControlType)"
        } | Sort-Object)
}

function Set-ABShareAccess {
    <# Remplace les accès d'un partage par la liste donnée (objets { Sid; Right; Type }). #>
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][object[]]$Entries)
    foreach ($a in @(Get-SmbShareAccess -Name $Name)) {
        if ($a.AccessControlType -eq 'Deny') { Unblock-SmbShareAccess -Name $Name -AccountName $a.AccountName -Force | Out-Null }
        else { Revoke-SmbShareAccess -Name $Name -AccountName $a.AccountName -Force | Out-Null }
    }
    foreach ($e in $Entries) {
        $account = (New-Object Security.Principal.SecurityIdentifier($e.Sid)).Translate([Security.Principal.NTAccount]).Value
        if ($e.Type -eq 'Deny') { Block-SmbShareAccess -Name $Name -AccountName $account -Force | Out-Null }
        else { Grant-SmbShareAccess -Name $Name -AccountName $account -AccessRight $e.Right -Force | Out-Null }
    }
}

Export-ModuleMember -Function *
