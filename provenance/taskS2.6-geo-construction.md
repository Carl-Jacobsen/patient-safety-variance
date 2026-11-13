# Task S2.6 — Treat geography as a construction question

**Date:** 2026-10-04 · **Budget:** 3 h · **Status: done. Stage 42,
post-review.** Holding the measurement constant closes about half of the grain
disagreement. Rebuilt from estimate percentages, the SVI themes agree far
better across grains (theme 4's cross-grain correlation rises from 0.62 to
0.92), and their part of the gap all but vanishes. The joint contrast's
tract-minus-county gap falls from +0.344 to +0.187 SD, and the sign split
disappears (county −0.188, tract −0.001). What remains comes mostly from ICE
and the limited-English share. Both are the same quantity at both grains, so
their divergence is aggregation: which tracts are averaged, not what is
measured. Better patient-origin data would bear on that remainder. It would
not have resolved the half that was construction.

---

## 1. The selection rule, fixed before any rebuilt value was computed

The task asks to rebuild "the measures whose association changes most between
county and catchment grain". I took the comparison that carries the Sep 30
sign split, county-grain catchment (spec 382) against tract-grain catchment
(spec 344), and fixed the rule from how each measure is built (`R/blockB.R`),
not from its result:

| Measure | Tract grain | County grain | Same quantity? | Rebuilt? |
|---|---|---|---|---|
| SVI themes 1–4 | mean of tract percentile ranks (ranked among tracts) | mean of county percentile ranks (ranked among counties) | **no** | yes |
| Uninsured, limited English | tract estimate % | ACS county-table estimate % | yes, different source table | yes, county value made an exact aggregate of the tracts |
| ICE (≥$150k) | tract household counts | county sums of those counts | yes, exact aggregate | no |
| ADI | population-weighted block-group ranks over the tract | the same over the county | yes, exact aggregate | no |
| Rurality, primary-care density | county-native | county-native | identical at both | no |

Before writing the rule I had seen the per-measure contrasts by grain (sec 4,
original columns). The largest moves were ICE (+0.36) and limited English
(+0.26), which the rule does not rebuild because they are already comparable.
The rule follows the review's point (ranks defined over different units)
rather than the size of the move, and sec 4 reports every measure.

## 2. What ran

`R/16-geo-construction.R`, registered as stage 42 before stage 39 (about 45 s;
a second run is byte-identical). Output: `output/tables/geo-construction.csv`
and the log `taskS2.6-geo-construction.txt`. Stage 39 registers 312 numbers
from it in section 05 and copies them to 01 and 10 (keys
`gc <grain> <construction> <quantity> <measure>`).

- **The rebuild.**
  - Each SVI theme becomes the mean of its estimate percentages (EP_* in the
    SVI 2022 file: theme 1 POV150, UNEMP, HBURD, NOHSDP, UNINSUR; theme 2
    AGE65, AGE17, DISABL, SNGPNT, LIMENG; theme 3 MINRTY; theme 4 MUNIT,
    MOBILE, CROWD, NOVEH, GROUPQ).
  - Each estimate is standardized against one fixed reference, the
    population-weighted national distribution of tract values, at both grains.
  - A county's estimate is the E_TOTPOP-weighted mean of its tracts'
    estimates. That approximates each estimate's own denominator (households
    for HBURD and CROWD, for example) with total population.
  - Catchment weighting then follows `R/blockB.R` exactly: the CT tract-code
    remap, discharge weights summed to county for county grain, and fallback
    hospitals at their own county's value at both grains.
