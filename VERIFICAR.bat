@echo off
setlocal
set BASE=%LOCALAPPDATA%\CentralGasPonte
echo ==============================================
echo   VERIFICACAO DA PONTE DA BINA - CENTRAL GAS
echo ==============================================
echo.
echo [1] Tarefa agendada (sobe sozinha no boot):
schtasks /Query /TN CentralGasPonte 2>nul || echo    NAO ENCONTRADA - rode o AUTOINICIO.bat
echo.
echo [2] Ponte rodando agora (node.exe):
tasklist /FI "IMAGENAME eq node.exe" 2>nul | findstr /I "node.exe" || echo    NENHUM node.exe rodando - rode o AUTOINICIO.bat
echo.
echo [3] Escutando a bina (porta UDP 514):
netstat -ano -p UDP | findstr /C:":514 " || echo    NADA escutando na porta 514
echo.
echo [4] Regra do firewall (deixa o HT814 falar com o PC):
netsh advfirewall firewall show rule name="CentralGasPonte Syslog" >nul 2>&1 && (echo    Regra OK) || (echo    SEM REGRA - rode o AUTOINICIO.bat como administrador)
echo.
echo [5] Arquivos da ponte:
if exist "%BASE%\ponte.js" (echo    ponte.js OK) else (echo    FALTA ponte.js - rode o INSTALAR-PONTE.bat)
if exist "%BASE%\.env" (echo    .env OK) else (echo    FALTA .env - falta o token)
echo.
echo [6] IP deste PC (e o que vai no Syslog Server do HT814):
ipconfig | findstr /I "IPv4"
echo.
echo [7] Ultimas linhas do log da ponte:
if exist "%BASE%\ponte.log" (powershell -NoProfile -Command "Get-Content -Tail 15 '%BASE%\ponte.log'") else (echo    sem ponte.log ainda - rode o AUTOINICIO.bat de novo pra ligar o log)
echo.
echo ==============================================
echo   Tire uma FOTO desta tela (ou selecione o
echo   texto, Enter copia) e mande pro Fabricio.
echo ==============================================
echo.
pause
