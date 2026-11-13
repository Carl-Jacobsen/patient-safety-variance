# Task S2.5 — Check the support of the joint disadvantage contrast

**Date:** 2026-10-04 · **Budget:** 2.5 h · **Status: done. Stage 41,
post-review.** The joint 10th-to-90th-percentile profile is on support at every
grain under the pre-registered rule: 12–34% of observed catchments sit at least
as far from the center. So the rule does not require replacing it. The
decomposition shows why its sign moves between grains. Composition always
pulls it down, rurality and primary-care density always push it up, and the
material-deprivation part changes sign with the grain. Averaged over observed
catchments, materially deprived catchments go with higher (worse) PSI-90 at
every grain, and catchments high on the composition score with lower PSI-90.
A first draft of this stage scored three of the four grains with the wrong
model; sec 5 records how the check caught it.

---

## 1. What ran

`R/15-contrast-support.R`, registered in `make.R` as stage 41 and listed before
stage 39 (about 10 s; a second run is byte-identical). Output:
`output/tables/contrast-support.csv` (52 rows: four grains × six support rows
and seven contrasts) and the log `taskS2.5-contrast-support.txt`. Stage 39
registers 188 numbers from it in section 05 (keys `cs <grain> <quantity> …`).

- **Models.** P-best (spec 382, catch_county) and its three grain siblings with
  identical settings: 344 (catch_tract), 420 (hospital county) and 458 (HSA).
  All four are members of the primary set. Each is refitted with the
  harness's frame-wide standardization and knots. The stage stops unless each
  reproduces its stored joint contrast and standard error to 1e-8 (all four
  do), and unless each grain's contrast function still reproduces its own
  estimate after all four are built (sec 5).
- **Groups** (pre-registration sec 7): material deprivation = ADI, ICE, SVI 1,
  SVI 4, uninsured share; composition = SVI 2, SVI 3, limited-English share;
  rurality and primary-care density apart. A group's score is the mean of its
  measures, standardized on the frame and signed by `DIS_SIGN`.
- **Support.** Mahalanobis distance over the ten measures on each grain's model
  frame (n = 2,569; 2,605 at HSA), plus the distance to the nearest observed
  catchment. That second distance is compared with the observed catchments' own
  nearest-neighbor distances, taken over distinct profiles, since many
  hospitals share a county or HSA profile.
