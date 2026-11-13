# Task S1.6 — Rerun the payment stages and trace their uncertainty

**Date:** 2026-10-03 · **Budget:** 3.5 h · **Status: done. Stages 35–38 rerun
clean on the S1.3–S1.5 code.** Every simulated payment output now has a row
naming the random inputs that move it and its interval type; the test is an
experiment, not a reading of the code. Amendment 9's rule, applied to the
finite return, leaves **two of the four Sep 30 headline verdicts standing**
(regressive by ADI, lower at safety-net). It turns the third (the primary
ranking) from "neutral" to "structurally regressive" by a margin inside
Monte Carlo error, and renames the fourth. Phase S1 is complete.

---

## 1. What ran

Ran `make.R` stages 35 → 38, detached (stage 35 takes about 32 min: B =
16,000, all 80 headline outputs converged; stage 37 then reran after the
statement edit in sec 4). Results equal the S1.5 run to the last digit, since
the trace draws no random numbers the main run uses. Also changed:

- **Stage 35** (`R/09-payment-sim.R`):
  - `one_draw()` takes `fix`, which replaces named random inputs after they
    are drawn. It uses exact `[[ ]]` lookups, because `fix$z` partially
    matched `zero_coef`, a bug caught in the first trace test.
  - New sec 7b, the trace (sec 2).
  - The U3 score draw is described as what it is (sec 3).
  - C2 is annotated as a check of the scoring rule alone.
  - `hd_q` is relabeled as distance from the best measured score.
- **Stage 37** (`R/11-regressivity.R`), rewired from `Marg` to the finite
  return:
  - "headroom" becomes "distance from the best measured score";
  - the new verdict vocabulary (sec 4);
  - every scenario, with S1.5's labels;
  - the revenue exposure coefficient as supplementary rows;
  - `payment-uncertainty-trace.csv`.

  Its verify now also fails on "neutral" or "headroom" anywhere in the
  statement.
- **Stage 38** (fig 8) reads the new quantity and labels.
- **Stage 39** (`R/13-report-numbers.R`) sec 08 is rewired to the new tables.
  The Sep 30 payment verdicts became recorded claims, as the TIS claims did in
  S1.2. It now runs to the end and lists every stale number and six dead
  claims (three TIS, three payment), as expected until S5.

## 2. The uncertainty trace

**Method.** I took 20 reference draws. For each, I re-drew **one** input
group from another seed while holding the rest, and recorded which outputs
changed (relative tolerance 1e-9). The four groups:

- **specification:** two specs compared at their estimated coefficients. The
  score and residual inputs are held explicitly, because a spec with a
  different coefficient count shifts the random stream. The first trace run
  showed that shift as a spurious "payment moved by specification".
- **coefficients:** the β noise and the imputation completion;
- **published score:** U3, θ and the fresh measurement;
- **C2 residual:** U4.

881 output columns fall into 426 families. Stage 35 stops unless five design
expectations hold:

| Output | Specification | Coefficients | Published score | C2 residual | Interval |
|---|---|---|---|---|---|
| payment (total, per hospital, by stratum other than model quintiles) | – | – | ✓ | – | simulation, score draw only |
| finite return (mean, per hospital, indices along distance and ADI, SN ratio) | – | – | ✓ | – | simulation, score draw only |
| finite return index along model-implied disadvantage; anything by model quintile | ✓ | ✓ | ✓ | – | simulation, all three model and score draws |
| disadvantage-associated payment (total, per hospital, by stratum) | ✓ | ✓ | ✓ | – | simulation, all three |
| revenue exposure, per NPR, along ADI | – | – | – | – | **zero-width: no modeled variation** |
| revenue exposure, per NPR, along model-implied disadvantage | ✓ | ✓ | – | – | simulation (the ranking moves, the quantity does not) |
| all-improve payment change; rescaled-total gap | – | – | – | – | zero-width (exactly $0) |
| fixed-reliability run, along distance or ADI | – | – | – | – | zero-width |
| HACRP check (C2) expected count | ✓ | ✓ | – | ✓ | simulation; the score draw never enters |

Eleven rows cover intervals that are not simulation intervals over the
stage 35 draws:

| What | Interval type |
|---|---|
| Stage 36 within-draw contrasts | simulation interval of the contrast |
| Gap decomposition | point estimate, no interval |
| Per-hospital means | mean and SD over draws |
| Reliability spread | U3 spread, not evidence for scalar reliability |
| C2 slope, AUC and coverage | point values, no interval |
| C2 reference rows | deterministic |
| Observed HACRP shares | Wilson interval |
| Observed HACRP rate ratios | normal approximation on the log ratio |
| Observed HACRP concentration indices | hospital bootstrap, 2,000 resamples |
| Statement item 5 | descriptive |

**Coverage check (verify).** All 494 metrics in `payment-scenarios.csv` and
`payment-returns.csv` map to a traced column. Stage 37 stops if any does not.

## 3. The score draw, reliability and the HACRP check

- **U3 is a hypothetical repeated measurement under the normal model.** It
  draws θ ~ N(published, v), measures θ again, and re-shrinks the result. The
  expected published value is μ + λ × (the current published deviation): the
  published value shrunk once more. That is neither the current published
  value nor next year's. Its spread is generated by the scalar-reliability
  model, so it is no evidence for that model. Two places used it that way, and
  both are withdrawn:
  - the 4.2 note's sec 3, "the uncertainty … is not in how much its payment
    moves year to year";
  - the "reliability" heading in stage 35, which is relabeled with that
    caveat.
