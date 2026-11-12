# Windows launcher: run the same lifecycle contract in WSL2.
$ErrorActionPreference = 'Stop'
$script = (Join-Path $PSScriptRoot 'status-state-017-portfolio-lookthrough-generated.sh')
$linuxScript = wsl.exe wslpath -a $script
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
wsl.exe bash $linuxScript @args
exit $LASTEXITCODE
