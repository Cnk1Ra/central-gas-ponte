# Instalador da Ponte da Bina - Central Gas (Windows)
# Baixa Node portatil + a ponte, pede o token uma vez, e deixa rodando sozinho (boot + auto-restart).
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

  # 3) configuracao (.env): anon key publica embutida; o token voce cola agora
  $anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4Y3p4dWFuempkcnl4dmppbnVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MzU4NDIsImV4cCI6MjA5ODQxMTg0Mn0.HXKpY8SoxXOKgp0aY4UTh5pQ50CsXUrQXDWlsAKtQU0'
  Write-Host ''
  $token = Read-Host 'Cole o TOKEN de ingestao e tecle Enter'
  if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token vazio. Rode de novo e cole o token (botao direito do mouse cola no terminal).' }
  $envTxt = "SUPABASE_URL=https://qxczxuanzjdryxvjinuo.supabase.co`r`nSUPABASE_ANON_KEY=$anon`r`nINGEST_TOKEN=$($token.Trim())`r`nSYSLOG_PORT=514`r`nDEBOUNCE_MS=6000`r`n"
  Set-Content -Path (Join-Path $base '.env') -Value $envTxt -Encoding ascii

  # 4) launcher que reinicia sozinho em caso de queda (loop), rodando escondido
  $rodar = "@echo off`r`ncd /d `"$base`"`r`n:loop`r`n`"$base\node\node.exe`" ponte.js`r`ntimeout /t 3 /nobreak >nul`r`ngoto loop`r`n"
  Set-Content -Path (Join-Path $base 'rodar.cmd') -Value $rodar -Encoding ascii
  $vbs = "CreateObject(`"WScript.Shell`").Run `"cmd /c """"$base\rodar.cmd""""`", 0, False"
  Set-Content -Path (Join-Path $base 'rodar-oculto.vbs') -Value $vbs -Encoding ascii

  # 5) tarefa agendada: sobe sozinha quando o PC liga/loga (nao-fatal se falhar)
  try {
    schtasks /Create /TN 'CentralGasPonte' /TR "wscript.exe \"$base\rodar-oculto.vbs\"" /SC ONLOGON /RL LIMITED /F | Out-Null
    Write-Host '-> Auto-inicio no boot: configurado.' -ForegroundColor Cyan
  } catch {
    Write-Host '-> Aviso: nao consegui registrar o auto-inicio (a ponte vai rodar agora mesmo assim).' -ForegroundColor Yellow
  }

  # 6) inicia agora (escondido)
  Start-Process wscript.exe -ArgumentList "`"$base\rodar-oculto.vbs`""

  Write-Host ''
  Write-Host 'PRONTO! A ponte esta rodando e sobe sozinha quando o PC ligar.' -ForegroundColor Green
  Write-Host "Pasta: $base"
  Write-Host ''
  Write-Host 'PROXIMO: no HT814 (192.168.2.2) -> Syslog -> aponte para o IP deste PC, nivel DEBUG.' -ForegroundColor Yellow
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
