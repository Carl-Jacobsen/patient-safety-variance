# Task 3.11 — Implement MCR bounds

**Date:** 2026-09-22 · **Budget:** 7 h · **Status: complete.**

One stage (`make.R` 29, `R/06-mcr.R`) implementing model reliance and model
class reliance, following Fisher, Rudin and Dominici (2019), *All Models are
Wrong, but Many are Useful*, JMLR 20(177). The task sheet's verify condition is
that the implementation reproduces a published or hand-computable result before
it is trusted on the real data, so the file is ordered to make that literal: the
validation suite runs first and halts the stage on any failure, and only then
does the script read anything from `data/`. Fifteen checks, fifteen passing.
Task 3.12 runs the bounds; this task establishes that the machinery is right.

---

## 1. What is being computed

Model reliance asks what a model loses when a variable is scrambled. For a
fitted model f and a variable or group of variables X₁,

  MR(f) = e_switch(f) ÷ e_orig(f),

where e_orig is the model's loss as fitted and e_switch is its loss when each
hospital's X₁ values are replaced by some other hospital's. MR = 1 means
scrambling X₁ costs the model nothing, so the model does not rely on X₁ at all.
MR = 1.2 means scrambling it raises the loss by a fifth.

Model class reliance takes the range of that ratio over a Rashomon set:
MCR⁻ is the smallest MR any near-optimal model has and MCR⁺ the largest. **MCR⁻
> 1 is the claim Plan §6 wants**, since it says every model the data cannot rule
out relies on the variable to some degree — no near-optimal model can ignore it.

The loss is the common-frame loss that defined the set at Task 3.9: unweighted
mean squared error against published PSI-90 on the fixed 2,569-hospital
evaluation frame, with each specification's predictions mapped back to that
scale first. Using any other loss would compute reliance for a model class
defined by a different criterion than the one that admitted its members, so the
stage asserts that the e_orig it computes equals the loss stored in
`data/rashomon-loss.rds` to within 1e-10. It does, for every specification
tested.

## 2. The estimator is exact, and no permutations are drawn

Fisher et al.'s switch estimator averages over every ordered pair of
observations rather than over sampled permutations,

  e_switch = 1/(n(n−1)) · Σ_{i≠j} L( f(x₁ⱼ, x₂ᵢ), yᵢ ),

which on 2,569 hospitals is 6.6 million model evaluations per specification per
variable group, and there are 194 specifications. Most implementations
approximate it by sampling permutations. That is not necessary here, because
every back-transform in this project puts the permuted prediction in one shape:

  p(i←j) = Bᵢ + Cᵢ · Vⱼ,

with B and C built from row i alone and V from row j alone. An identity-scale
fit gives Cᵢ = 1 and Vⱼ the permuted columns' linear predictor. The
errors-in-variables arm's re-shrinking, `gm + λᵢ(ŷ − gm)`, gives Cᵢ = λᵢ. A
log-scale fit gives Cᵢ = exp(aᵢ) and Vⱼ = exp(vⱼ), because exp(aᵢ + vⱼ)
factors. A component fit's un-z-scoring is affine and folds into B and C. Once
the prediction has that shape the double sum separates into sums over i and
sums over j, and e_switch is computable exactly in O(n):

  Σ_{i≠j}(dᵢ − CᵢVⱼ)² = n·Σdᵢ² − 2·Σ(dᵢCᵢ)·ΣVⱼ + ΣCᵢ²·ΣVⱼ² − Σ(dᵢ − CᵢVᵢ)².

Multiple imputation averages m predictions before the loss is taken, which
leaves an m × m cross-product matrix in the quadratic term rather than a scalar,
and is exact in the same way. So the numbers Task 3.12 reports carry no
Monte-Carlo error at all, and a specification's MR takes milliseconds once it is
fitted.

Splining does not complicate this. Permuting a hospital's ADI means permuting
every column of that variable's spline basis together, since the basis is a
row-wise function of the variable, so the group of basis columns is the thing
that moves.

## 3. The validation

| # | Check | Result |
|---|---|---|
| 1 | Hand-worked example, arithmetic printed in the log: y = (1,2,3,6), permuted contribution v = (1,2,3,4), so e_orig = 1, Σ_{i≠j} = 80 − 4 = 76, e_switch = 76/12, **MR = 19/3** | exact |
| 2 | Closed form against brute force over all n(n−1) ordered pairs, additive case | to 1e-9 |
| 3 | …with a row-varying C, the errors-in-variables re-shrink | to 1e-9 |
| 4 | …multiplicative, a log-scale fit | to 1e-9 |
| 5 | …with m = 5 completions averaged inside the loss | to 1e-9 |
| 6 | A variable with a zero coefficient returns MR exactly 1 | exact |
| 7 | A variable with a constant contribution returns MR exactly 1 | exact |
| 8 | Population case: y = x + e with Var(x) = Var(e) = 1 gives MR → 3, since e_switch = e_orig + 2·Cov(r,u) = 1 + 2 | 2.9931 at n = 4×10⁵ |
| 9 | Orthogonal design identity: MR = 1 + 2·β₁²·Var(X₁) ÷ e_orig | to 1e-4 |
| 10 | Sampled permutations converge to the closed form | 3.5931 against 3.5973 at R = 20,000 |
| 11 | MR is invariant to rescaling the loss | exact |
| 12 | Permuting a zero-width block leaves the loss alone | exact |

