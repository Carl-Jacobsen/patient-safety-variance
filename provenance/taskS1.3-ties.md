# Task S1.3 — Make the counterfactual rank agree with the actual rank

**Date:** 2026-10-02 · **Budget:** 1.5 h · **Status: done. `pos_cf()` now uses
`pos_of()`'s average-rank convention. The identity test passes and fails on the
old code.** Counted over all 32,000 stored draws, the tie error is negligible
in every reported scenario and material only in the PSI-90-only scenario,
which the report does not cite. Stage 35 has not been rerun; S1.6 does that.

---

## 1. The defect

`pos_of()` ranks each hospital's score with ties averaged. `pos_cf()` placed
the counterfactual score `Scf_i` among the other hospitals' actual scores by
counting only those strictly below it, a minimum-rank convention. Where
`Scf_i` ties with other hospitals' scores, the two disagree by half the size of
the tie, and an unchanged score did not get its own position back. The ties are
real: every hospital clamped at a winsorization bound shares its standardized
score with the 5% clamped beside it. Where the score blends in the infection
measures, those mostly break the tie, so the error concentrates in hospitals
scored on PSI-90 alone.

The direction is always the same. The old convention gave the counterfactual a
better position than the actual one, so it **understated** the
disadvantage-associated amount (`Dis`).

## 2. The repair

`pos_cf(S, Scf)` = 1 − (others strictly below + 1 + ½ · others tied) / n. The
old version is kept as `pos_cf_sep30()` only for the test.

## 3. Identity test (stage 35, runs every time, before any draw)

A counterfactual equal to the actual score must give a payment difference of
exactly 0 for every hospital. The test vector is the Q-HIP frame's published
PSI-90 with every 7th hospital set to the median: 368 tied at the median, with
infection measures and without, plus 129 clamped at each winsorization bound.

| Rate | Repaired | September 30 |
|---|---|---|
| linear (base) | 0 nonzero | 29 nonzero, max $5,568 |
| threshold | 0 nonzero | 27 nonzero, max $7,424 |
| linear, PSI-90 only | 0 nonzero | 628 nonzero, max $3,189,598 |

The stage stops if the repaired function leaves any nonzero difference, or if
the old function passes. A hand case is also checked: S = (1, 2, 2, 2, 3) must
return average ranks 1, 3, 3, 3, 5 through both functions, and the old one must
not.

## 4. What the old convention misassigned in the stored draws

Ran `tools/s1.3-tie-count.R` (log `output/tables/taskS1.3-ties.txt`; tables
`payment-ties-count.csv` and `payment-ties-strata.csv`). It replays every stored
draw from its seed with the old convention, and **all 16,000 primary and 16,000
metropolitan draws reproduce the stored rows exactly.** For every scenario call
it also computes the counterfactual payment under the repaired convention.
Each pool took about 28 min; the results are cached in
`data/tie-count-<pool>.rds`.

Per draw, primary pool (metro within 3%):

| Scenario | Hospitals moved, mean (max) | Dollars, mean | Largest single hospital | Share of the scenario's Dis total |
|---|---|---|---|---|
| base, w10, w20, concave, convex, CASH2 variants | 1.5–1.7 (≤ 13) | $0.6K–$2.0K | ≤ $6,873 | ≤ 0.002% |
| threshold | 1.6 (11) | $1.9K | $6,554 | 0.002% |
| fixed reliability | 1.9 (7) | $0.7K | $911 | 0.0007% |
| **PSI-90 only** | **268 (345)** | **$44.5M** | **$2.47M** | **17.3%** |

The moved dollars all carry the same sign (net = absolute), as sec 1 says.

**Task 4.3's catchment-associated amounts**, base run, primary pool: the ties
move the per-hospital mean by **at most $1.53** in any stratum. ADI quintile 1
goes from $167,982.9 to $167,983.5, and quintile 5 from −$29,342.7 to
−$29,342.6. The +$167K to −$29K finding is not changed by this defect. The
amounts are still marked superseded in the 4.3 note, as the task requires,
because S1.6 regenerates them with the rest of the payment stage.

**PSI-90 only.** That scenario's `dis_total` is understated by about 17%.
`R/11-regressivity.R` reports the scenario's concentration indices, which do
not use `Dis`. Its `dis_total` appears only in `payment-scenarios.csv` and is
not cited in the report.

## 5. Not done here

- Stage 35 has not been rerun. Its cached `payment-sim.rds` is stale against
  the new code and is regenerated in S1.6, after S1.4 and S1.5.
- The concave and convex rows in sec 4 equal the base row because `k` never
  reaches the rate. That is S1.5's defect; it is noted here only because it
  shows in the table.
