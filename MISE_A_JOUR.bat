@echo off
rem Double-clic pour tout faire : installer ce qui manque, recuperer le
rem travail des autres, envoyer le sien, lancer le jeu.
rem
rem La fenetre reste ouverte a la fin, quoi qu il arrive : sans pause, un
rem message d erreur disparaitrait avant d avoir pu etre lu.
title Breaking Bad Game - mise a jour
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0go.ps1"
echo.
pause
