# Task S7.3 — A published-score Rashomon set calibrated on its own; the all-improve reference

**Date:** 2026-10-12 · **Budget:** 1.5 h · **Status: done. Stages 27, 30 and
37, October 7 audit findings A2 and A6.** The published-score fits now have
their own best model and their own bootstrap tolerance. On them the reliance
lower bound holds at all three tolerances. The all-improve zero is tied to the
recalculated scoring reference, with the fixed-reference alternative computed
beside it.

---

## 1. A2: why a separate calibration

The October 7 report said the reliability approximation "bears on the
sensitivity analyses only, since every primary result uses the published score
unweighted." That was false. The primary Rashomon set (194 models) holds 88
errors-in-variables, 41 weighted and 65 unweighted fits, and its best fit
(spec 418) and its tolerance both come through the mixed registry. The 65
"published-score" models were a restriction of that set, not a set of their
own. The audit offered two remedies: calibrate the unweighted fits separately,
or describe the mixed analysis honestly. This task does the first, and S7.4
does the second as well.

## 2. What ran

`R/05-rashomon.R` sec 6b (stage 27), added after the audit and labeled post
hoc. Among the 184 composite specifications at the `unweighted` reliability
level, the ERM is **spec 382** (loss 0.032559, 2.12% above the full registry's
best). It is refitted on B = 1,000 resamples at each unit by the same
procedure and alpha as the pre-registered tolerance (seeds 20260940–42), cached
in `data/rashomon-boot-published.rds` under its own key, so the existing draws
are untouched. Output `output/tables/rashomon-tolerance-published.csv`;
`data/rashomon-tolerance.rds` gains `$published`. About 2.5 min.

| Unit | ε (% of L(382)) | MCSE | Members of 184 |
|---|---|---|---|
| hospital | 2.91% | 0.064% | 105 |
| metro area | 3.50% | 0.054% | 133 |
| state | 6.16% | 0.193% | 176 |

`R/06-mcr-run.R` (stage 30) adds `members = "published"` rows to
`rashomon-published-subset.csv` from the cached per-model reliance (no refit
of reliance; the cache key covers the whole runner, so stage 30 recomputed it,
about 4 min, identically). The stage checks that the member count and ERM
match stage 27's.

| Set | n | MCR⁻ | MCR⁺ | Contrast range (SD) | Share positive |
|---|---|---|---|---|---|
| Main, hospital | 194 | 1.0848 | 1.2300 | −0.370 to +0.858 | 57% |
| Main ∩ unweighted, hospital | 65 | 1.0848 | 1.1491 | −0.227 to +0.182 | 55% |
| **Published, hospital** | **105** | **1.0790** | 1.1491 | −0.227 to +0.347 | 71% |
| Published, metro | 133 | 1.0626 | 1.1491 | −0.227 to +0.367 | 77% |
| Published, state | 176 | 1.0476 | 1.1491 | −0.227 to +0.367 | 83% |
| Main, state | 536 | 1.0000 | 1.2300 | −0.370 to +0.952 | 84% |

**Reading.** On the published score alone the reliance bound holds at all
three tolerances, because the published set's state tolerance (6.2%) admits no
Block-A-only fit, while the main set's (9.3%) does. The contrast range is
narrower at the bottom (no fit below −0.23) and still straddles zero, so the
direction finding stands. The published set is reported beside the main set
wherever reliance or direction is stated (S7.4).

## 3. A2, payment: the fixed-score run brought forward

No rerun was needed: stage 35 already writes a fixed run (every published
score at its value). The report now gives it beside the base run's
repeated-measurement draw, whose conditional mean is μ + λᵢ(θ̂ᵢ − μ), not θ̂ᵢ:

| Quantity | Fixed | Base (score draws) |
|---|---|---|
| ADI concentration of return per NPR | −0.035 (no modeled variation) | −0.058 (−0.073 to −0.044) |
| Safety-net ratio | 0.64 | 0.62 (0.59 to 0.65) |
| Model-implied disadvantage | −0.017 (−0.064 to +0.021), no clear direction | −0.038 (−0.085 to −0.0004), on the edge |

The ADI and safety-net intervals in the base run reflect the score draw alone.

## 4. A6: the all-improve reference

`R/11-regressivity.R` sec 3b (stage 37) reruns the all-improve shift at the
published scores with stage 35's own `score_of`, `pos_of` and `rate_of` (parsed
from `R/09-payment-sim.R`), after checking that it reproduces stage 35's
fixed-score payments to a cent. Output `output/tables/all-improve-reference.csv`.

| Scoring reference | Total payment change | Positions changed |
|---|---|---|
| recalculated (stage 35) | $0 | 0 of 2,569 |
| fixed at original | −$56.53M | 2,384 of 2,569 |

The zero is a property of a common additive shift with the winsorization
bounds, mean and SD recalculated and revenues fixed. Held at the original
reference, clipping at the bounds and the 60 hospitals scored on PSI-90 alone
break the symmetry. Regressivity statement item 6 now says so. This matches the
audit's independent reproduction.

## 5. Time

About 1.5 h.
