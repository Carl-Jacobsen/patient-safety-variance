# Claim-to-evidence table

**Task S5.1, 2026-10-07; revised 2026-10-12 for the October 7 audit (Task S7.4).** Every claim the main report makes, with the five
fields the second pass requires: the quantity the claim is about (target), the
hospitals it was computed on (sample), how it was computed (method), what kind
of uncertainty its interval carries (uncertainty), and the CASH decision it
bears on (decision relevance). Sections 2 to 9 are drafted from this table
(S5.2), and the meaning review (S5.5) reads every sentence of the report
against it. Section 1 carries a shortened version.

**The question the report serves.** A fairness assessment of a performance
measure: does variation in published PSI-90 follow community conditions that
hospitals do not control, and how firmly can the public data say so? Payment
exposure is a secondary question, kept because a measure can be fair and the
payment rule built on it still distribute money unevenly. The return-on-
investment question goes to the next-exercise page (S3.5).

**The limit under every claim.** The analysis observes neither hospital safety
effort nor the response to an intervention. An association between PSI-90 and
community measures is consistent with a shortfall in risk adjustment and
equally with real differences in care, and nothing here separates the two.
Section 2 states this before any number appears.

**Uncertainty vocabulary.** *Bootstrap 95%*: hospitals (or HSAs, where named)
resampled. *Model range*: the spread of an estimate across the members of a
Rashomon set, which is not a sampling interval. *Simulation 95%*: the 2.5th
and 97.5th percentiles over the payment draws (specification, coefficients and
published-score draws). *Repeat range*: the 2.5th to 97.5th percentiles over
20 repeated random fold assignments. *Scenario range*: the spread across a
declared grid of assumptions, with no probability attached. *Log-scale normal
approximation*: a 95% interval on a log rate ratio, groups treated as fixed
and hospitals as independent. *None modeled*:
the number carries no interval, and the prose must say so.

Sample abbreviations: **frame** = the 2,801 acute care hospitals with a
published FY 2026 PSI-90; **evaluation frame** = the 2,569 complete on every
composite model term, on which every composite model is scored (each is
fitted to the hospitals complete on its own terms, 803 to 2,744; the
"model frame" of the October 7 table); **HACRP frame** = the 2,551 with both a HACRP PSI-90 and
a penalty decision.

---

## 1. How much of the score public characteristics describe (report sec 5)

| ID | Claim | Target | Sample | Method | Uncertainty | Decision relevance | Source |
|---|---|---|---|---|---|---|---|
| F1 | The community block describes 3.3% (2.5% to 4.8%) of the variation in published PSI-90, and hospital structure 4.5% (3.5% to 6.8%); the paired difference (+1.2 points, −0.4 to +3.4) does not rank them. | Share of variance in published PSI-90 by block | Evaluation frame | LMG decomposition of an OLS fit, published score unweighted (primary) | Bootstrap 95%, hospitals, B = 1,000 | Says how much of the spread in scores lines up with the measured community block in one linear decomposition; it is not a bound on how far any community adjustment would move scores or payments (audit A3) | `variance-decomposition.csv`; stage 22 |
| F2 | 91.2% of the variation is left unexplained, conditional on these linear covariates, the complete-case frame and squared-error loss. It is not the share of harm unrelated to hospitals or communities, and not a measure of hospital effort. | Residual share | Model frame | As F1 | Bootstrap 95% (87.9% to 92.6%) | Prevents the residual being read as "hospital-controlled" | as F1 |
| F3 | On the four component measures, fitted to the same 2,569 hospitals (9,782 component rows), community accounts for 1.62% (−0.81% to 4.19%) of the between-hospital variance, an interval that includes zero; structure 6.13%, and the paired difference (+4.5 points, 1.0 to 10.3) ranks structure above community on this target. The October 7 value (1.44%, −0.60% to 3.67%) came from subset models fitted to different samples and is withdrawn. | Community share of the between-hospital variance component | Evaluation frame, every subset model on identical rows (checked per subset and per replicate) | LMG on the hospital variance component | Bootstrap 95%, HSAs resampled whole, B = 1,000 | Shows F1 does not survive a change of target; carried beside F1, not below it (audit A1, S7.1) | as F1 |
| F4 | Weighting by each hospital's reliability gives 3.6% (2.8% to 5.3%), a different descriptive allocation, not a correction. The reliability used is a scalar approximation whose accuracy for this release is unknown. | Reliability-weighted share | Model frame | WLS, scalar λ | Bootstrap 95% | Sensitivity; the direction of any error in λ is unknown (audit A2); supplement carries the derivation and the S2.2 question | `variance-decomposition.csv`; S2.1, S2.2 notes |

