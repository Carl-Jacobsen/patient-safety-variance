# Task 1.4 — Acquire Block B (social and geographic context)

**Date:** 2026-08-27 · **Budget:** 4 h · **Status: complete.** Every verify condition is
met, one of them by discovering that the thing to be verified was recorded wrongly (§5).

---

## 1. What was acquired

Ten files across three directories, plus one API pull.

| `source_id` | Grain | Role |
|---|---|---|
| `svi_2022_tract` | tract | **base case** — the four SVI themes |
| `svi_2022_county` | county | fallback for the 130 gate-B0.a hospitals |
| `adi_2024_bg` | block group | primary disadvantage measure, 1.0-year gap |
| `adi_2020_bg` | block group | vintage axis |
| `acs_2024_ice` | tract | the ICE construction, and the only ACS pull |
| `zcta_tract_2020` | ZCTA×tract | base-case catchment crosswalk |
| `zcta_county_2020` | ZCTA×county | fallback crosswalk |
| `ahrf_2023_2024` | county | primary-care physician density |
| `chr_2025` | county | county health measures |
| `rucc_2023` | county | rurality |

Four things were **deliberately not acquired**, each recorded rather than silently
skipped:

- **market concentration** — derived at Task 2.5 as an HHI over hospital shares within
  each ZIP, from the Service Area File itself. It appears in no download list and would
  otherwise be discovered missing in Phase 2.
- **HUD USPS crosswalk** — now needs an API token; the Census relationship files do the
  same job free. `sources.csv` row `hud_usps_crosswalk`, with the reason.
- **ACS uninsured and limited-English pulls** — `EP_UNINSUR` and `EP_LIMENG` are columns
  of the SVI file. Two fewer pulls, one fewer vintage mismatch.
- **ADI ZIP+4 crosswalk** — cannot join to 5-digit HSAF ZIPs. Row `adi_zip4_crosswalk`.

## 2. Verify: SVI arrives as four separate themes

`RPL_THEME1`–`RPL_THEME4` all present, along with `EP_UNINSUR`, `EP_LIMENG`, and `FIPS`.
84,120 tracts, **83,342 (99.1%)** with all four themes valid; the county file has all
four valid for all 3,144 counties.

**`RPL_THEMES` is acquired and must never enter a model.** It is the composite the design
exists to decompose — collapsing four themes into one number is precisely the information
loss Phase 3 measures. It is in the archive because excluding it from the download would
make the exclusion invisible; it is named here so the exclusion is a decision.

**Parse trap:** SVI codes missing as **`-999`, not blank**. A negative percentile is a
suppression flag, and coercing the column to numeric without filtering yields silent
nonsense — a tract that looks like the least vulnerable in the country. 778 tracts carry
it on theme 1, 762 on theme 2, 503 on theme 3, 761 on theme 4.

**Vintage:** SVI 2022 is built on ACS 2018–2022, data midpoint 2020-07-01, against a PSI
midpoint of 2023-07-01. **Gap 3.0 years**, and no newer release exists — 2023 and 2024
both 404. This is why ADI's 1.0-year gap matters and why ADI is not a duplicate of SVI.

## 3. Verify: ADI at block group, four suppression codes distinguished

Handled at stage 6 and recorded in `provenance/` at the ADI ingest. Both vintages are
character-parsed with `GQ` / `PH` / `GQ-PH` / `QDI` kept distinct from genuine values.

**The `GQ` count, recorded separately as the task requires:** **2,595 block groups
(1.07%)** in the 2024 vintage, **2,803 (1.16%)** in 2020. Group-quarters suppression
removes prisons, dormitories, and nursing homes — populations that are neither randomly
distributed nor irrelevant to a hospital's catchment. The per-hospital count of
`GQ`-suppressed block groups inside each catchment gets carried alongside
`catch_coverage` at Task 2.5.

One correction the delivered files forced: the combined code is **`GQ-PH`**, not `PH-GQ`
as `spike-context.md` §3.5 recorded. A parse written to the old spelling would have
dropped 789 block groups silently.

## 4. The ICE pull

ACS **2020–2024** 5-year, table `B19001`, tract level, all 52 state and state-equivalent
FIPS codes. **85,382 tracts**, 84,279 (98.7%) with households > 0.

ICE = (households ≥ $100,000 − households < $25,000) ÷ total households with income
reported. Distribution: p05 −0.269, median **+0.233**, p95 +0.688.

