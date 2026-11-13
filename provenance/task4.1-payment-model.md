# Task 4.1 — Design the payment-impact model

**Date:** 2026-09-24 · **Budget:** 6 h · **Status: complete.**

Design only. No code, no `make.R` stage, no data product. The deliverable is
`provenance/payment-model-inputs.md`, committed before any simulation, so its
commit timestamp is the evidence for the verify condition's order.

---

## 1. What was decided

- **A payment model, not an ROI re-run.** Q-HIP bonus dollars per hospital,
  from CASH2's band (0.1–4%), its linear score-to-band map, its 15%
  attribution and its full-book eligibility base case. QI cost, SSI and QALY
  inputs stay in CASH2 (Plan §6).
- **Hospitals, not Tracks.** 3.16 found a gradient and failed the Track bed
  sizes, so revenue is each hospital's NPR × CASH2's commercial share (37%,
  × 0.40 for safety-net). The linear map reproduces CASH2's Track bonus rates
  within a quarter point (0.75 / 2.05 / 3.35% against 0.5 / 2.0 / 3.5%), so
  the Track rates are not needed.
- **PSI-90 as the lever, at CASH2's 15%.** CASH2's weight was a proxy from the
  equal HACRP weighting, which gives PSI 90 and SSI the same 1/6. It moves
  across unchanged.
- **Four uncertainty sources drawn:** Rashomon specification (194 members),
  parameters, PSI-90 reliability (θ ~ N(psi90, vᵢ)), and model residual for
  predictive draws. Structural assumptions run as a scenario grid outside the
  draws, as CASH2 ran them.
- **Regressivity = a concentration index** of marginal and unearned bonus
  dollars, ranked by headroom and by model-implied disadvantage. Rank-based, so
  no benchmark PSI-90 is invented.
- **Strata along the gradient:** 3.16's nine cells labelled as cells, the
  safety-net flag, and quintiles of the model-implied Block B contribution
  (ADI second, since 3.14 found its reliance mostly on loan).
- **Seed 20260924**, and B doubled from 250 until MCSE < 5% of each headline
  output's SD across draws.

## 2. The calibration protocol

Two checks, in order, before any Q-HIP draw:

- **C1, a gate.** Observed inputs + HACRP rule must reproduce all 719
  penalised / 2,293 not, from the file's W-Z scores and again from raw measure
  values. Mismatches are explained by a documented exclusion or the run stops.
- **C2, reported.** Replace PSI-90 with the Phase 3 predictive draw on the
  published scale, apply HACRP, and score p̂ᵢ against the observed set:
  calibration in the large (±10%), decile slope (0.8–1.2), AUC, 90% PSI-90
  coverage, all by λ quartile and without the re-shrink step. Nothing is
  adjusted after C2 is seen.

The distinction is stated in the document's §5.1 table: HACRP is a Medicare
all-or-nothing 1% penalty on the worst quartile, Q-HIP a commercial,
upside-only, continuous 0.1–4% bonus. The check validates the shared machinery
upstream of the payment rule. It does not validate Q-HIP.

## 3. What inspecting the HACRP file showed

Structure only. No agreement statistic was computed.

- Total HAC Score = mean of available W-Z scores, to 8 × 10⁻⁵.
- The penalty cut is the 75th percentile of the 2,929 scored hospitals:
  lowest penalised 0.3799, highest unpenalised 0.3792, q75 0.3792.
- In the 2,801 frame: 664 penalised, 2,097 not, 40 N/A.

## 4. Things found while designing, carried to 4.2–4.4

1. **CASH2's concave and convex shapes (Table C4) cannot move a rank-based
   regressivity measure.** They multiply every hospital's slope by the same
   factor. They move levels only. Say so in §8 rather than letting the
   scenario grid imply otherwise.
2. **CASH2 Table 3's "75% of hospitals earn a bonus" implies a bottom-quartile
   zero,** a mirror image of HACRP's worst-quartile penalty. It is the only
   sourced shape that varies by position, so it is the scenario to watch.
3. **The regressivity result does not depend on eligibility (P6); the dollar
   amounts do.** A uniform eligible fraction scales dollars and leaves ranks
   alone. Every dollar figure is a national what-if, since Q-HIP participation
   is not identifiable by hospital.
4. **HAI scores are held at observed values,** so the simulated spread is a
   lower bound.
5. **The disadvantage-associated payment will straddle zero,** because the
   Rashomon set's disadvantage contrast does (3.10). Report it that way.

## 5. Open for Carl

Neither blocks 4.2; the document takes the first option.

1. Commercial share: CASH2's flat 37% / 0.40 (base) or a per-hospital share
   from raw HCRIS S-3 days (better, but a new derived parameter).
2. Scorecard: six HACRP measures (base) with PSI-90-only as the bracket, or the
   reverse.
