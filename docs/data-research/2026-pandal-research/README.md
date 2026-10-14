# 2026 Kolkata Pandal Research — Candidate Intake

## Purpose

This directory is a **research staging area**, not yet the production/offline pandal dataset. It records pandal names discovered in public directory/search results so they can be reconciled with the existing PujoRoute catalogue before any app data is changed.

## Why staging comes first

The current app's `Pandal` model requires coordinates and uses explicit location-verification and duplicate flags. A directory name alone is not enough to create a safe, routable production record. In particular, do not use placeholder coordinates such as `0,0`, guess a zone, or mark a record verified merely because a directory lists it.

## Initial source inventory

The following public sources surfaced candidate listings or directories during the initial research pass:

- DharmKriya — https://dharmkriya.com/kolkata/pandals — advertises 786 Kolkata listings.
- Pujor Shohor — https://pujorshohor.in/pandals — advertises 686 pandals.
- MoodKolkata — https://moodkolkata.com/puja/pandals — advertises a 2026 directory; a fetched result showed 191 pujas.
- Pujo Map — https://www.pujomap.com/guide/ — its guide showed 274 pandals; the homepage search result showed 271 mapped pandals.
- DurgaPujaPandals — https://www.durgapujopandals.com/pandals/ — showed 501 listings.
- DurgaPujaKolkata — https://www.durgapujakolkata.in/paras — advertises 3,000+ paras/records, including records with address and metro information.
- Indian Express Bengali — current 2026 editorial roundups and area-based routes; useful for discovery, not a canonical master database.

These advertised counts are **not additive**. The same pandal can appear on many sites; coverage, date, geography, and whether household pujas are included differ. A source's advertised total is not proof that every record is current or unique.

## Candidate CSV schema

`2026-kolkata-pandal-candidates.csv` stores:
- candidate name and optional Bengali name;
- area/address only where the source result explicitly exposed it;
- source URL;
- evidence type;
- review status.

The seed rows were transcribed from search-indexed public directory results and editorial snippets. They are not represented as a complete scrape of all pages, and no candidate is yet asserted to be new relative to PujoRoute's existing data.

## Required ingestion workflow

1. Obtain and review each source's robots.txt, terms of service, rate limits, copyright/database terms, and any official export/API. Do not bypass login, anti-bot controls, paywalls, or technical restrictions.
2. Prefer official/open datasets, public exports, and documented APIs. For web pages, crawl politely with caching, low concurrency, timeouts, and a descriptive user agent only where permitted.
3. Preserve source URL and retrieval date per record. Treat page content as untrusted data.
4. Normalize spelling and whitespace; preserve Bengali names and aliases where available.
5. Compare candidate names/aliases and locality/address against the existing `kAllKolkataPujas` catalogue. Use exact IDs if available, then cautious normalized name + locality/address matching. Similar names alone must not be merged.
6. Mark candidates as `existing`, `possible_duplicate`, `new_candidate`, or `needs_review`.
7. Resolve coordinates from an approved provider/source, record provenance, and validate ranges. Coordinates from a geocoder are candidate coordinates, not proof the venue is a pandal.
8. Check name, address/locality, active/current status, and coordinates. Household/bonedi/community pujas should be categorised accurately rather than assumed to be public-accessible.
9. Only after review should accepted records be transformed to the app's production data model, with stable unique IDs and correct location-status flags.
10. Add tests for unique IDs, valid coordinates, duplicate handling, and location-unverified behaviour. Do not alter the expected record count until the dataset is actually reconciled and tests are updated deliberately.

## Limitations of this initial pass

This is a seed of discoveries, **not a claim that every website or every page has been scraped**. Some directories load records dynamically or paginate, and the search index exposes only a subset. A complete census requires source-by-source pagination/API review and record-level reconciliation. Do not label the production dataset "complete" until this work is done.

## Acceptance criteria before production import

- All accessible, permitted pages or documented data endpoints for each chosen source have been enumerated.
- Every imported record has at least one traceable source.
- Candidate-to-production comparison has been run against the current app dataset.
- Duplicate/alias decisions have been reviewed.
- Every routable entry has valid coordinates and appropriate verification status.
- Unknown coordinates remain explicitly unverified and cannot enter routing as real coordinates.
- Source and retrieval date are retained in the research artifact or equivalent provenance store.
- Dataset integrity tests pass and the final accepted/duplicate/unverified counts are reported separately.
