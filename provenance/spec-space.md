# The specification space — full enumeration

**Date:** 2026-09-02 · **Task:** 3.4 · **Status: enumerated, not yet frozen.**
Task 3.5 converts this to `data/spec-registry.rds` and commits the integer count
before the first fit.

This document lists every analytic choice the specification curve will vary, the
levels of each, and a stated reason for every level. It is written **before any
specification is fitted** and — per the task sheet's fresh-session rule — without
the Task 3.3 decomposition numbers in view. Every level below is justified from
one of: the plan (`Variance Project - Plan.md`), the frozen amendments
(`plan-amendments.md`, `admission-gates.md`), or the **pre-decomposition**
exploratory pass (Task 3.1, `provenance/task3.1-eda.md`). No level was added,
dropped, or re-scoped because a fitted result made it look interesting; §11
records the choices that were considered and deliberately left out.

Everything is fitted on the frozen file `data/analytic-v1.rds` (hash
`7d409b5d…`) and nothing else. All Block B grain variants, the reliability
weight `lambda_i`, the two suppression flags, and the catchment-fallback flag
are already columns in that file — this space introduces no new data.

---

## 1. The axes at a glance

| # | Axis | Levels | k |
|---|---|---|---|
| A1 | Covariate blocks | A / A+B / A+B+C(admitted) | 3 |
| A2 | Functional form | linear / natural spline on the continuous disadvantage measures | 2 |
| A3 | Outcome definition | composite PSI-90 / PSI-03 / PSI-06 / PSI-12 / PSI-13 / denominator-weighted component aggregate | 6 |
| A4 | Reliability treatment | unweighted / reliability-weighted / high-reliability subsample / λ-corrected errors-in-variables | 4 (composite) · 3 (component outcomes) |
| A5 | Geographic grain | catchment-tract / catchment-county / hospital-county / Dartmouth HSA | 4 |
| A6 | Missing-data treatment | MI (PMM, m=20) / complete-case / covariate omitted | 3 (only when Block C is in) |
| A7 | Influential-point handling | all / drop footnote-23 & -29 hospitals / drop catchment fallbacks | 3 |

Naive crossing 3·2·6·4·4·3·3 = **5,184**. Structural voids (§9) remove roughly
half. Grid size: §10.

---

## 2. Axis A1 — covariate blocks

**Levels: A / A+B / A+B+C(admitted).**

| Level | Contents | Reason it is a level |
|---|---|---|
| A | 11 Block A structural covariates (Task 2.3 working set; `cmi`, `volume`, beds/ADC size cluster, teaching intensity, DSH, operating margin, wage index, ownership, system membership, urban/rural location) | The "hospital characteristics" baseline. Plan §6 line 106 lists covariate blocks in/out as the first axis. This is the model that attributes everything it can to structure. |
| A+B | A plus the 11-measure Block B working block (SVI 1–4, `adi`, `ice150`, `uninsured`, `rurality`, `limeng`, `pcp_density`, `hhi_zip`) settled at Task 3.1 | The substantive question of the project — how much between-hospital PSI variation tracks community disadvantage once structure is held. |
| A+B+C | A+B plus the admitted Block C covariates (`cmi_drift`, `contract_labor_share`, `tort_*`) per Task 2.7's gate results and amendment A1 | The full defensible model. Block C entered as context, never ranked (`plan-amendments.md` §3.3). `cmi_level` is excluded permanently — it is an exact duplicate of Block A's `cmi` (Task 3.2 headline 2), not an analytic choice. |

**Not a level: B alone, or C alone.** Block A is a confounder set for the Block B
question (Task 3.1 §4: Block A×B entangled, `wage_index`~`adi` −0.66); a
disadvantage association with no structural adjustment is not a defensible
specification, only a diagnostic. Block ordering is not an axis either — the
decomposition is order-free by construction (LMG), so "A then B" vs "B then A"
is not a modelling fork.

---

## 3. Axis A2 — functional form

**Levels: linear / natural cubic spline on the continuous disadvantage measures.**

