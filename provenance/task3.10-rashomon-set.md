# Task 3.10 — Construct the Rashomon set and report its width

**Date:** 2026-09-21 · **Budget:** 7 h · **Status: complete.**

One stage (`make.R` 28, `R/05-rashomon-set.R`) reading the common-frame loss
table and the tolerances from Task 3.9 and the disadvantage estimates from Task
3.7. Nothing is fitted. A specification is in its family's Rashomon set when its
loss is at most L(ERM) + ε, and the width is the range of the p10→p90
community-disadvantage contrast across the members, in SD of the outcome (Task
3.7's `dis_std`). The task sheet's verify condition is that the width is reported
before any MCR bound is computed, so that a wide set is a finding rather than a
disappointment. No MCR code exists in the repository; `R/06-mcr.R` is Task 3.11,
and the stage asserts its absence.

**The width: 1.25 SD of PSI-90, from −0.37 to +0.88, and the set straddles
zero.** At the pre-registered tolerance, 194 of the 736 composite
specifications are near-optimal. Their estimates of the disadvantage contrast
run from −0.370 to +0.879 SD, with an interquartile range of 0.44 SD and a
median of +0.07. The empirical risk minimizer itself sits at the negative end,
at −0.360 SD. Plan §8 says "the data cannot distinguish these explanations" is
useful information for a data-prioritization deliverable, and that is the
result: on the published composite, models the data cannot tell apart disagree
about the sign.

---

## 1. The width, at every tolerance

| Set | ε | In set | Block-A in set | Range of the estimate (SD) | Width | IQR | Share > 0 | Clear of zero, + / − |
|---|---|---|---|---|---|---|---|---|
| **composite, hospital (primary)** | 4.10% | **194 / 736** | **0** | **−0.370 to +0.879** | **1.249** | 0.439 | 57.2% | 7.2% / 0.0% |
| composite, metro area | 5.10% | 319 / 736 | 0 | −0.370 to +0.926 | 1.296 | 0.329 | 73.0% | 11.3% / 0.0% |
| composite, state | 9.31% | 536 / 736 | 8 | −0.370 to +0.952 | 1.322 | 0.275 | 83.7% | 24.4% / 0.0% |
| aggregate | 3.21% | 116 / 552 | 0 | −0.376 to +0.151 | 0.527 | 0.156 | 59.5% | 0.0% / 0.0% |
| PSI-03 | 3.16% | 99 / 552 | 0 | −0.438 to +0.114 | 0.552 | 0.158 | 37.4% | 0.0% / 0.0% |
| PSI-06 | 3.00% | 252 / 552 | 6 | −0.042 to +0.298 | 0.340 | 0.128 | 83.3% | 0.0% / 0.0% |
| **PSI-12** | 3.07% | 167 / 552 | 4 | **+0.147 to +0.494** | 0.347 | 0.058 | **100%** | 38.7% / 0.0% |
| PSI-13 | 3.92% | 180 / 552 | 4 | −0.231 to +0.268 | 0.499 | 0.187 | 56.8% | 0.0% / 0.0% |

Three things are true at once. The set is wide: its range is 1.25 SD against
1.68 SD for the whole 736-specification curve, so the tolerance removed
three-quarters of the specifications and a quarter of the spread. The set is not
symmetric about zero: 57 percent of the members put the contrast above zero at
the primary tolerance, 73 percent at the metro-area one, 84 percent at the
state one, and every member that is clear of zero is positive — 7.2 percent of
the primary set, none negative. And the set is imprecise rather than
contradictory: the median member has a t-statistic of 0.77 in absolute value,
the ERM's own is −0.81 (estimate −0.360, standard error 0.445), so most members
cannot tell their own sign, and the width is largely the standard error of the
spline's joint contrast showing through rather than two confident answers in
opposition.

No model without community disadvantage is in the primary set, or the metro-area
one. Eight are in the state-cluster set. That is Task 3.9 §7's flag confirmed:
whether a near-optimal model can ignore community disadvantage altogether
depends on the resampling unit, and on two of the three units it cannot.

PSI-12 (perioperative pulmonary embolism or deep vein thrombosis) is the one
family whose set does not straddle zero. All 167 members are positive, from
+0.15 to +0.49 SD, and 39 percent are clear of zero. Task 3.7 found PSI-12 the
component with the strongest gradient (+0.31 SD, positive in 93 percent of
specifications); Task 3.10 finds it the one outcome on which the data can make
up their mind. The four other secondary families straddle zero the way the
composite does.

## 2. What organizes the sign inside the set

The composite set is not a cloud. Two axes sort its members by sign almost
cleanly.

**Geographic grain.** Every member at catchment-county grain is negative
(72 specifications, −0.370 to −0.085 SD). Every member at catchment-tract grain
is positive (41 specifications, +0.080 to +0.879 SD). HSA and hospital-county
members sit between (−0.023 to +0.721 and −0.072 to +0.403). Task 2.5 measured
the correlation between tract-grain and county-grain versions of the same
disadvantage measure at 0.56 to 0.88, low enough that the two grains carry
different information, and this is where the difference lands: the same models,
fed the same hospitals' catchments aggregated at two resolutions, disagree
about the direction of the gradient, and the loss does not choose between them
(catchment-county holds the ERM; catchment-tract's best member is 0.32 ε above
it).

**Functional form.** The 178 spline members run from −0.370 to +0.502 SD with
a median near zero. The 16 linear members run from +0.52 to +0.88, with
standard errors of about 0.31, so they are the ones clear of zero. All 16 are
errors-in-variables fits at catchment-tract or HSA grain, and all sit between
0.83 and 0.99 ε above the ERM — inside the set, near its edge. Task 3.7 found
the spline shrinks the p10→p90 contrast in every composite cell while fitting
slightly better; Task 3.10 confirms that the tolerance admits both and that
the reader's choice between them is the choice between a strong positive
gradient and none.

**Reliability.** The errors-in-variables arm supplies 88 of the 194 members
and the ERM. Unweighted supplies 65, λ-weighted 41, and the high-reliability
subsample none — its best specification is 2.55 ε above the ERM. Dropping the
low-reliability hospitals is the one reliability choice the data reject.

The other axes matter less. Multiple imputation, complete-case, and omitting
contract labor share are in the set in similar proportion (32 to 35 percent of
each level), the three influential-point treatments likewise (25 to 30
percent), and identity scale beats log two to one. Block A + B specifications
are in the set at 19 percent and A + B + C at 30 percent, so adding the policy
block helps the fit slightly and does not change the estimate's range.

## 3. The complexity question, answered

Task 3.9's pre-registration deferred to here the question of whether the
near-optimal region is simply the high-parameter region. It is not, although
the smallest models are excluded. Members carry between 26 and 51 fixed
effects; no 12-effect (Block A) or 23-effect (Block A + B, linear) specification
is inside. Among the 176 specifications at the maximum of 51 effects, 106 are
in and 70 are out, and the correlation between parameter count and loss across
the composite family is −0.03. Membership above the floor is decided by
reliability, grain, and scale, not by size.

## 4. How the set grows with the tolerance

The first negative estimate enters at ε = 0, since the ERM is negative. The
upper edge of the range reaches +0.88 SD by the primary tolerance and +0.95 by
the state one, then stops; the lower edge stays at −0.37 until roughly 3.7 times
the primary tolerance, where a second cluster of negative specifications
(29 high-reliability-subsample spline fits at catchment-county and HSA grain,
0.005 to 0.008 above the ERM) begins to enter and pulls it to −0.71. The first Block-A specification
enters at 2.16 ε. So a reader who prefers the metro-area tolerance gets a set
of 319 with the same range and a higher share positive; a reader who prefers
the state tolerance gets 536, the same range, eight models with no community
disadvantage in them, and 84 percent positive. The width is stable across the
three; what moves is the composition.

## 5. What this means for the deliverable, and for Tasks 3.11 and 3.12

The Plan's Model 2 is a data-prioritization exercise, and a wide Rashomon set
says which data would narrow it. Two of the set's axes are data questions
rather than modeling ones. The grain axis asks which resolution the catchment
is measured at, and it splits the set by sign; a patient-origin file at the
hospital level, which Phase 1 could not obtain and Task 2.4 approximated from
HSAF ZIP shares, would settle it. The reliability axis asks whether the
published composite or the un-shrunk one is modeled, and the un-shrunk one both
fits better and carries the positive gradient; access to the component-level
numerators and denominators that CMS smooths away, or to more years of them,
would tighten the standard errors that make most of the set unable to tell
its own sign. Those two are the data the width is asking for.

For Task 3.11, the wide width in the contrast does not pre-decide the MCR
bounds. MCR asks a different question — how much the loss rises when the
community-disadvantage block is permuted — and does not depend on the p10→p90
joint contrast, which under a spline is evaluated at a corner of the covariate
space where few hospitals sit and which is therefore imprecise for reasons
that have nothing to do with whether disadvantage matters to the fit. A model
can have a near-zero joint contrast and still lose fit badly when disadvantage
is scrambled. Whether the near-optimal set can ignore Block B is the MCR⁻
question, and §1 already answers the coarse version of it: at the primary and
metro-area tolerances, no member does.

For Task 3.12, the headline claim must carry the width alongside it, per the
task sheet, and the honest sentence is this one: on the published composite,
near-optimal models put the community-disadvantage gradient anywhere from
−0.37 to +0.88 SD, more of them positive than negative, the ones that are sure
all positive, and none of them dispensing with disadvantage altogether; on
PSI-12 the near-optimal models agree it is positive.

## 6. Files

```
R/05-rashomon-set.R                          new -- make.R stage 28
make.R                                       stage 28 added
data/rashomon-set.rds                        the sets, widths, axis table, width-vs-tolerance curve, membership
output/tables/rashomon-set.csv               every spec x every tolerance: loss, excess, in_set, estimate
output/tables/rashomon-set-width.csv         8 rows, one per set
output/tables/rashomon-set-axes.csv          membership and estimate range by axis level, composite, 3 units
output/figures/rashomon-set.png              4 panels
output/tables/task3.10-rashomon-set.txt      stage log
```

`make.R --stage 28`: `ok`, provenance `consistent`, 0.7 s. Nothing upstream
touched; the frozen analytic hash is unchanged. Provenance table stays at 33
rows.

## 7. Next

**Task 3.11 — implement MCR bounds**, `R/06-mcr.R`, validated against a case
with a known answer before it is trusted on the real data. The set it runs over
is `data/rashomon-set.rds`, primary membership under `$primary$spec_ids` (194
composite specifications). Task 3.12 is scoped to Block B as the primary MCR
target, Block A secondary, no MCR on Block C.
