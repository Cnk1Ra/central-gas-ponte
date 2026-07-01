@echo off
title Auto-inicio da Ponte da Bina - Central Gas
echo.
echo  Configurando a ponte pra iniciar sozinha com o PC...
echo.
powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main/autoinicio.ps1 | iex"
echo.
pause