## 2. Community associations across models and geography (report sec 6)

| ID | Claim | Target | Sample | Method | Uncertainty | Decision relevance | Source |
|---|---|---|---|---|---|---|---|
| F5 | At the primary tolerance, scrambling the disadvantage measures raises the squared error of every one of the 194 near-optimal models (MCR⁻ 1.085, MCR⁺ 1.230), a lower bound that falls to 1.000 at the state tolerance (F6). The bounds cover the 736 enumerated specifications only, and the set is chosen through the mixed registry, whose best fit is errors-in-variables. | Model class reliance on the ten-measure disadvantage group | Evaluation frame; Rashomon set at ε = 4.1% of loss | MCR over the enumerated specification space | Model range; ε from a hospital bootstrap of the best fit's loss | Community measures cannot be dropped from a model of PSI-90 without loss, under this tolerance | `mcr-bounds-blockB.csv` |
| F6 | The claim in F5 depends on the resampling unit behind the tolerance: it holds at the metro-area tolerance (MCR⁻ 1.079, 319 models) and fails at the state tolerance (MCR⁻ 1.000, 536 models). Restricting to the 65 unweighted members leaves the primary lower bound unchanged, against 1.000 at the state tolerance. A published-score set calibrated on its own (184 unweighted specifications, best fit spec 382, ε = 2.91%) admits 105 models, with MCR⁻ 1.079, 1.063 and 1.048 at its hospital, metro and state tolerances. | As F5 | As F5; published-score set added for audit A2 | As F5 | Model range at three tolerances | States how firm F5 is; the primary bound never appears without the state bound (claim guard `bound_alone`) | `mcr-bounds-blockB.csv`; `rashomon-published-subset.csv` |
| F7 | The models disagree on direction. Moving every disadvantage measure from its 10th to its 90th percentile changes predicted PSI-90 by −0.370 to +0.858 SD across the 194 models (57% positive), and by −0.227 to +0.347 SD across the 105 models of the published-score set (−0.227 to +0.182 across the 65 unweighted members of the main set). In the best published-score model it is −0.21 SD with a standard error of 0.20; its HSA sibling is fitted to 2,605 hospitals, the others to 2,569. | Joint p10→p90 disadvantage contrast, SD of published PSI-90 | Model frame | Contrast from each set member's fitted coefficients | Model range; per-model standard error | The data do not establish that PSI-90 penalizes hospitals in disadvantaged catchments, or that it favors them | `mcr-bounds-blockB.csv`; `contrast-support.csv` |
| F8 | The joint move is a synthetic profile. 12% to 34% of observed catchments lie at least as far from the center at each grain (the radial rule passes), but at the county catchment the most disadvantaged end is 2.07 from its nearest observed profile, against an observed 95th percentile of 1.88 (3.1% as isolated). | Support of the joint contrast | Evaluation frame, four grains | Mahalanobis radial share; nearest distinct observed profile, transformation corrected and checked against direct quadratic forms (audit A4) | None modeled (descriptive) | F7 is a model-based scenario, not a comparison of existing places | `contrast-support.csv` (S2.5, corrected S7.2) |
| F9 | The parts of the disadvantage group point in different directions. The composition part (SVI themes 2 and 3, limited-English share) is negative in all four models (−0.15 to −0.29 SD), rurality and primary-care density positive (+0.16 to +0.24), and the material-deprivation part changes sign with the geographic grain. A negative composition coefficient is not evidence that these populations are protected, and a positive minority-status coefficient is not a patient-level risk. | Parts of the joint contrast | Model frame; specs 382, 344, 420, 458 | Exact split of the joint contrast by group | Model range over four specifications | Shows why direction is unsettled; carries the review's two interpretive cautions | `contrast-support.csv` (S2.5) |
| F10 | A supplementary, post hoc comparison averages fitted predictions over the observed community profiles in each extreme decile, other inputs fixed: +0.23 SD (SE 0.10) for material deprivation and −0.44 SD (SE 0.11) for composition at the county catchment, same signs at every grain. The raw differences in mean published PSI-90 between the same deciles are +0.15 and −0.22. | Fitted contrast over observed decile profiles | Evaluation frame | Model contrast on the deciles' mean design rows; raw outcome difference beside it | Model-based SE (coefficient covariance); not pre-registered | Context for F9, labeled supplementary and fitted at point of use (audit A5) | `contrast-support.csv` |
| F11 | How the catchment measures are built changes the answer. Rebuilding the SVI themes from comparable tract quantities cuts the tract-county gap in the joint contrast from +0.344 to +0.187 SD (county −0.188, tract −0.001). In the term accounting the remainder is carried mainly by the fitted income-index and limited-English terms, which differ by aggregation; the accounting does not isolate why (audit A12). | Gap in the joint contrast between grains | Model frame | Rebuilt themes, refit at P-best and siblings | **None modeled for the gap**; per-grain SE about 0.18 to 0.20 | Any community adjustment must fix its geographic construction first | `geo-construction.csv` (S2.6) |
| F12 | Filling the suppressed counts barely moves the aggregate results (loss within 0.15%, joint contrast within 0.08 SD) but moves individual hospitals: the rank correlation of each hospital's community contribution falls to 0.92 overall and 0.84 among the 251 hospitals with the fewest mapped discharges, and one hospital moves 1,696 places of 2,569. | Hospital-level community contributions | Model frame; specs 382 and 344 | Four fixed fills and 20 uniform draws on 996,700 suppressed cells | Scenario range | Public data, as constructed here, do not support a hospital-by-hospital community adjustment; the fills are not probabilistic bounds | `suppression-sensitivity.csv` (S3.2) |
| F13 | Adding ownership and system membership moves the contrast by at most 0.04 SD. | Joint contrast | Model frame; P-best, P-median | Refit with Block A extended | None modeled (two refits) | Robustness of F7; supplement table, one clause in sec 6 | `ownership-sensitivity.csv` (S3.3) |

