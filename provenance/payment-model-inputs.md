# Payment-impact model — inputs and calibration protocol

**Date:** 2026-09-24 · **Task:** 4.1 · **Status: fixed before any simulation is
run.** Task 4.2 implements this document. It does not change it.

What had been looked at when this was written: the CASH2 memo (final, v6
"recalibrated scenario analysis", `CASH memo/CASH2 memo - Final.pdf`), its
parameter register (`CASH memo/Models/vbp_model_parameter_table.md`), every
Phase 3 note, and the **structure** of the FY 2026 HACRP file: its columns,
its Payment Reduction counts, and where the penalty cut falls (§5.1). No
agreement between any pipeline output and the observed penalties has been
computed. No payment has been simulated.

---

## 1. What the model is for

One question, from Plan §4: **does a Q-HIP-style incentive send money toward or
away from the hospitals with the most improvement headroom?** Plan §74 names the
mechanism. Q-HIP pays a percentage of the commercial fee schedule, commercial
share runs with resources, and resources run with safety. If both run the same
way, the hospitals with the most room to improve have the least incentive money
to improve with. That is a property of the formula and is demonstrated as
arithmetic.

The model does **not** re-run the CASH2 ROI. QI cost, SSI incidence, cost of
harm and the QALY term are not inputs here (Plan §6: the CASH2 models are
consumed as given, not revised). This is a payment model, not a return model.

Two things change from CASH2, both forced by Phase 3:

- **Hospitals, not archetypes.** Task 3.16 found a gradient, not strata, and
  the Tracks' bed sizes (175 / 300 / 500) failed outright (median 151 / 190 /
  144). Every per-Track input is replaced by a per-hospital one. This is the
  "hospital-level calibration" the CASH2 verification review deferred to P2.
- **PSI-90, not SSI.** The Phase 3 relationships are estimated on PSI-90. The
  lever the model moves is PSI-90's contribution to the safety score.

## 2. The model

For hospital *i* in draw *b*:

```
R_i      = NPR_i × c_i                                    eligible commercial revenue
S_ib     = w × Z_PSI,ib + (1 − w) × mean(Z_HAI,i)         safety score (lower = safer)
P_ib     = 1 − rank(S_ib) / n                             position in the frame, best = 1
r_ib     = 0.1% + 3.9% × P_ib                             bonus rate on the band
Pay_ib   = R_i × r_ib                                     bonus dollars
Open_ib  = R_i × (4.0% − r_ib)                            band dollars not yet earned
Marg_i   = R_i × w × 3.9%                                 bonus per 100% relative PSI-90
                                                          improvement (CASH2 marginal rule)
```

`Z_PSI,ib` is the HACRP-style winsorized z-score of the hospital's PSI-90 in
draw *b* (§3). `Z_HAI,i` are the hospital's observed HACRP W-Z scores for the
five HAI measures, held fixed. When a hospital has no HAI scores, `S = Z_PSI`;
when it has some, the mean is over those available, as HACRP does.

`Marg_i` is CASH2's marginal-bonus formula (parameter register §F: composite
improvement = relative reduction × attribution; marginal rate = composite
improvement × band width) applied to PSI-90 and a hospital-level revenue. It
does not depend on the draw.

**Disadvantage-associated payment.** Each draw also computes `Pay` with the
hospital's Block B contribution (3.13's contribution space,
`v_B = X_B β_B`) replaced by the frame median contribution. The difference is
the bonus the drawn model associates with catchment disadvantage. It is an
associational counterfactual under that model, not an effect, and it inherits
the Rashomon set's width on the disadvantage contrast (3.10: −0.37 to +0.88 SD,
straddling zero). It will straddle zero too, and is reported that way.

## 3. What each draw propagates

Four sources of statistical uncertainty are drawn, in this order:

