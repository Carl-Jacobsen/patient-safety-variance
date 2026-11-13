# Task 3.12 — Run MCR, scoped

**Date:** 2026-09-22 · **Budget:** 5 h · **Status: complete.**

One stage (`make.R` 30, `R/06-mcr-run.R`) sourcing Task 3.11's implementation,
which re-runs its fifteen validation checks on the way in, and computing model
reliance for all 736 composite specifications so that the bounds at each of the
three tolerances are minima over nested subsets. The scope is the task sheet's:
Block B primary as a group and per measure, Block A secondary, Block C
coefficient ranges with no MCR.

**The headline: MCR⁻ = 1.085 for community disadvantage as a group, and every
one of the 194 near-optimal models has reliance above one.** Scrambling
community disadvantage across hospitals costs the least-reliant near-optimal
model 8.5 percent of its squared error and the most-reliant one 23.0 percent.
No near-optimal model on these data can ignore community disadvantage.

---

## 1. The claim, stated as a claim about the model class

The bound says something about which models these data admit, and nothing about
what disadvantage does to patients. Written out: of the specifications the data
cannot distinguish from the best-fitting one, every single one relies on
community disadvantage, in the sense that scrambling hospitals' catchment
disadvantage profiles raises the model's error. It is not a statement that
deprivation causes adverse events, nor a measure of how much harm it causes.
Plan §9 requires that framing and it is the one used throughout the stage log
and the tables.

**The width goes with it.** The same 194 models put the p10→p90 disadvantage
contrast anywhere from −0.370 to +0.879 SD of PSI-90, a width of 1.25 SD that
straddles zero (Task 3.10). Both facts are true at once, and the apparent
tension is the whole point of doing this with a model class rather than a model:
reliance is bounded away from one while the contrast is not bounded away from
zero. Every near-optimal model needs community disadvantage to fit these data;
the near-optimal models do not agree on the direction or size of the gradient
they fit with it. A single-model analysis reporting +0.36 SD with a standard
error would have shown neither.

**And MCR⁻ = 1.085 is a lower bound.** The composite outcome is CMS's
reliability-shrunk PSI-90. `plan-amendments.md` §1.3 predicted that the
shrinkage attenuates this gradient toward zero; Task 3.7 confirmed it in 91.5
percent of paired composite cells; Task 3.9 confirmed it again by finding that
the un-shrunk errors-in-variables arm is the empirical risk minimizer. The
reliance measured here is what survives that attenuation, so the reliance an
unshrunk outcome would show is at least this large.

## 2. The group bound, and where it fails

| Tolerance | ε ÷ L | Models | MCR⁻ | MCR⁺ | Share above 1 |
|---|---|---|---|---|---|
| **hospital (pre-registered primary)** | 4.10% | 194 | **1.0848** | 1.2300 | 100% |
| metro area (post hoc sensitivity) | 5.10% | 319 | 1.0790 | 1.2300 | 100% |
| state (pre-registered sensitivity) | 9.31% | 536 | **1.0000** | 1.2300 | 98.5% |

At the state-cluster tolerance MCR⁻ is exactly one, and the claim is not
available. The mechanism is precisely the one Task 3.9 §7 flagged and Task 3.10
§1 confirmed: the state tolerance is wide enough to admit eight Block-A
specifications, models carrying no community disadvantage at all, and a model
with no such column has reliance of exactly 1 by definition. Those eight are
the entire difference — the other 528 members of the state set have MCR⁻ =
1.0475. So the claim's availability turns on the resampling unit, which is a
judgment about whether hospitals within a state are independent, not something
these data settle. Reported at all three, adopted at the pre-registered
primary, and the state result is not buried.

## 3. Per measure: no single measure carries the block

| Measure | MCR⁻ | MCR⁺ | Median | Share > 1 |
|---|---|---|---|---|
| **the block, as a group** | **1.0848** | **1.2300** | 1.1408 | 100% |
| limited English | 1.0162 | 1.0994 | 1.0447 | 100% |
| SVI 3, racial and ethnic minority status | 1.0059 | 1.0770 | 1.0307 | 100% |
| SVI 4, housing type and transportation | 1.0029 | 1.0361 | 1.0085 | 100% |
| rurality | 1.0015 | 1.0459 | 1.0102 | 100% |
| ADI | 1.0015 | 1.0353 | 1.0086 | 100% |
| ICE-150 | 1.0013 | 1.1489 | 1.0178 | 100% |
| market concentration (control, not a deprivation axis) | 1.0008 | 1.0137 | 1.0076 | 100% |
| SVI 1, socioeconomic | 1.0006 | 1.0476 | 1.0149 | 100% |
| SVI 2, household characteristics | 1.0000 | 1.0195 | 1.0072 | 99.5% |
| uninsured | 1.0000 | 1.0698 | 1.0287 | 99.5% |
| PCP density | 0.9993 | 1.0033 | 1.0005 | 86.1% |

The largest single-measure MCR⁻ is 1.0162, against 1.0848 for the group. The
group bound is more than five times the best individual one, and that gap is
the result rather than an inconvenience. Task 3.1 measured the collinearity that
produces it — ADI against ICE-150 at r = −0.83, variance inflation up to 9.8,
the first principal component carrying 46 percent of Block B's variance — and
the consequence is that a near-optimal model can drop any one measure and lean
on its neighbors, but cannot drop the ten together. This is why Plan §6 scoped
the defensible claim to community disadvantage rather than to SVI theme 2
specifically, and it is why per-measure attribution is TIS's job at Tasks 3.13
and 3.14 rather than MCR's.

