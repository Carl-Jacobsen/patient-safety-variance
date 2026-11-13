# Task S2.2 — Ask for the release-specific methodology

**Date:** 2026-10-03 · **Budget:** 0.5 h · **Status: done; nothing sent.** The
question to the QualityNet Q&A tool is drafted below for Carl to send or hold.
Retrieving the release documents answered more than expected. CMS states that
the composite interval in the October 2025 Care Compare release (the one this
project reads) is built by AHRQ's v2024 Empirical Methods §F.5.1. That turns
the scalar λ from an undocumented assumption into an approximation of a
documented formula, and the formula shows where it can fail. What is still
missing is the matrix of component signal variances. CMS does not publish it,
and it decides whether the project's τ² is right.

---

## 1. What was retrieved

Five documents, archived in `data-raw/methods_psi90_v15/` with
`MANIFEST.sha256`, and added to `provenance/sources.csv` through `prov_add()`
(now 38 rows; make.R's provenance check reports consistent):

| source_id | Document | What it settles |
|---|---|---|
| `cms_psi_v15_factsheet` | CMS+VA PSI v15.0 Fact Sheet | v15 is built on AHRQ v2024; Table 1 lists the ten composite weights; signal variances and reference rates are Medicare-derived and released only with the software |
| `cms_psi_v15_sa_report` | CMS+VA PSI v15.0 Scientific Acceptability Testing Report | Component reliability definition (two-stage normal model); Tables 9–10 give component reliabilities; Table 11 gives a split-half composite ICC of 0.69; Table 13 shows smoothed component correlations no higher than 0.318 |
| `cms_psi_v15_faq` | CMS PSI FAQ, v15 | FAQ 22: the composite interval's standard error comes from AHRQ v2024 Empirical Methods §F.5.1 |
| `cms_psi_v15_replication` | v15.0 replication instructions (Oct 2025) | The software (and with it the parameters) is available only by request through the Q&A tool |
| `ahrq_qi_empirical_methods_v2024` | AHRQ QI Empirical Methods, v2024 | §F.5.2: the composite formula; §F.5.1 (numbered so twice in the source): the composite variance |

QualityNet's file pages are an app shell. The bytes come from
`/publicgateway/public/files/<id>`, which returns a presigned S3 link valid for
300 seconds, and the `url` column records that recipe.

**The version question is answered from the documents.** QualityNet's PSI
Resources page (FY 2026 tab) lists CMS PSI software **v15** for both the October
2025 Care Compare release (CMS+VA population) and the FY 2026 HACRP (CMS-only
population), over discharges from 07/01/22 to 06/30/24. Our Care Compare file
carries that window, so its intervals come from CMS+VA v15.0, built on AHRQ
v2024. The FY 2027 / October 2026 release moves to v16, over discharges from
7/1/23 to 6/30/25.

**A correction for S5.** The draft (03 ¶1) attributes the 0.00191 mean gap
between the Care Compare and HACRP composites to the two releases freezing
claims on different dates. The documents give a different reason: they are
produced by two versions of the software, CMS+VA and CMS-only, whose reference
rates, signal variances and weights are estimated on different reference
populations. S5 should state that cause, with its source.

## 2. What the documented method implies for the scalar λ

AHRQ §F.5 builds the composite for hospital i from component smoothed ratios.
Each component's observed-to-expected ratio is shrunk toward 1 by its own
reliability β_ik, so Ĉ_i − 1 = Σ_k w_k β_ik (OE_ik − 1). The composite posterior
variance is

v_i = Σ_k w_k² Ω_kk (1 − β_ik) + Σ_{j≠k} w_j w_k Ω_jk (1 − β_ij)(1 − β_ik),

where Ω is the component signal variance-covariance matrix. The interval is
Ĉ_i ± z·√v_i on the ratio scale. The project's approximation (Task 2.2) assumes
v_i = τ²(1 − λ_i), with τ² = Var(Ĉ) + E[v] = 0.07744. Three consequences follow,
each checkable once Ω is known.

1. **The interval read is consistent with the published data.** All 2,908
   published PSI-90 intervals in the Care Compare file are symmetric on the
   ratio scale to within the two-decimal rounding (1,491 exactly, 1,417 off by
   0.01, none by more). On the log scale they are not symmetric (median
   log-asymmetry −0.19). So v_i = [(u − l)/(2z)]² is the right reading, provided
   z = 1.96, which no document states.
2. **If Ω is diagonal, τ² is right and λ_i has a clean meaning.** The identity
   Var(Ĉ) + E[v] then equals w′Ωw exactly in expectation. λ_i becomes
   Σ_k w_k² Ω_kk β_ik / Σ_k w_k² Ω_kk, the components' reliabilities averaged
   with weights equal to each component's share of the composite's signal
   variance. That is a legitimate composite reliability. It is still not a
   single shrinkage factor, because each component deviation is shrunk by its
   own β_ik, and the v15 component reliabilities differ by a factor of about
   six (median 0.579 for PSI 03 against 0.100 for PSI 08). So the errors-in-
   variables transform, (Ĉ − ĝ)/λ_i, recovers the unsmoothed composite only
   approximately, even in the best case.
3. **If Ω has positive off-diagonal terms, τ² is too small, and the direction
   is known.** Working the expectation through gives Var(Ĉ) + E[v] =
   w′Ωw − Σ_{j≠k} w_j w_k Ω_jk E[β_ij + β_ik − 2β_ij β_ik], and the bracket is
   non-negative for reliabilities between 0 and 1. A τ² that is too small makes
   every λ_i too small. Shrinkage is then overstated, the errors-in-variables
   arm stretches deviations too far, and the weighted fits put too little weight
   on small hospitals. The smoothed components correlate at up to 0.318 (Table
   13), so some positive signal covariance is likely; its size is unknown.

## 3. Which answer supports the approximation, and which undercuts it

The decisive number is w′Ω_μw computed from the v15 CMS+VA parameters, compared
with the project's τ² of 0.07744.

| Answer | Reading |
|---|---|
| z = 1.96, the interval is Ĉ ± 1.96·√v on the ratio scale, and v includes the off-diagonal terms of §F.5.1 | **Supports** the interval read (v_i is the composite posterior variance). Already consistent with the symmetry check. |
| Ω is diagonal or near it, and w′Ωw lies within 10% of 0.07744 | **Supports** the τ² identity. λ stays as "the composite reliability under the approximation", and S5 still calls the errors-in-variables transform approximate (sec 2, item 2). |
| Off-diagonal Ω terms are material, so w′Ωw exceeds 0.07744 by more than 10% | **Undercuts** τ², and λ is biased low. Recompute λ_i with the true τ² (one line in stage 12) and rerun the λ arms; the published-score primary analyses (S2.1) do not move. |
| z ≠ 1.96, a log-scale or bootstrap interval, or a variance that adds risk-model parameter uncertainty | **Undercuts** the interval read; v_i is mis-scaled for every hospital. The symmetry check argues against a log-scale interval. |
| Components with denominator < 3 enter with β = 0 and their full Ω_kk | Consistent with the approximation; such a hospital's λ is lower, as it should be. A different treatment would bias λ for small hospitals. |

The 10% bar is a proposal, not a pre-registered rule. If Carl sends the
question, the bar should go into `amendments.md` before the answer is read.

Off the critical path: if no answer arrives before S5, the report states λ as a
result under the approximation (already the S2.1 wording), names §F.5.1 as the
documented method, and says the signal covariance matrix was not available to
check τ².

## 4. The draft question

For the QualityNet Question and Answer Tool: Ask a Question → Program
"Inpatient Claims-Based Measures" → Topic "Patient Safety Indicators (PSI)".
Carl decides whether and when to send it; nothing has been submitted.

> **Subject:** CMS+VA PSI v15.0 — construction of the PSI 90 composite interval
> (October 2025 Care Compare)
>
> I am analyzing the CMS PSI 90 composite as published in the Care Compare
> Complications and Deaths file (PSI_90, discharges 07/01/2022 to 06/30/2024),
> which I understand was produced with CMS+VA PSI software v15.0. FAQ 22 of the
> v15 PSI FAQ states that the composite's standard error follows Section F.5.1
> of the AHRQ v2024 Empirical Methods. I would be grateful for confirmation of
> four details that the documents do not state.
>
> 1. Are the Lower Estimate and Higher Estimate fields the composite value plus
>    and minus 1.96 times the square root of w′Var(v)w, on the ratio scale, with
>    Var(v) including the off-diagonal terms Ω_jk(1 − β_j)(1 − β_k) given in
>    Section F.5.1?
> 2. Is the signal variance-covariance matrix Ω used in that calculation a full
>    matrix, or diagonal (signal variances only)? Could CMS share the v15.0
>    CMS+VA values of Ω, or confirm that they are included in the software
>    available on request?
> 3. For a component whose denominator is below three (so the national rate is
>    substituted), does the variance calculation set that component's
>    reliability weight to zero and use its full signal variance?
> 4. Is the difference between the Care Compare PSI 90 value and the FY 2026
>    HAC Reduction Program PSI 90 Composite Value for the same hospital and
>    period due to the CMS-only and CMS+VA versions of the software using
>    different reference-population parameters, or do the two also differ in
>    the claims extract?
>
> The answer would let me check an approximation that treats the composite as a
> single normal shrinkage when estimating each hospital's reliability. Thank you.

An optional second request, under the subtopic "PSI 90 Software", would ask for
the CMS+VA v15.0 software itself, whose parameter files should contain Ω and
the reference rates. The documents do not say whether the software is released
to people outside hospitals. Carl decides on this one as well.

## 5. Verify

The note states which answers support the scalar λ approximation and which
undercut it (sec 3), with the direction of the bias for the most likely failure
(sec 2, item 3). The sources are in `sources.csv` with hashes, and make.R's
provenance check passes.

## 6. Notes for later tasks

- Stage 39 registers `n_sources` from `sources.csv`, so the 03 source count in
  the Sep 30 prose is now stale (33 → 38). S5 should decide whether methods
  references count as sources in that sentence.
- The v15 weights of the project's four components sum to 0.554 (PSI 03 0.1818,
  06 0.0332, 12 0.1527, 13 0.1863). The appendix and section 3 can cite them in
  place of describing the composite in general terms.
- S2.3's guard should treat "recover" near λ the same way it treats "reveal".