| # | Source | Draw | From |
|---|---|---|---|
| U1 | Specification | spec *m* uniform over the **194 composite Rashomon members, primary ε** | 3.9 / 3.10, `data/rashomon-set.rds` `$primary$spec_ids` |
| U2 | Parameters | β ~ MVN(β̂ₘ, Vₘ); Rubin-pooled V for MI specs | refit through the 3.6 harness, `R/04-spec-curve.R` |
| U3 | Reliability | θᵢ ~ N(psi90ᵢ, vᵢ), the posterior implied by the published CI | 2.2, `v_i`, `lambda_i`, `tau2` in `analytic-v1.rds` |
| U4 | Residual | hospital-level residual from spec *m*, for predictive draws only (§5.3) | spec *m*'s fitted residual variance |

**U3 is the task sheet's rev 3 requirement.** λᵢ runs 0.091 to 0.963 in the
frame. A simulation that fixes PSI-90 at its published value treats a
hospital with λ = 0.09 as measured as precisely as one with λ = 0.96, and
understates payment spread most for the low-volume hospitals the regressivity
argument is about. 4.2 runs the model **twice, with U3 and with θᵢ fixed at the
published value**, and reports the difference. The U3 run is primary.

Structural choices are **not** drawn. They run as a scenario grid outside the
Monte Carlo (§4.2), as CASH2 ran them, so that a reader can see which result
belongs to which assumption rather than getting one interval that mixes both
kinds of uncertainty.

## 4. Parameters

Every row cites the CASH2 memo, its parameter register, or a Phase 3 (or
frozen-file) output by name. There is no other kind of row.

### 4.1 Base case

| # | Parameter | Value | Source |
|---|---|---|---|
| P1 | Band floor | 0.1% of commercial fee schedule | CASH2 Table 3, Table A2 (memo ref 7, Hsu et al. 2024) |
| P2 | Band ceiling | 4.0% | CASH2 Table 3, Table A2 |
| P3 | Direction | upside only, no penalty | CASH2 Table 3 |
| P4 | Score-to-rate shape | linear across the band | CASH2 §4 ("the score shift maps linearly onto the band"), Table C4 base |
| P5 | PSI-90 attribution weight *w* | 15% | CASH2 Table A2, §4 (proxy from memo ref 24, CMS HACRP measure weighting) |
| P6 | Eligible share of commercial book | 100% | CASH2 §4 ("the base case assumes the full commercial book is bonus-eligible") |
| P7 | Period | one year, single period | CASH2 §4 |
| P8 | Net patient revenue | `net_patient_revenue`, per hospital | `analytic-v1.rds`, Block A (HCRIS FY 2023, Task 2.3) |
| P9 | Commercial share, non-safety-net | 37% of NPR | CASH2 parameter register §I (KFF, non-SNH commercial ≈ 35–40%; midpoint used there) |
| P10 | Safety-net commercial factor | 0.40 × P9 = 14.8% | CASH2 §4, Table B1, parameter register §I |
| P11 | Safety-net definition | `dsh_pct` ≥ 0.370 (top quartile) | Task 3.16, `archetype-preregistration.md` §2 |
| P12 | Model set | 194 composite Rashomon members | Tasks 3.9–3.10 |
| P13 | Reliability | `psi90`, `v_i`, `lambda_i`, `tau2` | Task 2.2 |
| P14 | Published-scale mapping | μ + λᵢ(ŷ − μ) for EIV specs | Task 3.9 (the re-shrink step) |
| P15 | Block B contribution | `v_B = X_B β_B` | Task 3.13 |

**On P5.** CASH2's 15% was SSI's share of the Q-HIP composite. It is applied
here to PSI-90 because of where CASH2 got it: the HACRP weighting, in which
PSI 90 and SSI each carry an equal 1/6. The proxy's source treats the two
measures identically, so it moves across unchanged. The HACRP value, 16.7%, sits
inside CASH2's 10–20% range.

**On P9–P10.** CASH2 used illustrative Track revenues ($80M / $200M / $400M). Task
3.16 showed the bed sizes behind them fail, so revenue now comes from each
hospital's own NPR, times a commercial share from the same register that CASH2's
safety-net scenario used. The flat 37% is crude, and it is CASH2's.

**On P4 and the Track rates.** CASH2 set expected bonus rates of 0.5% / 2.0% /
3.5% by Track as "archetype inference". The linear map puts a hospital at the
middle of the bottom, middle and top thirds at 0.75% / 2.05% / 3.35%, within a
quarter point of each. The per-Track rates are therefore not carried; the
linear map reproduces them from P1, P2 and P4, and needs no Track.

