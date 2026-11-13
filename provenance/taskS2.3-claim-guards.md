# Task S2.3 — Narrow the credible-model language and add claim guards to stage 39

**Date:** 2026-10-03 · **Budget:** 1.5 h · **Status: done.** Stage 39 now
carries a claim guard: ten sentence-level rules for the meanings the review
retired. On the Sep 30 prose it finds 53 instances across every rule the review
names. It runs that test against a frozen copy of the Sep 30 prose on every
run, and stops if any required rule stops firing, so the guard cannot quietly
go blind. On `report/`, which is still the Sep 30 text, it fails, as it should
until S5. The generated text that made the same claims (stages 17, 18, 30, 32
and 38) has been reworded, and the stage-log scan from S2.1 now covers this
wording too. No number moved.

---

## 1. The guard

`R/13-report-numbers.R`, after the S2.1 checks. Each rule is a pattern applied
to every sentence of every `report/*.md` file, the appendix included. A rule
can require a second pattern in the same sentence (`with`), widen that
requirement to the paragraph (`para`), or exempt a sentence (`unless`).

| Rule | Fires on | Sep 30 hits |
|---|---|---|
| `every_credible` | "every credible model", "every one of the N credible models" | 21 |
| `no_credible` | "no credible model" | 9 |
| `universal_set` | the same claim without the word: "every model that fits …", "every model the evidence …", "models the evidence cannot tell apart", "none of them can do without", "no near-optimal model" | 4 |
| `reveal_shrink` | "reveal" in a sentence about shrinkage, smoothing, reliability, λ or intervals | 2 |
| `neutral` | "neutral" in a sentence without "no clear direction" | 7 |
| `conservative` | "conservative" in a sentence about a bias, result, estimate, error or direction | 2 |
| `imputation` | "licensed"/"license"/"unbiased" in a paragraph about imputation, MI or missing at random | 3 |
| `no_precedent` | "no precedent", "without precedent", "unprecedented", "first study to" | 1 |
| `confidence_set` | "confidence set/region", or "confidence" in a sentence about the Rashomon set or tolerance | 0 |
| `bound_alone` | the primary block bound (1.085 or 8.5%) in a sentence about reliance without the state bound (1.000) | 4 |

**Self-test.** `tools/claim-guard/sep30/` holds the eleven Sep 30 report files,
copied byte for byte from the `draft-2026-09-30` tag. On every run, stage 39
applies the guard there first and stops unless each of the nine rules the review
names fires at least once. `confidence_set` is reported but not required, since
the draft never used the phrase.

**On `report/`.** Any hit fails the stage (`claim_guard` in the verify list) and
is written to `output/tables/claim-guard-hits.csv` with file, paragraph and
text. That file is S5's worklist. The `bound_alone` renderings are computed
from `mcr-bounds-blockB.csv`, so they follow the numbers if a rerun moves them.

**Choices, checked against the fixture.**
- "Cannot distinguish" and "cannot rule out" count only when the subject is
  models, data or evidence. Two Sep 30 sentences ("most individual
  specifications cannot distinguish their estimate from zero"; "the partial
  proxy cannot rule out the coding explanation") are legitimate, and the first
  draft of the rule flagged both.
- `neutral` follows the task sheet literally, so it also flags 03's "the
  smoothing is not neutral noise", which is not a claim about an interval. S5
  can say "not uniform noise". I did not add an exemption, because an
  exemption list is the easiest place for a guard to leak.
- The rules match meaning by wording and will miss a paraphrase. The review's
  point stands: a reading for meaning stays separate from any automated check.

**Generated text.** The S2.1 scan of stage logs now also fails on "every
credible model", "no credible model", "no near-optimal model", "MI licensed"
and "MI is unbiased".

## 2. Generated text reworded

| Stage | Script | Was | Now |
|---|---|---|---|
| 17 | `R/missingness.R` | "-> licenses MI at 2.7", "MI licensed", "MI is licensed for every variable …" | "MI under a MAR working assumption"; observed predictors support MAR as a working assumption but cannot establish it |
| 18 | `R/blockC.R` | "Task 2.6 established MAR …, which is exactly where MI is unbiased" | "found missingness predicted by fully observed covariates, which supports MAR as a working assumption but cannot establish it" |
| 30 | `R/06-mcr-run.R` | "Of the specifications the data cannot distinguish from the best-fitting one, every single one relies … No near-optimal model on these data can ignore community disadvantage." | "Each of the 194 fitted specifications (of 736 composite specifications) whose in-sample excess loss lies within the bootstrap-calibrated empirical tolerance relies on community disadvantage … (MCR⁻ 1.085), while at the state tolerance the lower bound is 1.000. It describes these fitted models, not every model that fits nearly as well …" |
| 32 | `R/07-tis-run.R` | verify: "covariates no near-optimal model can ignore" | "covariates every fitted member relies on directly" |
| 38 | `R/12-figures.R` | Fig 4 key: "no model can ignore it" | "direct reliance > 1 in every fitted member" |

Checks on the reruns. Stage 17's `missingness-audit.csv` is byte-identical.
Stage 18's `blockC.rds` is byte-identical, and `blockC_mice.rds` differs only
in the `mids` date field: the imputations are equal and the content hash the
caches read is unchanged, so no downstream cache moved. Stages 30 and 32 are
covered in sec 4. The `mar_licensed` column name in `missingness-audit.csv` is
kept, since the registry and stage 18 read it; it is an identifier, not prose.

## 3. Replacements for S5

These are the forms the rewrite should use. Every sentence the guard lists is
in `claim-guard-hits.csv`.

**The set.** "Credible models" becomes "the 194 fitted specifications (of the
736 composite specifications) whose in-sample loss lies within the
bootstrap-calibrated empirical tolerance of the best", shortened after first
use to "the fitted members of the set" or "the 194 members". It is never a
confidence set, and never "every model the data admit".

