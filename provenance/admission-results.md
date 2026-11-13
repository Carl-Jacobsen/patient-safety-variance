# Admission test results — Task 2.7

**Date:** 2026-08-31 · **Budget:** 4 h (+1 by `plan-amendments.md` §3.4) ·
**Status: complete. This task does not get cut.**

23 gates evaluated against `provenance/admission-gates.md`. **22 meet their
threshold; C2.e is exceeded and triggers conditional admission via amendment A1
(not exclusion).** No covariate is excluded, so `provenance/sources.csv` is
unchanged. Every threshold in `output/tables/admission-gate-results.csv` is
byte-identical to `admission-gates.md`; the only deviations are the two logged
amendments A1 and A2, neither of which moved a number.

`data/blockC.rds` (2,801 × 33) + `data/blockC_mice.rds` (the m = 20 mice object)
carry the admitted Block C covariates.

---

## 1. Gate C1 — coding / surveillance intensity (CMI level and drift)

| gate | threshold | observed | |
|---|---|---|---|
| C1.a | non-missing `TACMIV42` ≥ 0.95 | **99.89%** | PASS |
| C1.b | `TACMIV42` ∈ [0.50, 5.00]; flagged ≤ 0.02 | 0.00% (0 flagged) | PASS |
| C1.c | computable relative drift ≥ 0.95 | **99.82%** | PASS |
| C1.d | \|drift\| ≤ 0.50; flagged ≤ 0.01 | 0.036% (**1** flagged → NA) | PASS |
| C1.e | SD of relative drift ≥ 0.010 | **0.0527** | PASS |

`drift = (TACMIV42_FY2026file − TACMIV42_FY2025file) / TACMIV42_FY2025file` —
the same grouper (V42) across two MedPAR years, isolating change in coded case
mix. Every value reproduces `spike-structure.md` §6.

**Disposition: PASS → admitted, and labelled a partial proxy in every table and
sentence it appears in** (fixed here, not contingent on any result). It cannot
separate more thorough documentation from genuinely sicker patients. Columns
`cmi_level`, `cmi_drift` in `data/blockC.rds`; the one hospital with
\|drift\| > 0.50 has `cmi_drift = NA` and `cmi_drift_flag = TRUE`.

---

## 2. Gate C2 — staffing instability (HCRIS S-3 contract & agency labour)

**Order of operations (amendment A1):**

### Step 1 — deterministic recovery (done at Task 1.6)

`contract_labor_source` on the frame: `puf_fy2023` 2,541 · `raw_s3_fy2023` 47 ·
`puf_fy2022` 75 · `missing` 138. The PUF's 90.7% baseline rose to **95.0%** with
observed values only — raw HCRIS Worksheet S-3 Part II plus the FY2022 report.
Nothing was imputed at this step.

### Step 2 — gate C2 on the recovered coverage

| gate | threshold | observed | |
|---|---|---|---|
| C2.a | computable share ≥ 0.85 | **95.04%** | PASS |
| C2.b | blank Contract Labor values imputed to zero **= 0 exactly** | **0** | PASS |
| C2.c | Total Salaries ≥ $1M; flagged ≤ 0.01 | 0.036% (**1** flagged → NA) | PASS |
| C2.d | share ∈ [0.00, 0.50]; flagged ≤ 0.02 of computable | 0.68% (**19** flagged → NA) | PASS |
| C2.e | \|SMD\| in beds and rural between present/absent ≤ 0.10 | **beds +0.68, rural −0.20 — EXCEEDED** | conditional |

**C2.b is the gate that matters most, and it holds exactly.** A blank cannot be
distinguished from a genuine zero; imputing blanks to zero would put a false
floor on 5% of the frame on the exact variable meant to measure staffing
instability. Zero blanks are imputed to zero — by recovery and by MI both.

### Step 3 — multiple imputation, because C2.e is exceeded

C2.e was known to be exceeded since Phase 0 (then beds SMD +0.462, rural −0.269
at 9.2% missing; now **+0.68 / −0.20 at 5.0% missing** — recovery shrank the
count, the residual is still differential). **Amendment A1 fixes the
consequence: conditional admission with MI as the primary treatment**, because
Task 2.6 established that this missingness is **MAR** — predicted by fully
observed covariates (LR p < 1e-4). MAR is precisely where multiple imputation
is unbiased and the missingness-indicator method is not.

`mice(m = 20, method = "pmm", seed = 20260831)` on the 158 missing
(139 truly missing + 19 out-of-range set to NA by C2.d). Imputation model:
`log(beds)`, rurality, ownership, wage index (a CBSA-level quantity, proxying
CBSA), `log(volume)`, CMI, DSH %, teaching, occupancy, the four Block B
disadvantage measures (all observed), **and PSI-90** (omitting the outcome from
the imputation model attenuates the associations being estimated).

| | n | median | IQR | max |
|---|---|---|---|---|
| observed share | 2,643 | 0.055 | [0.024, 0.100] | 0.497 |
| imputed share (158 × 20) | 3,160 | 0.059 | [0.025, 0.120] | 0.497 |

