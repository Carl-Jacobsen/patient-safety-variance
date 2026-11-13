# Task 1.2 — Acquire the outcome layer

**Date:** 2026-08-26 · **Budget:** 1 h · **Status: complete.** Gate O1.b passes.

---

## 1. What the layer is

Six files, all from the CMS Provider Data Catalog, all public and unauthenticated.
Five define the outcome and the sample frame; the sixth is the FY 2026 HAC Reduction
Program file, added at this task because it carries each hospital's **observed** penalty
status.

| `source_id` | PDC id | Role |
|---|---|---|
| `cc_candd` | `ynj2-r877` | PSI-90 and components at 2 dp, denominators, and the only published CI |
| `cc_psi6dec` | `muwa-iene` | the same quantity at six decimals — no denominator, no CI |
| `cc_footnotes` | `y9us-9xdf` | decodes the suppression mechanisms |
| `cc_measuredates` | `4j6d-yzce` | independent confirmation of the PSI window |
| `cc_hospinfo` | `xubh-q36u` | `Hospital Type` — the column that executes gate O1.b |
| `hacrp_fy2026` | `yq43-i98g` | Total HAC Score and observed `Payment Reduction` |

`data-raw/careCompare_2022Q3-2024Q2/` and `data-raw/hacrp_fy2026/`, publisher filenames
restored. `provenance/sources.csv` now has **seven rows** — the sixth is RAND, which was
never retrieved (§4).

## 2. Retrieval goes through the metastore API

A PDC download URL embeds a release token — `.../6af7c44d…_1785189947/…` — that changes
on every refresh. A recorded URL is therefore a snapshot, not a recipe, and
`sources.csv` records the **API path** instead:

```
https://data.cms.gov/provider-data/api/1/metastore/schemas/dataset/items
  -> select by `identifier` -> distribution[[1]]$data$downloadURL
```

`R/acquire-outcome.R` (stage 2) does this. It is idempotent: a file already on disk is
hashed and checked against `sources.csv` and left alone; only a missing file is fetched.

Two facts worth recording. The token has **not** rotated since Phase 0 fetched these
files this morning — the resolved URLs are character-for-character the ones in
`spike-outcome.md` §2. And re-downloading through the API produces bytes that hash
**identically** to the Phase 0 archive, all six files. The archive is the live file.

The metastore carries no `license` or `rights` field. `accessLevel` is `public` and the
publisher is CMS, so the licence recorded is *public domain, U.S. Government work*, with
the absence of the field noted in the row rather than papered over.

## 3. Gate O1.b, passed

From the permanent layout, by `R/frame-o1b.R` (stage 3):

| Cut | n |
|---|---|
| Facilities in the provider file | 4,790 |
| — with a numeric `PSI_90` | 2,908 |
| — `Hospital Type == "Acute Care Hospitals"` | **2,801  ← the frame** |
| — `Hospital Type == "Acute Care - Veterans Administration"` | **107  ← excluded, counted** |
| — any other `Hospital Type` | **0** |
| — no `Hospital Type` row at all | **0** |

**GATE O1.b: PASS** on both predicates. The two zero rows matter as much as the two
counts: the numeric-PSI-90 population is exactly acute-care plus VA, so the explicit
filter is not quietly discarding a third category.

Corroborating checks in the same stage:

- window confirmed twice — `07/01/2022 .. 06/30/2024` on the provider file's PSI rows,
  and 13 PSI rows in `Measure_Dates.csv`
- every `Facility ID` is 6 characters, **749 of them starting with a zero**
- all 2,801 frame hospitals have a six-decimal `PSI_90` (median 0.962079)
- footnotes parse as multi-codes: 96 rows carry more than one, and code 1 (volume
  suppression, 3,898 rows) stays distinct from code 7 (structural zero, 1,490 rows)
- **all 2,801 frame hospitals appear in the HACRP file, and 0 VA hospitals do** —
  independent confirmation that the VA exclusion is right rather than merely convenient
- observed penalties: 719 Yes / 2,293 No / 43 N/A

## 4. RAND recorded as an exclusion

`sources.csv` now carries `rand_hospital_data` with `retrieval_method = not retrieved`
and an `exclusion_reason`: paywalled, and the Cost Report PUF covers 99.9% of the frame
including the S-3 contract-labour line. Standing rule 4 says nothing gets dropped
quietly; this is what the `exclusion_reason` column added at Task 1.1 was for. It is
Block A's exclusion, not the outcome layer's, but the row belongs in the table now that
the table exists.

## 5. The one design decision: moving files without breaking Phase 0

Moving these six files out of `data-raw/spike-phase0/` breaks the two ported Phase 0
drivers, which read the spike paths — and standing rule 1 says their numbers must keep
regenerating.

Editing the ported bodies was the obvious fix and the wrong one: it would end the
property that they *are* the Phase 0 scripts rather than a retelling. Instead every move
is recorded in **`provenance/relocations.csv`**, and `R/relocate.R` replays it as a
relative symlink at the old path before any stage runs. `read.csv` follows symlinks
without noticing.

This also survives a re-download. A stranger rebuilding `data-raw/` from `sources.csv`
gets the permanent paths only; `make.R` restores the spike-era paths from the same
table, so Phase 0's numbers regenerate on a machine that has never seen the spike
layout. Verified: after the move, `phase0-numbers.txt` still reports frame 2,801, VA
107, HSAF suppression 87.46%, and `phase0-followup.txt` still reports median λ 0.462
and rural λ 0.304 vs 0.520.

## 6. Verification actually performed

| Check | Result |
|---|---|
| `Rscript make.R`, working tree | 4 stages **ok**, provenance consistent |
| Gate O1.b | **PASS**, 2,801 and 107, with 0 in every other category |
| Fresh `git clone` + `renv::restore()` | 78 packages restored from cache, clean |
| Fresh clone, **empty** `data-raw/`, stage 2 | all six files downloaded through the metastore API; **all six sha256 match `sources.csv`** |
| Fresh clone, stage 3 | output **byte-identical** to the working-tree run |
| Phase 0 stages after the move | numbers unchanged |
| `shasum -c` on all three `data-raw/*/MANIFEST.sha256` | 16 files, 0 failures |

The fresh-clone rebuild is the Phase 1 test stated in the task sheet — *a stranger
holding only the provenance table can re-download every file* — and for the outcome
layer it now holds literally, not by assertion.

It also closes half of the item left open at Task 1.1: `renv::restore()` against a clean
library works. What is still untested is **another machine or OS** — the restore drew
from this machine's renv cache.

## 7. Open items this touched

- **Item 6** (snapshot-date explanation for the HACRP vs Care Compare PSI-90 divergence)
  is unchanged and still open. It is recorded in the `hacrp_fy2026` row's `parse_notes`
  so it cannot be forgotten at Task 2.2, where the two values first sit side by side.
- `Total HAC Score` is numeric for 2,929 of 3,055 HACRP rows. The 126 blanks are a
  Phase 4 concern, not a Phase 1 one; noted here so it is not a surprise later.

## 8. Next

**Task 1.3** (Block A — the FY 2026 and FY 2025 Impact Files, the Cost Report PUF, and
the Provider of Services file) and **Task 1.5** (the Hospital Service Area File) are both
unblocked and parallel. 1.3 carries the vintage decision flagged in
`phase1-readiness.md` §6.1: FY 2025 for case-mix and volume, FY 2026 for payment-policy
fields, with the choice carried as a specification axis rather than a silent default.
