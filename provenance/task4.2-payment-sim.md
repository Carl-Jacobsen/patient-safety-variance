# Task 4.2 — Implement the Monte Carlo

**Date:** 2026-09-27 · **Budget:** 8 h · **Status: complete.**

> **Corrections (2026-10-02/03, Tasks S1.3–S1.6; see `taskS1.6-payment-rerun.md`).**
>
> 1. **λ quartile 1 calibration slope.** The 1.29 in sec 2 was a rounding
>    error on analytic-v1: the value was 1.2849, which rounds to 1.28. On
>    analytic-v2 it is 1.2872 (1.29). Either way it is the one C2 miss, and it
>    stays visible.
> 2. **What C2 checks.** C2 is a check of the scoring rule alone. PSI-90 is
>    drawn, while the five HAI scores stay observed and are five-sixths of the
>    score. It is read beside the HAI-only reference (AUC 0.879) and by λ
>    quartile.
> 3. **Sec 3 is withdrawn as an argument.** The U3 spread is generated *by*
>    the scalar-reliability model, as a hypothetical repeated measurement
>    whose expected published value is μ + λ × the current published
>    deviation. It cannot support that model, and it is not year-to-year
>    movement.
> 4. **"Headroom"** is renamed "distance from the best measured score". It
>    ranks measured burden, not preventable harm.
> 5. **`Marg` is replaced.** Every Marg figure in sec 4 is superseded by the
>    finite return (S1.4), and every "neutral" by "no clear direction under
>    the modeled uncertainty".

One stage (`make.R` 35, `R/09-payment-sim.R`, ≈ 7 min warm, plus 1.1 min of
refits cold). It implements `payment-model-inputs.md` and its amendments 1–8.
**Every amendment was committed before the run it governs**: 1–6 before any
draw (`72370ba`, `0551659`), 7 after the gate stopped the first attempt and
before anything past it ran (`38e17df`), 8 after the first full run's
convergence trace and before this run (`b33c1ca`). Amendment 8 is the only one
made after seeing a run output, and it says so.

Fits cached in `data/payment-fits.rds` (`PAYMENT_REFIT=1` forces). Results in
`data/payment-sim.rds` for 4.3 and 4.4.

---

## 1. The order held

