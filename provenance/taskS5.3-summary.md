# Task S5.3 — Draft the summary last

**Date:** 2026-10-07 · **Budget:** 1.5 h · **Status: done.**
`report/01-summary.md` replaces the September 30 summary. It opens with the
review's three-sentence statement, adjusted to the corrected numbers and to
the fairness framing. Six paragraphs of findings and decision points follow,
and Table 1, a short claim-to-evidence table, closes it. Stage 39 passes on
it: 61 numeric tokens, all registered, no causal verbs, no claim-guard hits.
The stage now fails only on `appendix.md` (S5.4).

---

## 1. The opening

The review's statement is kept with one change: "explain" became "describe",
to match sections 5 and 6. The sentence after it states the question in
fairness terms and the limit that covers every finding (no observation of
effort or response, so no separation of risk-adjustment shortfall from a
difference in care).

## 2. Verify: every headline number names its sample and interval type

| Paragraph | Number | Sample | Interval type |
|---|---|---|---|
| 2 | 3.3%, 4.5% | 2,569 hospitals | bootstrap 95% |
| 2 | 1.44% | separate components model, all 2,801 hospitals | bootstrap over HSAs |
| 2 | 91.2% | same 2,569 | bootstrap |
| 3 | MCR⁻ 1.085 / 1.000 | 194 models fitted to those hospitals | model range at two tolerances |
| 3 | −0.37 to +0.86 | same | "a range across models rather than a sampling interval" |
| 3 | 0.840 | 251 hospitals | fill scenario, no probability |
| 4 | 2.2%, 0.37%, 1.30% | same hospitals, unseen states | range over 20 fold assignments |
| 4 | 4.0% | same | "no interval was computed" |
| 5 | 1.39 | 2,551 HACRP hospitals | bootstrap |
| 5 | $0 | the rule | "by construction and with no modeled uncertainty" |
| 5 | −0.058, −0.038 | 2,569 hospitals, CASH2-style rule | 95% simulation interval |

The components sample was checked in the Task 3.2 log: the stacked
components model nests all 2,801 hospitals in 1,749 HSAs.

## 3. The data-prioritization recommendation

Decision point two rests only on S2.4: the SVI themes with the
limited-English share, not ADI alone, as a module for safety-score analysis,
"not a minimum dataset for a CASH2 business case" (the S3.5 scope wording).
No TIS result appears in the summary.

## 4. Length

937 words with Table 1 (nine rows) included, against 800 budgeted. The prose
is about 745 words; the table is the overrun. With sections 2 to 8 the main
report is 6,362 words. S5.5 checks the page count, and if the report runs
past 16 pages, the summary table's Where column and sections 3 and 4 are
the first cuts.

## 5. Stage 39

The 01 copy block now also copies `n_cc_abc`, the residual interval, `n_set`,
the contrast percentiles, the state bound, the low-decile suppression row,
the repeat count, the HACRP frame, the $0 constant, the 0.40 factor, the
model-implied index and its four-decimal endpoint, and the star-arm frame.
Each is copied from its own section, never recomputed.

## 6. Time

About 1.5 h.
