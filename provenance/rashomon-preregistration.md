# Rashomon tolerance — pre-registration

**Date:** 2026-09-10 · **Task:** 3.9 · **Status: fixed before the first loss was
computed.**

Task 3.9's verify condition is that the tolerance came from the bootstrap rather
than from an analyst's judgment, and that α was fixed before the quantile was
computed. A statement inside the same commit as the answer is not evidence of
that, so this file goes in first and on its own, the way `data/spec-registry.rds`
went in before the first fit at Task 3.5. Its commit timestamp is the evidence.
Nothing below was chosen after seeing a loss, an excess loss, or a tolerance.

---

## 1. α

**α = 0.05.** The tolerance is the 95th percentile of the bootstrap
excess-loss distribution. No other α will be computed, reported, or substituted,
and the 0.05 is not a sensitivity axis.

## 2. The loss

The Rashomon set is defined by a loss, so the loss has to mean the same thing in
every specification that competes for a place in it. The specification curve's
own `loss_wrmse` does not: it is computed on whatever rows and whatever outcome
scale each specification was fitted on, so a subsample specification's loss is
over fewer hospitals, a log specification's is in log units, and an
errors-in-variables specification's is against an un-shrunk outcome that no
other specification is fitting. Those numbers are not comparable and will not be
used here.

The loss for the Rashomon work is instead computed on a **common evaluation
frame**, fixed once per outcome family:

- **Rows.** The complete-case Block A + B + C frame — every hospital finite on
  all eleven Block A covariates, all eleven Block B measures at all four grains,
  all four Block C covariates including observed contract labour share, with a
  non-missing HSA and county — intersected with the rows where that family's
  outcome and its weight denominator exist. One row per hospital. The row set
  does not depend on the specification, so every specification in a family is
  scored on identical hospitals.
- **Target.** The family's outcome on its natural scale: published PSI-90 for
  the composite, the denominator-weighted component aggregate for the aggregate
  family, the published rate for each component family.
- **Loss.** Unweighted mean squared error against that target. Unweighted
  because a weighted loss would privilege whichever reliability arm supplied the
  weights.
- **Predictions are mapped back to the target's scale before they are scored.**
  A log-scale fit is exponentiated. A component fit is un-z-scored with the
  same frozen parameters that z-scored it. An errors-in-variables fit predicts
  the un-shrunk composite, so it is re-shrunk by the exact inverse of the
  transform that un-shrunk it, `gm + λ_i(ŷ − gm)`, with `gm` the fitted sample's
  grand mean. Without that step the errors-in-variables arm would be scored
  against a target it was never predicting, and would be excluded from the
  Rashomon set by an artefact of bookkeeping rather than by fit. Mixed-model
  predictions include the fitted geography random effect.
- **Multiple imputation** specifications predict once per completion and the
  twenty predictions are averaged before scoring.

Losses are comparable **within** an outcome family and are not comparable across
families, because the target differs. Each family therefore gets its own
empirical risk minimizer and its own tolerance. The composite is the primary
family, per Plan §6 and Task 3.12; the aggregate and the four component families
are secondary.

The tolerance is reported in two forms: absolute, in the family's squared
outcome units, and relative, as ε ÷ L(ERM). The relative form is the headline
because it is the form the method's literature quotes and the only one that can
be read across families.

## 3. The empirical risk minimizer

The ERM of a family is the registered specification with the lowest common-frame
loss, taken over every specification in that family — including the Block A
specifications, which carry no community disadvantage at all. There is no
screening, no exclusion of specifications for being implausible, and no
tie-breaking on any criterion other than the loss.

The loss is in-sample: the evaluation frame is contained in the fitting frame
for most specifications, so more parameters buy a lower loss mechanically. That
is the empirical risk the method is defined on, and it is what will be used. The
parameter count of every specification is recorded alongside its loss so that
the question of whether the near-optimal region is simply the high-parameter
region can be answered at Task 3.10 rather than assumed either way. No
complexity penalty is applied to the loss.

## 4. The bootstrap

For a family with ERM `f̂`:

1. Draw `B` resamples with replacement.
2. Refit the ERM's specification — the same registered specification, not a
   re-selected one — on each resample, giving `f̂_b`.
3. Score each `f̂_b` on the **original** common evaluation frame.
4. The excess loss of replicate `b` is `Δ_b = L(f̂_b) − L(f̂)`, both terms on
   that original frame.
5. **ε = the 95th percentile of the `Δ_b`**, `α` being 0.05 from §1.

`Δ_b` may come out slightly negative for some replicates, because the evaluation
frame is not identical to the fitting frame; negative values are kept as they
fall and are not truncated at zero.

