# Task S3.1 — The inclusion flow and the missing-data assumption

**Date:** 2026-10-04 · **Budget:** 2 h · **Status: done. Stage 43,
post-review.** Every analytic frame now traces to the 2,801-hospital outcome
frame in one table, and stage 39 stops if any keyed row disagrees with the
count it registers. The preregistered shift of the imputed contract-labor
values does almost nothing: across shifts of ±0.5 and ±1 SD at both MI anchors
the community share moves by at most 0.03 points and the reliance on the
disadvantage group by at most 0.0004. That is mostly because the imputed
hospitals never enter the 2,569-hospital frame on which loss and reliance are
measured, and the headline community share is complete-case. Which
missing-data arm a model uses matters more than what the imputed values are
(sec 4).

---

## 1. What ran

`R/17-inclusion-missingness.R`, registered as stage 43 before stage 39
(about 80 s; deterministic, a second run is byte-identical). Outputs:
`output/tables/inclusion-flow.csv` (33 rows), `output/tables/mnar-sensitivity.csv`
(18 rows) and the log `taskS3.1-inclusion-missingness.txt`.

- **Each frame is rebuilt by its own stage's rule**, not by a new definition:
  the composite frame by 06-mcr.R's `KEEP` (asserted identical), the star frame
  as stage 34 builds it, the clustering frame as stage 33, the payment and
  calibration frames as stage 35. Each is asserted equal to that stage's count.
- **Stage 39 reconciles** the 14 rows that carry a registry key (`section|key`)
  against the registered value and stops on any difference. Shown to fail: with
  row 15 edited to 2,570 the stage stops with "inclusion flow does not
  reconcile: 03-data|n_cc_abc = 2569, flow row 15 … = 2570".
- **Stage 17 (missingness audit) reworded**, numbers unchanged (checked
  column by column against the previous table):
  - `mar_licensed` is now `missing_predicted`.
  - `disposition` now records what the analysis does. It used to read "MI" for
    all eight substantive variables, but only contract labor is imputed; the
    other seven are analyzed at their own coverage (three components),
    complete-case (operating margin, uncompensated care, market concentration)
    or not modelled (system membership).
  - The header and printout no longer say the regression "licenses" MI or
    that MI is "unbiased".
- Stage 39 registers 1,818 numbers (1,480 before this task); the flow and
  shift keys are `if <frame> <step>` and `mnar <anchor> <delta> <quantity>` in
  03-data and 09-limitations.

## 2. The inclusion flow

| Frame | Step | n | Removed, and why |
|---|---|---|---|
| Outcome | Care Compare provider file | 4,790 | |
| | numeric PSI-90 published | 2,908 | 1,882 without one |
| | acute care, VA excluded | **2,801** | 107 VA hospitals |
| Components (not imputed) | PSI-03 / 06 / 12 / 13 | 2,778 / 2,801 / 2,727 / 2,313 | footnote 1 (too few cases): 23 / 0 / 74 / 436; footnote 7 (no eligible cases, structurally inapplicable): PSI-13 52 |
| | all four | 2,294 | 507 |
| HACRP comparison | PSI-90 in both files | 2,793 | 8 |
| Composite model | Block A complete | 2,744 | 57 (uncompensated care 54, operating margin 19, others 2–3) |
| | Block B complete at every grain | 2,700 | 44 (a Block B measure, market concentration included, missing at some grain) |
| | contract labor observed and in range | **2,569** | 131 (114 missing after recovery, 17 outside [0, 0.50]) |
| | left out in total | 232 | sole reason: Block A 32, Block B 36, contract labor 131; 33 for more than one |
| MI and omit arms (M-best, M-median) | fit frame | 2,700 | 131 imputed hospitals enter the fit; evaluation stays on the 2,569 |
| Star rating | star published | 2,593 | 208 unrated |
| | margin present | **2,581** | 12 (4 net patient revenue under $1M, where the margin is undefined; 8 not in HCRIS) |
| Clustering | margin present, margin ≥ −1 | 2,759 | 19 missing, then 23 below −1 |
| Payment | model frame, positive NPR | 2,569 | 0; 139 of them unrated |
| HACRP calibration | HACRP PSI-90 value present | 2,564 | 5 |
| | outside Maryland | **2,551** | 13 (Maryland is waived) |

The FY 2026 HACRP file has 3,055 rows (gate C1's file, not a subset of the
frame).

**Two different 139s.** The payment frame's 139 unrated hospitals and the 139
hospitals missing contract labor are disjoint (the second group is entirely
outside the payment frame). The report should never give either as "139"
without its noun.

**The 158 imputed contract-labor values** are 139 missing after the Task 1.6
recovery and 19 observed but above 0.50 (0.503 to 0.814), set to missing by
gate C2.d. The Task 2.6 audit modelled the missingness of the 139 only. Of
the 158, 131 are otherwise complete for every composite term and enter the MI
fits; 27 are also excluded for another reason. None is in the evaluation
frame. The imputed values average 0.100 against 0.076 observed: predictive
mean matching gives the missing hospitals higher contract-labor shares than
the observed average, as the imputation model's covariates predict.

## 3. The missing-data claim, restated

Draft (sec 3, para 41): "That condition, called missing at random, is the one
under which multiple imputation gives unbiased estimates, and the missingness
audit licensed imputation for all 8." Sec 9, para 18: "Multiple imputation,
which was licensed for all of them …"

For S5:

