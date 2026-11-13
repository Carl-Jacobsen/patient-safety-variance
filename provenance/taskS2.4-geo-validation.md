# Task S2.4 — Validate reduced datasets on held-out geography

**Date:** 2026-10-03 · **Budget:** 4.5 h · **Status: done. Stage 40, post-review,
run as pre-registered (second-pass-preregistration.md sec 6).** The community
measures earn their place out of sample. Dropping Block B raises the held-out
loss in unseen states by 2.2%, outside the 1% tolerance in every repeat. The
SVI themes plus the limited-English share come within tolerance of the full
block (+0.37%). ADI alone does not (+1.30%). All of this sits on a small base:
the best model explains 4.0% of the variation in published PSI-90 in states it
has not seen, against 11.0% in sample.

---

## 1. What ran

`R/14-geo-validation.R`, registered in `make.R` as stage 40 and listed before
stage 39 so the registry reads a fresh table. It runs in about 15 s, and a
second run reproduces both output tables byte for byte.

- **Candidates.** P-best's settings (spec 382: composite, spline, unweighted,
  catch_county, complete-case, identity) with its Block A and Block C terms;
  only Block B varies. (a) no Block B; (b) all eleven Block B terms, as in
  P-best; (c) ADI only; (d) SVI themes 1–4 and the limited-English share. (e),
  the S1.2 essential set, is empty, because S1.2 tagged no measure essential.
  It therefore coincides with (a) and is recorded, not fitted twice. An
  intercept-only fit is reported as a reference.
- **Frame.** The 2,569 hospitals complete on (b)'s terms, the same hospitals as
  spec 382's stored fit and evaluation frame. Every candidate is nested in (b),
  so all are fitted and scored on identical hospitals.
- **Folds.** New-area: the 51 state codes partitioned at random into five
  groups, 20 repeats (seed 20261001 + r). Held-out folds run from 267 to 976
  hospitals, because states differ in size. Within-area: five random hospital
  folds, 20 repeats (seed 20261001 + 1000 + r).
- **Inside each training fold:** means, SDs and spline knots (quantiles
  .25/.50/.75, boundary .05/.95, as in the harness) come from training
  hospitals only. P-best is complete-case, so no imputation step exists to move
  inside the fold.
- **Loss:** MSE of published PSI-90 over a repeat's held-out predictions, so
  each hospital is predicted once per repeat. Differences are taken from (b)
  within each repeat and summarized by their mean and 2.5th–97.5th percentiles
  over the 20 repeats.

**Outputs.** `output/tables/geo-validation.csv` (one row per design × model),
`output/tables/geo-validation-repeats.csv` (per repeat), and
`output/tables/taskS2.4-geo-validation.txt`. Stage 39 registers 157 numbers from
the table in sections 06, 01 and 10 (keys `gv <design> <model> …`).

## 2. Checks before any fold ran

1. **The builder reproduces P-best.** Stage 40 builds its own design matrix so
   it can take knots and standardization from training rows. Given the
   frame-wide parameters the harness uses, it reproduces spec 382 exactly: 51
   columns (stored n_fe 51), loss 0.032559462792 against the stored value,
   relative difference 0. That needed the harness's eight-significant-figure
   rounding of the knots.
2. **Leakage.** On every fold of the first repeat of both designs, for all four
   candidates (40 fits), permuting the held-out outcomes changed no training
   fit; coefficients and parameters were `identical()`. The test as written
   would also pass a fitter that took its knots from all rows, since a
   permutation leaves every quantile unchanged. So the stage adds a stronger
   perturbation: held-out outcomes and covariates replaced with noise. That
   also changes nothing for the fold fitter, and it changes all 40 fits from a
   deliberately leaky fitter that takes its parameters from every row. The test
   can therefore catch the failure it exists for.

## 3. Results

Held-out loss relative to (b), mean over 20 repeats [2.5th, 97.5th]:

| Model | New-area loss | Held-out R² | vs (b) | Repeats within 1% | Within tolerance |
|---|---|---|---|---|---|
| (a) no Block B | 0.035972 | 1.9% | +2.17% [+0.98%, +3.10%] | 5% | no |
| (b) all of Block B | 0.035208 | 4.0% | — | — | reference |
| (c) ADI only | 0.035664 | 2.8% | +1.30% [+0.11%, +2.25%] | 30% | no |
| (d) SVI 1–4 + limited English | 0.035337 | 3.7% | +0.37% [−0.98%, +1.34%] | 90% | **yes** |
| intercept only | 0.036678 | 0.0% | +4.18% [+2.22%, +5.47%] | — | — |

