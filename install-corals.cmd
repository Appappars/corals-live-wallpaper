@echo off
chcp 65001 >nul
title Corals — установка живых обоев
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Appappars/corals-live-wallpaper/main/install.ps1 | iex"
echo.
pause