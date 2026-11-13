# Task 3.6 — Build the fitting harness

**Date:** 2026-09-02 · **Budget:** 8 h · **Status: complete. Harness built and
tested; the full grid is Task 3.7.**
One stage (`make.R` 24, `R/04-spec-curve.R`) reading `data/spec-registry.rds`
(the frozen 3,496-row grid), `data/analytic-v1.rds`, and `data/blockC_mice.rds`
(the m=20 PMM object, for the `missing = "mi"` arm — same second read as Task
3.2). **No specification is fitted for the record yet** — this task builds the
harness and runs it on a 10-spec subset; `SPEC_CURVE_FULL=1` (Task 3.7)
produces `data/spec-results.rds`. The Task 3.5 registry commit (`7e8a04e`)
predates this harness, and this harness commit predates the first recorded fit.

---

## 1. What the harness produces per spec — one uniform row

Every registered spec resolves to one row of a results data.frame, whatever
happens to the fit:

| field group | columns |
|---|---|
| identity | `spec_id`, all 8 axis columns + derived fields (merged from the registry) |
| status | `status` ∈ {ok, failed}, `fail_reason` (chr, NA when ok), `runtime_s`, `m_imp` |
| fit health | `converged`, `singular`, `lme4_msg` — **flags, not filters**: a non-converged or singular fit is `status = "ok"` with the flag set, kept in the object |
| **focal estimate** | `dis_effect`, `dis_se`, `dis_sign`, `dis_sig` |
| per-measure | `b_<m>`, `se_<m>` for the 10 disadvantage measures (svi1–4, adi, ice150, uninsured, limeng, rurality, pcp_density) |
| loss / fit | `loss_wrmse`, `logLik`, `AIC`, `deviance` |
| variance | `var_geo`, `var_hosp`, `var_resid`, `icc_geo` |

**Failures are rows, not skips** (task sheet). A fit that errors is caught,
`status` set to `"failed"`, `fail_reason` set to the condition message, `spec_id`
and `runtime_s` retained, every estimate `NA`. Verified directly: a spec pointed
at a non-existent outcome column returns `status = "failed"`,
`fail_reason = "subscript out of bounds"`, row intact. The 10 real test specs
all fit clean (0 failed), so the failure path is exercised separately rather
than by planting a broken spec in the test set.

---

## 2. The focal estimate — `dis_effect`

The model-predicted change in the outcome when a hospital's community-
disadvantage profile moves from the **10th to the 90th frame percentile on
every disadvantage measure at once**, each oriented so the deprived end is the
high end (ICE-150 and PCP density inverted). Positive = more-deprived
communities have worse (higher) PSI.

It is a **joint contrast, not a single coefficient**, by design. Task 3.1
established Block B is too collinear for any one marginal coefficient to be
stable (`adi`~`ice150` r = −0.83; three VIFs > 5). Plan §6: "the defensible
claim is that no near-optimal model can ignore community disadvantage, not SVI
theme 2 specifically." Computed as **c′β** where c is the contrast vector from
`model.matrix()` on two hospital-profile rows (hi/lo), with SE **√(c′Vc)** by
the delta method — identical machinery for `lm` and `lmer`, and it handles the
spline basis automatically (natural cubic spline, knots fixed from frame
quantiles so the contrast is the same "move" in every spec). Per-measure single
contrasts `b_<m>` use the same vector with all but one measure's columns zeroed
— stored for Task 3.8 and the TIS decomposition, **not** for marginal
interpretation.

`blocks = A` specs carry no Block B → `dis_effect` is NA (they are the
"disadvantage omitted" comparison and a loss reference for Rashomon).

---

## 3. How each axis level is realised