### 4.2 Scenario grid (structural, not drawn)

| # | Scenario | Values | Source |
|---|---|---|---|
| S1 | Attribution *w* | 10%, 15%, 20% | CASH2 Table A2 range, Figure 2 |
| S2 | Shape | linear; concave ×0.5; convex ×2.0 | CASH2 Table C4 |
| S3 | Threshold | none (base); bottom 25% earn nothing, rest linear | CASH2 Table 3, "pay-for-performance hospitals earning a bonus: 75%" |
| S4 | Payer mix | factor 0.40 (base); factor 1.0 (no safety-net difference) | CASH2 §4, Table B1 |
| S5 | Eligibility | full book (base); zero Q-HIP | CASH2 §4, Table B1 bracket |
| S6 | Scorecard | six HACRP measures (base); PSI-90 only (*w* = 1) | §6, D1 |
| S7 | Model set | primary ε (194); metro-cluster ε (319) | Task 3.9 amendment 2, 3.10 |

**Two things the grid shows before it is run, stated now so they are not
discovered later.**

1. **S2's multipliers cannot move the regressivity measure.** CASH2's concave
   and convex shapes scale every hospital's marginal slope by the same factor.
   A rank-based concentration index (§7) is unchanged by a common factor.
   They move dollar levels only. The shape that could move the answer is one
   whose slope varies with position, and CASH2 does not specify one.
2. **S3 is the only sourced position-dependent shape.** Table 3's 75% bonus
   rate implies a quarter of hospitals earn nothing. That makes the Q-HIP
   design a mirror of HACRP's worst-quartile cut, which is worth saying in the
   report.

### 4.3 Carried from CASH2 but not used

| CASH2 input | Why not |
|---|---|
| `commercial_revenue` by Track | replaced by P8 × P9–P10 (Track sizes fail at 3.16) |
| `expected_bonus_rate` by Track | reproduced by P1, P2, P4 (§4.1) |
| `hospital_beds`, `annual_procedures` | the Tracks are not strata (3.16) |
| SSI incidence, reduction, cost, QALY, QI cost | ROI is not re-run (Plan §6) |
| Participating hospitals (743), admissions share (74–89%) | describe Elevance's footprint, which is not identifiable by hospital. Used in the report as context only |

**Every dollar figure is a national what-if.** Q-HIP runs in Elevance's states
and on Elevance's book. Which hospitals participate is not public, so the model
applies a Q-HIP-style design to every hospital in the frame, as if all its
commercial payers used it. A uniform eligible fraction below 1 would scale
every dollar figure down and **leave every rank-based result unchanged**. The
regressivity finding does not depend on P6; the dollar amounts do.

## 5. HACRP calibration protocol

### 5.1 What HACRP is, and what is not being claimed

**HACRP and Q-HIP are different formulas.** The calibration checks the
machinery, not the substitution of one programme for the other. It asks one
question: **does the pipeline, fed the HACRP rule, reproduce who actually got
penalised in FY 2026?** A pass says the scoring, ranking and
reliability-propagation code does what it claims on a formula whose output is
published. It says nothing about whether Q-HIP pays what the model says it
pays. Q-HIP's scoring function is proprietary, and no published payment data
exist to calibrate against.

| | HACRP (FY 2026) | Q-HIP (as modeled) |
|---|---|---|
| Payer | Medicare | Elevance, commercial |
| Direction | penalty | bonus, upside only |
| Base | Medicare IPPS payments | commercial fee schedule |
| Size | 1%, all or nothing | 0.1–4%, continuous |
| Rule | worst quartile of Total HAC Score | linear in score position |
| Measures, weights | six, equal, published | proprietary; six-measure stand-in, *w* = 15% |
| Observable | yes, per hospital | no |

What the machinery shares: the six measure scores, the winsorized z-scores, the
combination into one score, ranking across the frame, and the propagation of
PSI-90 reliability into rank. What it does not share: the payment rule. The
HACRP check exercises everything upstream of the payment rule.

