# Task 2.5 — Build Block B, catchment-weighted

**Date:** 2026-08-31 · **Budget:** 8 h · **Status: complete.** `data/blockB.rds`
— 2,801 rows, 67 columns. Twelve covariates, each at four grain variants; the
`_catch_county` vs `_county` comparison reproduces Phase 0 (SVI r 0.92–0.99) and
the informative `_catch_tract` vs `_county` comparison drops as low as **r =
0.56** (SVI theme 4) — the tract-grain choice earns its hours. One new
acquisition (block-group population) and one substantial geography fix
(Connecticut).

---

## 1. The four grain variants

For every covariate, per hospital:

| suffix | construction |
|---|---|
| `_catch_tract` | discharge-weighted mean of the tract-level covariate over the catchment's census tracts (`data/catchment-weights.rds`) — **the base case** |
| `_catch_county` | the same discharge weights aggregated to county grain, applied to county-level covariate values |
| `_county` | the covariate of the county (CT: COG planning region) the hospital sits in — naive assignment |
| `_hsa` | population-weighted mean over the tracts of the hospital's Dartmouth Atlas Hospital Service Area — **suppression-free**, an independent check |

`county_fallback` hospitals (gate B0.a, 130) take their hospital-county value
for the `_catch_*` variants — verified: `_catch_tract == _county` exactly for
them. County-native covariates (rurality, PCP density) have `_catch_tract ==
_catch_county` exactly by construction (every tract carries its county's value).

### Covariates and sources

| covariate | source | grain |
|---|---|---|
| `svi1`–`svi4` (SVI themes) | SVI 2022 tract + county | tract-native |
| `uninsured` (`EP_UNINSUR`), `limeng` (`EP_LIMENG`) | inside the SVI file | tract-native |
| `ice` (+ `ice150` axis) | ACS B19001; county by summing the household counts | tract-native |
| `adi` (2024) + `adi2020` (vintage axis) | block-group ADI → tract by **population weighting** | see §3 |
| `rurality` | RUCC 2023 (long format, `RUCC_2023` rows) | county-native |
| `pcp_density` | AHRF 2023–2024 `phys_nf_prim_care_pc_exc_rsdt_22` / `popn_est_22` × 1e5 | county-native |
| `hhi_zip`, `hhi_hsa` | derived from the HSAF itself (Herfindahl of provider discharge shares) | hospital-level, §4 |

SVI codes missing as `-999`; parsed to `NA` (99.1–99.4% of tracts valid). ICE is
undefined (not missing) where a tract has no households.

---

## 2. Connecticut: 2020 legacy geography → 2022 COG planning regions

**Every Block B source in this task is on Connecticut's new geography** (the 9
COG planning regions, `09110`–`09190`, and 2022-vintage tract numbers): SVI
2022, ACS 2020–2024 (ICE and block-group population), ADI 2024, RUCC 2023, AHRF.
But `data/catchment-weights.rds` and the Task 2.1 crosswalk are on the **2020
Census** geography (legacy 8 counties `09001`–`09015`), because the catchment
engine's one allocation step is the Census 2020 ZCTA→tract relationship file.

Left unhandled, all 25 CT hospitals would silently get Block B values computed
over only the out-of-state slice of their catchments.

**The fix is exact.** For Connecticut, 2020 tract `09XXX·suffix` → 2022 tract
`09YYY·suffix`: the 6-digit tract suffix is preserved and every suffix is unique
within the state (**879 tracts, 879 distinct suffixes, 879 / 879 matched**
against the SVI 2022 tract list). `remap_ct()` rewrites the county-equivalent
digits of every CT tract in the catchment weights, the ZCTA→tract table, and the
ADI 2020 roll-up. A CT hospital's own "county" (`_county`) is taken from its
remapped location tract, or the weight-max planning region of its catchment
where the location tract is missing.

**AHRF is the one source that still splits CT**: physician counts on the 8
legacy counties (no `popn_est_22`), population on the 9 planning regions (no
physician data). Mapping physicians to planning regions needs a legacy→COG
crosswalk we do not have, so the 25 CT hospitals get **CT's statewide
primary-care density (85.4 / 100k**, legacy-county physicians over 2020 census
population). Flagged here; `pcp_density` is county-native and the least central
Block B covariate, and RUCC — the other county-native one — was updated to the
new geography and needs no patch.

---

## 3. ADI: block group → tract by population weighting (a new acquisition)

`spike-context.md` §3.3 commits the build to rolling block-group ADI up to
census tract by **population weighting** before catchment weighting — block
groups nest exactly inside tracts, so the roll-up carries no allocation error
and stays inside the Neighborhood Atlas's stated validity limits (which exclude
ZCTA-level use). The Atlas file carries no population column.

**New source `acs_2024_bg_pop`** (`sources.csv` row 33): ACS 2020–2024 5-year
table **B01003** (total population), block-group level, one request per state,
same key handling as `acs_2024_ice`. Same vintage as `adi_2024_bg` and
`acs_2024_ice`, so the weight and the thing it weights share a vintage. The
first pull dropped Massachusetts to a 60-second timeout and wrote a partial
archive; the script now retries each state four times and **refuses to write an
archive if any state is still missing** (`R/acquire-bg-population.R` is stage
15).

