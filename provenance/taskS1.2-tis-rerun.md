# Task S1.2 — Rerun the decomposition and rebuild the tags as exploratory

**Date:** 2026-10-02 · **Budget:** 3 h · **Status: done. Exploratory
throughout. Under the preregistered threshold, no disadvantage measure is
essential or substitutable.** Three are *useful* (limited English, SVI 3,
rurality) and seven are *optional*. The September 30 data-prioritisation
recommendation (keep the SVI file, ADI substitutable) does not survive. Stage
32's log shows invariant 3 passing on all 7,360 pairs.

---

## 1. What ran

`Rscript make.R --stage 32` under the S0.3 cache key took 9.5 min: 5.1 for the
decomposition and about 4 for the bootstrap. The run had these parts.

- **Invariants.** All three S1.1 invariants pass on all 736 specifications
  (worst 1.8e-15, 5.0e-15, 1.4e-13), and all three fail on the September 30
  wrapper.
- **Signed reporting.** The ranking table carries the positive-part sender
  term, the signed net sender term (median and range) and TIS_net
  (min..med..max) beside TIS. `tis-decomposition.csv` gains `sendnet_*`,
  `tisnet_lo/hi`, `rank_tis` and `rank_tisnet`; `tis-per-model.csv` gains
  `sender_net`, `e_orig` and `pred_err`. The flow matrix prints signed values,
  with lender and borrower totals both positive-only and net. Figure panel 3
  plots TIS_net beside TIS.
- **Correction.** The flow matrix was always the **mean** over the set; the
  September 30 log and note called it the median. The label is fixed.
- **Tags** under preregistration sec 5, at all three tolerances, and an
  HSA-cluster bootstrap (B = 200, seed 20261001 + b, one resample shared by
  both anchors) of P-best 382 and P-median 610. Both anchors were re-derived
  by the sec 1 rule and asserted. No replicate failed out of 400. The
  bootstrap is cached in `data/tis-boot.rds`; the replicates are in
  `output/tables/tis-boot.csv`.
- **Stage 39.** Its five TIS claim asserts (`R/13-report-numbers.R`) now
  record a failed claim and carry on instead of crashing. One run therefore
  lists every stale claim and number, and the stage still fails at the end.
  Three claims fail; sec 5.

## 2. Measure by measure, September 30 against now

The old values used analytic-v1 and the defective wrapper. The new ones use v2
and the repaired wrapper. The v1→v2 change alone moves stage 30's marginal
medians by at most 0.0003 and leaves the set unchanged (194, same IDs), so the
differences below are the repair. Medians are over the 194; "dir lo" is the
lowest direct reliance in the primary set.

| Measure | Marginal | Direct | Dir lo | Shared share | Δ<0 | TIS | Rank | Tag |
|---|---|---|---|---|---|---|---|---|
| limited English | 1.043 → 1.045 | 1.018 → 1.020 | 1.0070 → 1.0066 | 42% → 52% | 8% → 0% | 1.023 → 1.039 | 3 → 1 | essential → useful |
| SVI 3 | **0.998 → 1.031** | 1.017 → 1.019 | 1.0015 → 1.0020 | n/a → 46% | 97% → 0% | 1.028 → 1.034 | 1 → 2 | essential → useful |
| uninsured | 1.009 → 1.029 | 1.018 → 1.025 | 0.9997 → 1.0000 | neg → 18% | 98% → 1% | 1.021 → 1.027 | 4 → 3 | useful → optional |
| ICE | 1.011 → 1.018 | 1.005 → 1.006 | 1.0008 → 1.0012 | 65% → 63% | 48% → 0% | 1.024 → 1.019 | 2 → 4 | substitutable → optional |
| SVI 1 | 1.006 → 1.015 | 1.008 → 1.011 | 0.9966 → 1.0001 | neg → 19% | 75% → 5% | 1.009 → 1.018 | 7 → 5 | optional → optional |
| rurality | 1.021 → 1.010 | 1.006 → 1.005 | 1.0016 → 1.0001 | 72% → 50% | 0% → 1% | 1.016 → 1.016 | 5 → 6 | substitutable → useful |
| ADI | 1.017 → 1.009 | 1.003 → 1.004 | 1.0004 → 1.0004 | **78.5% → 42.5%** | 2% → 6% | 1.013 → 1.013 | 6 → 7 | substitutable → optional |
| SVI 4 | 1.007 → 1.009 | 1.007 → 1.007 | 1.0015 → 1.0019 | 8% → 13% | 30% → 4% | 1.009 → 1.010 | 8 → 8 | essential → optional |
| SVI 2 | 1.006 → 1.007 | 1.006 → 1.007 | 1.0000 → 1.0000 | 4% → 4% | 49% → 24% | 1.008 → 1.008 | 9 → 9 | essential (borderline) → optional |
| PCP density | 1.003 → 1.001 | 1.001 → 1.000 | 0.9999 → 0.9992 | 73% → 20% | 4% → 24% | 1.005 → 1.005 | 10 → 10 | useful → optional |

