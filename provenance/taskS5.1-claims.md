# Task S5.1 — Claim-to-evidence table and settled outline

**Date:** 2026-10-07 · **Budget:** 2 h · **Status: done.** `report/claims.md`
lists 30 claims in six groups, each with target, sample, method, uncertainty
type and decision relevance, plus nine claims the report does not make and
the settled outline. No code or number changed.

- **The question.** Carl settled it on 2026-10-07: the deliverable is first a
  fairness assessment of PSI-90 as a performance measure. Payment exposure
  stays as a secondary question; the ROI question goes to the S3.5
  next-exercise page. The Foundation lead's written confirmation, if wanted, moves to
  S6.2.
- **Outline.** The Track cells lose their own section (Carl, 2026-10-07). The
  report runs to eight sections, not nine; sec 7 is payment and sec 8 what
  remains open.
- **Payment framing.** Every simulated payment claim is stated as a
  Q-HIP-style rule *as CASH2 specified it*. The Q-HIP formula is not public,
  and C1/C2 validate the scoring shared with HACRP, not the payment rule.

---

## 1. What was read

Every number in `claims.md` was read from the release-state output tables
(S4.1, commit 232b52f), not from the September 30 prose or from earlier
notes: `variance-decomposition.csv`, `mcr-bounds-blockB.csv`,
`rashomon-published-subset.csv`, `contrast-support.csv`,
`geo-construction.csv`, `suppression-sensitivity.csv`, `geo-validation.csv`,
`payment-scenarios.csv` (primary set, all 14 scenarios),
`regressivity-statement.txt`, `observed-hacrp-regressivity.csv`,
`hacrp-calibration.csv`, `inclusion-flow.csv`, and the S2.1–S3.5 notes for
the remaining values.

## 2. The claim groups

| Group | Report sec | Claims | Role |
|---|---|---|---|
| How much of the score public characteristics describe | 5 | F1–F4 | Primary (fairness) |
| Community associations across models and geography | 6 | F5–F13 | Primary (fairness) |
| Which community data to keep | 6 | D1–D3 | Secondary (data) |
| Payment consequences | 7 | P1–P8 | Secondary (payment) |
| Connection to CASH2 | 2, 8 | T1–T3 | Scope |
| Data and missingness | 3 | M1–M3 | Scope |

P1, the observed FY 2026 HACRP penalty ratio by ADI fifth (1.39, 1.14 to
1.71), was in the regressivity statement but not in the September 30
summary. Under the fairness framing it is the most direct evidence the report
has: it concerns a program in force, needs no payment assumption, and is
associational. It leads sec 7.

## 3. Two corrections to what I told Carl in chat

1. **ADI under CASH2's revenue rules.** The ADI per-revenue-dollar index
   holds under every curve, weight and revenue multiplier, weakens under
   CASH2's flat share (−0.017 [−0.029, −0.005]) and the PSI-90-only
   scorecard (−0.020), and has no clear direction only under the 0.40
   safety-net factor (−0.008 [−0.021, +0.004]). The safety-net ratio stays
   below 1 in every scenario (0.35 to 0.87). P4 and P5 say this.
2. **The held-out validation.** I said ADI did better in unseen states and
   the SVI set within known areas. That was a misreading of the relative-loss
   column. The SVI themes plus the limited-English share do better in both
   designs: 89% of the full block's gain kept in unseen states against ADI's
   38%, and 83% against 44% within known areas. D2 has the correct reading.

## 4. Claims with no modeled uncertainty

The verify condition requires the prose to say so for each. S5.2 must write
it at the point of use for: F8 (support share), F11 (the tract-county gap),
F13 (ownership refits), D3 (held-out R²), P3 (all-improve pays $0, zero by
construction), T1 (memo parameters), T2 (the 61.6% off-diagonal share; the
subsample shares are the only uncertainty), T3 (memo arithmetic), M1
(inclusion flow), M3 (reproduction).

## 5. Checks run on `claims.md`

- **Claim guard and causal verbs.** Stage 39 scans every `report/*.md`, so
  `claims.md` is in scope. The guard rules and the causal-verb pattern, read
  from `R/13-report-numbers.R` and run on the file alone: no hits. The first
  draft needed four changes to get there: F5 and F6 now name the state bound
  in the same sentence (`bound_alone`); the "not made" list describes the
  banned words instead of quoting them (`neutral` and `conservative` in item
  3, `no_precedent` in item 7); and F8 says "supports", not "licenses".
- **Numbers.** Stage 39's registry check runs only on files named for a
  registry section, so `claims.md` is not number-checked. Its numbers are
  checked twice in practice: here against the tables, and again when S5.2
  registers each one in its section's block.

## 6. Carried to S5.2

1. **Section files and registry keys.** The outline renumbers the report:
   `07-payment`, `08-open`, and no archetype or actions section. Stage 39's
   registry blocks are keyed to the September 30 file names (`07-archetypes`,
   `08-payment`, `09-limitations`, `10-actions`), and line 833 reads
   `09-limitations.md` by name. S5.2 renames the files and moves the blocks
   together, or the number check passes vacuously on sections it skips.
2. **Section 2 registry block.** It must register the six CASH2 values as
   quoted external values (S3.5 note sec 2), plus the memo's safety-net share
   ranges for T1.
3. **Regressivity statement item 2** still prints "structurally regressive"
   for the primary ranking. The report uses the on-the-edge wording (P6,
   Carl 2026-10-07); the generated statement is the rule's output and stays
   as it is, quoted in the supplement only.
4. **Figure choice for sec 6.** MCR bounds or the specification curve; the
   draft's Fig 4 carries the TIS-era subtitle and must be regenerated either
   way.
5. **Interpretive cautions** are in F9 and must stay in sec 6's prose.
6. **Person test** from Task 5.3 is still pending on sec 4.

## 7. Time

About 2 h, within budget.
