# Local DB maintenance (uses DATABASE_URL from .env)
#   .\scripts\maintenance\run_db_maintenance.ps1
# Production (SSH + docker):
#   .\scripts\maintenance\run_db_maintenance.ps1 -Prod
# Dry-run:
#   .\scripts\maintenance\run_db_maintenance.ps1 -DryRun

param(
    [switch]$Prod,
    [switch]$DryRun,
    [switch]$Vacuum,
    [int]$MaxAgeDays = 0
)

$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$Args = @()
if (-not $DryRun) { $Args += "--apply" }
if ($Vacuum -and -not $DryRun) { $Args += "--vacuum" }
if ($MaxAgeDays -gt 0) { $Args += @("--max-age-days", "$MaxAgeDays") }

if ($Prod) {
    python scripts/maintenance/run_prod_db_maintenance.py @Args
} else {
    python scripts/maintenance/maintain_database.py @Args
}
exit $LASTEXITCODE
