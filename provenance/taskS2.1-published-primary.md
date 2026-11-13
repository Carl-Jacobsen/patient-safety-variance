# Task S2.1 — Make the published score the primary outcome

**Date:** 2026-10-03 · **Budget:** 2.5 h · **Status: done.** Every stage that
orders the reliability analyses now leads with the unweighted fit to the
published score and reports the λ-based fits beside it as sensitivity analyses
under the project's scalar approximation. No number moved: the decomposition,
spec-curve, MCR and baseline tables are byte-identical to the S1.6 state. What
changed is order, labels, the generated statements, one new table of the
Rashomon set restricted to its published-score members, and three new checks in
stage 39. The September 30 prose fails those checks, as it should until S5.

---

## 1. What changed

| Stage | Script | Change |
|---|---|---|
| 1b | `R/phase0-followup.R` | The −0.193 slope is printed as a diagnostic consistent with shrinkage, not an identification of it (total Medicare volume is not the component-specific denominator). "Recovers about 47% of the true gradient" and "the part the composite hides" become results under the scalar approximation. Number lines untouched, so stage 39's patterns still match. |
| 21 | `R/03-baseline.R` | "CMS's own composite reliability" becomes "the composite reliability implied by the project's scalar approximation". |
| 22 | `R/03-variance-decomposition.R` | Published score first, labeled primary; weighted fit labeled sensitivity; table `version` strings renamed (sec 2); the statement rewritten (sec 2); the "what the smoothing conceals" reading removed; verify now fails if the weighted share precedes the published one or if the statement uses any of eight retired terms. |
| 25 | `R/04-spec-curve-report.R` | The errors-in-variables shift is "what the scalar approximation predicts", not "the un-attenuation the smoothing was concealing". |
| 30 | `R/06-mcr-run.R` | "AND IT IS A LOWER BOUND" replaced: MCR⁻ is stated for the published score as fitted, the attenuation reading is labeled conditional on the approximation. New sec: the set and its bounds for the `reliability = unweighted` members beside the full set, at all three tolerances, written to `output/tables/rashomon-published-subset.csv`. |
| 38 | `R/12-figures.R` | Fig 2 panel A: the published score is the filled marker, the weighted fit the open one, key and residual note relabeled. |
| 39 | `R/13-report-numbers.R` | Decomposition keys registered in pairs (sec 4); published-subset keys in 04, 05 and 06; the published residual is primary; λ sources say "scalar approximation"; the −0.193 slope registered in 03 as a diagnostic; three new checks (sec 4). |

The MCR cache is keyed on `06-mcr-run.R` itself, so the edit forced the 3.6-min
refit. `mcr-per-model.csv`, both bounds tables and the coefficient ranges came
back identical, so stage 32's TIS invariants are unaffected. Stage 22's
components bootstrap is keyed on its functions, not its file, and was reused.

Stage 2 (Task 1.2 acquisition) ran once by mistake, before I saw that the Phase
0 follow-up is stage `1b`. It only queried the CMS catalogue and re-hashed the
archived files (all matched); nothing in `data-raw/` or the tree changed.

## 2. The decomposition, published score first

The table's `version` column now reads `published, unweighted (OLS) -- primary`,
`reliability-weighted (WLS, scalar lambda_i) -- sensitivity` and
`between-hospital variance component (components carry no composite smoothing)`.

| Analysis | Community | Structure | Explained | Residual |
|---|---|---|---|---|
| Published score, unweighted (primary) | 3.3% (2.5% to 4.8%) | 4.5% (3.5% to 6.8%) | 8.8% | 91.2% |
| Reliability-weighted, scalar λ (sensitivity) | 3.6% (2.8% to 5.3%) | 4.3% (3.3% to 6.8%) | 9.1% | 90.9% |
| Components, share of between-hospital variance | 1.44% (−0.60% to 3.67%) | 7.5% | — | 88.1% |

The task sheet quotes the components share as 1.45% (−0.58% to 3.71%). Those are
the v1 values; the v2 file gives 1.44% (−0.60% to 3.67%), and the registry
carries the v2 renderings at one and two decimals.

The statement stage 22 now prints:

> Community disadvantage (Block B) is associated with an estimated 3.3% (95%
> interval 2.5% to 4.8%) of the variation in published PSI-90 across hospitals,
> against 4.5% (3.5% to 6.8%) for hospital structure (Block A); of the 8.8% the
> three blocks explain together, community accounts for 37.8% and structure for
> 51.0%. Weighting each hospital by its reliability under the project's scalar
> approximation gives 3.6% (2.8% to 5.3%) of reliability-weighted variation, a
> different descriptive allocation rather than a correction. On the four
> component measures, community accounts for 1.44% (-0.60% to 3.67%) of the
> between-hospital variance, an interval that includes zero. The 91.2% left
> unexplained is conditional on these linear covariates, the complete-case frame
> and squared-error loss; it is not the share of harm unrelated to hospitals or
> communities.

