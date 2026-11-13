# Task 3.1 — Exploratory pass on the frozen file

**Date:** 2026-09-01 · **Budget:** 4 h · **Status: complete. Phase 3 opens.**
One stage (`make.R` 20, `R/03-eda.R`) reading `data/analytic-v1.rds` and nothing
else. Distributions of every outcome and continuous covariate, within- and
cross-block correlation, the Block B collinearity that motivates the TIS
decomposition, and the geographic patterning of PSI-90.

Outputs: `output/figures/eda-*.png` (9), `output/tables/blockB-correlation.csv`
(+ `-spearman`), `output/tables/eda-*.csv` (8), and this reading. No `data/`
output — Task 3.1 is diagnostic, it builds nothing the model reads. No
`sources.csv` change.

**Headline:** the eight-measure disadvantage set the report leans on is
genuinely collinear — pairwise |r| to 0.83, three VIFs above 5, correlation-
matrix determinant 0.002, two principal components carrying 73% of its
variance. Marginal permutation importance would divide the shared variance
between these measures arbitrarily. **That is the empirical case for TIS
(Tasks 3.13–3.14) and MCR (3.11–3.12), and it is now on disk.**

**Working-set decision (Task 3.1 follow-up, settled here):** Block B carries
two exact-duplicate pairs — `adi`~`adi2020` r = 0.99, `ice150`~`ice` r = 0.99
— that identify nothing when both are in a model (full-block VIF 64–87).
**Keep `adi` (2024 vintage) and `ice150`; `adi2020` and `ice` are demoted to
Task 3.4 robustness swaps and never enter a model alongside their partner.**
The 11-measure working block (`R/03-eda.R` `bB_primary`) is what
`eda-blockB-collinearity.csv` and the PCA below now report.

---

## 1. Distributions — functional form is a live Task 3.4 axis

`output/tables/eda-distributions.csv` — 37 measures, each with n, moments,
skew, excess kurtosis, zero share, and a functional-form note.

**PSI-90 is right-skewed** (skew +2.75, excess kurtosis +17.1; min 0.40,
median 0.96, max 3.16, no zeros). A log transform pulls the skew to +1.05.
The components are worse (`psi03` skew +5.0). Whether the baseline model and
the spec curve enter the outcome raw or logged is a Task 3.4 enumerated
choice, not settled here.

**20 of 37 measures have |skew| > 1**, among them every count-like Block A
covariate (`beds` +3.1, `volume` +2.8, `adc` +3.4), `operating_margin`
(−5.1, heavy left tail from a few large losses), `uncomp_care_pct` (+9.0),
and the Block B rates `uninsured` (+1.4), `limeng` (+2.7), `rurality` (+1.2).
Two are zero-inflated and need a spline or signed transform rather than a
log: `resident_to_bed` (teaching intensity, 0 for non-teaching hospitals) and
`tort_cap_total`. The **SVI themes, ADI, and ICE are all near-symmetric** —
they are already percentile or index scales.

Figures: `eda-outcome-distribution.png` (PSI-90 raw and logged, CI width vs
point estimate, and the shrinkage signature — low-λᵢ hospitals compressed
toward 1.0), `eda-covariate-distributions.png` (12-panel grid).

---

## 2. Within-block correlation

| block | measures | median \|r\| | max \|r\| | pairs \|r\| ≥ 0.6 |
|---|---|---|---|---|
| A (structure) | 11 | 0.19 | 0.98 | `beds`~`adc` 0.98, `beds`~`volume` 0.85, `adc`~`volume` 0.87 |
| B (context) | 13 | 0.37 | 0.99 | 11 |
| C (policy) | 5 | 0.03 | 0.15 | 0 |

Block A's collinearity is the expected size cluster (beds / ADC / Medicare
volume are one latent "how big is this hospital"). Block C is effectively
orthogonal — tort context does not move with coding intensity or staffing,
consistent with its "context only, never a driver" status (`admission-gates.md`
C3, Task 2.7).