**Structure of the file, as inspected for this protocol.** 3,055 hospitals:
719 penalised, 2,293 not, 43 N/A. 2,929 carry a Total HAC Score. The published
Total HAC Score equals the mean of the hospital's available W-Z scores to
within 8 × 10⁻⁵, rounding. The lowest penalised score is 0.3799, the highest
unpenalised 0.3792, and the 75th percentile of scored hospitals is 0.3792. So
the rule is "Total HAC Score above the 75th percentile of scored hospitals".
In the 2,801-hospital frame: 664 penalised, 2,097 not, 40 N/A.

Calibration uses **`psi90_hacrp`**, the value HACRP scored, not the Care
Compare value. They differ by a mean +0.00191 (2.2).

### 5.2 C1 — deterministic reproduction (a gate)

Feed the pipeline the observed inputs and the HACRP rule. No draws.

- **C1a**, from the file's W-Z scores: recompute Total HAC Score and the
  worst-quartile flag.
- **C1b**, from raw measure values: winsorize PSI-90 and each SIR at the 5th
  and 95th percentiles, z-score, average, rank, flag. This is the path the
  Monte Carlo actually uses for PSI-90.

**Pass: all 719 penalised and 2,293 unpenalised reproduced, on the full
3,055.** Every mismatch is listed by CCN with its reason. **C1 is a gate. The
Monte Carlo does not run until it passes or every mismatch is explained.**
Explained means a documented CMS exclusion, not a tolerance.

### 5.3 C2 — model-driven reproduction (reported, not a gate)

C1 shows the code applies the rule. C2 shows how much of the penalty
assignment the Phase 3 machinery recovers when it has to predict PSI-90 rather
than read it.

For each draw: PSI-90 is replaced by a **predictive draw on the published
scale.** Take spec *m*'s prediction from covariates (U1, U2), add a residual
(U4), and map to the published scale through P14, which is where reliability
shrinks low-volume hospitals toward the mean. The five HAI W-Z scores stay
observed. Apply the HACRP rule. Over draws, each hospital gets **p̂ᵢ, its
probability of being penalised.**

Reported, on the calibration frame (Q-HIP frame ∩ HACRP-scored; 4.2 prints
the count):

| # | Check | Statistic | Reads as good |
|---|---|---|---|
| C2.1 | Calibration in the large | Σp̂ᵢ against the observed penalised count | within ±10% |
| C2.2 | Calibration by decile | observed rate vs mean p̂ in ten p̂-deciles; calibration slope | slope 0.8–1.2 |
| C2.3 | Discrimination | AUC of p̂ against observed | reported; no bar |
| C2.4 | PSI-90 coverage | share of observed `psi90_hacrp` inside its 90% predictive interval | 85–95% |
| C2.5 | Reliability | C2.1–C2.4 by λ quartile | reported; no bar |
| C2.6 | Without reliability | C2.1–C2.4 with the P14 re-shrink step removed | reported beside the main result |

**What to expect, stated now.** PSI-90 is one of six measures, and Phase 3's
near-optimal models explain about 13% of its variance (3.9, R² 0.129). C2.3 will
be modest, and a modest AUC is a finding about how little of the penalty the
covariates determine, not a pipeline fault. C2.1, C2.2 and C2.4 are the checks
on the machinery. They ask whether the predictive distribution is honest about
its own spread. That is the property the Q-HIP simulation depends on.

**The rule for a bad result.** Nothing in this document is changed after C2 is
seen. No weight, residual variance, band or model is adjusted to improve C2.
A C2 result outside the "reads as good" column is reported in 4.2's note and
in report §8, with the reason if one is identifiable. 4.2 still runs the Q-HIP
simulation, and its outputs carry the C2 result beside them.

### 5.4 Order

1. C1 passes, or every mismatch is explained. (4.2)
2. The draw count is fixed by the convergence rule in §8. (4.2)
3. C2 is run and reported. (4.2)
4. Only then the Q-HIP simulation. (4.2)

The commit timestamps on 4.2's note are the evidence for this order.

## 6. Structural choices to state, not parameters

These are the places where the model makes a choice that is not a number from
CASH2 or Phase 3. Each is named in the report where its result appears.