Predictive mean matching draws from observed donors, so **0 imputed values fall
outside [0, 0.50]** by construction — which is why PMM was chosen over
normal-linear MI for this bounded, right-skewed variable.

**Disposition: CONDITIONAL ADMISSION (A1).** The 20 completed vectors are
`cl_share_mi_01…cl_share_mi_20` in `data/blockC.rds`; `data/blockC_mice.rds` is
the full mice object for Phase 3's Rubin's-rules pooling. The coefficient range
is reported under **both** MI and complete-case at Phase 3; contract labour
receives **no MCR bound** (Block C control, `plan-amendments.md` §3.3); the
missingness indicator (`contract_labor_missing`) is retained **only** as an MNAR
diagnostic — is it predictive after conditioning?

---

## 3. Gate C3 — state tort environment (DSTLR 7.1)

| gate | threshold | observed | |
|---|---|---|---|
| C3.a | frame states matching a DSTLR 2021 row ≥ 0.99 | **100.00%** (all 51) | PASS |
| C3.b | distinct reform vectors across the core reform columns ≥ 20 | **50** | PASS |
| C3.c | years, DSTLR terminal year (2021) → PSI midpoint (2023-07-01) ≤ 4.0 | **2.5** | PASS |

**C3.b column-set note.** `admission-gates.md` C3.b names "the 17 core reform
columns"; `spike-structure.md` §7 reported 44 distinct vectors with that set,
but no spike script defining the 17 survives. The DSTLR 7.1 README documents
**11** reform-indicator columns (`r_cn`, `r_cp`, `r_ct`, `r_sr`, `r_cs`, `r_pe`,
`r_pp`, `r_cf`, `r_js`, `r_pcf`, `r_cmpf`). This evaluation uses those 11 and
finds **50** distinct vectors across the 51 frame states. The threshold (≥ 20)
is not moved and clears on any reasonable column set.

**Disposition: PASS → admitted as CONTEXT ONLY** (fixed in advance, not
contingent on passing). It enters the specification space as a state-level
control; it is **never** reported as a driver, never ranked in report §6, and
**never** carries an MCR claim. With ~50 distinct values across 2,801 hospitals
it is near-collinear with region and with other state policy. Columns
`tort_state`, `tort_cap_noneconomic` (`r_cn`), `tort_cap_total` (`r_ct`),
`tort_n_reforms` (count of the 11, range 2–10) in `data/blockC.rds`.

---

## 4. Gate B0 — catchment coverage (re-evaluated)

| gate | threshold | observed | |
|---|---|---|---|
| B0.a | admissible iff `n_obs_cells ≥ 3` and `obs_cases ≥ 100` | **130 fail (4.64%)** → county fallback | PASS |
| B0.b | share on the county fallback ≤ 0.10 | 0.0464 | PASS |
| B0.c | admissible weights sum to 1 within 1e-9 | max \|Σw − 1\| = **3.6e-15** | PASS |
| B0.d | `catch_coverage` recorded for every frame hospital = 1.00 | 100% | PASS |
| B0.e | median `catch_coverage` ≥ 0.60 | **0.829** | PASS |

Every value reproduces Task 2.4 and Phase 0. Amendment A2 corroborated the
working constant of 3 in `catch_coverage`; no threshold moved.

---

## 5. Gate O1 — outcome frame (re-evaluated)

| gate | threshold | observed | |
|---|---|---|---|
| O1.a | frame = Acute Care Hospitals with numeric PSI-90 | **n = 2,801** | PASS |
| O1.b | VA hospitals excluded by explicit filter, count reported = 107 | **107, reported** | PASS |
| O1.c | footnote codes kept distinct; code 7 never collapsed with code 1 = 0 | **0 collapsed** | PASS |
| O1.d | component n's individual **and** four-component joint n both stated | 2,313–2,801 individual / **2,294** joint | PASS |
| O1.e | outcome = six-decimal file; HACRP reserved; both stated and differ | mean diff **+0.00191**, r **0.9996** | PASS |

Reproduces Task 2.2.

---

## 6. What was excluded

**Nothing.** Every FAIL-if gate is met; C2.e's exceedance is a conditional-
admission trigger, not an exclusion. `provenance/sources.csv` is unchanged (33
rows). Had any gate failed, the covariate would carry the failing gate id as its
`exclusion_reason` there, per standing rule 4.

---

## 7. Files

```
R/blockC.R                                  new — stage 18
make.R                                      stage 18 added
output/tables/admission-gate-results.csv    23 rows (gate_id, threshold, observed, pass, n_flagged, date_evaluated)
data/blockC.rds                             2,801 × 33  (cmi_level, cmi_drift, contract_labor_share + 20 MI draws, tort_*)
data/blockC_mice.rds                        the m=20 mice object, for Phase 3 pooling
output/tables/task2.7-admission.txt         stage log
```

No `provenance/sources.csv` change. Full `make.R`: 18 stages `ok`, provenance
`consistent`.

---

## 8. Next

**Task 2.8 — freeze the analytic file.** Merge outcomes, Block A, Block B, and
admitted Block C on CCN; hash it; version it; write the amendment procedure into
the repo. After the freeze, changes require a logged amendment.