- **linear** — every covariate enters linearly (the Task 3.2 baseline form).
- **spline** — natural cubic splines (df = 3, boundary knots at the 5th/95th
  percentiles) on the *continuous* Block B disadvantage measures: `adi`,
  `ice150`, `svi1`–`svi4`, `uninsured`, `limeng`. Ordinal / count measures
  stay linear (`rurality` is USDA RUCC 1–9; `pcp_density` is a rate with a
  long right tail better handled by the reliability/transform machinery than
  by knots) and the market measure `hhi_zip` stays linear. Block A and Block C
  covariates stay linear in both levels — the axis is about the shape of the
  **disadvantage–outcome** relationship, which is the relationship the report
  makes a claim about.

**Reason for the spline level.** Task 3.1 §1: 20 of 37 measures have |skew| > 1,
and PSI-90 itself is right-skewed (+2.75). Task 3.1 §5: the outcome gradient
across ADI quartiles is +0.045 Q1→Q4 but not evenly spaced across the quartiles,
and `uninsured` runs the *opposite* direction from the other disadvantage axes —
both are signs that a single linear slope may misrepresent the relationship.
Plan line 106 lists functional form as an enumerated axis. Two levels is enough:
the question is "does allowing curvature change the conclusion," not "which of
six bases is best."

**Spline collapses to linear when Block B is out** (blocks = A) — see §9.

---

## 4. Axis A3 — outcome definition

**Levels: composite PSI-90 / PSI-03 / PSI-06 / PSI-12 / PSI-13 / denominator-weighted component aggregate.**

| Level | What it is | Reason it is a level |
|---|---|---|
| composite PSI-90 | The CMS Care Compare published composite, reliability-shrunk | The outcome a JHF reader actually sees and the one the plan's §10 sentence is about (Plan §2). |
| PSI-03 / 06 / 12 / 13 | The four admitted components, each at its own published denominator and coverage (Task 2.2; psi13 82.6%) | Plan §2: "the components measure what [the composite's] concealment costs." The four move together only weakly (pairwise r 0.04–0.15, Task 3.2 §1), so they are four genuinely different views, not four noisy copies. |
| denominator-weighted component aggregate | The four components combined into one hospital score, weighted by their published denominators — an un-smoothed alternative composite | Isolates the effect of CMS's *reliability smoothing* specifically: same four conditions, same weighting logic, without the shrinkage. Directly serves the "what does the smoothing conceal" question the missing O/E split forced onto the analysis. |

PSI-13's 17.4% missingness is handled available-case per component (admission
gate O1.d) in every arm — it is **not** on the missing-data axis (A6). Component
outcomes are z-scored to their own mean/sd before any pooled fit, per Task 3.2
headline 1 (raw component variances differ ~500×); the z-scoring is a fixed
preprocessing step, not a level.

---

## 5. Axis A4 — reliability treatment *(new in rev 2)*

**Levels: unweighted / reliability-weighted / high-reliability subsample / λ-corrected errors-in-variables.**

The published composite retains a **median 46% of true between-hospital
deviation** (`lambda_i` median 0.462, range 0.09–0.96; Task 2.2) and the
attenuation is **volume-correlated** — λ rises monotonically across volume
quartiles 0.21 → 0.38 → 0.56 → 0.76 (`plan-amendments.md` §1.2). Rural hospitals
retain 0.30, non-rural 0.52. A specification that ignores this is making an
implicit choice ("the published number is the truth"), so it must be an explicit
axis. `plan-amendments.md` §1.4(b) names it.

| Level | Composite | Component outcomes | Reason |
|---|---|---|---|
| unweighted | OLS / unweighted mixed model | same | The naive analysis. The baseline every other level is compared against. |
| reliability-weighted | WLS with `weights = lambda_i` (Task 3.2 §7's composite choice) | WLS with `weights =` published denominator (Task 3.2's component choice) | Down-weights the hospitals whose published value is least informative. For the composite the weight is λᵢ; for the components, which have no composite-specific reliability but *do* have published denominators, the principled analog is denominator weighting. |
| high-reliability subsample | restrict to hospitals with λᵢ in the top tier (λ ≥ 0.6, ≈ upper two volume quartiles) | restrict to the same hospital set (volume/denominator top tier) | Trades N for a sample where measurement error is small. If the conclusion holds here it is not an artifact of the low-λ tail. `plan-amendments.md` §1.4(b). |
| λ-corrected errors-in-variables | outcome treated as a noisy observation of the latent value with known reliability λᵢ; variance inflated by 1/λᵢ² *inside* the regression, never as a per-hospital point estimate (`plan-amendments.md` §1.4(c)) | **not defined** — no published per-hospital reliability for the components at the precision this needs | The formal correction. Composite only. |