Across all ten measures:

- **Shared share of the total.** Summed over the ten, the median model's
  marginal excess is **0.2006**, of which **0.0828 (41.3%)** is shared. On
  September 30 it was 0.133, 0.021 and 15.5%. The new 41.3% is not the old
  41.3% (that was the share of negative Δ), and nothing more connects them.
- **Negative Δ** now occurs in **6.4%** of measure-by-model pairs, against
  41.3% on September 30. Most of the "suppression" the September 30 draft
  explained was the defect, not the cross-terms.
- **Direct reliance above 1 in every set member** now holds for **9 of 10**
  (all but PCP density), against 7. Seven of the nine fail the 1.005
  threshold.
- **Flows.** The largest is **limited English ← SVI 3, +0.0162**. On
  September 30 it was SVI 3 ← limited English at −0.016: the direction and
  sign are reversed. The largest lender is **SVI 3** (+0.0186) and the largest
  borrower **limited English** (+0.0257), the same whether flows are counted
  positive-only or net. ICE and rurality held these roles on September 30.
  Eight of 90 mean flows are negative, all of them under 0.0002 in size.
- **TIS against TIS_net.** The two now rank the measures **identically**
  (Spearman +1.000). Truncation at zero matters little once the spurious
  negative flows are gone.
- **Shapley.** The Shapley values at the ERM did not move (they never used the
  wrapper). Their rank correlation with TIS is **+0.39** (was +0.27). ICE is
  still last on Shapley but now 4th on TIS.

**SVI theme 3.** The September 30 pattern, marginal reliance below 1 with
direct reliance above 1, is gone, as the task sheet expected. Marginal
reliance is 1.031 (median), and its Δ is positive in every set member.
Corrected direct reliance has a median of 1.019 and stays above 1 in all 194
primary members (lowest 1.0020). It does not clear 1.005 there, and at the
metropolitan tolerance its lowest falls to **0.99995**. So some credible model
can do without SVI 3's unique part. At the two anchors it is robust: 100% and
97% of bootstrap replicates have direct reliance ≥ 1.005. Its tag is *useful*,
earned through TIS (lowest 1.0104), mostly as the main source of limited
English's shared reliance. The case presented as the one that "justifies the
method" was produced by the defect.

## 3. Tags (exploratory; `driver-tags.csv`)

The rule is the 2026-09-29 four-tag rule, with 1.005 in place of 1 (prereg
sec 5). The "on loan" share is defined as before. The metropolitan set
(319 members) contains the primary set (194), so its lower bound binds.

| Measure | Tag | Dir lo, primary / metro | On loan | TIS lo | Primary / metro / state | Boot share ≥ 1.005, P-best / P-median |
|---|---|---|---|---|---|---|
| limited English | useful | **1.0066** / 1.0040 | 0.52 | 1.0108 | substitutable / useful / optional | 1.00 / 0.99 |
| SVI 3 | useful | 1.0020 / 1.0000 | 0.46 | 1.0104 | useful / optional / optional | 1.00 / 0.97 |
| rurality | useful | 1.0001 / 1.0001 | 0.50 | 1.0074 | useful / optional / optional | 0.39 / 0.78 |
| uninsured | optional | 1.0000 / 1.0000 | 0.18 | 1.0022 | optional throughout | 1.00 / 0.92 |
| SVI 1 | optional | 1.0001 / 1.0000 | 0.19 | 1.0023 | optional throughout | 0.91 / 0.96 |
| ICE | optional | 1.0012 / 1.0000 | 0.63 | 1.0036 | optional throughout | 0.82 / 0.75 |
| SVI 4 | optional | 1.0019 / 1.0000 | 0.13 | 1.0036 | optional throughout | 0.84 / 0.78 |
| SVI 2 | optional | 1.0000 / 0.9999 | 0.04 | 1.0038 | optional throughout | 0.84 / 0.71 |
| ADI | optional | 1.0004 / 1.0004 | 0.43 | 1.0036 | optional throughout | 0.71 / 0.79 |
| PCP density | optional | 0.9992 / 0.9992 | 0.20 | 1.0012 | optional throughout | 0.11 / 0.04 |

