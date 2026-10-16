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

# ===========================================================================
# MOTEUR DE PROFIL DES EMPLOYÉS (commun aux 4 postes)
# Vérifié en VM (AB-PC-03-T, 24H2) : CreateProfile hors session, écriture dans la
# ruche, vraie ouverture de session ensuite (Bureau, profil non temporaire, pas
# d'animation), tâche sous l'identité de l'employé avec droit temporaire.
# ===========================================================================
if (-not ('ABNative.Profile' -as [type])) {
    Add-Type -Namespace ABNative -Name Profile -MemberDefinition @'
[DllImport("userenv.dll", CharSet = CharSet.Unicode)]
public static extern int CreateProfile(string sid, string userName, System.Text.StringBuilder path, uint size);
'@
}
if (-not ('ABNative.Lsa' -as [type])) {
    Add-Type -Namespace ABNative -Name Lsa -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
[StructLayout(LayoutKind.Sequential)]
public struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
[DllImport("advapi32.dll")] static extern uint LsaOpenPolicy(IntPtr system, ref LSA_OBJECT_ATTRIBUTES attr, uint access, out IntPtr handle);
[DllImport("advapi32.dll")] static extern uint LsaAddAccountRights(IntPtr handle, byte[] sid, LSA_UNICODE_STRING[] rights, uint count);
[DllImport("advapi32.dll")] static extern uint LsaRemoveAccountRights(IntPtr handle, byte[] sid, bool all, LSA_UNICODE_STRING[] rights, uint count);
[DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr handle);
[DllImport("advapi32.dll")] static extern int LsaNtStatusToWinError(uint status);
public static int Change(byte[] sid, string right, bool add) {
    LSA_OBJECT_ATTRIBUTES a = new LSA_OBJECT_ATTRIBUTES(); IntPtr h;
    uint r = LsaOpenPolicy(IntPtr.Zero, ref a, 0x00000800 | 0x00000010, out h);
    if (r != 0) return LsaNtStatusToWinError(r);
    LSA_UNICODE_STRING[] s = new LSA_UNICODE_STRING[1];
    s[0].Buffer = Marshal.StringToHGlobalUni(right);
    s[0].Length = (ushort)(right.Length * 2); s[0].MaximumLength = (ushort)((right.Length + 1) * 2);
    r = add ? LsaAddAccountRights(h, sid, s, 1) : LsaRemoveAccountRights(h, sid, false, s, 1);
    Marshal.FreeHGlobal(s[0].Buffer); LsaClose(h);
    return LsaNtStatusToWinError(r);
}
'@
}

function Get-ABUserRightSid {
    <# SID qui détiennent un droit utilisateur (ex. SeBatchLogonRight), d'après secedit. #>
    param([Parameter(Mandatory)][string]$Right)
    $file = Join-Path $env:TEMP "ab-droits-$PID.inf"
    & secedit.exe /export /cfg $file /areas USER_RIGHTS /quiet | Out-Null
    $line = Get-Content -LiteralPath $file -Encoding Unicode | Where-Object { $_ -match "^\s*$Right\s*=" }
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    if (-not $line) { return @() }
    return @(($line -split '=', 2)[1].Split(',') | ForEach-Object {
            $v = $_.Trim()
            if ($v.StartsWith('*')) { $v.Substring(1) } else { ConvertTo-ABSidString -Identity $v }
        })
}

function Set-ABUserRight {
    <# Ajoute ou retire un droit utilisateur à un SID (API LSA). #>
    param([Parameter(Mandatory)][string]$Sid, [Parameter(Mandatory)][string]$Right, [Parameter(Mandatory)][bool]$Grant)
    $s = New-Object Security.Principal.SecurityIdentifier($Sid)
    $bytes = New-Object byte[] $s.BinaryLength
    $s.GetBinaryForm($bytes, 0)
    $err = [ABNative.Lsa]::Change($bytes, $Right, $Grant)
    if ($err -ne 0) { throw "LSA : impossible de modifier $Right pour $Sid (erreur $err)." }
}

function Get-ABUserSid {
    param([Parameter(Mandatory)][string]$Compte)
    return (Get-LocalUser -Name $Compte -ErrorAction Stop).SID.Value
}

function Close-ABUserSession {
    <# Ferme les sessions ouvertes d'un compte (profil déchargé ensuite). #>
    param([Parameter(Mandatory)][string]$Compte)
    # quser écrit « Aucun utilisateur » sur la sortie d'erreur : sans ceci, Stop arrêterait l'appelant (5.1)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $lines = @(& quser.exe 2>&1 | Where-Object { $_ -is [string] } | Select-Object -Skip 1) }
    finally { $ErrorActionPreference = $previous }
    foreach ($l in $lines) {
        $cols = ($l.Trim().TrimStart('>') -split '\s+')
        if ($cols[0] -ne $Compte) { continue }
        $id = $cols | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1
        if ($id) { & logoff.exe $id; Write-LabOK "Session $id de $Compte fermée." }
    }
}

function Remove-ABUserProfile {
    <#
    Supprime le profil d'un employé (dossier et inscription), pour le recréer à neuf
    entre deux équipes. Ferme d'abord ses sessions. Sans effet si absent.
    #>
    param([Parameter(Mandatory)][string]$Compte)
    $user = Get-LocalUser -Name $Compte -ErrorAction SilentlyContinue
    if ($user) {
        Close-ABUserSession -Compte $Compte
        # Ruche restée montée par un script interrompu (Mount-LabUserHive : HKU\LAB_<compte>)
        if (Test-Path -LiteralPath "Registry::HKEY_USERS\LAB_$Compte") {
            Dismount-LabUserHive -Hive ([pscustomobject]@{ Loaded = $true; MountName = "LAB_$Compte" })
        }
        $sid = $user.SID.Value
        $deadline = (Get-Date).AddSeconds(60)
        do {
            $p = Get-CimInstance Win32_UserProfile -Filter "SID='$sid'"
            if ($p -and $p.Loaded) { Start-Sleep -Seconds 2 }
        } while ($p -and $p.Loaded -and (Get-Date) -lt $deadline)
        if ($p) {
            if ($p.Loaded) { throw "Le profil de $Compte est encore chargé : impossible de le recréer." }
            Remove-CimInstance -InputObject $p
            Write-LabOK "Profil de $Compte supprimé."
        }
    }
    # Dossier orphelin (sinon CreateProfile créerait C:\Users\<compte>.<poste>)
    $orphan = Join-Path $env:SystemDrive "Users\$Compte"
    if (Test-Path -LiteralPath $orphan) { Remove-Item -LiteralPath $orphan -Recurse -Force; Write-LabOK "Dossier orphelin retiré : $orphan" }
}

