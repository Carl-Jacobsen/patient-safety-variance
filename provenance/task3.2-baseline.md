# Task 3.2 — Fit the baseline hierarchical model (REWRITTEN, rev 2)

**Date:** 2026-09-01 · **Budget:** 6 h · **Status: complete.**
One stage (`make.R` 21, `R/03-baseline.R`) reading `data/analytic-v1.rds` and
`data/blockC_mice.rds` (the m=20 PMM mice object `R/blockC.R` froze explicitly
"for Phase 3 pooling" — a second read of an already-frozen, reproducible
pipeline output, not a new data source). Full `make.R` from raw (324 s):
every stage `ok` through stage 21, provenance `consistent`, stage 19
re-verified the frozen hash (`7d409b5d…`) unchanged.

**The bug this fixes** (`plan-amendments.md` §1.4, task sheet Task 3.2): a
hierarchical model fit on the *published* PSI-90 would shrink an
already-shrunk estimate a second time, hardest exactly where CMS's own
shrinkage was already hardest (low-volume hospitals). **Fix:** the primary
hierarchical fit runs on the four admitted **components** (PSI-03, -06, -12,
-13) — published denominators, far weaker smoothing — stacked long, hospitals
nested in **HSA** (the Dartmouth Hospital Service Area containing the
hospital's own ZIP; `R/blockB.R`'s `zip2hsa`, this project's "catchment
geography"), weighted by the published denominator. The composite is treated
separately, via task-sheet option (b): reliability-weighted fixed effects, no
random intercept anywhere — never re-shrunk.

**Headline 1 — the four components are not on a common scale, and that had
to be fixed before fitting.** Unlike PSI-90 (a ratio, mean ≈ 1), each
component's six-decimal "Rate" is a raw risk-adjusted rate in its own units:
mean(psi06) = 0.21, mean(psi13) = 5.31 — a 25× difference in level and a
**~500× difference in variance** (0.0025 vs 1.23). Stacking the raw rates
under one residual-variance parameter would let PSI-12/-13's noise dominate a
"between-hospital variance" meant to describe all four conditions; a `psi`
fixed effect only re-centers each group, it does not equalize variances.
**Each component is z-scored to its own mean/sd before stacking.** This is a
Task 3.2 finding in its own right, not a modeling nicety — see §1.

**Headline 2 — a second bug caught in Block C's own "admitted" list.**
`cmi_level` (`R/blockC.R` line 91: `cmi_level <- n_(a$cmi)`) is an **exact
duplicate of Block A's `cmi`** (r = 1, 0 mismatches on 2,798 hospitals with
both). Entering both made the fixed-effect design matrix rank deficient.
Block A's `cmi` already carries that information; `cmi_drift` (the
FY2025→FY2026 change) is Block C's genuine incremental contribution and is
what's in the model. `cmi_level` is dropped — see §5.

**Headline 3 — the reconciliation the verify condition asked for is a real
disagreement, and it has a specific, stated explanation.** The null model's
between-hospital variance is not on tau2's scale (z-units vs. psi90's ratio
units), so the unit-free comparison is share-of-variance: **ICC(hospital) =
0.217** in the components model vs. **mean λᵢ = 0.475** for the composite
(Task 2.2). That is a **material gap, recorded, not papered over** — see §3.

---

## 1. Component scale check (`R/03-baseline.R` §2)

| component | mean | sd | var |
|---|---|---|---|
| psi03 | 0.601 | 0.511 | 0.2607 |
| psi06 | 0.210 | 0.050 | 0.0025 |
| psi12 | 3.507 | 0.714 | 0.5098 |
| psi13 | 5.313 | 1.111 | 1.2336 |

Pairwise correlation among the four raw components: **min 0.040, max 0.147**
— these are largely distinct clinical conditions (postoperative hemorrhage,
iatrogenic pneumothorax, pulmonary embolism/DVT, sepsis), not four noisy
readings of one latent "hospital safety" trait. That weak intercorrelation is
the reason §3's reconciliation gap is a real finding and not a coding error:
a single shared hospital random intercept is being asked to explain four
conditions that do not, empirically, move together.

Coverage: psi03 99.2%, psi06 100.0%, psi12 97.4%, psi13 82.6% of the
2,801-hospital frame (17,4% missing on psi13 reproduces the 2.6 missingness
audit). Stacked long frame: **10,619 rows, 2,801 hospitals × up to 4
components**.

---

## 2. The nested progression — null → Block A → Block A+B → Block A+B+C

`y ~ psi + <block covariates> + (1 | hsa/ccn)`, `weights = denominator`
(rescaled to mean 1, WLS-equivalent, numerically stable), REML,
`lmerControl(optimizer = "bobyqa")`.

