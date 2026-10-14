<#
.SYNOPSIS
    Extracts Kolkata Durga Puja pandals from DharmKriya, Pujor Shohor, PujoRoute, and additional public sources.
.DESCRIPTION
    Runs the comprehensive data-engineering extraction pipeline, performs cross-source deduplication,
    and produces audited CSV files in data/pandals/.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  PujoRoute -- Comprehensive Kolkata Durga Puja Pandal Extraction Pipeline      " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Working Directory: $repoRoot" -ForegroundColor Gray
Write-Host "Timestamp (UTC)  : $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))" -ForegroundColor Gray

# Ensure Python is installed
$pythonCmd = Get-Command python, py -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pythonCmd) {
    Write-Error "Python 3 is required to run the extraction engine but was not found on PATH."
    exit 1
}

$engineScript = Join-Path $PSScriptRoot "extract_engine.py"
if (-not (Test-Path $engineScript)) {
    Write-Error "Extraction engine script not found at $engineScript"
    exit 1
}

Write-Host "Executing extraction engine with $($pythonCmd.Name)..." -ForegroundColor Yellow
& $pythonCmd.Name $engineScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "Extraction engine exited with code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Extraction completed successfully!" -ForegroundColor Green
Write-Host "Deliverable CSV files generated in: data/pandals/" -ForegroundColor Green
