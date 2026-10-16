@echo off
rem Ouvre la console des pannes Particuliers (Menu-Particuliers.ps1) en administrateur : double-clic, puis accepter l'UAC.
rem Le chemin passe par une variable pour que les parentheses du dossier, ex. CFRN-LAB(prof), ne posent pas probleme.
rem (Fichier en ASCII : cmd lit mal les accents.)
set "PART_MENU=%~dp0Menu-Particuliers.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"' + $env:PART_MENU + '\"')"