The 0.28-point difference between the weighted and unweighted community shares
is registered (`vd_shift`, at one and two decimals) with the source note "two
allocations, not hidden signal". Weighting changes which hospitals dominate the
variance being decomposed; it does not undo smoothing, so the difference has no
reading as community signal the composite concealed.

## 3. The Rashomon set on the published score

From stage 30's cached reliance, no refit. The full-set rows reproduce
`mcr-bounds-blockB.csv` and the stage 28 width exactly (a `stopifnot`).

| Tolerance | Members | n | MCR⁻ | MCR⁺ | Contrast range (SD) | Median | Best member |
|---|---|---|---|---|---|---|---|
| hospital (primary) | all | 194 | 1.0848 | 1.2300 | −0.370 to +0.858 | +0.062 | 418 (EIV) |
| hospital (primary) | unweighted | 65 | 1.0848 | 1.1491 | −0.227 to +0.182 | +0.022 | 382 |
| metro | all | 319 | 1.0790 | 1.2300 | −0.370 to +0.907 | +0.113 | 418 |
| metro | unweighted | 105 | 1.0790 | 1.1491 | −0.227 to +0.347 | +0.125 | 382 |
| state | all | 536 | 1.0000 | 1.2300 | −0.370 to +0.952 | +0.226 | 418 |
| state | unweighted | 180 | 1.0000 | 1.1491 | −0.227 to +0.367 | +0.175 | 382 |

Two readings for S5. The reliance lower bound does not depend on the λ arms:
the least reliant member of the full set at each tolerance is itself an
unweighted member, so MCR⁻ is identical in both rows. The contrast range does
depend on them. Restricted to the published score, the primary set's range
shrinks from 1.23 SD to 0.41 SD (−0.227 to +0.182), and its whole positive tail
above +0.18 (including all 16 straight-line members, +0.52 to +0.88) comes from
the errors-in-variables arm. The best unweighted member is spec 382, the
preregistered P-best anchor, with a contrast of −0.21 (SE 0.20). Per measure,
every unweighted MCR⁻ is at least the full-set value (limited English 1.026
against 1.017, SVI 3 1.010 against 1.006); PCP density reaches exactly 1.000.

## 4. The new checks in stage 39

1. **Pairs in the registry.** Every composite decomposition key is registered by
   `reg_pair()`, once as `published` and once as `weighted`, so neither can be
   cited from the registry without the other existing. The summary and actions
   sections copy both members of every pair plus the components share.
2. **Pairs in the prose.** A paragraph that cites a weighted share (community,
   structure or residual) and mentions reliability, λ, weighting or correction
   must also cite the published share of the same block. A section that cites a
   composite community share in a sentence about variation must cite the
   components share. Renderings match as whole tokens, so "3.3%" does not match
   inside "33.3%".