## 3. Which community data to keep (report sec 6)

| ID | Claim | Target | Sample | Method | Uncertainty | Decision relevance | Source |
|---|---|---|---|---|---|---|---|
| D1 | In states held out of the refit, dropping the community block raises held-out loss by 2.2% (1.0% to 3.1%). | Held-out squared-error loss relative to the full block | Evaluation frame (spec 382's settings, chosen beforehand on all hospitals) | Five-fold cross-validation with states as folds, repeated 20 times | Repeat range; conditional on the prior selection of settings (audit A8) | Within the selected settings, the community measures earn a place out of sample | `geo-validation.csv` (S2.4) |
| D2 | The four SVI themes plus the limited-English share are 0.37% worse than the full block (−0.98% to 1.34%) in held-out states, within the chosen 1% mean-loss tolerance (a practical rule, not a statistical equivalence test), and keep 89% of its gain; ADI alone falls 1.30% (0.11% to 2.25%) short and keeps 38%. Within known areas the SVI set keeps 83% and ADI 44%. | As D1, per reduced dataset | As D1 | As D1, plus within-area folds | Repeat range | Basis for naming the SVI set a candidate community-data module for this analysis (never a "minimum dataset" for CASH2) | as D1; S3.5 scope |
| D3 | All of D1 and D2 sit on a small base: the best model explains 4.0% of the variation in published PSI-90 in unseen states and 6.8% within known areas, against 11.0% in sample. | Held-out R² | As D1 | As D1 | None modeled for the R² values | Keeps D2 from being read as a large gain | as D1 |

## 4. Payment consequences (report sec 7)

Every claim in this group except P1 and P2 describes **a project-defined
rank-based rule that uses CASH2's bonus band and revenue assumptions** (a 0.1%
to 4% bonus band on commercial revenue, a linear rank-to-rate map, PSI-90 at
15% of a six-measure scorecard), not Q-HIP, whose formula is not public, and
not CASH2's own improvement formula (audit A10). The commercial share is a
residual inpatient-day share, a proxy for eligible revenue. Dollar figures
are national what-ifs, because participation cannot be identified by
hospital. The base run's score draw is a hypothetical repeated measurement
under the reliability approximation; the fixed-score run is reported beside
it (audit A2).

