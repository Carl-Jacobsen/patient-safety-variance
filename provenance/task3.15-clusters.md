# Task 3.15 — Cluster on margin and safety maturity

**Date:** 2026-09-23 · **Budget:** 7 h · **Status: complete.**

One stage (`make.R` 33, `R/08-clusters.R`), reading `analytic-v1.rds` only.
Every choice in it was fixed in `provenance/cluster-preregistration.md`, which
was committed alone as `2d3659b` before the first mixture was fitted. That
commit is the evidence for the verify condition. Nothing in the pre-registration
was revisited after a solution was seen.

The question is whether hospitals fall into distinct groups on the two axes the
CASH2 Tracks are stylized on, operating margin and safety maturity (PSI-90). The
criterion is ICL over Gaussian mixtures, G = 1 to 9, all fourteen covariance
models. BIC and the gap statistic are reported beside it. PSI-90 enters twice:
as published (CMS-shrunk) and λ-corrected (un-shrunk, `gm + (psi90 − gm)/λ_i`).

**The headline: the data are one cloud. No criterion finds separated strata. ICL
returns a dense core with a halo or tails split off around it, under both PSI-90
versions and both screens. The gap statistic returns k = 1 in all four runs, and
ICL's own choice is unstable under subsampling. What does exist is a continuous
gradient: worse margin goes with worse PSI-90, r = −0.17 published and −0.20
corrected. The Tracks have the direction right and the discreteness wrong.**

---

## 1. Screening, before clustering

