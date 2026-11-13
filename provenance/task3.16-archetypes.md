# Task 3.16 — Validate the Track archetypes

**Date:** 2026-09-23 · **Budget:** 5 h · **Status: complete.**

One stage (`make.R` 34, `R/08-archetypes.R`, 6 s). It reads `analytic-v1.rds`,
Task 3.15's `data/clusters.rds`, and the star rating from the hash-registered
`cc_hospinfo` source. The frozen file is not amended. The verdict rule, the
star-band mapping, the tercile construction, the safety-net cut and the frame
were fixed in `provenance/archetype-preregistration.md`, committed alone as
`cdc8669` before any cross-tabulation was computed.

**Leapfrog grades were not acquired. The safety axis is the CMS Hospital overall
star rating**, the task sheet's fallback, banded 1–2★ / 3★ / 4–5★ and read as
Leapfrog D/F / C / A–B. That mapping is an inference, not a published crosswalk.

---

## 1. The verdict

**Gradient, not strata.** This is the pre-registered rule's middle outcome,
applied mechanically:

- **γ = +0.206 [+0.155, +0.253].** Star rating and margin move together in the
  direction the Tracks assume, clearly above zero.
- **The three Track cells hold 38.4% [36.5%, 40.2%] of hospitals**, against 33.3%
  if the two axes were independent and a pre-registered bar of 50%. The upper end
  of the CI is ten points short of the bar.

The same verdict holds without the 23 margin < −1 hospitals (γ +0.203, 38.5%)
and with PSI-90 terciles as the safety axis (γ +0.195, 37.0%). Neither replaces
the verdict. They agree with it.

**In plain language, for Task 6.3:** better-resourced hospitals do tend to be
safer, and the safety-net mix runs across the Tracks almost exactly as the memo
said. But hospitals don't sort into three types. About six in ten sit outside
the Track the memo would assign them. Knowing a hospital's margin moves the odds
of its star band by about a fifth to a quarter either way. The Tracks are a
reasonable shorthand for a continuous gradient and a poor description of
distinct groups. This is a null on the archetypes as strata. Per the task sheet,
it goes to the Foundation lead before the Work Group sees it.

Task 3.15 reached the same answer by a different route: no separated clusters on
margin × PSI-90. Its forced three-cluster solutions have no relation to the
Track cells (adjusted Rand index −0.003 published, 0.021 corrected).

## 2. The table

Rows are star band, worst to best. Columns are margin tercile, thin to
comfortable. Each cell shows count and observed ÷ expected; Track cells are in
bold. n = 2,581.

| | thin | middle | comfortable |
|---|---|---|---|
| **1–2★ (D/F)** | **297 · 1.24×** | 235 · 0.98× | 186 · 0.78× |
| **3★ (C)** | 295 · 1.08× | **272 · 0.99×** | 254 · 0.93× |
| **4–5★ (A/B)** | 268 · 0.77× | 353 · 1.02× | **421 · 1.21×** |

