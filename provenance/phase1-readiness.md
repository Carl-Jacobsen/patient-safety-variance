# Phase 1 readiness check

**Date:** 2026-08-26
**Verdict: ready to start.** Every source resolves live, the toolchain is complete, and
one input (ADI) gates one column of one task.

---

## 1. Live availability — every Phase 1 source, checked today

Not "recorded in Phase 0" — re-requested this morning.

| Task | Source | Status |
|---|---|---|
| 1.2 | CMS Provider Data Catalog metastore API | **200** |
| 1.2 | FY 2026 HAC Reduction Program file | **200** |
| 1.3 | FY 2026 IPPS Impact File | **200** |
| 1.3 | FY 2025 IPPS Impact File (Correction Notice) | **200** |
| 1.3 | Hospital Provider Cost Report, FY 2023 Final | **200** |
| 1.3 | Provider of Services, Q2 2026 | **200** |
| 1.4 | SVI 2022 national tract file | **200** |
| 1.4 | SVI 2022 county file | **200** |
| 1.4 | Census 2020 ZCTA→tract relationship file | **200** |
| 1.4 | Census 2020 ZCTA→county relationship file | **200** |
| 1.4 | AHRF 2023–2024 | **200** |
| 1.4 | County Health Rankings 2025 analytic | **200** |
| 1.4 | **ADI** | **login required — see §3** |
| 1.4 | **Census ACS 5-year API** | **key required — see §3** |
| 1.5 | Hospital Service Area File CY 2023 | **200** *(already archived)* |
| 1.5 | Dartmouth Atlas ZipHsaHrr19 crosswalk | **200** |
| 1.6 | Raw HCRIS `HOSP10FY2023.zip` (137 MB) | **200** |
| 1.6 | Hospital Provider Cost Report FY 2022 Final | **200** |
| 1.6 | Database of State Tort Law Reforms 7.1 | **200** *(already archived)* |

**No dead links, no paywalls, no DUAs on the critical path.** RAND was the one paid
dependency and it is substituted out.

## 2. Toolchain

| | |
|---|---|
| R | **4.5.0** ("How About a Twenty-Six") |
| git | 2.39.5 |
| `renv` | installed |
| `readxl` (DSTLR 7.1 is .xlsx) | installed |
| `mice` (gate C2 imputation, PMM) | installed |
| `lme4` (Task 3.2 hierarchical models) | installed |
| `data.table` (HSAF is 1.14 M rows) | installed |
| `sf` (geographic joins) | installed |

Nothing to install before Task 1.1. Note the working directory is **not yet a git
repository** — Task 1.1 initialises it, which is what it is for.

## 3. The two gated inputs, both self-service

**ADI — Neighborhood Atlas.** Free account, email validation, no review, no DUA.
Realistic turnaround minutes to hours. Full process, which vintages to take, and the
`PH`/`GQ`/`PH-GQ`/`QDI` parse traps: `spike-context.md` §3.4 and §3.5. Blocks Task 1.4
and the ADI column of Task 2.5, nothing else.

**Census API key — new, found today.** The ACS 5-year API now returns *Missing Key* on
unauthenticated requests; Phase 0's earlier note that no key was needed for light use is
**wrong as of today**. The key is free and instant from
`https://api.census.gov/data/key_signup.html` — name, email, organisation, and the key
arrives by email. Needed only for the ICE construction in Task 1.4.

Both are Carl's to do, for the same reason: they are accounts registered under his name
and affiliation.

**ACS vintage for ICE.** ACS 2021–2025 5-year does not exist yet — that release lands in
December 2026, after the contract ends. **ACS 2020–2024 5-year is the newest available**,
data midpoint 2022-07-01, a **1.0-year gap** to the PSI window midpoint. Take it, and do
not default to matching SVI's 2018–2022 vintage: ICE has no reason to inherit SVI's
3.0-year gap.

## 4. What Phase 0 already banked

Six sources are downloaded, hashed, and parsed, and their traps are documented rather
than waiting to be rediscovered:

| Trap | Where |
|---|---|
| Impact File `.txt` is **latin-1** with its header on **line 2** | 1.3 |
| Cost Report PUF has **62 CCNs with more than one report** — deduplicate deliberately | 1.3, 2.3 |
| HSAF suppression is the literal string `*` **padded with spaces**, plus a trailing blank line and non-hospital provider numbers | 1.5, 2.4 |
| Care Compare footnotes are **comma-concatenated multi-codes** — parse as a list, and never collapse code 7 (structural zero) with code 1 (volume suppression) | 1.2, 2.2 |
| `Facility ID` is a 6-char CCN with **significant leading zeros** — read as character everywhere | all |
| PDC download URLs carry a **release version token** that changes each refresh — retrieve through the metastore API | 1.2 |
| ADI value column is **character**, carrying suppression codes inline | 1.4 |

`phase0-numbers.R` and `phase0-followup.R` are working base-R drivers reading raw files
by relative path with no package dependencies. Task 1.1 **ports them into `make.R`**
rather than writing a driver from scratch.

## 5. Dependencies, cleared

| Task | Depends on | Status |
|---|---|---|
| 1.1 | 0.1 | **cleared** — engagement terms recorded |
| 1.2 | 1.1 | ready |
| 1.3 | 1.1, 0.3 | **0.3 cleared** |
| 1.4 | 1.1, 0.4 | **0.4 cleared except ADI** |
| 1.5 | 1.1, 0.4 | **cleared** |
| 1.6 | 1.1, 0.3 | **cleared** |
| 1.7 | 1.2–1.6 | ready |

## 6. Three decisions to make inside Phase 1

Not blockers — but they are choices, and choices made by default are the ones that get
attacked in review.

1. **Which Impact File vintage feeds which field** (Task 1.3). FY 2025 is built on FY 2023
   MedPAR, which sits near the PSI window midpoint; FY 2026 is built on FY 2024 MedPAR,
   which overlaps only its last quarter. Recommendation: **FY 2025 for case-mix and
   volume, FY 2026 for payment-policy fields**, and carry the vintage choice as a
   specification axis rather than a silent default.
2. **`sources.csv` schema** (Task 1.1). The rev-1 schema is source, file, retrieval date,
   URL, vintage, license, sha256. Phase 0 shows it needs three more columns:
   **`retrieval_method`** (direct URL vs metastore API vs account login),
   **`parse_notes`**, and **`exclusion_reason`** — standing rule 4 requires attempted-and-
   excluded sources to stay visible, and there is nowhere to put that today.
3. **Whether raw HCRIS S-3 extraction is worth its 3 hours** (Task 1.6). It is a 137 MB
   download and a worksheet-line parse, against a PUF that already covers 90.7%. Worth
   it if it materially reduces the 9.2% blank rate, because those hospitals are
   systematically smaller and more rural. **Timebox it:** if raw S-3 does not beat the
   PUF after two hours, stop and go to cross-year fill plus MI.

## 7. Verdict

**Start Task 1.1.** Nothing blocks it. Register for ADI and the Census key in parallel —
both are minutes of work and neither gates 1.1, 1.2, 1.3, 1.5, or 1.6.

The only item worth doing today that is not Phase 1 work at all: **request the Task 6.4
and 6.5 meeting slots.** They are the one part of the plan that does not move with
throughput.