function New-ABUserProfile {
    <# Crée le profil (copie du profil par défaut, NTUSER.DAT inclus) sans ouverture de session. Retourne son chemin. #>
    param([Parameter(Mandatory)][string]$Compte)
    $sid = Get-ABUserSid -Compte $Compte
    $existing = Get-CimInstance Win32_UserProfile -Filter "SID='$sid'"
    if ($existing) { return $existing.LocalPath }
    $sb = New-Object System.Text.StringBuilder 260
    $hr = [ABNative.Profile]::CreateProfile($sid, $Compte, $sb, 260)
    if ($hr -ne 0) { throw ("CreateProfile a échoué pour {0} (HRESULT 0x{1:X8})." -f $Compte, $hr) }
    $path = $sb.ToString()
    if (-not (Test-Path -LiteralPath (Join-Path $path 'NTUSER.DAT'))) { throw "Profil incomplet : $path (NTUSER.DAT absent)." }
    return $path
}

function Invoke-ABUserHive {
    <# Monte la ruche d'un employé, exécute $ScriptBlock (reçoit la racine Registry::...), puis la démonte. #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $hive = Mount-LabUserHive -UserName $Compte
    try { & $ScriptBlock $hive.Root }
    finally { Dismount-LabUserHive -Hive $hive }
}

# Réglages de l'interface dans la ruche (vérifiés par Test-ABUserProfile)
function Get-ABShellSettingList {
    param([Parameter(Mandatory)][string]$Wallpaper)
    # Verifier = $false : valeur réécrite par Windows à la première ouverture de session
    # (thème par défaut), donc écrite mais pas contrôlée. Vérifié en VM (24H2).
    @(
        # Fond d'écran AB par stratégie de l'utilisateur : il gagne sur le thème par défaut
        # et sur « Windows à la une » à chaque ouverture (4 = remplir)
        @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'Wallpaper'; Value = $Wallpaper; Type = 'String'; Verifier = $true }
        @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'WallpaperStyle'; Value = '4'; Type = 'String'; Verifier = $true }
        @{ Key = 'Control Panel\Desktop'; Name = 'Wallpaper'; Value = $Wallpaper; Type = 'String'; Verifier = $false }
        @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'; Name = 'BackgroundType'; Value = 0; Type = 'DWord'; Verifier = $false }
        @{ Key = 'Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableSpotlightCollectionOnDesktop'; Value = 1; Type = 'DWord'; Verifier = $true }
        @{ Key = 'Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsSpotlightFeatures'; Value = 1; Type = 'DWord'; Verifier = $true }
        # Menu Démarrer qui s'ouvre seul à la première ouverture de session (vérifié en VM)
        @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'StartShownOnUpgrade'; Value = 1; Type = 'DWord'; Verifier = $false }
        # « Terminons la configuration de votre appareil » et accueil après mise à jour
        @{ Key = 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0; Type = 'DWord'; Verifier = $false }
        @{ Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0; Type = 'DWord'; Verifier = $false }
    )
}

function Set-ABUserShellSetting {
    <# Applique les réglages d'interface et retire OneDriveSetup de la clé Run (ruche montée). #>
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Wallpaper)
    foreach ($s in Get-ABShellSettingList -Wallpaper $Wallpaper) {
        Set-LabRegistryValue -Path (Join-Path $Root $s.Key) -Name $s.Name -Value $s.Value -Type $s.Type
    }
    $run = Join-Path $Root 'Software\Microsoft\Windows\CurrentVersion\Run'
    if (Test-Path -LiteralPath $run) { Remove-ItemProperty -LiteralPath $run -Name 'OneDriveSetup' -ErrorAction SilentlyContinue }
}

function Set-ABUserNetworkDrive {
    <# Lecteur réseau persistant (HKCU\Network\<lettre>), restauré par Windows à l'ouverture de session. #>
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Letter, [Parameter(Mandatory)][string]$RemotePath)
    $k = Join-Path $Root "Network\$($Letter.TrimEnd(':'))"
    Set-LabRegistryValue -Path $k -Name 'RemotePath' -Value $RemotePath -Type String
    Set-LabRegistryValue -Path $k -Name 'UserName' -Value '' -Type String
    Set-LabRegistryValue -Path $k -Name 'ProviderName' -Value 'Microsoft Windows Network' -Type String
    Set-LabRegistryValue -Path $k -Name 'ProviderType' -Value 0x20000 -Type DWord
    Set-LabRegistryValue -Path $k -Name 'ConnectionType' -Value 1 -Type DWord
    Set-LabRegistryValue -Path $k -Name 'DeferFlags' -Value 4 -Type DWord
}

function Get-ABEmployeeDrive {
    <# Lecteurs d'un employé : @{ Lettre = '\\AB-SRV-01\Partage' }. #>
    param([Parameter(Mandatory)]$Employe)
    $cfg = Get-ABConfig
    $map = [ordered]@{}
    foreach ($l in $Employe.Lecteurs) {
        $share = $cfg.Partages | Where-Object { $_.Lecteur -eq $l } | Select-Object -First 1
        if (-not $share) { throw "Aucun partage pour le lecteur $l dans AB-Config.psd1." }
        $map[$l] = "\\$($cfg.Reseau.Serveur)\$($share.Nom)"
    }
    return $map
}

function Resolve-ABUserTarget {
    <# Cible d'une ligne de manifeste : absolue (C:\...) ou relative au profil. #>
    param([Parameter(Mandatory)][string]$ProfilePath, [Parameter(Mandatory)][string]$Target)
    if ($Target -match '^[A-Za-z]:\\') { return $Target }
    return (Join-Path $ProfilePath $Target)
}

