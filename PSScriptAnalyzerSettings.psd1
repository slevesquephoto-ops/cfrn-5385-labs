@{
    # Réglages Invoke-ScriptAnalyzer du dépôt (règle 9 de CLAUDE.md).
    # Usage : Invoke-ScriptAnalyzer -Path <fichier> -Settings .\PSScriptAnalyzerSettings.psd1
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Fonctions internes de scripts de labo : pas de -WhatIf/-Confirm voulu.
        'PSUseShouldProcessForStateChangingFunctions',
        # Messages en couleur voulus (Write-LabStep/OK/Warn, résumé des scripts).
        'PSAvoidUsingWriteHost'
    )
}
