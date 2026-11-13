# Task 5.2 — Draft §3, data construction and provenance

**Date:** 2026-09-28 · **Budget:** 5 h · **Status: complete.** Both §3 items were settled 2026-09-28: Carl chose to leave them disclosed.

The draft is `report/03-data.md`, about 2,900 words with three tables, written
in Carl's voice under American spelling. This task also adds one stage:
`make.R` 39, `R/13-report-numbers.R`. It enforces standing rule 1 on the
report text, which no earlier task could do because there was no text yet.

---

## 1. Stage 39: every number in the prose is computed

For each drafted section, the stage computes every number the section cites
from the data products and stage outputs (Tables, `data/*.rds`, and for Phase
0–2 figures the stage logs, read with strict patterns). It writes them to
`output/tables/report-numbers.csv` with section, key, value, the text the prose
may use, and the source.

It then reads `report/<section>.md`, pulls out every numeric token, and
**fails the run if any token is not a registered rendering of a computed
value.** Some tokens are exempt by pattern:

- code spans;
- measure names (PSI-90, SVI 1);
- years, fiscal years and dates;
- cross-references (Table 3.1, Figure 1, section 9).

State of the check:

- **§3: 152 numeric tokens, 0 unregistered. The registry holds 143 values.**
- **Negative test:** changing "2,801" to "2,810" in the draft fails the stage
  and names the line.
- **Limit:** the check proves that each number was produced by make.R. It does
  not prove the number sits next to the right claim. A number that exists
  elsewhere in the registry would pass in the wrong place. 6.2's read has to
  cover that.

Task 6.1 can run this stage on its fresh clone as the "every number in the
report appears in the regenerated outputs" test. Sections 4–10 and the
appendix will each add a registry block as they are drafted.

## 2. Verify

| Condition | Where in §3 |
|---|---|
| What was tried and rejected, and why | §3.3: the three sources not taken, with reasons. §3.4: county-grain weighting rejected as the base case, with the correlations that justify it (Table 3.1) |
| VA exclusion count 107 | §3.1, and Table 3.2 |
| Joint component sample 2,294 vs 2,801 | §3.1: 507 hospitals would be lost; components analyzed at their own coverage |
| Catchment is a discharge-weighted average over ~83% of cases | §3.4: coverage median 0.829, rendered as 83% |
| 87.46% of HSAF cells suppressed | §3.4: 996,700 of 1,139,665 |
| Measured suppression bias, r ≥ 0.986 | §3.4, stated as a measured cost. The test's grain (county, 2,730 hospitals) is stated too |
| Two official PSI-90 values, mean difference 0.00191 | §3.2: r 0.9996 on 2,793 hospitals, and which value is used where |
| Four-way grain comparison | Table 3.1: tract and county catchment against own county and against the suppression-free Service Area |
| Missingness finding on disadvantage | §3.6 and Table 3.3 |

## 3. Two things the draft had to reconcile, for Carl

The draft describes what the models did. Where that differs from an earlier
plan document, the difference is stated here rather than smoothed over.

1. **Multiple imputation was licensed for 8 variables, but it is used for one.**
   The 2.6 audit licensed MI for all 8 variables with substantive missingness,
   and its note says "complete-case for none." The Phase 3 harness does
   something narrower:
   - it imputes contract labor share, with MI, complete-case and omit arms;
   - it analyzes components at their own coverage, never imputed (gate O1.d);
   - it drops hospitals missing operating margin, uncompensated care or HHI.

   The A+B+C composite frame is therefore 2,569 of 2,801. §3.6 says this
   plainly, and says that the dropped hospitals lean small and deprived. This
   is defensible: the gaps are 0.7–1.9% each, and MCR/TIS need one frame. But
   the 2.6 note's "complete-case for none" is not what ran. **Your call:** leave
   it disclosed as it is, or add MI arms for those three. Adding them would
   mean refitting Phase 3.
2. **Block A is not the list in `spec-space.md`.** Task 3.4's axis table named
   ownership, system membership and urban/rural location in Block A. Every
   fitted model from 3.2 onward uses a different 11: beds, ADC, occupancy,
   residents per bed, teaching, CMI, volume, DSH, wage index, operating margin
   and uncompensated care. Ownership and system membership are in the frozen
   file but were never entered. §3.3 states the actual 11 and that the other
   two were assembled and not used. **Your call:** accept this as disclosed, or
   run a robustness arm with ownership and system membership. That arm would
   touch the Block A MCR and the decomposition shares.

**Decision (Carl, 2026-09-28): leave both disclosed as §3 states them. No imputation arms are added and there is no Block A robustness run.** Neither item changes a number already reported. Both change what the report
can say about Block A and missing data, so they belong in 6.2's list if they
are not settled first.

## 4. Other notes

- §3 is written as a report section. It would need only light changes to
  serve as a manuscript's data section.
- **Figure order.** The final figures were renumbered so that §3's figure
  comes first. Reliability-by-volume is now `fig1`, and variance decomposition
  is `fig2`.
- **American spelling.** The report prose uses American spelling, and the
  figure labels were changed to match (labor, neighbors, penalizes, modeled).
  The provenance notes keep their existing spelling.