| ID | Claim | Target | Sample | Method | Uncertainty | Decision relevance | Source |
|---|---|---|---|---|---|---|---|
| P1 | Under the Medicare program running today (FY 2026 HACRP), hospitals in the most deprived fifth of catchments were penalized at 1.39 (1.14 to 1.71) times the rate of the least deprived fifth; safety-net hospitals at 1.14 (0.98 to 1.33), an interval that includes parity. This describes who was penalized in this frame, not why. | Penalty rate ratio | HACRP frame | Observed penalties by ADI fifth and safety-net flag | Log-scale normal approximation (audit A7); the separate concentration index uses a 2,000-resample hospital resampling | The fairness question already applies to a live program that uses PSI-90 | `observed-hacrp-regressivity.csv`; regressivity statement item 10 |
| P2 | The scoring machinery reproduces HACRP: 3,054 of 3,055 penalty decisions from the published inputs, and 627 expected against 629 observed when PSI-90 is replaced by model draws (calibration slope 1.09, AUC 0.967). This validates the scoring shared with the simulation, not the Q-HIP rule. | Agreement with observed penalties | HACRP frame | C1 gate, C2 calibration | C2: simulation 95% on the count (623 to 632) | Limits what "validated" may mean in sec 7 | `hacrp-calibration.csv` |
| P3 | If every hospital improves PSI-90 by 0.05 at once and the scoring reference is recalculated, ranks and payments are unchanged with revenues fixed (total change $0). Held at the original reference, the same shift moves 2,384 of 2,569 positions and total payment by −$56.5M (diagnostic). | Change in total payment | Evaluation frame | All-improve experiment, stage 35; fixed-reference diagnostic, stage 37 | **None modeled** | This rule does not increase its payout for a common shift; attainment targets, fixed benchmarks or an improvement credit are untested alternatives (audit A6) | regressivity statement item 6; `all-improve-reference.csv` |
| P4 | Per revenue dollar, safety-net hospitals' return to a 0.05 improvement is 0.64 with published scores fixed and 0.62 (0.59 to 0.65) under the score draws, and below 1 in every scenario (0.35 under CASH2's 0.40 safety-net factor, 0.87 under CASH2's flat share). | Safety-net ratio of finite return per net patient revenue | Model frame | Finite return, base and 13 scenarios | Simulation 95%; scenario range | Robust direction; size depends on the commercial-share assumption | `payment-scenarios.csv` |
| P5 | Per revenue dollar, the return falls with catchment deprivation (concentration index −0.035 with published scores fixed; −0.058, −0.073 to −0.044, under the score draws, an interval from that draw alone; 39.2 against 47.6 basis points of revenue per full PSI-90 unit, about 1.96 against 2.38 for the 0.05 step, most against least deprived fifth). It holds under every rate curve, PSI-90 weight and revenue multiplier, weakens under CASH2's flat share (−0.017) and the PSI-90-only scorecard (−0.020), and shows no clear direction under CASH2's 0.40 safety-net factor (−0.008, −0.021 to +0.004). Much of it lines up with the estimated commercial share (0.238 against 0.272), a day-share proxy. | ADI concentration index of finite return per net patient revenue | Evaluation frame | As P4 | Simulation 95% (score draw only); scenario range | The revenue base moved the unevenness most, the scorecard too; the proxy and the unvalidated score draw are named at point of use | `payment-scenarios.csv`; regressivity statement items 3, 5 |
| P6 | Against catchment disadvantage as the models rank it (the pre-registered primary ranking), the return is on the edge under the score draws: −0.038 (−0.085 to −0.0004), an endpoint within one Monte Carlo standard error of zero, with no clear direction in 8 of the 13 other scenarios, the fixed-score run among them (−0.017, −0.064 to +0.021). | Concentration index along model-implied disadvantage | Model frame | As P4 | Simulation 95%; Monte Carlo SE 0.0004; scenario range | Not a basis for calling the rule regressive; the report does not lead with that word | regressivity statement item 2; S1.6 note |
| P7 | Against distance from the best measured score, the return shows no clear direction (−0.000, −0.035 to +0.034); only a convex rate curve makes it regressive (−0.048, −0.086 to −0.009). | Concentration index along distance from best score | Model frame | As P4 | Simulation 95%; scenario range | The rate curve's shape is a design choice that sets how much the furthest hospitals gain relative to others | `payment-scenarios.csv` |
| P8 | Total payment under the base rule is $5.84B, and $3.6B to $9.0B across the scenarios. | Total bonus dollars | Evaluation frame | As P4 | Simulation 95%; scenario range; eligibility unknown | Context only; national what-if, not realized Q-HIP payments | `payment-scenarios.csv` |