PCP density is the one measure whose MCR⁻ falls below one, at 0.9993. A reliance
under one means some near-optimal model fits marginally better with that
variable scrambled, which is possible for a variable contributing almost
nothing; the deviation is three ten-thousandths and is reported rather than
rounded away.

## 4. Block A, secondary

| | MCR⁻ | MCR⁺ | Median |
|---|---|---|---|
| Block A as a group | 1.1121 | 1.2659 | 1.1581 |
| beds | 1.0975 | 1.4990 | 1.2168 |
| operating margin | 1.0158 | 1.0443 | 1.0263 |
| volume | 1.0123 | 1.1413 | 1.0644 |
| occupancy | 1.0088 | 1.0883 | 1.0256 |
| teaching | 1.0009 | 1.0137 | 1.0055 |
| the remaining six | 0.9987 to 1.0006 | 1.0036 to 1.3320 | ≈ 1.00 to 1.02 |

**Structure's group bound exceeds community disadvantage's**, 1.1121 against
1.0848, and hospital size alone nearly matches the entire disadvantage block at
1.0975. This is reported second, as the task sheet requires, and it is not the
headline — but it is not softened either. It agrees with Task 3.3, which found
structure at 4.25 percent of the variance in PSI-90 against community's 3.62
percent under the reliability-corrected model, so two methods with different
machinery put the two blocks in the same order. The honest summary is that both
blocks are things no near-optimal model can ignore, and structure is the larger
of the two on the published composite.

Unlike Block B, Block A's reliance concentrates in single covariates: beds alone
gets most of the way to the block's bound, where no Block B measure gets a fifth
of the way to its block's. Structure's covariates are separable; disadvantage's
are not.

## 5. Block C: coefficient ranges, no MCR

No MCR was computed for coding-intensity drift, contract labor share, or either
tort variable, and the stage asserts that none was. `admission-gates.md` §4
forbids a tort MCR claim, and rev 2 of the task sheet extended that to coding
intensity and contract labor: these covariates are in the model so that a rival
explanation is addressed, not so that they can be ranked. The exclusion is
principled and it stands.

Their Rashomon coefficient ranges, in SD of PSI-90 per SD of the covariate,
across the 194 members:

| Covariate | Range | Median | |
|---|---|---|---|
| contract labor share | +0.047 to +0.162 | +0.085 | one sign throughout |
| coding-intensity drift | −0.063 to +0.005 | −0.016 | straddles zero |
| tort reforms enacted | −0.099 to +0.027 | −0.023 | straddles zero |
| tort damages cap | −0.038 to +0.013 | −0.013 | straddles zero |

Contract labor share is the one Block C covariate whose sign every near-optimal
model agrees on, and it agrees with Task 3.2's finding under both complete-case
and imputation. The tort variables straddle zero across the set, which is the
result the block was admitted to produce: the rival explanation was entered and
it does not displace anything.

## 6. Block B coefficient ranges

Three of the ten hold one sign across every near-optimal model: SVI theme 3 at
+0.083 to +0.584, rurality at +0.092 to +0.852, and limited English at −0.995
to −0.082. The first two run in the expected direction, more deprived to worse
rates. The third runs against it and does so unanimously, which Task 3.1 first
saw in the raw correlations and Task 3.7 saw again in the per-measure
contrasts. The remaining seven straddle zero, ICE-150 most widely at −0.449 to
+1.295. So within a block that no near-optimal model can ignore, most individual
measures have no agreed sign — the same structure as §3, seen through
coefficients rather than reliance.

## 7. Files

```
R/06-mcr-run.R                             new -- make.R stage 30
make.R                                     stage 30 added
data/mcr-reliance.rds                      per-spec reliance and coefficients (cached; MCR_REFIT=1 forces)
output/tables/mcr-bounds-blockB.csv        group and per measure, three tolerances, width alongside
output/tables/mcr-bounds-blockA.csv        secondary, same shape
output/tables/rashomon-coef-ranges.csv     Blocks A, B and C across the primary set
output/tables/mcr-per-model.csv            every composite spec: loss, excess, membership, MR for every group
output/figures/mcr-bounds.png              4 panels
output/tables/task3.12-mcr-run.txt         stage log, the claim written out
```

`make.R --stage 30`: `ok`, provenance `consistent`, 234 s cold and seconds warm.
Every specification's `e_orig` equals its stored common-frame loss to better
than 1e-10, so reliance and set membership are computed on the same criterion.
Provenance table stays at 33 rows.

## 8. The scope caveat that travels with the number

MCR⁻ and MCR⁺ are minima and maxima over the specifications the registry
enumerated, not over a continuous model class. A minimum over a subset can only
overstate the true minimum, so MCR⁻ = 1.085 is an upper bound on the MCR⁻ of any
richer class, and the claim is properly stated as ranging over the 736 composite
specifications frozen at Task 3.5 before anything was fitted. The companion fact
does not depend on the enumeration in the same way: at the primary and
metro-area tolerances, no model without community disadvantage in it is
near-optimal at all.

## 9. Next

**Task 3.13 — implement the TIS decomposition**, separating direct from shared
attribution under the collinearity §3 has just demonstrated is doing the work.
The synthetic test there has a known shared structure to recover, and the
direct and shared components must sum as the method requires. Task 3.14 runs it
and reports which dimension of disadvantage carries the weight and how much of
the attribution is shared rather than direct, which is the question §3 raises
and cannot answer.