function Copy-ABUserData {
    <#
    Copie les fichiers d'un manifeste (SourceRelative;TargetRelative;CreationTime;
    LastWriteTime;Criticality) : dates appliquées, propriété donnée à l'employé.
    #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$ProfilePath,
        [Parameter(Mandatory)][string]$DataRoot, [Parameter(Mandatory)][string]$Manifest)
    $rows = @(Import-Csv -LiteralPath $Manifest -Delimiter ';' -Encoding UTF8)
    $owner = "$env:COMPUTERNAME\$Compte"
    foreach ($r in $rows) {
        $dst = Resolve-ABUserTarget -ProfilePath $ProfilePath -Target $r.TargetRelative
        $dir = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath (Join-Path $DataRoot $r.SourceRelative) -Destination $dst -Force
        Set-LabItemTime -Path $dst -Created ([datetime]$r.CreationTime) -Modified ([datetime]$r.LastWriteTime)
        & icacls.exe $dst /setowner $owner /C /Q | Out-Null
    }
    return $rows.Count
}

function New-ABShortcut {
    <# Raccourci .lnk (WScript.Shell). #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Target, [string]$Arguments = '', [string]$Icon = '')
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath = $Target
    if ($Arguments) { $lnk.Arguments = $Arguments }
    if ($Icon) { $lnk.IconLocation = $Icon }
    $lnk.Save()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}

function Invoke-ABAsUser {
    <#
    Exécute une commande SOUS L'IDENTITÉ d'un employé (session fermée) : tâche planifiée
    ponctuelle avec son mot de passe, supprimée ensuite. Un utilisateur standard n'a pas
    le droit « Ouvrir une session en tant que tâche » : il est octroyé le temps de la
    tâche puis retiré (retour vérifié). Retourne le code de sortie de la commande.
    Sert à ce qui n'existe que dans la session (cmdkey : chiffré par l'utilisateur).
    #>
    param(
        [Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Execute, [string]$Arguments = '',
        [int]$TimeoutSeconds = 120
    )
    $right = 'SeBatchLogonRight'
    $sid = Get-ABUserSid -Compte $Compte
    $granted = $false
    if ((Get-ABUserRightSid -Right $right) -notcontains $sid) { Set-ABUserRight -Sid $sid -Right $right -Grant $true; $granted = $true }
    $name = 'CFRN-Lab-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    try {
        $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
        if (-not $Arguments) { $action = New-ScheduledTaskAction -Execute $Execute }
        Register-ScheduledTask -TaskName $name -Action $action -User "$env:COMPUTERNAME\$Compte" -Password $Password -RunLevel Limited -Force | Out-Null
        Start-ScheduledTask -TaskName $name
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        do {
            Start-Sleep -Seconds 2
            $info = Get-ScheduledTaskInfo -TaskName $name
            $state = (Get-ScheduledTask -TaskName $name).State
        } while ((($info.LastRunTime.Year -lt 2000) -or ($state -eq 'Running')) -and ((Get-Date) -lt $deadline))
        if ($info.LastRunTime.Year -lt 2000) { throw "La tâche sous l'identité de $Compte n'a pas démarré (0x$('{0:X}' -f $info.LastTaskResult))." }
        if ($state -eq 'Running') { throw "La tâche sous l'identité de $Compte dépasse $TimeoutSeconds s." }
        return [int]$info.LastTaskResult
    } finally {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
        if ($granted) {
            Set-ABUserRight -Sid $sid -Right $right -Grant $false
            if ((Get-ABUserRightSid -Right $right) -contains $sid) { Write-LabWarn "$right n'a pas pu être retiré à $Compte." }
        }
    }
}

