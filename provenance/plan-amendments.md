# Plan amendments

**Date:** 2026-08-26 (revised later the same day — see §7)
**Supersedes:** parts of `Variance Project - Plan.md` §4, §6, §7, §12 and of
`Variance Project - Tasks.md` as itemised in §5 below.
**Evidence:** every number regenerates from `provenance/phase0-numbers.R` and
`provenance/phase0-followup.R`.

This document answers three questions Carl put after the Phase 0 spikes, and then
propagates the answers into the phases and tasks they change. Nothing here is left as
"noted for later."

---

## 1. What the absent O/E split actually costs

Short answer: **more than I said in `spike-outcome.md`, and I can now put a number on
it. The published composite retains a median of 46% of each hospital's true deviation
from the national mean, and how much it retains is almost entirely determined by
volume — which makes the attenuation differential with respect to rurality but not
with respect to urban poverty.**

### 1.1 The published interval reveals the shrinkage

CMS publishes, for PSI-90, a point estimate and a `Lower Estimate`/`Higher Estimate`
interval. If that interval were ordinary sampling error on an unshrunk rate, its width
would fall as 1/√n, giving a log-log slope of −0.50 against volume. Measured:

| | |
|---|---|
| corr(log CI width, log Medicare volume) | **−0.8634** |
| slope of log(CI width) on log(volume) | **−0.1934** |
| slope implied by pure sampling error | −0.500 |

A slope far flatter than −0.5 is the signature of a **posterior** interval on an
already-shrunk estimate: at low volume the posterior stops tracking the data and
collapses onto the prior, so the interval stops widening. This corroborates the FY 2026
fact sheet's description of the composite as built from *smoothed* component rates.

### 1.2 Solving for the shrinkage factor

Treat the published value as a posterior mean, θ̂ᵢ = μ + λᵢ(yᵢ − μ), with posterior
variance vᵢ = (half-width/1.96)² and λᵢ = τ²/(τ² + σᵢ²). Then λᵢ = 1 − vᵢ/τ², and since
Var(θ̂) = τ² − E[v], τ² is identified from published quantities alone:

| | |
|---|---|
| Var(published PSI-90) | 0.03678 |
| mean implied posterior variance E[v] | 0.04066 |
| **implied prior variance τ²** | **0.07744** (τ = 0.2783) |

Note the diagnostic in its own right: **the mean within-hospital variance exceeds the
observed between-hospital variance of the published scores.** That is arithmetically
impossible for unshrunk estimates and is by itself proof that heavy smoothing has been
applied.

**Implied shrinkage factor λᵢ — the share of a hospital's true deviation that survives
into the published number:**

| p05 | p25 | median | p75 | p95 |
|---|---|---|---|---|
| 0.143 | 0.289 | **0.462** | 0.656 | 0.837 |

Mean λ = **0.475**. A regression slope fitted on the published composite recovers, on
average, **about 47% of the true gradient.**

### 1.3 The part that matters: the attenuation is covariate-correlated, and selectively so

| | corr with λ |
|---|---|
| log Medicare volume | **+0.9345** |
| log beds | +0.8694 |
| **rural indicator** | **−0.4004** |
| DSH patient percentage | +0.0652 |
| Medicaid day share | +0.0812 |

| Volume quartile | mean λ | median Medicare cases |
|---|---|---|
| Q1 lowest | **0.205** | 322 |
| Q2 | 0.381 | 1,032 |
| Q3 | 0.559 | 2,279 |
| Q4 highest | **0.755** | 5,008 |

Rural hospitals retain **0.304**; non-rural retain **0.520**.

**This is the finding.** The composite's attenuation is almost perfectly explained by
volume (r = 0.93). Rurality is strongly entangled with volume, so **the rural limb of
the disadvantage gradient is attenuated roughly twice as hard as the urban limb.**
DSH percentage and Medicaid share are barely correlated with λ at all, so the
urban-safety-net limb is attenuated at close to the average rate and is not
differentially distorted.

Two consequences that a reviewer will reach for immediately:

1. **A null or weak rural coefficient on the composite is uninterpretable.** It is
   consistent with no rural gradient *and* with a large rural gradient shrunk by 70%.
   The report cannot report a rural result off the composite without the correction.
