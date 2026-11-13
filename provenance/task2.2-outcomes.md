# Task 2.2 — Assemble the outcome table

**Date:** 2026-08-31 · **Budget:** 5 h · **Status: complete. Five gates pass.**
`data/outcomes.rds` — 2,801 rows, 53 columns. `tau2 = 0.07744`, median `lambda`
= 0.462, and the volume-quartile λ table (0.205 / 0.381 / 0.559 / 0.755)
reproduce stage 1b to the fourth decimal. Gate O1.c / O1.d / O1.e pass.

---

## 1. What the table carries

One row per frame CCN. The join key is the 6-char CCN; `setequal(frame,
crosswalk$ccn)` is asserted at the top of the stage, so Task 2.1 is a hard
dependency, not a footnote.

| group | columns | source |
|---|---|---|
| **PSI-90 composite** | `psi90` (outcome), `psi90_2dp`, `psi90_lower`, `psi90_upper`, `psi90_ci_width`, `psi90_denominator`, `psi90_compared_national`, `psi90_footnote` | `psi90` from the **six-decimal file** (gate O1.e); CI and everything else from the provider file |
| **footnote flags** | `fn_too_few` (1), `fn_not_available` (5), `fn_structural_zero` (7), `fn_not_calculable` (13), `fn_out_of_frame` (19), `fn_claims_discrepancy` (23), `fn_partial_window` (29) | parsed from `psi90_footnote` as a **list**, one boolean per code |
| **components** | `psi03/06/12/13` (six-decimal rate), `_2dp`, `_denom`, `_lower`, `_upper`, `_footnote` | rate from six-decimal file; **denominator** (at-risk population — the components' precision weight) from the provider file |
| **reliability** | `v_i`, `tau2`, `lambda_i`, `lambda_in_tau2_sample`, `volume_bills_fy2026` | derived; see §3 |
| **HACRP (Phase 4 only)** | `psi90_hacrp`, `psi90_hacrp_wz`, `hacrp_total_hac_score`, `hacrp_payment_reduction` | FY2026 HACRP file — carried, **not** the analytic outcome |
| **measure metadata** | `measure_start` 2022-07-01, `measure_end` 2024-06-30, `measure_period` "2022Q3-2024Q2", `psi_software_version` (NA) | Measure_Dates + provider file, triangulated |

**`psi90` is the six-decimal `Rate`, not the 2-dp `Score`.** They are the same
quantity; `psi90_2dp` is kept because it is the basis of the published CI and of
the Phase 0 τ² derivation, and because a reviewer checking against the provider
file will want the value they see there. Max |six-dp − 2-dp| = 0.005, i.e.
rounding only.

**`psi90_denominator` is NA for every hospital.** CMS publishes `Denominator =
"Not Applicable"` for the composite (spike-outcome.md §3a). The components carry
real denominators; the composite does not, and that is a fact about the measure,
not missing data.

**`psi_software_version` is NA.** The CMS PSI software version for FY2026 is
unresolved in public sources (spike-outcome.md §9.1 — FY2025 used v13.0, the
FY2026 fact sheet names no version). It does not block: the published values are
fixed and hashed and the design is a single cross-section. Carried as NA so the
gap stays visible rather than being papered over with a guess.

---

## 2. Footnotes — parsed as a list, seven codes kept distinct (gate O1.c)

Footnotes are comma-concatenated multi-codes. `has_code()` splits on `,\s*` and
tests membership, so each of the seven mechanism codes gets its own boolean
column and **code 7 (structural zero) is never merged with code 1 (volume
suppression)**.

On the frame's PSI-90 rows only two codes appear:

| code | n | meaning | in `outcomes.rds` |
|---|---|---|---|
| 23 | 16 | hospital reported claims-data discrepancies — value present, flag it | `fn_claims_discrepancy` |
| 29 | 61 | partial performance period, CMS-approved exception — value present, flag it | `fn_partial_window` |

Code 1 does not appear on the frame: a hospital with too few cases to report has
no numeric PSI-90 and never entered the frame (gate O1.a). The other five codes
are representable and would populate if a component row carried them —
**`fn_structural_zero` does fire on component rows** (PSI-13 carries code 7 for
hospitals with a genuinely empty at-risk denominator), which is exactly the
distinction O1.c exists to preserve.

`GATE O1.c: 0 rows collapse code 7 into code 1 → PASS.`

---

## 3. Reliability — the empirical-Bayes shrinkage (stands in for the O/E split)

There is no O/E split in the public release and none can be reconstructed
(spike-outcome.md §5). What the published `Lower Estimate` / `Higher Estimate`
interval *does* reveal is how hard each hospital was shrunk toward the national
mean. Following `plan-amendments.md` §1.2, treating the published value as a
posterior mean θ̂ᵢ = μ + λᵢ(yᵢ − μ):

- **`v_i`** = ((`psi90_upper` − `psi90_lower`) / 2 / 1.96)² — the implied
  posterior variance
- **`tau2`** = Var(published) + mean(`v_i`) — the implied prior variance,
  identified from published quantities alone because Var(θ̂) = τ² − E[v]
- **`lambda_i`** = 1 − `v_i` / `tau2` — the share of the hospital's true
  deviation that survives into the published number

`tau2` is identified on the **2,799** hospitals with a published CI *and* a
positive FY2026 Medicare volume and bed count — exactly stage 1b's sample — then
`lambda_i` is applied to every hospital that has a CI (all 2,801; the two without
FY2026 volume get `lambda_in_tau2_sample = FALSE`).

| quantity | this task | stage 1b target |
|---|---|---|
| Var(published PSI-90, 2 dp) | 0.03678 | 0.03678 |
| mean implied posterior variance | 0.04066 | 0.04066 |
| **τ²** | **0.07744** (τ = 0.2783) | 0.07744 |
| median λ | 0.462 | 0.462 |
| mean λ | 0.475 | 0.475 |
| n identifying τ² | 2,799 | 2,799 |

The diagnostic that comes free: **mean within-hospital variance (0.04066)
exceeds the between-hospital variance of the published scores (0.03678).** That
is arithmetically impossible for unshrunk estimates — by itself proof that heavy
smoothing has been applied.

### `output/tables/reliability-by-volume.csv` — reproduces `plan-amendments.md` §1.3

| volume quartile | n | median Medicare cases | mean λ |
|---|---|---|---|
| Q1 low | 700 | 322 | **0.205** |
| Q2 | 700 | 1,032 | 0.381 |
| Q3 | 699 | 2,279 | 0.559 |
| Q4 high | 700 | 5,008 | **0.755** |

Rural hospitals retain **0.304**, non-rural **0.520** (printed to the log, not
tabled — the quartile table is the deliverable). The composite's attenuation is
almost perfectly explained by volume, which makes the rural limb of the equity
gradient roughly twice as attenuated as the urban limb. This is why Phase 3
carries a reliability axis and why a null rural coefficient on the raw composite
is uninterpretable (`plan-amendments.md` §1.3–1.4).

---

## 4. Components (gate O1.d)

| measure | rate n | share of frame | denominator median |
|---|---|---|---|
| PSI-06 iatrogenic pneumothorax | 2,801 | 100.0% | 2,937 |
| PSI-03 pressure ulcer | 2,778 | 99.2% | 2,352 |
| PSI-12 perioperative PE/DVT | 2,727 | 97.4% | 596 |
| PSI-13 postoperative sepsis | **2,313** | **82.6%** | 250 |
| **all four simultaneously** | **2,294** | 81.9% | — |

PSI-13 is the binding constraint (small at-risk denominator, volume suppression
bites), and the 507 hospitals it drops are systematically low-volume. Per O1.d
the table stores every component at its own coverage; the joint sample (2,294)
is computed and reported separately, never imposed by a listwise default. All
five numbers match spike-outcome.md §7 exactly.

`GATE O1.d: individual n's 2,313–2,801 stated, joint n 2,294 stated separately → PASS.`

---

## 5. Two official PSI-90 values, and they differ (gate O1.e)

The FY2026 HACRP file and the Care Compare six-decimal file both publish a
PSI-90 composite for the identical 2022-07-01…2024-06-30 window. On the 2,793
frame hospitals with both:

| | |
|---|---|
| Pearson r | **0.999606** |
| mean difference (HACRP − Care Compare) | **+0.001912** |
| SD / 99th pct \|diff\| / max \|diff\| | 0.005411 / 0.019169 / 0.047078 |
| exact agreement to 5 dp | 38 of 2,793 |

They are not the same number — most likely a different data snapshot (HACRP
frozen at the review-and-correct deadline, Care Compare at the July 2026
refresh), unconfirmed. The **analytic outcome is the Care Compare six-decimal
value**; `psi90_hacrp` and the HACRP z-score / total-HAC-score / payment-reduction
fields are carried only as the Phase 4 payment anchor. `hacrp_payment_reduction`
on the frame: Yes 664 / No 2,097 / N/A 40.

`GATE O1.e: outcome = six-decimal file; HACRP reserved for Phase 4; both values
stated and their difference recorded → PASS.`

---

## 6. Files

```
R/outcomes.R                             new — stage 12
make.R                                   stage 12 added
data/outcomes.rds                        2,801 × 53   (built product, gitignored)
output/tables/reliability-by-volume.csv  5 rows (4 quartiles + all)
output/tables/task2.2-outcomes.txt       stage log, carries every verify line
```

No `provenance/sources.csv` change — every input (`cc_*`, `hacrp_fy2026`,
`ipps_impact_fy2026`) already has a row. Full `make.R`: 12 stages `ok`,
provenance `consistent`.

---

## 7. Next

**Task 2.3 — assemble Block A** (hospital structure: beds, ownership, teaching
intensity, CMI, DSH %, wage index, system membership, occupancy, operating
margin, uncompensated care burden). Depends on 2.1. Parallel with 2.4. Case-mix
and volume take the FY2025 Impact File (MedPAR inside the PSI window); payment-
policy fields take FY2026. Coverage gate is ≥99% of the frame per covariate;
uncompensated care cannot reach it from the public HCRIS PUF and that is a 2.6
decision, not a blocker (`blockA-coverage.R`).