| model | n rows | logLik | converged | singular |
|---|---|---|---|---|
| null (psi + geography) | 10,619 | −21,352.8 | yes | no |
| + Block A (11) | 10,419 | −20,862.8 | yes | no |
| + Block A + B (11, Task 3.1 working set) | 10,260 | −20,454.1 | yes | no |
| + Block A+B+C (4, complete-case) | 9,782 | −19,322.9 | yes | no |

**No convergence warnings anywhere, no models singular** — the verify
condition's "warnings are resolved, not suppressed" requirement is met by
having none to resolve.

### Variance components (z-units — see §3 for why these aren't tau2-scaled)

| model | var(HSA) | var(hospital) | var(residual) | ICC(hospital) | ICC(HSA) |
|---|---|---|---|---|---|
| null | 0.0510 | 0.3063 | 1.0549 | **0.217** | 0.036 |
| + Block A | 0.0472 | 0.2794 | 1.0441 | 0.204 | 0.034 |
| + Block A + B | 0.0348 | 0.2762 | 1.0616 | 0.201 | 0.025 |
| + Block A+B+C (CC) | 0.0354 | 0.2699 | 1.0418 | 0.200 | 0.026 |

Covariates explain almost none of the hospital-level ICC (0.217 → 0.200,
a 1.7-point drop across all three blocks) — the between-hospital signal in
the raw components is largely **not** attributable to the structural,
community, or policy covariates on hand. That is itself the raw material
Task 3.3's decomposition has to work with, and is consistent with Task 3.1's
finding that every marginal correlate of the outcome is small.
`output/tables/baseline-variance-components.csv`.

---

## 3. Reconciling the null model against tau2 = 0.07744 (the verify condition)

tau2 (Task 2.2) is in psi90's own ratio-to-national units
(Var(psi90) = 0.0368); the components model's response is z-scored per
component (§1), so its variance components are dimensionless. **A raw ratio
of the two would compare apples to oranges** (for the record: hospital
variance / tau2 = 3.95×, noted but not used).

**The comparison that is unit-free:** both quantities answer "of the
variance in a single, unsmoothed hospital-level PSI measurement, what
fraction is genuine, stable signal?"

| quantity | value |
|---|---|
| composite: mean published reliability λᵢ (Task 2.2) | **0.475** |
| components: null-model ICC(hospital) | **0.217** |
| gap | **−0.258** |

**FINDING — material disagreement, and here is the reading.** A single
shared hospital random intercept across four conditions with pairwise
r = 0.04–0.15 (§1) is a much more constrained model than the composite's own
construction (a specific, national, condition-weighted average). It can only
capture the *common* part of a hospital's tendency across conditions; if the
true "hospital effect" is substantially condition-specific — plausible,
given how weakly the raw rates correlate — a shared scalar intercept will
recover less of it than CMS's composite reliability implies, because the
composite's λᵢ describes reliability of the *specific weighted average CMS
already built*, not of a naively shared latent trait across four unrelated
conditions. **This is the expected signature of exactly the population Task
3.1 described (Block B's outcome signal spread across many weakly correlated
measures, not concentrated in one dimension) showing up again on the
outcome side.** It is not evidence the components fit is wrong; it is
evidence that "one PSI performance" is not one thing, which is itself
material for how Task 3.3 frames the decomposition and for whether a future
task should test a condition-specific (`(1 + psi | ccn)`) random-slope
extension — flagged for Task 3.4, not fitted here (scope).

---

## 4. Fixed effects, Block A+B+C (complete-case), standardized components

`output/tables/baseline-fixed-effects-ABC-complete-case.csv` (30 terms,
n = 9,782 rows / ~2,445 hospitals). Selected terms with |t| ≥ 2:

| term | β (z-units) | SE | t |
|---|---|---|---|
| volume (Medicare bills) | **−0.168** | 0.035 | **−4.85** |
| psipsi13 (component intercept) | −0.149 | 0.051 | −2.93 |
| psipsi06 (component intercept) | −0.116 | 0.022 | −5.20 |
| contract_labor_share | **+0.063** | 0.019 | **+3.38** |
| hhi_zip (market concentration) | +0.069 | 0.022 | +3.15 |
| operating_margin | **−0.073** | 0.023 | **−3.24** |
| resident_to_bed (teaching intensity) | +0.074 | 0.022 | +3.39 |

**No Block B (community-context) measure clears \|t\| = 2** — `ice150`
(income/poverty axis) comes closest at β = −0.118, t = −1.70, in the
direction Task 3.1's raw gradient predicted (more affluent catchment →
lower/better standardized rate). This null result at the individual-measure
level is exactly what Task 3.1's collinearity finding (§3 there) said to
expect, and is why Tasks 3.11–3.14 (MCR, TIS) exist rather than reading
significance off single Block B coefficients here.

