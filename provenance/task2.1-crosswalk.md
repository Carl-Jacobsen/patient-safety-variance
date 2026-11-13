# Task 2.1 — Build the identifier crosswalk

**Date:** 2026-08-31 · **Budget:** 8 h · **Status: complete. Phase 2 open.**
Every one of the 2,801 frame hospitals carries a `provider_number`, `zip5`,
`county_fips`, and `census_tract`; each join's match rate is reported below and
in `output/tables/crosswalk-match-rates.csv`; the 361 hospitals that failed a
join or needed a coarse fallback are in `output/tables/unmatched-hospitals.csv`,
none dropped.

---

## 1. What the crosswalk connects

`data/crosswalk.rds` — 2,801 rows, 28 columns, one row per frame CCN. The spine
is the CCN, rebuilt from the outcome layer exactly as `R/frame-o1b.R` and
`R/blockA-coverage.R` do it (numeric `PSI_90`, `Hospital Type == "Acute Care
Hospitals"`). Four identifiers hang off it, each with a primary source and at
least one independent check:

| identifier | primary | checks |
|---|---|---|
| `provider_number` | FY2026 IPPS Impact File `Provider Number` | FY2025 Impact File, Provider of Services file |
| `zip5` | Care Compare Hospital General Information `ZIP Code` | POS `ZIP_CD` |
| `county_fips` | FY2026 Impact File `FIPS County Code` | POS `FIPS_STATE_CD`+`FIPS_CNTY_CD`, Census geocoder county |
| `census_tract` | U.S. Census Bureau batch geocoder | ZCTA largest-land-area tract (flagged fallback) |

The `.rds` also carries the raw candidate columns (`county_fips_impact`,
`county_fips_pos`, `county_fips_geocode`, `zip5_pos`), the source flags
(`county_fips_source`, `tract_source`, `tract_match_type`), the geocoder
`lat`/`lon`, and context fields used to characterise the unmatched (`beds`,
`urgeo`, `cbsa`, `zcta5`).

---

## 2. Match rate at each join

### Join 1 — `provider_number`

| source | matched | rate |
|---|---|---|
| FY2026 Impact File | 2,799 / 2,801 | 99.93% |
| FY2025 Impact File | 2,798 / 2,801 | 99.89% |
| Provider of Services file | 2,801 / 2,801 | 100.00% |

For a hospital the Medicare provider number **is** the CCN — `provider_number ==
ccn` for all 2,799 present. The join's value is confirming the payment layer
reaches the frame at all. The two absent from the Impact File are **`010062`
Wiregrass Medical Center (AL)** and **`050350` Adventist Health White Memorial
Montebello (CA)** — the same AL/CA pair `spike-structure.md` §2 flagged. Both are
in the frame (numeric PSI-90), both resolve on every other identifier, both are
carried in `unmatched-hospitals.csv` with `unmatched_on = provider_number`.

### Join 2 — `zip5`

Care Compare gives a 5-digit ZIP for **2,801 / 2,801 (100%)** — expected, the
frame is built from a Care Compare file. POS `ZIP_CD` is also 100% present and
agrees with the primary on **97.1%** (80 disagreements, 70 of which share the
first three digits — same sectional centre, a PO-box vs street-address or a
campus-relocation difference, not a mis-join).

### Join 3 — `county_fips`

| source | present | rate |
|---|---|---|
| FY2026 Impact File `FIPS County Code` | 2,799 | 99.93% |
| … that are an actual census county | 2,774 | **99.04%** |
| POS `FIPS_STATE_CD`+`FIPS_CNTY_CD` | 2,801 | 100.00% |
| **final `county_fips` (impact → POS → geocoder)** | **2,801** | **100.00%** |

**The Impact File county code is not always a county.** For FY2024 onward CMS
adopted Connecticut's nine **Council-of-Governments planning regions**
(`09110`…`09190`) in place of its eight legacy counties. Every county-grain
Block B source — SVI, ADI roll-up, AHRF, County Health Rankings — is still keyed
to the legacy counties, so carrying the COG codes would silently break every CT
county join at Task 2.5. The build validates `FIPS County Code` against the
Census county universe (from the 2020 ZCTA→county relationship file) and, for the
**25 CT hospitals**, takes the legacy county from POS — which carries a valid one
for all 25, agreeing with the geocoder on the 18 the geocoder placed. The two
hospitals absent from the Impact File take POS as well. `county_fips_source`
records which of the three won for every row.

POS agrees with the (valid) Impact File county on **97.4%**; the geocoder's
address-derived county agrees on **98.2%**. All 80 source disagreements are
enumerated in `output/tables/crosswalk-county-disagreements.csv` with a `reason`
(25 "CT COG planning region", 55 "boundary/reclassification difference") and
`resolved_to` / `resolved_from` — every one is within the same state.

### Join 4 — `census_tract`

The hospital's own 2020 census tract, from the **Census Bureau batch geocoder**
(`geocoding.geo.census.gov/geocoder/geographies/addressbatch`, benchmark
`Public_AR_Current`, vintage `Census2020_Current`).

