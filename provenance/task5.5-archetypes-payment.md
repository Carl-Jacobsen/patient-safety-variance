# Task 5.5 — Draft §7 and §8, archetype validation and payment simulation

**Date:** 2026-09-29 · **Budget:** 6 h · **Status: drafted; all three verify
conditions pass.**

- `report/07-archetypes.md`: about 1,200 words, Figure 6, Table 7.1.
- `report/08-payment.md`: about 1,900 words, Figures 7 and 8.

---

## 1. Verify

| Condition | How it is met |
|---|---|
| The archetype result is reported whichever way it fell | §7 opens with the verdict as the pre-registered rule produced it: **gradient, not strata**. Its first paragraph states the positive half, that margin and safety move together and the safety-net mix runs as the memo said. The null half follows: the Track cells hold 38.4% against a 50% bar, and T2 is at 0.99×. Every memo parameter is graded in Table 7.1, including the three that fail. Stage 39 asserts that the verdict row says "GRADIENT, NOT STRATA", so the text cannot outlive a changed result |
| The payer-mix mechanism is presented as arithmetic on the payment formula (plan §4) | §8.1, "The mechanism is arithmetic", derives it from the formula. The incentive is 0.585% of eligible revenue for every hospital, so per revenue dollar it is proportional to commercial share and nothing else. The CASH2 flat-share scenario confirms this, since its index is 0 along every ranking by construction. Stage 39 asserts that zero |
| "Structurally regressive" appears only as a claim about the arithmetic of the formula, and says so wherever it appears | **Now a mechanical check in stage 39.** Every sentence in `report/*.md` that contains the phrase must also contain "arithmetic", or the stage fails. The check found one real violation, in §4: the defining sentence carried its qualifier in the next sentence. It was fixed by moving the qualifier into the same sentence. The phrase is now in 1 sentence of §4 and 7 of §8, all qualified |

Stage 39 status: **§7: 63 tokens, 0 unregistered. §8: 85 tokens, 0
unregistered.** The registry holds 600+ values across six sections.

## 2. A number that `make.R` did not produce, and now does

The 4.3 note's split of the ADI quintile 5 / 1 dollar gap (75% size, 17%
commercial share, 8% position) was computed by hand for the note. No stage
wrote it, so under standing rule 1 §8 could not cite it.

**`R/10-payment-strata.R` (stage 36) now writes
`output/tables/payment-gap-decomposition.csv`.** The split is exact: the log
ratio of mean bonus equals the log of mean NPR plus the log of eligible
revenue over NPR plus the log of bonus over eligible revenue, each a ratio of
stratum means. It reproduces the note: size 75.0%, commercial share 16.9%,
position 8.1%. The table is new output only. The stage's existing tables and
figure are byte-identical (md5).

## 3. Corrected while drafting

- **§8.4 first said the scenarios other than the threshold "leave the
  verdicts unchanged."** Checked against `regressivity.csv`'s verdict column,
  that was wrong:
  - `cash2_sn` flips ADI to +0.013, with zero width;
  - `cash2_sn` flips the models' ranking to +0.027;
  - `cash2_sn` flips headroom to −0.009;
  - `fixed` flips headroom to −0.004, with zero width;
  - `cash2_flat` zeroes every index.

  The paragraph now names every scenario that changes a verdict. The generated
  `regressivity-statement.txt` (stage 37) omits the `cash2_sn` ADI flip. It is
  left as it is and recorded here.
- The §8.5 sentence claimed that HACRP penalties follow from scores "only
  weakly predictable" from covariates. That was cut: HACRP's score is mostly
  the HAI measures, and the report's decomposition is on PSI-90.
- §8 used "the plan" twice, which is internal provenance and not report
  language. Both were rephrased.
- The 139 unrated hospitals in §8 are the payment sample's unrated. §7's 208
  are the whole frame's. The text now says which is which.

## 4. What §7–§8 hand forward

- **To §1 (5.7):**
  - **Headroom.** Per revenue dollar, the incentive is neutral along headroom
    (−0.005 [−0.013, +0.004]). With the bottom-quarter threshold that CASH2's
    mechanics imply, it runs away from headroom (−0.076). That answers the
    plan §10 question.
  - **ADI.** The incentive is structurally regressive along ADI, as
    arithmetic and by a small margin: 13.92 against 15.92 basis points, with
    zero width, and entirely from commercial share.
  - **Per hospital.** Dollars fall fourfold across ADI, 75% of it size.
  - **Tracks.** Gradient, not strata.
- **To §9 (5.6):**
  - the C2 slope miss in the lowest-λ quartile (1.28);
  - the zero-width ADI interval;
  - the what-if status: Q-HIP payments are not public;
  - the star rating as the Leapfrog fallback;
  - the 208 unrated hospitals outside the archetype test.
- **To §10 (5.7):**
  - commercial-share weighting is the lever that decides the ADI verdict;
  - the bottom-quarter threshold is the design choice that turns the headroom
    verdict.
- **To 6.3 (Foundation lead):** §7 carries the archetype verdict, and §8.4 carries the
  regressivity result. Both should reach him before the Work Group sees them.
