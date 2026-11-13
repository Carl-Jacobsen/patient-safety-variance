# Task 3.7 — Run the specification curve

**Date:** 2026-09-09 · **Budget:** 7 h · **Status: complete.**

Two stages. `make.R` 24 (`R/04-spec-curve.R`, the Task 3.6 harness) run with
`SPEC_CURVE_FULL=1` fits every one of the 3,496 registered specifications and
writes `data/spec-results.rds`. `make.R` 25 (`R/04-spec-curve-report.R`) reads
that object and produces the sorted curve, the sign-stability number, the
reliability axis on its own, and two figures. The full fit took 1,295 seconds.
All 3,496 specifications produced a result row, none failed, and after the two
harness corrections below none carried a convergence or singularity flag.

**Two corrections to the harness before the recorded run.** The first pass left
1,383 of the mixed-model fits flagged "nearly unidentifiable: very large
eigenvalue" and 3,450 fits reporting a dropped column. Neither was a real
identifiability problem. The published component denominators run from 29 to
56,196, and weighted least squares is invariant to the scale of its weights,
but `lme4`'s convergence check reads an unscaled weight vector of that spread as
a scaling failure; rescaling the weights to mean one clears every flag and
leaves the coefficients unchanged, which is the same fix `R/03-baseline.R`
already applied. The dropped columns came from splining `rurality`, a USDA
rural-urban code taking nine integer values, at a coarse geographic grain,
where the natural-spline basis is rank-deficient. `provenance/spec-space.md` §3
already restricts the spline to the continuous disadvantage measures, so the
harness now does too, and the rank-deficiency disappears. The estimates from
the first and second runs agree to four decimals; only the flags changed.

---

## 1. The focal estimate

Each specification yields `dis_effect`, the model-predicted change in the
outcome when a hospital's community-disadvantage profile moves from the 10th to
the 90th frame percentile on every disadvantage measure at once, with ICE-150
and PCP density inverted so that the high end is always the deprived end. A
positive value means hospitals serving more deprived communities have worse
(higher) PSI. The estimate is a joint contrast rather than a single coefficient
because Task 3.1 established that Block B is too collinear for a marginal
coefficient to be stable, and the claim the project needs is about community
disadvantage as a set, not about one measure.

`dis_effect` is in each outcome's own units. The composite is a ratio to the
national rate with a standard deviation near 0.19; the five component-based
outcomes are z-scored and have a standard deviation near 1. The curve therefore
runs on the standardized estimate, `dis_effect` divided by the standard
deviation of that specification's outcome, which reads as the p10-to-p90
disadvantage move measured in standard deviations of the outcome. The 152
blocks-only-A specifications carry no disadvantage term and sit out the curve,
leaving 3,344 specifications on it.

---

## 2. Sign-stability

**2,334 of the 3,344 specifications, or 69.8 percent, put the estimate above
zero.** The median standardized estimate is +0.10 SD, the interquartile range
runs from −0.03 to +0.31 SD, and the central 95 percent of specifications fall
between −0.44 and +0.94 SD. No specification produces an estimate that is
negative and separated from zero by a 95 percent interval; 250 specifications,
7.5 percent, are positive and separated from zero. Most individual
specifications cannot distinguish the association from zero because the
intervals are wide, particularly for the component outcomes, but the mass of
the distribution sits above zero and the sign is stable.

The published composite is the outcome a JHF reader sees, and it is more
positive than the curve as a whole. Across its 704 specifications the estimate
is positive in 77.6 percent, the median is +0.21 SD, and 18.3 percent are
separated from zero. The component aggregate, which rebuilds a composite from
the four component rates without CMS's smoothing, is the weakest single family
at a +0.03 SD median and 63.6 percent positive. The individual components
disagree: PSI-12, perioperative pulmonary embolism or DVT, is positive in 92.6
percent of its specifications at a +0.31 SD median, while PSI-03, postoperative
pressure ulcer, is essentially null at a −0.02 SD median and 41.7 percent
positive. The disadvantage association is real in the aggregate and
concentrated in particular conditions.

---

## 3. What moves the estimate

`output/tables/spec-curve-summary.csv` gives the standardized estimate by every
axis level. Two axes carry most of the spread.

**Functional form is the largest single source of variation.** Under a linear
disadvantage term the median estimate is +0.20 SD and 84.3 percent of
specifications are positive; under a natural spline the median is +0.02 SD and
55.3 percent are positive. The spline shrinks the p10-to-p90 contrast in 100
percent of the composite specification cells, by a within-cell median of 0.066
in psi90 ratio units, which is most of the linear estimate. The spline also
fits slightly better, with a lower in-sample weighted RMSE in every composite
cell and a lower AIC in 62 percent of them, so the flattening is at least
partly a real curvature in the disadvantage-outcome relationship rather than an
artifact of the basis. Both forms are defensible, and the answer has to hold
across the pair, which is what the Rashomon and MCR steps are for.