Component-outcome arms therefore have **3 levels** on this axis, not 4.

**Interaction with A3 already handled:** the reliability axis exists because of
composite smoothing; the "denominator-weighted component aggregate" outcome
(A3) is a different lever (removes smoothing by construction) and the two are
allowed to co-vary — an aggregate outcome under λ-EIV correction is simply void
(no λ for that outcome), pruned in §9.

---

## 6. Axis A5 — geographic grain

**Levels: catchment-tract / catchment-county / hospital-county / Dartmouth HSA.**

All four are already built as parallel column families in the frozen file
(`*_catch_tract`, `*_catch_county`, `*_county`, `*_hsa`) and as nesting
geographies.

| Level | Block B covariate grain | Nesting | Reason it is a level |
|---|---|---|---|
| catchment-tract | catchment-tract-weighted (Task 2.4 engine, 705k ccn×tract weights) | HSA | The base case (`plan-amendments.md` §2.4). Task 2.5 key result: r(catch_tract, county) = 0.56–0.88 — the tract weighting diverges materially from naive county assignment, i.e. it earns its hours. |
| catchment-county | catchment-weighted but aggregated to county | HSA | Diagnostic middle grain. Isolates whether it is the *catchment weighting* or the *tract resolution* that matters — r(catch_county, county) = 0.92–0.99 for SVI (Task 2.5), so this is close to the naive grain for most measures. |
| hospital-county | the hospital's own county, unweighted | county | The naive / attack grain — what a critic who dismisses catchment weighting would use. Its distance from the base case is the robustness result. |
| Dartmouth HSA | HSA-level disadvantage measures | HSA | Suppression-free robustness grain. HSA is the project's catchment geography for nesting already (Task 3.2); at HSA level the small-area suppression that forces fallbacks at tract level mostly disappears. |

**Reason for four and not more:** ZIP and ZCTA are the *base grains the engine
builds from* (Task 2.4), not analysis grains; census region/division/state carry
almost no PSI-90 signal (ICC 0.006–0.043, Task 3.1 §5) so a state-level grain
would be a null by construction. CBSA (ICC 0.13) is where the signal sits but is
not a disadvantage-measurement geography — it is picked up by the nesting in the
tract and county arms.

Under blocks = A (no Block B in the model) the tract vs county *covariate* grain
is inert; the arms differ only by nesting geography — 3.5 may dedupe these (§9).

---

## 7. Axis A6 — missing-data treatment

**Levels: MI (PMM, m=20) / complete-case / covariate omitted.**

The only substantively-missing **covariate** in the model space is Block C's
`contract_labor_share` (5.0% missing, MAR, differential with disadvantage —
Task 2.6). The m=20 PMM imputation is frozen with the file (`cl_share_mi_01..20`).

| Level | Reason |
|---|---|
| MI (PMM, m=20), Rubin's rules | The licensed primary treatment (admission gate C2, amendment A1). Imputation model is richer than the analysis model and includes the outcome. |
| complete-case | The transparent fallback. Task 2.7 reports `contract_labor_share` under both and they agree (β = +0.063 CC vs +0.058 MI-pooled); showing that agreement across the whole curve is the robustness result. |
| covariate omitted | Drop `contract_labor_share` from the model entirely. The honest option if a reader distrusts both the imputation and the complete-case sample. |

**The missingness-indicator arm is deliberately absent.** Amendment A1: the
indicator method is biased in regression even under MCAR. It is retained only as
a diagnostic in the missingness audit, never as a specification-curve level.

