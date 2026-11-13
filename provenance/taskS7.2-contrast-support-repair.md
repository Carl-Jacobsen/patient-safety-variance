# Task S7.2 — Nearest-neighbor distances repaired; decile contrasts relabeled as fitted

**Date:** 2026-10-12 · **Budget:** 1 h · **Status: done. Stage 41, October 7
audit findings A4 and A5.** The radial support result is unchanged. The
nearest-neighbor distances the S2.5 run reported were wrong, and after the fix
the most disadvantaged county-catchment endpoint is more isolated than 96.9%
of observed profiles. The supplementary decile comparison was a fitted
contrast and is now labeled as one, with the raw outcome difference beside it.

---

## 1. A4: the whitening

`chol(Si)` in R returns the upper factor U with `t(U) %*% U = Si`. For a row
vector x the Mahalanobis whitening is `x %*% t(U)`, since
|x U′|² = x U′ U x′ = x Si x′. Stage 41 used `M %*% U`. The radial distance
(`mdist`, a direct quadratic form) was right; only the nearest-neighbor
distances were affected.

`R/15-contrast-support.R` now whitens with `t(U)` and stops unless:

- the whitened Euclidean distance equals the direct quadratic form on 200
  random pairs of observed rows (tolerance 1e-8), and
- the whitened distance from each synthetic end to the whitened center equals
  its radial Mahalanobis distance (1e-8).

Joint contrast, nearest distinct observed profile (corrected; the S2.5 value
for the county endpoint was 1.421, with 22.96% as isolated):

| Grain | End | Nearest observed | Observed NN p95 | Share as isolated |
|---|---|---|---|---|
| catch_county | most | 2.07 | 1.88 | 3.1% |
| catch_county | least | 1.78 | 1.88 | 6.4% |
| catch_tract | most | 1.97 | 2.07 | 5.7% |
| catch_tract | least | 1.58 | 2.07 | 13.3% |
| hosp_county | most | 1.83 | 2.32 | 17.4% |
| hsa | most | 1.92 | 2.33 | 13.6% |

These reproduce the audit's independent check (2.074, p95 1.876, 3.06%). The
radial shares (12–34%) are unchanged, so the pre-registered rule still passes;
but a radial check cannot show local support, and the report now reads the
joint contrast as a model-based scenario rather than a description of real
places.

## 2. A5: the decile contrast

The "observed contrast, decile means (supplementary)" rows apply the model's
contrast to the mean design rows of the top and bottom deciles, with structure,
policy and market concentration at reference. They average observed community
profiles, not observed outcomes, and the standard error is the coefficient
covariance's. The rows are renamed "fitted contrast over observed decile
profiles (supplementary)" and gain `raw_outcome_diff`, the difference in mean
published PSI-90 between the same deciles in SDs:

| Grain | Profile | Fitted | Raw |
|---|---|---|---|
| catch_county | material | +0.233 | +0.153 |
| catch_county | composition | −0.441 | −0.224 |
| catch_tract | material | +0.255 | +0.311 |
| catch_tract | composition | −0.378 | −0.134 |
| hosp_county | material | +0.211 | +0.236 |
| hosp_county | composition | −0.398 | −0.177 |
| hsa | material | +0.205 | +0.201 |
| hsa | composition | −0.466 | −0.171 |

The signs agree at every grain; the sizes do not.

## 3. Checks

Stage 41: all four stored joint contrasts reproduced to 1e-8 before any new
quantity; every contrast splits exactly into its parts; both new checks pass.
Run time 6 s.

## 4. Time

About 1 h.