**The block bound.** Wherever 1.085 appears, it carries 1.000 in the same
sentence. For example: "Scrambling the ten disadvantage measures raises the
squared error of every one of the 194 members, the least reliant by 8.5% (MCR⁻
1.085); at the wider state tolerance the set admits models with no disadvantage
measure, and the lower bound falls to 1.000." The S2.1 result belongs beside it:
the 65 members fitted to the published score without weights have the same
MCR⁻ of 1.085.

**Data prioritization.** "The measures no credible model can replace" does not
survive in any form. S1.2 found no measure tagged essential, and S2.4's held-out
validation, not reliance among fitted members, is the evidence for a reduced
dataset. Where the reliance result is still reported, the form is: "in each of
the 194 members, removing X's direct contribution raised error", stated with
the threshold and labeled exploratory.

**Sign agreement.** "Every credible model agrees on the sign" becomes "all 194
members estimate a positive (or negative) coefficient", which is a count over
fitted models. The PSI-12 sentence becomes "all 167 members of the PSI-12 set
estimate a positive association".

**Neutral.** "Neutral" becomes "no clear direction under the modeled
uncertainty", following the S1.6 statement. "Close to neutral" goes too. If
practical neutrality matters, define the acceptable range first.

**Conservative.** Delete both claims (09 ¶5 on urban results, 09 ¶24 on the ADI
result). In their place, state the mechanism and say its direction is not
established in a multivariable model.

**Imputation.** "Licensed" and "gives unbiased estimates" become "MI was used
under the working assumption that missingness depends only on observed
covariates (missing at random); the audit shows missingness is predicted by
those covariates, which is consistent with but cannot establish that
assumption; the complete-case analysis is the sensitivity check."

**Precedent.** 02's "the approach has no precedent in this field" becomes "the
CASH literature review (nineteen sources) found no application of Rashomon-set
or Monte Carlo methods to safety-event prediction; it was not a systematic
search."

**Reveal.** As listed in the S2.1 note, sec 5.1.

## 4. Verify

- **The guard fails on the Sep 30 text and finds at least the instances the
  review names.** It records 53 hits on the frozen copy, including every
  example the review quotes: "every credible model" (01, 04, 06), "no credible
  model can replace" (01 ¶5, 06 ¶33, 10 ¶6), "neutral" (08 ¶2, ¶16; 10 ¶12,
  ¶14), "conservative" (09 ¶5, ¶24), "licensed" and "gives unbiased estimates"
  (03 ¶41–42, 09 ¶18), "no precedent" (02 ¶5), "reveal" (03 ¶8, appendix ¶4),
  and the bound stated without the state result (01 ¶4, 04 ¶28, 06 ¶2, ¶4). It
  fails stage 39 on `report/`, which is still that text.
- **It passes on the S5 rewrite.** To be shown at S5. The self-test keeps the
  guard honest in the meantime.
- **Generated text.** After rerunning stages 17, 18, 30, 32 and 38, the
  stage-log scan passes with the extended patterns. Stages 30 and 32 reproduce
  `mcr-per-model.csv`, `mcr-bounds-blockB.csv` and all five TIS tables byte for
  byte.

## 5. Notes

- The guard reads `report/*.md` only. The technical supplement S5 creates should
  be added to its file list when it exists.
- `confidence_set` has no Sep 30 instance. It guards the rewrite against
  describing the tolerance the way the review warns against.
