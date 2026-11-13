# Admission gates

**Committed:** 2026-08-26
**Committed by:** Carl Jacobsen
**Committed before:** any model has been fitted. No regression, decomposition,
Rashomon set, or MCR bound had been computed on these data when this document was
written. The only quantities seen were univariate coverage counts, distributions, and
crosswalk match rates from `spike-outcome.md`, `spike-structure.md`, and
`spike-context.md`.

**Amendment rule:** these thresholds may be changed only by a dated, signed amendment
appended to §7 below, stating what changed, why, and what had been seen at the time.
Changing a threshold after seeing a modelling result that it affects is not permitted.

---

## 0. The claim these gates cannot touch

**The equity finding rests on Block B and survives total Block C failure.**

Block B — SVI's four themes, ADI, uninsured rate, rurality, primary care physician
density, market concentration, limited-English-proficiency share, and the Index of
Concentration at the Extremes — is public, complete, standard, and validated. If every
gate in §2, §3, and §4 below fails and all three Block C covariates are excluded,
report sections 5, 6, and 7 stand unchanged, and so does the headline claim that
MCR⁻ > 1 for community disadvantage.

Block C's job is to answer rival explanations, not to carry the finding. A failed
Block C gate costs the report an answer to an objection. It does not cost it a result.

This is stated here, in advance, so that no gate outcome can be argued to have
weakened or strengthened the equity claim after the fact.

---

## 1. How to read a gate

Every gate below is a predicate a script evaluates and records in
`output/tables/admission-gate-results.csv`, with columns: `gate_id`, `threshold`,
`observed`, `pass`, `n_flagged`, `date_evaluated`. Gates run at **Task 2.7**, against
the built analytic file, before the freeze at 2.8.

Three outcomes only:

- **PASS** — the covariate is admitted with its stated disposition.
- **FAIL** — the covariate is excluded from the analysis. It stays in
  `provenance/sources.csv` with the failing gate id as its exclusion reason
  (standing rule 4). It does not reappear in any specification.
- **FLAG** — a per-hospital condition. The value is set to `NA` for those hospitals,
  the count is reported, and the hospitals are enumerated. A FLAG never silently drops
  a row.

Values in the "observed at spike" column are what Phase 0 measured. They are recorded
for calibration and audit. **The gate is the threshold, not the observed value** — a
gate evaluated at 2.7 against a rebuilt file may land differently, and the threshold
is what decides.

---

## 2. Gate C1 — Coding and surveillance intensity (CMI level and drift)

**Source:** `TACMIV42` from the FY 2025 IPPS Impact File (Correction Notice) for level;
the same field differenced against `TACMIV42` from the FY 2026 Impact File for drift.
Differencing the same grouper version across two MedPAR years isolates change in coded
case mix from change in the grouper.

| Gate | Predicate | Threshold | Type | Observed at spike |
|---|---|---|---|---|
| **C1.a** | share of frame with non-missing `TACMIV42` (FY2025 file) | **≥ 0.95** | FAIL if below | 1.000 |
| **C1.b** | `TACMIV42` within `[0.50, 5.00]`; outside → `NA` | **≤ 0.02** of frame flagged | FAIL if above | 0.000 |
| **C1.c** | share of frame with computable relative drift | **≥ 0.95** | FAIL if below | 0.998 |
| **C1.d** | `abs(drift) ≤ 0.50`; outside → `NA` | **≤ 0.01** of frame flagged | FAIL if above | 0.00036 (1 hospital) |
| **C1.e** | SD of relative drift across the frame | **≥ 0.010** | FAIL if below | 0.0527 |

`drift = (TACMIV42_FY2026file − TACMIV42_FY2025file) / TACMIV42_FY2025file`

**C1.e** exists because a coding-intensity proxy with no variation is not a proxy. If
drift is degenerate, the level term alone is admitted and the drift term is dropped.

**Disposition if PASS:** admitted, and **labelled a partial proxy in every table and
sentence in which it appears**. It cannot distinguish more thorough documentation from
genuinely sicker patients. That label is fixed here and is not contingent on any
result.

**Disposition if FAIL:** excluded. Section 9 of the report states that the coding-
intensity objection could not be addressed on public data, and names the HCUP path
(secondary diagnoses per discharge, POA completeness) as what would address it.

---

## 3. Gate C2 — Staffing instability (HCRIS Worksheet S-3 contract and agency labor)

**Source:** `Contract Labor: Direct Patient Care` ÷ `Total Salaries (adjusted)`, CMS
Hospital Provider Cost Report PUF, FY 2023 Final.

| Gate | Predicate | Threshold | Type | Observed at spike |
|---|---|---|---|---|
| **C2.a** | share of frame with a computable share | **≥ 0.85** | FAIL if below | 0.907 |
| **C2.b** | count of blank `Contract Labor` values imputed to zero | **= 0**, exactly | FAIL if above | n/a — enforced by construction |
| **C2.c** | `Total Salaries (adjusted) ≥ 1,000,000`; below → `NA` | **≤ 0.01** of frame flagged | FAIL if above | 0.00036 (1 hospital) |
| **C2.d** | share within `[0.00, 0.50]`; outside → `NA` | **≤ 0.02** of computable flagged | FAIL if above | 0.0075 (19 hospitals) |
| **C2.e** | absolute standardized difference in **beds** and in **rural indicator**, between hospitals with and without a value | **≤ 0.10** | if exceeded → **conditional admission**, see below | **beds +0.462, rural −0.269 — EXCEEDED** |

