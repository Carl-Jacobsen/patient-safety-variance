# Task S3.2 — Extend the suppression sensitivity

**Date:** 2026-10-05 · **Budget:** 2.5 h · **Status: done. Stage 44,
post-review.** Filling the suppressed Service Area File cells barely changes
the fit, and the sign of the disadvantage contrast is the same at each grain
under every fill. Which hospitals rank where on their community contribution
moves a good deal, though, and the movement is largest among the hospitals
whose catchments rest on the fewest observed discharges.
- **Fit.** Loss changes by at most 0.15%.
- **Contrast.** It moves by at most 0.08 SD of PSI-90, against a standard
  error of about 0.19.
- **Ranks.** Rank correlation with the as-built ranks is 0.92 to 1.00 over all
  frame hospitals and 0.84 to 0.98 in the low-weight decile. One hospital in
  that decile moves 1,696 of 2,569 places.

Phase 0's reassurance ("r ≥ 0.986", made on covariates) holds for the
covariates and the headline quantities. It does not hold for individual
hospitals' standing. This is a sensitivity check over five allocation rules,
not a bound.

---

## 1. What ran

`R/18-suppression.R`, registered as stage 44 before stage 39 (about 11 min;
seeded; a second run through make.R reproduced the preregistered rows
byte for byte). Output: `output/tables/suppression-sensitivity.csv` (168 rows)
and the log `taskS3.2-suppression.txt`.

- **Allocations, as preregistered (sec 7):**
  - Each of the 996,700 suppressed cells (87.46% of 1,139,665) is set to 1, 3,
    5.5 and 10 discharges.
  - Then 20 draws of a uniform integer on 1–10 per cell, with seed 20261001 + draw.
  - Every suppressed cell in the file is filled, so market concentration (HHI,
    built from all providers' cells) is rebuilt as well as the catchment
    weights.
  - Which hospitals are catchment-weighted (2,506 in the frame) and which take
    the county fallback (63) is left as built, because gate B0 is defined on
    observed cells.
- **Both grains.** The fills are applied to spec 382 (P-best, county-grain
  catchment) and spec 344 (its tract-grain sibling). Everything except
  Block B is identical to the stored fits.
- **Measured on what the report reads:**
  - in-sample loss on the 2,569-hospital frame;
  - the joint p10 → p90 contrast;
  - each hospital's rank on its community contribution (the fitted Block B part
    of its prediction, market concentration included).

  Covariate correlations with the as-built values are kept for continuity
  with Phase 0.
- **The low-weight decile.** The rule was fixed before any filled output
  existed: the bottom decile of catchment-weighted frame hospitals by mapped
  discharges (observed discharges on placeable ZIPs, `obs_cases ×
  zip_matched_share`). That is 251 hospitals with at most 534 mapped
  discharges, and a median of 88.3% of their cells are suppressed (85.7%
  across all catchment-weighted hospitals). Fallback hospitals are reported
  as a third group.

**Checks, before any fill.**
1. Observed cells only, the vectorised builder reproduces
   `catchment-weights.rds` exactly: 705,043 rows, the same pairs, difference 0.
2. All 20 catchment columns of the ten measures and `hhi_zip` match
   `analytic-v2.rds` to under 1e-10, with the same missing values.
3. Specs 382 and 344 reproduce their stored joint contrasts (to 1e-8) and
   losses (to 1e-10).

## 2. Results, preregistered allocations

Changes are against the as-built fit (county joint −0.215, tract +0.130).
Rank changes are in places out of 2,569.

| Fill | Grain | Loss | Joint (change) | Rank ρ, all | ρ, low decile | Median / p90 / max rank change, low decile | Min covariate r |
|---|---|---|---|---|---|---|---|
| 1 | county | −0.07% | −0.216 (−0.002) | 0.995 | 0.974 | 58 / 208 / 903 | 0.998 |
| | tract | +0.04% | +0.139 (+0.009) | 0.996 | 0.982 | 53 / 186 / 766 | 0.998 |
| 3 | county | −0.09% | −0.227 (−0.013) | 0.980 | 0.921 | 125 / 415 / 1,543 | 0.990 |
| | tract | +0.09% | +0.162 (+0.032) | 0.986 | 0.946 | 116 / 331 / 872 | 0.990 |
| 5.5 | county | −0.03% | −0.203 (+0.012) | 0.959 | 0.881 | 159 / 537 / 1,573 | 0.979 |
| | tract | +0.12% | +0.186 (+0.056) | 0.972 | 0.915 | 161 / 429 / 1,034 | 0.978 |
| 10 | county | +0.12% | −0.171 (+0.044) | 0.924 | 0.840 | 221 / 648 / 1,696 | 0.957 |
| | tract | +0.13% | +0.211 (+0.081) | 0.950 | 0.878 | 206 / 560 / 1,140 | 0.956 |
| uniform 1–10, 20 draws (median) | county | −0.05% | −0.206 (+0.009) | 0.959 | 0.880 | max 1,578 (largest draw 1,624) | |
| | tract | +0.11% | +0.178 (+0.048) | 0.971 | 0.912 | max 1,034 (largest draw 1,140) | |

Over all frame hospitals the median rank change is 27–147 places. In the low
decile it is about double that. The low decile's largest change equals the
largest anywhere (1,696 at county grain, 1,140 at tract grain, both at a fill
of 10), so the biggest moves happen among the hospitals with the least
observed data.

## 3. Reading

