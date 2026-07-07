@echo off
setlocal
set BASE=%LOCALAPPDATA%\CentralGasPonte
echo ==============================================
echo   VERIFICACAO DA PONTE DA BINA - CENTRAL GAS
echo ==============================================
echo.
echo [1] Inicio automatico no boot:
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CentralGasPonte.vbs" (echo    Pasta Inicializar OK) else (echo    SEM atalho na Inicializar - rode o ATUALIZAR-BINA.bat)
schtasks /Query /TN CentralGasPonte >nul 2>nul && (echo    Tarefa agendada OK) || (echo    sem tarefa agendada - ok se a Inicializar estiver OK)
echo.
echo [2] Ponte rodando agora (node.exe):
tasklist /FI "IMAGENAME eq node.exe" 2>nul | findstr /I "node.exe" || echo    NENHUM node.exe rodando - rode o AUTOINICIO.bat
echo.
echo [3] Escutando a bina (UDP 6590 BraiD / 514 syslog):
netstat -ano -p UDP | findstr /C:":6590 " || echo    NADA escutando na porta 6590 (BraiD)
netstat -ano -p UDP | findstr /C:":514 " || echo    NADA escutando na porta 514 (syslog)
echo.
echo [4] Regras do firewall (deixam a bina chegar no PC):
netsh advfirewall firewall show rule name="CentralGasPonte BraiD" >nul 2>&1 && (echo    Regra BraiD OK) || (echo    SEM REGRA BraiD - rode o ATUALIZAR-BINA.bat como administrador)
netsh advfirewall firewall show rule name="CentralGasPonte Syslog" >nul 2>&1 && (echo    Regra Syslog OK) || (echo    SEM REGRA Syslog)
echo.
echo [5] Arquivos da ponte:
if exist "%BASE%\ponte.js" (echo    ponte.js OK) else (echo    FALTA ponte.js - rode o INSTALAR-PONTE.bat)
if exist "%BASE%\.env" (echo    .env OK) else (echo    FALTA .env - falta o token)
echo.
echo [6] IP deste PC (e o que vai no BraiD "Enviar para mais IPs"):
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
