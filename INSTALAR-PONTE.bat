@echo off
title Ponte da Bina - Central Gas
echo.
echo  Instalando a Ponte da Bina - Central Gas...
echo  (vai baixar o necessario e pedir o token uma vez)
echo.
powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main/instalar.ps1 | iex"
echo.
echo  (se a janela fechou sozinha antes, rode novamente)
pause
