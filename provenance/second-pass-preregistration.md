# Second pass — pre-registration

**Date:** 2026-10-01 · **Task:** S0.2 · **Status: fixed before any corrected
output was computed.** Carl accepted every default in the second-pass task
sheet's Table 2 on 2026-10-01; this file turns each one into a rule a script can
apply, and fixes the invariants the repaired stages must pass.

It goes in alone, as `cluster-preregistration.md` and
`archetype-preregistration.md` did, so that the commit timestamp shows these
choices preceded their results. Every analysis below is **post-review** and the
report labels it so.

What had been seen when this was written: the whole September 30 draft and its
outputs (archived at Task S0.1), the critical review of 2026-10-01, and the
checks recorded in the task sheet's Table 1. Those include two stored numbers
the repairs will touch: SVI theme 3's median marginal reliance over the 194
members (1.0307 in `mcr-per-model.csv`, 0.9976 in the defective
`tis-per-model.csv`), and the count of disagreeing pairs (7,040 of 7,360). No
repaired TIS, payment, validation or sensitivity output had been computed, and
no Connecticut covariate had been recomputed.

Seed for every new random step: **20261001**, offset per draw or repeat as each
stage already does (`SEED + b`).

---

## 1. Anchor specifications

The overall empirical risk minimizer, spec 418, uses the errors-in-variables
outcome built on λ. The second pass makes the published score primary (Task
S2.1), so the analyses that need one or two representative models use
published-score members instead, chosen by rule:

| Anchor | Rule | Spec today |
|---|---|---|
| P-best | Lowest excess loss among set members with `reliability = unweighted` | 382 (ABC, spline, catch_county, complete, identity) |
| P-median | Median excess loss among those 65 members (upper median) | 610 (ABC, spline, hsa, omit, identity) |
| M-best | Lowest excess loss among unweighted members with `missing = mi` | 80 (ABC, spline, catch_county) |
| M-median | Median excess loss among those 17 members (upper median) | 157 (ABC, spline, hosp_county) |

If Task S0.4 adopts `analytic-v2` and the set changes, the rules apply to the
new set and the note records the new IDs. The M anchors exist because the
contract-labor shift (sec 7) moves imputed values, which P-best and P-median
never use.

## 2. Invariants the repaired code must pass

Each is shown to **fail on the code it replaces** before it counts (standing
rule 3).

**Direct and shared reliance (S1.1),** on every one of the 736 composite
specifications and every imputation completion:

1. The reconstructed unperturbed prediction equals the model's own prediction
   within 1e-10 (maximum absolute difference).
2. The baseline loss equals the loss in `rashomon-loss.rds` within 1e-10
   (relative).
3. Marginal reliance equals stage 30's value in `mcr-per-model.csv` within 1e-9
   for all 7,360 specification-by-measure pairs.

Plus two synthetic tests: a real proxy (X2 = 0.8 X1 + 0.6 ξ, outcome coefficient
on X2 exactly 0) must give X2 direct reliance 1 within 1e-3 and TIS below X1's;
and the two-predictor case (independent standard normals, y = X1 + X2 + ε,
n = 5,000) must give marginal reliance above 2.8 for both predictors.

**Counterfactual rank (S1.3):** a counterfactual score equal to the actual score
gives a payment difference of exactly 0 for every hospital, on a test vector
with ties, with values at both winsorization bounds, and under both the linear
and the threshold rate.

**Finite returns (S1.4):** at an improvement smaller than the smallest gap
between adjacent standardized scores in the draw, the return is 0 for every
hospital; the return reproduces a hand computation for three hospitals named in
the task note (one near the median score, one at a winsorization bound, one with
no infection measures) to the cent.

**Rate curves (S1.5):** a test fails if `k` changes anything but the rate; at
common endpoints the three curves' total payments differ; rescaled, each equals
the linear base's total to the dollar in every draw.

## 3. Finite payment returns

- **Improvement sizes:** Δ = 0.01, 0.025, 0.05 and 0.10 PSI-90 units.
  **Δ = 0.05 is primary** (about a quarter of the published score's SD of 0.19,
  and 5% of its mean of 1.00).
- **Computation, within each payment draw:** the hospital's published PSI-90
  falls by Δ; every other hospital's published value, and the draw's
  winsorization bounds, mean and SD, are held fixed; score, position (average
  rank), rate and payment are recomputed; the return is the payment change
  divided by Δ. Hospitals without infection measures are scored on PSI-90 alone
  by the existing `score_of()`.
