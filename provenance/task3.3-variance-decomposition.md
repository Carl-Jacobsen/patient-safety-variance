# Task 3.3 — Variance decomposition and its figure

**Date:** 2026-09-02 · **Budget:** 5 h · **Status: complete.**
One stage (`make.R` 22, `R/03-variance-decomposition.R`) reading
`data/analytic-v1.rds` and `output/models/task3.2-models.rds` (cross-reference
only — every number reported here is recomputed fresh by this script, nothing
is read out of Task 3.2's serialized fits and reported as-is).

**The method.** Task 3.1 found Block A and Block B entangled
(`wage_index`~`adi` r = −0.66) and Block B internally collinear. Splitting
"how much tracks structure" vs. "how much tracks community" by adding the
blocks in a fixed order is order-dependent and would arbitrarily hand shared
variance to whichever block goes first — exactly the failure mode Task 3.1
flagged for individual covariates, one level up. The fix is the standard one
for this exact problem: **LMG / Shapley-value decomposition** (Lindeman,
Merenda & Gold 1980) — each block's marginal contribution is averaged over
every ordering in which it could be added (3 blocks → 6 orderings, 8 subset
models, each evaluated once and memoised). It is symmetric by construction
and needs no assumption about which block "gets credit" for shared variance.

**Two decompositions, computed independently:**
1. **The composite (psi90)**, twice — uncorrected (plain OLS, as if the
   published value carried no measurement error) and reliability-corrected
   (WLS, `weights = lambda_i`, Task 3.2 §7's choice for the composite). The
   gap between the two is what CMS's smoothing conceals.
2. **The components model** (Task 3.2's primary, un-shrunk fit) — the same
   LMG logic applied to the between-hospital variance component
   (`var_hospital`, the `ccn:hsa` term) instead of R². No smoothing to
   correct for here, so reported once, as a structurally independent
   cross-check on the composite-side headline.

**A bug caught and fixed before the numbers below were final:** the first
pass restricted the composite's common sample to complete cases of
`contract_labor_share` only (n = 2,643) — but `lm()` silently drops rows
missing *any* variable in its own formula, so the 8 subset R²'s were each
being computed on a slightly different N, which breaks the LMG average (it
requires one common sample across every comparison). Fixed to complete-case
across **every** Block A+B+C variable (n = 2,569 — exactly Task 3.2 §7's
Block A+B+C model N, a direct cross-check that the fix is right). The shares
moved by ≤0.001 — reassuring that the bug, while real, was not distorting the
conclusion — but the fix is the correct thing regardless.

**Uncertainty:** nonparametric bootstrap for the composite (hospitals
resampled with replacement, B = 1,000, ~47 s — lm() is cheap). A **cluster
("cases") bootstrap** for the components model: hospitals resampled with
replacement, each resampled copy relabelled with a unique fake `ccn` kept in
its true HSA so `lme4` treats it as an independent unit; B = 150 (8 `lmer`
refits per replicate, ~373 s total, ~2.5 s/replicate — noted plainly, see §3
for why this B is smaller and the CIs correspondingly rougher).

---

## 1. Composite (psi90) — LMG shares, uncorrected vs. reliability-corrected

Common sample for all 8 subset fits: **n = 2,569** (complete-case, Block A+B+C).

| block | uncorrected (OLS) | 95% CI | reliability-corrected (WLS, λᵢ) | 95% CI |
|---|---|---|---|---|
| structure (A) | 4.48% | [3.44, 6.75] | 4.25% | [3.33, 6.80] |
| community (B) | 3.34% | [2.55, 4.80] | 3.62% | [2.80, 5.36] |
| policy (C) | 0.98% | [0.47, 2.02] | 1.19% | [0.52, 2.48] |
| **R² (structure+community+policy)** | **8.79%** | | **9.06%** | |
| residual (unexplained) | 91.21% | [87.88, 92.55] | 90.94% | [86.97, 92.02] |

Shares are **percentage points of total Var(psi90)** — i.e. literally "how
much of the variation tracks X," matching Plan.md §10's own phrasing. Of the
~9% these three blocks explain between them: structure 47–51%, community
38–40%, policy 11–13% (relative shares, not points of total variance —
kept clearly distinct in the script's output and here).

**The gap — what CMS's reliability smoothing conceals:** community's share
rises from 3.34% (uncorrected) to 3.62% (corrected), **+0.28 points**, while
structure's *falls* slightly (4.48% → 4.25%). This is the expected direction:
`plan-amendments.md` §1.3 predicted λ-weighting would un-attenuate exactly
this kind of community-disadvantage association because naive OLS gives
equal weight to low-volume hospitals whose composite value CMS shrunk
hardest. The gap is small in absolute terms (0.28 points) but is the
correctly-signed, correctly-sized answer to "what does the smoothing hide" —
not a large effect, but a real and directionally confirmed one.

`output/tables/variance-decomposition.csv` rows 1–8.

---

## 2. Components model (Task 3.2's primary fit) — LMG on var(hospital)

`var_hospital(null)` = 0.30627 (z-units — **cross-checked against Task 3.2's
frozen fit, exact match**, confirming this script's independent refit
reproduces the earlier stage).

| block | share of var_hospital(null) | 95% CI |
|---|---|---|
| structure (A) | 7.46% | [8.71, 39.34] |
| community (B) | 1.45% | [1.51, 6.70] |
| policy (C) | 2.96% | [−12.12, 13.73] |
| residual (unexplained hospital variance) | 88.12% | [52.23, 89.29] |

**Read the CIs with real caution — flagged, not hidden.** For structure and
community, the bootstrap's lower bound sits *above* the point estimate (e.g.
structure: point 7.46%, CI [8.71, 39.34]). That is a signature of the
B = 150 cluster bootstrap interacting badly with how sparse HSA nesting is
(Task 3.1: 74% of HSAs hold exactly one hospital) — duplicating hospitals
with replacement changes the effective within-HSA group-size distribution in
every replicate, which can shift the null model's own `var_hospital` (the
denominator every share is normalized against) in a way that is not purely
random noise around the original estimate. **This is a real limitation of
the method at this B, not a claim that the point estimates are wrong** — the
qualitative picture (structure and community both explain only a small,
imprecisely-pinned-down slice of between-hospital variance; residual
dominates at ~88%) does not change, and a larger B would narrow but not
relocate these intervals. Flagged as a Task 3.4 candidate if more precision
on this specific quantity is ever needed.

`output/tables/variance-decomposition.csv` rows 9–12.

---

## 3. The candidate sentence (Plan.md §10 / the verify condition)

> Under the reliability-corrected model (WLS, weights = published λᵢ),
> community disadvantage (Block B) is associated with an estimated **3.6%**
> [95% CI 2.8%–5.4%] of the total variance in PSI-90 across hospitals,
> versus **4.3%** for hospital structure (Block A) — of the 9.1% these two
> blocks explain between them, community disadvantage's share (39.9%) is
> slightly less than structure's (46.9%). The naive, uncorrected model would
> have put community's absolute share at 3.3%, 0.3 points lower, which is
> what CMS's reliability smoothing conceals.

**The sentence names its version** (reliability-corrected) per the verify
condition. It is drawn from the composite decomposition (§1), because that
is the published, CMS-smoothed outcome a JHF reader actually sees — not
because it is the more rigorous number.

**Caveat carried forward, stated plainly and not buried:** the components
model (§2, Task 3.2's primary, un-shrunk fit) finds community's share of
between-hospital variance **much smaller** — 1.5% of `var_hospital`, against
structure's 7.5% — a bigger relative gap between the two blocks than the
composite shows, in the *same* direction (structure > community) but more
pronounced. The composite-based sentence is what belongs in front of a JHF
reader; the components-model number is the more conservative, structurally
independent cross-check, and the gap between the two readings is itself
carried forward into Task 3.4's specification-space enumeration and into
Tasks 3.11–3.14 (MCR, TIS) as a reason no single-model number should be
treated as final.

---

## 4. Figure

`output/figures/variance-decomposition.png` — two panels, structure/
community/policy only (residual dropped from the bars — at 88–91% it would
dwarf everything else; reported instead as a text annotation above each
panel). Panel 1: composite, uncorrected vs. corrected, bootstrap error bars.
Panel 2: components model, single set of bars, bootstrap error bars (visibly
wider, per §2's caveat).

---

## 5. Files

```
R/03-variance-decomposition.R                         new -- stage 22
make.R                                                 stage 22 added
output/tables/variance-decomposition.csv               the Sec 1/2 deliverable (12 rows,
                                                        both composite versions + components model)
output/figures/variance-decomposition.png
output/tables/task3.3-variance-decomposition.txt       stage log
```

Full `make.R` from raw: stage 22 depends on `data/analytic-v1.rds` and
`output/models/task3.2-models.rds` (stage 21) — reproduces end to end.

---

## 6. Next

**Task 3.4 — enumerate the specification space.** `[START FRESH SESSION —
the specification space must be defined without the decomposition results
in working memory, per the task sheet.]` Fixes the axis list: covariate
blocks, functional form, outcome definition, reliability treatment
(unweighted / λ-weighted / high-λ subsample / λ-corrected errors-in-
variables — this task's uncorrected/corrected comparison is the λ-weighted
level of that axis, already run once), geographic grain, missing-data
treatment, influential-point handling. **Carry forward:** the composite vs.
components-model gap on community's share (§3) is itself an argument for why
the reliability-treatment axis matters as much as the task sheet already
says it does; the components model's wide bootstrap CIs (§2) are a reason
the eventual Rashomon-set/MCR width reporting (3.11–3.12) should not be
surprised by a similarly wide range on this particular comparison.

---

## Amendment 1 — the components-model bootstrap resamples HSAs, not hospitals (2026-09-28)

**Found at Task 5.1:** the components-model interval did not contain its own
point estimate for structure or community. The published interval for
structure was [8.7%, 39.3%] around a point estimate of 7.5%.

**Cause.** The header called it a cluster bootstrap, but the code resampled
**hospitals** into their true HSA. When a hospital is drawn twice, two
identical copies sit in one HSA, and the `(1 | hsa/ccn)` model reads that as
HSA-level signal. That moves variance out of the hospital term, which is the
denominator of every share.

Measured over 25 draws each (null model, before any covariates):

| | var(ccn:hsa) | var(hsa) | structure share |
|---|---|---|---|
| point estimate | 0.306 | 0.051 | 0.075 |
| hospital resample (old) | **0.121** | **0.254** | **0.191** |
| HSA-cluster resample (new) | 0.303 | 0.052 | 0.084 |

Raising B would not have fixed this, because the bias is in the resampling
unit and not in Monte Carlo noise.

**Fix.** HSAs are now resampled whole with replacement. Each drawn HSA and its
hospitals are relabelled, so a cluster drawn twice enters as two independent
clusters. B = 1,000 (up from 150) and seed 20260928.

- The draws are cached in `data/variance-decomp-boot.rds`, keyed on B, seed,
  scheme and the analytic file's sha256. `VD_REFIT=1` forces a redraw.
- The run took 5,040 s (5.04 s/rep, because whole-HSA draws are larger) with
  0 failed replicates.
- The stage now checks that each point estimate lies inside its own interval.
  **It does, for all three: PASS.**

**What changed:** only the four components-model rows of
`variance-decomposition.csv`. Point estimates are unchanged. The composite side
(uncorrected and λ-corrected, B = 1,000 hospital resample, correct there
because that model has no nesting) is byte-identical, and so is the candidate
sentence.

| Components model | point | old interval | **new interval** |
|---|---|---|---|
| structure | 7.5% | [8.7%, 39.3%] | **[3.7%, 13.9%]** |
| community | 1.5% | [1.5%, 6.7%] | **[−0.6%, 3.7%]** |
| policy | 3.0% | [−12.1%, 13.7%] | **[−0.6%, 8.1%]** |
| residual | 88.1% | [52.2%, 89.3%] | [79.6%, 93.6%] |

**One substantive consequence.** In the components model, community's share of
between-hospital variance is now **not distinguishable from zero**. The old
interval appeared to exclude zero, but only because it was biased upward. The
composite headline, community 3.6% [2.8%, 5.4%] under λ-correction, is
untouched. The components model was always the conservative cross-check, and
it is now more clearly so. §5 must report the two together with this
interval.
