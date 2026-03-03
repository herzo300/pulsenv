Param(
    [string]$TargetDir = "services\uvr5-ui",
    [int]$Port = 7860
)

$ErrorActionPreference = "Stop"

Write-Host "== UVR5 Mini App setup ==" -ForegroundColor Cyan

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git не найден в PATH"
}

if (-not (Test-Path $TargetDir)) {
    git clone https://github.com/Eddycrack864/UVR5-UI.git $TargetDir
} else {
    Write-Host "Target already exists: $TargetDir" -ForegroundColor Yellow
}

Push-Location $TargetDir
try {
    if (-not (Test-Path ".venv")) {
        python -m venv .venv
    }

    .\.venv\Scripts\Activate.ps1
    python -m pip install --upgrade pip
    pip install -r requirements.txt

    Write-Host ""
    Write-Host "Setup complete." -ForegroundColor Green
    Write-Host "Run UVR5 UI:" -ForegroundColor Cyan
    Write-Host "  cd $TargetDir"
    Write-Host "  .\.venv\Scripts\Activate.ps1"
    Write-Host "  python app.py --server_port $Port --server_name 0.0.0.0"
    Write-Host ""
    Write-Host "Then set in .env:" -ForegroundColor Cyan
    Write-Host "  UVR5_MINIAPP_URL=https://<your-public-url>"
} finally {
    Pop-Location
}