Roll-up: `adi_tract = Σ_bg pop_bg · natrank_bg / Σ_bg pop_bg` over non-suppressed
block groups. Suppression codes `GQ` / `PH` / `GQ-PH` / `QDI` → `NA` and counted
(2024: 6,132 suppressed, 3,384 of them `GQ`). **The result is a
population-weighted rank-of-ranks, not a block-group ADI** — stated in the stage
output and to be stated in report §3.

### `output/tables/adi-aggregation-diagnostics.csv`

Per hospital: catchment tracts, weighted block-group count, and the weighted
share of catchment block groups lost to suppression. **Median 1.3% suppressed
(all of it `GQ` — group quarters: prisons, dorms, nursing homes), p95 5.1%.**
ADI suppression barely touches the catchments.

---

## 4. Market concentration (HHI) — derived from the HSAF

Not acquired (`task1.4-blockB.md` §1): built here as a Herfindahl index of
provider discharge shares.

- `hhi_zip` — for each patient-ZIP, every provider's share of that ZIP's
  observed Medicare discharges (all providers, not just the frame); the
  hospital's value is its own discharge-weighted mean over the ZIPs it serves.
  Median **3,276** on the classic 0–10,000 scale. `NA` for 54 hospitals whose
  every HSAF cell is suppressed (all `county_fallback`).
- `hhi_hsa` — the same at Dartmouth HSA grain; median **2,862**, present for all
  2,801.

**Both are biased upward:** HSAF suppression hides small providers' presence in
a ZIP, so fewer competitors are counted. Stated in the stage output and carried
as a known limitation.

---

## 5. The diagnostic — `output/tables/catchment-vs-county-correlation.csv`

The rev-1 wording was a trap: "correlation is high, so weighting bought little"
is true **at county grain for the wrong reason**. Three comparisons, not two:

| covariate | r(catch_tract, county) | r(catch_county, county) | MAD ct–co | MAD cc–co |
|---|---|---|---|---|
| svi1 | **0.79** | 0.95 | 0.149 | 0.052 |
| svi2 | **0.72** | 0.95 | 0.165 | 0.055 |
| svi3 | 0.88 | 0.97 | 0.213 | 0.038 |
| svi4 | **0.56** | 0.92 | 0.191 | 0.061 |
| uninsured | 0.93 | 0.98 | 1.08 | 0.49 |
| limeng | 0.89 | 0.98 | 0.97 | 0.35 |
| ice | 0.89 | 0.97 | 0.053 | 0.024 |
| adi | 0.97 | 0.99 | 4.35 | 2.27 |
| rurality | 0.97 | 0.97 (=) | 0.31 | 0.31 |
| pcp_density | 0.83 | 0.83 (=) | 9.9 | 9.9 |

- **`r(catch_county, county)` = 0.92–0.99 for SVI** reproduces Phase 0's
  0.89–0.97. County-grain catchment weighting *is* near-redundant with naive
  county assignment — that belongs in the report as the reason tract grain was
  chosen, **not** as evidence the weighting is pointless.
- **`r(catch_tract, county)` = 0.56–0.88 for the SVI themes** is the informative
  comparison. At tract grain the catchment-weighted covariate diverges
  substantially from the naive county value; the tract-grain average moves the
  covariate 3–4× as far (MAD). SVI theme 4 (housing / transportation) at r =
  0.56 is where the weighting matters most.
- **`r(catch_tract, hsa)` = 0.82–0.98** — the suppression-free Dartmouth
  construction tracks the discharge-weighted one, so the suppression handling is
  not driving the covariate.

`output/tables/catchment-grain-comparison.csv` carries mean / sd / p05 / p50 /
p95 of all four variants for every covariate, so the report can state both *how
much* catchment weighting changes each covariate and *at which grain it starts
to matter*.

---

## 6. Files

```
R/acquire-bg-population.R                          new — stage 15
R/blockB.R                                         new — stage 16
make.R                                             stages 15, 16 added
data/blockB.rds                    2,801 × 67   12 covariates × 4 variants + HHI + retained-weight cols
data-raw/blockB_acs/acs2024_5yr_B01003_blockgroup.csv   new (242,297 block groups, 52 states)
output/tables/catchment-vs-county-correlation.csv       12 rows
output/tables/catchment-grain-comparison.csv            48 rows
output/tables/adi-aggregation-diagnostics.csv           2,801 rows
output/tables/task2.5-blockB.txt, task2.5-bgpop.txt     stage logs
provenance/sources.csv                             32 → 33 rows (acs_2024_bg_pop)
```

Full `make.R`: 16 stages `ok`, provenance `consistent`.

---

## 7. Next

**Task 2.6 — the missingness audit** (`output/tables/missingness-audit.csv`,
figure, written interpretation). Tabulate missingness for every variable, cross
it against hospital characteristics — size, ownership, rurality, DSH, and the
Block B disadvantage measures specifically — and run the MAR-plausibility check
(is missingness predicted by *fully observed* covariates?) that licenses
multiple imputation at 2.7. Depends on 2.2, 2.3, 2.5. **Does not get cut.**
