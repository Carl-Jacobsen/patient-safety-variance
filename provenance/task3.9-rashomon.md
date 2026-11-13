# Task 3.9 — Select the Rashomon tolerance by bootstrap

**Date:** 2026-09-10, metro-area sensitivity added 2026-09-18 · **Budget:** 7 h · **Status: complete.**

One stage (`make.R` 27, `R/05-rashomon.R`) reading the frozen registry, the
frozen analytic file, and the frozen imputation object, and sourcing
`R/04-spec-curve.R` for its helpers only. The task sheet asks for the empirical
risk minimizer, a resample, and the (1 − α) quantile of excess loss, following
the dissertation procedure, with α fixed and stated before the quantile is
computed.

**The answer: ε = 0.001306 in squared PSI-90 units, which is 4.10 percent of the
empirical risk minimizer's loss of 0.031883.** It is the 95th percentile of
1,000 bootstrap excess losses, none of which failed.

---

## 1. α was fixed in a commit of its own

Task 3.9's verify condition is that the tolerance came from the bootstrap rather
than from an analyst's judgment, and that α was fixed before the quantile was
computed. A statement of that inside the same commit as the answer is not
evidence, so `provenance/rashomon-preregistration.md` went in first and alone,
at 11:17:43, the way `data/spec-registry.rds` went in before the first fit at
Task 3.5. It fixes α = 0.05, the loss, the ERM rule, the resampling unit, the
replicate counts, and what happens to a failed replicate. The stage that
produced the number ran afterwards. Two commit timestamps, in that order, are
the evidence.

One amendment was made before the first loss was computed and committed
separately (§3). A second, adding a metro-area resampling sensitivity, was made
after the first results were read and is recorded as post hoc (§6). Nothing
about the primary was revised after a number existed.

## 2. The specification curve's own loss could not be used

`loss_wrmse` from Task 3.7 is computed on whatever rows and whatever outcome
scale each specification was fitted on. The high-reliability subsample arm's is
over 854 hospitals rather than 2,569; the log arm's is in log units; the
errors-in-variables arm's is against an un-shrunk outcome that no other
specification is predicting. Those numbers are not comparable to one another,
and a Rashomon set built on them would be an artifact of bookkeeping rather than
a statement about fit. So every one of the 3,496 specifications was re-fitted
here and scored on a **common evaluation frame**, fixed once per outcome family:
the complete-case Block A + B + C rows with both nestings present, one row per
hospital, the family's outcome on its natural scale, unweighted mean squared
error. On the composite that frame is **n = 2,569**, the same N as Task 3.2 §7
and Task 3.3, which is the check that the frame is the one the rest of Phase 3
has been working on.

Each specification's predictions are mapped back to the target's scale before
they are scored: a log fit is exponentiated, a component fit is un-z-scored with
the same frozen parameters that z-scored it, and an errors-in-variables fit is
re-shrunk by `gm + λᵢ(ŷ − gm)`, the exact inverse of the transform that
un-shrunk it. That last step is not cosmetic. Scored without it, the
errors-in-variables arm posts a loss of 0.0397 against a frame variance of
0.0366 — worse than predicting the mean — and would have been thrown out of the
Rashomon set for predicting a target it was never asked to predict. Scored with
it, the same arm is the empirical risk minimizer.

Losses are comparable within a family and not across families, since the target
differs. Each family therefore has its own ERM and its own tolerance, with the
composite primary per Plan §6 and Task 3.12.

## 3. Amendment 1: predictions are population-level

The pre-registration first said mixed-model predictions would include the fitted
geography random effect. That cannot coexist with the cluster bootstrap, and the
conflict is arithmetic. A cluster bootstrap has to relabel each drawn copy of a
cluster or a cluster drawn twice becomes one cluster of twice the size; once
relabeled, every cluster in a replicate is a label the evaluation frame has
never seen, so a random-effect-inclusive prediction collapses to zero for every
row of it while the original fit keeps its matched effects. Every replicate
would be charged for that difference and ε would come out wide for a reason
having nothing to do with sampling variability. All predictions are therefore
fixed-effects-only, applied identically to the ERM and to every replicate. The
composite is unaffected: it is fitted by ordinary least squares and has no
random effect to include.

## 4. The empirical risk minimizer of each family

