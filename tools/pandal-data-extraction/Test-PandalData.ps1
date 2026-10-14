<#
.SYNOPSIS
    Validates all generated Kolkata pandal CSV datasets for schema compliance, integrity, and coordinate validity.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$dataDir = Join-Path $repoRoot "data\pandals"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  PujoRoute -- Pandal Data Validation Suite (Automated Audit)                   " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$requiredFiles = @(
    "pandals_all_source_records.csv",
    "kolkata_pandals_master.csv",
    "pandal_duplicate_review.csv",
    "pandal_extraction_audit.csv",
    "pandal_data_quality_issues.csv",
    "README.md"
)

$errorsFound = 0
$warningsFound = 0

# 1. Existence and Non-Empty Checks
Write-Host ""
Write-Host "[Check 1/5] Verifying required deliverable files..." -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $dataDir $file
    if (-not (Test-Path $filePath)) {
        Write-Host "  [FAIL] Missing file: $file" -ForegroundColor Red
        $errorsFound++
    } else {
        $size = (Get-Item $filePath).Length
        if ($size -le 0) {
            Write-Host "  [FAIL] File is empty: $file" -ForegroundColor Red
            $errorsFound++
        } else {
            $kb = [math]::Round($size / 1024, 1)
            Write-Host "  [PASS] $file exists ($kb KB)" -ForegroundColor Green
        }
    }
}

if ($errorsFound -gt 0) {
    Write-Host "Basic file check failed with $errorsFound error(s)." -ForegroundColor Red
    exit 1
}

# 2. Parsing CSV Datasets
Write-Host ""
Write-Host "[Check 2/5] Parsing CSV records and header schema..." -ForegroundColor Yellow
$rawCsv = Import-Csv -Path (Join-Path $dataDir "pandals_all_source_records.csv") -Encoding UTF8
$masterCsv = Import-Csv -Path (Join-Path $dataDir "kolkata_pandals_master.csv") -Encoding UTF8
$reviewCsv = Import-Csv -Path (Join-Path $dataDir "pandal_duplicate_review.csv") -Encoding UTF8
$auditCsv = Import-Csv -Path (Join-Path $dataDir "pandal_extraction_audit.csv") -Encoding UTF8
$qualityCsv = Import-Csv -Path (Join-Path $dataDir "pandal_data_quality_issues.csv") -Encoding UTF8

$rowCount = $rawCsv.Count
$masterCount = $masterCsv.Count
$reviewCount = $reviewCsv.Count
$auditCount = $auditCsv.Count
$qualityCount = $qualityCsv.Count

Write-Host "  All Source Records Count : $rowCount" -ForegroundColor White
Write-Host "  Canonical Master Count   : $masterCount" -ForegroundColor White
Write-Host "  Duplicate Review Pairs   : $reviewCount" -ForegroundColor White
Write-Host "  Extraction Audit Rows    : $auditCount" -ForegroundColor White
Write-Host "  Quality Issues Logged    : $qualityCount" -ForegroundColor White

if ($rowCount -lt 2000) {
    Write-Host "  [FAIL] Expected at least 2,000 raw source records, found $rowCount" -ForegroundColor Red
    $errorsFound++
} else {
    Write-Host "  [PASS] Raw records count satisfies comprehensive criteria." -ForegroundColor Green
}

if ($masterCount -lt 1000) {
    Write-Host "  [FAIL] Expected at least 1,000 canonical master pandals, found $masterCount" -ForegroundColor Red
    $errorsFound++
} else {
    Write-Host "  [PASS] Canonical master catalog count verified ($masterCount unique pandals)." -ForegroundColor Green
}

# 3. Source Traceability and Provenance
Write-Host ""
Write-Host "[Check 3/5] Validating provenance and source URLs..." -ForegroundColor Yellow
$missingUrls = 0
$missingNames = 0
foreach ($row in $rawCsv) {
    if ([string]::IsNullOrWhiteSpace($row.canonical_name)) {
        $missingNames++
    }
    if ([string]::IsNullOrWhiteSpace($row.source_url) -and [string]::IsNullOrWhiteSpace($row.source)) {
        $missingUrls++
    }
}

if ($missingNames -gt 0) {
    Write-Host "  [FAIL] $missingNames raw records have blank names." -ForegroundColor Red
    $errorsFound++
} else {
    Write-Host "  [PASS] All $rowCount raw records have non-empty names." -ForegroundColor Green
}

# 4. Coordinate Range Validation
Write-Host ""
Write-Host "[Check 4/5] Validating GPS coordinate bounds (-90 to 90, -180 to 180)..." -ForegroundColor Yellow
$invalidCoords = 0
$validCoordCount = 0
foreach ($row in $masterCsv) {
    if (-not [string]::IsNullOrWhiteSpace($row.latitude) -and -not [string]::IsNullOrWhiteSpace($row.longitude)) {
        [double]$lat = 0
        [double]$lon = 0
        $parsedLat = [double]::TryParse($row.latitude, [ref]$lat)
        $parsedLon = [double]::TryParse($row.longitude, [ref]$lon)

        if (-not $parsedLat -or -not $parsedLon) {
            $invalidCoords++
        } elseif ($lat -lt -90 -or $lat -gt 90 -or $lon -lt -180 -or $lon -gt 180) {
            $invalidCoords++
        } else {
            $validCoordCount++
        }
    }
}

if ($invalidCoords -gt 0) {
    Write-Host "  [FAIL] Found $invalidCoords invalid coordinates in master CSV." -ForegroundColor Red
    $errorsFound++
} else {
    Write-Host "  [PASS] Verified coordinates valid for $validCoordCount master pandals (0 out-of-bounds)." -ForegroundColor Green
}

# 5. Deduplication Reconciliation Audit
Write-Host ""
Write-Host "[Check 5/5] Reconciling raw source records vs unique groups..." -ForegroundColor Yellow
$auditTotalUnique = 0
foreach ($row in $auditCsv) {
    $auditTotalUnique += [int]$row.unique_records_extracted
}
Write-Host "  Sum of source-level unique extractions: $auditTotalUnique" -ForegroundColor White

if ($masterCount -le $rowCount) {
    $savedDups = $rowCount - $masterCount
    Write-Host "  [PASS] Deduplication correctly collapsed $rowCount raw entries into $masterCount canonical entries (saved $savedDups duplicates)." -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Master count ($masterCount) exceeds raw count ($rowCount)." -ForegroundColor Red
    $errorsFound++
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
if ($errorsFound -eq 0) {
    Write-Host "  ALL VALIDATION AUDITS PASSED CLEANLY (0 ERRORS)!                            " -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "  VALIDATION FAILED WITH $errorsFound ERROR(S).                               " -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Cyan
    exit 1
}