- **D1. The six HACRP measures stand in for Q-HIP's proprietary scorecard.**
  Hsu et al. describe a composite safety scorecard. Its measures and weights
  are not published. The HACRP set is the nearest published composite, and it
  is the one CASH2's attribution weight was built from. S6 brackets it with a
  PSI-90-only scorecard, which is the maximum channel for the Phase 3
  relationships.
- **D2. Score position is a percentile of the frame.** Rank-based scoring is
  how HACRP works and is the reading of "performance tier" in the CASH2 parameter register §F that
  reproduces its Track rates (§4.1).
- **D3. HAI scores are held at observed values.** Phase 3 modelled PSI-90, not
  HAIs, so no relationship or reliability is available for them. **The
  simulated spread is therefore a lower bound**, and the report says so.
- **D4. The frame.** 3.9's composite common frame (n = 2,569, complete-case
  A+B+C), less hospitals with `net_patient_revenue` ≤ 0 or `flag_npr_tiny`.
  Every hospital removed is listed with its reason.

## 7. Outputs 4.2 produces for 4.3 and 4.4

Per hospital, over draws: `Pay`, `Open`, `Marg`, disadvantage-associated
`Pay`, `P`, and θ. From these:

- **Strata (4.3).** 3.16 said gradient, not strata, so results are reported
  along the gradient, never by Track:
  1. the nine star-band × margin-tercile cells from 3.16, labelled as cells
     on a gradient;
  2. the safety-net flag (P11), the memo's best-supported claim;
  3. **quintiles of the model-implied Block B contribution** `v_B`, recomputed
     in each draw, so that stratum membership carries model uncertainty. ADI
     quintiles are reported second, for readability. They are not primary,
     because 3.14 found ADI's reliance is mostly on loan from its neighbours.
- **Regressivity (4.4).** The **concentration index** of `Marg` and of `Open`,
  with hospitals ranked by improvement headroom (θ, worst first). Then again,
  ranked by `v_B`. A negative index means incentive dollars concentrate among
  the hospitals with the least headroom. Rank-based and benchmark-free, so no
  "achievable" PSI-90 needs inventing. Reported with its interval over draws,
  per scenario. **"Structurally regressive" is a claim about this arithmetic
  and is stated as one** (Plan §9).

## 8. Seed and draw count

- **Seed: 20260924**, set once at the top of `R/09-payment-sim.R` and printed
  in its output.
- **Draw count** starts at B = 250 and doubles until, for every headline
  output (the C2.1 expected count, each stratum's mean `Pay`, and each
  concentration index in the base scenario), the Monte Carlo standard error is
  below 5% of that output's standard deviation across draws. The B reached,
  and the MCSE table, go in 4.2's note. B is not chosen by habit.

## 9. Open for Carl

Neither blocks 4.2. The document above takes the first option in each.

1. **Commercial share (P9–P10).** CASH2's flat 37% with a 0.40 safety-net
   factor is crude. Raw HCRIS (`hcris_raw_hosp10_fy2023`, already registered)
   carries Medicare and Medicaid days on worksheet S-3, from which a
   per-hospital non-public share could be built. That would be a better
   estimate. It would also be a new derived parameter from an existing source,
   which is what this task's verify condition asks to avoid. **Recommendation:
   keep CASH2's values as the base and add the HCRIS share as a scenario only
   if the Foundation lead wants hospital-level payer mix in §8.**
2. **Scorecard (D1 / S6).** Six-measure base, PSI-90-only bracket, as written.
   The reverse ordering would put more of the Phase 3 relationships into the
   headline and less of the programme's likely design.

---

## 10. Amendments

Dated and numbered. **All were made before any simulation was run**, and are
committed alone ahead of `R/09-payment-sim.R`, as 3.9's amendment 1 was.

### Amendment 1 — per-hospital commercial share (2026-09-24, Carl's decision on §9.1)

**P9–P10 are replaced.** The eligible share of NPR is each hospital's own
**non-public share of inpatient days**, from raw HCRIS FY 2023
(`hcris_raw_hosp10_fy2023`, already registered at 1.6), worksheet S-3 Part I:

```
c_i = 1 − (L14 c5 + L14 c6 + L14 c7 + L2 c6 + L2 c7) / L14 c8
        Title V, XVIII and XIX days (line 14), plus Medicare and Medicaid
        managed-care days (line 2, "HMO and other"), over total patient days
```

Line 2 matters. Line 14's Title XVIII column is fee-for-service only, and
Medicare Advantage is a median 15% of a hospital's days. The PUF carries only
line 14, so the raw file is used. One report per CCN is kept by the 1.6 rule
(non-blank, then longest period, then latest end).

What was seen before this amendment, and nothing else: in the 2,801 frame,
**c_i is available for 2,798; median 0.240 (IQR 0.187–0.317); safety-net
0.198 against 0.253 for the rest; r(c_i, `dsh_pct`) = −0.39.** 15 hospitals
report more public days than total days (c_i < 0). **Those 15 and the 3 with no
S-3 take CASH2's rule (P9–P10) and are flagged** `cshare_source = "cash2_fallback"`.

Three things to carry into the report:

1. **Days are not dollars.** Commercial payers pay more per day than Medicare
   or Medicaid, so a day share understates the commercial revenue share, and
   every dollar level runs low. Rank-based results are unaffected by a common
   factor. The difference between hospitals in price per day is not captured.
2. **The residual includes self-pay and other payers.** That overstates
   commercial share most where uninsurance is highest, which is at safety-net
   hospitals. **The error runs against finding regressivity**, so it is
   conservative for the question being asked.
3. The safety-net ratio in these data is 0.78 (0.198 / 0.253), not CASH2's
   0.40. CASH2's factor is a revenue ratio from different sources, so the two
   are not directly comparable. The comparison is reported, not adjudicated.

**S4 becomes three levels:** per-hospital c_i (base); CASH2 flat 37% with 0.40
safety-net factor; CASH2 flat with no safety-net difference.

**D1 is confirmed as written** (Carl, same date): six-measure scorecard is the
base, PSI-90-only is the bracket.

### Amendment 2 — what is scored in a draw (clarification)

§2 left open whether the score reads the true PSI-90 θ or a published value.
**Programmes pay on published values.** Scoring θ directly would give a
low-λ hospital a spread that no programme produces. So, in each draw:

```
θ_ib   ~ N(psi90_i, v_i)                       true value (U3)
y*_ib  = θ_ib + e_ib,  e_ib ~ N(0, v_i / λ_i)   a fresh measurement
pub_ib = μ + λ_i (y*_ib − μ)                    published the way CMS publishes
```

`v_i / λ_i` is the sampling variance implied by 2.2's normal–normal set-up, and
μ is 2.2's prior mean (mean published PSI-90 over the τ² sample). **`pub` is
what gets scored; θ is what headroom is ranked on.** The fixed-reliability run
sets both to the published `psi90`.

### Amendment 3 — parameter draws for MI specifications

U2 for a multiply-imputed spec: **pick one of the 20 completions uniformly, then
draw β ~ MVN(β̂ⱼ, Vⱼ).** The mixture over completions carries within- and
between-imputation variance, which is what Rubin pooling summarises. It is the
draw-level form of the same thing.

### Amendment 4 — residuals for predictive draws (U4)

PSI-90 is right-skewed (3.1: skew +2.75), so a normal residual would misstate
exactly the upper tail HACRP penalises. **U4 resamples spec m's own
evaluation-frame residuals on the published scale, within the hospital's λ
quartile**, so residual spread tracks reliability.

### Amendment 5 — mechanics fixed from the file's structure

- **Z_PSI in the Q-HIP score:** winsorize the frame's `pub` at its 5th and 95th
  percentiles (quantile type 2), z-score over the frame. HAI W-Z scores are the
  observed national ones. A hospital absent from HACRP or without HAI scores is
  scored on Z_PSI alone.