function Invoke-ABAsUserCommand {
    <#
    Exécute une ligne de commande (cmd.exe) sous l'identité d'un employé et retourne sa
    sortie. Fichiers temporaires dans le TEMP de son profil, supprimés aussitôt.
    #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Password, [Parameter(Mandatory)][string]$Command)
    $prof = (Get-CimInstance Win32_UserProfile -Filter "SID='$(Get-ABUserSid -Compte $Compte)'").LocalPath
    if (-not $prof) { throw "Profil de $Compte absent." }
    $tmp = Join-Path $prof 'AppData\Local\Temp'
    if (-not (Test-Path -LiteralPath $tmp)) { New-Item -ItemType Directory -Path $tmp -Force | Out-Null }
    $id = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $cmdFile = Join-Path $tmp "cfrn-$id.cmd"
    $outFile = Join-Path $tmp "cfrn-$id.txt"
    try {
        Set-Content -LiteralPath $cmdFile -Value @('@echo off', "$Command > `"$outFile`" 2>&1") -Encoding ASCII
        $code = Invoke-ABAsUser -Compte $Compte -Password $Password -Execute 'cmd.exe' -Arguments "/c `"$cmdFile`""
        $out = @()
        if (Test-Path -LiteralPath $outFile) { $out = @(Get-Content -LiteralPath $outFile) }
        return [pscustomobject]@{ Code = $code; Output = $out }
    } finally {
        Remove-Item -LiteralPath $cmdFile, $outFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-ABUserCredentialTarget {
    <# Cibles des identifiants Windows mémorisés d'un employé (cmdkey /list dans son contexte). #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Password)
    $r = Invoke-ABAsUserCommand -Compte $Compte -Password $Password -Command 'cmdkey /list'
    return @($r.Output | ForEach-Object { if ($_ -match 'target=(\S+)') { $Matches[1] } })
}

function Add-ABUserCredential {
    <# Mémorise un identifiant Windows (Gestionnaire d'identification) dans le coffre de l'employé. #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$UserName, [Parameter(Mandatory)][string]$Secret)
    $r = Invoke-ABAsUserCommand -Compte $Compte -Password $Password -Command "cmdkey /add:$Target /user:$UserName /pass:$Secret"
    if ((Get-ABUserCredentialTarget -Compte $Compte -Password $Password) -notcontains $Target) { throw "Identifiant $Target non mémorisé pour $Compte : $($r.Output -join ' ')" }
}

function Remove-ABUserCredential {
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$Password, [Parameter(Mandatory)][string]$Target)
    $null = Invoke-ABAsUserCommand -Compte $Compte -Password $Password -Command "cmdkey /delete:$Target"
    if ((Get-ABUserCredentialTarget -Compte $Compte -Password $Password) -contains $Target) { throw "Identifiant $Target toujours présent pour $Compte." }
}

# ---------------------------------------------------------------------------
# Stratégies machine (HKLM) des postes
# ---------------------------------------------------------------------------
function Get-ABMachinePolicyList {
    <# Stratégies HKLM des postes : première ouverture de session et LibreOffice (vérifiées par Test-ABMachinePolicy). #>
    $lo = 'HKLM:\SOFTWARE\Policies\LibreOffice'
    $list = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'EnableFirstLogonAnimation'; Value = 0; Type = 'DWord' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'; Name = 'DisablePrivacyExperience'; Value = 1; Type = 'DWord' }
    )
    # LibreOffice : ni conseils du jour ni « Quoi de neuf » (nœuds lus dans main.xcd de la version installée)
    foreach ($node in 'org.openoffice.Office.Common\Misc\ShowTipOfTheDay', 'org.openoffice.Office.UI.Infobar\Enabled\WhatsNew', 'org.openoffice.Setup\Product\WhatsNew') {
        $list += @{ Path = "$lo\$node"; Name = 'Value'; Value = 'false'; Type = 'String' }
        $list += @{ Path = "$lo\$node"; Name = 'Type'; Value = 'xs:boolean'; Type = 'String' }
        $list += @{ Path = "$lo\$node"; Name = 'Final'; Value = 1; Type = 'DWord' }
    }
    return $list
}

function Set-ABMachinePolicy {
    foreach ($p in Get-ABMachinePolicyList) { Set-LabRegistryValue -Path $p.Path -Name $p.Name -Value $p.Value -Type $p.Type }
}

function Test-ABMachinePolicy {
    <# Liste des écarts (vide si conforme). #>
    foreach ($p in Get-ABMachinePolicyList) {
        $s = Get-LabRegistrySnapshot -Path $p.Path -Name $p.Name
        if (-not $s.Exists -or "$($s.Value)" -ne "$($p.Value)") { "$($p.Path)\$($p.Name) différent de $($p.Value)" }
    }
}

# ---------------------------------------------------------------------------
# Profil LibreOffice d'un employé (R6-A : verrou; R6-E : sécurité des macros)
# ---------------------------------------------------------------------------
function Get-ABLibreOfficeRoot {
    <# Installation utilisateur de LibreOffice (…\LibreOffice\4) : le verrou « .lock » y est, le profil dans « user ». #>
    param([Parameter(Mandatory)][string]$Compte)
    $prof = (Get-CimInstance Win32_UserProfile -Filter "SID='$(Get-ABUserSid -Compte $Compte)'").LocalPath
    if (-not $prof) { throw "Profil de $Compte absent." }
    return (Join-Path $prof 'AppData\Roaming\LibreOffice\4')
}

$script:XcuNs = 'http://openoffice.org/2001/registry'
$script:ScriptingPath = '/org.openoffice.Office.Common/Security/Scripting'

function Get-ABLibreOfficeMacroConfig {
    <# Sécurité des macros du profil : { Niveau (0..3, 2 si absent = défaut); Emplacements; Existe }. #>
    param([Parameter(Mandatory)][string]$Compte)
    $xcu = Join-Path (Get-ABLibreOfficeRoot -Compte $Compte) 'user\registrymodifications.xcu'
    $r = [pscustomobject]@{ Niveau = 2; Emplacements = @(); Existe = (Test-Path -LiteralPath $xcu) }
    if (-not $r.Existe) { return $r }
    [xml]$x = Get-Content -LiteralPath $xcu -Raw -Encoding UTF8
    $ns = New-Object Xml.XmlNamespaceManager($x.NameTable); $ns.AddNamespace('oor', $script:XcuNs)
    $lvl = $x.SelectSingleNode("//item[@oor:path='$($script:ScriptingPath)']/prop[@oor:name='MacroSecurityLevel']/value", $ns)
    if ($lvl) { $r.Niveau = [int]$lvl.InnerText }
    $urls = $x.SelectNodes("//item[@oor:path='$($script:ScriptingPath)']/prop[@oor:name='SecureURL']/value/it", $ns)
    $r.Emplacements = @($urls | ForEach-Object { $_.InnerText })
    return $r
}

function Set-ABLibreOfficeMacroConfig {
    <#
    Écrit le niveau de sécurité des macros et les emplacements de confiance dans le profil
    LibreOffice de l'employé (registrymodifications.xcu), sans toucher au reste du fichier.
    #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][int]$Niveau, [AllowEmptyCollection()][string[]]$Emplacements = @())
    $userDir = Join-Path (Get-ABLibreOfficeRoot -Compte $Compte) 'user'
    if (-not (Test-Path -LiteralPath $userDir)) { New-Item -ItemType Directory -Path $userDir -Force | Out-Null }
    $xcu = Join-Path $userDir 'registrymodifications.xcu'
    if (Test-Path -LiteralPath $xcu) { [xml]$x = Get-Content -LiteralPath $xcu -Raw -Encoding UTF8 }
    else { [xml]$x = '<?xml version="1.0" encoding="UTF-8"?><oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></oor:items>' }
    $ns = New-Object Xml.XmlNamespaceManager($x.NameTable); $ns.AddNamespace('oor', $script:XcuNs)
    foreach ($n in @($x.SelectNodes("//item[@oor:path='$($script:ScriptingPath)'][prop[@oor:name='MacroSecurityLevel' or @oor:name='SecureURL']]", $ns))) { [void]$n.ParentNode.RemoveChild($n) }
    $list = ($Emplacements | ForEach-Object { "<it>$([Security.SecurityElement]::Escape($_))</it>" }) -join ''
    $frag = $x.CreateDocumentFragment()
    $frag.InnerXml = "<item xmlns:oor=`"$($script:XcuNs)`" oor:path=`"$($script:ScriptingPath)`"><prop oor:name=`"MacroSecurityLevel`" oor:op=`"fuse`"><value>$Niveau</value></prop></item>" +
    "<item xmlns:oor=`"$($script:XcuNs)`" oor:path=`"$($script:ScriptingPath)`"><prop oor:name=`"SecureURL`" oor:op=`"fuse`"><value>$list</value></prop></item>"
    [void]$x.DocumentElement.AppendChild($frag)
    $settings = New-Object Xml.XmlWriterSettings; $settings.Encoding = New-Object Text.UTF8Encoding($false)
    $w = [Xml.XmlWriter]::Create($xcu, $settings); try { $x.Save($w) } finally { $w.Close() }
    & icacls.exe (Split-Path -Parent $userDir) /setowner "$env:COMPUTERNAME\$Compte" /T /C /Q | Out-Null
}

function Get-ABLibreOfficeLock {
    <# Verrou du profil LibreOffice : $null, ou { Poste; Compte; Chemin }. #>
    param([Parameter(Mandatory)][string]$Compte)
    $lock = Join-Path (Get-ABLibreOfficeRoot -Compte $Compte) '.lock'
    if (-not (Test-Path -LiteralPath $lock)) { return $null }
    $h = @{}; foreach ($l in Get-Content -LiteralPath $lock) { if ($l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2] } }
    return [pscustomobject]@{ Poste = $h['Host']; Compte = $h['User']; Chemin = $lock }
}