2. **A positive urban-disadvantage result on the composite is conservative.** λ is
   near-flat in DSH and Medicaid share, so attenuation there is roughly uniform, which
   biases the slope toward zero without distorting its shape. **MCR⁻ > 1 for community
   disadvantage, if found on the composite, is a lower bound.** That is a genuinely
   useful thing to be able to say and should be said explicitly.

### 1.4 What the analysis does about it

Three changes, in increasing cost:

**(a) Report λ as a data-quality result.** Free. The distribution above, plus the
volume quartile table, belongs in report §3 and §9. It is also the single most
interesting methodological observation Phase 0 produced.

**(b) Reliability-weighted estimation as a specification-space axis.** Cheap. Weight
by λᵢ, or by 1/vᵢ, or restrict to the high-λ subsample. Plan §6 already lists
influential-point handling as an axis; this adds a reliability axis alongside it.

**(c) An explicit measurement-error correction.** The corrected estimator is
θ̃ᵢ = μ̂ + (θ̂ᵢ − μ̂)/λᵢ, with variance inflated by 1/λᵢ². **It must not be used as a
per-hospital point estimate** — at λ = 0.14 the inflation is 50×. It is used as an
errors-in-variables correction inside the regression, or equivalently by fitting a
hierarchical model that treats the published value as a noisy observation with known
λᵢ rather than re-shrinking it.

**And one thing to stop doing.** Task 3.2 as written fits a hierarchical model with
hospitals nested in catchment geography. Fitting a hierarchical model *on already-shrunk
estimates* shrinks twice, and the second shrinkage compounds the first exactly where
the first was worst. Task 3.2 must either work on the components (where denominators
are published and λ is far closer to 1) or treat the CMS smoothing as the model's first
level. **This is a real bug in the current task sheet, not a refinement.**

### 1.5 Where this lands in the phases

| Task | Change | Δ hours |
|---|---|---|
| 2.2 | Compute and store λᵢ, vᵢ, τ² alongside the outcome | +1 |
| 3.2 | Rewritten to avoid double shrinkage; components carry the hierarchical model | 0 |
| 3.3 | Variance decomposition reports the λ-corrected and uncorrected split | +1 |
| 3.4 | Specification space gains a **reliability axis** (unweighted / λ-weighted / high-λ subsample / λ-corrected) | +1 |
| 5.2, 5.6 | Report §3 and §9 carry the λ distribution and the directional-bias argument | +1 |
| **New** | The λ derivation goes in the technical appendix — it is the manuscript's strongest methods hook | +2 |
| | | **+6** |

**And it kills plan §12's third cut line.** "Component PSI secondary outcomes, leaving
PSI-90 alone" is now the worst available cut: the components are the only outcome with
published denominators and weak smoothing, and they are how the composite's attenuation
is characterised. Cutting them leaves the whole analysis on a covariate-correlated,
50%-attenuated outcome with nothing to calibrate it against. See §4.

---

## 2. HSAF suppression: what it entails, and whether it is severe

Short answer: **suppression is not severe — I tested it directly and it moves the
catchment-weighted covariates almost not at all. But the test surfaced a different
problem that is real: at county grain, catchment weighting is nearly redundant with
naive county assignment, and that is not a suppression artifact.**

### 2.1 What suppression mechanically entails

For hospital *h* and ZIP *z*, a cell with fewer than 11 Medicare discharges is masked.
The weight is then computed over observed cells and renormalised:
wₕᵤ = casesₕᵤ / Σ_observed casesₕᵤ. Renormalising **assumes the masked ZIPs have the same
average covariate value as the observed ones**. Since masked cells are the small,
peripheral edges of a catchment and observed cells are its core, the assumption fails
in a specific direction: renormalising pulls the catchment estimate **toward the
hospital's own immediate area** — that is, toward the naive county value.

That is a testable prediction, so I tested it rather than asserting it.

### 2.2 The test

Built a free ZCTA→county crosswalk from the Census 2020 relationship file, joined the
SVI 2022 county themes, and computed each hospital's catchment-weighted SVI two ways
— observed cells only, and observed cells plus every suppressed cell imputed at 3 cases
— then compared both against the naive hospital-county value. n = 2,730 hospitals.