**That median is itself a finding.** The conventional <\$25k / ≥\$100k cutoffs date from
an era when \$100,000 sat near the 80th percentile of household income. In 2020–2024
dollars it does not, and the index accordingly skews positive — 15,715 tracts above +0.5
against 920 below −0.5. So a **≥\$150,000 variant is carried as a specification axis**;
it medians at +0.040 and correlates 0.9715 with the primary. Neither is asserted as
correct.

Two things kept distinct: a tract with **no households** has ICE *undefined*, which is
not the same as missing, and must not be imputed to zero.

**Vintage:** midpoint 2022-07-01, **gap 1.0 year**. ACS 2021–2025 does not exist — it
lands December 2026, after the contract ends. ICE deliberately does not inherit SVI's
3.0-year gap.

**The key.** The ACS API now returns *Missing Key* unauthenticated, contradicting Phase
0's note that no key was needed for light use. `CENSUS_API_KEY` is read from the
environment; it is in `~/.Renviron` outside the repository and appears in no tracked
file. `sources.csv` records that a key was used and the endpoint shape, never the value.

## 5. County Health Rankings: the licence is not what Phase 0 recorded

The verify condition is that CHR's licence terms be checked against JHF's intended
distribution. Checking them turned up an error worth more than the check.

Phase 0 recorded CHR&R as **Creative Commons BY-NC-ND**, and flagged NoDerivatives as
the clause at risk — since any covariate built from those columns is arguably a
derivative. **The live Terms of Use, last updated 2024-12-16 and read today, are not
Creative Commons at all.** They say:

- all content is *"the property of CHR&R or its licensors with all rights reserved"*
- CHR&R grants a non-exclusive licence to use the unauthenticated portions of the site
  *"for personal or non-profit purposes including educational, research, or public
  health"*, provided copyright notices are kept intact
- commercial use — explicitly including training AI models offered as commercial
  products — requires express prior written consent (`info@countyhealthrankings.org`)
- the required citation is *University of Wisconsin Population Health Institute. County
  Health Rankings & Roadmaps. www.countyhealthrankings.org.*

**There is no NoDerivatives clause.** The risk Phase 0 flagged does not exist, and
derived covariates are fine.

Open item 7 therefore narrows to a single question for JHF: **is the intended
distribution non-commercial?** A foundation research report plainly is, and research and
public health are named permissions. A paid, licensed, or client-billed deliverable is
not, and would need written consent first. That is a question about JHF's plans, not
about the data, so it is Carl's to close — but it is now a much smaller question than it
was this morning.

Both `sources.csv` and `spike-context.md` §5 carry the correction.

## 6. Grain: one join key, three sources

SVI is tract. ADI is block group, and rolls up to tract exactly — block groups nest
inside tracts, so the aggregation carries no allocation error. ICE is tract. The Hospital
Service Area File is 5-digit ZIP, and the Census 2020 **ZCTA→tract** relationship file
(171,480 rows, 33,792 ZCTAs, 85,528 tracts) is the single allocation step in the chain.

County grain survives only as the documented fallback, because Phase 0 measured
county-grain catchment weighting as near-redundant with naive county assignment
(r 0.89–0.97) — the weighting only earns its hours at tract grain.

## 7. Verification actually performed

| Check | Result |
|---|---|
| `Rscript make.R` | **9 stages ok**, 25 files hash-verified, provenance consistent |
| SVI four themes present, `RPL_THEMES` flagged never-model | confirmed |
| SVI `-999` trap | 503–778 tracts per theme, quantified |
| ADI `GQ` count recorded separately | 2,595 (2024) / 2,803 (2020) |
| ICE pull | 85,382 tracts, 52 state requests, all succeeded |
| CHR licence | read live; **Phase 0's record corrected** |
| Every Block B source hashed into `sources.csv` | 26 rows total, 4 of them exclusions |

## 8. Open items

- **Item 7 (CHR licence)** — narrowed, not closed. One question for JHF: non-commercial
  distribution? See §5.
- AHRF's 2023–2024 release **renamed variables** relative to prior editions. The
  extraction at Task 2.5 must read the User Tech documentation first rather than reusing
  prior variable names.
- RUCC ships in **long format** — one row per county per attribute, 9,703 rows — and
  needs reshaping before it joins.

## 9. Next

**Task 1.5** (Hospital Service Area File into the permanent layout, plus the Dartmouth
Atlas ZIP→HSA/HRR crosswalk) and **Task 1.6** (Block C candidates) are the remaining
Phase 1 acquisitions. Both are unblocked. Task 1.7 closes the provenance table.