The hand-worked case is the one that satisfies the verify condition most
directly: the log prints the arithmetic so a reader can check 19/3 with a
calculator, and it is printed before the script has opened a single project
file. Checks 8 and 9 are the population identities, derived from the fact that
for squared-error loss e_switch − e_orig = 2·Cov(r, u), where r is the residual
before the permuted block contributes and u is that block's contribution; the
identity is worth recording because it says MR > 1 exactly when the block's
contribution is positively correlated with what is left to explain.

Full table in `output/tables/mcr-validation.csv`, regenerated on every run.

## 4. The bound is over an enumerated class, and that shapes the claim

MCR⁻ and MCR⁺ here are the minimum and maximum of MR over the 194
specifications Task 3.10 admitted, not over a continuous model class. That is
what the task sheet asks for — "model class reliance over the constructed set" —
and it is what Task 3.12 will report, but the direction of the approximation has
to be stated with the result rather than discovered later.

Taking the minimum over a subset of a class can only overstate the true minimum.
So the MCR⁻ this implementation returns is an **upper bound on the MCR⁻ of any
richer class** containing the same specifications, and a finding of MCR⁻ > 1 is
therefore a statement about the enumerated set, not a proof that no unenumerated
near-optimal model could ignore community disadvantage. MCR⁺ runs the other way
and is a lower bound, so it is conservative. Task 3.12 must state its MCR⁻
claim as ranging over the registry's 3,496 pre-registered specifications, which
is the honest scope, and not as a claim about all possible models. Task 3.10 §1
supplies the natural companion fact, which does not depend on the enumeration in
the same way: no Block-A specification — a model with no community disadvantage
in it at all — is inside the set at the primary or metro-area tolerance.

## 5. The smoke run

Eight members spanning the set's axes, end to end:

| Spec | Form | Reliability | Grain | Scale | e_orig | MR, disadvantage block | MR, ADI alone |
|---|---|---|---|---|---|---|---|
| 418 (the ERM) | spline | EIV | catch-county | identity | 0.031883 | 1.183 | 1.030 |
| 340 | linear | EIV | HSA | identity | 0.032984 | 1.179 | 1.003 |
| 74 | linear | EIV | catch-tract | identity | 0.033021 | 1.147 | 1.002 |
| 1824 | spline | EIV | catch-tract | log | 0.033054 | 1.126 | 1.005 |
| 79 | spline | unweighted | catch-county | identity | 0.032734 | 1.122 | 1.008 |
| 80 | spline | unweighted | catch-county | identity | 0.032606 | 1.115 | 1.008 |
| 3 | spline | unweighted | catch-tract | identity | 0.033093 | 1.107 | 1.004 |
| 4 | spline | unweighted | catch-tract | identity | 0.032953 | 1.100 | 1.004 |

Every e_orig equals the stored common-frame loss exactly. `mcr_over_set()`
returns MCR⁻ = 1.100 and MCR⁺ = 1.183 over these eight, with all eight above
one. That is a smoke run on a handful chosen to span the axes, not a result;
Task 3.12 runs all 194.

Two things in it are worth carrying forward anyway. The reliance numbers are
tight across very different specifications, between 1.10 and 1.18, while Task
3.10 found those same specifications disagreeing about the p10→p90 contrast from
−0.37 to +0.88 SD. That is the distinction Task 3.10 §5 anticipated: a
specification can put its joint contrast near zero, or negative, and still lose
a tenth of its fit when community disadvantage is scrambled, because the
contrast reads the fitted surface at one corner of the covariate space while
reliance integrates over the whole of it. And ADI alone carries almost no
reliance, 1.002 to 1.030, against 1.10 to 1.18 for the block — the collinearity
Task 3.1 quantified, showing up exactly where Plan §6 predicted it would: the
defensible claim is about community disadvantage, not about any one measure of
it.

## 6. Files

```
R/06-mcr.R                              new -- make.R stage 29
make.R                                  stage 29 added
output/tables/mcr-validation.csv        15 checks, got / want / tolerance / pass
output/tables/mcr-smoke.csv             8 specs end to end, e_orig against the stored loss
output/tables/task3.11-mcr.txt          stage log, validation arithmetic included
```

The functions Task 3.12 will call are `model_reliance()` (the estimator),
`mr_spec(spec, vars)` (one specification, one variable group, on the common
frame) and `mcr_over_set(spec_ids, groups, label)` (returns MCR⁻, MCR⁺, the
specifications attaining each, the median, the share above one, and every
model's MR). `make.R --stage 29`: `ok`, provenance `consistent`, 15.2 s.
Provenance table stays at 33 rows.

## 7. Next

**Task 3.12 — run MCR, scoped.** Block B is primary, individually and as a
group, with the group bound the one that matters. Block A is a secondary output,
reported after Block B and never as the headline. Block C gets Rashomon
coefficient ranges only and no MCR, which `admission-gates.md` §4 already
forbids for tort and rev 2 extended to coding intensity and contract labor.
Every bound is stated as a claim about the model class rather than about the
world, the set's width from Task 3.10 appears alongside, and if MCR⁻ > 1 holds
on the composite it is stated as a lower bound, since reliability shrinkage
attenuates the gradient toward zero (`plan-amendments.md` §1.3).