| Family | Spec | Loss | R² vs frame variance | Specification |
|---|---|---|---|---|
| **composite** | 418 | 0.031883 | 0.129 | ABC / spline / **EIV** / catchment-county / complete-case / all / identity |
| aggregate | 392 | 0.108775 | 0.103 | ABC / spline / unweighted / catchment-county / complete-case / all / identity |
| PSI-03 | 384 | 0.224484 | 0.083 | as above |
| PSI-06 | 386 | 0.002413 | 0.048 | as above |
| PSI-12 | 388 | 0.479048 | 0.089 | as above |
| PSI-13 | 390 | 1.213313 | 0.039 | as above |

The six minimizers agree on every axis they can agree on: all blocks in, spline
form, catchment-county grain, complete-case, no hospitals dropped, identity
scale, 51 fixed effects. The composite's is the one that differs, and it differs
in the direction Task 3.7 already pointed: **the errors-in-variables treatment,
which un-shrinks CMS's smoothing, is not merely a robustness arm that
strengthens the estimate — it is the specification that fits the data best.**
Task 3.7 found un-shrinking moved the disadvantage estimate up in 91.5 percent
of paired composite cells; Task 3.9 finds the same treatment minimizes the
empirical risk. Two independent reasons to stop treating the published composite
as the thing to model.

Everything about this is in-sample, as the method defines it and as the
pre-registration said it would be. The ERM carries 51 fixed effects against a
minimum of 12 across the composite family, so more parameters do buy a lower
loss. The parameter count is recorded next to every loss in
`data/rashomon-loss.rds`, which is what makes the question answerable at Task
3.10 instead of assumed here. The early sign is that complexity is not doing the
work: the best linear specification sits only 0.83 ε above the ERM, so the 24
extra spline columns buy less than one tolerance.

## 5. The tolerance

| Family | Unit | Role | L(ERM) | ε | ε ÷ L | MC SE ÷ L |
|---|---|---|---|---|---|---|
| composite | hospital | **primary** | 0.031883 | **0.001306** | **4.10%** | 0.089% |
| composite | state | sensitivity (pre-registered) | 0.031883 | 0.002969 | 9.31% | 0.363% |
| composite | metro area | sensitivity (post hoc) | 0.031883 | 0.001627 | 5.10% | 0.101% |
| aggregate | nest | secondary | 0.108775 | 0.003488 | 3.21% | 0.188% |
| PSI-03 | nest | secondary | 0.224484 | 0.007103 | 3.16% | 0.097% |
| PSI-06 | nest | secondary | 0.002413 | 0.000072 | 3.00% | 0.140% |
| PSI-12 | nest | secondary | 0.479048 | 0.014683 | 3.07% | 0.120% |
| PSI-13 | nest | secondary | 1.213313 | 0.047596 | 3.92% | 0.154% |

The primary bootstrap distribution has a median excess loss of +0.000896 and
runs from +0.000410 to +0.002021. None of the 1,000 replicates came out
negative, so the evaluation frame sitting inside the fitting frame did not
produce the artifact the pre-registration allowed for. No replicate failed, in
any family: 4,000 drawn, 4,000 scored. The Monte-Carlo standard error of the
quantile is under a tenth of a percent of L for the primary and under two tenths
for the secondaries at B = 200, so the smaller replicate count for the secondary
families cost very little.

The five secondary families land between 3.0 and 3.9 percent, close enough to
one another and to the composite's 4.1 that the tolerance is a property of these
data and this model class rather than of any one outcome.

## 6. The resampling unit matters more than α, and the metro area is the defensible middle

Resampling states instead of hospitals more than doubles the tolerance, from
4.10 percent to **9.31 percent** of L. The primary stays the primary — it was
pre-registered and it is the unit an ordinary-least-squares model on one row per
hospital treats as exchangeable — but the sensitivity is reported because it is
the larger fact. Task 3.8 found New York alone moves the disadvantage estimate
by 0.13 to 0.26 SD; this is the same finding arriving through the loss.

