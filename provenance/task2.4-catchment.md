# Task 2.4 — Build the catchment-weighting engine

**Date:** 2026-08-31 · **Budget:** 8 h (revised to 6 by `plan-amendments.md` §2.4)
· **Status: complete. All five B0 gates pass.**
`R/catchment.R` — discharge-weighted ZIP→tract catchment weights, self-tested by
hand. `data/catchment.rds` (per-hospital, carries `catch_source` /
`catch_coverage`) + `data/catchment-weights.rds` (705,062 hospital × tract
rows). B0.a 130 fallback (4.64%), B0.c max |Σw − 1| = 3.6e-15, B0.e median
`catch_coverage` 0.829 — Phase 0 reproduced to the digit.

---

## 1. What the engine does

For each frame hospital it produces a weight vector over 2020 census tracts,
`Σ weight = 1`, so Task 2.5 can take a discharge-weighted average of any
tract-level Block B covariate.

```
HSAF cell (hospital h, patient-ZIP z, TOTAL_CASES)
  │  drop suppressed cells ('*'), renormalise:  w_z = cases_z / Σ_observed cases
  │  drop ZIPs with no ZCTA, renormalise again  (zip_matched_share)
  ▼
ZCTA z → tracts t, population share  s_{z,t}   (the one allocation step)
  ▼
w_t = Σ_z w_z · s_{z,t}          prune < 1e-6, renormalise → Σ w_t = 1 exactly
```

### The grain is tract, not county — and that is the whole point

`plan-amendments.md` §2.2 measured it: at **county** grain the catchment-weighted
SVI correlates **0.89–0.97** with naive hospital-county assignment, and imputing
every suppressed cell moves that by ~0.01. The redundancy is the grain, not the
suppression. County-grain weighting buys ~3 correlation points for 8 hours.
Tract grain retains the within-county heterogeneity county assignment destroys,
so that is the base case; county is the documented fallback (§3).

### The one allocation step: ZCTA → tract by population

`spike-context.md` §3.3 commits the build to exactly one allocation step. It is
done by **population weighting**, not area: a tract's share of a ZCTA is its
population lying inside that ZCTA —

```
slice_pop(z,t) = pop(t) · [ AREALAND_PART(z,t) / AREALAND_TRACT(t) ]
s(z,t)         = slice_pop(z,t) / Σ_t slice_pop(z,t)
```

Tract population is SVI 2022 `E_TOTPOP`. Where a tract has no SVI population
(≈2.8% of relationship-file tracts, `-999` or blank), that slice falls back to
raw intersection **land area**. Result: **98.7% of ZCTAs are placed by
population only, 1.3% mixed** with an area fallback for some slices. Population
weighting matters here because the covariates being averaged are themselves
neighbourhood-poverty percentiles — a ZCTA that is one dense town plus open land
must put its weight on the town's tracts, which area weighting would not do.

### Suppression: renormalise over observed cells (evidence-backed)

87% of HSAF cells are suppressed. The weights are renormalised over the observed
cells only. Phase 0 tested this directly against imputing every suppressed cell
at 3 cases: **r ≥ 0.986 on all four SVI themes, mean difference < 0.004**
(`plan-amendments.md` §2.2, `admission-gates.md` A2). `catch_coverage =
obs_cases / (obs_cases + 3 × n_suppressed_cells)` is recorded for **every** frame
hospital (gate B0.d); the constant 3 is the committed working assumption for the
mean size of a suppressed cell (bounded [1, 10]; a cross-vintage test found only
2.3% exceed 11 in an adjacent year, so most hold 1–3) and is used **only** for
this diagnostic, never to impute a weight.

---

## 2. The core function and its hand check

`catchment_weights_one(zip_cases, alloc)` is the whole engine — ~15 lines,
base R. `catchment_selftest()` runs first, every stage, and `stopifnot`s two
hand computations:

1. **Allocation share.** Tract T1 (pop 1000, all inside ZCTA Z), tract T2 (pop
   200, half inside Z) → share Z→T1 = 1000/1100, Z→T2 = 100/1100.