# ---------------------------------------------------------------------------
# Polices (Montserrat pour le modèle de facture, R6-D)
# ---------------------------------------------------------------------------
$script:FontKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

function Get-ABFontList {
    <# Polices fournies dans AB\data\polices\<famille>\*.ttf : { Fichier; Nom registre }. #>
    param([Parameter(Mandatory)][string]$Famille)
    $dir = Join-Path $PSScriptRoot "data\polices\$Famille"
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter *.ttf) {
        $style = ($f.BaseName -split '-', 2)[1]
        $name = "$Famille $style (TrueType)"
        if ($style -eq 'Regular') { $name = "$Famille (TrueType)" }
        [pscustomobject]@{ Source = $f.FullName; Fichier = $f.Name; Nom = $name }
    }
}

function Install-ABFont {
    <# Installe une famille de polices pour TOUS les utilisateurs (C:\Windows\Fonts + registre). #>
    param([Parameter(Mandatory)][string]$Famille)
    foreach ($f in Get-ABFontList -Famille $Famille) {
        $dst = Join-Path $env:windir "Fonts\$($f.Fichier)"
        if (-not (Test-Path -LiteralPath $dst)) { Copy-Item -LiteralPath $f.Source -Destination $dst }
        Set-LabRegistryValue -Path $script:FontKey -Name $f.Nom -Value $f.Fichier -Type String
    }
}

function Test-ABFont {
    <# Écarts (vide si la famille est installée pour tous les utilisateurs). #>
    param([Parameter(Mandatory)][string]$Famille)
    foreach ($f in Get-ABFontList -Famille $Famille) {
        if (-not (Test-Path -LiteralPath (Join-Path $env:windir "Fonts\$($f.Fichier)"))) { "$($f.Fichier) absent de C:\Windows\Fonts" }
        $s = Get-LabRegistrySnapshot -Path $script:FontKey -Name $f.Nom
        if (-not $s.Exists -or $s.Value -ne $f.Fichier) { "$($f.Nom) absent du registre des polices" }
    }
}

# ---------------------------------------------------------------------------
# R4 : démarrage encombré et processus gourmand (couche logicielle), RAM
# ---------------------------------------------------------------------------
function Get-ABInstalledMemoryGo {
    <# RAM physique installée, en Go (arrondi 0,1). Le Verifier la rapporte sans échouer. #>
    [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB, 1)
}

function Get-ABRunKey {
    param([Parameter(Mandatory)][string]$HiveRoot)
    return (Join-Path $HiveRoot 'Software\Microsoft\Windows\CurrentVersion\Run')
}

# Fichiers déposés sur le poste : commentaires neutres seulement (règle 6, discrétion);
# ASCII sans accent (wscript lit les .vbs en ANSI).
$script:VbsInutile = @'
' Utilitaire interne Architecture Boreale
WScript.Sleep 1500
'@

function Get-ABGreedyLauncher {
    <# Lanceur .vbs : démarre le script gourmand caché (aucune fenêtre de terminal). #>
    param([Parameter(Mandatory)][string]$Dossier, [Parameter(Mandatory)][string]$Script)
    return @"
' Indexation des documents Architecture Boreale
Set sh = CreateObject("WScript.Shell")
ps1 = sh.ExpandEnvironmentStrings("%APPDATA%") & "\$Dossier\$Script"
sh.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
"@
}

function Get-ABGreedyScript {
    <#
    Contenu du script « gourmand » : retient MemoireMo de mémoire (blocs de 256 Mo, données
    aléatoires donc incompressibles) et la retouche toutes les 30 s pour qu'elle reste en
    mémoire vive, visible dans le Gestionnaire des tâches (sinon Windows la renvoie au
    fichier d'échange et la lenteur disparaît).
    #>
    param([Parameter(Mandatory)][int]$MemoireMo)
    $nb = [math]::Ceiling($MemoireMo / 256)
    return @"
# Indexeur de documents Architecture Boreale
`$alea = New-Object Random
`$cache = New-Object 'System.Collections.Generic.List[byte[]]'
for (`$n = 0; `$n -lt $nb; `$n++) { `$b = New-Object 'byte[]' (256MB); `$alea.NextBytes(`$b); `$cache.Add(`$b) }
while (`$true) {
    foreach (`$b in `$cache) { [Array]::Reverse(`$b) }
    Start-Sleep -Seconds 30
}
"@
}