**Block B** is the one that matters. `output/tables/blockB-correlation.csv`
is the deliverable (Pearson, all 13 measures; `-spearman.csv` alongside). The
block carries **redundant vintages and variants**: `adi`~`adi2020` r = 0.99,
`ice`~`ice150` r = 0.99 — resolved below (**keep `adi` + `ice150`**).
Setting those aside, the substantive cross-construct correlations are still
large: `adi`~`ice150` −0.83, `svi_ses`~`svi_household` 0.76, `svi_ses`~`ice`
−0.68, `svi_minority`~`limeng` 0.68, `svi_ses`~`uninsured` 0.67,
`adi`~`rurality` 0.59.

Figures: `eda-corr-blockA.png`, `eda-corr-blockB.png`, `eda-corr-blockC.png`.

---

## 3. Block B collinearity + principal-component structure

The verify set named in the task sheet: **SVI's four themes, ADI, the income /
poverty axis (`ice150` — Index of Concentration at the Extremes on ACS income:
households ≥ $150k minus households < $25k, over total, so a positive value is
concentrated affluence and a negative value concentrated poverty; SVI theme 1
also loads on below-poverty share), uninsured rate, and rurality** — eight
measures, complete for all 2,801 hospitals.

| diagnostic | value | reading |
|---|---|---|
| pairwise Pearson \|r\| | median 0.41, **max 0.83** (`adi`~`ice150`) | several measures largely restate each other |
| VIF, verify set (each on the other 7) | `ice150` 9.8, `svi_ses` 8.8, `adi` 5.8; rest < 4 | **3 of 8 above the conventional 5** |
| VIF, 11-measure working block (each on the other 10) | `ice150` 10.7, `svi_ses` 9.5, `adi` 6.9 | adding `limeng`/`pcp_density`/`hhi_zip` moves these up slightly |
| VIF, 13-measure block incl. the vintage pairs | up to 87 (`ice`↔`ice150`, `adi`↔`adi2020`) | why `adi2020`/`ice` are dropped (§ headline) |
| correlation-matrix determinant (verify set) | **0.0022** | ≈ 0; an orthogonal set would be 1 |
| condition number √(λmax/λmin) (verify set) | 8.4 | moderate — not the >30 "severe" regime |
| PCA (verify set) | **PC1 46%, PC1+PC2 73%**; 4 PCs for 90% | the 8 measures span ~2 effective dimensions |

`output/tables/eda-blockB-collinearity.csv` — the 11-measure working block,
VIF + PC1–3 loadings.

### PC1–3, read off the loadings rather than assumed

Loadings oriented so a **high score = more advantaged**. Verify set (8) and
working block (11, `adi2020`/`ice` dropped) give the same three axes; the
working block's PC3 additionally pulls in `hhi_zip` and `pcp_density`.

| | **PC1** general advantage | **PC2** rural vs. urban character | **PC3** housing / built environment |
|---|---|---|---|
| variance (verify / working) | 46% / 37% | 27% / 28% | 11% / 10% |
| cumulative | 46% / 37% | 73% / 65% | 84% / 75% |
| strongest loadings | `svi_ses` −0.46/−0.43, `svi_household` −0.42/−0.40, `ice150` +0.45/+0.43, `uninsured` −0.34/−0.33, `adi` −0.33 (both) | `svi_minority` −0.61/−0.50, `adi` +0.43/+0.34, `rurality` +0.46/+0.35 (working: `limeng` −0.48, `hhi_zip` +0.31) | `svi_housing` −0.79/−0.63 (working: `hhi_zip` −0.46, `pcp_density` −0.42) |
| **reading** | Every vulnerability measure loads the same direction and `ice150` (the one affluence-scored measure) loads the opposite way — money, insurance, and (in the working block) PCP access move together. **One general socioeconomic gradient.** | Positive end = rural/ADI-style deprivation (+ concentrated hospital markets); negative end = urban minority/uninsured/limited-English deprivation. **These are two different kinds of disadvantage, not two points on one scale** — `adi`~`uninsured` r = 0.25, `rurality`~`uninsured` r = 0.12. | SVI theme 4 (multi-unit/mobile housing, crowding, no vehicle) almost owns this axis on its own; market concentration and PCP scarcity ride along in the working block. |

