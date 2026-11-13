# Task S1.1 — Repair the direct and shared reliance wrapper

**Date:** 2026-10-02 · **Budget:** 4 h · **Status: done. The fixed part is the
full model minus one measure; the three preregistered invariants pass on all
736 composite specifications and fail on the September 30 wrapper.** The
repaired TIS outputs exist (stage 32 has rerun) but are not read here. Reading
them, the signed flows and the tags are S1.2's job.

---

## 1. The defect

`contrib_of()` in `R/07-tis-run.R` returned B and C carrying everything
*except* the ten disadvantage measures, and `decompose_spec()` then used that
same B and C for every measure. So each measure was permuted inside a model
that had lost the other nine. The prediction it scored was not the model's, and
neither was the loss. `decompose_model()` in `R/07-tis.R` had the same flaw
(one B for every j), and so did its smoke run.

Evidence (review of 2026-10-01, confirmed in the preregistration sec 1):
marginal reliance from the wrapper disagreed with stage 30's
`mcr-per-model.csv` in 7,040 of 7,360 specification-by-measure pairs. For
SVI 3, the median was 0.9976 against 1.0307.

The validation suite missed it for two reasons. Check 3 built the right fixed
part by hand. It also called `decompose_model()`, the function actually used,
but never checked the result. Check 8's "noise proxy" was an independent signal with
coefficient 0.6, so it was not a proxy at all.

## 2. The repair

- **`fixed_part(B0, C0, V, j, mult)`** (`R/07-tis.R`). Identity scale:
  B0 + C0 · Σ_{k≠j} v_k, with C0 unchanged. Log scale: B0, with C0 · Π_{k≠j} V_k
  where V = exp(v). Errors-in-variables specs inherit the right shape because
  B0 and C0 already carry the λ un-shrinkage.
- **`decompose_model()`** calls it for each measure. The September 30 version
  is kept as `decompose_model_sep30()` only so the tests can be run against it.
- **`decompose_spec()`** (`R/07-tis-run.R`) builds each measure's fixed part
  *within each completion* and then pools, in the same form stage 30 uses
  (B averaged over completions, C and V kept as n × m matrices).
  `decompose_spec(s, sep30 = TRUE)` reproduces the old wrapper exactly.
- **`pieces_pred()`** is the fit from `spec_pieces()` plus the model's own
  `predict()` on the evaluation frame, back-transformed as stage 29 does it.
  Invariant 1 compares against this, so the comparison is with something the
  decomposition did not build itself. `R/06-mcr.R` is untouched, so stage 30's
  cache and outputs stand as the independent reference.

## 3. Invariants (preregistration sec 2)

The invariants are checked on every specification and every completion, and
written to `output/tables/tis-invariants.csv`. Stage 32 stops before writing
any decomposition output if one fails.

| Invariant | Tolerance | Worst of 736 | Sep 30 wrapper (specs 1, 1749, 2) |
|---|---|---|---|
| 1. B + C·v_j = model's `predict()` (max abs) | 1e-10 | 1.8e-15 | 0.17, 0.14, 0.16 |
| 2. e_orig = `rashomon-loss.rds` (relative) | 1e-10 | 5.0e-15 | 0.069, 0.061, 0.062 |
| 3. MR_marginal = `mcr-per-model.csv`, 7,360 pairs | 1e-9 | 1.4e-13 | 0.023, 0.018, 0.017 |

The three negative cases are one identity-scale spec, one log-scale spec and
one multiply-imputed spec. They run inside stage 32 every time (sec 1 of the
runner), and the stage stops if any invariant *passes* on the old code. Swapping
the old wrapper back in therefore fails the suite by construction.

Invariant 2 reads the stored loss and invariant 3 the stage 30 table outside
the TIS cache, so a change upstream is seen on every run.

## 4. Synthetic tests (`R/07-tis.R`, 37 checks, all pass)

- **Two independent predictors** (8b; y = X1 + X2 + ε, n = 5,000). Marginal
  reliance is **2.925 and 3.086** (theory 3). The September 30 code gives
  **1.939 and 2.069** on the same data, and a check requires it to fall at or
  below 2.8.
- **Real proxy** (8; X2 = 0.8 X1 + 0.6ξ, model coefficient on X2 exactly 0,
  n = 200,000). X2's direct reliance is 1.000000, and its TIS is 1.000, below
  X1's. This is the preregistered gate. It cannot discriminate the defect,
  because with v2 ≡ 0 the old and new fixed parts coincide; check 8b does that
  job.
- **Fitted proxy, a known property of TIS, logged rather than checked.** On the
  same data with X2's coefficient *fitted* (true value 0, estimate 0.007),
  direct reliance is still 1.0000 (passes to 1e-3). But **TIS ranks the proxy
  above its signal: 2.276 against 1.718.** The flow split is invariant to the
  size of the neighbour's coefficient: regressing v1 on b2·x2 projects onto
  span(x2) for any b2 ≠ 0. So any nonzero estimate hands the proxy the signal's
  whole Δ (1.276) as sender credit. At b2 = 0 exactly, the credit vanishes, so
  the sender term is discontinuous at zero. On 2026-10-02, before stage 32 ran,
  Carl chose to keep the exact-zero case as the gate, log the fitted case on
  every run, and carry it to S1.2 as a reason the ranking is exploratory.
  Preregistration amendment 1 records this.
- **New checks.** `decompose_model()` agrees with the full-minus-one fixed part
  built by hand (3), and the log-scale fixed part rebuilds exp(Σ v) to 1e-12.
  The pure-noise check (TIS = 1) is kept on the new signature.

## 5. What this note does not do

- It does not interpret the repaired shared-attribution table, TIS ranking,
  flow matrix or tags. `tis-decomposition.csv`, `tis-flow-matrix.csv`,
  `tis-per-model.csv` and `driver-tags.csv` were regenerated by the stage 32
  run that checked the invariants. `driver-tags.csv` still uses the
  September 30 rule; S1.2 rebuilds it under the preregistered threshold.
- The 07-tis.R smoke run (`tis-smoke.csv`) has also moved, since its September
  30 values carried the same defect. S1.2 records the change.
- The Shapley cross-check at the ERM uses B0 (everything but the ten measures)
  as before. That is correct for an identity-scale ERM, and S1.2 confirms the
  ERM's scale.

## 6. Run

`Rscript make.R --stage 31` (20 s) and `--stage 32`: 5.1 min cold, since the
cache key includes both changed scripts. Logs are in
`output/tables/task3.13-tis.txt` and `task3.14-tis-run.txt`.
