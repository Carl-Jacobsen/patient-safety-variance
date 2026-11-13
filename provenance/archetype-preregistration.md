# Track archetype validation — pre-registration

**Date:** 2026-09-23 · **Task:** 3.16 · **Status: fixed before any cross-tabulation
of safety against margin was computed.**

Task 3.16's verify condition is that a null result is written up as a null
result. That is easiest to honour if what counts as a null is written down first,
so this file goes in alone, before the analysis, as `cluster-preregistration.md`
did at Task 3.15.

What had been seen when this was written: Task 3.15's full results (one cloud on
margin × PSI-90, r = −0.17; the 23 screened public safety-net hospitals), and the
**marginal** distributions of the inputs below. Star rating is published for
2,593 of the 2,801 hospitals (1★ 160, 2★ 561, 3★ 826, 4★ 765, 5★ 281, 208 not
available), and `dsh_pct` quartiles are 0.204 / 0.283 / 0.366. No star rating
had been tabulated against margin, DSH, beds or PSI-90.

---

## 1. What the Tracks claim

The CASH2 Tracks (`CASH memo/Models/vbp_model.R`, `Drafts/Planning/Memo -
Plan.md` Task 1.2, deck slide 14) are internally constructed. The memo says so
itself. Five claims in them can be checked against data:

| # | Claim | Memo source |
|---|---|---|
| C1 | Margin and safety move together: thin margin with poor safety, comfortable margin with good | Track definitions |
| C2 | Hospitals fall into three bands on those two axes, and Track 2 is the plurality | Memo Plan Task 1.2 ("the plurality of hospitals will most resemble this archetype") |
| C3 | Safety-net share is 50–70% in Track 1, 15–30% in Track 2, 5–10% in Track 3 | `safety_net_proportion_lo/hi` |
| C4 | Size rises with Track: about 175, 300 and 500 beds | `hospital_beds` |
| C5 | Track 1's safety metrics are in the bottom quartile | Memo Plan Task 1.2, Track 1 paragraph |

C1 and C2 are the question the task asks. C3 to C5 are the parameters the memo's
ROI model is built on, and each gets its own pass/fail row.

## 2. Inputs

- **Safety maturity (primary): the CMS Hospital overall star rating.** Leapfrog
  grades are sold, not published, and were not acquired. **This is the fallback
  the task sheet names, and every output says so.** It is read from
  `Hospital_General_Information.csv` (source `cc_hospinfo`, already
  hash-registered at Phase 1). It is **not** added to `analytic-v1.rds`: it is a
  validation target for this task, not a covariate, and the frozen file is not
  amended. Bands, by the memo's own grade language: **1–2★ ↔ Leapfrog D/F,
  3★ ↔ C, 4–5★ ↔ A/B.** The mapping is an inference, not a published crosswalk,
  and is stated as one.
- **Safety maturity (secondary): published PSI-90**, in rank terciles (lowest
  PSI-90 = best). This connects the result to Task 3.15 and uses the measure the
  project is about. It is reported after the star rating and is not the verdict.
- **Margin:** `operating_margin`, in **rank terciles** over the analysis frame.
  Ranks rather than cut-points because the memo's language is relative ("thin",
  "median", "comfortable"), and because ranking makes the −497% tail harmless
  without screening it.
- **Safety-net:** `dsh_pct` in the **top quartile** of the analysis frame, the
  common operational definition. Median `dsh_pct` per cell is reported beside it
  so the conclusion doesn't rest on the cut.
- **Beds:** `beds`, Block A.

## 3. Frame, and the 23 hospitals

**Analysis frame:** every hospital with a published star rating and a non-missing
margin. **The 23 hospitals with margin below −1, which Task 3.15 screened, stay
in.** Ranking places them in the bottom margin tercile, which is where Track 1
puts them, and a Track 1 test that drops them tests a different population. **One
sensitivity: the same analysis without them.** Their star, DSH and PSI-90
profile is reported by name.

Hospitals without a star rating are out of the frame. Their margin tercile,
DSH quartile and beds are compared with rated hospitals, so any selection is
visible.

## 4. Tests

**Track cells.** T1 = 1–2★ × bottom margin tercile; T2 = 3★ × middle tercile;
T3 = 4–5★ × top tercile. The other six cells of the 3 × 3 table are
**off-Track**.

- **C1, the gradient.** Goodman–Kruskal γ between star band and margin tercile,
  with a 95% percentile CI from 2,000 hospital bootstrap resamples. Spearman ρ
  between the 1–5 rating and continuous margin is reported beside it.
- **C2, concentration.** The share of hospitals in the three Track cells,
  against the share expected if star band and margin tercile were independent
  (the product of the margins), with a bootstrap CI on both the share and the
  observed/expected ratio. Plurality: whether T2 is the largest Track cell and
  whether it is the largest cell in the table.
- **C3–C5.** Per Track cell: safety-net share with a Wilson 95% CI, against the
  memo's range; median beds, checking whether the ordering T1 < T2 < T3 holds;
  and the share of T1 in the worst PSI-90 quartile, where "bottom quartile" in
  the claim is read as a majority of T1 hospitals being there.
- **Task 3.15 comparison.** The forced three-component assignments are
  cross-tabulated against Track cells with an adjusted Rand index. They are used
  only as a comparison, never as evidence that three groups exist (3.15 prereg §5).

Seed 20260923.

## 5. The verdict rule, fixed now

On the star-rating primary, full frame:

| Verdict | Condition |
|---|---|
| **Not supported** | γ's 95% CI includes zero or lies below it. Margin and safety do not move together |
| **Gradient, not strata** | γ's CI lies above zero, **but the three Track cells together hold under 50% of hospitals**. Most hospitals sit off-Track |
| **Supported as strata** | γ's CI lies above zero **and** the Track cells hold at least 50% |

The 50% bar is the plain meaning of "exists as strata": if the three archetypes
are a fair stylization, most hospitals should sit in one of them. Independence
puts about a third there. Perfect alignment of these marginals would put about
93% there.

C3–C5 each get pass / fail / partial against the memo's own numbers and do not
change the verdict. They answer a different question: whether the ROI model's
per-Track parameters describe the hospitals that land in each Track.

The verdict is reported as it falls, whichever row it is. PSI-90 and the
without-23 sensitivity are reported next to it and do not replace it. The
verdict goes to the Foundation lead through Task 6.3 before the Work Group sees it.

## 6. What would count as violating this

Changing the star-band mapping, the tercile construction, the safety-net cut, the
50% bar, or the frame after the cross-tabulation has been seen, or promoting the
PSI-90 arm or the sensitivity to the verdict because it reads better.
