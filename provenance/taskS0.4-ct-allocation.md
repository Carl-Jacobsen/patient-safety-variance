# Task S0.4 — Connecticut allocation and the fallback rule

**Date:** 2026-10-01 · **Budget:** 2 h · **Status: done. The repair changes the
frozen file, so by the preregistered rule the analysis moves to
`analytic-v2.rds` (amendment 1).** National results have not been recomputed
yet and this note makes no claim about them.

---

## 1. The two defects

`build_zcta_tract_alloc()` in `R/catchment.R` splits each ZCTA's discharges
across census tracts by population.

1. **Connecticut.** SVI 2022 keys Connecticut tracts by the 2022 planning
   regions (county codes 110–190); the 2020 ZCTA-to-tract relationship file uses
   the legacy counties (001–015). The two share none of their 879 and 883 tract
   IDs, so the population lookup failed for every Connecticut slice and each
   fell back to land area. `blockB.R` remapped the IDs afterwards, which joined
   the covariates correctly but could not restore the weights.
2. **Mixed units.** A slice without a population used its land area in square
   metres while the other slices of the same ZCTA used people, and the two were
   normalised together.

## 2. The repair

- The population lookup goes through the 6-digit tract suffix for Connecticut,
  which is unique within the state and the same in both vintages (the mapping
  `blockB.R` already verified, 879 of 879). The allocation keeps the 2020 IDs, so
  everything downstream joins as before.
- **One unit per ZCTA.** A ZCTA is population-weighted only if every slice with
  land has a population and a land fraction and the population total is
  positive; otherwise the whole ZCTA uses land area. Slices with no land never
  decide the unit.
- The allocation is now a pure function, `alloc_from_parts()`, and the stage
  14 self-test exercises it on a hand example. A mixed ZCTA falls back whole
  (shares 100/150 and 50/150), a no-land slice does not trigger the fallback,
  and a legacy Connecticut ID finds its population under the 2022 ID.

| | Before | After |
|---|---|---|
| ZCTAs population-weighted | 98.7% ("population-only") | 99.5% |
| ZCTAs on land area | 1.3% ("mixed"), people and square metres together | 0.5%, whole: 149 with a landed slice lacking population, 12 with zero population total |
| Connecticut ZCTAs population-weighted | 0 (every slice fell back) | 288 of 288 |

The 12 zero-population ZCTAs were dropped before the repair: their shares were
0/0, so their discharges could not be placed. They are now area-weighted. That
is a third consequence of the same rule, and it is counted in sec 3.

## 3. What moved

`Rscript tools/compare-analytic-versions.R` compares every numeric column for
every frame hospital, archived v1 against the rebuilt file, and writes
`output/tables/ct-allocation-check.csv`.

- **Covariates:** 38 hospitals. All **25 Connecticut** hospitals, by up to
  **0.71 SD** (SVI theme 4 at tract grain; SVI 2 0.65, SVI 1 0.53, ICE₁₅₀ 0.57,
  limited English 0.51), and **13 elsewhere**, by up to **0.067 SD** (SVI 4 at
  tract grain). The review's spot check of 24 ZCTAs found no realized
  mixed-unit distortion; the full comparison finds these 13, small but real.
- **Imputations:** contract labor's 20 completions changed for **157 of the 158
  imputed hospitals**. The imputation model uses Block B as predictors, and with
  those inputs changed the same seed draws a different chain. No observed value
  changed, and no non-numeric column changed.

## 4. The rule, applied

The preregistration (sec 7) adopts `analytic-v2` if any frame hospital's value
moves by more than 1e-8. The moves above are many orders of magnitude larger, so v2 is
adopted:

- amendment 1 in `provenance/amendments.md` (under rule 2, defect repairs);
- `R/freeze.R` now writes `data/analytic-v2.rds` and checks its own pin. A new
  version is pinned only with `FREEZE_PIN=1` after its amendment is written, and
  otherwise fails like any drift. Pinned, then re-run: "rebuilt file MATCHES the
  frozen hash";
- `provenance/analytic-v1.sha256` keeps the v1 lines and gains the v2 lines;
- every script and `make.R` now read `analytic-v2.rds`. Provenance notes keep
  their v1 references as history. The September 30 report text also still says
  v1; the S5 rewrite replaces it.

## 5. What this means for the national results

Every downstream stage must rerun on v2, and the cache keys force it. That
rerun (a release run, several hours unattended) is what shows whether any
reported number moves. Given that 25 Connecticut hospitals moved and the
imputations were redrawn, small changes are likely, but nothing here says
which. The S1 repairs are evaluated on v2.

## 6. Addendum: the v2 release rerun (2026-10-01, evening)

`make.R --release` on v2 ran stages 1–38 clean, recomputing every cache whose
key covers Block B (variance bootstrap, specification curve, Rashomon loss and
bootstrap, MCR, TIS, payment fits). The cluster-stability cache was reused
because its inputs (margin and PSI-90) do not touch Block B. Stage 39 then
stopped the release, as expected: the September 30 prose cites 35 numbers in
seven sections that v2 no longer produces. The S5 rewrite replaces that text.

The national results moved little. 23 of 76 archived tables are byte-identical.

| Quantity | v1 | v2 |
|---|---|---|
| Community share of variation, published score (OLS) | 3.34% | 3.32% |
| The same, reliability-weighted | 3.62% | 3.60% |
| Components model, community | 1.45% (−0.58% to 3.71%) | 1.44% (−0.60% to 3.67%) |
| Primary Rashomon set | 194 members | 194 members |
| Disadvantage contrast across the set | −0.370 to +0.879 SD | −0.370 to +0.858 SD |
| Disadvantage-group MCR⁻, primary / metro / state | 1.0848 / 1.0790 / 1.0000 | 1.0848 / 1.0790 / 1.0000 |
| HACRP calibration slope, lowest λ quartile | 1.2849 | 1.2872 |

The last row changes an S1.6 instruction. The task sheet asked for the review's
1.28 to be kept and the 4.2 note's 1.29 corrected; on v2 the slope rounds to
**1.29**, and the rewrite cites the v2 value. The TIS outputs regenerated on v2
still carry the wrapper defect that S1.1 repairs.