| Model | Within-area loss | Held-out R² | vs (b) | Repeats within 1% |
|---|---|---|---|---|
| (a) no Block B | 0.035077 | 4.2% | +2.84% [+2.27%, +3.45%] | 0% |
| (b) all of Block B | 0.034109 | 6.8% | — | — |
| (c) ADI only | 0.034658 | 5.3% | +1.61% [+1.09%, +2.10%] | 0% |
| (d) SVI 1–4 + limited English | 0.034276 | 6.4% | +0.49% [+0.09%, +0.80%] | 100% |
| intercept only | 0.036601 | 0.0% | +7.31% [+6.47%, +8.19%] | — |

Share of Block B's held-out gain over (a) that each reduced dataset keeps,
(loss_a − loss_m)/(loss_a − loss_b) per repeat:

| | ADI only | SVI 1–4 + limited English |
|---|---|---|
| New-area | 38% [−43%, 89%] | 89% [42%, 192%] |
| Within-area | 44% [33%, 53%] | 83% [73%, 97%] |

The new-area ratios are wide because their denominator, Block B's gain in a
single repeat, is small and varies with which states are held out. The
within-area ratios are the steadier read.

## 4. Reading

- **Community measures predict out of sample.** Without Block B, held-out loss
  rises 2.17% in unseen states and 2.84% in seen ones, and in both designs the
  full block beats structure alone in every repeat. This is the held-out
  evidence the review asked for in place of "every credible model relies on
  it". It concerns prediction for new hospitals, not reliance among fitted
  members.
- **The reduced SVI dataset passes the pre-registered test; ADI alone fails
  it.** (d) is within 1% of (b) on mean new-area loss and in 90% of repeats.
  Within areas it is slightly but consistently worse (2.5th–97.5th
  percentiles +0.09% to +0.80%, all 20 repeats inside the tolerance). ADI alone keeps under half of
  the block's gain in both designs and fails the tolerance on its mean.
- **The practical recommendation partly survives, on new evidence.** The Sep 30
  recommendation, the SVI file with its themes kept separate over ADI alone,
  was argued from the TIS tags, which S1.2 showed do not hold. Stage 40 gives
  that recommendation an independent basis: a model built on one public file
  (the SVI themes and its limited-English share) predicts held-out PSI-90 within
  the pre-registered 1% of the full eleven-measure block. Going from (d) to (b)
  adds six measures from four further sources (ADI from the Neighborhood
  Atlas, ICE and uninsured share from the ACS, RUCC rurality, AHRF physician
  density, and HSAF market concentration) for under half a percent of
  held-out loss.
- **The base is small.** Held-out R² for the best model is 4.0% in new states
  and 6.8% in seen ones, against 11.0% in sample. The candidates differ by
  about one to two points of held-out R². A data-prioritization statement
  should carry both numbers: the reduced dataset loses little of what the full
  block predicts, and the full block predicts little.

## 5. Limits

- **One anchor.** Every candidate takes P-best's settings, including catchment
  weighting at county grain. S2.6 takes up the grain question; the result here
  is not shown to hold at tract grain.
- **Outcome.** The outcome is the published score, unweighted (S2.1); no λ
  analysis enters.
- **Frame.** It is the complete-case 2,569. The 232 hospitals outside it are not
  represented.
- **Tolerance.** The 1% bar was fixed before the run (pre-registration sec 6).
  It is a practical threshold, not an equivalence test with a stated error
  rate. (d)'s new-area interval reaches +1.34%, and S5 should say so beside the
  verdict.
- **Folds.** State partitions are unequal in size, so a repeat's loss weights
  large states more. That is the target (loss over hospitals) but makes repeats
  vary.

## 6. Verify

- **Leakage test.** Permuting held-out outcomes changes no training fit (0 of
  40). The stronger noise test also changes none, while a leaky fitter is caught
  in 40 of 40. Spec 382 is reproduced exactly before any fold runs.
- **New-area and within-area results reported separately.** Two tables, with the
  tolerance applied to new-area loss only, as pre-registered.
- **Labeled post-review.** In the stage name, the script header and this note.