1. **C1 gate, first.** The first attempt stopped on 110107 (GA) and 340027
   (NC). Both are tied exactly at the cut (Total HAC Score 0.3792 = q75), and
   CMS penalises only strictly above. Under amendment 7 (Carl): C1a reproduces
   all 3,055 but 440218, which was penalised with no published score. C1b
   (raw PSI-90, the simulation's path) adds 340027, 0.0001 from the cut and
   inside the measured 0.0004 standardisation gap. **Gate passed.**
2. **All 319 refitted specs** (194 primary, 319 metro) reproduce 3.9's stored
   common-frame loss to 0.0e+00. This frame is 3.9's frame.
3. **B = 8,000** by amendments 6 and 8: all 56 headline outputs pass, worst
   non-integer MCSE/SD 0.046. At B = 4,000, 32 of 56 passed.
4. C2, then Q-HIP, from the same draws.

**Reproducibility:** draws 1–25 re-run from their seeds inside the stage are
identical, and a second full run of the stage reproduces all 11 output tables
byte for byte (md5).

## 2. C2 — how well the pipeline reproduces who HACRP penalised

Calibration frame 2,551 (Q-HIP frame ∩ HACRP-scored ∩ not Maryland), 629
observed penalties.

| | Expected | Ratio | Slope | AUC | 90% coverage |
|---|---|---|---|---|---|
| **Main** | **627 [623, 632]** | **0.997** | **1.10** | **0.967** | **0.915** |
| λ quartile 1 (0.11–0.30) | 181 vs 172 | 1.050 | **1.29** | 0.981 | 0.924 |
| λ quartile 2 | 153 vs 152 | 1.005 | 0.97 | 0.978 | 0.920 |
| λ quartile 3 | 153 vs 161 | 0.948 | 0.99 | 0.959 | 0.907 |
| λ quartile 4 | 141 vs 144 | 0.978 | 1.11 | 0.939 | 0.907 |
| C2.6, no re-shrink | 626 | 0.996 | 0.97 | 0.966 | 0.918 |

**Every pre-set check reads good on the main arm.** The one miss is the
calibration slope in the lowest-reliability quartile, 1.29 against a 0.8–1.2
bar. Slope above 1 means p̂ is under-dispersed there: the draws are less
decisive about low-volume hospitals than the outcome turned out to be.
Dropping the re-shrink step moves that slope to 1.10. That is reported, not
adopted. The protocol fixed the re-shrink step, and nothing is changed after
C2.

**What AUC 0.967 means, which it does not mean alone.** C2 predicts only
PSI-90; the five HAI scores stay observed and are five-sixths of the score.
Two post-hoc reference rows, added after the B = 30 smoke run and before this
run and labelled as such, bracket it. **HAI information alone gives AUC 0.879.
Observed PSI-90 gives 1.000. The Phase 3 draws reach 0.967, closing 73% of the
gap.** So the models recover most of what PSI-90 adds to the penalty
assignment, even though they explain 13% of PSI-90's variance. The penalty
turns on rank near the cut, not on the whole distribution.

## 3. Reliability: the 4.1 expectation was wrong

4.1 §3 expected that drawing reliability would widen payment spread **most for
low-volume hospitals.** It does not.

| λ quartile | n | Pay SD, $ | Pay SD / mean | Position SD |
|---|---|---|---|---|
| 1 (0.11–0.30) | 673 | 77,900 | 0.154 | 0.065 |
| 2 (0.32–0.48) | 616 | 139,600 | 0.162 | 0.065 |
| 3 (0.48–0.66) | 642 | 261,400 | 0.174 | 0.073 |
| 4 (0.67–0.96) | 638 | 698,600 | 0.152 | 0.066 |

**Relative spread is flat, about 15–17%, in every quartile.** Programmes pay on
the published value (amendment 2), and CMS's shrinkage has already pulled a
low-λ hospital's published value toward the mean. A fresh measurement moves its
rank about as much as anyone's. **The uncertainty is there. It sits in how far
a low-volume hospital's published value is from its true one, not in how much
its payment moves year to year.**

Where it does show: **fixing PSI-90 at the published value overstates how
well the incentive tracks headroom.** CI(Open | headroom) is +0.187 fixed
against +0.134 [+0.113, +0.155] with reliability drawn. The fixed run ranks
headroom on the same number it scores, so it cannot see the gap.

## 4. Q-HIP — what 4.4 will read (not yet the regressivity statement)

Base scenario, 2,569 hospitals, B = 8,000. **Total bonus $5.84B [5.79, 5.89]
a year**, as a national what-if (§4.3 of the design; dollar levels run low
because day share understates revenue share, amendment 1). Concentration
indices, 95% interval over draws. Negative means dollars concentrate at the
low end of the ranking.

| Ranked by → | Headroom (θ) | Model-implied disadvantage | Catchment ADI |
|---|---|---|---|
| Marginal $ per improvement | **+0.020 [+0.002, +0.039]** | **−0.159 [−0.228, −0.085]** | **−0.203** |
| Unearned band | +0.134 [+0.113, +0.155] | −0.135 [−0.218, −0.050] | −0.186 [−0.190, −0.181] |
| Bonus paid | −0.102 [−0.121, −0.083] | −0.185 [−0.242, −0.119] | −0.222 [−0.227, −0.218] |

Read as arithmetic only:

- **Against headroom, the marginal incentive is close to neutral** (+0.020,
  positive in 98.7% of draws). Hospitals with more room to improve get about
  as much per unit of improvement as anyone.
- **Against disadvantage it is not.** Marginal dollars concentrate in
  less-deprived catchments: −0.203 by ADI, −0.159 by the models' own
  disadvantage ranking, negative in 99.98% of draws. That is Plan §74's
  mechanism running through the commercial share: the incentive per unit of
  improvement is set by commercial revenue, and commercial revenue is thinner
  where catchments are poorer.
- **Bonus paid** runs away from headroom (−0.102) by construction: a
  pay-for-performance bonus pays better performers more.

Scenarios move sizes, not signs:

- **The threshold (S3) is the one that turns the headroom result:** CI(Marg |
  headroom) −0.097 [−0.118, −0.074]. A quarter of hospitals earn nothing at the
  margin, and they are the ones with the most headroom.
- **CASH2's flat 37% / 0.40** narrows the disadvantage gradient (−0.111 by
  model-implied disadvantage) but keeps its sign.
- **The PSI-90-only scorecard** doubles the unearned-band gradient against
  headroom (+0.297).
- **S2's concave and convex shapes** leave every index unchanged to 0.0e+00, as
  4.1 said they would.
- **The metro-tolerance set** (319 specs) gives −0.164 [−0.242, −0.086], the
  same as the primary set.

**Bonus the models associate with catchment:** net +$95M [+29M, +213M], positive
in 99.95% of draws. That is the net of each hospital's bonus against its bonus
with a median catchment. The gross transfer both ways is larger; per-hospital
values are in `payment-by-hospital.csv` for 4.4.

## 5. Checks carried

- CASH2 Track rates reproduced by the linear map: 0.75 / 2.05 / 3.35% against
  0.5 / 2.0 / 3.5%.
- Commercial share: 2,553 of 2,569 from HCRIS S-3, 16 on CASH2's fallback. No
  frame hospital removed for NPR (D4 removes none).
- Every result here is associational. "Associated with catchment" means under
  the drawn model's own contrast, which straddles zero in the Rashomon set
  (3.10). The concentration index on the models' disadvantage ranking holds its
  sign in 99.98% of draws anyway. Why it holds, given that straddle, is for 4.4
  to examine, not something asserted here.

## 6. Outputs

`output/tables/`: `payment-c1-mismatches.csv`, `payment-convergence.csv`,
`hacrp-calibration.csv`, `hacrp-calibration-deciles.csv`,
`payment-scenarios.csv`, `payment-strata.csv`, `payment-by-hospital.csv`,
`payment-reliability.csv`, `payment-frame-exclusions.csv` (empty),
`task4.2-payment-sim.txt`. `data/payment-sim.rds`, `data/payment-fits.rds`
(both gitignored, regenerable).