2. **A hospital's weights.** Observed cases A 60, B 40, C 20; ZCTA A → T1 0.75 /
   T2 0.25; ZCTA B → T2 1.0; ZCTA C absent. → C drops, `zip_matched_share =
   5/6`, renormalised A 0.6 / B 0.4, → w(T1) = 0.45, w(T2) = 0.55, Σ = 1.

Separately, `provenance/`-time verification recomputed hospital **010073**
(3 observed ZIPs, 18 catchment tracts) from the raw HSAF and relationship files
by an independent path: **max weight difference 0.0**.

---

## 3. Gate B0 (`admission-gates.md` §5) — all five pass

| gate | predicate | threshold | observed | |
|---|---|---|---|---|
| **B0.a** | admissible iff `n_obs_cells ≥ 3` **and** `obs_cases ≥ 100` | per-hospital FLAG | **130 fail (4.64%)** | → county fallback |
| **B0.b** | share on the county fallback | ≤ 0.10 | 0.0464 | **PASS** |
| **B0.c** | admissible weights sum to 1 | `\|Σw − 1\| ≤ 1e-9` | max 3.6e-15 | **PASS** |
| **B0.d** | `catch_coverage` recorded for every frame hospital | = 1.00 | 100.00% | **PASS** |
| **B0.e** | median `catch_coverage` | ≥ 0.60 | **0.829** | **PASS** |

Every observed value matches Phase 0's measurement (`phase0-numbers.R` stage 1).

### The 130 fallback hospitals — `output/tables/catchment-fallback-hospitals.csv`

`catch_source = "county_fallback"`; they are **not** in the weight table — Task
2.5 gives them their hospital-county covariate value directly. By reason: 86 have
both < 3 cells and < 100 cases, 27 have < 100 cases only, 15 have < 3 cells only,
2 (`050855`, `060133`) are absent from the HSAF entirely (opened 2023, no
Medicare claims history — the same two missing from the FY2025 Impact File and
the HCRIS PUF). By rurality: 20 RURAL / 52 OURBAN / 57 LURBAN / 1 unknown — the
fallback set is **not** rural-skewed (frame is 20.8% RURAL), because the trigger
is Medicare discharge volume, and small urban hospitals with a nearby competitor
capturing most local discharges fail it too. `catch_source` enters the Phase 3
specification space as an influential-point axis (all hospitals / admissible
only).

### 12 admissible hospitals place < 90% of discharge weight on mappable ZIPs

`flag_low_zip_match` in `data/catchment.rds`. All are resort / frontier
catchments — Steamboat Springs, Lake Tahoe, Vail, Jackson WY, Juneau and
Fairbanks AK, Kona HI — where a real share of patients live in unincorporated
areas with a PO-box ZIP that has no ZCTA (minimum: UCHealth Yampa Valley,
60.7%). The weights are still valid discharge-weighted averages; they are just
built on less of the discharge base, and the flag makes that visible rather than
silent.

---

## 4. Files

```
R/catchment.R                                   new — stage 14
make.R                                          stage 14 added
data/catchment.rds              2,801 × 15   per-hospital: catch_source, catch_coverage,
                                             admissible, cell tallies, n_tracts, weight_sum,
                                             zip_matched_share, flag_low_zip_match, fallback_county_fips
data/catchment-weights.rds      705,062 × 3  ccn × tract_geoid × weight  (2,671 admissible hospitals)
output/tables/catchment-fallback-hospitals.csv   130 rows
output/tables/catchment-gate-B0.csv              5 rows
output/tables/task2.4-catchment.txt              stage log
```

No `provenance/sources.csv` change — HSAF, the ZCTA→tract file, and SVI all have
rows. Full `make.R`: 14 stages `ok`, provenance `consistent`.

---

## 5. Next

**Task 2.5 — Block B, catchment-weighted.** Apply `data/catchment-weights.rds` to
every Block B covariate (SVI four themes, ADI, uninsured rate, rurality, PCP
density, market concentration, LEP share, ICE), keeping the four grain variants
per covariate — `_catch_tract` (base), `_catch_county`, `_county`, `_hsa`
(Dartmouth, suppression-free) — so "the weighting bought little" and "the grain
was too coarse" stay distinguishable. ADI first rolls block group → tract by
population weighting. Fallback hospitals take `_county` for `_catch_tract`.
Depends on 2.4, 1.4.