Neither of those two units is where the dependence in these data was measured
to be. Task 3.1 found 13 percent of PSI-90 variance sitting between metro areas
and 4 percent between states, so hospitals share more with the neighbors in
their market than with hospitals elsewhere in their state. The hospital
bootstrap ignores that sharing altogether. The state bootstrap sweeps it up
together with everything else a state has in common, using only about fifty
clusters, and its quantile is correspondingly noisy (Monte-Carlo SE four times
the primary's). A **metro-area cluster bootstrap** was therefore added after the
first two were read — amendment 2 in the pre-registration, committed before it
was run and labeled post hoc wherever it appears. It resamples the 457 CBSAs
(the two hospitals without one are singleton clusters) at B = 1,000 and gives
**ε = 0.001627, 5.10 percent of L**, with a Monte-Carlo SE of 0.10 percent and
no failed or negative replicates. It sits between the two pre-registered
tolerances and much nearer the primary: allowing hospitals in the same market to
move together widens the tolerance by a quarter, and the further doubling under
state resampling is what the state adds on top, which is mostly coincidental
geography rather than shared dependence.

This is worth saying plainly because of where the argument usually goes. The
Plan calls analyst-chosen tolerance "the weakest link in most applications of
this method" and removes it by bootstrap. That was right, and it is done. But
the bootstrap has its own weak link, and it is not α — it is the unit. Fixing α
in advance bought a defensible number; the unit is where the remaining judgment
lives, and it is now stated with three answers attached rather than buried. The
primary is not being swapped for the metro-area figure: substituting a primary
after seeing results is the move the pre-registration exists to prevent. But a
reader who finds within-market independence doubtful, and it is, should read
every Rashomon result at 5.10 percent as well as 4.10.

## 7. What this hands Task 3.10

`data/rashomon-loss.rds` holds all 3,496 specifications with their common-frame
loss, evaluation N, fitted N, fixed-effect count, and convergence flags. The set
construction and its width are 3.10's work and are not done here. Three flags
go with it.

**The linear and spline arms are both inside the tolerance, at every unit.**
The best linear composite specification is 0.83 ε above the ERM at the primary
tolerance and 0.66 ε at the metro-area one. Task 3.8 predicted this and the
consequence stands: the near-optimal set contains both functional forms, and
Task 3.7 measured the disadvantage estimate at +0.20 SD under linear against
+0.02 SD under spline. The set will be wide on the contrast that matters, and
per Plan §8 that width is a finding.

**Whether a model with no community disadvantage at all is near-optimal depends
on the resampling unit, and two of the three units say it is not.** The best
Block-A-only composite specification sits 2.16 ε above the ERM at the primary
tolerance, 1.74 ε at the metro-area tolerance, and 0.95 ε at the state-cluster
tolerance, which is to say exactly on the boundary. Task 3.12 wants MCR⁻ > 1 for
community disadvantage, and MCR⁻ > 1 requires that no near-optimal model can
ignore it. On the pre-registered tolerance and on the metro-area one that
requirement is met with room to spare. On the state-cluster tolerance it is met
by nothing at all. Task 3.12 must report which tolerance its bound is standing
on, and it cannot report the favorable ones alone.

**The high-reliability subsample is the only reliability level clearly outside.**
Its best specification is 2.55 ε above the ERM (2.05 ε at the metro-area
tolerance), against 0.52 ε for unweighted, 0.68 ε for λ-weighted, and 0.00 for
errors-in-variables. Discarding the
low-reliability hospitals costs more fit than any other single choice on the
composite family.

## 8. Files

```
R/05-rashomon.R                             new -- make.R stage 27
make.R                                      stage 27 added
provenance/rashomon-preregistration.md      alpha and the procedure, committed first (8e901fb, add85e9); amendment 2 (e7f3c65)
data/rashomon-loss.rds                      3,496 specs, common-frame loss (gitignored, regenerable)
data/rashomon-boot.rds                      4,000 bootstrap replicates
data/rashomon-tolerance.rds                 alpha, the tolerance table, the draws, the ERMs
output/tables/rashomon-tolerance.csv        8 rows, one per family x unit
output/tables/rashomon-bootstrap-draws.csv  every replicate's excess loss
output/tables/rashomon-loss.csv             the loss table, readable
output/figures/rashomon-tolerance.png       4 panels
output/tables/task3.9-rashomon.txt          stage log
```

`make.R --stage 27`: `ok`, provenance `consistent`. 30.1 minutes cold — 26.3 of
it re-fitting the 3,496 specifications, the rest the bootstrap — and 4.9 seconds
warm, since the loss table and the draws are cached against the registry and the
harness rather than against this script. `RASHOMON_REFIT=1` forces a re-fit. A run
added to the script later (the metro-area bootstrap was) is drawn on its own and
appended to the cache; the runs already drawn are not redrawn. The
frozen analytic hash is unchanged and nothing upstream was touched. The
provenance table stays at 33 rows.

## 9. Next

**Task 3.10 — construct the Rashomon set at ε = 0.001306 and report its width.**
The verify condition there is that the width is reported before any MCR bound is
computed, so a wide set is a finding rather than a disappointment. §7 says to
expect a wide one.
