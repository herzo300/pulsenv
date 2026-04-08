$ErrorActionPreference = "Stop"

$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$userHome = $env:USERPROFILE
$targetDir = Join-Path $userHome "tools\openclaude-lite"
$binDir = Join-Path $userHome "bin"
$configPath = Join-Path $userHome ".openclaude-lite.json"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

Copy-Item -LiteralPath (Join-Path $sourceDir "oclaude.py") -Destination (Join-Path $targetDir "oclaude.py") -Force
Copy-Item -LiteralPath (Join-Path $sourceDir "README.md") -Destination (Join-Path $targetDir "README.md") -Force

$wrapper = "@echo off`r`n`"%LocalAppData%\Python\bin\python.exe`" `"%USERPROFILE%\tools\openclaude-lite\oclaude.py`" %*"
Set-Content -LiteralPath (Join-Path $binDir "oclaude.cmd") -Value $wrapper -Encoding ASCII
Set-Content -LiteralPath (Join-Path $binDir "openclaude.cmd") -Value $wrapper -Encoding ASCII

if (-not (Test-Path $configPath)) {
  @'
{
  "base_url": "http://127.0.0.1:4000/v1",
  "api_key_env": "LITELLM_MASTER_KEY",
  "model": "qwen-mini"
}
'@ | Set-Content -LiteralPath $configPath -Encoding UTF8
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) {
  $userPath = ""
}

$parts = $userPath -split ";" | Where-Object { $_ }
if ($parts -notcontains $binDir) {
  $newPath = if ($userPath) { "$userPath;$binDir" } else { $binDir }
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  $env:Path = "$env:Path;$binDir"
}

Write-Host "Installed OpenClaude Lite to $targetDir"
Write-Host "Command wrappers: $binDir\oclaude.cmd and $binDir\openclaude.cmd"
Write-Host "Config file: $configPath"
