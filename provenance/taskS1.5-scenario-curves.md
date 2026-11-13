# Task S1.5 — Give the payment scenarios real curves

**Date:** 2026-10-02 · **Budget:** 2 h · **Status: done. The rate curves live
in `rate_of()`, so payment, the finite return and the counterfactual all use
the scenario's curve.** Both preregistered tests pass and both fail on the Sep
30 code. Stage 35 has rerun (B = 16,000, all 80 headline outputs converged).
The curve shape now moves the concentration of returns, and in the convex
direction it moves it materially.

---

## 1. The defect

The Sep 30 `rate_of(P, thr)` took no `k`. The concave and convex scenarios
differed from base only in `Marg`, which multiplied by `k`. Their payments,
counterfactuals and every index were identical to base, and stage 35 reported
that as "S2 shapes change nothing (0.0e+00)". It was a no-op, not a finding.

## 2. The repair

- **`rate_of(P, sc)`.** r(P) = 0.001 + 0.039 P^k, with k = 0.5 (concave),
  1 (base) and 2 (convex), all sharing the linear base's endpoints of 0.1% and
  4.0% (prereg sec 4). The threshold rule keeps its arithmetic. `sc$c`, when
  set, multiplies the rate. Every caller passes the scenario: payment,
  `fin_return()`, the counterfactual, the all-improve case and the S1.3/S1.4
  tests.
- **Rescaled curves.** `concave_rs` and `convex_rs` take a per-draw factor
  c = (base total) / (curve total). The factor is computed from the base
  scenario in the same draw; base runs first, which is asserted. Because it
  travels inside `sc`, the return and counterfactual are rescaled too.
- **Revenue scenarios** `rev_rho15` and `rev_rho20`: commercial revenue share
  ρs / (ρs + 1 − s), where s is the HCRIS day share. Median s is 0.237; the
  revenue share is 0.318 at ρ = 1.5 and 0.383 at ρ = 2.0. Eligible revenue
  rises from $303.3B to $396.9B and $470.6B. The 16 CASH2-fallback hospitals
  keep their share, since it is already a revenue share. These replace the
  Sep 30 claim that every dollar level runs low: the dollar level now moves
  with ρ.
- **Threshold relabeled** "threshold — hypothetical stress test" in every
  output (`SCEN_LABEL`, the new `label` column of `payment-scenarios.csv`,
  the stage log). The reason is in `payment-model-inputs.md` amendment 10:
  - CASH2's "75% earn a bonus" is a participation statistic, not a rule that
    excludes the worst quarter.
  - Elevance describes rewards for meeting targets plus credit for
    year-over-year improvement.
- **Follow-up.** An improvement-credit rule needs a second reporting window.
  It is follow-up 1 in the new `provenance/follow-ups.md`.
- **New output** `pay_gap_to_base` for every scenario (0 for base). Base's
  constant joins the headline set, which is now 80, and is exempt from the
  convergence rule as zero-variance.

## 3. Tests (stage 35 sec 4, before any draw)

**(a) `k` changes the rate and nothing else.** On the published PSI-90, with
a counterfactual 0.02 lower, `qhip(..., pieces = TRUE)` returns these pieces
identically for k = 1, 0.5 and 2:

- score;
- position;
- counterfactual position;
- the finite return's position;
- the exposure coefficient.

The rate differs. The Sep 30 `Marg` totals $1,774M, $887M and $3,549M across
the three values of `k`. It changed with `k`, so it fails.

**(b) Endpoints, totals, rescaling.** All three curves run 0.001 to 0.040.
On the published vector, total payment is:

| Curve | Total |
|---|---|
| linear | $5,762.0M |
| concave | $7,973.6M |
| convex | $3,560.8M |

Rescaled, concave and convex match linear to the dollar, with a gap of
−$0.0000. Over all 16,000 draws:

- rescaled totals match base to within **$0.0000**;
- common-endpoint totals differ from base by at least **$2,178M**;
- the shape scenarios' distance index differs from base by up to 0.077,
  against 0.0 on Sep 30.

## 4. Results (primary set, B = 16,000; finite return per NPR dollar at Δ = 0.05, mean [95% simulation interval])

| Scenario | Total paid | Distance from best score | Model-implied disadvantage | ADI |
|---|---|---|---|---|
| base (linear) | $5,840M | −0.000 [−0.035, +0.034] | −0.038 [−0.085, −0.0004] | −0.058 [−0.073, −0.044] |
| concave, common endpoints | $8,043M | +0.033 [−0.001, +0.067] | −0.025 [−0.068, +0.011] | −0.044 [−0.059, −0.029] |
| convex, common endpoints | $3,625M | **−0.048 [−0.086, −0.009]** | **−0.048 [−0.102, −0.005]** | −0.068 [−0.086, −0.049] |
| concave, rescaled | $5,840M | same as concave | same | same |
| convex, rescaled | $5,840M | same as convex | same | same |
| threshold, hypothetical stress test | $4,053M | −0.025 [−0.064, +0.013] | −0.048 [−0.100, −0.006] | −0.069 [−0.088, −0.049] |
| revenue, ρ = 1.5 | $7,636M | +0.001 [−0.031, +0.033] | −0.036 [−0.079, −0.000] | −0.053 [−0.067, −0.039] |
| revenue, ρ = 2.0 | $9,047M | +0.001 [−0.029, +0.031] | −0.033 [−0.075, +0.000] | −0.049 [−0.062, −0.035] |

- **Shape moves the concentration.** A convex curve concentrates the return
  where distance from the best score and disadvantage are *low*: both
  intervals exclude zero. A concave curve leans the other way, and its
  distance interval only just reaches zero. The ADI index is negative under
  every curve.
- **Rescaling changes totals and dollars, not indices.** A concentration index
  is scale-invariant, so the rescaled rows repeat the common-endpoint indices
  exactly. What rescaling changes is dollars. The catchment-associated total
  is $53.2M concave and $151.9M convex, against $95.8M base at the same total
  payment. The mean return is $1.10M and $3.07M per PSI-90 unit, against
  $1.93M.
- **Revenue scenarios** raise the dollar level by 31% and 55%. They barely
  move the indices, so the per-NPR picture does not hinge on the day-share
  proxy.
- **Flagged for S1.6, not concluded.** On the preregistered primary ranking
  (model-implied disadvantage), whether the per-NPR return's interval excludes
  zero now varies across scenarios:
  - **clearly excludes zero:** convex and threshold;
  - **by a hair:** base (−0.0004) and ρ = 1.5;
  - **does not:** concave, and ρ = 2.0 (+0.000).

  Amendment 9's statement is regenerated in S1.6 and will have to carry that
  fragility.

## 5. Notes

- `tools/s1.3-tie-count.R` replays draws against the Sep 30 scenario list. It
  is a one-off whose results are cached in `data/tie-count-*.rds`, and it is
  not expected to run against the new stage.
- Stages 37–39 still read the old `marg` columns (S1.4 sec 5). S1.6 rewires
  them and adds the new scenarios and labels.
