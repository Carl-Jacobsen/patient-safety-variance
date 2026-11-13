# Task 5.4 — Draft §5 and §6, decomposition and driver ranking

**Date:** 2026-09-29 · **Budget:** 8 h · **Status: drafted, and both verify
conditions pass.**

The drafts are `report/05-decomposition.md` (about 2,100 words, citing Figures 2
and 3) and `report/06-drivers.md` (about 2,300 words, citing Figures 4 and 5,
with Table 6.1).

---

## 1. Verify

| Condition | How it is met |
|---|---|
| Every importance claim carries the Rashomon set's width | §6 opens with the contrast width (−0.37 to +0.88 SD) beside the block reliance. Every MCR figure is stated as a range across the set. Every TIS figure has its range, both in the prose and in Table 6.1. The per-measure direction claims are stated as coefficient ranges across the set. §5.3 is built on the width |
| Every number matches the driver script output | Stage 39 has registry blocks for §5 and §6. **§5: 78 tokens, 0 unregistered. §6: 130 tokens, 0 unregistered.** The registry now holds 400+ values across four sections |

Stage 39 also asserts the qualitative claims in §5–§6 that a data change could
silently falsify, and it stops if any assertion fails:

- every composite-anchor top state is NY, and no leave-one-hospital-out
  estimate flips sign;
- the catchment-county set members are all negative and the catchment-tract
  members all positive;
- all 16 linear set members use EIV;
- every PSI-12 set member is positive;
- no composite set member is negative with its interval clear of zero;
- ADI's two largest lenders are ICE and rurality;
- the largest single flow is SVI3 ← limeng;
- ICE lends the most in total and rurality borrows the most;
- ICE is last on Shapley shares;
- no Block A covariate other than beds, volume and margin has MCR⁻ above
  1.01;
- exactly four measures are tagged essential, and exactly one (SVI2) is
  borderline.

## 2. Decision recorded: the Model 2 tag rule (Carl, 2026-09-29)

§4 promised Model 2 tags in §6. Carl chose the four-tag rule after being shown
how each candidate rule falls on the data. **The rule was chosen after the
results were seen, and §6.5 says so in its first paragraph.**

The rule is computed in `R/07-tis-run.R` (stage 32) and written to
`output/tables/driver-tags.csv`. It adds new outputs only: the stage's existing
tables and figure are byte-identical, checked by md5.

- **On loan** is 3.14's shared share (median Δ ÷ median marginal excess) where
  Δ > 0. Where Δ ≤ 0 the neighbors suppress rather than lend, and the share is
  set to 0. Without that clause SVI3, whose Δ is negative and whose marginal
  excess is below 0, would get a meaningless ratio of 8.27.
- The tags:
  - **essential**: direct lower bound above 1 and less than half on loan;
  - **substitutable**: direct lower bound above 1 and half or more on loan;
  - **useful**: TIS lower bound above 1;
  - **optional**: the rest.
- The result: essential are SVI3, limeng, SVI4 and SVI2 (borderline: its
  direct lower bound is 1.0000004); substitutable are ICE, rurality and ADI;
  useful are uninsured and PCP density; optional is SVI1.

## 3. Corrections made while drafting, against the stage outputs

1. **"Net lender" was a mislabel in 3.14's log.** `R/07-tis-run.R` takes
   gross column and row sums of the flow matrix: total lent and total
   borrowed, not lent minus borrowed. §6 says "ICE lends the most in total
   (+0.013) and rurality borrows the most (+0.019)". The first draft's claim
   that ICE "supplies more than it borrows" was not supported and was removed.
   The log line is left as it is; this note records the correct reading.
2. **"Of the 9.1% that the two blocks explain"** came from 3.3's candidate
   sentence. The 9.1% is the full A+B+C R² (structure 4.25 + community 3.62 +
   policy 1.19). The report says "the three covariate blocks", and the
   sentence in `R/03-variance-decomposition.R` is corrected. Stage 22 reran
   from the cached draws and `variance-decomposition.csv` is byte-identical.
3. **Block C ranges are per one SD of the covariate**, not a p10→p90 contrast
   (`R/06-mcr-run.R`, per-SD scalar coefficients). §6.3 says so, and the
   panel C axis label in Figure 4 now names both units.
4. **Tone and scope, from the read-through:**
   - "Each measure can be dropped" contradicted the direct-reliance result;
     it now reads that each measure's own reliance is small.
   - The three measures without direct reliance above 1 are described as
     ones that some credible model can do without, not as "not consequential".
   - "Most often used" became "often used".
   - "Catchments have worse scores" became "hospitals serving … have".
   - The spline members' range replaces "cluster near zero".
   - "Do not displace" is now backed by a number: the median is +0.12
     without Block C and +0.10 with it.

## 4. What §5–§6 hand forward

- **To §1 (5.7):** the sentence, which reads "Under the reliability-corrected
  model, community disadvantage is associated with 3.6% [2.8, 5.4] of the
  variation in published PSI-90, against 4.3% [3.3, 6.8] for structure; of
  the 9.1% the three blocks explain, community is 39.9% and structure 46.9%."
  Also: roughly 90% of the variation is unexplained, and a payment program
  ranking on this score ranks mostly on that variation.
- **To §9 (5.6):**
  - the components model puts community's share at 1.5% [−0.6, 3.7],
    indistinguishable from zero;
  - the state tolerance takes the block's MCR⁻ to 1.000;
  - Block C's partial proxy cannot rule out coding.
- **To §10 (5.7):**
  - data investments: a finer patient-origin file (the grain axis splits the
    sign) and more years or component numerators (the EIV arm);
  - the minimum-viable dataset: the SVI file with its themes kept separate.