| SVI theme | r(obs, imputed) | mean diff | sd diff | r(obs, county) | r(imputed, county) |
|---|---|---|---|---|---|
| T1 socioeconomic | **0.9901** | −0.0008 | 0.0422 | 0.9374 | 0.9251 |
| T2 household characteristics | **0.9885** | −0.0015 | 0.0443 | 0.9405 | 0.9301 |
| T3 racial/ethnic minority | **0.9947** | +0.0037 | 0.0292 | 0.9653 | 0.9556 |
| T4 housing/transport | **0.9864** | +0.0022 | 0.0418 | 0.9032 | 0.8854 |

Theme-1 absolute gap: median 0.0205, p95 0.0754, max 0.3556; 378 hospitals (13.8%)
exceed 0.05 SVI percentile points.

**Verdict 1: suppression does not severely impact the analysis.** Correlations ≥ 0.986,
mean differences under 0.004 SVI percentile points, essentially no systematic
direction. Renormalising over observed cells is sound. My predicted
drag-toward-county is visible — r(obs, county) exceeds r(imputed, county) on every
theme — but the magnitude is ~0.01, which is negligible.

**Verdict 2, which matters more:** r(catchment, hospital-county) is **0.89–0.97**.
At county grain, catchment weighting is nearly redundant with just using the county
the hospital sits in. And because imputing the suppressed cells barely moves that
correlation, **this is not suppression's fault.**

This directly contradicts what I recommended in `spike-context.md` §4, where I proposed
county grain as the base case. **That recommendation is withdrawn.** At county grain the
8-hour catchment engine buys 3 correlation points. If catchment weighting is to earn
its hours it must run at ZIP or tract grain, where within-county heterogeneity — the
thing county assignment destroys — is actually retained.

It also **disarms a trap in the task sheet.** Task 2.5's verify says: "Where [the
correlation] is high, the catchment weighting bought little and the report should say
so." Read naively at county grain that sentence produces a true statement for the wrong
reason. The diagnostic now needs three columns, not two: catchment-at-fine-grain,
catchment-at-county-grain, and naive county — so that "the weighting bought little"
can be distinguished from "the grain was too coarse to let it buy anything."

### 2.3 Alternative datasets, assessed

| Alternative | Verdict |
|---|---|
| **Pooling adjacent HSAF vintages** to recover cells that cross 11 in another year | **Tested and rejected.** Of 711,362 suppressed 2023 cells, 42.2% appear in 2024 at all and only **2.3%** are unsuppressed there. Median catch_coverage gain: **+0.006**. Not worth the acquisition. *Useful side finding:* if suppressed cells typically held 7–10 cases, far more than 2.3% would cross 11 in an adjacent year. That so few do is direct evidence most suppressed cells hold **1–3 cases**, which independently supports gate B0's working constant of 3 — and means the "10 cases per cell" upper bound in `spike-context.md` is far too pessimistic. |
| **Dartmouth Atlas ZIP→HSA/HRR crosswalk** | **Recommended as a robustness axis.** Free, no registration, no suppression at all — it assigns each ZIP to one hospital service area by plurality of Medicare admissions. Coarser (no weights, whole-ZIP assignment) but a genuinely independent construction. Costs ~2 h and gives the report a suppression-free comparison. |
| **HUD USPS ZIP crosswalk** | **Dropped.** Now requires an API token (`{"error":"Unauthenticated"}`). The **Census 2020 ZCTA relationship files** are free, need no token, and do the same job — ZCTA→county verified working (33,791 entries), ZCTA→tract verified reachable. This removes a registration dependency from Phase 1. |
| **HCUP State Inpatient Databases** | The real alternative — all-payer, patient ZIP, not Medicare-only, which also fixes the *other* catchment limitation. Requires the DUA plus purchase. Stays on the enrichment track; for the PRHI-region section specifically it is the highest-value enrichment available. |
| **AHA Annual Survey service areas** | Licensed; on the enrichment track. |
| **Medicare Geographic Variation files** | County-level only. No hospital × ZIP resolution. No use here. |

### 2.4 Where this lands in the phases