**Margins (verify condition).** Every tag is assigned by a comparison with
1.005, so none rests on the old comparison with 1, which had no practical
margin.

- **Limited English** is the closest call. It clears 1.005 at the primary
  tolerance by 0.0016 and misses at the metropolitan tolerance by 0.0010.
  That gap alone separates *substitutable* (its tag at primary, since 52% is
  on loan) from *useful*.
- **Rurality's** *useful* rests on a TIS lower bound 0.0024 above the
  threshold, and SVI 3's on 0.0054.
- **ICE, SVI 4, SVI 2 and ADI** sit 0.0014 or less below the TIS threshold, so
  a small change could make any of them *useful*.

**Stability.** Seven of ten tags are the same at all three tolerances. The
three that move (limited English, SVI 3, rurality) are the three that are not
*optional*, and each moves toward *optional* as the tolerance widens. At the
state tolerance every measure is *optional*.

**What the bootstrap does and does not say.** It resamples HSAs and refits
the two anchors, so it measures sampling stability at two specifications. It
says nothing about the set's lower bound, which is set by other members. Most
measures clear 1.005 at the anchors in most replicates: uninsured 100% and
92%, SVI 1 91% and 96%. Yet some set member always sits near 1. The tags turn
on that **specification spread**, not on sampling noise at the anchors.
Rurality (39% at P-best) and PCP density (11% and 4%) are the exceptions,
where sampling noise matters too.

**Reading.** On the preregistered rule, the TIS evidence supports no ranked
minimum dataset. No measure is one that every credible model needs beyond
half a percent of squared error, and the three *useful* tags lose that status
at wider tolerances. That is consistent with placing the ranking in the
supplement and resting any data-prioritisation claim on S2.4's held-out
validation (prereg sec 6).

## 4. Exploratory status and lineage

The flow allocation is labelled exploratory everywhere it is printed. Its
lineage:

- **Spring derivation** (`Rashomon/Spring 26/docs/decomposition_algorithm.docx`).
  Δ splits into a quadratic part and a cross-term part. Each part is
  attributed to neighbour k separately, with
  Δ_j^(k),cross = 2β_j α_k Σ r_i x_ik / ((n−1)e₀). The derivation calls the
  cross-term "typically negligible" away from the ERM and tracks it as a
  diagnostic (`cross_term_frac`). **This project's implementation (Task 3.13)
  divides all of Δ, cross-terms included, in the proportions of the quadratic
  terms α_k Cov(v_k, v_j).** The two allocations agree at the ERM and differ
  elsewhere, and no specification here is the ERM on its evaluation frame.
  The cross-term share was never computed. Reported as a limitation, not
  repaired.
- **Autumn sketches** (`Rashomon/Autumn 26/Project sketches - Rashomon
  variable importance.docx`, sketch 1) list three things as unfinished:
  - the conditional draw beyond linear classes ("contestable", model-dependent).
    Here the draw is a linear residualisation in contribution space, which
    for log-scale specifications is linear in exp(v), and for spline
    specifications is linear in the summed basis contribution.
  - uncertainty for the flow matrix (RID-style resampling or a calibrated
    outer set). There is none here beyond the anchor bootstrap of direct
    reliance.
  - per-neighbour attributions are unstable under near-collinearity even
    when their sum is stable. The ten measures have R² on the rest up to
    0.57.
- **S1.1** adds a fourth item: sender credit is invariant to the size of the
  neighbour's coefficient. A fitted proxy outranks its signal (TIS 2.28
  against 1.72; prereg amendment 1).

## 5. Every September 30 sentence that cited a TIS number or TIS claim

"Survives" means it can stand with at most a number changed. Stage 39 flags
the numbers mechanically (sections 01, 04 and 06). The appendix has no
registry block and was checked by hand.

