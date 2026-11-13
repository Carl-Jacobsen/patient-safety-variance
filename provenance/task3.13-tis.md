# Task 3.13 — Implement the TIS decomposition

**Date:** 2026-09-22 · **Budget:** 7 h · **Status: complete.**

One stage (`make.R` 31, `R/07-tis.R`). The task sheet's verify condition has two
parts — direct and shared components sum as the method requires, and a synthetic
case with known shared structure recovers it — so the file is ordered to make
both literal: the validation suite runs first, halts the stage on failure, and
only then does the script read anything from `data/`. Thirty checks, thirty
passing.

---

## 1. What TIS is, and where the definition came from

The project plan references TIS a dozen times and never defines it. It is not
published literature; it is the project's own prior work, and it lives in the
`Rashomon/` folder: `Spring 26/docs/decomposition_algorithm.docx` carries the
derivation, `mcr_formula_reference.docx` the quantities, and `Spring 26/
correlated_signals/mcr_correlated_signals.Rmd` §9 the metric itself. **TIS is
the Total Influence Score.** The Autumn 26 sketch names the same thread "direct
versus shared model class reliance, with an exact per-neighbor flow matrix,
reported over the set."

The decomposition splits a measure's reliance in two:

  MR_marginal(j) = MR_direct(j) + Δ(j)

Marginal reliance permutes the measure outright, destroying both what is unique
to it and what it shares with its neighbors. Direct reliance permutes only the
residual of that measure regressed on the others — the part of it the others
cannot reconstruct — holding the reconstructable part fixed. Δ is the difference:
the inflation a measure's reliance gets from its correlations, and zero when it
is orthogonal to everything else in the model.

Δ then divides across the neighbors by the OLS projection identity
Var(X̂ⱼ) = Σₖ αₖ Cov(Xₖ, Xⱼ), giving Δⱼ⁽ᵏ⁾ = Δⱼ · αₖCov(Xₖ,Xⱼ) / Var(X̂ⱼ), which
sums over k back to Δⱼ exactly. Collected over all pairs that is the **flow
matrix** F[j,k]: how much of measure j's apparent importance is on loan from
measure k. And finally

  TIS(k) = MCR⁺_direct(k) + Σ_{j≠k} max(F[j,k], 0)

— what a measure earns on its own account, plus the credit it earns as a
*sender*, for the inflation it lends to everything else. That second term is
what makes TIS answer Task 3.14's verify condition, distinguishing covariates no
near-optimal model can ignore from covariates merely correlated with something
consequential: pure noise scores 1, a noise variable correlated with a real
signal gets a small sender term and no direct term, and a true signal gets both.

## 2. Two deliberate departures from the prior code

**The conditional expectation is taken exactly.** The prior implementation uses
E[(eᵢ − e_π(i))²] = eᵢ²(n−2)/(n−1) + ‖e‖²/(n−1); the exact all-pairs value is
eᵢ²·n/(n−1) + ‖e‖²/(n−1). Check 5 puts both against brute force over every
ordered pair and the exact form is the one that matches. The difference is
O(1/n) and immaterial at n = 2,569, but this file uses the exact form, which is
also the estimator Task 3.11 validated by brute force.

**Everything works in contribution space.** The prior code assumes a scalar
βⱼxᵢⱼ term. Half this project's specifications spline the disadvantage measures,
so a measure is a block of basis columns rather than one column. Working with
vⱼ = X[, cols(j)] · β[cols(j)] — the measure's whole contribution to the linear
predictor — handles a spline basis as a unit, and permuting the contribution is
the same as permuting the underlying variable because the basis is a row-wise
function of it. Check 9 verifies that this reduces exactly to the prior
formulas when a measure has a single column.

## 3. The validation

Thirty checks in `output/tables/tis-validation.csv`. The ones that carry the
verify condition:

| Check | Result |
|---|---|
| Conditional permutation: closed form against brute force over all n(n−1) ordered pairs | exact |
| An orthogonal measure has Δ = 0 and MR_direct = MR_marginal | exact |
| **MR_marginal = MR_direct + Δ**, all four measures of a correlated synthetic design | exact |
| **The per-neighbor flow sums to Δ**, all four measures | exact |
| Δ = 2n·Var(v̂)/((n−1)e₀) at the ERM, the closed form of `decomposition_algorithm.docx` §5 | to 1e-6 |
| **Known structure: X₁ = 0.8·X₂ + 0.6·ξ.** The reconstructable share comes back as ρ² = 0.64, *all* of Δ₁ flows to X₂ and none to X₁ itself, and Δ₁ matches its exact closed form | to 5e-3 / exact |
| **Known three-way split: X₁ = 0.6·X₂ + 0.8·X₃ + noise** with X₂ ⟂ X₃, so the flow must divide 0.36 : 0.64 | 0.361 : 0.639 |
| A measure its neighbors reconstruct exactly has MR_direct = 1 | to 1e-6 |
| Pure noise scores TIS = 1; a noise proxy ranks above pure noise and below the signal | exact / holds |
| Contribution space reproduces the X-space residualization | exact |
| Shapley values sum to R², and equal the unique components under orthogonality | to 1e-8 |

