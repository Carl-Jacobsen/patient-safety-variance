# Task S1.4 — Replace Marg with finite payment changes

**Date:** 2026-10-02 · **Budget:** 5 h · **Status: done. `Marg` is gone. The
finite return replaces it, and both preregistered tests pass and fail on the
old quantity.** Stage 35 has rerun (B = 16,000, all 79 headline outputs
converged). Two of its results change the payment story: a rank-based rule pays
**nothing** for an across-the-board improvement, and the corrected return
reads differently from `Marg` along disadvantage. The regressivity statement
is not redrawn here. Stages 37–39 still read the old `marg` columns and fail
until S1.6 rewires them.

---

## 1. The defect

`Marg = R × w × 0.039 × k` (`R/09-payment-sim.R`, Sep 30 line 362) never
consulted `rate_of()` or any other hospital's score. It was a revenue scale,
not the payment a hospital earns by improving. Per NPR dollar it is
0.00585 × commercial day share, so its concentration index was the index of
commercial share (Sep 30: −0.033 by ADI, with a zero-width interval, because
nothing in it was simulated).

## 2. The repair

`fin_return(sc, so, pub, R, Pay, Δ)`, called within each draw and scenario:

1. Lower one hospital's published PSI-90 by Δ.
2. Hold every other hospital's score and the draw's scoring reference fixed
   (winsorization bounds, mean and SD, carried in `so$zfun`).
3. Recompute its score and its position among the others (`pos_cf()`,
   average-rank ties, S1.3), then its rate and payment.
4. Divide the payment change by Δ.

Hospitals with no infection measures go through the same line as in
`score_of()`, so their weight on the change is 1.

- **Grid:** Δ = 0.01, 0.025, 0.05 and 0.10, with 0.05 primary (prereg sec 3).
  Every scenario reports Δ = 0.05. The base and fixed runs report the full
  grid, the share of zero returns split by cause (clamped beyond a bound, or
  passes nobody) and per-draw quantiles.
- **All-improve case:** every hospital improves by 0.05 and is rescored from
  the shifted values.
- **Revenue exposure coefficient** `Expo = R × w × 0.039`, in dollars per unit
  of percentile position. It appears only in supplementary columns
  (`ci_expo*`, `exponpr.*` strata, `revenue_exposure` in
  `payment-by-hospital.csv`). The phrase "incentive to improve" appears nowhere
  in the stage, and no comment or output calls this coefficient an incentive.
- **Outputs:**
  - `payment-returns.csv`: base and fixed runs plus the metro base run, by Δ,
    with simulation intervals, plus the all-improve row.
  - `payment-returns-hand.csv`.
  - `payment-by-hospital.csv` gains `ret_d010` to `ret_d100`, `ret_d050_sd`,
    `ret_d050_per_npr` and `share_draws_zero_d050`.
  - `payment-scenarios.csv` swaps the `marg` metrics for `ret`, `retnpr` and
    `expo`.
- **Convergence set:** the `marg` stratum means (deterministic up to quintile
  assignment) leave the headline set. The `ret`, `retnpr` and `exponpr` strata
  and the Δ grid are carried, as Open and Dis already were. The Δ = 0.05
  indices, SN ratios, mean and zero share are headline: 79 outputs, against
  131 on Sep 30. This was fixed before any output was seen.

## 3. Tests (stage 35 sec 4, before any draw; standing rule 3)

**(a) Below the smallest gap.** The test uses the published PSI-90 vector.
Δ = half the smallest gap between adjacent distinct scores, counting only gaps
above 1e-9. The blended score has distinct values differing only in the 17th
digit, and half of such a gap is a Δ that changes no published value at all,
which would make the test vacuous. Every hospital is also checked against a
longhand rank count that does not use `pos_cf()`.

| Rate | Δ | Scores that move | Returns zero | Tie-breakers (match longhand) |
|---|---|---|---|---|
| linear | 1.8e-8 | 2,312 | 2,569 of 2,569 | 0 |
| threshold | 1.8e-8 | 2,312 | 2,569 of 2,569 | 0 |
| linear, PSI-90 only | 5.0e-7 | 2,312 | 2,566 of 2,569 | 3, to 5e-9 cents |

The 257 hospitals whose scores don't move are clamped at a bound. Every
hospital whose step crosses no other score returns exactly 0. The three
PSI-90-only exceptions share their published value exactly with another
hospital, so any improvement breaks the tie, and they gain exactly half the
tie in position. The Sep 30 `Marg` is nonzero for all 2,569 hospitals at any
Δ, so it fails.

**(b) Three named hospitals, longhand, base scenario, Δ = 0.05, published
PSI-90.** All match `fin_return()` to the cent.

| Case | Hospital | PSI-90 | Score → new | Rank → new | Payment change | Return per PSI-90 unit |
|---|---|---|---|---|---|---|
| near the median | 450346 Baptist Beaumont Hospital | 0.9943 | −0.03553 → −0.08709 | 1285 → 1189 | $219,524.70 | $4,390,494.10 |
| upper winsorization bound | 390086 Penn Highlands DuBois | 1.3485 | +0.63747 → +0.58591 | 2198 → 2148 | $124,514.20 | $2,490,284.03 |
| no infection measures | 230301 Surgeons Choice Medical Center | 0.9609 | −0.18549 → −0.52921 | 1018 → 461 | $41,008.81 | $820,176.22 |