function Add-ABStartupClutter {
    <#
    Installe la couche logicielle de R4 dans la session de lpgauthier : scripts inutiles et
    script gourmand déposés dans %APPDATA%\<dossier>, valeurs Run dans la ruche, tâche
    planifiée au logon. Retourne l'état d'origine (à enregistrer pour le Retrait).
    #>
    param([Parameter(Mandatory)][string]$Compte)
    $r4 = (Get-ABConfig).Pannes.R4
    $prof = (Get-CimInstance Win32_UserProfile -Filter "SID='$(Get-ABUserSid -Compte $Compte)'").LocalPath
    if (-not $prof) { throw "Profil de $Compte absent." }
    $scriptDir = Join-Path $prof "AppData\Roaming\$($r4.DossierScripts)"
    $greedy = Join-Path $scriptDir $r4.ScriptGourmand
    New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
    Set-Content -LiteralPath (Join-Path $scriptDir 'assistant.vbs') -Value $script:VbsInutile -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $scriptDir 'synchro.vbs') -Value $script:VbsInutile -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $scriptDir $r4.Tache.Script) -Value $script:VbsInutile -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $scriptDir $r4.LanceurGourmand) -Value (Get-ABGreedyLauncher -Dossier $r4.DossierScripts -Script $r4.ScriptGourmand) -Encoding ASCII
    Set-Content -LiteralPath $greedy -Value (Get-ABGreedyScript -MemoireMo $r4.MemoireMo) -Encoding UTF8
    & icacls.exe $scriptDir /setowner "$env:COMPUTERNAME\$Compte" /T /C /Q | Out-Null

    # État : nom de chaque valeur Run et son état d'origine (sans le chemin de ruche, qui
    # dépend du nom de montage; il est reconstruit au retrait).
    $state = [ordered]@{ Compte = $Compte; ScriptDir = $scriptDir; Run = @(); Tache = $r4.Tache.Nom }
    Invoke-ABUserHive -Compte $Compte -ScriptBlock {
        param($Root)
        $run = Get-ABRunKey -HiveRoot $Root
        foreach ($nom in $r4.Demarrage.Keys) {
            $snap = Get-LabRegistrySnapshot -Path $run -Name $nom
            $state.Run += , ([ordered]@{ Name = $nom; Exists = $snap.Exists; Value = $snap.Value; Type = $snap.Type })
            # ExpandString : Windows développe %APPDATA% au lancement (REG_SZ ne l'est pas)
            Set-LabRegistryValue -Path $run -Name $nom -Value $r4.Demarrage[$nom] -Type ExpandString
        }
    }
    # Tâche au logon sous l'identité de lpgauthier (interactive, aucun mot de passe requis)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$Compte" -LogonType Interactive -RunLevel Limited
    $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$(Join-Path $scriptDir $r4.Tache.Script)`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:COMPUTERNAME\$Compte"
    Register-ScheduledTask -TaskName $r4.Tache.Nom -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    return $state
}

function Remove-ABStartupClutter {
    <# Retire R4 depuis l'état enregistré par Add-ABStartupClutter (retrait exact). #>
    param([Parameter(Mandatory)]$State)
    $r4 = (Get-ABConfig).Pannes.R4
    # Processus gourmand encore en cours (session de lpgauthier)
    $greedy = Join-Path $State.ScriptDir $r4.ScriptGourmand
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -match [regex]::Escape($greedy) } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Unregister-ScheduledTask -TaskName $State.Tache -Confirm:$false -ErrorAction SilentlyContinue
    Invoke-ABUserHive -Compte $State.Compte -ScriptBlock {
        param($Root)
        $run = Get-ABRunKey -HiveRoot $Root
        foreach ($v in $State.Run) {
            if ($v.Exists) { Set-LabRegistryValue -Path $run -Name $v.Name -Value $v.Value -Type $v.Type }
            elseif (Test-Path -LiteralPath $run) { Remove-ItemProperty -LiteralPath $run -Name $v.Name -ErrorAction SilentlyContinue }
        }
    }
    if (Test-Path -LiteralPath $State.ScriptDir) { Remove-Item -LiteralPath $State.ScriptDir -Recurse -Force }
}

function Test-ABStartupClutter {
    <# Écarts R4 (vide = démarrage propre) : valeurs Run, tâche, dossier de scripts, processus gourmand. #>
    param([Parameter(Mandatory)][string]$Compte)
    $r4 = (Get-ABConfig).Pannes.R4
    $problems = @()
    $prof = (Get-CimInstance Win32_UserProfile -Filter "SID='$(Get-ABUserSid -Compte $Compte)'").LocalPath
    if ($prof) {
        $scriptDir = Join-Path $prof "AppData\Roaming\$($r4.DossierScripts)"
        if (Test-Path -LiteralPath $scriptDir) { $problems += "dossier de scripts de démarrage présent : $scriptDir" }
    }
    if (Get-ScheduledTask -TaskName $r4.Tache.Nom -ErrorAction SilentlyContinue) { $problems += "tâche planifiée « $($r4.Tache.Nom) » présente" }
    $hive = Mount-LabUserHive -UserName $Compte
    try {
        $run = Get-ABRunKey -HiveRoot $hive.Root
        foreach ($nom in $r4.Demarrage.Keys) { if ((Get-LabRegistrySnapshot -Path $run -Name $nom).Exists) { $problems += "élément de démarrage « $nom » présent" } }
    } finally { Dismount-LabUserHive -Hive $hive }
    if ($prof) {
        $greedy = Join-Path $prof "AppData\Roaming\$($r4.DossierScripts)\$($r4.ScriptGourmand)"
        $running = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match [regex]::Escape($greedy) })
        if ($running) { $problems += "$($running.Count) processus gourmand en cours" }
    }
    return $problems
}

# ---------------------------------------------------------------------------
# R2 (PC-04) : ordre de démarrage UEFI (panne physique, contrôle au mieux)
# ---------------------------------------------------------------------------
function Get-ABBootOrder {
    <#
    Tente de lire l'ordre de démarrage UEFI (bcdedit /enum firmware). Retourne
    { Lisible; DisqueEnTete; Detail }. Si l'ordre n'est pas lisible de façon fiable
    (fréquent en VM), Lisible = $false : le Verifier le signale en contrôle manuel.
    #>
    $illisible = { param($m) [pscustomobject]@{ Lisible = $false; DisqueEnTete = $false; Detail = "$m (à vérifier dans le microprogramme)" } }
    $out = & bcdedit.exe /enum firmware 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return (& $illisible 'ordre de démarrage UEFI illisible ici') }
    $text = $out -join "`n"
    # Section {fwbootmgr} : displayorder = liste d'identificateurs ({bootmgr} ou GUID),
    # sur plusieurs lignes indentées. Le premier est l'entrée de tête.
    $order = [regex]::Match($text, '(?m)^displayorder\s+(\{[\w-]+\}(?:\s*\n\s+\{[\w-]+\})*)')
    $ids = [regex]::Matches($order.Groups[1].Value, '\{[\w-]+\}') | ForEach-Object { $_.Value }
    if (-not $ids) { return (& $illisible 'ordre de démarrage UEFI non déterminé') }
    $premier = $ids[0]
    # Description de l'entrée : {bootmgr} = « Windows Boot Manager » (disque système).
    # Sections séparées par une ligne vide; on prend celle dont l'identificateur est le premier.
    $esc = [regex]::Escape($premier)
    $sec = @($text -split '\r?\n\s*\r?\n' | Where-Object { $_ -match "(?m)^identificateur\s+$esc\s*$" }) | Select-Object -First 1
    $desc = [regex]::Match($sec, '(?m)^description\s+(.+)$').Groups[1].Value.Trim()
    if (-not $desc) { return (& $illisible "première entrée $premier sans description") }
    $reseau = $desc -match 'Network|R.seau|PXE'
    $disque = -not $reseau -and ($desc -match 'Windows Boot Manager|Gestionnaire.*Windows|SCSI|SATA|NVMe|Disk|Disque|SSD|HDD')
    return [pscustomobject]@{ Lisible = $true; DisqueEnTete = [bool]$disque; Detail = "première entrée de démarrage : $desc" }
}