This axis is **only active when Block C is in the model** (blocks = A+B+C). For
blocks = A and A+B it collapses to a single "n/a" level — see §9.

---

## 8. Axis A7 — influential-point handling

**Levels: all / drop footnote-23 & -29 hospitals / drop catchment fallbacks.**

| Level | n dropped | Reason |
|---|---|---|
| all | 0 | Standing rule 4: nothing gets dropped quietly. The full frame is the base case. |
| drop footnote-23 & -29 | 77 (16 with a claims-data discrepancy flag + 61 computed on a partial performance period; the two sets do not overlap) | These hospitals carry a **numeric PSI-90 with a CMS quality caveat attached** (`spike-outcome.md` §6). Footnote 23 = the hospital reported claims-data discrepancies; footnote 29 = CMS-approved partial-window calculation. Both are present values of reduced trustworthiness — the canonical influential-point sensitivity. |
| drop catchment fallbacks | 130 (`catch_source == "county_fallback"` — hospitals whose catchment could not be built from the ZIP→tract engine and fell back to county assignment; Task 2.4, 4.64% of the frame, all 5 gate B0 checks still pass) | Tests whether the catchment-weighted Block B measures are being driven by the hospitals where the weighting is weakest. Only bites on arms with Block B in at a catchment grain. |

Cook's-distance / leverage-based trimming is **not** a level — it selects the
points to drop using the fitted model, which is circular in a specification
curve. The three levels here are defined from data-quality flags fixed before
any fit (3 of the 130 fallbacks also carry a 23/29 flag; the two drop rules are
applied independently, not unioned).

---

## 9. Structurally void combinations

The naive crossing contains cells that are not defensible specifications but
logical impossibilities or exact duplicates. Task 3.5 prunes them mechanically;
they are enumerated here so the frozen count is not mistaken for the factorial.

| # | Rule | Effect |
|---|---|---|
| V1 | **Spline requires disadvantage measures in the model.** A2 = spline is identical to A2 = linear whenever blocks = A. | Under blocks = A, A2 collapses to 1 level. |
| V2 | **The missing-data axis requires the imputed covariate in the model.** `contract_labor_share` ∈ Block C only. | Under blocks ∈ {A, A+B}, A6 collapses to 1 level ("n/a"). |
| V3 | **λ-corrected EIV requires a published per-hospital reliability.** Defined for the composite outcome only. | A4 = λ-EIV is void for all five component-based outcomes; those outcomes carry 3 A4 levels, not 4. |
| V4 | **Catchment covariate grain is inert without Block B covariates.** Under blocks = A, catchment-tract and catchment-county differ only by nesting geography. | 3.5 may dedupe A5 to {HSA-nested, county-nested} = 2 levels under blocks = A. Applied as a dedup, conservatively left as 4 in the upper bound below. |
| V5 | **Drop-catchment-fallbacks is a no-op where it changes nothing measurable** — under blocks = A, or under a hospital-county grain (no catchment construction used). It is kept as a distinct row for bookkeeping but produces a fit identical to "all" in those cells. | Duplicate fits, deduped by 3.5. |

---

## 10. Grid size

| Count | Value |
|---|---|
| Naive factorial (3·2·6·4·4·3·3) | **5,184** |
| After hard voids V1–V3 (spline⇒B, missing-arm⇒C, EIV⇒composite) | **2,592** |
| After the A4 component mapping (3 levels not 4 on the five component outcomes) and the V4 grain dedup | **≈ 1,950–2,100** |
| Frozen integer | **produced by Task 3.5**, committed before the first fit |

Worked reduced count (one defensible ruleset — 3.5 mechanizes the exact figure):