### C2.b is the gate that matters most

The FY 2023 PUF contains **zero** exact-zero values for contract labor and 257 blanks
in the frame. A blank cannot be distinguished from a genuine zero. Imputing blanks to
zero would assign 9.2% of the frame a false floor on the exact variable meant to
measure staffing instability, and — per C2.e — those hospitals are systematically
smaller and more rural. **Blanks stay missing. There is no threshold to negotiate here;
the count of zero-imputations must be exactly 0.**

### C2.e is already known to be exceeded, and the consequence is fixed now

Phase 0 measured it (n present 2,540; n absent 258): hospitals missing a
contract-labor value are smaller (mean 139.0 beds vs 226.4, standardized difference
+0.462) and more rural (31.4% vs 19.7%, standardized difference −0.269).
Missingness is differential with
respect to precisely the covariates the study is about.

> **AMENDED 2026-08-26** (amendment A1, logged in §7). The hierarchy below was
> backwards. Missingness predicted by **fully observed** covariates is the textbook MAR
> case, where multiple imputation is unbiased — and the indicator method is known to be
> biased in regression even under MCAR. MI is now primary and the indicator is demoted
> to a diagnostic. Full reasoning: `plan-amendments.md` §3.1.

**Conditional admission, as amended:**

0. **Deterministic recovery is attempted first.** Raw HCRIS Worksheet S-3
   (`downloads.cms.gov/files/hcris/HOSP10FY2023.zip`, no registration) and the
   FY 2022 cost report are both public. A value recovered from either is observed
   data, flagged in `contract_labor_source`, and is never imputed over.
1. **Primary treatment: multiple imputation by chained equations**, m = 20, using
   **predictive mean matching** for the share — it is right-skewed and bounded below
   at 0, so normal-linear MI would generate impossible values. The imputation model
   includes beds, rurality, ownership, CBSA, wage index, volume, and the Block B
   disadvantage measures, all of which are 100% observed.
2. **Sensitivity: complete-case**, reported alongside, so the reader sees what MI did.
3. **The missingness indicator is not an estimation strategy here.** It is retained
   only as an MNAR diagnostic — is it predictive after conditioning?
4. **Retained: the covariate-omitted specification**, which is what shows whether the
   covariate matters at all.
5. **Contract labor receives no MCR bound.** It is a Block C control, and Block C's job
   is to be in the model, not to be ranked (`plan-amendments.md` §3.3). Its
   **coefficient range across the Rashomon set** is reported under both MI and
   complete-case.
6. The report states the differential missingness with both standardized differences,
   in Limitations, whatever the estimates turn out to be.

**Disposition if PASS:** admitted under the conditions above.
**Disposition if FAIL:** excluded; Limitations states that staffing instability could
not be measured to standard on public data.

---

## 4. Gate C3 — State tort environment

**Source:** Database of State Tort Law Reforms 7.1 (Avraham), terminal year **2021**.

| Gate | Predicate | Threshold | Type | Observed at spike |
|---|---|---|---|---|
| **C3.a** | share of frame hospitals whose state matches a DSTLR 2021 row | **≥ 0.99** | FAIL if below | 51 states present |
| **C3.b** | count of distinct reform vectors across the 17 core reform columns | **≥ 20** | FAIL if below | **44** |
| **C3.c** | years between DSTLR terminal year and PSI window **midpoint** (2023-07-01) | **≤ 4.0** | FAIL if above | **2.5** |

**Disposition is fixed in advance and does not depend on passing.** Even on a full
pass, this covariate is **context only**:

- It enters the specification space as a state-level control.
- It is **never** reported as a driver, never ranked in the driver ranking of report
  §6, and **never carries an MCR importance claim**.
- With 44 distinct values across 2,801 hospitals, it is near-collinear with region and
  with other state policy, and any apparent importance is unidentifiable from those.

This disposition is committed now precisely so that a large coefficient cannot later
promote it.

**Disposition if FAIL:** excluded, with the failing gate recorded.

---

## 5. Gate B0 — Catchment coverage *(added beyond Task 0.6's letter)*

Task 0.6 asks for gates on the three Block C covariates. This fourth gate is added
because `spike-context.md` §2 found that 87.46% of Hospital Service Area File ZIP
cells are suppressed, which was not anticipated in the plan, and because catchment
weighting is a **Block B** operation — the block the equity finding rests on. A
threshold committed after seeing catchment-weighted estimates would be worth nothing.

**Definitions, fixed here:**

- `n_obs_cells` = ZIP cells for the hospital with an unsuppressed `TOTAL_CASES`
- `obs_cases` = sum of unsuppressed `TOTAL_CASES` for the hospital
- `catch_coverage` = `obs_cases / (obs_cases + 3 × n_suppressed_cells)`
  The constant **3** is the committed working assumption for the mean size of a
  suppressed cell (which is bounded in `[1, 10]`). It is used **only** for this
  diagnostic, never to impute a weight.