- **C1 exclusions known from the file:** the 43 N/A are Maryland, waived from
  payment adjustment (the file's footnote `a`). They are scored and ranked but
  never penalised. 126 hospitals have no Total HAC Score (125 "No", 1 "Yes").
  They cannot be reproduced by a score-based rule and are listed.
- **C2 ranks nationally.** Frame hospitals' PSI-90 values are replaced by
  predictive draws. Every other HACRP hospital keeps its observed value.
  Winsorizing, z-scoring and the 75th-percentile cut are recomputed over all
  scored hospitals, as HACRP does. Draws get the mean HACRP − Care Compare
  offset (+0.00191) so they sit on the HACRP scale.
- **Disadvantage-associated payment (§2)** shifts the value on the scale each
  spec was fitted to: θ for EIV specs, then re-measured; `pub` directly for
  the others; multiplicatively for log-scale specs.

### Amendment 6 — the convergence rule covers interval endpoints

§8's rule, as written, is degenerate. For a mean over draws, MCSE = SD / √B, so
"MCSE below 5% of SD" holds for any output once B ≥ 400, and says nothing
about the output. Every headline output is reported as a mean **and a 95%
interval over draws**, so the rule applies to all three numbers. **B doubles
until, for every headline output, the MCSE of its mean, of its 2.5th
percentile, and of its 97.5th percentile are each below 5% of its SD across
draws.** Quantile MCSE uses the order-statistic interval: half the distance
between the order statistics at B·p ± 1.96·√(B·p(1−p)), divided by 1.96.
Outputs with zero spread across draws are deterministic and exempt. For a
normal output the endpoint condition binds at about B ≈ 2,900.

The metro-tolerance run (S7) uses the B the primary run reached. It is not
re-converged.

### Amendment 7 — C1 at published precision, and the PSI-90 standardisation gap (2026-09-27, Carl)

The first C1 run stopped at the gate on two hospitals, **110107 (GA) and 340027
(NC)**. Both have a published Total HAC Score of **exactly 0.3792, which is also
the 75th-percentile cut**. CMS penalises only scores strictly above the cut,
so neither was penalised. Applied to the published Total HAC Scores, the rule
reproduces every scored hospital. Nothing past the gate had run.

- **C1a compares at published precision.** Recomputed Total HAC Scores are
  rounded to the file's 4 decimals before the cut is taken. Unrounded, the
  mean of 4-decimal W-Z scores carries floating-point noise, which put 110107
  a hair above a cut it is tied with.
- **C1b's residual gap is measured and recorded, not tuned away.** Rebuilding
  PSI-90's W-Z from its raw value reproduces CMS's winsorisation bounds, but
  standardises with a mean and SD about 1 × 10⁻⁴ off CMS's (0.98857 / 0.14330
  against an implied 0.98847 / 0.14325). The file publishes the composite to
  4 decimals, and CMS most likely standardises unrounded values. The largest
  W-Z gap is 0.002. **A C1b mismatch counts as explained only if the hospital's
  distance from the cut is within that measured gap divided by its number of
  scored measures**, the most a W-Z gap of that size can move a Total. Any other
  mismatch still stops the run.

What this costs: the simulation's HACRP scoring is exact to within ≈ 0.0003 of
Total HAC Score. That matters only for hospitals on the cut, and is small next
to the spread of C2's predictive draws.

### Amendment 8 — integer-valued outputs (2026-09-27, after the first full run's convergence trace)

**Made after seeing the convergence trace, and marked as such.** The first
full run was stopped at B = 16,000. At B = 8,000, 55 of 56 headline outputs met
amendment 6. The 56th, C2's penalised count, sat at MCSE/SD = 0.115 / 0.117 /
0.118 / 0.118 for B = 2,000 / 4,000 / 8,000 / 16,000. That is a floor, not
noise. The count is an integer with SD ≈ 2.2, and the order-statistic interval
can never be narrower than one integer step: 1 / (2 × 1.96) ≈ 0.255 counts,
≈ 0.118 SD. No B would pass it, so the run would have reached the 64,000 cap
and reported "not converged" for a quantile already pinned to one pair of
adjacent integers.

**For an integer-valued output, an interval endpoint passes when its
order-statistic interval spans at most one integer.** Its mean is held to
amendment 6 unchanged. Every non-integer output is unaffected. No run output
other than the trace was looked at before this amendment, and no setting that
touches a result changes.

