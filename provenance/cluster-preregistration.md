# Archetype clustering — pre-registration

**Date:** 2026-09-23 · **Task:** 3.15 · **Status: fixed before the first mixture
was fitted.**

Task 3.15's verify condition is that the cluster-count criterion was fixed in
advance and that the solution was not tuned toward producing three clusters. A
statement inside the commit that carries the answer is not evidence of either, so
this file goes in first and on its own, as `rashomon-preregistration.md` did at
Task 3.9. Its commit timestamp is the evidence.

What had been looked at when this was written: the marginal quantiles of
`operating_margin`, `psi90` and `lambda_i` in `analytic-v1.rds`, the same
quantiles Phase 0 and Task 2.3 already published. No clustering, mixture,
k-means or distance computation of any kind had been run on these data.

---

## 1. What the clusters are asked to find

The CASH2 memo's three Tracks (`CASH memo/Models/vbp_model.R`,
`vbp_model_parameter_table.md` §A) are stylized on two axes: financial position
("thin margin" / "median margin" / "comfortable margin") and safety maturity
(Leapfrog D/F / C–uneven B / A–B). Task 3.15 asks whether hospitals fall into
distinct groups on those two axes. Task 3.16 asks whether those groups are the
Tracks. This task answers the first question only, and **"one group" is an
admissible answer.** No criterion below is capable of returning fewer than one
cluster, and every one of them is capable of returning one.

## 2. The two inputs

- **Margin.** `operating_margin` from the frozen file: HCRIS FY2023
  (Net Patient Revenue − Less Total Operating Expense) ÷ Net Patient Revenue,
  built at Task 2.3.
- **Safety maturity.** PSI-90, lower is better, in two versions, both reported:
  - **published** — `psi90` as CMS publishes it, already shrunk toward the mean
    by CMS's empirical-Bayes smoothing;
  - **λ-corrected** — the same value un-shrunk,
    `gm + (psi90 − gm) / λ_i`, with `gm` the unweighted mean of `psi90` over the
    clustering frame (§3) and `λ_i` the reliability from Task 2.2. This is the
    transform the specification curve's errors-in-variables arm uses
    (`R/04-spec-curve.R`), applied unchanged.

  Shrinkage pulls a low-volume hospital's published value toward the mean, which
  tightens any cluster exactly where volume is low; the un-shrunk version undoes
  that at the price of the sampling noise the shrinkage was suppressing (λ runs
  0.09 to 0.96, so the noisiest deviations are stretched about elevenfold). Each
  version is biased in its own direction. Neither is designated primary.

Leapfrog grades are not in the frozen file; Task 3.16 handles the CMS star-rating
fallback. PSI components, payer mix and DSH share are not clustering inputs: the
task names two dimensions, and adding axes after the fact would be the kind of
choice this document exists to close off.

**Scaling.** Each input is z-scored on the clustering frame, separately per
version. No other transform: PSI-90 is not logged because the λ-corrected version
takes negative values and both versions must share one scale.

## 3. Screening, before clustering

Phase 0 found two catastrophic margin outliers on near-zero revenue denominators.
Task 2.3's guard already set margin to NA where Net Patient Revenue is below $1M
(5 hospitals) and 14 more have no margin at all. That leaves a long negative tail.

**Screening rule:** a hospital enters the clustering frame only if
`operating_margin` is non-missing **and** `operating_margin ≥ −1`, that is,
operating expense no more than twice net patient revenue. Below that line a
hospital is funded mainly by something other than patient revenue (state
appropriation, grants, a parent system), its operating margin does not describe
the financial position the Tracks mean, and a single such point on a z-scored axis
would dominate any distance-based or Gaussian fit. This is Task 2.3's
`flag_margin_extreme` rule; no threshold is chosen here. Screened hospitals are
listed in an output table with their values and are not assigned to a cluster.
Nothing else is screened: PSI-90 is complete and no hospital is removed for its
PSI-90 value.

**One pre-registered sensitivity:** the whole analysis re-run at the tighter screen
`operating_margin ≥ −0.5`. It is reported alongside, is not a substitute for the
primary screen, and neither screen is preferred after seeing which yields the
cleaner answer.

## 4. Method and the cluster-count criterion

**Model.** Gaussian finite mixtures (`mclust` 6.1.3, `Mclust()`), all fourteen of
its covariance parameterizations, `G = 1, …, 9` components, default hierarchical
initialization. The range is symmetric about three and starts at one.

**Criterion: ICL** (integrated completed likelihood; Biernacki, Celeux & Govaert
2000). The selected solution is the (G, covariance model) pair with the highest
ICL. ICL rather than BIC because they answer different questions: BIC selects the
mixture that best **estimates the density**, and on skewed data (PSI-90's skew is
+2.75) it adds components to fit the skew whether or not separate groups exist.
ICL adds an entropy penalty for overlapping components, so it selects **separated
groups**, which is what "the Tracks exist as strata" means. BIC's selection is
computed and reported next to ICL's and does not override it.

**Independent check: the gap statistic** (Tibshirani, Walther & Hastie 2001) on
k-means of the same z-scored inputs: `cluster::clusGap`, `K.max = 9`, `B = 500`
reference sets drawn uniformly over the data's principal-component box
(`spaceH0 = "scaledPCA"`), `d.power = 2`, k-means with `nstart = 25`, and the
paper's own rule (`method = "Tibs2001SEmax"`): the smallest k with
Gap(k) ≥ Gap(k+1) − SE(k+1). The gap statistic is a different family of method
with a different null, and it too can return k = 1.

**Reading rule, fixed now.**
- ICL's G is the answer for that PSI-90 version.
- If ICL selects G = 1, the reading is that hospitals do not separate into strata
  on these two axes under that version.
- If ICL and the gap statistic disagree, both are reported and the disagreement
  is part of the finding. Neither is used to break the other's tie, and no third
  criterion is introduced after the fact.
- If the published and λ-corrected versions disagree, both are reported. That is
  the comparison the task asks for, not a problem to resolve.

**Selection stability.** 100 subsamples of 80 percent of the frame, drawn without
replacement (duplicated points from a with-replacement bootstrap produce
degenerate zero-variance Gaussian components). ICL's selected G is recorded on
each; the share of subsamples agreeing with the full-frame G is reported.

**Seed:** 20260923, set once at the top of `R/08-clusters.R`.

## 5. The three-cluster solution

A three-component solution is computed for each version regardless of what ICL
selects, because Task 3.16 needs to compare the data with a three-way Track
assignment. It is labelled **forced**, not selected, in every table and figure,
and it is never reported as the answer to §1's question.

## 6. What is reported for every solution

Cluster size; mean and median margin and PSI-90 per cluster, in natural units;
mean λ per cluster; and, to test the shrinkage prediction directly, the spread of
each PSI-90 version within λ quartiles.

## 7. What would count as violating this

Changing the criterion, the G range, the screen, the inputs, or their scaling
after any solution has been seen. If ICL returns something awkward — one cluster,
nine, or three groups that look nothing like the Tracks — that is the finding, and
it goes to Task 3.16 and the Foundation lead as it fell.