```
blocks = A      : FF 1 · miss 1 · grain 4 · infl 3
   composite            1·1·4·3 · rel 4  =  48
   5 component outcomes 1·1·4·3 · rel 3  = 180
   subtotal                              = 228   (→ ~114 after V4 grain dedup)

blocks = A+B    : FF 2 · miss 1 · grain 4 · infl 3
   composite            2·1·4·3 · rel 4  =  96
   5 component outcomes 2·1·4·3 · rel 3  = 360
   subtotal                              = 456

blocks = A+B+C  : FF 2 · miss 3 · grain 4 · infl 3
   composite            2·3·4·3 · rel 4  = 288
   5 component outcomes 2·3·4·3 · rel 3  = 1,080
   subtotal                              = 1,368

total ≈ 2,052   (≈ 1,938 after V4 grain dedup)
```

**If the optional outcome-scale axis (§11) is adopted, multiply by 2 → ≈ 3,900.**

Runtime feasibility (Task 3.6's problem, flagged here): the composite arms are
`lm`/`lme4` fits of a few seconds; the component arms are stacked-long `lmer`
fits (~2.5 s each at the sizes seen in Task 3.2). At ~2,000 specs and a few
seconds each the full curve is single-digit hours, comfortably inside Task 3.6's
8 h and the "estimate runtime before launching" verify condition.

---

## 11. Considered and deliberately excluded

Recorded so the exclusions are visible and 3.5 does not silently reintroduce
them.

| Candidate | Disposition |
|---|---|
| **Outcome scale: identity vs log** | Task 3.1 §1 flagged raw-vs-log outcome as a candidate axis (PSI-90 skew +2.75 → +1.05 logged). It is **defensible and pre-decomposition**, but it is not in the rev-2 axis table, which the task sheet states "fixes the axis list." **Left as an open decision for Task 3.5 / Carl.** Recommendation: add it as an 8th axis (2 levels) — it is cheap, principled, and a health-services reviewer will ask (Plan §12). Grid-size figures in §10 are given both ways. |
| **`adi2020` for `adi`, `ice` for `ice150`** | Not an axis. These are near-exact duplicate vintages (r = 0.99, full-block VIF 64–87; Task 3.1 headline). They are one-at-a-time **robustness swaps** run outside the curve, never co-entered with their partner. |
| **Block B as PCA / reduced index (PC1–3)** | Not a base-case level. Task 3.1 §3: PC1–3 carry 73% of Block B's variance but only 52% of its outcome association — collapsing to components discards half of an already-small signal. It is a single robustness arm (Plan appendix), not a curve axis. |
| **Block ordering / sequential attribution** | Not an axis. The decomposition (Task 3.3 method) is order-free by construction. |
| **Cook's-distance / model-based outlier trimming** | Not a level (A7). Selecting points with the fitted model is circular inside a specification curve. |
| **Alternative nesting (CBSA, state)** | Not a grain level. State carries ~4% of PSI-90 variance, division <1% (Task 3.1 §5); CBSA signal is absorbed by the tract/county nesting already in A5. |
| **HACRP composite (`psi90_hacrp`)** | Reserved for Phase 4 (`provenance/task2.2-outcomes.md`); not a Phase 3 outcome level. |
| **Weighting by 1/vᵢ instead of λᵢ** | Folded into A4's "reliability-weighted" level as an implementation detail, not a separate level — λᵢ and 1/vᵢ rank hospitals near-identically. |

---

## 12. Files and next

```
provenance/spec-space.md    this document — the enumerated grid
```

No code, no `make.R` stage, no `data/` output, no `sources.csv` change — Task
3.4 is enumeration only. Provenance table stays at 33 rows.

**Task 3.5 — freeze the specification registry.** Convert this grid to
`data/spec-registry.rds`, resolve the two open items (the outcome-scale axis;
the exact V4/V5 dedup rule), count the total, and **commit before any fit** —
that commit timestamp is the evidence the curve was not fitted first. `[Fitting
begins at Task 3.6, not before.]`

---

**Resolved at Task 3.5 (2026-09-02, commit `7e8a04e`).** Both open items closed:
the outcome-scale axis (identity / log) **was adopted** as an 8th axis (Carl's
sign-off); the V4/V5 dedups were mechanised as written. Frozen registry:
**N = 3,496** specifications (`data/spec-registry.rds`, force-tracked). Naive
8-axis factorial 10,368 → 3,496 after V1–V5. See
`provenance/task3.5-spec-registry.md`.
