# Task S5.4 — Assemble the technical supplement

**Date:** 2026-10-07 · **Budget:** 2 h · **Status: done.** The supplement is
five sections in `report/supplement/` (5,994 words) and builds to its own
document, `output/report/Variance Project - Technical Supplement.docx` and
`.pdf` (18 pages, Meridian palette). The full number registry ships beside it
as `Variance Project - Number Registry.csv`. With the supplement in place and
the September appendix gone from `report/`, **stage 39 passes end to end for
the first time in the second pass.** Every section file of both documents is
number-checked, the causal-verb scan finds nothing, and the claim guard has
0 hits on `report/` and `report/supplement/`.

---

## 1. Contents

| File | Content | Source |
|---|---|---|
| `A-methods.md` | A.1 reliability under the scalar approximation (rewritten; S2.2 caveat), A.2 specification space, A.3 Rashomon set and published-score subset, A.4 MR and MCR, A.5 variance decomposition, A.6 contrast parts and geographic rebuild (new), A.7 held-out validation (new), A.8 payment simulation (rewritten) | Sep 30 appendix A.1–A.4 and A.6, corrected; S1.3–S1.6, S2.4–S2.6 notes |
| `B-importance.md` | TIS method with the full-minus-one fixed part, invariants, synthetic checks and the fitted-proxy property, lineage, Table S2 and exploratory tags | Sep 30 A.5 corrected; S1.1, S1.2 notes; `tis-decomposition.csv`, `driver-tags.csv` |
| `C-sensitivity.md` | Reliability by volume (Fig S1), specification curve (Fig S2), suppression (Table S3), missing-data shift (Table S4), ownership (Table S5), uncertainty trace, the nine Track cells (Table S6, Fig S4), payment by stratum (Fig S5) | stage 44, 43, 45, 37, 46 outputs |
| `D-registry.md` | How the registry and the guards work; rows by section (Table S7) | stage 39 |
| `E-glossary.md` | The glossary from S3.3 (moved; its comment block removed) | `report/glossary.md` |

`report/glossary.md` moved with `git mv` and keeps its history. `report/appendix.md`
was rewritten heavily enough that git records it as deleted and `A-methods.md`
as new; the September text is in tag `draft-2026-09-30`.

## 2. Corrections made in moving the appendix

- **A.1** no longer says the intervals "reveal" the smoothing (claim-guard
  rule `reveal_shrink`). It adds the S2.2 finding: CMS's composite variance
  is w′Var(v)w with positive signal covariances, so the scalar τ² is too
  small and λ is biased low. It also states where λ is used, which includes
  the payment simulation's published-score draws. The first draft of that
  sentence said "sensitivity results only"; that was wrong and was corrected
  before commit.
- **A.5 (old)**, the TIS section, moved to B and was rewritten around the
  repaired fixed part. The old "41.3% of Δ negative" is now 6.4%. The new
  41.3% is the shared share of total excess reliance, and B.3 says what it
  is.
- **A.6 (old)** payment quantities: `Marg` is replaced by the finite return,
  with the average-rank counterfactual position formula, the rate curve with
  k, the threshold and rescaled variants, the draw structure, the
  concentration index, the verdict rule and the revenue scenarios. The
  revenue exposure coefficient is named as supplementary.
- **A.3** adds the published-score subset and P-best 382 as the anchor.

## 3. Verify: could a trained reader reimplement the two calculations?

- **Direct reliance (B.1 with A.4).** The supplement gives the
  contribution-space regression, the exact ordered-pair formula with its
  B + CV form, the fixed part on both scales (full model minus measure j),
  the treatment of v̂ⱼ, and pooling across completions. That is everything
  `decompose_model()` and `fixed_part()` use, and the invariants say what a
  correct implementation must reproduce.
- **Finite return (A.8).** The supplement gives the score with winsorization
  and standardization, the HAI term and the rule for hospitals without it,
  positions with average ranks, the rate curves, the counterfactual position
  formula, the return and its per-revenue-dollar form, and the commercial
  share's S-3 formula with its fallback. It also gives the draw structure and
  the concentration index with its orientation. Those are the inputs
  `fin_return()`, `pos_cf()`, `rate_of()` and `cindex()` use. The one thing
  the supplement does not restate is the HACRP W-Z construction of the
  infection scores, which is CMS's published method and is used as given.

I checked this by reading A.8 against `R/09-payment-sim.R` lines 345–410 and
B.1 against S1.1's note. No outside reader has tried it; S6.1's hostile
reproducibility check is the real test.

## 4. Stage 39 and the build

- **Supplement files are checked.** `check_section()` falls back to
  `report/supplement/<sec>.md`. Every drafted section file is checked whether
  or not it has a registry block, so a section with no block fails on its
  first number instead of passing unread. The causal-verb scan, the
  published/weighted pairing and the claim guard cover both directories.
  New exemptions: `Figure S<n>`, `Table S<n>` and `A.4`-style
  cross-references.
- **Registry blocks:** `A-methods` (log reads from the stage 1b, 4, 17, 26 and
  28 logs; `rashomon-tolerance.csv`; copies; and named definition constants,
  each with its source); `B-importance` (formerly `supp-tis`, plus invariant
  worst cases as mantissa and exponent, synthetic-check values and
  marginal/direct medians); `C-sensitivity` (copies by key pattern via the new
  `copy_pat()`, plus the diagonal total and the largest shift change);
  `D-registry` (row counts per main section, computed in the run, so the
  table fails if the registry changes and the prose does not).
- **Build:** `tools/build_report.py --supplement` reads `report/supplement/`,
  numbers figures S1, S2 and so on from `report/supplement/figures.csv`, and
  writes the supplement and the registry CSV. `make.R --release` now builds
  both documents after stage 39.

## 5. Carried to S5.5

1. The figure fixes from S5.2 (fig8's "regressive" label and subtitle; fig2's
   "cluster-bootstrap" subtitle).
2. Layout. Page 11 is mostly blank because Figure S2 does not fit below
   C.2's paragraph. That is a layout pass, not content.
3. The meaning review covers the supplement too, against `claims.md` where a
   claim appears in both documents.

## 6. Time

About 2.5 h, half an hour over budget, most of it spent on the registry
blocks for A and C.
