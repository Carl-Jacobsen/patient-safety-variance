# Task S0.1 — Preserve the September 30 state

**Date:** 2026-10-01 · **Budget:** 0.5 h · **Status: done; the verify condition passes.**

Second-pass plan: `../Variance Project - Tasks (second pass).md`. It answers the
critical review of 2026-10-01, which this task records but does not act on.

---

## 1. The tag

The draft the review assessed was uncommitted (the voice pass on sections 1 and
3–10, and new `02-question.md` and `appendix.md`). It is now committed unchanged
and tagged **`draft-2026-09-30`**. `git status` was clean at the tag apart from
the archive folder this task then created.

## 2. The archive

`archive/draft-2026-09-30/` holds copies of `output/tables/` (117 files),
`output/figures/final/` (the eight report figures and their manifest) and all of
`data/` (94 MB, including the TIS, MCR and payment caches the second pass will
replace). The copies are gitignored like every other built product; the hash
manifest, `archive/draft-2026-09-30/MANIFEST.csv` (153 files, path, bytes,
sha256), is tracked.

Verify: all 51 tables and caches that stages 38 and 39 read are in the
manifest, and so are figures 1 to 8. No corrected output may overwrite this
folder (second-pass standing rule 1).

## 3. The documents the second pass answers

| File (relative to the project folder) | sha256 |
|---|---|
| `review-2026-10-01/review.md` | `65fa4ce1dcf542bce18bbcf2810d497e3fa61ab6da35fe0ad5b84c5a76cd2749` |
| `review-2026-10-01/Patient Safety Variance Project - Critical review and recommendations.docx` | `35f96f32cbf507aa94a049f446be12f687e74c8130358797ce7cc0f9c40c38c7` |
| `report-draft/Variance Project - Report draft (2026-09-30).pdf` | `944023a888305a6923a449995d05affee89c4e896ebcbe0daeba3fdefc0f7944` |

## 4. The contract end date

The engagement record (not published) said the contract ran **through October 12**.
Rev 3 corrected the task sheet to October 15 on 2026-08-26 but not this record.
The line now reads October 15, with the correction dated.