| Gate | Predicate | Threshold | Type | Observed at spike |
|---|---|---|---|---|
| **B0.a** | hospital is catchment-admissible iff `n_obs_cells ≥ 3` **and** `obs_cases ≥ 100` | per-hospital | FLAG → county fallback | 130 fail (4.64%) |
| **B0.b** | share of frame requiring the county fallback | **≤ 0.10** | FAIL if above → catchment weighting is abandoned in favour of county assignment for the whole frame, and the report says so | **0.0464** |
| **B0.c** | catchment weights sum to 1 per admissible hospital | `abs(sum − 1) ≤ 1e-9` | FAIL if any hospital violates | to be evaluated at 2.4 |
| **B0.d** | `catch_coverage` recorded for **every** hospital in the frame | **= 1.00** of frame | FAIL if below | required output |
| **B0.e** | median `catch_coverage` across the frame | **≥ 0.60** | FAIL if below | **0.829** |

**Fallback rule, committed:** a hospital failing B0.a receives its hospital-county
value, and a `catch_source` column records `"catchment"` or `"county_fallback"` for
every hospital. The fallback count is reported in report §3 and the hospitals are
enumerated in `output/tables/catchment-fallback-hospitals.csv`. `catch_source` enters
the Phase 3 specification space as an influential-point axis (all hospitals / admissible
only).

**On the composite honesty requirement:** the report must describe catchment weighting
as a discharge-weighted average over the observed portion of each catchment, and state
the median `catch_coverage`. It must not describe the Service Area File as closing the
geographic-attribution problem at no cost. Plan §4's wording to that effect is
superseded by the measurement in `spike-context.md` §2.

---

## 6. Gate O1 — Outcome frame *(added; committed for the same reason as §5)*

| Gate | Predicate | Threshold | Type | Observed at spike |
|---|---|---|---|---|
| **O1.a** | frame = `Hospital Type == "Acute Care Hospitals"` **and** numeric `PSI_90` | definitional | — | **n = 2,801** |
| **O1.b** | VA hospitals excluded by explicit filter, count reported | **107**, reported not dropped silently | FAIL if not reported | 107 |
| **O1.c** | footnote codes `1`, `5`, `7`, `13`, `19`, `23`, `29` kept distinct; `7` (structural zero) never collapsed with `1` (volume suppression) | **= 0** collapsed | FAIL if above | enforced by construction |
| **O1.d** | component models report their own `n`; the four-component joint sample reported separately | both `n`s stated | FAIL if not | 2,801 vs **2,294** |
| **O1.e** | PSI-90 source is the Care Compare six-decimal file; HACRP PSI-90 is used only as the Phase 4 payment anchor, and the report states both official values exist and differ | stated | FAIL if not | mean difference **0.00191**, r = 0.9996 |

O1.d exists because listwise deletion across the four components silently costs 507
hospitals (18.1% of the frame), and those hospitals are systematically low-volume —
correlated with rurality and therefore with Block B. That must be a decision, not a
default.

---

## 7. Amendments

**A1 — 2026-08-26 — Gate C2 imputation hierarchy reversed.**
*What changed:* multiple imputation (PMM, m=20) becomes the primary treatment of
contract-labor missingness; the missingness indicator is demoted from required
estimation strategy to MNAR diagnostic; deterministic recovery from raw HCRIS and the
FY 2022 report is inserted ahead of any imputation; the MCR clause is replaced by a
Rashomon coefficient-range requirement.
*Why:* the indicator method is biased in regression even under MCAR, and the Phase 0
diagnostic that prompted the original clause — missingness predicted by beds and
rurality — establishes MAR against fully observed covariates, which is precisely where
MI is unbiased. Separately, Block C covariates are controls and never carry MCR claims,
so the original clause was scoped wrong.
*What had been seen at the time:* the Phase 0 coverage and missingness diagnostics
only. **No model had been fitted, and none has been fitted as of this amendment.** No
threshold in §2, §4, §5, or §6 is altered.

**A2 — 2026-08-26 — Gate B0 working constant corroborated; no threshold changed.**
A cross-vintage test found only 2.3% of suppressed cells exceed 11 cases in an adjacent
year, evidence that most hold 1–3. The constant of 3 in `catch_coverage` stands. A
direct test of the suppression bias (`plan-amendments.md` §2.2) found r ≥ 0.986 between
observed-only and suppression-imputed catchment SVI. **No gate threshold is changed.**

---

## 8. Verification against Task 0.6

- [x] A completeness threshold and a plausibility screen committed for **each** Block C
      covariate: coding intensity (§2), staffing instability (§3), tort environment (§4).
- [x] Every gate has **a number** and the document has **a date**. No gate reads
      "adequate coverage" or "reasonable quality" — every predicate is one a script
      evaluates and writes to `admission-gate-results.csv`.
- [x] The document states that the equity finding rests on Block B and survives total
      Block C failure — §0, first line.
- [x] Committed before any modelling result was seen, with the amendment rule that
      keeps it that way — header.