| Task | Change | Δ hours |
|---|---|---|
| 1.4 | HUD crosswalk replaced by Census ZCTA relationship files; no registration needed | −1 |
| 1.5 | HSAF CY2023 already downloaded, parsed, hashed in Phase 0 | −2 |
| **2.4** | **Base case moves to ZIP→tract, not county.** County becomes the documented fallback for the 130 gate-B0.a hospitals. Suppression handling is now evidence-backed rather than defensive, which is *less* work, not more | −2 |
| **2.5** | Diagnostic becomes **three-way**: catchment-tract vs catchment-county vs hospital-county, so "bought little" and "grain too coarse" are distinguishable | +1 |
| **2.5** | Add the Dartmouth Atlas HSA assignment as a suppression-free robustness column | +2 |
| 5.2 | Report §3 carries the measured suppression-bias table above rather than a hedge | 0 |
| | | **−2** |

Note the direction: **measuring the suppression cost made Phase 2 cheaper, not dearer.**
The 8 hours on Task 2.4 were budgeted to defend a weighting scheme against an attack.
The attack has now been answered empirically, and the answer is stronger than the
defence would have been.

---

## 3. Imputation and MCR scoping — Carl is right on both, and I over-constrained

### 3.1 The imputation hierarchy was backwards

`admission-gates.md` §3 required a missingness indicator as the primary treatment, with
multiple imputation as one of three permitted specifications. **That ordering is wrong
and is corrected here.**

The missingness-indicator method is known to be biased in regression settings even
under MCAR (White & Carlin 2010; Greenland & Finkle 1995). It is not a principled
estimator; it is a convenience that happens to keep rows.

Meanwhile the Phase 0 diagnostic that made me nervous is actually the argument *for*
imputation: contract-labor missingness is predicted by **beds** (standardized difference
+0.462) and **rurality** (−0.269), both of which are **fully observed for 100% of the
frame** from the Impact File. Missingness predicted by fully-observed covariates is the
textbook MAR case, and **multiple imputation under MAR is unbiased and efficient there**.
Differential missingness is a reason to impute properly, not a reason to hedge.

**Corrected hierarchy:**

1. **Primary: multiple imputation by chained equations**, with predictive mean matching
   for the contract-labor share (it is right-skewed and bounded below at 0, so
   normal-linear MI would generate impossible values). Imputation model includes beds,
   rurality, ownership, CBSA, wage index, volume, and the Block B disadvantage
   measures. m = 20.
2. **Sensitivity: complete-case**, reported alongside, so the reader can see the
   difference MI makes.
3. **Dropped: the missingness indicator** as an estimation strategy. It stays only as a
   *diagnostic* — is the indicator predictive after conditioning? — which is a
   legitimate MNAR probe.
4. **Retained: the covariate-omitted specification**, because that is what tells you
   whether the covariate matters at all.

### 3.2 Deterministic recovery beats imputation where it is available

Two routes that recover real values rather than imputing them, both cheap, both to be
attempted **before** any imputation runs:

**(a) Raw HCRIS.** The 90.7% population rate is the coverage of the *curated PUF*, not
of HCRIS itself. The full cost report files carry every worksheet line, and Worksheet
S-3 Part II is where contract labor actually lives. Verified available, no registration:
`https://downloads.cms.gov/files/hcris/HOSP10FY2023.zip` (137 MB), with
`hosp10-reports.zip` and `hosp10-sas.zip` at the same location. If raw S-3 populates
hospitals the PUF leaves blank, those are recovered values, not imputed ones.

**(b) Cross-year fill.** A hospital blank in FY 2023 may have reported in FY 2022.
`CostReport_2022_Final.csv` is public at the same endpoint. Contract labor share is
persistent year to year, so a prior-year value is a far better estimate than any
imputation — and it is observed data, carried with a `contract_labor_source` flag.

Both are Task 1.6 / 2.7 work. Expected effect: the 9.2% blank rate falls, and whatever
remains is genuinely missing rather than an artifact of CMS's PUF curation.

### 3.3 MCR does not run on every covariate

Carl is right, and this saves real hours in the phase that has none to spare.

Plan §6 states the claim worth having: **MCR⁻ > 1 for community disadvantage.** That is
a claim about Block B. Task 3.12 as written computes bounds "for every covariate," which
is expensive and mostly produces bounds nobody will cite.

**Revised scoping:**

