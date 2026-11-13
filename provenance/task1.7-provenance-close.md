# Task 1.7 — Close the provenance table

**Date:** 2026-08-31 · **Budget:** 1 h · **Status: complete. Phase 1 closed.**
Re-download test run against all 31 rows: **25 byte-identical, 3 credential-gated
(recipe complete), 3 exclusions**. No failing rows.

---

## 1. What Task 1.7 checks

Phase 1's grading condition, from the task sheet: *a stranger holding only the
provenance table can re-download every file.* Two parts:

1. **Every row complete.** Schema populated for all 31 rows, per `R/provenance.R`
   `PROV_COLS`.
2. **The re-download test.** Hand `sources.csv` to a fresh session; retrieve one
   file per source using nothing but the recorded `url`, `retrieval_method`, and
   `vintage`; confirm the bytes are what the `sha256` column says.

## 2. The table is complete

`prov_read()` parses clean — no schema drift. 31 rows: **28 retrieved, 3
excluded.**

| Column | State |
|---|---|
| `source_id`, `source`, `retrieval_date`, `url`, `retrieval_method`, `vintage`, `license` | populated for all 31 rows |
| `file`, `sha256` | populated for all 28 retrieved rows; empty for the 3 exclusions, as the schema requires |
| `parse_notes` | populated for all 28 retrieved rows; empty for the 3 exclusions (no file to parse) |
| `exclusion_reason` | populated for exactly the 3 excluded rows (`rand_hospital_data`, `adi_zip4_crosswalk`, `hud_usps_crosswalk`), empty for the other 28 — standing rule 4 |

`retrieval_method` is one of the seven `PROV_METHODS` on every row.

## 3. The re-download test

Script: `provenance/redownload-test.py` — standard library only, by the same
reasoning `R/provenance.R` is base R only: the recipe must not lean on tooling the
recipe does not name. It reads *only* `sources.csv`, resolves each row's recipe,
fetches a fresh copy, and diffs the sha256.

```
python3 provenance/redownload-test.py
```

### Result, 2026-08-31

| Verdict | n | Meaning |
|---|---|---|
| **MATCH** | 25 | fresh download hash-identical to the archived file |
| **CRED** | 3 | recipe complete; retrieval needs a free, documented credential the table deliberately does not carry |
| **NA** | 3 | not-retrieved source; nothing to fetch |
| FAIL | 0 | — |

All 25 retrievable sources came back **byte-for-byte identical** — every CMS
Provider Data Catalog file (`metastore API`), every data.cms.gov DCAT file
(`catalog API`), and every static publisher URL (`direct URL`), including the
137 MB raw HCRIS archive and the 58 MB SVI tract file. Nothing has drifted since
the Phase 1 retrieval dates, and every rotating-token URL resolved through its
recorded API route rather than the dead snapshot link.

### The three CRED rows

| `source_id` | Credential | Why the recipe still passes |
|---|---|---|
| `acs_2024_ice` | Census API key | `url` records the full endpoint shape with `{FIPS}` and `{CENSUS_API_KEY}` placeholders and "looped over all 52 state and state-equivalent FIPS codes"; `parse_notes` records that the key is read from `CENSUS_API_KEY` and that unauthenticated requests return *Missing Key*. Key is free, instant, self-service. Endpoint verified live (HTTP 302 to the keyed request). |
| `adi_2024_bg` | Neighborhood Atlas account | `url` records the full click-path: create an account (the bare `/register` path 404s — verified, still true), validate the confirmation email, `/download`, Linkage Format = 12-digit FIPS, States = All, Version = 2024. Landing page HTTP 200; `/download` HTTP 302 to login, consistent with the recorded "account login" method. Account is free, email-validated, no review. |
| `adi_2020_bg` | same | same recipe, Version = 2020 |

A stranger cannot pull these two sources without first spending five minutes on a
free registration — but the table tells them exactly which registration and
exactly which form settings. That is the standard Phase 0 set for ADI
("free, self-service registration with email validation — no review, no DUA") and
the recipe meets it. Recorded here rather than counted as a pass without
qualification.

### The three NA rows

`rand_hospital_data`, `adi_zip4_crosswalk`, `hud_usps_crosswalk` — attempted-and-
excluded sources carried under standing rule 4 so the roads not taken stay
visible. Each has a filled `exclusion_reason` and no file. Nothing to re-download;
the test skips them by design.

## 4. County Health Rankings licence — the one open item that closed here

The open-questions table carried *"County Health Rankings licence terms for JHF
distribution — Open, closes at 1.7."* Task 1.4 §5 did the substantive work:
established that CHR&R is **not** Creative Commons BY-NC-ND as Phase 0 recorded,
that there is **no NoDerivatives clause**, and that the binding constraints are
**non-commercial use and attribution**. `sources.csv` row `chr_2025` and
`spike-context.md` §5 both carry the corrected terms and the required citation.

What remains is not a data question. It is: **is JHF's intended distribution of
this report non-commercial?** A foundation research report plainly is — research
and public health are named permissions in the live Terms of Use. A paid,
licensed, or client-billed deliverable would need written consent from
`info@countyhealthrankings.org` first. This is Carl's to confirm with the Foundation lead, and
it does not block Phase 2: CHR feeds county-grain covariates that are themselves
the documented fallback grain, and the equity finding rests on Block B tract-grain
sources that are all public domain.

**Status: licence terms closed and recorded. Distribution question flagged for
The Foundation lead — non-blocking.**

## 5. What this closes

Phase 1 is done. Seven tasks, 31 provenance rows, one driver script that
re-hashes every archived file on each run and one that re-fetches every file from
the table alone. The frame is **2,801 acute-care hospitals**; every covariate
block has its sources in hand or a recorded substitute.

```
sources.csv                 31 rows  (28 retrieved, 3 excluded)
redownload-test.py          new — the Phase 1 grading condition, executable
make.R                      unchanged; prov_verify() still consistent, 28 files
```

## 6. Next

**Task 2.1 — build the identifier crosswalk.** Connect CCN, provider number, ZIP,
county FIPS, and census tract; report the match rate at each join; enumerate the
unmatched hospitals rather than dropping them. Depends on 1.7 (now cleared).
Budget 8 h. This starts Phase 2, which ends with the hashed, frozen analytic file
at Task 2.8.