The `psipsi06`/`psipsi13` component-intercept terms are not exactly zero
despite the per-component z-scoring (§1) — expected: z-scoring used the
full 2,801-hospital frame, but each model's *estimation sample* differs
slightly by component (case-wise deletion on covariates), so the
within-sample component means aren't identically zero. The `psi` fixed
effect is doing its job absorbing that residual differential-missingness
shift.

---

## 5. Contract-labor-share: MI (m=20) vs. complete-case

`R/blockC.R`'s own instruction (Sec "A1 step 3", written when Task 2.7 froze
`data/blockC_mice.rds` "for Phase 3 pooling"): **"coefficient range reported
under both MI and complete-case at Phase 3."** Done here for the Block
A+B+C model — 20 `lmer` refits (one per `mice::complete(mi, k)`, contract-
labor-share and its co-imputed tiny Block A gaps substituted), pooled by
Rubin's rules.

| treatment | n | β (z-units) | SE |
|---|---|---|---|
| complete-case (158 hospitals / 557 rows dropped) | 9,782 | **+0.0630** | 0.0187 |
| MI pooled (m = 20) | 10,260 | **+0.0578** | 0.0193 |

Both treatments agree: **higher contract-labor share associates with worse
(higher) standardized component rates**, t = 3.38 (CC) / z = 3.00 (MI
pooled), fraction of missing information FMI = 0.12 — modest, consistent
with 5.6% raw missingness on a variable Task 2.6 found MAR. All 20
imputations converged, none singular. Variance components across the 20
fits are tight (hospital variance 0.2720–0.2746, mean 0.2736; no formal
Rubin's-rule extension exists for variance components, so the spread itself
is the reported uncertainty). `output/tables/baseline-contract-labor-mi-vs-cc.csv`,
`baseline-fixed-effects-ABC-MI-pooled.csv`.

---

## 6. Composite (PSI-90) — option (b): reliability-weighted, no random effect

Task sheet option (a) — treat CMS's known λᵢ/vᵢ as the model's first level —
needs a variance structure lme4 does not expose (a *fixed*, not
re-estimated, per-observation residual variance), and `DESCRIPTION` declares
no meta-analysis package for it. **Option (b) is exact with what's on hand:**
`lm(psi90 ~ blockA + blockA+B + blockA+B+C, weights = lambda_i)`, fixed
effects only, no random intercept at any level — nothing here can re-shrink
the composite.

| model | n | weighted R² | resid. SE |
|---|---|---|---|
| null | 2,801 | 0.000 | 0.1503 |
| + Block A | 2,744 | 0.046 | 0.1468 |
| + Block A + B | 2,700 | 0.081 | 0.1456 |
| + Block A+B+C (CC) | 2,569 | 0.091 | 0.1439 |

Block B roughly doubles Block A's explained (weighted) variance (+0.035);
Block C adds a further +0.010. `output/tables/baseline-composite-wls.csv`.

---

## 7. Files

```
R/03-baseline.R                                      new -- stage 21
make.R                                                stage 21 added
.gitignore                                            output/models/* added (built product, same
                                                       treatment as data/ and output/tables|figures/)
output/models/task3.2-models.rds                      all model objects (gitignored, regenerable)
output/tables/baseline-variance-components.csv        the Sec 2/3 deliverable
output/tables/baseline-fixed-effects-ABC-complete-case.csv
output/tables/baseline-fixed-effects-ABC-MI-pooled.csv
output/tables/baseline-contract-labor-mi-vs-cc.csv
output/tables/baseline-composite-wls.csv
output/tables/task3.2-baseline.txt                    stage log
```

---

## 8. Next

**Task 3.3 — variance decomposition and its figure.** Produce the
community/structure/residual split with uncertainty, reported both
uncorrected and λ-corrected. This task's variance-component table
(`baseline-variance-components.csv`) and the §3 reconciliation (ICC(hospital)
0.217 vs. λ̄ 0.475, and why) are the direct inputs. **Carry forward:** Block
covariates explain almost none of the hospital ICC (0.217→0.200, §2) — the
decomposition's "how much tracks community disadvantage" question is being
asked of a between-hospital variance that structural/context covariates
barely touch, which itself belongs in the one-sentence-with-a-number
statement Task 3.3 has to draft. Also carried forward: the weak
inter-component correlation (§1) as a candidate reason to test a
condition-specific random-slope extension at Task 3.4, and `cmi_level` /
Block A's `cmi` as duplicate columns to flag if any future task's covariate
list is built independently of `R/03-baseline.R`'s `bA`/`bC`.