- **Check 1.** Fed the original inputs (RPL ranks, the county file's estimates),
  the weighting code reproduces all twelve original columns in
  `analytic-v2.rds` (six measures × two grains) to at most 7.8e-14, with
  identical missingness.
- **Check 2.** Specs 382 and 344 are reproduced (joint contrast to 1e-8) before
  anything is swapped.
- **Identical except aggregation.** All four fits ({county, tract} × {original,
  rebuilt}) use the same 2,569 hospitals, the same outcome values, the same 51
  terms, the same standardization and knot rule, and ordinary least squares.
  The stage asserts that every non-Block-B column is identical across the four
  frames. Within the rebuilt pair, the only difference between grains is
  whether the catchment's values are formed from its tracts or from the whole
  counties they sit in.

## 3. Cross-grain agreement of each measure (common sample)

| Measure | Original r(tract, county) | Rebuilt |
|---|---|---|
| SVI 1 | 0.852 | 0.866 |
| SVI 2 | 0.765 | 0.873 |
| SVI 3 | 0.929 | 0.946 |
| SVI 4 | 0.616 | **0.916** |
| uninsured | 0.949 | 0.949 |
| limited English | 0.910 | 0.909 |
| ADI, ICE (not rebuilt) | 0.978, 0.917 | the same |

## 4. Contrasts, SD of PSI-90

| | Original: county | tract | tract − county | Rebuilt: county | tract | tract − county |
|---|---|---|---|---|---|---|
| **Joint (all ten)** | −0.215 | +0.130 | **+0.344** | −0.188 | −0.001 | **+0.187** |
| material part | −0.135 | +0.117 | +0.252 | −0.122 | +0.053 | +0.175 |
| composition part | −0.294 | −0.150 | +0.144 | −0.249 | −0.194 | +0.055 |
| rurality + PCP part | +0.214 | +0.163 | −0.051 | +0.182 | +0.140 | −0.043 |
| SVI 1 | +0.007 | −0.048 | −0.055 | +0.023 | +0.024 | +0.001 |
| SVI 2 | +0.043 | −0.132 | −0.175 | +0.038 | −0.090 | −0.127 |
| SVI 3 | +0.150 | +0.207 | +0.056 | +0.199 | +0.151 | −0.048 |
| SVI 4 | +0.033 | −0.083 | −0.116 | +0.002 | −0.015 | −0.017 |
| ADI | +0.093 | +0.082 | −0.011 | +0.123 | +0.059 | −0.064 |
| ICE (≥$150k) | −0.043 | +0.317 | +0.359 | −0.033 | +0.200 | +0.233 |
| uninsured | −0.226 | −0.152 | +0.074 | −0.238 | −0.215 | +0.023 |
| limited English | −0.488 | −0.225 | +0.263 | −0.485 | −0.255 | +0.230 |

## 5. Reading

- **Half the disagreement was measurement.** With the SVI themes measured the
  same way at both grains, the joint gap falls by 46%, and the grain no longer
  flips the sign (county −0.19, tract −0.00). Themes 1 and 4, which carried
  much of the original gap, now agree across grains to within 0.02 SD.
- **The other half is aggregation, concentrated in ICE and limited English.**
  Both are built identically at both grains and still move by about 0.23 SD.
  A catchment's tracts and the whole counties it touches are different
  populations, and for those two measures the difference matters. This is the
  part a patient-origin file finer than the Service Area File could bear on.
- **The S2.5 material flip survives in smaller form.** The material part still
  changes sign (county −0.12, tract +0.05), now almost entirely through ICE.
- **Uncertainty.** Each fit's joint standard error is about 0.18–0.20 SD, and
  both the original gap (+0.34) and the rebuilt one (+0.19) are differences
  between two fits on the same hospitals. I did not compute a standard error
  for the gap or for its change, so neither is claimed to be different from
  zero. What is shown is that a fixed construction removes most of the SVI
  themes' divergence; whether the remaining gap is distinguishable from zero
  is not tested here.
- **The rebuilt themes are not the published SVI.** They are means of
  standardized estimates, not percentile ranks of summed percentile ranks. The
  comparison is valid because both grains use the same rebuilt measure. It
  does not say the rebuilt version should replace the published index in the
  primary analysis.

## 6. Action 10.3, recast

Draft: "every credible model that weights catchments at county grain estimates
a negative association, and every one that weights them at tract grain a
positive one. A patient-origin file finer than the Medicare Service Area File …
would help decide between them."

For S5, in the S2.3 forms:

> In the fitted members of the set, the direction of the disadvantage
> association depends on the grain at which catchments are weighted. Part of
> that dependence is a measurement artifact: the published SVI themes are
> percentile ranks among tracts at one grain and among counties at the other.
> When the themes are rebuilt from the same estimate percentages at both
> grains, the gap between the two grains' estimates falls by about half
> (+0.34 to +0.19 SD) and the sign no longer changes. The remainder comes
> mainly from the income-concentration index and the limited-English share,
> which are measured identically at both grains, so it reflects which
> communities a catchment is taken to contain. Better patient-origin data
> (finer than the Medicare Service Area File, of which 87.46% of cells are
> suppressed, and covering all payers, as the HCUP state inpatient databases
> do) would help with that remainder. It would not by itself establish that
> county and tract quantities estimate the same relationship. Rebuilding
> measures from comparable quantities at every grain is a prerequisite, and
> costs nothing in new data.

The reliability half of 10.3 ("the models that reverse CMS's smoothing") is
recast under S2.1 and S2.2.

## 7. Verify

Only the aggregation differs between the two grains: outcome, sample (2,569),
terms, standardization and knot rule, and estimator are identical across all
four fits, asserted in the stage. The two catchment grains of each rebuilt
measure are formed from one tract-level quantity by two aggregations.

## 8. Not done

- Hospital-county and HSA grains were not rebuilt; the comparison here is the
  one that carried the sign split. The same function would apply.
- No bootstrap of the gap (sec 5). If S5 wants to say the rebuilt gap is or is
  not distinguishable from zero, a paired bootstrap over hospitals (refitting
  both grains on each resample) is the test. It should run under 10 minutes
  with this design builder.
