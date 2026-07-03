@echo off
setlocal
set BASE=%LOCALAPPDATA%\CentralGasPonte
echo ==============================================
echo   MODO APRENDIZADO - formato da bina (HT814)
echo ==============================================
echo.
echo Este modo PARA a ponte oculta e mostra na tela
echo TUDO que o HT814 mandar pelo syslog.
echo.
echo   1. Deixe esta janela aberta
echo   2. Ligue de um celular para a loja
echo   3. Copie/fotografe o que aparecer aqui
echo   4. Feche a janela e rode o AUTOINICIO.bat
echo      de novo pra religar a ponte normal
echo.
if not exist "%BASE%\ponte.js" (echo Nao achei a ponte em %BASE% - rode o INSTALAR-PONTE.bat primeiro. & pause & exit /b 1)

rem para a ponte oculta (loop + node) pra liberar a porta 514
schtasks /End /TN CentralGasPonte >nul 2>&1
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { ($_.CommandLine -like '*rodar.cmd*') -or ($_.CommandLine -like '*rodar-oculto.vbs*') -or ($_.Name -eq 'node.exe' -and $_.CommandLine -like '*CentralGasPonte*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

cd /d "%BASE%"
set LEARN=1
"%BASE%\node\node.exe" ponte.js
echo.
echo (a ponte de aprendizado parou)
pause