- **All-improve case:** every hospital falls by Δ = 0.05, scores restandardized
  from the shifted values; reported as the change in total payment.
- **Regressivity:** amendment 9's rule is applied unchanged to the per-NPR
  finite return at Δ = 0.05 in the base scenario. "Structurally regressive"
  means its concentration index is negative with a 95% simulation interval
  excluding zero, as a claim about the formula's arithmetic.
- **The old quantity** R × w × 0.039 is kept as the *revenue exposure
  coefficient*, in dollars per unit of percentile position, in supplementary
  tables only.

## 4. Payment scenarios

- **Rate curves:** r(P) = 0.001 + 0.039 P^k for k = 0.5 (concave) and k = 2
  (convex), sharing the linear base's endpoints of 0.1% and 4.0%. Each is also
  run rescaled by a per-draw factor that makes its total payment equal the
  linear base's.
- **Revenue scenarios:** commercial revenue share derived from day share s with
  a commercial-to-public per-day price ratio ρ, as ρs / (ρs + 1 − s), for
  ρ = 1.5 and 2.0; eligible revenue is NPR times that share.
- **Threshold:** unchanged arithmetic, relabeled a hypothetical stress test.
- **Distance from the best measured score** replaces "improvement headroom" as
  the name of the existing headroom rank; the rank itself is unchanged.

## 5. Direct reliance, tags and the TIS ranking

- **Practical threshold:** a measure's direct reliance counts as above 1 only
  if its lower bound over the set is **at least 1.005** at the primary tolerance
  **and** at the metropolitan tolerance.
- **Tags** (the four-tag rule of 2026-09-29 with the threshold in place of 1):
  *essential* = direct lower bound ≥ 1.005 and median shared share < 0.5;
  *substitutable* = direct lower bound ≥ 1.005 and shared share ≥ 0.5;
  *useful* = direct lower bound below 1.005 but TIS lower bound ≥ 1.005;
  *optional* = neither.
- **Stability:** tags at all three tolerances (the sets nest), and an
  HSA-cluster bootstrap, B = 200, of P-best and P-median, reporting for each
  measure the share of replicates with direct reliance ≥ 1.005.
- **Signed flows** and TIS_net are reported beside TIS everywhere.
- **Placement:** the TIS ranking and tags go in the technical supplement only,
  labeled exploratory, whatever they show. Data-prioritization claims in the
  main report rest on sec 6.

## 6. Geographic validation (stage 40)

- **Candidate models.** Each takes P-best's settings (spline, unweighted,
  catch_county, complete, identity) and its Block A and Block C terms; only the
  Block B content varies:
  (a) no Block B; (b) all of Block B as in P-best; (c) ADI only;
  (d) SVI themes 1–4 and limited-English share;
  (e) the measures tagged essential in S1.2, if that set differs from (d).
- **Folds.** New-area: five folds by state, the 51 state codes partitioned at
  random, 20 repeats. Within-area: five random hospital folds, 20 repeats.
- **Inside each training fold:** spline knots, standardization and any
  imputation are fitted on training hospitals only.
- **Loss:** mean squared error of published PSI-90 on held-out hospitals.
- **Practical tolerance:** a reduced dataset "loses nothing" if its mean
  new-area held-out loss is within **1% of model (b)'s**. Differences are
  reported with their 2.5th–97.5th percentiles over the 20 repeats.

## 7. Data sensitivities

- **Contract labor (S3.1):** imputed values only are shifted by δ times the SD
  of observed contract-labor share, δ = −1, −0.5, +0.5, +1, on M-best and
  M-median; reported: community share of variation and disadvantage-group
  reliance at each δ.
- **Suppression (S3.2):** every suppressed HSAF cell set to 1, 3, 5.5 and 10
  discharges, and 20 draws of a uniform integer on 1–10; at county and tract
  grain; measured on P-best's loss, the joint contrast, and hospital ranks on
  the community contribution; the bottom decile by mapped discharge weight
  reported separately.
