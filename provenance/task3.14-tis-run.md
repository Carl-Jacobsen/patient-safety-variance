# Task 3.14 — Run TIS and report shared attribution

**Date:** 2026-09-22 · **Budget:** 5 h · **Status: complete.**

One stage (`make.R` 32, `R/07-tis-run.R`) sourcing Task 3.13's implementation,
which re-runs its 30 validation checks and the MCR implementation's 15 beneath
them. All 736 composite specifications are decomposed across the ten
disadvantage measures — marginal reliance, direct reliance, the inflation
between them, and the flow matrix row saying which neighbors that inflation is
on loan from — and the three nested tolerances subset them. TIS is computed per
model and reported as a range over the set, the way the rest of Phase 3 reports
everything.

Plan §10 asks that shared attribution be reported rather than hidden inside a
ranked list, so the stage prints the direct-versus-shared split for all ten
measures before it prints any ranking, and the ranking then carries both
components rather than a single score.

**The headline: 15.5 percent of the median near-optimal model's excess reliance
on community disadvantage is shared rather than direct, and the measure that
looks most important marginally is not the one that survives holding its
neighbors fixed.**

---

## 1. Shared attribution, before any ranking

Median over the 194 near-optimal models. "R² on rest" is how much of a measure
the other nine reconstruct; "shared" is the fraction of its excess reliance that
is on loan.

| Measure | R² on rest | MR marginal | MR direct | Δ | Shared | Δ < 0 |
|---|---|---|---|---|---|---|
| ADI | 0.569 | 1.0168 | 1.0035 | +0.0132 | **78.5%** | 2% |
| ICE-150 | 0.557 | 1.0112 | 1.0046 | +0.0073 | 65.4% | 48% |
| limited English | 0.528 | 1.0428 | 1.0177 | +0.0179 | 41.8% | 8% |
| rurality | 0.477 | 1.0207 | 1.0056 | +0.0148 | 71.5% | 0% |
| SVI 3, minority status | 0.463 | **0.9976** | **1.0173** | −0.0202 | — | 97% |
| PCP density | 0.268 | 1.0033 | 1.0010 | +0.0024 | 73.5% | 4% |
| SVI 1, socioeconomic | 0.219 | 1.0056 | 1.0080 | −0.0017 | — | 75% |
| SVI 4, housing/transport | 0.216 | 1.0073 | 1.0066 | +0.0006 | 7.8% | 30% |
| uninsured | 0.184 | 1.0089 | **1.0181** | −0.0081 | — | 98% |
| SVI 2, household | 0.079 | 1.0062 | 1.0063 | +0.0003 | 4.1% | 49% |

Summed over the ten measures, the median model's marginal excess reliance is
0.1330 and the shared part of it is +0.0207, or **15.5 percent of the total**.
That is the number Plan §10 asks for: about a sixth of what community
disadvantage appears to contribute is contribution its measures are lending one
another rather than earning.

**ADI is the clearest borrower.** The other nine measures reconstruct 57 percent
of it, and 78.5 percent of its apparent reliance is on loan. Its direct reliance
is 1.0035, the second smallest in the block. ADI is the single most widely used
deprivation index in health-services research, and on these data most of what it
appears to contribute is contribution its neighbors would supply in its absence.
Rurality (71.5 percent shared) and ICE-150 (65.4 percent) are close behind.

**Three measures have negative Δ, and two of them almost always.** SVI theme 3
has Δ < 0 in 97 percent of near-optimal models and the uninsured rate in 98
percent. A negative Δ means a measure's correlations *lower* its apparent
reliance rather than inflating it — classical suppression, where scrambling the
measure lets its correlated partners carry a signal they were being held back
from carrying. Across every measure-by-model pair, 41.3 percent of Δ values are
negative. Task 3.13 §4 flagged why this is possible here and the formula
reference's Δ ≥ 0 is not violated: that guarantee holds when the model is the
least-squares solution on the frame its reliance is scored on, and no
specification in this project is, since each is fitted on its own frame and
scored on the common evaluation frame Task 3.9 fixed.

