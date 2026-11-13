# Task 2.3 — Assemble Block A (hospital structure)

**Date:** 2026-08-31 · **Budget:** 5 h · **Status: complete.** `data/blockA.rds`
— 2,801 rows, 45 columns. Coverage reproduces the Task 1.3 gate exactly (8 of 10
covariates ≥ 99%); every covariate range is checked and the 92 hospitals with a
plausibility flag are enumerated in `output/tables/blockA-outliers.csv`, none
winsorized.

---

## 1. The ten covariates and their sources

| covariate | column(s) | source | coverage |
|---|---|---|---|
| beds | `beds` | FY2026 Impact `Beds` | 99.93% |
| ownership | `ownership` (+ `_code`) | FY2026 Impact `Ownership Control Type` (V/P/G/X) | 99.93% |
| teaching intensity | `resident_to_bed`, `teaching` | FY2026 Impact `Resident to Bed Ratio` | 99.93% |
| case mix index | `cmi` | **FY2025** Impact `TACMIV42` (transfer-adjusted, grouper V42) | 99.89% |
| DSH percentage | `dsh_pct` | FY2026 Impact `DSHPCT` | 99.93% |
| wage index | `wage_index` | FY2026 Impact `FY 2026 Wage Index` | 99.93% |
| system membership | `system_member`, `system_id/name/size`, `owner_type` | Hospital Enrollments + Hospital All Owners | 98.71% |
| occupancy | `occupancy` | FY2026 Impact `Average Daily Census` ÷ `Beds` | 99.93% |
| operating margin | `operating_margin` | HCRIS FY2023 `(Net Patient Revenue − Less Total Operating Expense) / Net Patient Revenue` | 99.32% |
| uncompensated care burden | `uncompensated_care` ($), `uncompensated_care_pct_npr` | HCRIS FY2023 `Cost of Uncompensated Care` | 98.29% |

**8 of 10 clear 99%** — identical to Task 1.3's corrected count. System
membership and uncompensated care fall short for structural reasons, not
retrieval failure (§4, §5), and go to Task 2.6/2.7 with a missingness indicator.

### The vintage split, carried through from Task 1.3

- **FY2025 Impact File (Correction Notice)** → `cmi` and `volume_bills`. Its
  FY2023 MedPAR sits inside the PSI window near the midpoint. `TACMIV42`
  correlates **0.9708** with the FY2026 vintage (median 1.717 vs 1.706) — close
  but not identical, which is why "Impact File vintage" is a Phase 3
  specification axis, not a silent default.
- **FY2026 Impact File** → every structural / payment-policy field.

The `.rds` also carries `provider_type` (RRC 784, SCH 222, SCH/RRC 168, IHS 10,
EACH/RRC 2), `urban_rural`, `adc`, `discharges`, HCRIS cross-checks
(`occupancy_hcris`, `dsh_pct_hcris`, `beds_hcris`), and the HCRIS fiscal window
(`hcris_fy_begin/end`, `hcris_window_overlap_days` — median 365, 96.1% wholly
inside the PSI window, 0% zero overlap).

---

## 2. HCRIS: dedup by longest fiscal period, FY2022 deterministic recovery

**62 CCNs file more than one FY2023 cost report.** They are deduplicated by the
**longest fiscal period** (tie → later end date), never by taking the first row
(task1.3-blockA.md §1). Same rule applied to the FY2022 PUF.

**Recovery before imputation (standing rule 7).** Where FY2023 is blank, the
FY2022 value is taken — an adjacent fiscal year is observed data, not
imputation. `operating_margin_source` and `uncompensated_care_source` record
which vintage each value came from:

| | fy2023 | fy2022 fill | below $1M / missing |
|---|---|---|---|
| operating margin | 2,773 | 9 | 5 / 14 |
| uncompensated care | 2,744 | 9 | — / 48 |

This matches Task 1.3's measured ceiling exactly: uncompensated care 97.97% →
**98.29%** with the FY2022 fill (+9 hospitals), and no further acquisition
closes the gap. The residual 48 are a Task 2.6 decision.

**Operating margin denominator guard.** The ratio is computed only where Net
Patient Revenue ≥ $1M (the same floor Task 0.3 used for the contract-labour
share); 5 hospitals fall below it and get NA + `operating_margin_source =
"denominator < $1M"` rather than a wild ratio.