### Amendment 9 — the regressivity measure's framing and rule, before it is computed (2026-09-27, Carl)

4.3 found that about 75% of the per-hospital dollar gap across catchment ADI is
hospital size. A per-hospital index therefore mostly measures size, which any
percentage-of-revenue payment has. **Carl's decision: the headline measure is
per dollar of net patient revenue. Per hospital is reported beside it as the
fundability view, with 4.3's size / payer-mix / position split stated.**

**The measures (4.4).** Concentration indices, fractional rank, over the
2,569-hospital frame, computed in every draw of 4.2's run and summarised as
mean and 95% interval:

| Framing | Quantity | Role |
|---|---|---|
| **per NPR dollar** | **marginal incentive / NPR** (= c_i × w × 3.9% × k) | **headline** |
| per NPR dollar | unearned band / NPR; bonus paid / NPR | beside it |
| per hospital | marginal incentive; unearned band; bonus paid | fundability view |
| per eligible dollar | marginal incentive / eligible revenue | stated only: constant by construction under the linear rule |

Each is ranked three ways:

- **by headroom** (θ, worst = most headroom);
- **by model-implied disadvantage** (v_B), the primary disadvantage ranking;
- **by catchment ADI**, secondary.

The safety-net flag is reported as a two-group ratio. All of this runs for the
base scenario and the S1–S7 grid.

**The rule for the words "structurally regressive".** The incentive formula is
called structurally regressive **along an axis** when the per-NPR-dollar
marginal-incentive concentration index, ranked along that axis, is negative
and its 95% interval over draws excludes zero in the base scenario. Otherwise
the result is described as neutral, or as running the other way, whichever the
interval shows. The words are used only about the arithmetic of the formula,
never about intent or realised outcomes, and every sentence that uses them
says so (Plan §9). A scenario that changes the verdict is named beside it.

**The observed HACRP cross-tabulation (4.4, Plan §9 associational).** On 4.2's
calibration frame (2,551 hospitals, 629 penalised, Maryland excluded as
waived):

- the penalised share with a Wilson 95% interval, by safety-net flag, catchment
  ADI quintile, quintile of each hospital's mean v_B over draws, and 3.16's
  cells;
- rate ratios, ADI Q5 / Q1 and safety-net / not, with log-method 95%
  intervals;
- the concentration index of the penalty indicator ranked by ADI and by mean
  v_B.

Worded "over-represented among" or "associated with", never with a causal verb.
Penalty dollars are not computed: the 1% applies to Medicare IPPS payments,
which are not in the frame.

**What 4.2 adds for this, and nothing else changes.** 4.2's stage gains, per
scenario, the per-NPR-dollar concentration indices above, and, per stratum,
quintiles of headroom and the per-NPR marginal incentive. These are new
outputs. No input, draw or setting changes. The amendment-6/8 rule applies to
the enlarged headline set, so B is whatever it now needs.

### Amendment 10 — the threshold scenario is a hypothetical stress test (2026-10-02, Task S1.5)

S3 above derived "bottom 25% earn nothing" from CASH2's statement that 75% of
pay-for-performance hospitals earn a bonus. That is a participation statistic.
It does not identify a rule that excludes the worst quarter, and Elevance
describes its program as rewards for meeting targets plus credit for
year-over-year improvement. The arithmetic is unchanged, but the scenario is
now labeled **threshold — hypothetical stress test** in every output
(`SCEN_LABEL` in `R/09-payment-sim.R`, the `label` column of
`payment-scenarios.csv`). The report presents it as a stress test, not as
Q-HIP's rule. An improvement-credit rule needs a second reporting window and
is follow-up 1 (`provenance/follow-ups.md`).

Also from S1.5 (second-pass preregistration sec 4, fixed 2026-10-01):

- The S2 shape curves r(P) = 0.001 + 0.039 P^k (k = 0.5, 2) now act through
  `rate_of()`. Each is also run rescaled per draw to the base total.
- Two revenue scenarios, commercial revenue share ρs / (ρs + 1 − s) at
  ρ = 1.5 and 2.0, replace the claim that every dollar level runs low. The 16
  CASH2-fallback hospitals keep their share, since it is already a revenue
  share.
