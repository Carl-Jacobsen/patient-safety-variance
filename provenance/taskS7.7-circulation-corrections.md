# Task S7.7 — Corrections from the October 13 circulation audit

**Date:** 2026-10-14 · **Budget:** 2 h · **Status: done.** The October 13 audit
(`../review-2026-10-13/review.md`) cleared the trimmed report for internal
review after five corrections ("Corrections to make before sending"). All five
are made. No number, model or output table changed, and nothing was rerun
except stage 39 and the document build.

## 1. Disposition

| # | Audit correction | Change |
|---|---|---|
| 1 | Geography labels reversed (report p. 11) | Section 6: the county-catchment contrast moves from −0.21 to −0.19 and the tract-catchment contrast from +0.13 to approximately 0.00; gap 0.34 → 0.19, no interval. Matches `geo-construction.csv` |
| 2 | Shapley wording (pp. 6, 8) | Section 4: "averaging each block's incremental contribution over all orders of entry …, so the allocation does not depend on choosing one order". Section 5: "a small share of the total variation" (community is 37.8% of the explained part) |
| 3 | Which residual is 91.2% (p. 1) | Summary: "The 91.2% of published-composite variation left unexplained". The component residual (90.87%) is not cited |
| 4 | References and version label | Every reference in section 9 and supplement F now carries a direct link or DOI; the CASH2 memo is identified as `v6`. Footer reads "Draft for review, <date> revision". The October 12 release is restored (below) |
| 5 | Figure ambiguity | Figure 2 caption names the main (mixed) Rashomon set and says it is not the published-score set; Figure 3 caption says panel A is the base score-draw scenario and points to Table 4 for the fixed-score result; supplement Figure S2 now sits directly under the C.2 heading, not inside C.3 |

## 2. Builder and guard

- `tools/build_report.py`: a code span holding an `http(s)://` address is
  written as a hyperlink. `report_date()` now dates the report and the
  supplement separately and uses today's date when their sources have
  uncommitted edits. S7.6 was built before its commit, so it carried October
  12. A new figure placement, `after-heading`, puts a tall figure under the
  heading of the section that cites it. That is used for S2, because
  placing it in the text left page 13 mostly blank.
- `R/13-report-numbers.R`: the causal-verb scan exempts reference links. The
  IPPS file's address contains "impact". Stage 39 passes, with 0 claim-guard hits on
  `report/`.

## 3. Length

To hold 16 pages, the longer captions and links were offset by wording only, with
no claim or qualification removed. In section 5 the adjustment sentence was
tightened. In section 6 the opening of the parts paragraph, the
coefficient caveat, the suppression conclusion and the validation lead were
shortened. In section 7 the rule preamble and two clauses were cut. Section 9 shortened the
Fisher title, and `verify_models.py` moved to the supplement only. Report 16 pp;
supplement 21 pp.

## 4. Dated copies

The audit asked for the October 12 release to be preserved and the
trim to carry its own label. S7.6 had overwritten `Variance Project - Report
(2026-10-12)` with the trim. It was rebuilt from commit 4507afc in a detached
worktree, using the same figures (unchanged since October 12): 18 pages, as S7.5
recorded. This revision is `Variance Project - Report (2026-10-14)` and `…
Technical Supplement (2026-10-14)`. It is dated October 14, the day it was
made, not the "October 13 revision" the audit suggested. The October 12
supplement copy was never overwritten.

## 5. Not done here

The CMS HACRP infographic link is the address the audit checked. From this
machine every `cms.gov/files/document/…` request returns 404 to curl,
including known-good files, so it was not re-fetched. Still open, as the audit
says: S6.1 other-machine build, the nontechnical reader test, and the
QualityNet question (drafted, unsent).