- **Contrasts**, all in SD of PSI-90, Block A and C at the reference, as the
  harness holds them: the joint synthetic move; the material-only and
  composition-only synthetic moves (the other measures at the center); the
  pre-registered observed contrast (the median catchment of the top decile of a
  score against the median catchment of its bottom decile, all ten measures at
  those two catchments' values); and a supplementary decile-mean contrast that
  averages the same move over every catchment in the two deciles. Every
  contrast is split exactly into the parts carried by material, composition and
  the other two measures, which the model's additivity makes possible.

## 2. Support

| Grain | Profile end | Mahalanobis | Observed catchments as far | Nearest observed (obs. NN median, p95) | Observed as isolated |
|---|---|---|---|---|---|
| catch_county | least deprived | 3.64 | 18.0% | 1.71 (0.78, 2.12) | 13.2% |
| catch_county | most deprived | 3.91 | 13.0% | 1.42 | 23.0% |
| catch_tract | least | 3.33 | 27.8% | 1.65 (1.18, 2.32) | 18.0% |
| catch_tract | most | 3.72 | 18.0% | 1.91 | 10.2% |
| hosp_county | least | 3.48 | 22.4% | 1.72 (1.60, 2.46) | 36.2% |
| hosp_county | most | 3.93 | 12.3% | 1.00 | 96.6% |
| hsa | least | 3.25 | 34.3% | 1.62 (1.57, 2.58) | 43.9% |
| hsa | most | 3.80 | 18.8% | 1.78 | 30.9% |

**Under the pre-registered rule** (an observed contrast wherever fewer than 5%
of catchments are as far out), the joint profile stays at every grain. In ten
dimensions a distance near 3.6 is typical: under a multivariate normal about
12–20% of points lie farther. The largest observed distances run from 10.6 to
18.7. Neither end of the profile is farther from an observed catchment than the
95th percentile of the distances between observed catchments themselves.

**The group-only profiles are worse supported than the joint one.** Moving the
material measures to their 90th percentile while holding composition and
rurality at the center gives a profile whose nearest observed catchment, at
county-catchment grain, is farther away than all but 3–5% of observed
catchments are from theirs. Deprived catchments differ on composition and
rurality too, so a material-only move describes few real places. That is why
sec 3 leads with the observed decile contrasts for the group results.

## 3. Contrasts

The joint synthetic contrast and its exact parts (SD of PSI-90):

| Grain | Joint (se) | Material part | Composition part | Rurality + PCP part |
|---|---|---|---|---|
| catch_county (382) | −0.215 (0.202) | −0.135 | −0.294 | +0.214 |
| catch_tract (344) | +0.130 (0.189) | +0.117 | −0.150 | +0.163 |
| hosp_county (420) | −0.044 (0.194) | −0.040 | −0.241 | +0.238 |
| hsa (458) | +0.090 (0.178) | +0.024 | −0.162 | +0.228 |

Observed contrasts, top against bottom decile of each score:

| Grain | Material: decile means (se) [material / composition / other] | Composition: decile means (se) [material / composition / other] | Pre-registered median-catchment contrasts: material, composition |
|---|---|---|---|
| catch_county | +0.233 (0.096) [−0.065 / +0.159 / +0.139] | −0.441 (0.105) [−0.068 / −0.302 / −0.070] | +0.270 (0.198), −0.544 (0.206) |
| catch_tract | +0.255 (0.100) [+0.238 / −0.087 / +0.104] | −0.378 (0.103) [−0.094 / −0.243 / −0.041] | −0.345 (0.242), −0.039 (0.189) |
| hosp_county | +0.211 (0.093) [−0.004 / +0.087 / +0.129] | −0.398 (0.103) [−0.083 / −0.241 / −0.074] | +0.288 (0.214), +0.102 (0.198) |
| hsa | +0.205 (0.091) [+0.065 / −0.015 / +0.155] | −0.466 (0.096) [−0.209 / −0.209 / −0.048] | +0.320 (0.146), −0.176 (0.193) |

## 4. Reading

- **The grain disagreement sits in the material measures.** In all four models
  the composition part of the joint move is negative (−0.15 to −0.29) and the
  rurality and primary-care part positive (+0.16 to +0.24). Only the material
  part changes sign: positive at tract and HSA grain, negative at the two
  county grains. The Sep 30 reading, that the set's members disagree about the
  direction and the disagreement follows the grain, is correct. The
  disagreement belongs to the material terms, not to the profile as a whole,
  and S2.6 is where it is tested.
- **The observed contrasts agree across grains, where the synthetic ones do
  not.** Averaged over observed catchments, the top decile of material
  deprivation goes with PSI-90 higher by 0.21 to 0.26 SD at every grain, each
  about 2.2 to 2.6 standard errors from zero. The top decile of composition goes
  with PSI-90 lower by 0.38 to 0.47 SD, each about 3.7 to 4.9 standard errors
  from zero. The composition of each observed contrast differs by grain: at the
  county grains the material contrast is carried by the composition and
  rurality terms that come with deprived catchments, and at tract grain by the
  material terms themselves. These are contrasts conditional on Block A and C
  at the reference and on one model per grain; they are not the set's range.
- **The pre-registered median-catchment contrasts are unstable.** Each rests on
  two hospitals, their standard errors run 0.15 to 0.24, and their signs change
  between grains. They are reported as pre-registered, but the decile-mean
  version, labeled supplementary, is the readable one. S5 should say that this
  choice was made after seeing both.
- **The negative composition contrast is not a protective effect.** As the
  review warns, a lower PSI-90 where composition scores are high is an
  association conditional on hospital structure and the other measures. It is
  not a statement about patients from those communities.

**For the rewrite.** The rule does not force an observed contrast. S5 should
still report the joint contrast together with its three parts, and lead the
group results with the observed decile contrasts rather than the
material-only or composition-only synthetic moves, which sit farther from
observed catchments than the joint profile does.

## 5. A defect caught in development

In the first draft, the per-grain model fits were built in a bare top-level
loop, and each grain's contrast function was a closure over that loop's
variables. All four closures therefore saw the last grain's coefficients (the
HSA fit). The joint contrasts were computed inside the loop and were right;
every later contrast at the other three grains used the HSA model. The exact
part decomposition exposed it: the material part of the joint move differed
from the material-only move (−0.135 against +0.029 at county grain), which an
additive model cannot produce. The fix builds each grain inside its own
function call. A new check now calls each stored contrast function after all
four exist and stops unless it reproduces its own grain's joint estimate. The
HSA rows did not change, which is consistent with the cause. No output of the
defective draft was committed or cited.

## 6. Verify

- **Share of observed catchments at least as far from the center as the
  synthetic profile:** 12.3% to 34.3% across the four grains and both ends (sec
  2), all at or above 5%, so the rule does not force an observed contrast.
  S5 can follow sec 4's recommendation anyway.
- **Material and composition contrasted separately,** synthetic and observed,
  at all four grains, with exact parts.