> For every variable with substantive missingness, whether a value is missing
> is predicted by fully observed hospital characteristics (bed count,
> rurality, ownership, teaching status, wage index, volume, case mix and
> occupancy). That is consistent with the values being missing at random given
> those characteristics, but it cannot establish it: missingness could also
> depend on the unseen values. Only contract labor share is imputed, 20 times,
> under that working assumption, for 158 hospitals (139 with no usable cost
> report value and 19 whose reported share exceeded 50%). The component
> outcomes are not imputed: a component is missing when CMS suppresses it for
> too few cases or when no case is eligible, and each is analyzed at its own
> coverage. Operating margin, uncompensated care and market concentration are
> handled complete-case, and the composite models run on 2,569 of the 2,801
> hospitals. Shifting every imputed contract-labor value up or down by half
> or one standard deviation of the observed share changes the community share
> by at most 0.03 percentage points and the reliance on the disadvantage
> measures by at most 0.0004 in the two imputation-arm models tested.

S2.3's claim guard already flags "licensed" and "unbiased" in report prose
(`claim-guard-hits.csv`, rule `imputation`); the three Sep 30 hits stay on the
S5 worklist.

## 4. The shift sensitivity

Preregistered (sec 7): imputed values only, shifted by δ × SD of the observed
share (SD 0.0748), δ = −1, −0.5, +0.5, +1, in all 20 completions, on M-best
(spec 80, catch_county) and M-median (spec 157, hosp_county). Both anchors
were re-derived by the sec 1 rule (17 unweighted MI members).

- **Community share** is the community block's LMG share, defined as stage 22
  defines it, computed in the anchor's own model and fit frame (2,700) and
  averaged over completions. The function reproduces stage 22's published
  3.32% exactly on spec 343, the linear complete-case tract spec that is
  stage 22's model.
- **Reliance** is the MR of the ten-measure disadvantage group, as stage 30
  computes it, on the common 2,569 frame. At δ = 0 both anchors reproduce
  `mcr-per-model.csv` (difference under 1e-9) and `rashomon-loss.rds` (under
  1e-10).

| Anchor | δ | Community share | Change (points) | MR, disadvantage | Change | Contract-labor coef. |
|---|---|---|---|---|---|---|
| M-best (80) | −1 | 5.108% | −0.013 | 1.1153 | +0.0004 | +0.0103 |
| | −0.5 | 5.113% | −0.008 | 1.1150 | +0.0001 | +0.0105 |
| | 0 | 5.121% | | 1.1149 | | +0.0105 |
| | +0.5 | 5.132% | +0.011 | 1.1149 | +0.0000 | +0.0102 |
| | +1 | 5.146% | +0.025 | 1.1150 | +0.0001 | +0.0097 |
| M-median (157) | −1 | 4.253% | −0.018 | 1.0957 | +0.0002 | +0.0105 |
| | −0.5 | 4.260% | −0.011 | 1.0955 | +0.0001 | +0.0108 |
| | 0 | 4.271% | | 1.0955 | | +0.0108 |
| | +0.5 | 4.284% | +0.013 | 1.0955 | +0.0000 | +0.0106 |
| | +1 | 4.299% | +0.028 | 1.0957 | +0.0002 | +0.0102 |

The coefficient is in PSI-90 units per SD of observed share.

- **Supplementary, fixed before the first run:** a shift of −1 SD takes 1,842
  of the 3,160 imputed values below zero (−0.5 SD: 1,027). Clamping each shifted value
  to [0, 0.50] gives the same picture (largest change 0.025 points and 0.0002).
- **Why so little moves:**
  - The imputed hospitals are 131 of 2,700 in each fit and none of the 2,569
    on which loss and reliance are scored.
  - Contract labor's own coefficient is small (about 0.01 PSI-90 units per SD,
    against a PSI-90 SD of 0.19) and barely responds to the shift.
- **The anchors' shares are not the headline.** 5.1% and 4.3% are spline
  models at county grains on the MI fit frame. The published headline (3.3%)
  is the linear tract-grain model on the complete-case frame and never sees
  an imputed value, so no shift of imputed values can move it.
- **What matters more (stored outputs, not new runs).** At M-best's settings
  the three missing-data arms give disadvantage-group reliance of 1.1149 (MI),
  1.1268 (complete-case, spec 382 = P-best) and 1.1203 (omit), and joint
  contrasts of −0.17, −0.22 and −0.16 SD. At M-median's settings: 1.0955,
  1.1044, 1.1004 and −0.00, −0.04, +0.02. Which hospitals are in the fit moves
  the quantities 30 times as much as the imputed values do. The complete-case
  restriction, which drops 232 smaller hospitals in more deprived catchments,
  is the missing-data choice the report should discuss. The imputation is a
  much smaller one.

## 5. Verify

- **Counts reconcile.** The flow table's counts equal every frame stage 39
  registers: 2,801, the four component counts, 2,294, 2,793, 2,569, 232,
  2,581, 208, 139, 3,055, 2,551. The check runs inside stage 39 on every run
  and was shown to fail on a wrong count.
- **"Licensed" and "unbiased".** Neither word describes the imputation in
  any script, generated log or table. The remaining hits are:
  - data licences, "licensed beds", and the claim-guard regex itself;
  - the frozen Sep 30 prose in `tools/claim-guard/sep30/`, kept on purpose as
    the guard's self-test;
  - the three draft-report paragraphs above, flagged for S5;
  - Phase 2 provenance notes (`task2.6-missingness.md`,
    `admission-results.md`), left unedited as the record of what was believed
    then. This note supersedes their wording.

## 6. Not done

- No sensitivity for the complete-case restriction itself (an MI arm for
  operating margin, uncompensated care and market concentration). Sec 4's
  arm comparison suggests it matters more than the contract-labor assumption.
  It would need a new imputation model and a refit of the composite set, so it
  goes to `follow-ups.md` (row 4).
- The shift is uniform across imputed hospitals. A shift that varies with
  disadvantage, which is the MNAR pattern the equity question cares about,
  was not preregistered and was not run.