| Block | Treatment | Why |
|---|---|---|
| **Block B disadvantage** (SVI four themes, ADI, uninsured, rurality, ICE) | **Full MCR⁻/MCR⁺**, individually and as a group | This is the claim. It is what the report is for |
| **Block A structure** (beds, teaching, CMI, DSH, wage index, ownership, occupancy, margin) | Rashomon-set coefficient ranges + specification-curve stability. **No MCR** | These are controls and context. A range across the Rashomon set answers everything the report asks of them |
| **Block C** (coding intensity, contract labor, tort) | Rashomon-set coefficient ranges only. **No MCR** | Their job is to be *in* the model so a rival explanation is addressed, not to be ranked. `admission-gates.md` §4 already forbids a tort MCR claim; this extends the same logic to the other two |

This also **dissolves the awkward clause in gate C2**: "no MCR importance claim may rest
on the contract-labor share unless it holds across all three treatments." Contract labor
never gets an MCR bound at all now, so the clause is replaced by the simpler requirement
that its *coefficient range* be reported under both MI and complete-case.

**Group MCR on Block B as a whole is worth more than the per-covariate bounds.** Given
the collinearity Task 3.1 will quantify, the defensible claim is that no near-optimal
model can ignore *community disadvantage*, not that none can ignore *SVI theme 2
specifically*. The per-covariate split is what TIS is for.

### 3.4 Where this lands in the phases

| Task | Change | Δ hours |
|---|---|---|
| 1.6 | Add raw HCRIS S-3 acquisition + FY2022 cross-year file | +3 |
| 2.7 | Deterministic recovery attempted before imputation; `contract_labor_source` flag | +1 |
| **3.11** | MCR implementation unchanged — still needs validating against a known answer | 0 |
| **3.12** | **Scoped to Block B, individually and as a group.** Block A and C get Rashomon coefficient ranges instead | **−5** |
| 3.4 | Specification space gains the MI / complete-case / omitted axis, drops the indicator arm | 0 |
| 2.6 | Missingness audit adds the MAR-plausibility check that justifies MI | +1 |
| | | **0** |

---

## 4. The schedule, and the cut order

### 4.1 The arithmetic

| | |
|---|---|
| Available: 47 days × 30 h/wk | **201 h** |
| Plan remaining after Phase 0 | **242 h** |
| **Shortfall** | **41 h (17%)** |

### 4.2 Plan §12's cut order does not survive Phase 0

Plan §12 says cut, in order: Phase 4 (20 h), archetype validation (12 h), then the
component PSI analyses.

**The third one is now the worst available cut**, for the reason in §1: with no O/E
split and a composite attenuated to 47% with volume-correlated bias, the components are
the only lightly-smoothed outcome with published denominators, and the only way to
characterise what the composite hides. Cutting them would leave every finding resting
on a single attenuated number with nothing to calibrate against — while §12 elsewhere
insists that what makes the report defensible must not be cut. The component analyses
have moved into that protected category.

### 4.3 Revised cut order and savings

| # | Cut or change | Saves | Rationale |
|---|---|---|---|
| 1 | **Phase 4 payment Monte Carlo → reduced, not cut** (20 h → 8 h) | **12** | The FY 2026 HACRP file gives *observed* penalty status for 3,055 hospitals. A descriptive regressivity analysis against real penalties delivers most of report §8's value without the full simulation. Cheaper *and* better-evidenced than what was planned |
| 2 | **Tasks 3.15–3.16 archetype validation — cut** | **12** | Plan §12's second cut, unchanged. Report §7 goes |
| 3 | **Task 5.5 §7/§8 drafting — reduced** (6 h → 2 h) | **4** | Follows from 1 and 2 |
| 4 | **Task 5.1 figure suite** (10 h → 6 h) | **4** | Two of seven figures go with the cuts above |
| 5 | **Task 3.12 MCR scoped to Block B** | **5** | §3.3 |
| 6 | **Task 2.4/2.5 catchment** | **2** | §2.4 — the empirical answer replaced the defensive build |
| 7 | **Phase 1 already partly executed in Phase 0** (1.1, 1.2, 1.5) | **9** | Six sources downloaded, hashed, parsed; URLs and parse traps documented; `phase0-numbers.R` is a working driver-script skeleton |
| 8 | **SVI supplies uninsured + LEP; RAND dropped; Census replaces HUD** | **3** | §2.3 and `spike-context.md` §4 |
| 9 | **Task 3.6/3.7 specification grid trimmed** | **4** | Grid narrows with the archetype and payment axes gone |
| | **Total saved** | **55** | |

