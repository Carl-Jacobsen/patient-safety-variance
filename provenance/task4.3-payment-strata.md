# Task 4.3 — Distributional results by stratum

**Date:** 2026-09-27 · **Budget:** 4 h · **Status: complete.**

> **Superseded in part (2026-10-02, Task S1.3).** The catchment-associated amounts in sec 3
> (+$167K in ADI quintile 1 to −$29K in quintile 5, and the model-ranking +$227K to −$69K)
> came from a counterfactual rank with the wrong tie convention (`pos_cf()`). They stand
> superseded until Task S1.6 regenerates them. The ties alone move them by at most $1.53 a
> hospital (`provenance/taskS1.3-ties.md` sec 4).

One stage (`make.R` 36, `R/10-payment-strata.R`, 3 s). It reads
`data/payment-sim.rds` from 4.2 and makes no draws. Base scenario, B = 8,000.
Every between-stratum contrast is computed within each draw, so its interval
is its own.

**The stratification follows 3.16's verdict:** a gradient, not strata. No
result is labelled Track 1, 2 or 3, and the script asserts that. The strata are
the ones 4.1 §7 fixed:

- the safety-net flag;
- catchment ADI quintiles;
- quintiles of the models' own disadvantage contribution, recomputed per draw;
- 3.16's nine star × margin cells, labelled as cells on a gradient.

---

## 1. The result

**The bonus rate barely moves along the disadvantage gradient. The bonus
dollars move a lot.**

| | Bonus rate, % | Bonus per hospital, $M | Share of all bonus $ | Share of hospitals |
|---|---|---|---|---|
| ADI quintile 1 (least deprived) | 2.05 [2.03, 2.08] | 3.33 [3.27, 3.39] | 29.3% | 20% |
| ADI quintile 5 (most deprived) | 1.93 [1.90, 1.95] | 0.85 [0.83, 0.86] | **7.4%** | 20% |
| Model-implied quintile 1 (least) | 2.08 [1.99, 2.19] | 3.11 [2.54, 3.55] | 27.3% | 20% |
| Model-implied quintile 5 (most) | 1.89 [1.80, 1.98] | 1.08 [0.80, 1.45] | 9.5% | 20% |
| Not safety-net | 2.06 [2.05, 2.07] | 2.24 [2.22, 2.26] | 74.4% | 75.4% |
| Safety-net | 2.02 [2.00, 2.04] | 2.37 [2.32, 2.41] | 25.6% | 24.6% |

Within-draw contrasts, most minus least deprived:

- **ADI:** bonus rate −0.13 points [−0.16, −0.09]; bonus −$2.48M a hospital
  [−2.55, −2.42].
- **Model-implied:** bonus rate −0.19 points [−0.36, −0.04]; bonus −$2.03M
  [−2.68, −1.30].
- **The metro-tolerance model set** gives the same to two decimals.

**Where the dollar gap comes from** (log ratio of mean bonus, ADI quintile 5
to 1, = −1.37, a factor of four):

- **about 75% is hospital size.** Net patient revenue averages $219M in
  quintile 5 against $612M in quintile 1.
- **about 17% is commercial share** (0.238 against 0.272).
- **about 8% is performance position.**

So the incentive reaches deprived catchments thinly mostly because the
hospitals serving them are smaller, and only secondarily because their payer
mix is less commercial. **Carry to 4.4:** the concentration indices in 4.2 are
per-hospital dollars, and they fold size in. 4.4 has to say whether
regressivity is judged per hospital or per dollar of revenue. The two answers
differ, and the design (4.1 §7) does not choose between them.

**Safety-net status is not where the gradient shows.** Safety-net hospitals are
larger on average (NPR $597M against $399M), so their lower commercial share
(0.212 against 0.274) nets out. They take 25.6% of the dollars for 24.6% of
the hospitals. The flag and the catchment measures are not the same axis.

## 2. The 3.16 cells

Bonus rate follows star band, as it must: the score is built from
safety measures that stars also draw on. 1–2 star / thin margin earns
1.41% [1.38, 1.44] of eligible revenue, against 2.46% [2.44, 2.49] for 4–5 star /
comfortable. That is 4.4% of the dollars for 11.1% of the hospitals, against
24.4% for 15.5%.

- **Along the gradient:** star band at middle margin moves the rate −0.57
  points, and margin at 3 stars −0.28.
- **The corner contrast:** −1.05 points [−1.09, −1.01] and −$2.68M a hospital.

**This is a gradient read of a pay-for-performance rule, not a finding about
archetypes.** Worse-rated hospitals are paid less by design. What 4.4 asks is
whether the dollars available for improving track room to improve.

**The unrated 139 earn 2.36% [2.24, 2.49], near the top.** They are small and
low-λ (3.16 §5), and CMS shrinkage pulls their PSI-90 toward the mean, which is
a good rank position. Their dollars are small
($0.59M a hospital), but the rate is a shrinkage effect worth a sentence in §8.

## 3. Bonus associated with catchment

Each hospital's bonus is compared with its bonus under a median catchment
contribution, per 4.2. *[Superseded until S1.6; see the banner above.]* It runs from +$167K a hospital [+51, +343] in ADI
quintile 1 to −$29K [−47, −13] in quintile 5. By the models' own ranking it
runs from +$227K to −$69K. **Under these models, a hospital in a less-deprived
catchment is associated with more bonus than its performance net of catchment
would earn, and one in a more-deprived catchment with less.** This is
associational, and conditional on models whose disadvantage contrast straddles
zero across the Rashomon set (3.10). The payment rule turns it into dollars
with a consistent sign.

## 4. Reliability

The fixed-PSI-90 run gives the same picture: rates within 0.1 points, the ADI
contrast −0.15 against −0.13. Drawing reliability widens intervals and slightly
narrows the cell gradient. The corner is −1.15 fixed against −1.05 drawn,
because a hospital's published value regresses on re-measurement. Nothing
changes sign.

## 5. Outputs

- `output/tables/payment-by-stratum.csv` (per stratum: rate, dollars,
  unearned band, share of dollars and of hospitals, catchment-associated
  bonus, and the fixed-reliability rate);
- `output/tables/payment-stratum-contrasts.csv` (within-draw contrasts, for
  the primary and metro sets, with and without reliability drawn);
- `output/figures/payment-by-stratum.png`;
- `output/tables/task4.3-payment-strata.txt`.