- **The HACRP check (C2) checks the scoring rule alone.** Only PSI-90 is
  drawn; the five HAI scores stay observed and make up five-sixths of the
  score.

  | | Expected vs observed | Ratio | Slope | AUC |
  |---|---|---|---|---|
  | main arm | 627 vs 629 | 0.997 | 1.094 | 0.967 |
  | HAI information alone | | | | **0.879** |
  | ceiling (observed PSI-90) | | | | 0.9997 |

  By λ quartile the slopes are **1.287**, 0.963, 0.985 and 1.110. The lowest
  quartile is the one miss against the 0.8–1.2 bar, and it stays visible.
  - **On 1.28 versus 1.29:** on analytic-v1 the slope was 1.2849, so the 4.2
    note's "1.29" was a rounding error. On analytic-v2 it is 1.2872, which is
    1.29. The note now carries a correction banner, and the report should
    cite 1.287.
- **"Headroom" is renamed "distance from the best measured score"** in every
  stage 37/38 output and the statement. It ranks measured burden, not
  preventable harm. The internal column ids (`hd_q`, `*_head`) are unchanged.

## 4. The statement (`regressivity-statement.txt`)

Ten numbered items, generated from the numbers.

- **Intervals that cross zero** read "shows no clear direction under the
  modeled uncertainty".
- **Zero-width intervals** read as "no modeled variation … not certainty".
  The exposure coefficient's ADI index (−0.033), item 9, is described this
  way.
- **Fragile verdicts.** Where a verdict's deciding endpoint lies within two
  Monte Carlo standard errors of zero (amendment 6's endpoint MCSE), the
  statement says the verdict follows the preregistered rule but is not robust
  to simulation error.
- **The threshold rule** is "a hypothetical stress test".
- **New item 6, the all-improve result:** $0, because a rank-based rule pays
  for improvement relative to others, not for improvement as such.
- **Item 5** now names both levers of the per-revenue-dollar return:
  commercial share, and how many hospitals a 0.05 improvement passes.
- **Scenarios that change a verdict.** Every scenario that changes a verdict
  on the two primary axes is named, 11 in all. Rescaled curves share their
  unscaled indices.

## 5. Amendment 9's rule on the finite return; the Sep 30 verdicts

Base scenario, per NPR dollar unless stated. Sep 30 is the marginal incentive
on analytic-v1; "now" is the finite return at Δ = 0.05 on analytic-v2.

| Sep 30 verdict | Sep 30 | Now | Survives? |
|---|---|---|---|
| no direction against headroom ("neutral") | −0.005 [−0.013, +0.004] | −0.000 [−0.035, +0.034], no clear direction | **Yes in substance.** The word "neutral" and the name "headroom" go. |
| neutral against model-implied disadvantage (primary ranking) | −0.014 [−0.037, +0.007] | **−0.038 [−0.085, −0.0004], structurally regressive** | **No: it reverses.** But the deciding endpoint lies within 1.0 Monte Carlo SE (0.0004) of zero, and 97.6% of draws are negative against the 97.5% the rule needs. Of the 13 other scenarios, 8 make it no clear direction, including w = 0.10, the concave curve, both CASH2 revenue rules, PSI-90 only, ρ = 2.0 and fixed reliability. Five keep it regressive: w = 0.20, both convex runs, threshold and ρ = 1.5. The honest reading is *on the edge*, and the statement says so. |
| regressive by ADI | −0.033, zero-width | **−0.058 [−0.073, −0.044]** | **Yes, and stronger.** It now carries modeled variation (the score draw), where the Sep 30 interval had none. |
| lower at safety-net hospitals | 0.77×, zero-width | **0.62 [0.59, 0.65]** | **Yes, and stronger:** 38% less per revenue dollar, against 23%. |

Other verdicts:

- **Threshold.** The Sep 30 result, regressive against headroom (−0.076), does
  **not** survive: −0.025 [−0.064, +0.013], no clear direction. It stays
  regressive by the models' ranking (−0.048 [−0.100, −0.006]) and by ADI.
- **CASH2 0.40 safety-net factor.** All three Sep 30 per-NPR verdicts
  (regressive by headroom, progressive by the models and by ADI) become no
  clear direction.
- **Per hospital.** Model ranking −0.172 [−0.240, −0.099], against −0.159;
  ADI −0.215, against −0.203; safety-net 1.18×, against 1.25×, now with an
  interval. Against distance, the per-hospital index loses its Sep 30
  "progressive" (+0.020 [+0.002, +0.039] → [−0.005, +0.046]).
- **Per revenue dollar by ADI fifth.** The most deprived fifth earns 39.2 basis
  points of revenue per PSI-90 unit and the least deprived 47.6. These are not
  comparable with the Sep 30 15.9 and 13.9, which were per 100% relative
  improvement under `Marg`.
- **Observed FY 2026 HACRP** (unchanged by the repairs):
  - ADI Q5/Q1 is 1.39 [1.14, 1.71];
  - model ranking Q5/Q1 is 1.65 [1.35, 2.02], against 1.63 on Sep 30 (the
    v2 model draws);
  - safety-net is 1.14 [0.98, 1.33], an interval that includes parity.

## 6. Not done here

- Report prose (secs 1, 4, 8, 9, 10, appendix) is S5's. Stage 39 lists every
  stale number and the three dead payment claims.
- **The fragile primary verdict is a reporting decision for S5.** The
  preregistered rule reads "structurally regressive", the simulation cannot
  tell its endpoint from zero, and most scenarios read no clear direction. My
  suggestion: report it as on the edge, with all three facts, and do not lead
  with the word "regressive".
