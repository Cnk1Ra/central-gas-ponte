# Auto-inicio da Ponte da Bina - Central Gas (Windows)
# Registra a ponte pra subir sozinha no boot e ja inicia agora.
# Use quando a ponte ja esta instalada e configurada (.env pronto).
$base = Join-Path $env:LOCALAPPDATA 'CentralGasPonte'

try {
  $ErrorActionPreference = 'Stop'
  Write-Host ''
  Write-Host '=== Auto-inicio da Ponte da Bina ===' -ForegroundColor Green

  if (-not (Test-Path (Join-Path $base 'ponte.js'))) { throw "Nao achei a ponte em $base. Rode o INSTALAR-PONTE.bat primeiro." }
  if (-not (Test-Path (Join-Path $base '.env'))) { throw "Nao achei o .env em $base. Falta a configuracao (token)." }

  # launcher que reinicia sozinho em caso de queda (loop), rodando escondido
  $rodar = "@echo off`r`ncd /d `"$base`"`r`n:loop`r`n`"$base\node\node.exe`" ponte.js`r`ntimeout /t 3 /nobreak >nul`r`ngoto loop`r`n"
  Set-Content -Path (Join-Path $base 'rodar.cmd') -Value $rodar -Encoding ascii
  $vbs = "CreateObject(`"WScript.Shell`").Run `"cmd /c """"$base\rodar.cmd""""`", 0, False"
  Set-Content -Path (Join-Path $base 'rodar-oculto.vbs') -Value $vbs -Encoding ascii

  # tarefa agendada: sobe sozinha quando o PC liga/loga
  schtasks /Create /TN 'CentralGasPonte' /TR "wscript.exe \"$base\rodar-oculto.vbs\"" /SC ONLOGON /RL LIMITED /F | Out-Null
  Write-Host '-> Auto-inicio no boot: configurado.' -ForegroundColor Cyan

  # mata instancias antigas do node da ponte (se houver) e inicia agora
  Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" | Where-Object { $_.CommandLine -like '*CentralGasPonte*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Process wscript.exe -ArgumentList "`"$base\rodar-oculto.vbs`""

  Write-Host ''
  Write-Host 'PRONTO! A ponte esta rodando escondida e sobe sozinha quando o PC ligar.' -ForegroundColor Green
  Write-Host "Pasta: $base"
}
catch {
  Write-Host ''
  Write-Host '!!! DEU ERRO:' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
}
