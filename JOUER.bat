@echo off
rem Double-clic pour lancer le jeu, sans terminal ni commande a taper.
rem
rem Passe par PowerShell avec ExecutionPolicy Bypass : sans ca, Windows
rem refuse d executer un script non signe et la fenetre se fermerait sans
rem rien dire.
title Breaking Bad Game
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bg.ps1" jouer
if errorlevel 1 (
  echo.
  echo Le jeu n a pas pu demarrer. Essaie MISE_A_JOUR.bat, puis relance.
  echo.
  pause
)