## 5. Connection to CASH2 (report secs 2 and 8)

| ID | Claim | Target | Sample | Method | Uncertainty | Decision relevance | Source |
|---|---|---|---|---|---|---|---|
| T1 | The memo's safety-net shares by Track are partly supported (48%, 24% and 12% against 50–70%, 15–30% and 5–10%). Its bed counts are scenario inputs for constructed health systems, so the single-hospital data cannot test them: the Track 3 cell's median hospital has 144 beds, and 11.2% have 500 or more. | Memo parameters against hospital cells | Star arm, 2,581 | Cell medians and shares | None modeled | Which CASH2 inputs national data support | `archetype-validation.csv`; S3.4 note |
| T2 | The data do not establish stable three-Track groups: 1,591 of 2,581 hospitals (61.6%) fall off the Track diagonal, and the preferred clustering recurs in only 44% and 59% of subsamples. | Track cell concentration and cluster stability | Star arm 2,581; clustering 2,759 | Nine-cell cross-tabulation; ICL and gap statistic; 100 × 80% subsamples | Subsample share; none modeled for the 61.6% | ROI inputs should be per hospital, not per Track; stated as an open limit in sec 8 | `archetype-cells-full.csv`; `cluster-summary.csv` |
| T3 | CASH2's verification script reproduces the memo's base-case returns (4.31, 10.38, 9.42) and its returns without the bonus (2.68, 5.44, 2.92). That confirms the arithmetic under the memo's assumptions, which this project neither establishes nor overturns. | Memo arithmetic | None (memo inputs) | `verify_models.py` rerun | None modeled | Scope statement; quoted external values in the sec 2 registry block | S3.5 note |

## 6. Data and missingness (report sec 3)

| ID | Claim | Target | Sample | Method | Uncertainty | Decision relevance | Source |
|---|---|---|---|---|---|---|---|
| M1 | Of 4,790 facilities, 2,801 acute care hospitals have a published PSI-90, and 2,569 are complete on every model term, the common evaluation frame; each model is fitted to the hospitals complete on its own terms (803 to 2,744). The 232 left out are smaller and in more deprived catchments. | Inclusion flow | All | Stage 43 inclusion flow | None modeled | Who the findings describe (audit A9) | `inclusion-flow.csv` |
| M2 | Missing contract-labor values are imputed under a working assumption that they are missing at random; shifting the imputations by ±1 SD moves the community share by at most 0.03 points. The choice between complete-case and imputed frames moves the model reliance about 30 times more, so the complete-case restriction is the larger missing-data question. | Sensitivity of F1 and F5 to the missing-data treatment | Frame; M-best, M-median | Shifted imputations; three missing-data arms | Scenario range | Names the untested assumption (follow-up 4) | `mnar-sensitivity.csv` (S3.1) |
| M3 | The full pipeline rebuilt from raw data in a clean checkout on the project machine (cold analytical run, S4.1) and the documents were built by a later warm release run. An independent build on another machine (S6.1) has not been done. | Reproducibility | All | `make.R --release --cold`; `make.R --release` | None modeled | The analysis can be rerun on the next PSI-90 release; external reproducibility is not yet shown (audit A12) | S4.1, S5.5 and S7.5 notes |