Against which Phase 0's findings **add** work:

| Addition | Costs |
|---|---|
| Reliability/λ correction: outcome storage, spec axis, decomposition, write-up, appendix | **+6** |
| Raw HCRIS S-3 + cross-year fill; MAR justification for MI | **+5** |
| Three-way catchment diagnostic + Dartmouth Atlas robustness column | **+3** |
| **Total added** | **+14** |

**Net: 242 − 55 + 14 ≈ 201 h against 201 h available.**

Zero buffer is not a plan, so the revised task sheet takes the harder version of cut 1:
**Phase 4 is cut entirely, not reduced**, with report §8 rebuilt at 2 h inside Task 5.5
on *observed* FY 2026 HACRP penalties. Task-by-task, `Variance Project - Tasks (rev 2).md`
totals **200.5 h of remaining work against 201 h available** — still half an hour of
slack, which is still not slack.

The revised sheet therefore carries **four named reserve cuts worth 10 h** (figure suite,
functional-form axis, the Dartmouth robustness column, TIS scope), to be taken at the
first overrun rather than the last minute. That puts the working plan at ~190.5 h and
the slack at ~5%. **This is thin, and it is the honest number.**

### 4.4 The binding constraint is the calendar, not the hours

Tasks 6.3, 6.4, and 6.5 are review meetings with the Foundation, with the external
reviewers, and with the Business Case Work Group. Their calendars are not Carl's, and they cannot be compressed
into the final week. Working backwards from October 12:

| Milestone | Date | Note |
|---|---|---|
| Analytic work complete (through 5.8) | **~Sept 28** | |
| 6.1 hostile reproducibility + 6.2 verification pass | Sept 29 – Oct 1 | 12 h; **neither may be cut** |
| 6.3 pre-socialize with the Foundation | ~Oct 2 | must precede 6.4 |
| 6.4 external reviewer call | ~Oct 5–6 | **schedule this now**, not in October |
| 6.5 Work Group review | ~Oct 7–8 | **schedule this now** |
| 6.6 revise and finalize | Oct 9–12 | 6 h |

**Action with a deadline attached: the two review slots should be requested this week.**
They are the only part of the schedule Carl cannot recover if they slip, and a two-week
booking lead is normal for a Work Group.

Phase 5 drafting begins ~Sept 20.

---

## 5. Itemised changes to the task sheet

Applied in `Variance Project - Tasks (rev 2).md`.

| Task | Change |
|---|---|
| 0.1 | Answers recorded. Finish date is **fixed at 2026-10-12**, not derived |
| 1.1 | Scaffold inherits `phase0-numbers.R` and `phase0-followup.R`; 3 h → 2 h |
| 1.2 | Outcome layer already downloaded and hashed in Phase 0; 3 h → 1 h. **Add the HACRP file** as a fourth source |
| 1.4 | HUD → Census ZCTA relationship files. SVI supplies uninsured + LEP. 6 h → 4 h |
| 1.5 | HSAF CY2023 already acquired; 2 h → 0.5 h. **Add Dartmouth Atlas ZIP→HSA** |
| 1.6 | **Add raw HCRIS S-3 extraction and FY2022 cross-year file**; 2 h → 5 h |
| 2.2 | **Compute and store λᵢ, vᵢ, τ²**; keep footnote codes 1/5/7/13/19/23/29 distinct; 4 h → 5 h |
| 2.4 | Base grain **ZIP→tract**, county as documented fallback; 8 h → 6 h |
| 2.5 | **Three-way diagnostic** + Dartmouth column; 5 h → 8 h |
| 2.6 | **Add MAR-plausibility check** justifying MI; 4 h → 5 h. Still uncuttable |
| 2.7 | Deterministic recovery before imputation; `contract_labor_source` flag; 3 h → 4 h. Still uncuttable |
| **3.2** | **Rewritten — must not double-shrink.** Hierarchical model runs on components; composite enters with known λᵢ |
| 3.3 | Reports λ-corrected and uncorrected decomposition; 4 h → 5 h |
| 3.4 | **Reliability axis added**; imputation axis is MI / complete-case / omitted; 6 h → 7 h |
| 3.6, 3.7 | Grid trimmed with archetype and payment axes gone; 8 h → 6 h, 6 h → 5 h |
| **3.12** | **Scoped to Block B**, individually and as a group; 5 h → 3 h. Block A and C get Rashomon coefficient ranges |
| 3.15, 3.16 | **CUT** (−12 h) |
| 4.1–4.4 | **CUT** (−20 h). Report §8 becomes a short descriptive regressivity section built on observed HACRP penalties, folded into 5.5 |
| 5.1 | Figure suite shrinks; 10 h → 6 h |
| 5.5 | §7 dropped; §8 becomes descriptive; 6 h → 2 h |
| 5.6 | Limitations carries the λ distribution and the measured suppression bias; 3 h → 4 h |
| 5.8 | Appendix carries the λ derivation; 3 h → 5 h |
| 6.x | Unchanged in hours. **6.4 and 6.5 need calendar slots requested this week** |