Two of these were failing tests rather than failing code, and both are worth
recording. The orthogonal-design case needed columns orthogonal to the intercept
as well as to each other, since the decomposition uses centered covariances. And
the closed form for Δ holds **at the ERM**, where the OLS normal equations kill
the cross-terms; the first version of that check assumed the true coefficients
rather than fitting them, so the identity did not apply and should not have.

One real bug surfaced: the Shapley helper memoizes subset R² values by a key
built from the column indices, and the empty subset's key is `""` — `exists("")`
throws. That is the same family of trap as the one Task 3.3 recorded about
`inherits = FALSE`, and the fix is a non-empty sentinel key.

## 4. What the smoke run shows, and the one thing Task 3.14 must handle

On specification 3, a spline, unweighted, catchment-tract member of the primary
set, the flow matrix rows sum to Δ to 3.5e-18 and the ranking already behaves
the way the method predicts. ICE-150 has the largest Δ at +0.0155 against a
direct reliance of 1.0198, so a third of its marginal reliance is on loan. ADI
has the smallest R² on the rest at 0.146 and correspondingly little inflation.
Limited English and SVI theme 3 have the highest reconstructable shares, 0.555
and 0.562, which is Task 3.1's collinearity appearing again through a different
instrument.

**Δ is not always positive here, and that is a real property of this
application rather than an error.** `mcr_formula_reference.docx` states Δ ≥ 0,
and that holds when the model is the OLS solution *on the data the reliance is
computed on*, because the normal equations then kill the cross-terms. No
specification in this project meets that condition: each is fitted on its own
frame — weighted, subsampled, or on an un-shrunk or logged outcome — and then
scored on the common evaluation frame Task 3.9 fixed, which is a different
frame. The cross-terms survive. Four of the ten measures have Δ < 0 on the
smoke specification and four do at the empirical risk minimizer too, meaning
their correlations *lower* their apparent reliance rather than inflating it.
This is printed in the stage log rather than left to be discovered, it is why
the TIS definition takes the positive part of the flow, and Task 3.14 will
report TIS and its signed variant TIS_net side by side rather than picking one.

## 5. Commonality and Shapley

Per the instruction to add them if they add information, `shapley_r2()` is
implemented and validated here: exact Shapley values over all 2ᵖ subsets, with
the unique (squared semipartial) components alongside, so shared = Shapley −
unique. Two checks confirm it sums to R² and collapses to the unique components
under orthogonality. Whether it says anything the flow matrix does not is a
question about the real data, not about the implementation, so it is Task 3.14's
to answer. The two answer different questions — Shapley divides explained
variance in the outcome, the flow matrix divides reliance between measures — and
the honest test is whether their rankings disagree.

## 6. Files

```
R/07-tis.R                              new -- make.R stage 31
make.R                                  stage 31 added
output/tables/tis-validation.csv        30 checks, got / want / tolerance / pass
output/tables/tis-smoke.csv             one specification, all ten measures, flow residual
output/tables/task3.13-tis.txt          stage log, including the negative-Delta note
```

The functions Task 3.14 will call are `residualize()`, `decompose_one()`,
`decompose_model()` (returns the flow matrix and the per-measure summary),
`tis_score(mr_direct, F, net =)` and `shapley_r2()`. `make.R --stage 31`: `ok`,
provenance `consistent`, 20.3 s. Provenance table stays at 33 rows.

## 7. Next

**Task 3.14 — run TIS and report shared attribution.** Decompose across the
correlated Block B measures over the Rashomon set, report which dimension of
disadvantage carries the weight and how much of the attribution is shared rather
than direct. The verify condition is that shared attribution is reported rather
than hidden inside a ranked list (Plan §10), and that the driver ranking
distinguishes covariates no near-optimal model can ignore from those merely
correlated with something consequential — which is what the sender term in TIS
is for.