# ---------------------------------------------------------------------------
# R3 : sauvegarde des fichiers « Critique » (contrôle par hash)
# ---------------------------------------------------------------------------
function Test-ABBackup {
    <#
    Vérifie que les fichiers « Critique » d'un employé (manifeste) se retrouvent, avec le bon
    hash, dans \\SERVEUR\Sauvegardes$\<compte>\<date la plus récente>. Écarts (vide = OK).
    Lu par le réseau avec l'identité courante (ab-tech a le droit sur Sauvegardes$).
    #>
    param([Parameter(Mandatory)][string]$Compte, [Parameter(Mandatory)][string]$ProfilePath, [Parameter(Mandatory)][string]$Manifest)
    $cfg = Get-ABConfig
    $r3 = $cfg.Pannes.R3
    $problems = @()
    $dest = "\\$($cfg.Reseau.Serveur)\$($r3.Partage)\$Compte"
    if (-not (Test-Path -LiteralPath $dest)) { return @("aucune sauvegarde pour $Compte dans $dest") }
    $jour = Get-ChildItem -LiteralPath $dest -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $jour) { return @("aucun dossier de sauvegarde daté dans $dest") }
    $critiques = @(Import-Csv -LiteralPath $Manifest -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Criticality -eq $r3.Criticite })
    foreach ($r in $critiques) {
        $src = Resolve-ABUserTarget -ProfilePath $ProfilePath -Target $r.TargetRelative
        $leaf = Split-Path -Leaf $r.TargetRelative
        $copie = @(Get-ChildItem -LiteralPath $jour.FullName -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
        if (-not (Test-Path -LiteralPath $src)) { $problems += "source absente : $src"; continue }
        $hash = (Get-FileHash -LiteralPath $src).Hash
        if (-not ($copie | Where-Object { (Get-FileHash -LiteralPath $_.FullName).Hash -eq $hash })) { $problems += "non sauvegardé (ou modifié) : $($r.TargetRelative)" }
    }
    return $problems
}

# ---------------------------------------------------------------------------
# Orchestration et vérification
# ---------------------------------------------------------------------------
function Initialize-ABEmployeeProfile {
    <#
    Moteur commun aux 4 Setup de poste : profil RECRÉÉ à neuf (décision : entre deux
    équipes), compte, CreateProfile, réglages de la ruche (interface, lecteurs), données
    du manifeste, raccourcis du Bureau. Retourne le chemin du profil.
    $Raccourcis : objets { Nom; Cible; Arguments; Icone } créés dans <profil>\Desktop.
    #>
    param(
        [Parameter(Mandatory)]$Employe,
        [Parameter(Mandatory)][string]$Wallpaper,
        [string]$DataRoot, [string]$Manifest,
        [object[]]$Raccourcis = @()
    )
    Remove-ABUserProfile -Compte $Employe.Compte
    Set-ABEmployeeAccount -Employe $Employe
    $path = New-ABUserProfile -Compte $Employe.Compte
    Write-LabOK "Profil créé : $path"
    $drives = Get-ABEmployeeDrive -Employe $Employe
    $wp = $Wallpaper   # lu par le bloc ci-dessous (portée dynamique)
    Invoke-ABUserHive -Compte $Employe.Compte -ScriptBlock {
        param($Root)
        Set-ABUserShellSetting -Root $Root -Wallpaper $wp
        foreach ($l in $drives.Keys) { Set-ABUserNetworkDrive -Root $Root -Letter $l -RemotePath $drives[$l] }
    }
    Write-LabOK "Ruche : interface AB, lecteurs $(($drives.Keys | ForEach-Object { "$($_): $($drives[$_])" }) -join ', ')"
    if ($Manifest -and (Test-Path -LiteralPath $Manifest)) {
        $n = Copy-ABUserData -Compte $Employe.Compte -ProfilePath $path -DataRoot $DataRoot -Manifest $Manifest
        Write-LabOK "$n fichiers de données copiés."
    } elseif ($Manifest) {
        Write-LabWarn "Manifeste absent ($Manifest) : aucune donnée copiée."
    }
    foreach ($s in $Raccourcis) {
        New-ABShortcut -Path (Join-Path $path "Desktop\$($s.Nom).lnk") -Target $s.Cible -Arguments ([string]$s['Arguments']) -Icon ([string]$s['Icone'])
    }
    if ($Raccourcis) {
        $owner = "$env:COMPUTERNAME\$($Employe.Compte)"
        & icacls.exe (Join-Path $path 'Desktop\*.lnk') /setowner $owner /C /Q | Out-Null
        Write-LabOK "$(@($Raccourcis).Count) raccourcis sur le Bureau."
    }
    return $path
}

function Find-ABProgram {
    <# Chemin d'un exécutable installé (Program Files), ou $null. #>
    param([Parameter(Mandatory)][string]$Exe)
    foreach ($root in $env:ProgramFiles, ${env:ProgramFiles(x86)}) {
        if (-not $root) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Filter $Exe -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$script:ABWallpaper = 'C:\Windows\Web\Wallpaper\AB\fond-AB.png'

function Initialize-ABPoste {
    <#
    Base commune des Setup de poste : politique de mots de passe, ab-tech, stratégies
    (première ouverture, LibreOffice), logiciels vérifiés, fond d'écran AB, puis profil
    de l'employé recréé par Initialize-ABEmployeeProfile. Retourne le chemin du profil.
    Chaque Setup ajoute ensuite ce qui est propre au poste.
    #>
    param([Parameter(Mandatory)][string]$Machine, [Parameter(Mandatory)][string]$Compte, [object[]]$Raccourcis = @())
    $cfg = Get-ABConfig
    $emp = $cfg.Employes | Where-Object { $_.Compte -eq $Compte }

    Write-LabStep 'Politique de mots de passe et comptes'
    Set-ABPasswordPolicy -Machine $Machine
    Set-ABAdminAccount
    Write-LabOK "$((Test-ABPasswordPolicy -Machine $Machine).detail); $($cfg.Administrateur) sans expiration."

    Write-LabStep 'Stratégies du poste (première ouverture, LibreOffice)'
    Set-ABMachinePolicy
    Write-LabOK 'Sans animation ni questions de confidentialité; LibreOffice sans conseils ni « Quoi de neuf ».'

    Write-LabStep 'Logiciels'
    foreach ($s in Get-ABSoftwareList -Poste $Machine) {
        $found = Test-ABSoftware -Logiciel $s
        if (-not $found) { throw "$($s.Nom) absent : lancer tools\Set-ABPoste.ps1 -Poste $Machine avant le point Propre." }
        Write-LabOK "$($found.DisplayName) $($found.Version)"
    }

    Write-LabStep 'Fond d''écran AB'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:ABWallpaper) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'data\communs\fond-AB.png') -Destination $script:ABWallpaper -Force
    Write-LabOK $script:ABWallpaper

    Write-LabStep "Profil de $($emp.NomComplet) ($Compte)"
    $data = Join-Path $PSScriptRoot "data\$Compte"
    $path = Initialize-ABEmployeeProfile -Employe $emp -Wallpaper $script:ABWallpaper -DataRoot $data -Manifest (Join-Path $data "manifeste-$Compte.csv") -Raccourcis $Raccourcis
    Write-LabOK "Profil prêt : $path"
    return $path
}

