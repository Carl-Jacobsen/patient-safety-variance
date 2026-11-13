# Task S5.2 — Draft sections 2 to 8

**Date:** 2026-10-07 · **Budget:** 5.5 h · **Status: done.** Sections 2 to 8
are drafted from `report/claims.md` in the eight-section outline S5.1 settled,
5,425 words against the 5,200 budgeted for them. Each is within 10% of its
budget, and stage 39 passes on every one: all numbers registered, no causal
verbs, claim guard clean, published shares beside weighted ones, components
beside the composite, and the nine required Phase 0 numbers present. Stage 39
still fails overall, on `01-summary.md` (S5.3) and `appendix.md` (S5.4), the
two September 30 files left in `report/`.

- **Files.** New: `06-associations.md`, `07-payment.md`, `08-open.md`.
  Rewritten: `02-question.md` to `05-decomposition.md`. Removed (git rm):
  `06-drivers`, `07-archetypes`, `08-payment`, `09-limitations`,
  `10-actions`. The September 30 text stays in tag `draft-2026-09-30` and in
  `tools/claim-guard/sep30/`.
- **Stage 39 follows the files.** Registry sections renamed, TIS and
  archetype keys moved to supplement labels, dead claims retired, new
  blocks for 02, 07 and 08 (sec 2).
- **Figures.** `report/figures.csv` now lists the main report's three; the
  other five go to the supplement (S5.4). Two need fixes before the build
  (sec 5).

---

## 1. Word counts

Counted with `wc -w` on each file, headings and tables included.

| Section | Words | Budget | Difference |
|---|---|---|---|
| 02-question | 548 | 500 | +9.6% |
| 03-data | 765 | 700 | +9.3% |
| 04-methods | 926 | 850 | +8.9% |
| 05-decomposition | 476 | 500 | −4.8% |
| 06-associations | 1,027 | 950 | +8.1% |
| 07-payment | 1,044 | 1,050 | −0.6% |
| 08-open | 639 | 650 | −1.7% |
| Total | 5,425 | 5,200 | +4.3% |

Four sections run near the top of their margin. S5.3's summary has 800 words
budgeted, so the main report lands near 6,200, which should still fit the 14
to 16 pages S5.5 checks; if it does not, sec 3 and sec 4 are the places to cut.

## 2. Stage 39 changes (`R/13-report-numbers.R`)

| Change | Why |
|---|---|
| `06-drivers` → `06-associations`; `reg_gc`, new `reg_cs` (the contrast-support loop as a function), `set_pos`, the metro-area set size, `n_specs_composite`, the 2.5/97.5 percentile labels registered there | Section 6 now carries geography, support and the held-out validation |
| TIS keys from `n_measures` on → label `supp-tis`; five TIS `claim()` calls removed | The TIS prose is retired; S5.4 writes the supplement's account from current outputs. Four of the five claims had already failed since S1.2 |
| `07-archetypes` → `supp-archetypes` | No Track section; T1 values copied into 02 and T2 values into 08 |
| `08-payment` → `07-payment`; Sep 30 claims "neutral against headroom", "neutral against the models' ranking" and "flat share zeroes every index" replaced by three claims the new text makes (distance: no clear direction; model-implied: regressive with upper endpoint above −0.001, i.e. on the edge; ADI under the 0.40 factor: no clear direction) | Every qualitative claim now holds |
| Every scenario's per-revenue-dollar indices, safety-net ratio and total registered from `payment-scenarios.csv` (keys `ps <scenario> <metric>`); scenario verdict counts computed from `regressivity.csv` (13 others, 8 no clear direction) | Table 4 and the scenario sentences |
| `09-limitations` → `08-open`; suppression and ownership keys moved to 06 | Limits stated at point of use |
| Task 5.6's required Phase 0 numbers checked across sections 02–08 together, not in one limitations file | Same reason; all nine present (in sec 3) |
| New `02-question` block: the six CASH2 returns as quoted external values, source `CASH memo/Models/verify_models.py` with its hash (S3.5 note sec 1), plus the Track safety-net shares | S3.5 required it |
| The 01/10 copy block now serves 01 only and reads the new section names | S5.3 rewrites 01 |

`R/17-inclusion-missingness.R` keys renamed to match (`03-data|n_cc_left`,
`supp-archetypes|…`, `07-payment|…`); stage 43 rerun (69 s, ok), and the
inclusion flow's 14 keyed rows reconcile.

Registry: 2,671 numbers across 10 section labels.

## 3. What the sections say that the claims table did not spell out

- **Sec 5** adds that structure's and community's intervals overlap on the
  published score, so the decomposition does not clearly rank one above the
  other. An earlier draft sentence suggesting structure's share partly
  reflects smoothing was cut as unsupported.
- **Sec 6** reports the joint contrast in the best model at all four grains
  (−0.21, +0.13, −0.04, +0.09; SEs 0.18 to 0.20), so none separates from
  zero. That sharpens F7.
- **Sec 7** opens with P1 (observed HACRP), which needs no payment
  assumption, and states the Q-HIP scope before any simulated number. The C1
  check is 3,054 of 3,055 penalty decisions (S5.1's "all 719" was wrong;
  `claims.md` P2 is corrected in this commit).
- **Sec 3** gives the Care Compare/HACRP gap the S2.2 explanation (two
  versions of the CMS software on different reference populations),
  replacing the claims-freeze explanation, hedged "largely" because
  QualityNet question 4 is unanswered.

## 4. Review cautions carried into the text

- Limited-English and minority-status coefficients: both cautions are in
  sec 6, paragraph 3.
- "No precedent" is gone; sec 2 makes no novelty claim.
- "Neutral", "conservative", "credible model", "licensed" and "minimum
  dataset" (except in the sentence that says the module is not one) do not
  appear.
- The ten "none modeled" claims from S5.1 say so in the text: F8 and F11
  (sec 6, "no interval was computed for the gap"), F13 (two refits), D3 ("no
  interval was computed for those shares"), P3 ("carries no modeled
  uncertainty"), T1 and T3 (sec 2, descriptive and quoted), T2 (sec 8,
  subsample shares only), M1 (sec 3, a count), M3 (not cited in 02–08; S5.3
  decides).

## 5. Carried forward

1. **Figure 3 (`fig8-regressivity.png`)** labels the model-implied
   per-revenue-dollar row "regressive". That contradicts the on-the-edge
   wording, and its subtitle runs off the canvas (noted in S3.3). Fix in
   `R/12-figures.R` and rerun stage 38 before S5.5 builds.
2. **Figure 1 (`fig2`)** subtitle says "cluster-bootstrap interval" for both
   panels. Panel A resamples hospitals; only panel B resamples HSAs.
3. **`claims.md` P2** corrected in this commit to 3,054 of 3,055.
4. **Person test** (Task 5.3): a reader outside the field reads sec 4 and
   restates what a Rashomon set is. Still pending, and Carl's to arrange
   before sign-off.
5. **Sec 8** names the QualityNet question as drafted, not sent. If Carl
   sends it before S6.4, the sentence changes.

## 6. Time

About 5 h.