- **Contrast support (S2.5):** material deprivation = ADI, ICE, SVI themes 1
  and 4, uninsured share; demographic composition = SVI themes 2 and 3,
  limited-English share; rurality and primary-care density reported apart.
  Distance is Mahalanobis over the ten disadvantage measures on the model
  frame. The material-deprivation score is the mean of those measures
  standardized and signed by `DIS_SIGN`. The rewrite uses an observed contrast
  wherever fewer than **5%** of observed catchments are as far from the center
  as the synthetic profile.
- **Track bands (S3.4):** (i) margin quartiles (Q1 low, Q2–Q3 middle, Q4 high)
  with the original star bands; (ii) original margin terciles with star bands
  1 / 2–4 / 5; (iii) both. Each reported with its full nine-cell table and
  diagonal share against the original 50% criterion.
- **Connecticut (S0.4):** adopt `analytic-v2` if the repaired allocation changes
  **any** frame hospital's value on any column by more than 1e-8 in absolute
  terms. Otherwise keep v1 and record the null.

## 8. The freeze rule

`provenance/amendments.md` gains a second rule, dated today: a repair of a
**defect in how the frozen file was built** is permitted after results have
been seen, when the amendment records the defect, the evidence for it, the old
and new values and the new hash; the old results stay in the archive; and every
downstream stage reruns. A repair is not a choice: it may not be selected for
its effect on a result, which is why sec 7's Connecticut rule is fixed here,
before the comparison exists.

## 9. What would count as violating this

Changing any number above after the output it governs has been computed;
adding a candidate model to sec 6 or a band definition to sec 7 after seeing
the others; reading a repaired output before its sec 2 invariants pass. Any
change goes in a dated amendment at the end of this file stating what had been
seen, as the Rashomon pre-registration's amendments do.

## Amendments

### Amendment 1 — reading the proxy test (2026-10-02, Task S1.1)

Sec 2's proxy test says the outcome coefficient on X2 is "exactly 0". Read as
the **model's** coefficient, the test passes (X2's contribution is identically
zero). Read as the **true** coefficient, with the model fitted (estimate 0.007
at n = 200,000), X2's direct reliance still passes, but its TIS is 2.276
against X1's 1.718. The sender term hands a proxy with any nonzero coefficient
the signal's whole Δ. Carl chose the first reading as the gate, with the fitted
case run and logged every time as a known property of TIS (task S1.1 note
sec 4). It is one more reason the ranking stays exploratory and supplement-only
(sec 5).

**What had been seen:** the two synthetic results above, computed in a scratch
prototype. No repaired output on project data had been computed when the choice
was made. The TIS formula is unchanged.

### Amendment 2 — the ownership sensitivity (2026-10-05, Task S3.3)

Task S3.3 asks for "a limited sensitivity with ownership and system membership
added to Block A on the ERM and median-member specifications". Sec 7 did not fix
it. It is fixed here before it runs.

- **Anchors:** P-best (spec 382) and P-median (spec 610), the published-score
  anchors of sec 1. The second pass reads "ERM and median member" as these,
  as sec 1 does for every other anchored analysis.
- **Added terms**, both from `analytic-v2.rds`, entered in Block A unstandardized:
  ownership as two indicators, government and proprietary, with voluntary
  nonprofit as the reference (`ownership_code` G / P / V, from the FY 2026
  Impact File); and system membership as one indicator (`system_member`, from
  Hospital Enrollments and Hospital All Owners, 2026-07-31). The 26 frame
  hospitals with no owner record are coded non-members in the frozen file and
  stay so.
- **Frame and everything else unchanged:** the same fit frames (no frame
  hospital lacks either field), the same evaluation frame of 2,569, the same
  standardization, knots and contrast profile. The augmented fit differs from
  the anchor only by the three columns.
- **Reported, for each anchor, as fitted and augmented:** common-frame loss;
  the joint p10 → p90 contrast with its standard error; the community block's
  LMG share (Block A with the added terms as structure); the
  disadvantage group's MR on the common frame; and the added terms'
  coefficients with standard errors. No threshold; the result is described,
  not tested.
- **Check first:** the as-fitted anchor reproduces its stored loss
  (`rashomon-loss.rds`, 1e-10), contrast (`spec-results.rds`, 1e-8) and MR
  (`mcr-per-model.csv`, 1e-9).

**What had been seen:** that both fields are complete on the 2,569-hospital
frame (G 332 / P 514 / V 1,723; members 1,878, non-members 691, 26 of them
without an owner record). No model with either field had been fitted.
