@echo off
rem Ouvre la console enseignant AB (Menu-AB.ps1) en administrateur : double-clic, puis accepter l'UAC.
rem Le chemin passe par une variable pour que les parentheses du dossier, ex. CFRN-LAB(prof), ne posent pas probleme.
rem (Fichier en ASCII : cmd lit mal les accents.)
set "AB_MENU=%~dp0Menu-AB.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"' + $env:AB_MENU + '\"')"