How the cases were chosen:

- **Near the median:** an untied infection-scored hospital nearest the median
  score.
- **Upper bound:** the lowest published value at or above the bound
  (q95 = 1.3485). It is clamped now and unclamps at 1.2985, so its score moves
  by the full w · Δ / SD. A hospital clamped deeper returns 0; those are
  counted in sec 4.
- **No infection measures:** nearest the median PSI-90 among those scored on
  PSI-90 alone. Its score moves by Δ / SD, not w · Δ / SD, which is why it
  passes 557 hospitals where the others pass about 50 to 100.

Every intermediate value is in `payment-returns-hand.csv`.

## 4. Results (base scenario, primary set, B = 16,000; mean [95% simulation interval])

| Δ | Mean return per PSI-90 unit | Median hospital | Per NPR dollar | Zero: clamped / passes nobody | CI per NPR: distance | model disadvantage | ADI |
|---|---|---|---|---|---|---|---|
| 0.01 | $1.95M | $0.73M | 0.47% | 9.6% / 2.1% | −0.017 [−0.054, +0.018] | −0.040 [−0.088, −0.001] | −0.060 [−0.076, −0.044] |
| 0.025 | $1.94M | $0.75M | 0.47% | 9.1% / 0.5% | −0.011 [−0.046, +0.024] | −0.040 [−0.087, −0.001] | −0.059 [−0.074, −0.044] |
| **0.05** | **$1.93M** | **$0.75M** | **0.47%** | **8.4% / 0.2%** | **−0.000 [−0.035, +0.034]** | **−0.038 [−0.085, −0.0004]** | **−0.058 [−0.073, −0.044]** |
| 0.10 | $1.90M | $0.74M | 0.45% | 7.4% / 0.1% | +0.022 [−0.012, +0.056] | −0.036 [−0.081, +0.001] | −0.057 [−0.071, −0.042] |

- **Distribution.** At Δ = 0.05 the per-draw 10th, 50th and 90th percentiles
  of the return are $16K, $0.75M and $4.6M per PSI-90 unit, a spread set
  mostly by eligible revenue. 8.6% of hospitals return 0 in a draw, almost all
  because they sit beyond a bound. Which hospitals those are changes from draw
  to draw: only 0.16% return 0 in every draw.
- **Safety-net hospitals** earn 0.62 [0.59, 0.65] of the non-safety-net return
  per NPR dollar, and 1.18× per hospital.
- **All-improve.** Every hospital improves by 0.05 and is rescored. Total
  payment changes by **exactly $0 in every draw**; scores move by at most
  7e-15. Standardizing removes a uniform shift, and ranks don't change. A
  rank-based rule pays for no part of an across-the-board improvement. The
  return above is the private return to improving *relative to the others*.
- **Against Sep 30 `Marg`** (per NPR, base):

  | Ranked by | Sep 30 `Marg` | Finite return |
  |---|---|---|
  | improvement distance | −0.005 [−0.013, +0.004] | −0.000 [−0.035, +0.034] |
  | model-implied disadvantage | −0.014 [−0.037, +0.007] | −0.038 [−0.085, −0.0004] |
  | ADI | −0.033, zero-width | −0.058 [−0.073, −0.044] |

  The corrected quantity is noisier, since it now depends on the draw. It is
  more concentrated away from deprivation by ADI. Against model-implied
  disadvantage, its interval **just excludes zero** (upper end −0.0004). That
  is the preregistered primary ranking, so amendment 9's rule would read
  "structurally regressive" there by a hair. That reading is S1.6's, under the
  rerun with S1.5's curves. It is flagged here, not concluded.
- **Other scenarios** (Δ = 0.05, per NPR):
  - **Threshold:** distance −0.025 [−0.064, +0.013], model disadvantage −0.048
    [−0.100, −0.006], ADI −0.069; 28.8% of hospitals return 0.
  - **CASH2 safety-net factor:** model disadvantage +0.006 [−0.034, +0.037],
    ADI −0.008 [−0.021, +0.004].
  - **PSI-90 only:** ADI −0.020 [−0.030, −0.010].
  - **Fixed reliability:** distance +0.030, model disadvantage −0.017
    [−0.064, +0.021].
  - **Concave and convex:** identical to base to 0.0, because `k` still never
    reaches the rate (S1.5).
- **The exposure coefficient's per-NPR index** by ADI is −0.0333, zero-width:
  exactly the index of commercial day share, as sec 1 says. Under the CASH2
  flat rule (one share for all) it is exactly 0.

## 5. What breaks until S1.6

- Stages 37 (`R/11-regressivity.R`), 38 (fig 8) and 39 read `ci_marg*`,
  `margnpr.*`, `marg.*` and the "marginal incentive" label. They fail until
  S1.6 points them at `ci_retnpr*` / `retnpr.*` at Δ = 0.05.
- Stage 36 reads only pay, open, dis and rate, so it still runs.
- Every report sentence that cites the marginal incentive (secs 1, 4, 8, 9, 10
  and the appendix) is superseded. S5 rewrites them from the S1.6 numbers.
