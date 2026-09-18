param(
  [int]$BackendPort = 8000
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
New-Item -ItemType Directory -Force -Path "logs" | Out-Null

python scripts/maintenance/ensure_runtime_indexes.py

$existing = Get-NetTCPConnection -LocalPort $BackendPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $existing) {
  Start-Process -FilePath python `
    -ArgumentList @("-m", "uvicorn", "services.Backend.app:app", "--host", "0.0.0.0", "--port", "$BackendPort") `
    -WorkingDirectory $Root `
    -RedirectStandardOutput "logs/desktop_backend.out.log" `
    -RedirectStandardError "logs/desktop_backend.err.log" `
    -WindowStyle Hidden
  Start-Sleep -Seconds 8
}

$monitor = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match "python" -and $_.CommandLine -match "start_all_monitoring.py"
} | Select-Object -First 1
if (-not $monitor) {
  Start-Process -FilePath python `
    -ArgumentList @("start_all_monitoring.py") `
    -WorkingDirectory $Root `
    -RedirectStandardOutput "logs/desktop_monitoring.out.log" `
    -RedirectStandardError "logs/desktop_monitoring.err.log" `
    -WindowStyle Hidden
}

python scripts/maintenance/runtime_health_gate.py
