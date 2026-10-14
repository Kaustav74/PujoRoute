# Kolkata Durga Puja Pandal Comprehensive Datasets

## Overview

This directory contains the audited, comprehensive Kolkata Durga Puja pandal census extracted, reconciled, and deduplicated across primary online directories and the existing PujoRoute catalogue.

Generated on: `2026-10-14T18:36:27Z`

## Deliverables Summary

| File | Description | Record Count |
| :--- | :--- | :--- |
| [`pandals_all_source_records.csv`](pandals_all_source_records.csv) | Complete extracted source records before merging with full provenance | `2244` |
| [`kolkata_pandals_master.csv`](kolkata_pandals_master.csv) | Canonical deduplicated master catalog with verified coordinates and merged aliases | `1159` |
| [`pandal_duplicate_review.csv`](pandal_duplicate_review.csv) | Cross-source duplicate review queue with similarity scores, distances, and rationales | `1085` |
| [`pandal_extraction_audit.csv`](pandal_extraction_audit.csv) | Source-level extraction audit logging advertised totals vs extracted counts | `5` |
| [`pandal_data_quality_issues.csv`](pandal_data_quality_issues.csv) | Identified data quality warnings (unverified coordinates, missing localities) | `99` |

## Source Totals vs Advertised Counts

| Source | Advertised Total | Extracted Raw | Duplicate Rows | Unique Extracted | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DharmKriya** | ~786 | `789` | `0` | `789` | `Success` |
| **Pujor Shohor** | ~686 | `686` | `0` | `686` | `Success` |
| **PujoRoute Production** | 532 | `532` | `17` | `532` | `Success` |
| **MoodKolkata** | 191 | `193` | `1` | `192` | `Success` |
| **2026 Research Intake** | 45 | `45` | `0` | `45` | `Success` |
| **Total Raw** | **2,240** | **`2244`** | - | **`2244`** | **Complete** |

## Deduplication & Reconciliation Rules

1. **Exact Normalized Sequence**: Token normalization, stop-word removal, and transliteration alignment (`sarbojanin` ↔ `sarbajanin`, `durgotsav` ↔ `puja`).
2. **Coordinate Proximity Clustering**: Physical proximity (< 120 meters) combined with name token overlap confirms co-located pandals across sources.
3. **Transparent Review Queue**: All multi-source matches are logged to `pandal_duplicate_review.csv` with distance in meters, similarity score, and match justification. No records are silently discarded.
4. **Coordinate Integrity**: Coordinates are preserved directly from source metadata; coordinates are never fabricated.

## Reproducibility Commands

To rerun the full extraction and validation from repository root:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\pandal-data-extraction\Extract-Pandals.ps1"
powershell -ExecutionPolicy Bypass -File ".\tools\pandal-data-extraction\Test-PandalData.ps1"
```