function Test-ABPoste {
    <# Contrôles communs des Verifier de poste (objets New-LabCheck). #>
    param([Parameter(Mandatory)][string]$Machine, [Parameter(Mandatory)][string]$Compte)
    $cfg = Get-ABConfig
    $emp = $cfg.Employes | Where-Object { $_.Compte -eq $Compte }
    $p = @(); foreach ($s in Get-ABSoftwareList -Poste $Machine) { if (-not (Test-ABSoftware -Logiciel $s)) { $p += "$($s.Nom) absent" } }
    $d = "$(@(Get-ABSoftwareList -Poste $Machine).Count) logiciels présents"; if ($p) { $d = $p -join '; ' }
    New-LabCheck -Name 'logiciels' -Passed (-not $p) -Detail $d
    Test-ABWindowsUpdateLock -Machine $Machine
    Test-ABPasswordPolicy -Machine $Machine
    $p = @(Test-ABMachinePolicy)
    $tech = Get-LocalUser -Name $cfg.Administrateur -ErrorAction SilentlyContinue
    if (-not $tech -or $null -ne $tech.PasswordExpires) { $p += "$($cfg.Administrateur) : mot de passe qui expire" }
    $d = 'première ouverture, LibreOffice, ab-tech conformes'; if ($p) { $d = $p -join '; ' }
    New-LabCheck -Name 'strategies' -Passed (-not $p) -Detail $d
    $data = Join-Path $PSScriptRoot "data\$Compte"
    $p = @(Test-ABUserProfile -Employe $emp -Wallpaper $script:ABWallpaper -DataRoot $data -Manifest (Join-Path $data "manifeste-$Compte.csv"))
    $d = "profil de $Compte complet (ruche, lecteurs $($emp.Lecteurs -join ', '), fond d'écran, données)"; if ($p) { $d = $p -join '; ' }
    New-LabCheck -Name 'profil' -Passed (-not $p) -Detail $d
}

function Test-ABUserProfile {
    <# Écarts du profil d'un employé par rapport à l'état attendu (vide si conforme). #>
    param(
        [Parameter(Mandatory)]$Employe, [Parameter(Mandatory)][string]$Wallpaper,
        [string]$DataRoot, [string]$Manifest
    )
    $user = Get-LocalUser -Name $Employe.Compte -ErrorAction SilentlyContinue
    if (-not $user) { return "$($Employe.Compte) absent" }
    $p = Get-CimInstance Win32_UserProfile -Filter "SID='$($user.SID.Value)'"
    if (-not $p) { return "profil de $($Employe.Compte) absent" }
    $problems = @()
    $expectedPath = Join-Path $env:SystemDrive "Users\$($Employe.Compte)"
    if ($p.LocalPath -ne $expectedPath) { $problems += "profil dans $($p.LocalPath) (attendu $expectedPath)" }
    foreach ($d in 'NTUSER.DAT', 'Desktop', 'Documents', 'Downloads', 'Pictures', 'AppData\Roaming') {
        if (-not (Test-Path -LiteralPath (Join-Path $p.LocalPath $d))) { $problems += "$d absent du profil" }
    }
    if (-not (Test-Path -LiteralPath $Wallpaper)) { $problems += "fond d'écran absent : $Wallpaper" }
    $drives = Get-ABEmployeeDrive -Employe $Employe
    $hive = Mount-LabUserHive -UserName $Employe.Compte
    try {
        foreach ($s in Get-ABShellSettingList -Wallpaper $Wallpaper | Where-Object { $_.Verifier }) {
            $snap = Get-LabRegistrySnapshot -Path (Join-Path $hive.Root $s.Key) -Name $s.Name
            if (-not $snap.Exists -or "$($snap.Value)" -ne "$($s.Value)") { $problems += "HKCU\$($s.Key)\$($s.Name) différent de $($s.Value)" }
        }
        foreach ($l in $drives.Keys) {
            $snap = Get-LabRegistrySnapshot -Path (Join-Path $hive.Root "Network\$l") -Name 'RemotePath'
            if (-not $snap.Exists -or $snap.Value -ne $drives[$l]) { $problems += "lecteur $($l): différent de $($drives[$l])" }
        }
        $net = Join-Path $hive.Root 'Network'
        if (Test-Path -LiteralPath $net) {
            foreach ($k in Get-ChildItem -LiteralPath $net) {
                if (-not $drives.Contains($k.PSChildName)) { $problems += "lecteur $($k.PSChildName): en trop" }
                $k.Close()   # sinon la ruche ne se démonte plus
            }
        }
    } finally { Dismount-LabUserHive -Hive $hive }
    if (Test-Path -LiteralPath "Registry::HKEY_USERS\LAB_$($Employe.Compte)") {
        $problems += "ruche LAB_$($Employe.Compte) encore montée : l'employé aurait un profil temporaire"
    }
    if ($Manifest -and (Test-Path -LiteralPath $Manifest)) {
        foreach ($r in Import-Csv -LiteralPath $Manifest -Delimiter ';' -Encoding UTF8) {
            $dst = Resolve-ABUserTarget -ProfilePath $p.LocalPath -Target $r.TargetRelative
            if (-not (Test-Path -LiteralPath $dst)) { $problems += "fichier absent : $dst" }
            elseif ((Get-FileHash -LiteralPath $dst).Hash -ne (Get-FileHash -LiteralPath (Join-Path $DataRoot $r.SourceRelative)).Hash) { $problems += "fichier modifié : $dst" }
        }
    }
    return $problems
}

Export-ModuleMember -Function *