**Does the outcome track the big axes, or is it spread out?** Correlating
each PC score with PSI-90: PC1 gives r = −0.084 (ρ = −0.125) — the single
strongest disadvantage–outcome relationship in the block, slightly ahead of
any raw measure. But regressing PSI-90 on **all 8** verify measures gives
R² = 0.0246, while **PC1–3 alone** (73% of the block's own variance) gives
only R² = 0.0127 — **52% of the full association**. The outcome-relevant part
of Block B is spread across all eight dimensions, not concentrated where the
variance is. **Conclusion: a reduced-PC index is a Task 3.4 robustness arm,
not a substitute for the raw measures** — collapsing to PC1–3 would throw
away about half of an already-small signal.

**Why this licenses TIS and not a marginal ranking.** With `adi` and `ice150`
at r = −0.83, a permutation-importance procedure can shift almost all of their
joint explanatory weight onto whichever one it permutes second; the ranking
is then an artifact of column order, not of the data. The plan already
commits to this (`Plan.md` line 110: "marginal importance would mislead, so
the TIS decomposition separates direct from shared attribution"). Task 3.1's
job was to show the collinearity is real at the magnitude that makes marginal
importance unsafe — it is. Figure `eda-blockB-collinearity.png` (correlation
heatmap · verify-set VIF · PCA scree).

This does **not** mean the disadvantage signal is weak or unidentified — it
means it is *shared*. MCR⁻ > 1 for community disadvantage (the claim worth
having, `Plan.md` line 110) is a statement about the *set* of these measures,
which is exactly what the collinearity structure permits.

---

## 4. Cross-block correlation

`output/tables/eda-outcome-correlations.csv` — PSI-90 vs all 29 covariates,
Pearson and Spearman.

**Every marginal correlation with PSI-90 is small.** The largest are
`operating_margin` −0.13, `ice150` / `ice` −0.13, `resident_to_bed` /
`teaching` +0.12, `contract_labor_share` +0.11, `beds` +0.11, `adi` +0.10.
Nothing clears |r| = 0.15. This is consistent with Phase 0 and with the whole
premise of the project: the between-hospital signal is real but modest, and
the interesting question is how the *blocks* partition it, not which single
column predicts best. The Block B measures do not all point the same way at
the margin — `adi` +0.10 but `uninsured` −0.02 and `ice150` −0.13 — another
reason the decomposition has to be multivariate.

**Block A × Block B are entangled** (`output/tables/eda-crossblock-correlation.csv`,
figure `eda-crossblock-AB.png`): `wage_index`~`adi` −0.66 (low-wage-index
areas are more deprived), `dsh_pct`~`svi_ses` +0.49, `uncomp_care_pct`~
`uninsured` +0.49, `dsh_pct`~`limeng` +0.47. Median |r| 0.13, max 0.66. A
hospital's structural position and its catchment's disadvantage are not
separable by inspection — the nested model and the block-wise variance
decomposition (Task 3.2–3.3) are what separate them.

---

## 5. Geographic patterning of PSI-90

`output/tables/eda-geographic.csv`, figure `eda-geographic.png`.

**Between-unit variance share (one-way ANOVA ICC):**

| grouping | units | hosp/unit | ICC | note |
|---|---|---|---|---|
| census region | 4 | 700 | 0.006 | |
| census division | 9 | 311 | 0.008 | |
| state | 51 | 55 | **0.043** | |
| CBSA | 457 | 6.1 | **0.132** | 19% singletons |
| catchment county | 1,289 | 2.2 | 0.027 | 63% singletons |
| HSA | 1,749 | 1.6 | ~0 | 74% singletons — not identified |

The signal is **local, not regional**: ~13% of PSI-90 variance sits between
CBSAs, ~4% between states, ~1% between census divisions. The county and HSA
grains are mostly one hospital per unit, so the ANOVA moment estimator cannot
separate between from within there and collapses toward zero — the random-
effects fit at Task 3.2 borrows strength across those sparse units where this
estimator cannot, which is the point of fitting hospitals nested in catchment
geography rather than running a fixed-effects ANOVA.

**Outcome gradient across catchment disadvantage** (`eda-outcome-gradient.csv`,
mean PSI-90 by quartile, every measure oriented so Q4 = most disadvantaged):

| measure | Q1 | Q4 | Δ |
|---|---|---|---|
| ADI | 0.979 | 1.024 | **+0.045** |
| rurality | 0.973 | 1.017 | +0.044 |
| ICE-150 (sign flipped so high = poor) | 0.957 | 1.020 | +0.062 |
| SVI socioeconomic | 0.976 | 1.002 | +0.026 |
| uninsured rate | 1.009 | 0.994 | −0.015 |

Four of five disadvantage axes show PSI-90 rising with catchment deprivation;
**uninsured rate runs the other way** (hospitals in high-uninsured catchments
have slightly *lower* measured PSI-90) — a reminder that "disadvantage" is not
one thing and that the uninsured share may be picking up region or hospital
type rather than deprivation. By hospital location, RURAL hospitals average
PSI-90 1.010 vs LURBAN 0.980 — a 0.03 gap, the same direction as the ADI and
rurality gradients.

The Δ of roughly +0.045 across ADI quartiles is a *marginal* gradient with
none of Block A or the reliability weighting removed — it is the raw pattern
the decomposition in Tasks 3.2–3.3 has to attribute, not the finding itself.

---

## 6. Files

```
R/03-eda.R                                   new -- stage 20
make.R                                       stage 20 added
output/figures/eda-outcome-distribution.png
output/figures/eda-covariate-distributions.png
output/figures/eda-corr-blockA.png / -blockB.png / -blockC.png
output/figures/eda-blockB-collinearity.png
output/figures/eda-crossblock-AB.png
output/figures/eda-outcome-correlations.png
output/figures/eda-geographic.png
output/tables/blockB-correlation.csv          the deliverable (+ -spearman.csv)
output/tables/eda-distributions.csv
output/tables/eda-blockA-correlation.csv / -blockC-correlation.csv
output/tables/eda-blockB-collinearity.csv     11-msr working block: VIF + PC1-3 loadings
output/tables/eda-outcome-correlations.csv
output/tables/eda-crossblock-correlation.csv
output/tables/eda-geographic.csv / eda-outcome-gradient.csv
output/tables/task3.1-eda.txt                stage log
```

Full `make.R` from raw (227 s): every stage `ok` through stage 20, provenance
`consistent`, and stage 19 re-verified the frozen analytic hash
(`7d409b5d…`) unchanged — Task 3.1 adds a read-only stage and touches nothing
upstream.

---

## 7. Next

**Task 3.2 — fit the baseline hierarchical model (REWRITTEN in rev 2).** The
primary fit runs on **the components**, not the published composite (fitting a
random-intercept model on an already-shrunk estimate shrinks twice). Hospitals
nested in catchment geography; null → Block A → Block A + B → all admitted
blocks; weighted by the published denominator. The composite gets treatment
(a) or (b) from the task sheet, stated explicitly, never a plain random
intercept. **Verify:** the null model's between-hospital variance is
reconciled against `tau2 = 0.07744` from Task 2.2; a material disagreement is
itself a finding. `[Fresh session per the task sheet.]`

**Carries forward from this task:** the Block B working set is `adi` +
`ice150` (not `adi2020` / `ice`) plus the four SVI themes, `uninsured`,
`rurality`, `limeng`, `pcp_density`, `hhi_zip` — 11 measures. `adi2020` and
`ice` are Task 3.4 robustness swaps only, never co-entered with their
partner. A PCA/index representation of Block B is a robustness arm, not the
base case (§3).
