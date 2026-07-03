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
  # tudo que a ponte imprime vai pro ponte.log (apaga quando passa de 5MB)
  $rodar = "@echo off`r`ncd /d `"$base`"`r`n:loop`r`nif exist ponte.log for %%A in (ponte.log) do if %%~zA gtr 5242880 del ponte.log`r`n`"$base\node\node.exe`" ponte.js >> ponte.log 2>&1`r`ntimeout /t 3 /nobreak >nul`r`ngoto loop`r`n"
  Set-Content -Path (Join-Path $base 'rodar.cmd') -Value $rodar -Encoding ascii

  # libera a porta do syslog no firewall (o HT814 precisa alcancar este PC).
  # Como a ponte roda escondida, o Windows nunca mostra o aviso de liberacao -
  # sem esta regra o syslog pode ser bloqueado em silencio. Precisa de admin.
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if ($isAdmin) {
    netsh advfirewall firewall delete rule name="CentralGasPonte Syslog" *> $null
    netsh advfirewall firewall add rule name="CentralGasPonte Syslog" dir=in action=allow protocol=UDP localport=514 | Out-Null
    Write-Host '-> Firewall: porta UDP 514 liberada.' -ForegroundColor Cyan
  } else {
    Write-Host '-> AVISO: sem admin, nao deu pra liberar o firewall (UDP 514).' -ForegroundColor Yellow
    Write-Host '   Rode o AUTOINICIO.bat de novo: botao direito > Executar como administrador.' -ForegroundColor Yellow
  }
  $vbs = "CreateObject(`"WScript.Shell`").Run `"cmd /c """"$base\rodar.cmd""""`", 0, False"
  Set-Content -Path (Join-Path $base 'rodar-oculto.vbs') -Value $vbs -Encoding ascii

  # tarefa agendada: sobe sozinha quando o PC liga/loga
  schtasks /Create /TN 'CentralGasPonte' /TR "wscript.exe \"$base\rodar-oculto.vbs\"" /SC ONLOGON /RL LIMITED /F | Out-Null
  Write-Host '-> Auto-inicio no boot: configurado.' -ForegroundColor Cyan

  # mata a ponte antiga inteira (loop rodar.cmd + vbs + node) antes de iniciar de novo,
  # senao o loop antigo ressuscita o node e briga pela porta 514 com o novo
  Get-CimInstance Win32_Process | Where-Object { ($_.CommandLine -like '*rodar.cmd*') -or ($_.CommandLine -like '*rodar-oculto.vbs*') -or ($_.Name -eq 'node.exe' -and $_.CommandLine -like '*CentralGasPonte*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
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