| pass | source | new | cumulative |
|---|---|---|---|
| A | geocode Care Compare address | 2,432 | 86.83% |
| B | geocode POS address, for pass-A misses | 9 | 87.15% |
| C | ZCTA largest-land-area tract, flagged | 347 | **99.54%** |
| — | still unmatched | — | 13 (0.46%) |

81.6% of the geocoder matches are `Exact`, the rest `Non_Exact` (a near-miss on
the house-number range — the tract is still right). Pass B barely moves the
number: the POS street address is usually the same string Care Compare has, and
a hospital address the TIGER range file cannot match is not a formatting problem
— a normalised retry (spelled-out "ONE", stripped PO-box tails, `HWY`→`HIGHWAY`)
recovered **zero** additional matches when tested. The **347** pass-C hospitals
get the largest-land-area tract of their ZCTA, marked `tract_source =
zcta_fallback` so no downstream step mistakes it for a rooftop match. The **13**
left unmatched all sit in unique/PO-box ZIPs with no ZCTA (Stamford, Yale-New
Haven, Univ. of Missouri, Dartmouth-Hitchcock, …); each still has a solid
`county_fips`, so they are not analytically lost, only imprecisely located.

**2,440 / 2,801 (87.1%)** are fully crosswalked with no fallback on any
identifier — the ceiling is set entirely by geocoder tract coverage.

---

## 3. The unmatched table — `output/tables/unmatched-hospitals.csv`

361 rows. A hospital is listed if, after every source and the flagged fallback,
an identifier is missing (`status = unresolved`) or was only obtainable from the
coarse ZCTA fallback (`status = fallback_zcta`, `census_tract` only).

| by identifier | n |
|---|---|
| `provider_number` unresolved | 2 |
| `census_tract` fallback or unresolved | 360 (347 fallback, 13 unresolved) |

**Characterisation** (the Task 2.1 verify condition — is the missingness
differential?):

- **Rural:** 80 / 361 unmatched are `URGEO == RURAL` (22%) against **20.8%** of
  the frame — essentially flat.
- **Size:** unmatched median 142 beds vs frame median 151 — flat.
- **State:** the count tracks state size — TX 42, FL 27, CA 26, PA 21, GA 14,
  IL 13. No single state is over-represented relative to its share of the frame.

The geocoder's failure to place a hospital is close to non-differential with
respect to the hospital characteristics that matter to the equity gradient. It
is a precision loss on the *location* of ~13% of hospitals, not a selection
effect, and it does not touch `county_fips`, which is the identifier the
county-grain Block B joins actually use. This goes to Limitations, not to the
imputation strategy.

---

## 4. The geocoder as a source

`sources.csv` gains a 32nd row, `census_geocoder`, `retrieval_method = web API`.
The recipe is the full multipart POST (`addressFile` of `id,street,city,state,zip`;
`benchmark`, `vintage`), pass A on the Care Compare address and pass B on the POS
address for pass-A misses. The per-hospital result is cached to
`data-raw/geocode/hospital-geocode.csv` (hash-frozen in `sources.csv` and in
`data-raw/geocode/MANIFEST.sha256`); `make.R` reads the cache and makes no
network call once it exists.

**Reproducibility caveat, recorded like the ADI vintage rows.** The
`Public_AR_Current` benchmark is revised over time. Deleting the cache forces a
fresh geocode, and a scratch rebuild may then reassign a small number of tracts
as TIGER improves. The cached file is the authority for the frozen analytic file
at Task 2.8; a bit-exact rebuild restores it from the archive rather than
re-fetching, exactly as ADI does. On a fresh clone with no `data-raw/`, stage 11
skips and `prov_verify()` reports `census_geocoder` MISSING alongside the other
un-restored raw inputs — unchanged behaviour.

The geocoder call goes through `curl` via `system2()`, the same reasoning
`R/provenance.R` shells out to `shasum`: base R has no multipart POST, and the
recipe must not name a package the recipe does not carry.

---

## 5. Files

```
R/crosswalk.R                                   new — stage 11
make.R                                          stage 11 added
data/crosswalk.rds                              2,801 × 28   (built product, gitignored)
output/tables/crosswalk-match-rates.csv         13 join rows
output/tables/unmatched-hospitals.csv           361 rows
output/tables/crosswalk-county-disagreements.csv 80 rows
output/tables/task2.1-crosswalk.txt             stage log
data-raw/geocode/hospital-geocode.csv           geocoder cache (hash-only in git)
data-raw/geocode/MANIFEST.sha256                 new
provenance/sources.csv                          31 → 32 rows (census_geocoder)
```

Full `make.R` run: all eleven stages `ok`, provenance `consistent`.

---

## 6. Next

**Task 2.2 — assemble the outcome table.** Hospital-level PSI-90 plus the four
components from the six-decimal file, denominators and CI from the provider file,
and the reliability quantities (`v_i`, `tau2 = 0.07744`, `lambda_i` median
0.462) that stand in for the missing O/E split. Depends on 2.1 (the crosswalk
spine), now cleared. Footnote codes 1 / 5 / 7 / 13 / 19 / 23 / 29 stay distinct —
code 7 is a structural zero, never collapsed with volume suppression.