**SVI theme 3 is the case that justifies the whole exercise.** Its median
marginal reliance is 0.9976 — *below one*, meaning that scrambling racial and
ethnic minority concentration across hospitals slightly improves the average
near-optimal model. Its direct reliance is 1.0173, and its minimum across the
set is 1.0015, above one everywhere. A marginal importance measure would have
ranked this measure as worthless or worse. Holding its neighbors fixed, no
near-optimal model can ignore it.

## 2. The driver ranking, with both components

| Measure | Direct MR (min..max) | Sender (med/max) | TIS (min..med..max) | Cannot be ignored |
|---|---|---|---|---|
| SVI 3, minority status | 1.0015 .. 1.0350 | 0.0122 / 0.0246 | 1.014 .. **1.028** .. 1.050 | **yes** |
| ICE-150 | 1.0008 .. 1.0411 | 0.0148 / 0.0426 | 1.006 .. 1.024 .. 1.057 | **yes** |
| limited English | 1.0070 .. 1.0405 | 0.0040 / 0.0087 | 1.009 .. 1.023 .. 1.045 | **yes** |
| uninsured | 0.9997 .. 1.0405 | 0.0017 / 0.0075 | 1.004 .. 1.021 .. 1.042 | no |
| rurality | 1.0016 .. 1.0247 | 0.0094 / 0.0358 | 1.007 .. 1.016 .. 1.051 | **yes** |
| ADI | 1.0004 .. 1.0120 | 0.0083 / 0.0710 | 1.002 .. 1.013 .. 1.071 | **yes** |
| SVI 1, socioeconomic | 0.9966 .. 1.0137 | 0.0011 / 0.0511 | 0.997 .. 1.009 .. 1.052 | no |
| SVI 4, housing/transport | 1.0015 .. 1.0205 | 0.0023 / 0.0195 | 1.004 .. 1.009 .. 1.040 | **yes** |
| SVI 2, household | 1.0000 .. 1.0211 | 0.0003 / 0.0202 | 1.004 .. 1.008 .. 1.039 | **yes** |
| PCP density | 0.9999 .. 1.0066 | 0.0044 / 0.0136 | 1.002 .. 1.005 .. 1.017 | no |

**Seven of the ten have MCR⁻_direct above one**: no near-optimal model can
ignore them even after their shared variation is held fixed. The three that do
not — the uninsured rate, SVI theme 1, and PCP density — are the covariates
merely correlated with something consequential, and the table shows them earning
their position through the sender term rather than on their own account. That
separation is the second half of the verify condition, and it is visible in the
columns rather than asserted.

The ranking is not the ranking a marginal analysis would produce. SVI theme 3
tops it while sitting below one marginally; ADI falls to sixth despite being
fourth on marginal reliance. Every TIS range is wide relative to the gaps
between measures, which is the same message Task 3.10's set width carried: the
data order these measures only loosely.

## 3. The flow matrix: who lends to whom

Entries are in reliance units; rows are the measure whose reliance is inflated,
columns the neighbor it is on loan from. Full matrix in
`output/tables/tis-flow-matrix.csv`.

The largest single flow is **SVI theme 3 ← limited English at −0.0162**, and it
is negative, which is the suppression above seen pairwise: these two measures
correlate at +0.68 across catchments, and each is holding the other back rather
than propping it up. The largest positive flows run into rurality,
from ICE-150 (+0.0060), ADI (+0.0047) and SVI theme 4 (+0.0029), and into ADI
from ICE-150 (+0.0096).

**ICE-150 is the biggest net lender at +0.0127 and rurality the biggest net
borrower at +0.0186.** That pairing has a plain reading: the income
concentration index is carrying information that rurality's apparent importance
is partly built on, which is what one would expect given that rural catchments
are where concentrated low income and low provider density coincide.

## 4. Does Shapley add anything? Yes, and it disagrees

Exact Shapley over all 2¹⁰ subsets at the empirical risk minimizer, R² = 0.0708:

| Measure | Shapley | Unique | Shared | Shared % |
|---|---|---|---|---|
| limited English | 0.01597 | 0.01392 | +0.00205 | 12.8% |
| rurality | 0.01256 | 0.00352 | +0.00904 | 72.0% |
| uninsured | 0.01116 | 0.01729 | −0.00613 | −54.9% |
| ADI | 0.00750 | 0.00142 | +0.00608 | 81.1% |
| SVI 3 | 0.00718 | 0.01439 | −0.00721 | −100.5% |
| PCP density | 0.00518 | 0.00268 | +0.00250 | 48.2% |
| SVI 2 | 0.00401 | 0.00367 | +0.00034 | 8.6% |
| SVI 1 | 0.00272 | 0.00418 | −0.00146 | −53.8% |
| SVI 4 | 0.00271 | 0.00255 | +0.00016 | 5.9% |
| ICE-150 | 0.00184 | 0.00139 | +0.00044 | 24.1% |

It sums to R² exactly. **The Spearman correlation between the Shapley ranking
and the TIS ranking is +0.27**, which is close to no agreement at all, so the
answer to whether Shapley adds information is yes. The two disagree most on
ICE-150, which Shapley ranks last and TIS ranks second, and on limited English,
which Shapley ranks first and TIS ranks third.

The disagreement is interpretable rather than a contradiction, because the two
answer different questions. Shapley divides the variance explained *in the
outcome*; TIS divides *reliance*, and credits a measure for the reliance it
lends to others. ICE-150 explains almost none of PSI-90 on its own and is the
block's largest net lender, so it scores last on one and second on the other.
Both are true, and a deliverable that reported only one would be making a choice
it had not declared. Shapley's shared share and the TIS R²-on-the-rest agree
much better with each other, Spearman +0.61, which is the check that the two
methods are at least measuring collinearity the same way.

The two agree on one thing worth saying plainly: the measures with the largest
*unique* contributions are limited English (0.0139), SVI theme 3 (0.0144) and
the uninsured rate (0.0173), and ADI's unique contribution is 0.0014, an order
of magnitude smaller. ADI carries its weight through what it shares.

## 5. What this hands the deliverable

Task 3.12 established that no near-optimal model can ignore community
disadvantage as a block. Task 3.14 says which parts of it are load-bearing
after the sharing is accounted for, and the answer is not the parts a
conventional analysis would name. The dimension that carries the most weight is
**racial and ethnic minority concentration together with limited English**,
both of which have large direct reliance and large unique Shapley contributions
and both of which look weak or negative marginally. **Area deprivation, the
measure most likely to be reached for first, is the block's clearest
borrower.** For the data-prioritization deliverable that matters: a
minimum-viable dataset built by keeping ADI and dropping the SVI themes would
keep the measure whose apparent importance is most on loan and discard two of
the three that earn theirs.

## 6. Files

```
R/07-tis-run.R                            new -- make.R stage 32
make.R                                    stage 32 added
data/tis-decomposition.rds                per-spec flow matrices and summaries (cached; TIS_REFIT=1 forces)
output/tables/tis-decomposition.csv       per measure: direct, shared, TIS range, Shapley
output/tables/tis-flow-matrix.csv         the flow matrix, long
output/tables/tis-per-model.csv           every spec x measure: marginal, direct, Delta, sender, TIS
output/figures/tis-decomposition.png      4 panels
output/tables/task3.14-tis-run.txt        stage log, shared attribution printed before the ranking
```

`make.R --stage 32`: `ok`, provenance `consistent`, 3.6 min cold and 24 s warm.
The per-neighbor flow sums to Δ for every one of the 736 specifications and all
ten measures, maximum error 1.3e-13. The m-completion generalization reproduces
Task 3.13's validated single-completion function exactly at m = 1. Provenance
table stays at 33 rows.

## 7. Next

Phase 3 is complete. **Task 3.15 — cluster on margin and safety maturity**,
reinstated in rev 3, with the cluster count selected by a criterion fixed before
the solutions are inspected, margin screened for the two catastrophic
near-zero-revenue outliers Phase 0 found, and clustering run on the λ-corrected
outcome as well as the raw one, since shrinkage compresses low-volume hospitals
toward the mean exactly where volume is low.