---

## 3. System membership: the plan's source is empty, the substitute is 98.71%

Provider of Services `MLT_FAC_ORG_NAME` / `MLT_OWND_FAC_ORG_SW` are blank for
every row (task1.3-blockA.md §4). The substitute joins **Hospital All Owners**
to **Hospital Enrollments** on `ENROLLMENT ID`.

- **`owner_type`** is a genuine three-way, not two-plus-missing: `organization`
  (2,407), `individual` (358 — hospitals really owned by people, not an
  org — *not* missing data), `none` (36 — absent from Enrollments entirely,
  the true missingness).
- **A hospital's `system_id`** is the organisational owner (by `ASSOCIATE ID -
  OWNER`, never by name) that holds the **most** frame hospitals among its
  owners, ties broken by ownership percentage. HCA appears under five
  ASSOCIATE IDs (`HCA INC`, `HEALTHTRUST INC`, `HERCULES HOLDING II`, `FRISCO
  HOLDING II`, `HCA HEALTHCARE INC`); the "largest owner" rule consolidates the
  holding chain to one system per hospital.
- **`system_member`** = that owner holds ≥ 2 frame hospitals.

**2,038 hospitals (72.8%) are in a multi-hospital system**, across **709
systems**: HCA INC 141, CommonSpirit 81, Tenet 60, Community Health Systems 51,
LifePoint 47.

The escalation route if 98.71% is judged insufficient is the AHA Annual Survey
(licence-gated, enrichment-track open item 4) — worth asking JHF now.

---

## 4. Plausibility — ranges checked, 92 outliers enumerated, 0 winsorized

`output/tables/blockA-ranges.csv` records n / min / p05 / median / p95 / max /
plausible range / n-outside for all ten. `output/tables/blockA-outliers.csv`
lists every hospital carrying a flag, with the values and identifying
information. Nothing is modified in `data/blockA.rds` — the raw value stays and a
`flag_*` boolean is set.

| flag | n | reading |
|---|---|---|
| `flag_occupancy_gt1` | 10 | ADC exceeds licensed beds — Loma Linda, UCLA, Strong Memorial, AdventHealth Palm Coast (max 1.15). Real: observation beds and licensed-vs-staffed differences. Kept. |
| `flag_margin_extreme` | 23 | \|operating margin\| > 1 — NPR much smaller than total operating expense (worst −4.97: NPR $14.6M vs TOE $87.3M). Hospitals heavily funded by non-patient revenue (state appropriations, grants). Kept. |
| `flag_dsh_gt1` | 6 | DSHPCT > 1.0 — the disproportionate-share patient percentage is a **sum of two ratios** (Medicare SSI fraction + Medicaid fraction) and can legitimately exceed 1. Kept. |
| `flag_npr_tiny` | 5 | Net Patient Revenue < $1M — margin set NA. |
| `flag_occupancy_zero` | 3 | ADC = 0 — specialty/low-census facilities. |
| `flag_beds_missing` | 2 | `010062`, `050350` — absent from the Impact File (the Task 2.1 pair). |
| `flag_uncomp_missing` | 48 | no HCRIS uncompensated-care value in either vintage. |

beds, resident-to-bed, wage index, CMI, volume, and raw uncompensated-care $
have **zero** values outside their plausible range.

---

## 5. Files

```
R/blockA.R                              new — stage 13
make.R                                  stage 13 added
data/blockA.rds                         2,801 × 45   (built product, gitignored)
output/tables/blockA-ranges.csv         10 covariate rows
output/tables/blockA-outliers.csv       92 rows
output/tables/task2.3-blockA.txt        stage log
```

No `provenance/sources.csv` change — every input already has a row. Full
`make.R`: 13 stages `ok`, provenance `consistent`.

---

## 6. Next

**Task 2.4 — the catchment-weighting engine** (`R/catchment.R`, ZIP→tract base
grain, county fallback for the ~4.6% failing gate B0.a, `catch_source` /
`catch_coverage`). Depends on 2.1; parallel with this task. It is the task most
likely to be attacked in review — Phase 0 answered the suppression objection
empirically but the grain choice and the fallback rule are still ours to defend.