| axis | realisation |
|---|---|
| `blocks` | which of the Block A (11) / B (11, working set) / C (admitted) covariate sets enter |
| `form` | `linear`, or `splines::ns(x, df≈4)` on the 10 continuous Block B disadvantage measures (hhi_zip stays linear); knots fixed from frame quantiles |
| `outcome` | composite = `psi90` (lm); psi03/06/12/13 = that rate, z-scored, `lmer (1\|nest)`; agg = denominator-weighted mean of each component's rate ÷ its national mean (a mean-1 "PSI-90 rebuilt from components without CMS smoothing"), `lmer (1\|nest)` |
| `reliability` | composite: unweighted / `weights = lambda_i` / λ≥0.60 subsample / **eiv** = un-shrink `psi90` as `gm + (psi90 − gm)/lambda_i` then `weights = lambda_i²` (`plan-amendments.md` §1.4c). component/agg: unweighted / denominator-weighted / λ≥0.60 subsample (no eiv — no published per-hospital reliability, registry V3) |
| `grain` | Block B column family (`_catch_tract` / `_catch_county` / `_county` / `_hsa`) and, for component/agg, the random-intercept geography (`hsa` or `county_fips`) |
| `missing` | mi = fit on each of m=20 completed datasets, pool `dis_effect` and every coefficient by Rubin's rules; complete = drop rows missing `contract_labor_share`; omit = drop that covariate from the model; na = Block C not in the model |
| `influential` | all / drop the 77 footnote-23 & -29 hospitals / drop the 130 catchment fallbacks |
| `scale` | `identity`, or `log` outcome (all outcomes strictly positive on the frame — no offset) |

Standardisation (Block A/B/C z-params, component-outcome mean/sd, spline knots,
p10/p90 quantiles) is **computed once on the frozen frame and reused in every
spec**, so a coefficient and the contrast mean the same thing across the whole
curve — the same discipline as Task 3.2's `zpar`.

---

## 4. Runtime estimate — before the full run (the verify condition)

From the 10-spec test, mean seconds per spec by family × missing:

| family × missing | s/spec |
|---|---|
| composite (lm) | 0.03 |
| aggregate (lmer) | 0.11 |
| component, single fit | 0.06 |
| component, mi (×20 fits, pooled) | ~2.4 |

**Extrapolated full-grid (3,496 specs): ≈ 1,600–1,800 s ≈ 27–30 minutes**,
single-threaded, dominated by the ~530 `missing = "mi"` component/aggregate
specs at 20 `lmer` fits each. Comfortably inside Task 3.7's 7 h. `make.R`
stage 24 caches: a `data/spec-results.rds` newer than the registry and the
script is reused rather than refitted.

10-spec test set (`spec_id` 1, 12, 20, 23, 49, 73, 153, 173, 265, 497) spans:
blocks A/AB/ABC, linear/spline, composite/psi03/psi06/psi12/psi13/agg,
unweighted/subsample/eiv, catch-tract/hsa/hosp-county grain, na/mi/omit missing.
All 10 converged, none singular, focal estimate present for all 8 Block-B specs.
Spot values: composite unweighted `dis_effect` +0.071 (SE 0.028); the **same
spec under λ-corrected EIV +0.176** (SE 0.063) — the reliability axis visibly
strengthens the disadvantage estimate, which is exactly the Task 3.7 result to
report separately. Not a finding yet (n = 1 pair); flagged as the thing the
full curve will quantify.

---

## 5. Files

```
R/04-spec-curve.R                       new -- make.R stage 24 (the harness)
make.R                                  stage 24 added
output/models/spec-curve-testrun.rds    10-spec test object (gitignored)
output/tables/task3.6-spec-curve.txt    stage log (gitignored)
```

`make.R --stage 24`: `ok`, provenance `consistent`, 12 s (test mode). Frozen
analytic hash unaffected. Registry unchanged. No `data/` output yet — that is
Task 3.7.

---

## 6. Next

**Task 3.7 — run the specification curve.** `SPEC_CURVE_FULL=1 Rscript make.R
--stage 24` → `data/spec-results.rds` (~30 min), then the spec-curve figure
(`output/figures/spec-curve.png`): `dis_effect` sorted, analytic choices
arrayed beneath, **the full distribution including the inconvenient specs**.
Report (a) the sign-stability of `dis_effect` across the curve as a single
number, and (b) **the reliability axis separately** — if `dis_effect`
strengthens under λ-weighting / EIV across the curve the way it did in the
one test pair, that is direct evidence CMS's smoothing was attenuating the
disadvantage association, and it is a result in its own right.
