# Task 3.8 — Influence and diagnostics across the curve

**Date:** 2026-09-10 · **Budget:** 4 h · **Status: complete.**

One stage (`make.R` 26, `R/04-spec-diagnostics.R`) reading `data/spec-results.rds`
from Task 3.7 and `data/analytic-v1.rds`. Two questions from the task sheet:
whether any single hospital or state drives the disadvantage estimate, and
whether particular specification choices sit as outliers. Nothing is removed.
The influential units are named, and where dropping one changes a conclusion
both versions are reported.

The influence work uses six anchor specifications rather than the whole
3,344-specification curve, because a leave-one-out pass over the full grid is
2,801 refits times 3,344 fits. The anchors are the published composite outcome
at the four functional-form-by-reliability combinations Task 3.7 found
consequential, fit by ordinary least squares so that leave-one-hospital-out is
the closed-form change in the fitted contrast, plus two mixed-model anchors, the
component aggregate and PSI-12, for which only leave-one-state-out is computed
by refit. Every anchor fixes the geography at catchment-tract, the missing-data
handling at complete-case, the sample at all hospitals, and the outcome scale at
identity.

---

## 1. No single hospital drives the estimate

Across the four composite anchors, removing the most influential hospital moves
the standardized estimate by at most 0.13 SD, which is 17 percent of that
anchor's estimate, and no single removal changes a sign. The one hospital that
matters most is Mississippi Baptist Medical Center in Jackson (CCN 250102),
whose published PSI-90 of 2.42 sits near the top of the national distribution
and whose catchment carries an area deprivation index of 77. It is a real
high-deprivation, high-PSI observation with genuine leverage on the slope, not a
coding error, and dropping it leaves every anchor firmly positive. The
`spec-results.csv` already carries a `drop_fallback` and a `drop_fn2329` axis,
and Task 3.7 §3 found both moved the curve by two to three hundredths of a
standard deviation, so the specification space had already absorbed the
influential-point question at the level of named data-quality flags.

## 2. New York is the influential state, and it flips only the null specifications

New York is the most influential state in every one of the six anchors.
Removing its 123 hospitals weakens the disadvantage estimate by between 0.13 and
0.26 SD. This is the expected direction and not a distortion: New York's
hospitals average a PSI-90 of 1.09 against a national 1.00, several of them
serve deprived areas of New York City, and they therefore sit exactly where a
positive disadvantage slope predicts. Removing a large block of observations
that support the association weakens it, which is what removing supporting data
does.

For the three anchors that are solidly positive, the linear composite at +0.35
to +0.40 SD and the errors-in-variables composite at +0.87 SD, no state removal
brings the estimate anywhere near zero. For the two anchors that Task 3.7
already reported as indistinguishable from zero, the spline composite at +0.08
SD and the component aggregate at +0.10 SD, removing New York turns the estimate
negative, to −0.18 and −0.06. Both versions are in
`output/tables/spec-diagnostics-influence.csv`. The reading is narrow: a
specification whose estimate could not be told from zero to begin with can be
pushed to either side by one state, and the specifications with a real signal
cannot. The PSI-12 anchor moves the other way, since removing Florida's 160
hospitals raises its estimate from +0.23 to +0.37 SD, so Florida's PSI-12 slope
runs against the pooled one.

## 3. Which specification choices move the estimate

The within-cell contribution of each axis holds the other seven fixed and moves
one. Four axes carry the spread: the outcome measure at a mean within-cell
standard deviation of 0.24, the reliability treatment at 0.22, the geographic
grain at 0.18, and the functional form at 0.18. Three barely register: the
outcome scale at 0.055, the missing-data treatment at 0.050, and the
influential-point rule at 0.037. A main-effects analysis of variance on the
balanced all-blocks subset, which drops the errors-in-variables level because it
occurs only with the composite, attributes 22 percent of the estimate's
variance to the outcome, 11 percent to the grain, 7 percent to the functional
form, and 3 percent to reliability, with 55 percent left in the residual. That
residual is interaction, chiefly functional form by outcome, because the spline
shrinks the composite contrast far more than it shrinks the component contrasts.

Adding Block C moves the estimate down by a within-cell median of 0.03 SD and
does so in 80 percent of cells, which is a small and consistent effect rather
than a swing. The single levels with the heaviest within-cell tails are the two
noisiest component outcomes, PSI-06 at a 95th-percentile absolute deviation of
1.06 SD and PSI-12 at 0.67, followed by the hospital-county grain at 0.75 and
the high-reliability subsample at 0.74. The last two are expected: the
hospital-county grain discards the catchment weighting, and the
high-reliability subsample is fewer than half the hospitals, so both are
estimated on thinner or coarser information.

## 4. What this means for the conclusion

No single hospital and no single state drives the headline. The estimate that
matters, the composite under a linear form with the reliability correction, is
stable to dropping any one hospital and any one state, and stays between +0.6
and +1.0 SD throughout. The specification choices that move the estimate are the
outcome measure, the reliability treatment, the geography, and the functional
form, and the two axes the registry built specifically to handle influential
points, the footnote-flag drop and the catchment-fallback drop, are near the
bottom of the list. The one caution to carry forward is that a specification
whose estimate is already indistinguishable from zero, which is most of the
spline arm and the aggregate, can be flipped by removing New York, so the
Rashomon set at Tasks 3.9 through 3.12 should be expected to straddle zero on
this contrast for the flatter specifications even though its center is positive.

---

## 5. Files

```
R/04-spec-diagnostics.R                          new -- make.R stage 26
make.R                                           stage 26 added
output/tables/spec-diagnostics-influence.csv     6 anchors: leave-one-hospital, leave-one-state
output/tables/spec-diagnostics-axis-contribution.csv   within-cell SD and eta^2 per axis
output/figures/spec-diagnostics.png              4 panels
output/tables/task3.8-spec-diagnostics.txt       stage log
```

`make.R --stage 26`: `ok`, provenance `consistent`, 13 s. The frozen analytic
hash is unchanged and the harness output is untouched. Provenance table stays at
33 rows.

---

## 6. Next

`[FRESH SESSION]` per the task sheet, then **Task 3.9 — select the Rashomon
tolerance by bootstrap.** Fit the empirical risk minimizer, resample, take the
(1 − α) quantile of excess loss, with α fixed and stated before the quantile is
computed. Task 3.8 leaves one thing on the table for it: the functional-form
split is systematic and roughly the size of the estimate, so the near-optimal
set will contain both the linear and the spline arm, and the coefficient range
it implies for community disadvantage will be wide.