---

## 7. Claims the report does not make

These stay out of the main report, or appear only as stated here.

1. **No minimum dataset from the importance tags.** The repaired direct and
   shared reliance (TIS) tags no measure essential at the primary tolerance.
   The method and table go to the supplement, labeled exploratory with their
   lineage. Any data recommendation rests on D2.
2. **No causal or effort language.** No coefficient is read as an effect, no
   share as hospital-controlled, and no association as a bias with a direction
   unless a mechanism is shown (stage 39 bans the verbs).
3. **No claim of equal treatment** without an equivalence range, and no claim
   that an estimate errs on the safe side without a demonstrated mechanism.
4. **No "regressive" as the lead word** for the payment result (P6).
5. **No validation of Q-HIP.** P2 validates the shared scoring only.
6. **No missing-at-random as established.** It is a working assumption (M2).
7. **No novelty claim.** The draft's sentence on precedent is deleted, or
   bounded to what the CASH literature review covered.
8. **No return-on-investment figure.** That is the next exercise (S3.5).
9. **No hospital-level community adjustment** is proposed (F12).
10. **No ceiling from a variance share.** A Shapley share is not a bound on
    how far any adjustment would move scores or payments (audit A3).
11. **No real-place reading of the synthetic contrast** (F8, audit A4), and
    no fitted contrast described as an observed difference (F10, audit A5).
12. **No equivalence** from the 1% mean-loss tolerance (D2, audit A8).
13. **No universal property of rank-based rules** from the all-improve
    result (P3, audit A6).
14. **No claim that the reliability approximation touches sensitivity
    analyses only** or that its error has a known direction (audit A2).

## 8. Settled outline

Table 3 of the task sheet, revised for the fairness framing. The Track cells
lose their own section: the memo-parameter check (T1) joins section 2, the
instability result (T2) joins section 8, and the nine-cell table moves to the
supplement. The 450 words go mostly to the payment section, which now carries
the scope statement for the CASH2-style rule and the observed HACRP result.

| Section | Content | Claims | Words | Figures and tables |
|---|---|---|---|---|
| 1. Summary and decision points | The fairness finding first, then payment and data, decision points, the short claim table | all | 800 | Table 1: claim-to-evidence (short) |
| 2. The question and its connection to CASH2 | Fairness of PSI-90 as the question; what a public-data analysis can and cannot separate; S3.5 scope statement; memo parameters | T1, T3 | 500 | None |
| 3. Data | Sources, inclusion flow, catchments, missing data as a working assumption | M1, M2, M3 | 700 | Table 2: inclusion flow |
| 4. Methods | Published score primary, specification space, Rashomon sets and MCR in plain language, the held-out validation, the payment simulation | — | 850 | None |
| 5. How much variation public characteristics describe | Decomposition, components model, residual | F1–F4 | 500 | Figure 1: decomposition |
| 6. Community associations across models and geography | MCR bounds with tolerance, direction, parts, construction, suppression, the data-module validation | F5–F13, D1–D3 | 950 | Figure 2: MCR bounds or specification curve; Table 3: validation |
| 7. Payment consequences | Observed HACRP, the CASH2-style rule and its assumptions, finite returns, scenarios | P1–P8 | 1,050 | Figure 3: payment returns; Table 4: scenarios by verdict |
| 8. What remains open | Limits not stated at point of use, Track instability, follow-ups, next ROI exercise | T2 | 650 | None |
| 9. Sources | Direct citations for CMS methods, program rules, MCR and CASH2 (audit A12) | — | 250 | None |
| | Total | | 6,000 | 3 figures, 4 tables |

Moving to the supplement: the nine-cell table and Fig 6, the TIS method,
table and Fig 5, the reliability-by-volume figure (Fig 1 of the draft), the
uncertainty trace, the suppression, shift and ownership sensitivity tables,
the full registry and the glossary.