| Where | Sentence (abridged) | Survives? |
|---|---|---|
| 01 ¶9 | "the measures no credible model can replace … three of the four SVI themes … and the limited-English share" | **No.** None clears 1.005 at both tolerances. |
| 01 ¶9 | "ADI … is substitutable: 78.5% … other measures also carry" | **No.** ADI is optional, with 42.5% shared. |
| 01 ¶9 | "A minimum dataset built on ADI alone would … drop the four that no credible model can replace" | **No.** |
| 01 ¶9 | "The tags follow a rule chosen after the results were seen" | Yes. The threshold is now preregistered; the four-tag rule is still post hoc. |
| 04 ¶57 | Method description: direct and shared parts, flow table, TIS, synthetic checks | Yes as description. Add exploratory status and the fitted-proxy property. |
| 04 ¶59 | "direct reliance above 1 in every credible model is essential" | **No.** The threshold is 1.005, at the primary and metropolitan tolerances. |
| 04 ¶59 | "SVI theme 3 … median ordinary reliance of 0.998 … dispensable only because … limited-English share offsets" | **No.** Marginal is 1.031, and the flow runs the other way, positive. |
| 06 ¶25 | "reliance beyond 1 is 0.133, of which 0.021, or 15.5%, is shared … Most of the importance is therefore the measures' own … concentrated in a few measures" | **No.** 0.201, 0.083 and 41.3%. Five measures have 42% or more shared, so it is not concentrated. |
| 06 ¶27 | "The other nine measures reconstruct 57% of its [ADI's] variation" | Yes (56.9%). |
| 06 ¶27 | "78.5% of its reliance … is shared …, mainly with ICE and rurality" | Number **no** (42.5%). Partners yes (ICE +0.0040, rurality +0.0011). |
| 06 ¶27 | "Its direct reliance stays above 1 in every credible model" | Yes (lowest 1.0004), but below the practical threshold. |
| 06 ¶27 | "most of what makes ADI look important … is information the other measures also supply" | **No.** Under half. |
| 06 ¶27 | SVI 3 "reverse case", 0.998, flow −0.016, "carries information no other measure supplies" | **No.** See sec 2. |
| 06 ¶27 | "ICE is the source of the most shared importance (+0.013), and rurality's reliance includes the most (+0.019)" | **No.** SVI 3 lends most (+0.019) and limited English borrows most (+0.026). |
| 06 ¶29 | TIS order SVI 3 (1.028), ICE (1.024), limited English (1.023) … | **No.** Now limited English 1.039, SVI 3 1.034, uninsured 1.027, ICE 1.019, SVI 1 1.018, rurality 1.016, ADI 1.013, SVI 4 1.010, SVI 2 1.008, PCP 1.005. |
| 06 ¶29 | "ranges … wide and overlap (ADI's runs from 1.002 to 1.071)" | Yes in substance (1.004 to 1.077). |
| 06 ¶29 | "Seven of the ten … direct reliance above 1"; the three that do not (uninsured, SVI 1, PCP) | **No.** Nine, and only PCP density fails. |
| 06 ¶31 | "rank correlation of only +0.27" | Number **no** (+0.39). Shapley and TIS still answer different questions. |
| 06 ¶31 | "ICE … ranks last on Shapley shares … and second on the total importance score" | Half. Still last on Shapley, but now 4th on TIS. |
| 06 ¶35 | Tag rule with threshold 1 | **No.** Replaced by the prereg sec 5 rule. |
| 06 Table 6.1 | All ten rows: score, range, lowest direct, shared, tag | **No.** Every row changes (sec 3). |
| 06 ¶52 | "SVI theme 2 clears the essential threshold only beyond the sixth decimal place" | **No** (moot; optional). |
| 06 ¶52 | ICE "substitutable … yet it ranks second overall" | **No.** |
| 06 ¶52 | "every tag describes the models, not the world" | Yes. |
| 06 ¶54 | "The four essential measures are three of the four SVI themes and the limited-English share … ADI … substitutable … the better-supported choice is the SVI file" | **No.** |
| 10 ¶11 | Recommended core = SVI file, because "three of the themes and the limited-English share are the measures no credible model can replace"; "ADI, ICE and rurality are substitutable"; "SVI theme 2 holds its tag only narrowly" | **No.** The TIS evidence supports no core. The recommendation must rest on S2.4 or be dropped. |
| App. ¶92 | "a noise measure correlated with a real signal … ranks below any measure that carries signal of its own" | **No.** False for a fitted proxy (S1.1 sec 4). |
| App. ¶94 | "41.3% of the measure-by-model values of Δ are negative" | **No** (6.4%). The suppression explanation still stands as a possibility. |
| App. ¶96 | "Thirty checks ran …"; synthetic recoveries 0.64, 0.361/0.639 | Count **no** (37). The recoveries survive. |
| Fig. 5 | Panels built from `tis-decomposition.csv` / flow matrix | Regenerated by stage 38 (`fig5-tis-decomposition.png`); old content superseded. |

Stage 39 fails three qualitative claims: the largest flow, the top lender and
borrower, and four essential measures with SVI 2 borderline. Two claims still
hold: ADI's main partners and ICE last on Shapley. All of sections 1 and 10
that rest on Table 6.1 go in the S5 rewrite.

## 6. Not done here

- The cross-term share of Δ per measure (sec 4). If S5's supplement wants it,
  it is a 30-minute addition to `decompose_spec()`.
- Sections 1, 4, 6, 10 and the appendix are not edited; S5 rewrites them.
