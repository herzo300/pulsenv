# Local Telegram backfill into production DB via SSH tunnel.
# Usage:
#   .\scripts\maintenance\run_local_backfill_prod.ps1
#   .\scripts\maintenance\run_local_backfill_prod.ps1 -PruneOnly
#   .\scripts\maintenance\run_local_backfill_prod.ps1 -Days 14

param(
    [int]$Days = 30,
    [switch]$Prune,
    [switch]$PruneOnly,
    [ValidateSet("auto", "telethon", "web")]
    [string]$Source = "auto"
)

$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$Args = @("scripts/maintenance/local_backfill_prod.py", "--days", "$Days", "--source", $Source)
if ($Prune) { $Args += "--prune" }
if ($PruneOnly) { $Args += "--prune-only" }

python @Args
exit $LASTEXITCODE