**Uncuttable, unchanged:** admission gates (0.6, 2.7), missingness audit (2.6),
internal verification pass (6.2) — plus, now, **the component PSI analyses**, promoted
into that set by §1.

---

## 6. Corrections to Phase 0 documents

| Document | Correction |
|---|---|
| `spike-outcome.md` §5 | Understated the attenuation. λ is now quantified; §1 above supersedes |
| `spike-context.md` §2 | The 10-cases-per-cell upper bound is too pessimistic. §2.3's recovery test shows most suppressed cells hold 1–3 cases |
| `spike-context.md` §4 | **County-grain recommendation withdrawn.** Base case is ZIP→tract; §2.2 above supersedes. HUD crosswalk replaced by Census |
| `admission-gates.md` §3 | **Imputation hierarchy reversed** — MI primary, indicator demoted to diagnostic; §3.1 above supersedes |
| `admission-gates.md` §3 | MCR clause replaced: contract labor gets no MCR bound at all |


---

## 7. Revision, later on 2026-08-26 — the schedule constraint was wrong

Section 4 above cut scope against a ceiling of 201 hours. **Both inputs to that ceiling
were wrong.**

1. **The contract runs to 2026-10-15, not 2026-10-12.** Fifty days, not forty-seven.
2. **The plan's hour estimates assume unassisted solo work.** They are not a forecast of
   how fast this project actually moves. Phase 0 is the demonstration: budgeted at
   8 hours, it delivered six provenance documents, thirteen hashed source files, two
   reproducible verification scripts, and three measurements nobody asked for.

**Every cut in §4.3 made for time is reinstated** in `Variance Project - Tasks (rev 3).md`:
Phase 4 (21 h, improved — it now has the observed HACRP penalty distribution as a
validation anchor), Tasks 3.15–3.16 archetype validation (12 h), Task 5.5 §7 and §8 back
to 6 h, Task 5.1 figures back to 10 h, Tasks 3.6–3.7 above rev 1 because the reliability
axis enlarges the grid, Task 2.4 back to 8 h, and Task 3.12 back to 5 h with Block A
restored as a secondary MCR output.

**What is not reinstated, because it was never a time cut.** Everything in §1, §2, and §3
of this document stands: the Task 3.2 double-shrinkage fix, the reliability quantities and
axis, amendment A1's imputation hierarchy, raw HCRIS recovery, the ZIP→tract catchment
grain, the Dartmouth robustness column, the Census-for-HUD substitution, and the
promotion of the component PSI analyses into the protected set. **Block C still receives
no MCR bound** — that is a principled exclusion, not a saving.

**Net: 257.5 h across 55 tasks**, against rev 1's 250 across 55 — about 14 hours of new
work Phase 0 showed to be necessary, offset by ~5.5 hours of Phase 1 already executed.

**Section 4's arithmetic is retained above as the record of a decision that was made and
then reversed**, not deleted. The cut order it produced survives as the ranked contingency
list in rev 3, which is the durable part: if hours ever do run short, the order is already
argued and the withdrawal of plan §12's third cut line still holds.

### One correction to §4.4 that survives

The observation that Tasks 6.4 and 6.5 are calendar-bound rather than hour-bound is
independent of the throughput question and still applies. Booking lead time does not
shrink because the work goes faster.