The gradient lives in the corners: T1 and T3 are each over-represented by about
a fifth, and the anti-Track corners are under-represented by about as much.
**The middle does not exist as a stratum.** T2 is at 0.99×, exactly what
independence predicts. A 3★ hospital is spread nearly evenly across margin
terciles (295 / 272 / 254). Track 2 was meant to be the plurality ("the
plurality of hospitals will most resemble this archetype"). **It is the smallest
Track cell, and the largest cell overall is T3 (421).** That largely reflects
star ratings skewing high: 40% of rated hospitals have 4–5★.

## 3. The memo's per-Track parameters

These do not move the verdict. They ask whether the ROI model's per-Track inputs
describe the hospitals that land in each Track. Grading: pass = point estimate
in the memo's range, partial = Wilson 95% CI overlaps it, fail = no overlap.
Safety-net = `dsh_pct` ≥ 0.370, the top quartile of the frame.

| Claim | Memo | Observed | Result |
|---|---|---|---|
| C3 safety-net share, T1 | 50–70% | 47.8% [42.2, 53.5] | partial |
| C3 safety-net share, T2 | 15–30% | 24.3% [19.6, 29.7] | **pass** |
| C3 safety-net share, T3 | 5–10% | 11.9% [9.1, 15.3] | partial |
| C4 beds rise with Track | 175 / 300 / 500 | median 151 / 190 / 144 | **fail** |
| C5 T1 safety in bottom quartile | majority | 42.1% [36.6, 47.8] in worst PSI-90 quartile | fail |
| C2 T2 is the plurality | largest group | smallest Track cell | **fail** |

**The safety-net gradient is the memo's best-supported claim.** Shares run
48% → 24% → 12% down the Tracks, and each is at or within a few points of the
memo's range. That holds across the whole table, not just the Track cells:
safety-net share falls with both better stars and better margin (47.8% in the
thin/D-F corner, 11.9% in the comfortable/A-B corner). The memo inferred these
ranges without a published cross-tab, and they turn out close.

**Size is the claim that fails outright.** Median beds are flat to inverted:
T3 (144) is smaller than T1 (151), and no cell's median exceeds 201. The
500-bed "large health system" Track 3 and the 175 / 300 / 500 progression are
not in these data. The ROI model scales QI cost, procedures and commercial
revenue off beds, so this is the parameter to revisit first in Phase 4.

**C5 fails narrowly and in the right direction.** 42% of T1 is in the worst
PSI-90 quartile, against 25% at random. That is enriched but not a majority.

## 4. The 23 hospitals

Seventeen of the 23 margin < −1 hospitals have a star rating and are in the
frame. Rank terciles put all 17 in the bottom margin third, but their stars are
4 / 9 / 4 across 1–2★ / 3★ / 4–5★, so **only 4 land in Track 1.** Highland, Gateway,
Conemaugh and Arrowhead are 1–2★, while Harris Health, Parkland, Cambridge Health Alliance and
University Health are 3★, and MLK and Metro Nashville General are 4★. Seventeen
of the 23 are safety-net by the top-quartile cut. They are the clearest case of
the memo's Track 1 financial description, and most of them do not have Track 1
safety ratings. Keeping them in or taking them out changes nothing (γ +0.206 vs
+0.203).

## 5. Who has no star rating

208 hospitals (7.4%) have no published rating and are outside the frame. They
are not a random 7%: median 28 beds against 168, median DSH 0.116 against 0.287,
mean λ 0.17 against 0.50. These are small, low-volume hospitals, most likely
below CMS's minimum measure count. The verdict describes rated hospitals. The
smallest hospitals, which Track 1's "small safety-net hospital" framing half
describes, are mostly unrated and so outside it.

## 6. Caveats carried

- The star rating is broader than safety: it also covers mortality,
  readmission, patient experience and timeliness. Leapfrog's grade is
  safety-specific. The PSI-90 arm is the check on this, and it gives the same
  verdict.
- Rank terciles impose equal thirds on margin. The memo's "thin / median /
  comfortable" doesn't specify proportions. A different cut moves the cell counts
  but cannot manufacture concentration that the continuous γ doesn't show.
- DSH patient percentage is a payer-mix proxy for safety-net status, not the
  memo's definition, which it never pins down.

## 7. Files

```
provenance/archetype-preregistration.md    committed alone first (cdc8669), with DESCRIPTION declaring mclust
R/08-archetypes.R                           new -- make.R stage 34
make.R                                      stage 34 added
data/archetypes.rds                         verdict, all three arms, frame, validation table
output/tables/archetype-validation.csv      one row per test: verdict, C1-C5, sensitivity, PSI-90 arm, ARI
output/tables/archetype-cells.csv           the 3 x 3 tables with per-cell profiles, all three arms
output/tables/archetype-screened23.csv      the 23 by name with star, DSH, beds, PSI-90
output/figures/archetype-validation.png     obs/exp heat map with Track cells outlined; C3; C4
output/tables/task3.16-archetypes.txt       stage log
```

`make.R --stage 34`: `ok`, provenance `consistent`, 6 s. No new source: the
star rating comes from `cc_hospinfo`, already in the table. Provenance table
stays at 33 rows.

## 8. Next

**Phase 3 is complete.** It closes when every result reproduces from the frozen
file through `make.R` (stages 20–34 do) and no importance claim rests on marginal
permutation alone (3.12–3.14). Phase 4 starts at Task 4.1. Carry in two points
from §3: the memo's bed-scaled parameters don't match the data, and Track
proportions should come from the table in §2 if Phase 4 uses Tracks at all.
**Task 6.3 carries §1's plain-language verdict to the Foundation lead.**
