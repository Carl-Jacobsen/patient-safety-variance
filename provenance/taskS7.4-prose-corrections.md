# Task S7.4 — The report, supplement and claims table corrected for the October 7 audit

**Date:** 2026-10-12 · **Budget:** 4 h · **Status: done.** Every interpretive
finding of the October 7 audit (A2–A12) is corrected in the prose, the claims
table and the README. Stage 39 gains the numbers the corrections cite and a
second set of claim guards, frozen against the October 7 prose, that must fire
there and must not fire on the corrected text. The builder now renders bold and
italic markers and can hold a tall figure past the next heading.

---

## 1. What changed, by finding

| Finding | Where | Change |
|---|---|---|
| A2 reliability | 1, 4, 6, 7, 8; A.1, A.3, A.8, C.6; claims F4–F6, P4–P6; README rule 6 | The "sensitivity analyses only" sentence is gone. Sec 4 names the four places λ enters. Sec 6 reports the published-score set (S7.3) beside the main set. Sec 7 and the summary give the fixed-score payment run beside the score draws and explain that the draw is centered on μ + λᵢ(θ̂ᵢ − μ). A.1 calls the volume slope and variance ordering diagnostics, not proofs, and states that the direction of any error in λ is unknown, since the CMS table gives correlations of smoothed rates, one of them negative. |
| A3 ceiling | 1, 5; A.5; claims F1, sec 7 item 10 | The ceiling and "between nothing and one twentieth" are gone, replaced by the audit's wording. Sec 5 and A.5 give the community block alone (3.6%), added last (3.1%) and the fitted term's variance (6.1%, SD 0.25) beside the Shapley 3.3%, to show they answer different questions. |
| A4 support | 1, 6; A.6; claims F8 | The joint contrast is "a model-based scenario, not a comparison between existing places", with the corrected nearest-neighbor result (S7.2). |
| A5 decile contrasts | 6; A.6; claims F10 | Relabeled as fitted predictions averaged over observed profiles, with the model-based SE named and the raw differences (+0.15, −0.22) beside them. |
| A6 all-improve | 1, 7; A.8; claims P3 | Stated with the recalculated reference and fixed revenues; fixed-reference diagnostic (−$56.5M, 2,384 positions) given; "cannot fund improvement" replaced by "does not increase its payout for a common improvement", with attainment targets, fixed benchmarks and improvement credit named as untested alternatives. |
| A7 interval method | 1, 7; Table 1; claims P1 | "Bootstrap" removed from the rate-ratio intervals: a normal approximation on the log scale, groups fixed, hospitals independent, the model ranking's uncertainty not carried. |
| A8 validation | 1, 4, 6; A.7; claims D1, D2 | Conditional on specification 382's prior selection on all hospitals; "meets the chosen 1% mean-loss tolerance", "a practical rule, not a statistical equivalence test"; "held-out states" for "states the model has not seen". |
| A9 frames | 3, 4, 6; A.3; Table 1; claims M1 | "Common evaluation frame"; fitting frames 803 to 2,744; the HSA sibling fitted to 2,605; Table 1's first row names both outcomes. |
| A10 CASH2 attribution | 1, 4, 7; A.8; figure captions; claims sec 4 | "A project-defined rank-based rule that uses CASH2's bonus band and revenue assumptions", neither CASH2's formula nor Q-HIP; the commercial share named as a residual day-share proxy with its three limits in the main text. |
| A11 TIS wording | B.1 | Residual = outside the linear projection; not conditional independence; log scale residualizes exp(v); the flow table an accounting identity, not a validated attribution, and not a basis for collection decisions. |
| A12 details | 5; 6; 7; Table 4; Fig S1; sec 9 and F (new); E rendering; Fig S2 placement; claims, README; sec 8 | Paired bootstrap difference replaces "intervals overlap"; the geography gap "carried by the fitted ICE and English terms", not a mechanism; basis points per full unit and per 0.05 step; Fig S1 conditional on the scalar model; source lists in both documents; glossary bold rendered; Fig S2 held past the next heading; claims and README reconciled; sec 8 says the other-machine build (S6.1) has not been done. |

A1 is S7.1's; A4's code is S7.2's; A2's and A6's computations are S7.3's.

## 2. Stage 39

- **Registry.** A block keyed to the audit registers every number the
  corrections add, in each section that cites it, from the S7.1–S7.3 outputs
  (`variance-decomposition-extra.csv`, `rashomon-tolerance-published.csv`,
  the published rows of `rashomon-published-subset.csv`, the corrected
  `contrast-support.csv`, `all-improve-reference.csv`, the fixed rows of
  `payment-scenarios.csv`). New qualitative claims are asserted: the
  published set's bound above 1 at all three tolerances and its contrast range
  straddling zero; the county endpoint farther than the observed
  nearest-neighbor 95th percentile; the ADI index negative with scores fixed
  and drawn.
- **Exemptions.** Written dates ("October 7") and supplement section F
  cross-references are exempt by pattern, like the existing ones.
- **Claim guards.** Eleven October 7 rules (`variance_ceiling`, `real_places`,
  `fitted_as_observed`, `equivalence`, `cash2_specified`, `relative_zero`,
  `sensitivity_only`, `rr_bootstrap`, `fitted_and_scored`, `components_all`,
  `cov_positive`). The October 7 prose is frozen in `tools/claim-guard/oct7/`
  and every rule must fire on it, or the stage stops; on the corrected
  report, supplement and claims table every rule must be silent. The
  September rules still must fire on `sep30/`.

## 3. Builder

`tools/build_report.py`: `**bold**` and `*italic*` are rendered rather than
printed (the glossary showed literal asterisks); a figure marked
`place = next-section` in `figures.csv` is placed after the first paragraph
following the next heading (Fig S2, the specification curve, which left most
of supplement page 11 blank).

## 4. Time

About 4 h.