3. **Generated text.** Every stage log in `output/tables/*.txt` is scanned for
   seven retired phrasings (reveal, conceal, "the composite hides", "recovers
   about N% of the true", un-attenuation, "signature of an interval", "what the
   smoothing …"). The scan passes.

On the September 30 text, check 2 fails in 01 and 05 (structure 4.3% and residual
90.9% cited without their published pairs; the components share absent, since
05 carries the v1 "1.5%"). That is the expected state until S5. The check has
one known blind spot: a rendering can coincide with an unrelated number in the
same paragraph (in 05's first paragraph the published community 3.3% collides
with the structure interval's lower end), which is why it tests all three
blocks.

Stage 39 run: registry 820 numbers; failing sections 01, 03–06, 08–10 on the
same stale v1 numbers as after S1.6, plus `weighted_with_published` and the six
dead claims. `generated_text_shrinkage` passes.

## 5. Draft sentences to replace in S5

Numbers in the replacements are v2 and registered. S5 writes the final prose;
these fix the claims, not the wording.

### 5.1 Sentences that say the intervals reveal or recover CMS's shrinkage

| Where | Draft | Replacement |
|---|---|---|
| 03 ¶2 | "The published confidence intervals do, however, reveal how hard each hospital was pulled." | "The published intervals are consistent with this smoothing, and under a scalar approximation they imply how far each hospital was pulled." |
| 03 ¶2 | "From them we recover a reliability for each hospital, written λ (lambda): the share of the hospital's own deviation from the national mean that survives into the published number." | "From them we derive an approximate reliability for each hospital, written λ (lambda), which is the share of the hospital's own deviation that would survive into the published number if the composite were a single normal shrinkage toward one national mean; CMS builds it from ten separately smoothed components, so λ is a result of that approximation and not a quantity CMS reports." |
| 04 ¶21 | "The reliability λ measures how much of each hospital's own signal survives this process." | "Under the project's scalar approximation, the reliability λ estimates how much of each hospital's own signal survives this process." |
| 04 ¶23 | "The fourth reverses the smoothing: it stretches each hospital's published deviation … by the inverse of its reliability, recovering an estimate of the unsmoothed score …" | "The fourth stretches each hospital's published deviation from the national mean by the inverse of its approximate reliability, which would undo the smoothing if the approximation held, and weights the result … (an errors-in-variables correction)." Order: unweighted first and labeled primary, the other three labeled sensitivity analyses. |
| 09 ¶11 | "… so λ is recovered from the published confidence intervals, which are rounded to two decimal places." | "… so λ is derived from the published confidence intervals, which are rounded to two decimal places, under an approximation that has not been checked against CMS's release-specific method (a question to QualityNet is drafted at Task S2.2)." |
| 09 ¶11 | "The recovery assumes that CMS's intervals are the posterior intervals of a normal smoothing model, which CMS does not document fully." | "The derivation assumes that the intervals are posterior intervals of one normal smoothing model with a single hospital-level shrinkage factor, which the composite's construction from ten smoothed components does not guarantee." |
| App ¶3 | "… the recovery of each hospital's reliability from the published intervals …" | "… the approximate reliability derived from the published intervals …" |
| App A.1 title | "Reliability recovered from the published intervals" | "An approximate reliability from the published intervals" |
| App ¶7 | "… so the smoothing it applies cannot be reversed from the counts, but the intervals reveal it." | "… so the smoothing cannot be reversed from the counts, and the intervals constrain it only under assumptions." |
| App ¶7 | "A slope that much flatter is what a posterior interval on a shrunk estimate produces: …" | "A slope that much flatter is consistent with a posterior interval on a shrunk estimate … It is a diagnostic, not an identification: total Medicare volume is not the component-specific at-risk denominator, and interval widths also move with case mix and component weighting." |
| App ¶9 | "The recovery treats each published value as the posterior mean …" | "The approximation treats each published value as the posterior mean …" |
| App ¶19 | "… and the recovery uses the two-decimal published score for the same reason." | "… and the derivation uses the two-decimal published score for the same reason." |

The appendix's second diagnostic (mean interval variance 0.04066 above the
variance of published scores 0.03678) is an argument that smoothing exists, not
how much any hospital was shrunk. It can stay as written.

### 5.2 Sentences that read λ results as recovered facts

| Where | Draft | Replacement |
|---|---|---|
| 01 ¶2, 05 ¶1 | "Under the reliability-corrected model, community disadvantage is associated with an estimated 3.6% … against 4.3% … for hospital structure; of the 9.1% …" | The sec 2 statement: published 3.3% (2.5% to 4.8%) against 4.5% (3.5% to 6.8%), of 8.8% explained 37.8% and 51.0%; weighted 3.6% (2.8% to 5.3%) as a share of reliability-weighted variation; components 1.44% (−0.60% to 3.67%) in the same paragraph. |
| 01 ¶2 | "The larger quantity is the remainder, since about 91% of the variation is associated with none of the covariates. A program that ranks hospitals on this score therefore ranks them mostly on variation that neither hospital nor community characteristics explain." | "About 91% of the variation is not associated with these covariates, a figure conditional on the linear covariates, the complete-case frame and squared-error loss; it is not the share of harm unrelated to hospitals or communities, and it does not by itself show that rankings on the score are invalid." |
| 01 ¶2, 05 ¶5.1 | "Part of that remainder is measurement noise that survives CMS's smoothing and part is hospital practice and case mix …" | Keep the sentence, add omitted covariates and nonlinear relationships to the list. |
| 03 ¶2, 09 ¶7, 10 ¶7 | "The median hospital retains 46% of its deviation (λ = 0.462)." | "Under the approximation, the median hospital's published score retains 46% of its deviation (λ = 0.462)." Same for the quartile (0.21, 0.76) and rural (0.304) figures. |
| 05 ¶5.1 | "Without any correction for CMS's smoothing, structure accounts for 4.5% …" | "On the published score, structure accounts for 4.5% …" |
| 05 ¶5.1 | "Weighting each hospital by its reliability raises community's share by 0.3 percentage points, to 3.6% … The direction of that shift is the one the reliability analysis predicts: CMS's smoothing … shrinks the differences associated with their communities more … so the correction sharpens the comparison without reversing it." | "Weighting each hospital by its approximate reliability gives community 3.6% of reliability-weighted variation and structure 4.3%. Weighting changes which hospitals dominate the variance being decomposed, so the two figures are different descriptive allocations, and the 0.28-point difference is not a measure of what the smoothing concealed." |
| 05 ¶5.1 | "… 9.1% … under the corrected model, which leaves 90.9% …" | "… 8.8% of the variation in the published score, which leaves 91.2% (90.9% of reliability-weighted variation) …" |
| 05 Panel B | "community disadvantage for 1.5% (−0.6% to 3.7%) … On the components, community's share is not distinguishable from zero." | Update to 1.44% (−0.60% to 3.67%) and move it beside the composite share at the top of 5.1, not after the remainder paragraph. |
| 05 ¶5.2 | "Reversing CMS's smoothing by the errors-in-variables correction raises the estimate in 91.5% … That pattern is further evidence that the smoothing was attenuating the association, and that discounting unreliable hospitals does not undo the attenuation." | "Under the scalar approximation, the errors-in-variables correction raises the estimate in 91.5% of the 176 paired composite cells, by a median of +0.34 standard deviations (composite median +0.18 unweighted, +0.47 corrected). That is what the approximation predicts if smoothing attenuates the association; it is a sensitivity result and not independent evidence for the approximation." |
| 05 ¶5.3 | "all 16 straight-line models in the set use the errors-in-variables correction …" and "The errors-in-variables members are the ones that reverse CMS's smoothing, and more years of data or published component numerators would make that reversal more precise." | Report the 65 published-score members beside the 194 (sec 3): their contrast runs −0.227 to +0.182 and their MCR⁻ is the same 1.0848. Say that the set's positive tail comes from the errors-in-variables arm and so depends on the approximation. |
| 09 ¶9 | "The errors-in-variables specifications reverse the smoothing, and they raise the disadvantage estimate in 91.5% of paired comparisons, which is what this account predicts." | "Under the approximation, the errors-in-variables specifications raise the disadvantage estimate in 91.5% of paired comparisons, as the account predicts; the agreement is not a test of the approximation." ("so the urban results are conservative" in the same paragraph is S2.3's.) |
| 10 ¶7 | "… once on a reliability-corrected version …" and "Reversing CMS's smoothing raised the community disadvantage estimate in 91.5% … so analyses that use the published score alone will tend to understate the association, most of all for rural hospitals." | "… once on the published score and once with each hospital's approximate reliability …"; the second sentence becomes conditional: "if the scalar approximation holds, analyses on the published score alone will understate the association, most of all for rural hospitals." |
| 10 ¶15 | "the models that reverse CMS's smoothing estimate the largest associations, and more years of data or published component numerators would make that reversal more precise." | "the models that apply the errors-in-variables correction estimate the largest associations, and they depend on the scalar approximation; component numerators or a release-specific derivation would show whether that approximation holds." |
| 01 decisions | "… or on a measure corrected for reliability, before any payment calculation rests on it." | "… or on a measure adjusted for reliability, noting that the project's adjustment rests on an approximation not yet checked against CMS's method …" |

## 6. Verify

- **Weighted and unweighted results never appear without each other.** In the
  regenerated outputs: stage 22's table, log, statement and verify, Fig 2, stage
  30's subset table and the registry pairs all carry both. In the prose: stage
  39's `weighted_with_published` enforces it and fails on the Sep 30 text, as
  expected.
- **No regenerated statement says the intervals reveal how much CMS shrank a
  hospital.** The stage 39 scan of every stage log passes; stage 22's own
  statement check passes.
- **Numbers unchanged.** `variance-decomposition.csv` (max difference 0),
  `mcr-per-model.csv`, `mcr-bounds-block{A,B}.csv`,
  `rashomon-coef-ranges.csv`, `spec-curve-{points,summary,reliability}.csv` and
  the five `baseline-*.csv` tables are byte-identical to before the task.

## 7. Left for later

- Stage 33 (clusters) already orders published before λ-corrected, but labels
  the second track "lambda-corrected (un-shrunk)" in its log and figure axis.
  Its cache is keyed on its script, and a relabel is not worth the refit now;
  S5 or the figure pass should relabel it.
- The appendix has no registry section, so the −0.193 slope and the λ
  percentiles there are unchecked. The slope is registered in 03.
- The Sep 30 payment sections use λ to draw scores (S1.6 described that target);
  none of their sentences claim the intervals reveal shrinkage.
- S2.3's guard on "reveal" near shrinkage or reliability will catch the 03 and
  appendix sentences in sec 5.1 as well.
