#requires -version 5.1
# CPT-ADMIN : le client est retiré du groupe Administrateurs (clients administrateurs seulement).
# Voir Particuliers-Config.psd1. « Je ne peux plus rien installer. » La correction le remet admin.
$blocs = @{
    Sauvegarder = {
        param($Ctx)
        $gsid = (Get-ABSid -Name 'Administrateurs').Value
        $membre = (Get-ABGroupMemberSid -GroupSid $gsid) -contains $Ctx.Sid
        @{ EtaitAdmin = [bool]$membre; GroupSid = $gsid }
    }
    Installer = {
        param($Ctx, $Etat)
        if ($Etat.EtaitAdmin) {
            Remove-LocalGroupMember -SID ([Security.Principal.SecurityIdentifier]$Etat.GroupSid) -Member $Ctx.Sid -ErrorAction SilentlyContinue
        }
    }
    Retirer = {
        param($Ctx, $Etat)
        if ($Etat.EtaitAdmin -and ((Get-ABGroupMemberSid -GroupSid $Etat.GroupSid) -notcontains $Ctx.Sid)) {
            Add-LocalGroupMember -SID ([Security.Principal.SecurityIdentifier]$Etat.GroupSid) -Member $Ctx.Sid -ErrorAction SilentlyContinue
        }
    }
    Tester = {
        param($Ctx)
        $gsid = (Get-ABSid -Name 'Administrateurs').Value
        $admin = (Get-ABGroupMemberSid -GroupSid $gsid) -contains $Ctx.Sid
        $d = 'client : membre des Administrateurs'; if (-not $admin) { $d = 'client : hors des Administrateurs' }
        @{ Ok = [bool]$admin; Detail = $d }
    }
}
# Fermetures : les blocs gardent les variables de ce fichier quand le moteur les appelle
foreach ($k in @($blocs.Keys)) { $blocs[$k] = $blocs[$k].GetNewClosure() }
$blocs