**Geographic grain matters and points the way Task 2.5 predicted.** The naive
hospital-county grain gives the strongest association, a +0.27 SD median with
85.5 percent of specifications positive, while the catchment-weighted county
grain gives the weakest, +0.06 SD and 59.9 percent. Catchment weighting pulls
the disadvantage measures toward the hospital's own area and attenuates the
association, which is consistent with the suppression-renormalization argument
in `plan-amendments.md` §2.1. The base-case catchment-tract grain sits between
the two at +0.08 SD and 71.4 percent.

The remaining axes move the estimate less. Dropping the footnote-23 and
footnote-29 hospitals lowers the median from +0.12 to +0.09 SD. Complete-case
handling of `contract_labor_share` gives a +0.07 SD median against +0.11 for
multiple imputation and +0.12 for dropping the covariate, so the transparent
fallback is the most conservative of the three. Adding Block C moves the median
from +0.12 SD to +0.10 SD. The outcome scale, identity against log, changes
almost nothing.

---

## 4. The reliability axis, reported separately

The task sheet asks for this axis on its own, because a disadvantage estimate
that strengthens once CMS's reliability smoothing is undone is direct evidence
that the smoothing was hiding it. The comparison is paired: within each
combination of the other seven axes, the estimate at each reliability level
minus the estimate unweighted.

**The errors-in-variables correction shifts the estimate up in 91.5 percent of
the 176 composite cells, by a within-cell median of +0.34 SD.** On the
composite the unweighted median is +0.18 SD and the corrected median is +0.48
SD, so undoing the shrinkage roughly triples the estimate. This is the
prediction in `plan-amendments.md` §1.3, that λ-weighting would un-attenuate the
community-disadvantage association because naive estimation gives equal weight
to the low-volume hospitals CMS shrank hardest, and it is now confirmed at a
size the plan did not commit to.

The gentler reliability levels do less. Weighting by λᵢ shifts the estimate up
in only 54.7 percent of cells, by a median of +0.01 SD, so down-weighting the
unreliable hospitals is not enough; the shrinkage has to be reversed, not just
discounted. Restricting to the high-reliability subsample shifts the estimate
up in 54.0 percent of cells at a +0.11 SD median, but with an interquartile
range that spans zero, because the subsample is less than half the hospitals
and the estimate is noisier there. The specification closest to Task 3.2's
baseline, all admitted blocks with a linear form on the λ-weighted composite at
the catchment-tract grain with multiple imputation, gives +0.36 SD with a
standard error of 0.03; its errors-in-variables variant gives +0.82 SD.

---

## 5. Figures

`output/figures/spec-curve.png` is the sorted curve. The top panel plots all
3,344 estimates with their 95 percent intervals, colored by sign and darkened
where the interval clears zero, with the y-axis spanning the full range from
−2.3 to +3.3 SD so that the near-zero and negative specifications are as
visible as the rest. The bottom panel is the choice grid, one row per axis
level, a mark where a specification uses that level, in the same sorted order.
The spline rows concentrate on the left, the errors-in-variables and
hospital-county rows on the right, and PSI-12 on the right against PSI-03 on the
left.

`output/figures/spec-curve-reliability.png` is the reliability axis alone. The
left panel is the estimate distribution at each reliability level, climbing
from unweighted through the errors-in-variables correction. The right panel is
the paired within-cell shift against the unweighted fit, which holds the other
seven axes fixed and isolates what the correction does.

---

## 6. Files

```
R/04-spec-curve.R                          two harness corrections (weight scaling,
                                            spline set); estimates unchanged
R/04-spec-curve-report.R                   new -- make.R stage 25
make.R                                     stage 25 added
data/spec-results.rds                      3,496 rows, one per spec (gitignored, regenerable
                                            via SPEC_CURVE_FULL=1 Rscript make.R --stage 24)
data/spec-results.csv                      flat mirror
output/figures/spec-curve.png
output/figures/spec-curve-reliability.png
output/tables/spec-curve-summary.csv       standardised estimate by axis level
output/tables/spec-curve-reliability.csv   the paired within-cell contrasts
output/tables/task3.7-spec-curve.txt       stage log
```

`make.R --stage 24` with `SPEC_CURVE_FULL=1` then `--stage 25`: both `ok`,
provenance `consistent`. The frozen analytic hash is unchanged; the harness
reads the file and writes nothing upstream of it. The registry is unchanged.
Provenance table stays at 33 rows.

---

## 7. Next

**Task 3.8 — influence and diagnostics across the curve.** Check whether any
single hospital or state drives the result and whether particular
specification choices sit as outliers, reporting influential points rather than
removing them. The functional-form split from §3 is the first thing to take in:
the linear and spline arms are both defensible and they disagree by most of the
estimate, so Task 3.8 should establish whether the disagreement is stable
across hospitals or driven by a few, and Tasks 3.9 through 3.12 should expect
the Rashomon set to be wide on this contrast for that reason.