Phase 0's two catastrophic outliers were already NA from Task 2.3's
net-patient-revenue guard. The pre-registered screen (margin non-missing and
≥ −1, Task 2.3's `flag_margin_extreme` line) removed 42 hospitals: 23 below −1,
5 with NPR under $1M, and 14 with no HCRIS margin. **Primary frame: 2,759.** The
sensitivity screen (≥ −0.5) removes 54 more, leaving 2,705.

**The 23 screened are not a random tail.** They include Harris Health, Parkland,
Highland, MLK Jr. Community, Cambridge Health Alliance, University Health (San
Antonio), San Mateo Medical Center, Arrowhead Regional and Metro Nashville
General. These are largely county-funded public safety-net hospitals whose
operating expense runs two to five times their patient revenue because
appropriations cover the gap. The screen is right that operating margin
misdescribes them. It is also true that they are the hospitals Track 1 was drawn
around. They are listed in `cluster-screened.csv`, not assigned to a cluster, and
**Task 3.16 has to handle them explicitly rather than inherit their absence.**

## 2. What shrinkage does to the cloud

This was measured before any clustering (prereg §6). Spread of PSI-90 within λ
quartiles, primary frame:

| λ quartile | λ range | SD published | SD corrected |
|---|---|---|---|
| Q1 | 0.09–0.29 | 0.083 | 0.380 |
| Q2 | 0.30–0.46 | 0.165 | 0.419 |
| Q3 | 0.46–0.66 | 0.221 | 0.385 |
| Q4 | 0.66–0.96 | 0.254 | 0.332 |

**The task sheet's prediction holds.** In published PSI-90 the lowest-volume
quarter has one third the spread of the highest (0.33×), so any cluster fitted on
it is artificially tight exactly where volume is low. Un-shrunk, the quartiles
are roughly level (1.15×). The corrected version doubles the overall SD
(0.192 → 0.382), and its minimum stays positive (0.215). Neither version is
designated primary: one understates low-volume hospitals' spread and the other
restores their noise along with their signal.

## 3. Selection

| Screen | PSI-90 | n | **ICL (criterion)** | BIC | gap | ICL stability |
|---|---|---|---|---|---|---|
| primary | published | 2,759 | **G = 2** (VEV) | 4 | **1** | 44% |
| primary | corrected | 2,759 | **G = 4** (EII) | 5 | **1** | 59% |
| sensitivity | published | 2,705 | G = 3 (EVE) | 6 | 1 | — |
| sensitivity | corrected | 2,705 | G = 2 (EVE) | 5 | 1 | — |

Under the pre-registered reading rule, ICL's G is the answer and the gap
statistic's disagreement is part of the finding. Three things say the ICL
answers are not strata:

- **The gap statistic falls monotonically from k = 1** in all four runs
  (published 2.47 → 2.34 → 2.22 …). A uniform reference box fits these data as
  well as any partition does.
- **ICL is not smooth in G.** Published ICL relative to its maximum runs
  −976, 0, −1,234, −981, −505 from G = 1 to 5. Corrected ICL has a second peak at
  G = 7 within 107 units of the best. A real partition would show one clear peak.
- **ICL's choice does not survive subsampling.** Over 100 subsamples of 80
  percent, published returns G = 2 in only 44 (the rest scatter across 3 to 6),
  and corrected returns G = 4 in 59 (the rest across 2 to 6).

BIC selects 4 to 6 components everywhere, as the pre-registration said it would
on data this skewed. It is estimating a density, not finding groups.

## 4. What the selected solutions actually are

Clusters are ordered by mean published PSI-90, best first.

**Published, ICL G = 2:** a core of 2,369 (86%) with median margin −0.5% and
PSI-90 0.95, and a halo of 390 (14%) with median margin −9% and PSI-90 1.27. The
figure shows the halo surrounding the core on every side, including both margin
extremes. The VEV model gives the second component a larger volume, which is the
signature of a mixture fitting a heavy-tailed distribution rather than two groups.

**Corrected, ICL G = 4:** a core of 2,517 (91%) plus three tails of 61, 66 and
115 hospitals: high margin (+43% median), deeply negative margin (−60%), and high
PSI-90 (corrected median 2.06). A spherical equal-volume model (EII) trimming the
edges of one cloud looks exactly like this.

**Sensitivity screen:** the same core-plus-tails shape. Published G = 3 is
85% / 14% / 2%, and corrected G = 2 is 91% / 9%.

**The forced three-component solutions** are kept for Task 3.16 and labelled
forced (prereg §5). Published: 79% / 20% / 1%. Corrected: 94% / 2% / 4%. **The
two versions' forced-3 assignments agree at an adjusted Rand index of 0.163.**
Whether shrinkage is undone changes which hospitals land where almost entirely,
so a three-way split of these data is not a stable object.

None of these looks like the CASH2 Tracks. The Tracks imply three populated
bands ordered jointly on margin and safety. Every solution here is a majority
core holding 79 to 94 percent of hospitals.

## 5. What this hands Task 3.16

3.16 tests whether Tracks 1 to 3 exist as strata. On margin and PSI-90, 3.15's
answer is no: the variation is continuous. It is not structureless, though.
Margin and PSI-90 correlate at −0.17 published and −0.20 corrected, in the
direction the Tracks assume. The most defensible reframing for the Work Group is
**a gradient, not three archetypes**.

That is a null result on the Tracks' discreteness. It should be written up as
such and pre-socialized with the Foundation lead at Task 6.3. 3.16 still needs to:

1. Run the CMS star-rating fallback (`Hospital overall rating`). Star rating is a
   broader safety-maturity proxy than PSI-90 and could separate where PSI-90 does
   not. 3.15 does not pre-empt that.
2. Decide how the 23 screened public safety-net hospitals enter. Any Track 1 test
   that silently drops them is testing a different population.
3. Use the forced-3 assignments only as a comparison against Track labels, never
   as evidence that three groups exist.

## 6. Files

```
provenance/cluster-preregistration.md   committed alone first (2d3659b)
R/08-clusters.R                          new -- make.R stage 33
make.R                                   stage 33 added
renv.lock                                mclust 6.1.3 (in the prereg commit)
data/clusters.rds                        frames, assignments (selected + forced3), selection tables
data/cluster-stability.rds               100-subsample ICL picks (cached; CLUSTER_REFIT=1 forces)
output/tables/cluster-selection.csv      ICL and BIC for every G x model, gap by k
output/tables/cluster-summary.csv        selected G per criterion, version and screen, with stability
output/tables/cluster-profiles.csv       every solution's clusters in natural units
output/tables/cluster-screened.csv       the 96 hospitals outside a frame, with reasons
output/tables/cluster-shrinkage.csv      §2's table
output/figures/clusters.png              clouds coloured by ICL's pick; ICL and gap against G
output/tables/task3.15-clusters.txt      stage log
```

`make.R --stage 33`: `ok`, provenance `consistent`, 84 min cold: 15 min of
selection (mostly the gap statistic's 500 reference sets), 69 min of stability.
Warm runs read the stability cache and take about 15 minutes. Seven k-means
"Quick-TRANSfer steps exceeded" warnings came from Hartigan–Wong inside gap
reference draws. They are convergence notes on individual starts, not failures,
and with `nstart = 25` they do not move the gap values. Provenance table stays
at 33 rows.

## 7. Next

**Task 3.16: validate the Track archetypes.** Carry §5's three items in.
