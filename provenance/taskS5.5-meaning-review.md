# Task S5.5 — Meaning review and the release build

**Date:** 2026-10-07 · **Budget:** 2 h attended (84 min unattended) · **Status: done.** The meaning review found and fixed 13 issues. The release run (no `--defer-prose`) passed all 47 stages, stage 39 included, and built both documents. The main report is 16 pages, with the title and contents above the summary on page 1, so the body is within the 14-to-16-page target. The supplement is 18 pages.

The meaning review read every sentence of the main report (sections 1 to 8)
and of the supplement against `report/claims.md`, separately from stage 39.
It checked four things the task names: a coefficient read as a patient-level
or protective effect; a bias given a direction without a demonstrated
mechanism; "neutral" without an equivalence range; and the payment
simulation described as validated beyond its scoring rule. It also checked
two the drafting had shown to be risky: an unbounded reliance claim made
without a number (which the `bound_alone` guard cannot see), and attributing
to PSI-90 what belongs to a program that scores it alongside other measures.

**Result: 13 findings. Seven are major, four minor and two cosmetic. All are
fixed.** None of the four named failure types survived drafting in its
literal form. The major findings are their near relatives: claims of
mechanism, scope or attribution that went one step past their evidence.

---

## 1. Findings

Grades: **Major** means the sentence claims more than its evidence and a
reader acting on it could decide differently. **Minor** means the claim holds
but its wording or uncertainty is incomplete. **Cosmetic** means wording only.

| # | Where | Finding | Grade | Fix |
|---|---|---|---|---|
| 1 | 1 ¶5; 7 ¶1; 7 last ¶ | "Payment tied to PSI-90 already falls unevenly", supported by HACRP penalty ratios. HACRP's total score averages PSI-90 with five infection measures, so the ratio belongs to the program, not to PSI-90. This is an attribution without a demonstrated mechanism. | Major | Named as HACRP's, with the scorecard stated; sec 7 adds that the ratios describe the program's penalties, not PSI-90 alone |
| 2 | 7 ¶4 | "Most of the difference comes from the revenue base" was supported by commercial shares only. The per-commercial-dollar comparison that shows it was missing. | Major | Added 1.621% vs 1.680% per commercial dollar (regressivity statement item 5), registered in 07 |
| 3 | 7 last ¶ | "Any fix ... lies in the rule's base and in how it credits improvement, not in the score." Two problems. Improvement credit was never modeled. And the PSI-90-only scorecard scenario moves the ADI index (−0.058 to −0.020), so the scorecard does matter. | Major | Rewritten to rank what the scenarios moved: revenue base most, scorecard too, PSI-90 weight barely; improvement credit untested |
| 4 | 1 ¶6 (decision 3) | "Those choices set where a Q-HIP-style bonus goes" includes improvement credit, which was not simulated. | Major | Revenue base "moved the concentration more than any other assumption the scenarios varied"; improvement credit "this simulation did not model" |
| 5 | 6 ¶1 | Topic sentence "The near-optimal models agree that the community measures carry information" holds only at the primary and metro tolerances. It is the unbounded reliance claim in words, which `bound_alone` cannot catch because no number is in the sentence. | Major | "At the primary tolerance ..." |
| 6 | 8 ¶4; supp. B intro | "Tags no measure as one the models cannot do without at the primary tolerance." That is false at the primary tolerance: the limited-English share's lowest direct reliance (1.0066) clears 1.005 there, and only the metropolitan-area bound, which the tag rule uses, takes it below. | Major | Restated by the rule actually used, with the primary-tolerance exception named |
| 7 | 7 ¶6 | "The shape of the rate curve ... decides whether the hospitals furthest from the best score gain from improving." Every hospital gains under every curve. The convex curve changes how much they gain relative to others. | Major | "sets how much ... gain from improving relative to others" |
| 8 | 1 ¶2; 5 last ¶ | "Community adjustment ... could move hospitals only modestly on average" is true of averages. It omits that PSI-90 is paid on at cut points (HACRP's top quartile), where a small change moves a hospital across. | Minor | Cut-point qualifier added in both places |
| 9 | 2 ¶4 | The Track safety-net shares "sit just outside" the memo's ranges, with no uncertainty, though their intervals reach into the ranges. | Minor | Intervals added (42.2% to 53.5%; 9.1% to 15.3%), registered in 02 |
| 10 | 1 ¶3; 6 ¶5 | "Public data cannot support a hospital-by-hospital adjustment" claims impossibility from fill scenarios. | Minor | "do not support" |
| 11 | 2 ¶1 | "A measure used that way is fair only if ..." states one necessary condition as the definition of fairness. | Minor | "one condition for a measure used that way to be fair is ..." |
| 12 | Fig 3 (fig8) | The panel labeled the model-implied row "regressive", contradicting the on-the-edge wording, and the subtitle ran off the canvas. | Cosmetic (but visible) | `R/12-figures.R`: labels now "below zero", "on the edge" (endpoint within 0.001 of zero), "no clear dir."; subtitle shortened and scoped to the CASH2-style rule |
| 13 | Fig 1 (fig2) | Subtitle said "cluster-bootstrap interval" for both panels; panel A resamples hospitals. | Cosmetic | Subtitle names each panel's resampling |

## 2. What the review checked and found clean

- **Coefficients read as effects.** The two review cautions (limited-English
  share not protective; minority-status theme not a patient-level risk) are
  in sec 6 ¶3. No other coefficient is interpreted.
- **"Neutral".** The word does not appear. "No clear direction" is always
  given with its interval, and "on the edge" with its endpoint and Monte Carlo
  standard error.
- **Validation of the payment simulation.** Sec 7 ¶2 and A.8 say the HACRP
  check covers the scoring the two rules share, not the rate curve or the
  revenue base. "Validated" is not used of the simulation anywhere.
- **Residual.** Read narrowly in sec 1 and sec 5 (conditional; not effort).
- **Supplement.** A, C and D were read against the claims table. Apart from
  finding 6 in B, the only issue was the one fixed in S5.4 (where λ is used).

## 3. Stage 39 after the fixes

Stage 39 passes. The registry-rows table (supplement Table S7) failed once
after the fixes, because sections 02 and 07 gained registry rows. That is the
check working: the table was refreshed from the run.

## 4. The release build

`Rscript make.R --release` (no `--defer-prose`), run detached with
`caffeinate`, log `output/tables/taskS5.5-release.log`. All 47 stages ok,
provenance consistent, 5,029 s. Most of that time was stage 35, the payment
simulation, which reruns its draws to convergence in every release. Stage 38
rebuilt fig2 and fig8 with the S5.5 text; MANIFEST.csv records the new
hashes.

| Document | Pages | Sections |
|---|---|---|
| `Variance Project - Report (2026-10-07).docx` / `.pdf` | 16 (title and contents share page 1 with the summary; the last page has about 100 words) | 1–8 on pp. 1, 3, 4, 6, 7, 9, 12, 15 |
| `Variance Project - Technical Supplement (2026-10-07).docx` / `.pdf` | 18 | A–E on pp. 1, 7, 10, 16, 17 |
| `Variance Project - Number Registry.csv` | — | full registry |

All are in `output/report/`, which git does not track; the build reproduces
them from the commit.

## 5. Left for S6

- **Person test** on sec 4 (Task 5.3, still pending; Carl to arrange).
- Supplement page 11 is mostly white space ahead of Figure S2, a layout
  pass that is not required.
- S6.1's hostile reproducibility check is the test of the supplement's
  reimplementation claim.

## 6. Time

About 2 h attended.