**Resampling unit.** The hospital for the composite family, which is fitted by
ordinary least squares on one row per hospital with no random effect. The
nesting cluster — HSA or hospital-county, whichever the ERM's grain selects —
for the aggregate and component families, because that is the unit their mixed
models treat as exchangeable. A **state-cluster bootstrap is run on the
composite family as a stated sensitivity**, because Task 3.8 found states carry
real leverage and New York moves the estimate by 0.13 to 0.26 SD. Both composite
tolerances are reported. The pre-registered primary is the hospital bootstrap;
if the state-cluster tolerance is larger, that is reported as a fact and not
adopted in place of the primary.

**Replicates.** B = 1,000 for the composite family and its state sensitivity.
B = 200 for each secondary family, because their ERMs may be mixed models fitted
twenty times over the imputation completions, which costs about 2.6 seconds a
replicate. The Monte-Carlo standard error of the 95th percentile is reported for
every family so the cost of the smaller B is visible rather than hidden.

**Imputation under the bootstrap.** The `m = 20` PMM completions were frozen at
Task 2.7 with the analytic file. They are not re-imputed inside the bootstrap;
the completions travel with the rows that are resampled. This is bootstrap after
imputation, it understates imputation uncertainty slightly, and it is stated
here rather than discovered later.

**Failures.** A replicate that errors is recorded with its reason and excluded
from the quantile, and the count of failed replicates is reported. Replicates
are not silently retried until they succeed.

## 5. What would count as violating this

The tolerance is the number step 5 produces. If it turns out to be wider than is
convenient for Task 3.10 — and the Task 3.7 result that the linear and spline
arms differ by roughly the size of the estimate itself suggests it may be — the
width is the finding, per Plan §8, and neither α nor the loss nor the resampling
unit gets revisited to narrow it.

---

## 6. Amendment 1 — mixed-model predictions are population-level

**2026-09-10, before the first loss was computed and before `R/05-rashomon.R`
was run for the first time.**

§2 said mixed-model predictions include the fitted geography random effect. That
is not implementable alongside §4's cluster bootstrap, and the conflict is
arithmetic rather than a matter of taste. The cluster bootstrap has to relabel
each drawn copy of a cluster, or a cluster drawn twice becomes one cluster of
twice the size and the between-cluster variance is understated. Once relabelled,
every cluster in a bootstrap refit is a label the original evaluation frame has
never seen, so a random-effect-inclusive prediction falls back to zero for every
row of it — while the original fit `f̂` keeps its matched random effects. Every
replicate would then be penalised for a bookkeeping difference, `Δ_b` would be
inflated across the board, and the tolerance would come out too wide for a
reason that has nothing to do with sampling variability.

**All predictions are therefore population-level**: fixed effects only,
`re.form = ~0`, applied identically to `f̂` and to every replicate, and
identically to every specification competing within a family. The composite
family is unaffected — it is fitted by ordinary least squares and has no random
effect to include.

This changes what the mixed families' loss measures: the fixed-effect part of
the model, evaluated as a predictor for a hospital whose geography the model has
not seen. That is the more demanding reading and the one that makes the
tolerance mean the same thing in every family. It is recorded here, before the
run, rather than discovered in the results.

## 7. Amendment 2 — a metro-area cluster bootstrap, added after the results

**2026-09-18, after the primary and the state-cluster tolerances had been
computed and read.** This is not a pre-registered choice and is not presented
as one.

The two pre-registered composite tolerances came out at 4.10 percent (hospital)
and 9.31 percent (state) of the minimizer's loss, and whether a model with no
community disadvantage falls inside the set depends on which is used. Neither
unit matches where the dependence in these data was measured to be: Task 3.1
found 13 percent of PSI-90 variance between metro areas (CBSAs) and 4 percent
between states, so hospitals share more with neighbors in their market than
with hospitals elsewhere in their state. The hospital bootstrap ignores that
sharing; the state bootstrap sweeps it up together with everything else a state
has in common, and does so with only about fifty clusters.

A third composite bootstrap therefore resamples **metro areas** (457 CBSAs;
the two hospitals without one are their own singleton clusters), at B = 1,000
with the same seed discipline. It is a **sensitivity**, reported beside the
state-cluster one and never in place of the pre-registered primary. Adding a
sensitivity after seeing results is the ordinary thing; substituting the
primary would not be, and it is not done.

---

**Fixed by:** Carl Jacobsen, 2026-09-10, before `R/05-rashomon.R` was run.
Amendment 2 added 2026-09-18, after.
