# Task S7.5 — Release rerun, the October 12 documents, and the disposition of the October 7 audit

**Date:** 2026-10-12 · **Budget:** 1 h attended (75 min unattended) ·
**Status: done.** `Rscript make.R --release` (warm) ran every stage from the
committed code, stage 39 included, and built both documents. Every finding of
the October 7 audit is closed by a task below. None is accepted without a
change.

---

## 1. Disposition of the October 7 audit

The audit (`review-2026-10-07/review.md`, `claim-audit.csv`) is kept apart
from the October 1 review, as it asked: its new defects (A1, A4) are recorded
here and in S7.1–S7.2, not as regressions of first-draft repairs, and its
retired meanings have their own claim guards, frozen against the October 7
prose (S7.4).

| ID | Priority | Finding | Closed by | Resolution |
|---|---|---|---|---|
| A1 | P0 | Component shares compare different samples | S7.1 | Every subset on the same 9,782 rows / 2,569 hospitals, checked per subset and replicate; bootstrap rerun: community 1.62% (−0.81% to 4.19%); 1.44% withdrawn |
| A2 | P1 | Reliability not confined to sensitivity analyses | S7.3, S7.4 | Published-score Rashomon set calibrated on its own (105 models; MCR⁻ 1.079 / 1.063 / 1.048); fixed-score payment run beside the score draws everywhere; the draw's centering explained; A.1 diagnostics and bias direction made conditional |
| A3 | P1 | 3.3% treated as an adjustment ceiling | S7.1, S7.4 | Ceiling and "nothing to one twentieth" removed; alone / added-last / fitted-term quantities shown beside the Shapley share |
| A4 | P1 | Support overstated; NN distances wrong | S7.2, S7.4 | Whitening corrected and tested; county endpoint 2.07 vs p95 1.88 (3.1% as isolated); contrast read as a model-based scenario |
| A5 | P1 | Fitted contrasts called observed differences | S7.2, S7.4 | Relabeled; raw differences (+0.15, −0.22) beside the fitted (+0.23, −0.44) |
| A6 | P1 | Zero all-improve change generalized | S7.3, S7.4 | Tied to the recalculated reference and fixed revenues; fixed-reference diagnostic −$56.5M, 2,384 positions |
| A7 | P2 | Rate-ratio intervals called bootstrap | S7.4 | Named as log-scale normal approximations, with their assumptions |
| A8 | P2 | Validation ignores full-data selection | S7.4 | Stated as conditional, post-selection; "meets the chosen 1% mean-loss tolerance", not equivalence |
| A9 | P2 | Fitting and evaluation frames conflated | S7.4 | "Common evaluation frame"; fitting frames 803–2,744; HSA anchor 2,605 disclosed |
| A10 | P2 | CASH2 attribution; revenue proxy | S7.4 | "Project-defined rank-based rule using CASH2's bonus band and revenue assumptions"; day-share proxy and its limits in the main text |
| A11 | P2 | TIS wording | S7.4 | Linear-projection residual, not conditional independence; log-scale exp(v) disclosed; flow not a validated attribution |
| A12 | P2 | Inference, handoff, layout details | S7.1, S7.4, this task | Paired differences; ICE/English "carried by fitted terms"; basis points per unit and per step; Fig S1 conditional; source lists; glossary bold; Fig S2 placement; claims and README reconciled; other-machine build stated as not done |

**Claim-audit CSV.** Every row marked for change is reflected in
`report/claims.md`: F1, F3, F4, F5–F8, F10, F11, D1–D3, P1, P3–P8, M1, M3.
Rows the audit retained (F2, F9, F12, F13, P2, T1–T3, M2) are unchanged apart
from frame wording.

## 2. What is still open

- **S6.1, the hostile reproducibility check on another machine.** Not done;
  the report (sec 8) and claim M3 now say so.
- **Person test of sec 4** (Task 5.3), still Carl's to arrange.
- **The QualityNet question** (S2.2) is drafted, not sent.
- The audit suggested, as an alternative to A2's calibration, a fully
  unweighted primary analysis. The published-score set is reported beside
  the main set rather than replacing it, because the main set's procedure was
  pre-registered; the report states where each result depends on the
  approximation.

## 3. The release run

`Rscript make.R --release`, run detached with `caffeinate`, log
`output/tables/taskS7.5-release.log`. All 47 stages ok, provenance consistent,
4,527 s (stage 35's draws dominate). Stage 39: every number registered; the
September guards fire on `sep30/` (57 hits), the October 7 guards on `oct7/`
(24 hits, every rule at least once), and no guard fires on the corrected
report, supplement or claims table. Stage 38 rebuilt fig2 and fig8 with the
S7.4 text; MANIFEST.csv records the new hashes.

| Document | Pages | Sections |
|---|---|---|
| `Variance Project - Report (2026-10-12).docx` / `.pdf` | 18 (was 16) | 1–9 on pp. 1, 3, 4, 6, 8, 10, 13, 17, 18 |
| `Variance Project - Technical Supplement (2026-10-12).docx` / `.pdf` | 21 (was 18) | A–F on pp. 1, 9, 12, 17, 19, 20 |
| `Variance Project - Number Registry.csv` | — | full registry |

The October 7 documents are kept beside them in `output/report/`. The main
report is two pages over the 14–16 target: the corrections add qualifications
the audit required (sections 4, 6 and 7 grew most) and a source list; nothing
was cut to make room, which would be a reader's call.

## 4. Time

About 1 h attended.
