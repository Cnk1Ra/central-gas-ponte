# Instalador da Ponte da Bina - Central Gas (Windows)
# Baixa Node portatil + a ponte, pede o token uma vez, e deixa rodando sozinho (boot + auto-restart).
$ErrorActionPreference = 'Stop'
$repo = 'https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main'

Write-Host ''
Write-Host '==================================================' -ForegroundColor Green
Write-Host '   Ponte da Bina - Central Gas (instalador)' -ForegroundColor Green
Write-Host '==================================================' -ForegroundColor Green
Write-Host ''

$base = Join-Path $env:LOCALAPPDATA 'CentralGasPonte'
New-Item -ItemType Directory -Force -Path $base | Out-Null

# 1) Node portatil (so baixa se nao tiver)
$nodeExe = Join-Path $base 'node\node.exe'
if (-not (Test-Path $nodeExe)) {
  Write-Host '-> Baixando o Node (uma vez so)...' -ForegroundColor Cyan
  $ver = 'v20.18.0'
  $zip = Join-Path $base 'node.zip'
  Invoke-WebRequest "https://nodejs.org/dist/$ver/node-$ver-win-x64.zip" -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $base -Force
  $nd = Join-Path $base 'node'
  if (Test-Path $nd) { Remove-Item $nd -Recurse -Force }
  Rename-Item (Join-Path $base "node-$ver-win-x64") $nd
  Remove-Item $zip
}

# 2) a ponte (sem segredo nenhum)
Write-Host '-> Baixando a ponte...' -ForegroundColor Cyan
Invoke-WebRequest "$repo/ponte.js" -OutFile (Join-Path $base 'ponte.js') -UseBasicParsing

# 3) configuracao (.env): anon key publica embutida; o token voce cola agora
$anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4Y3p4dWFuempkcnl4dmppbnVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MzU4NDIsImV4cCI6MjA5ODQxMTg0Mn0.HXKpY8SoxXOKgp0aY4UTh5pQ50CsXUrQXDWlsAKtQU0'
Write-Host ''
$token = Read-Host 'Cole o TOKEN de ingestao e tecle Enter'
$envTxt = "SUPABASE_URL=https://qxczxuanzjdryxvjinuo.supabase.co`r`nSUPABASE_ANON_KEY=$anon`r`nINGEST_TOKEN=$token`r`nSYSLOG_PORT=514`r`nDEBOUNCE_MS=6000`r`n"
Set-Content -Path (Join-Path $base '.env') -Value $envTxt -Encoding ascii

# 4) launcher que reinicia sozinho em caso de queda (loop) e roda escondido
$rodar = "@echo off`r`ncd /d `"$base`"`r`n:loop`r`n`"$base\node\node.exe`" ponte.js`r`ntimeout /t 3 /nobreak >nul`r`ngoto loop`r`n"
Set-Content -Path (Join-Path $base 'rodar.cmd') -Value $rodar -Encoding ascii
$vbs = "CreateObject(`"WScript.Shell`").Run `"cmd /c """"$base\rodar.cmd""""`", 0, False"
Set-Content -Path (Join-Path $base 'rodar-oculto.vbs') -Value $vbs -Encoding ascii

# 5) tarefa agendada: sobe sozinha quando o PC liga/loga
schtasks /Create /TN 'CentralGasPonte' /TR "wscript.exe `"$base\rodar-oculto.vbs`"" /SC ONLOGON /RL LIMITED /F | Out-Null

# 6) para uma instancia antiga e inicia agora
schtasks /End /TN 'CentralGasPonte' 2>$null | Out-Null
Start-Process wscript.exe -ArgumentList "`"$base\rodar-oculto.vbs`""

Write-Host ''
Write-Host 'PRONTO! A ponte esta rodando e vai subir sozinha quando o PC ligar.' -ForegroundColor Green
Write-Host "Pasta: $base"
Write-Host ''
Write-Host 'TESTE: faca uma ligacao pro telefone da loja e veja se aparece na Central de Chamadas.' -ForegroundColor Yellow
Write-Host 'Se nao aparecer, rode o modo aprendizado e mande o resultado:' -ForegroundColor Yellow
Write-Host "   cd `"$base`"  ;  `$env:LEARN=1 ; .\node\node.exe ponte.js" -ForegroundColor Yellow
Write-Host ''
Read-Host 'Tecle Enter para fechar'