- **The fit and the headline contrast hold up.**
  - Loss moves by less than 0.2% under every allocation.
  - The joint contrast keeps its sign at each grain under every fill. The
    county-minus-tract split survives too: the gap is 0.355 SD at a fill of 1
    and 0.381 SD at a fill of 10, against 0.344 as built.
  - The largest change (+0.08 SD, tract grain, fill 10) is well inside the
    contrast's own standard error of about 0.19.
  - The tract-grain contrast grows as the fill grows, steadily rather than at
    random, so it would grow further if suppressed cells were larger than 10.
    The suppression threshold caps them at 10.
- **Hospital ranks are not robust.** At a fill of 3, the Phase 0 working
  constant, the covariates correlate at 0.990 or above with their as-built
  values, consistent with Phase 0's 0.986. Even so, a hospital in the low
  decile moves 1,543 places at county grain. Small covariate changes reorder a
  contribution that is densely bunched near its middle, and they change the
  fitted coefficients too, so even fallback hospitals, whose disadvantage
  values cannot change, move (up to 1,330 places).
- **The draws look like the constant at their mean.** The uniform draws
  (mean 5.5) sit close to the 5.5 row and vary little between draws. What
  matters is the average size of the suppressed cells, not how sizes scatter
  across cells.
- **Which inputs move most.**
  - The weakest disadvantage covariate is primary-care density at county grain
    and SVI 4 at tract grain (lowest r 0.956).
  - Market concentration moves much more: r with as built is 0.97 at a fill of
    1 and 0.75 at a fill of 10. The draft already says suppression overstates
    concentration (sec 9).

## 4. Supplementary, added after section 2 was seen: market concentration held as built

HHI moved so much that I reran the four constants with HHI kept as built, to
see how much of the rank movement it carries. This is post hoc and labelled so
in the table (`allocation = "constant k, HHI as built"`).

| Fill | Grain | Rank ρ, all: HHI rebuilt → as built | Joint change: rebuilt → as built |
|---|---|---|---|
| 3 | county | 0.980 → 0.984 | −0.013 → −0.051 |
| | tract | 0.986 → 0.991 | +0.032 → +0.001 |
| 10 | county | 0.924 → 0.936 | +0.044 → −0.005 |
| | tract | 0.950 → 0.963 | +0.081 → +0.043 |

Holding HHI fixed removes only a small part of the rank movement, so most of
it comes from the ten disadvantage measures and the refitted coefficients. In
the joint contrast the two partly offset each other: with HHI held, the
county contrast moves the other way at a fill of 3. Neither version comes
near the contrast's standard error.

## 5. What the draft says, and the replacement

Draft, section 9: "The measured cost is small: filling each suppressed cell at
a realistic size changes the catchment-weighted SVI themes very little (r ≥
0.986 on all four) … That test was run at county grain on 2,730 hospitals, and
suppression was not tested separately at tract grain."

For S5:

> CMS suppresses every Service Area File cell with fewer than 11 discharges,
> 87.46% of cells, and the catchment weights are computed over the observed
> cells. As a sensitivity check, every suppressed cell was filled at 1, 3, 5.5
> and 10 discharges, and at random sizes from 1 to 10, at both catchment
> grains. Under every fill the model's fit changed by less than 0.2%, and the
> disadvantage contrast kept its sign at each grain, moving by at most 0.08
> standard deviations of PSI-90, well within its own uncertainty. Individual
> hospitals' standing on the fitted community contribution was less stable.
> Its rank correlation with the as-built ranks fell to 0.92 at the largest
> fill, and among the tenth of hospitals with the fewest observed discharges
> to 0.84, where one hospital moved 1,696 places out of 2,569. Conclusions
> about the population hold up under suppression; a hospital-level reading
> of the community contribution, especially for small hospitals, does not.
> These checks span a range of assumed cell sizes; they do not bound the
> effect of suppression, since the true sizes are unknown and could vary with
> disadvantage in ways no single fill represents.

`10-actions.md`'s recommendation of a finer patient-origin file gains a second
reason: hospital-level community contributions.

## 6. Stage 39

The suppression numbers are registered in section 09 only (`ss <allocation>
<grain> <group> <quantity>`, plus `ss uniform median|extreme …`), with the
loss and contrast once per allocation and grain. The first, wider registration
(both sections, every group) let an unrelated Sep 30 token in section 3
("+0.07", a market-concentration SMD) match a suppression loss change. The
narrower version restores the unregistered counts to exactly their state after
S3.1 (2 / 3 / 6 / 19 / 0 / 8 / 2 / 4 / 2). That is the same limit the 5.2 note
recorded: the registry shows that a number exists, not that it sits by the
right claim. Registry: 2,245 numbers.

## 7. Verify

- **Reported as a number.** The low-weight decile's largest rank change is
  1,696 places at county grain and 1,140 at tract grain, both at a fill of 10.
- **Wording.** The note and the replacement text call the result a
  sensitivity check. "Bound" appears only to say what it is not.

## 8. Not done

- **Disadvantage-correlated fills.** No fill varies with disadvantage. A
  suppressed cell is small partly because the ZIP is rural or the hospital is
  small, and both track disadvantage, so the realistic pattern is not uniform.
  A fill scaled by ZIP population or rurality would test it; it was not
  preregistered and is not run here.
- **Other grains.** Hospital-county and HSA grains do not use the Service Area
  File's cells for the measures (HSA is suppression-free; hospital-county is
  the hospital's own county), except through HHI.
- **Rank bootstrap.** No bootstrap of rank stability without suppression. Part
  of the rank movement reflects how imprecise individual community
  contributions are in any case. The comparison that would separate the two
  is a hospital bootstrap of the as-built ranks.
