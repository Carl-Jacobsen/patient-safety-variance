# Task S7.1 — The component decomposition on one declared frame

**Date:** 2026-10-12 · **Budget:** 1.5 h attended (46 min unattended) ·
**Status: done. Stage 22, October 7 audit finding A1 (P0).** Every subset
model of the components decomposition is now fitted to the same 9,782
component rows from the same 2,569 hospitals as the composite, in the point
estimate and in every bootstrap replicate, and the HSA-cluster bootstrap was
rerun. The community share is 1.62% (−0.81% to 4.19%), an interval that still
includes zero, now on a valid comparison. The stage also writes the paired
differences the audit asked for (A12) and the community quantities that show
the Shapley share is not a ceiling (A3).

---

## 1. The defect

`build_long()` kept every component row with an outcome and a positive
denominator, whatever its covariates, and `long_cc` was not complete-case
despite its name. Each `lmer()` call then dropped the rows missing its own
terms: 10,619 rows (2,801 hospitals) for the null model, down to 9,782 (2,569)
for the full one. The Shapley average therefore credited blocks with changes
of sample, and the bootstrap repeated the construction. The October 1 review
did not find it; the composite side was already right.

## 2. The repair

- `build_long()` keeps only rows complete on every covariate of every block.
  The stage stops unless the frame's hospitals equal the composite's
  `comp_cc` exactly.
- `var_hosp()` stops if any subset model's `nobs()` differs from the rows it
  was given, so no subset can drop a row, in the point estimate or in any
  replicate.
- The cluster bootstrap draws HSAs from the declared frame only.
- Task 3.2's null model (all 2,801 hospitals) now differs from this frame's by
  design (0.30627 against 0.29702); the comparison is printed, not tested.

The function text changed, so the cache key changed and the 1,000 replicates
were redrawn (2,705 s, 2.71 s per replicate, 0 failed). Every point estimate
lies inside its own interval.

## 3. Results

| Share of between-hospital variance | October 7 | Common frame | 95% interval (HSAs) |
|---|---|---|---|
| Structure | 7.47% | 6.13% | 3.22% to 11.81% |
| Community | 1.44% | 1.62% | −0.81% to 4.19% |
| Policy | 2.96% | 1.38% | 0.01% to 3.63% |
| Residual | 88.13% | 90.87% | 83.68% to 94.78% |

The point estimates reproduce the audit's diagnostic refit exactly. The
composite side is unchanged (community 3.32%, structure 4.49%, residual 91.21%).

**Paired differences, structure minus community (A12),** from the same
replicates:

| Decomposition | Difference | Paired 95% interval | Replicates > 0 |
|---|---|---|---|
| Composite, published | +1.16 pts | −0.44 to +3.36 | 93.1% |
| Composite, weighted | +0.66 pts | −0.87 to +2.92 | 82.4% |
| Components | +4.51 pts | +1.00 to +10.29 | 99.0% |

So on the published score the decomposition does not rank structure above
community, and on the components it does.

**Other community quantities from the same OLS fit (A3),** as shares of
Var(PSI-90): Shapley 3.32%, alone 3.59%, added last 3.10%, variance of the
fitted community term 6.11% (SD 0.247 outcome SDs). They answer different
questions, and none is an adjustment bound. Output
`output/tables/variance-decomposition-extra.csv`.

## 4. Downstream

Figure 1 (fig2) panel B is retitled "same 2,569 hospitals" (stage 38). The
prose that cited 1.44% (−0.60% to 3.67%) is corrected in S7.4. Stage 43's
check against the stage 22 composite share is unaffected.

## 5. Time

About 1.5 h attended.
