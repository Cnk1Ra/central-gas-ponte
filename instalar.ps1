# Instalador da Ponte da Bina - Central Gas (Windows)
# Baixa Node portatil + a ponte e deixa rodando sozinho (boot + auto-restart + log).
# Token: usa $env:PONTE_TOKEN se existir (instalador baixado de dentro do app, ja
# configurado); so pergunta se vier vazio (instalacao manual).
$repo = 'https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main'
$base = Join-Path $env:LOCALAPPDATA 'CentralGasPonte'

function Pausar { Write-Host ''; Read-Host 'Tecle Enter para fechar' }

try {
  $ErrorActionPreference = 'Stop'
  Write-Host ''
  Write-Host '==================================================' -ForegroundColor Green
  Write-Host '   Ponte da Bina - Central Gas (instalador)' -ForegroundColor Green
  Write-Host '==================================================' -ForegroundColor Green
  Write-Host ''

  New-Item -ItemType Directory -Force -Path $base | Out-Null
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  # 1) Node portatil (so baixa se nao tiver)
  $nodeExe = Join-Path $base 'node\node.exe'
  if (-not (Test-Path $nodeExe)) {
    Write-Host '-> Baixando o Node (uma vez so, ~30 MB)...' -ForegroundColor Cyan
    $ver = 'v20.18.0'
    $zip = Join-Path $base 'node.zip'
    Invoke-WebRequest "https://nodejs.org/dist/$ver/node-$ver-win-x64.zip" -OutFile $zip -UseBasicParsing
    Write-Host '-> Extraindo o Node...' -ForegroundColor Cyan
    $nd = Join-Path $base 'node'
    if (Test-Path $nd) { Remove-Item $nd -Recurse -Force }
    $extr = Join-Path $base "node-$ver-win-x64"
    if (Test-Path $extr) { Remove-Item $extr -Recurse -Force }
    Expand-Archive $zip -DestinationPath $base -Force
    Rename-Item $extr $nd
    Remove-Item $zip -Force
  }

  # 2) a ponte (sem segredo nenhum) + package.json (marca como modulo ES p/ os import)
  Write-Host '-> Baixando a ponte...' -ForegroundColor Cyan
  Invoke-WebRequest "$repo/ponte.js" -OutFile (Join-Path $base 'ponte.js') -UseBasicParsing
  Set-Content -Path (Join-Path $base 'package.json') -Value '{ "type": "module" }' -Encoding ascii

  # 3) configuracao (.env): anon key publica embutida; token do app ou digitado
  $anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4Y3p4dWFuempkcnl4dmppbnVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MzU4NDIsImV4cCI6MjA5ODQxMTg0Mn0.HXKpY8SoxXOKgp0aY4UTh5pQ50CsXUrQXDWlsAKtQU0'
  $token = $env:PONTE_TOKEN
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host ''
    $token = Read-Host 'Cole o TOKEN de ingestao e tecle Enter'
    if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token vazio. Rode de novo e cole o token (botao direito do mouse cola no terminal).' }
  } else {
    Write-Host '-> Token: ja veio configurado no instalador.' -ForegroundColor Cyan
  }
  $envTxt = "SUPABASE_URL=https://qxczxuanzjdryxvjinuo.supabase.co`r`nSUPABASE_ANON_KEY=$anon`r`nINGEST_TOKEN=$($token.Trim())`r`nSYSLOG_PORT=514`r`nBRAID_PORT=6590`r`nDEBOUNCE_MS=6000`r`n"
  Set-Content -Path (Join-Path $base '.env') -Value $envTxt -Encoding ascii

  # 4) launcher que reinicia sozinho em caso de queda (loop), rodando escondido.
  # Tudo que a ponte imprime vai pro ponte.log (apaga quando passa de 5MB).
  $rodar = "@echo off`r`ncd /d `"$base`"`r`n:loop`r`nif exist ponte.log for %%A in (ponte.log) do if %%~zA gtr 5242880 del ponte.log`r`n`"$base\node\node.exe`" ponte.js >> ponte.log 2>&1`r`ntimeout /t 3 /nobreak >nul`r`ngoto loop`r`n"
  Set-Content -Path (Join-Path $base 'rodar.cmd') -Value $rodar -Encoding ascii
  $vbs = "CreateObject(`"WScript.Shell`").Run `"cmd /c """"$base\rodar.cmd""""`", 0, False"
  Set-Content -Path (Join-Path $base 'rodar-oculto.vbs') -Value $vbs -Encoding ascii

  # 5) firewall: o HT814 precisa alcancar este PC na UDP 514. Como a ponte roda
  # escondida, o Windows nunca mostra o aviso de liberacao - sem a regra o syslog
  # pode ser bloqueado em silencio. Precisa de admin; nao-fatal se nao der.
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if ($isAdmin) {
    netsh advfirewall firewall delete rule name="CentralGasPonte Syslog" *> $null
    netsh advfirewall firewall add rule name="CentralGasPonte Syslog" dir=in action=allow protocol=UDP localport=514 | Out-Null
    netsh advfirewall firewall delete rule name="CentralGasPonte BraiD" *> $null
    netsh advfirewall firewall add rule name="CentralGasPonte BraiD" dir=in action=allow protocol=UDP localport=6590 | Out-Null
    Write-Host '-> Firewall: portas UDP 514 (syslog) e 6590 (BraiD) liberadas.' -ForegroundColor Cyan
  } else {
    Write-Host '-> AVISO: sem admin, nao deu pra liberar o firewall (UDP 514 e 6590).' -ForegroundColor Yellow
    Write-Host '   Rode o instalador de novo: botao direito > Executar como administrador.' -ForegroundColor Yellow
  }

  # auto-inicio no boot: atalho na pasta Inicializar (a prova de aspas no caminho -
  # o schtasks /TR quebrava com espaco/acento no perfil) + tarefa agendada de reforco
  $boot = 'FALHOU'
  try {
    $startup = [Environment]::GetFolderPath('Startup')
    if (-not (Test-Path $startup)) { New-Item -ItemType Directory -Force -Path $startup | Out-Null }
    Copy-Item (Join-Path $base 'rodar-oculto.vbs') (Join-Path $startup 'CentralGasPonte.vbs') -Force
    $boot = 'configurado (pasta Inicializar)'
  } catch {}
  try { schtasks /Delete /TN 'CentralGasPonte' /F 2>&1 | Out-Null } catch {}
  try {
    $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + (Join-Path $base 'rodar-oculto.vbs') + '"')
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName 'CentralGasPonte' -Action $action -Trigger $trigger -Force | Out-Null
    $boot = $boot + ' + tarefa agendada'
  } catch {}
  Write-Host "-> Auto-inicio no boot: $boot" -ForegroundColor Cyan

  # 7) mata a ponte antiga inteira (loop rodar.cmd + vbs + node) e inicia a nova,
  # senao o loop antigo ressuscita o node e briga pela porta 514 com o novo
  Get-CimInstance Win32_Process | Where-Object { ($_.CommandLine -like '*rodar.cmd*') -or ($_.CommandLine -like '*rodar-oculto.vbs*') -or ($_.Name -eq 'node.exe' -and $_.CommandLine -like '*CentralGasPonte*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Process wscript.exe -ArgumentList "`"$base\rodar-oculto.vbs`""

  Write-Host ''
  Write-Host 'PRONTO! A ponte esta rodando e sobe sozinha quando o PC ligar.' -ForegroundColor Green
  Write-Host "Pasta: $base"
  Write-Host ''
  Write-Host 'PROXIMO: no PC principal, abra o BraiD (bandeja, perto do relogio) ->' -ForegroundColor Yellow
  Write-Host 'Configuracoes de IPs -> adicione o IP deste PC com a porta 6590 em cada linha.' -ForegroundColor Yellow
  Write-Host 'Depois faca uma ligacao de teste e veja se aparece na Central de Chamadas.' -ForegroundColor Yellow
  Pausar
}
catch {
  Write-Host ''
  Write-Host '!!! DEU ERRO NA INSTALACAO:' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  try { Set-Content -Path (Join-Path $base 'erro.txt') -Value ($_ | Out-String) -Encoding utf8 } catch {}
  Write-Host ''
  Write-Host 'Tire um print desta tela e mande pro suporte.' -ForegroundColor Yellow
  Pausar
}
