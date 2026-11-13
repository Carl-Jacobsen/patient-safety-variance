# A. Methods

This part gives the constructions a methodologically trained reader would need to reimplement the analysis without the code: the reliability approximation, the registered specification space, the Rashomon set and its tolerance, model reliance and model class reliance, the variance decomposition, the disadvantage contrast and its geographic rebuild, the held-out validation, and the payment simulation. Throughout, hospitals are indexed by i = 1, …, n, the published PSI-90 composite of hospital i is written θ̂ᵢ, a fitted model f maps hospital i's covariates xᵢ to a prediction f(xᵢ), and every loss is squared error. Each construction is given with the checks it passed before project data were used.

## A.1 Reliability under a scalar approximation

CMS publishes, for each hospital, a PSI-90 point estimate and an interval (the Lower Estimate and Higher Estimate fields), but neither the observed numerator nor the expected rate. Two diagnostics show that the published scores are smoothed. If a published interval described sampling error around an unsmoothed rate, its width would fall with the square root of volume, and a regression of log interval width on log Medicare volume would have a slope near −0.50; the observed slope is −0.193 (correlation −0.863), the flatter pattern a posterior interval on a shrunk estimate produces. Converted to variances, the published intervals have a mean of 0.04066, which exceeds the variance of the published scores across hospitals (0.03678); for unsmoothed estimates the variance across hospitals must be at least the mean sampling variance, so the ordering is possible only if the scores have been pulled toward a common value.

The approximation treats each published value as the posterior mean of a normal model in which hospital i's true value θᵢ is drawn from N(μ, τ²) and its unsmoothed rate yᵢ is observed with sampling variance σᵢ²:

$$ θ̂ᵢ = μ + λᵢ (yᵢ − μ),   λᵢ = τ² / (τ² + σᵢ²).

The posterior variance is vᵢ = τ²(1 − λᵢ), so λᵢ = 1 − vᵢ/τ², and vᵢ = [(uᵢ − lᵢ)/(2 × 1.96)]² from the published lower and upper estimates. Averaged over hospitals, the variance of the published values is approximately τ² − E[vᵢ], which identifies the prior variance:

$$ τ² = Var(θ̂) + E[vᵢ] = 0.03678 + 0.04066 = 0.07744   (τ = 0.2783).

The prior variance is computed on the 2,799 hospitals with a published interval and a positive Medicare volume and bed count, and λᵢ for all 2,801. The median is 0.462 and the mean 0.475; the 5th, 25th, 75th and 95th percentiles are 0.143, 0.289, 0.656 and 0.837 (Figure S1). Reliability correlates at +0.93 with the logarithm of Medicare volume.

The approximation is a single normal shrinkage toward one national prior. CMS builds the composite from separately smoothed components, and its documentation (the AHRQ 2024 empirical methods, section `F.5.1`, which CMS cites for the composite's standard error) computes the composite variance as w′Var(v)w with off-diagonal terms for the components' signal covariances. Those covariances are positive, so the scalar τ² understates the composite's signal variance and λᵢ is biased low. λᵢ enters the reliability-weighted sensitivity analyses, the errors-in-variables level of the specification space and the payment simulation's published-score draws (section A.8), but not the primary decomposition, which uses the published score unweighted; a question asking CMS for the release-specific parameters has been drafted.

Reliability enters the specification space through four levels of one axis. The unweighted level fits ordinary least squares to the published value (the primary analysis), and the weighted level uses weights λᵢ. The subsample level keeps the hospitals with λᵢ ≥ 0.60 and weights them by λᵢ. The errors-in-variables level reverses the shrinkage hospital by hospital,

$$ ỹᵢ = ĝ + (θ̂ᵢ − ĝ) / λᵢ,

where ĝ is the mean published value in the fitting sample, and fits with weights λᵢ²; the un-shrunk value is used only inside a regression across hospitals, never as an estimate for one hospital.

## A.2 The specification space

The registry crosses eight analytic choices (Table S1), whose levels multiply to 10,368 combinations. Five rules remove combinations that are undefined or identical to another: the missing-data axis applies only when Block C, which contains the one imputed covariate, is in the model; splines apply only when disadvantage measures are in the model; the errors-in-variables level applies only to the composite; the two catchment grains are identical to the Service Area grain when no Block B covariate is in the model; and dropping the catchment fallbacks changes nothing when no catchment weighting is used. The remaining 3,496 specifications were committed to version control before the first model was fitted. Of these, 3,344 include community disadvantage and 736 model the composite.

Table S1. Axes of the specification space.

| Axis | Levels |
|---|---|
| Covariate blocks | A; A and B; A, B and C |
| Functional form | Linear; natural cubic splines on the eight continuous disadvantage measures |
| Outcome | PSI-90 composite; the four components; their denominator-weighted aggregate |
| Reliability | Unweighted; weighted; high-reliability subsample; errors-in-variables (composite only) |
| Geographic grain | Catchment tract; catchment county; hospital county; Dartmouth Hospital Service Area |
| Missing data | Multiple imputation (m = 20); complete case; covariate omitted (only with Block C) |
| Influential hospitals | All; drop the 77 hospitals with CMS footnote 23 or 29; drop the 130 catchment fallbacks |
| Outcome scale | Identity; logarithm |

The composite is fitted by least squares, weighted as the reliability level specifies, with one row per hospital. The component and aggregate outcomes are fitted as linear mixed models with a random intercept for the nesting geography, each component standardized to its own mean and standard deviation. Continuous covariates are standardized once on the analytic frame, and spline knots are fixed once at the 25th, 50th and 75th percentiles with boundary knots at the 5th and 95th. Multiple-imputation specifications are fitted to each of the 20 completed datasets and pooled by Rubin's rules. The focal estimate of each specification is the predicted difference between a hospital at the 10th percentile of every disadvantage measure and one at the 90th (ICE and primary-care density reversed, so the 90th percentile is the deprived end), computed as c′β̂ with standard error (c′V̂c)^{1/2} and divided by the standard deviation of the outcome. A positive contrast means worse PSI-90 in more disadvantaged catchments.

## A.3 The Rashomon set and its tolerance

Within each outcome family every specification is scored on a common evaluation frame, the hospitals complete on all three blocks at every grain (n = 2,569 for the composite), with the family's outcome on its natural scale as the target:

$$ L(f) = (1/n) Σᵢ (θ̂ᵢ − f(xᵢ))².

Predictions are returned to the target's scale before scoring: a log-scale prediction is exponentiated, a component prediction is unstandardized, and an errors-in-variables prediction is re-shrunk as ĝ + λᵢ(f(xᵢ) − ĝ). Mixed-model predictions use the fixed effects alone, and multiple-imputation specifications average their 20 predictions before scoring.

The empirical risk minimizer f̂ is the registered specification with the lowest loss in the family, including specifications with no community block; for the composite it is an errors-in-variables specification at L(f̂) = 0.031883. The tolerance comes from B = 1,000 resamples of hospitals: refit f̂ on each, score each refit on the original frame, and take the excess loss Δ⁽ᵇ⁾ = L(f̂⁽ᵇ⁾) − L(f̂). The tolerance ε is the 95th percentile of the Δ⁽ᵇ⁾, a level committed to version control before any loss was computed. For the composite ε = 0.001306, or 4.10% of L(f̂), and

$$ R(ε) = { f in the registry : L(f) ≤ L(f̂) + ε }

contains 194 of the 736 composite specifications. Members have between 26 and 51 fixed effects, and the correlation between parameter count and loss across composite specifications is −0.034. Resampling whole states gives ε = 9.31% of L(f̂) and resampling metropolitan areas 5.10%; because a larger tolerance admits a superset, the reliance bounds at each tolerance are minima and maxima over nested sets.

The 65 members fitted to the published score without weights form the published-score subset. Its best-fitting member, specification 382 (spline form, county-grain catchments, complete cases), is the anchor for the contrast-support, geography, suppression, ownership and validation analyses.

## A.4 Model reliance and model class reliance

Model reliance follows Fisher, Rudin and Dominici (2019). For a model f and a block S of covariates, let e_orig = L(f), and let e_switch be the loss when hospital i's values of the block are replaced by hospital j's, averaged over every ordered pair:

$$ e_switch = [1/(n(n − 1))] Σ_{i≠j} (θ̂ᵢ − f(i ← j))²,   MR(f, S) = e_switch / e_orig.

Under every transformation used here, the switched prediction has the form f(i ← j) = Bᵢ + CᵢVⱼ, where Vⱼ depends only on hospital j's values of the block and Bᵢ and Cᵢ only on hospital i's other covariates. On the identity scale Cᵢ = 1 and Vⱼ is the block's contribution to the linear predictor; under errors-in-variables re-shrinkage Cᵢ = λᵢ; on the log scale Cᵢ = exp(aᵢ) and Vⱼ = exp(vⱼ). Writing rᵢ = θ̂ᵢ − Bᵢ, the double sum separates,

$$ Σ_{i≠j} (rᵢ − CᵢVⱼ)² = n Σᵢ rᵢ² − 2 (Σᵢ rᵢCᵢ)(Σⱼ Vⱼ) + (Σᵢ Cᵢ²)(Σⱼ Vⱼ²) − Σᵢ (rᵢ − CᵢVᵢ)²,

so reliance is computed exactly in order n. Multiple-imputation specifications average m predictions inside the loss, which adds an m × m matrix of cross-products and leaves the computation exact. Model class reliance takes the extremes over the set, MCR⁻(ε) = min MR(f, S) and MCR⁺(ε) = max MR(f, S) for f in R(ε). Because the set is drawn from an enumerated registry, the reported MCR⁻ is an upper bound on the MCR⁻ of any richer class. In a hand-worked check with θ̂ = (1, 2, 3, 6) and contribution v = (1, 2, 3, 4), e_orig = 1, the ordered-pair sum is 76, e_switch = 76/12 and MR = 19/3, which the implementation reproduces; in the population case θ = x + e with unit variances, where MR tends to 3, a large simulated sample gives 2.9931.

## A.5 The variance decomposition

Each of the K = 3 covariate blocks receives its average gain in explained variance over every order of entry,

$$ φ_b = Σ_{S ⊆ blocks∖{b}} [|S|! (K − |S| − 1)! / K!] [R²(S ∪ {b}) − R²(S)],

so the three shares sum to the R² of the model with all three blocks. On the composite, R² is the ordinary coefficient of determination of the published score (primary) or its reliability-weighted version (sensitivity). On the components, the quantity divided is the hospital variance component of the null mixed model. Intervals come from 1,000 bootstrap resamples, of hospitals for the composite and of whole Hospital Service Areas for the components.

## A.6 The contrast, its parts and the geographic rebuild

The joint contrast of a fitted model is c′β̂ for the move from the 10th to the 90th percentile of every disadvantage measure at once, holding everything else at its center. Because the model is additive in the measures, the contrast splits exactly into the parts carried by material deprivation (ADI, the income index, SVI 1, SVI 4 and the uninsured share), demographic composition (SVI 2, SVI 3 and the limited-English share) and the access measures (rurality and primary-care density). Support was checked by the share of observed catchments whose Mahalanobis distance from the center is at least that of each end of the joint move, against a rule, fixed in advance, that a share below 5% would put the move off support.

The SVI themes are percentile ranks computed separately for tracts and for counties, so a county-grain theme and a catchment average of tract themes are not the same quantity. The rebuild replaces each theme with the mean of the standardized estimates of its component variables, standardized against a population-weighted national tract reference, and computes county values as population-weighted aggregates of tract estimates; the uninsured and limited-English shares are rebuilt as exact tract aggregates.

## A.7 The held-out validation

The validation refits specification 382's settings with four versions of the community block, scored on the 2,569 hospitals of its evaluation frame. In the new-area design the 51 state codes are partitioned at random into five folds, and each fold's hospitals are predicted by a model fitted to the other four; in the within-area design hospitals are partitioned into five folds at random. Every fold assignment is repeated 20 times. For each repeat, the held-out loss of each reduced version is divided by that of the full community block, and the table reports the mean ratio minus one with its 2.5th and 97.5th percentiles over repeats. A reduced version is equivalent to the full block if its relative loss is within 1%. The share of the full block's held-out gain over the no-community model that a reduced version keeps is reported beside it.

## A.8 The payment simulation

The simulation applies a Q-HIP-style rule as CASH2 specified it to the 2,569 hospitals of the model frame. Hospital i's eligible revenue is Rᵢ = NPRᵢ × cᵢ, its net patient revenue times its commercial revenue share, where the base cᵢ is the hospital's commercial day share from its FY 2023 cost report: one minus the Title V, Medicare and Medicaid inpatient days (with the Medicare and Medicaid managed-care days of line 2) over total days on worksheet S-3 Part I (`1 − (L14 c5 + L14 c6 + L14 c7 + L2 c6 + L2 c7) / L14 c8`), with CASH2's share (`0.37`, or `0.37 × 0.40` at safety-net hospitals) where the cost report gives no usable value. Its safety score is

$$ Sᵢ = w zᵢ + (1 − w) h̄ᵢ,

where zᵢ is its published PSI-90 winsorized at the 5th and 95th percentiles across hospitals and standardized by the winsorized mean and standard deviation, h̄ᵢ is the mean of its HACRP winsorized z-scores on the five infection measures (held at observed values), and w = 0.15; a hospital with no infection measures is scored on zᵢ alone. Lower scores are safer. Its position is Pᵢ = 1 − rank(Sᵢ)/n with ties given their average rank, so the safest hospitals have the highest positions, and its bonus is Payᵢ = Rᵢ r(Pᵢ), with

$$ r(P) = 0.001 + 0.039 P^k,

for k = 1 (base), 0.5 (concave) and 2 (convex), all sharing the endpoints 0.1% and 4%. The threshold variant pays r = 0 for P < 0.25 and 0.001 + 0.039(P − 0.25)/0.75 above it, and the rescaled curves multiply r by a per-draw factor that sets the total equal to the base total.

The finite payment return of hospital i is computed in four steps. Lower its published PSI-90 by Δ = 0.05, keeping the draw's winsorization bounds, mean and standard deviation fixed. Recompute its score Sᵢ′ with the same weights. Place Sᵢ′ among the other hospitals' unchanged scores by the same average-rank convention,

$$ Pᵢ′ = 1 − (#{j ≠ i : Sⱼ < Sᵢ′} + 1 + ½ #{j ≠ i : Sⱼ = Sᵢ′}) / n,

so that an unchanged score returns its own position exactly. The return is [Rᵢ r(Pᵢ′) − Payᵢ] / Δ, in dollars per unit of PSI-90, and the per-revenue-dollar return divides it by NPRᵢ. In the all-improve case every hospital's PSI-90 is lowered by Δ and every hospital is rescored; because positions depend only on ranks, total payment is unchanged.

Each draw b carries three sources of uncertainty. A specification is drawn from the Rashomon set and, for imputed specifications, one completion; its coefficients are drawn from their estimated sampling distribution; and each hospital's true score is drawn as θᵢ ~ N(θ̂ᵢ, vᵢ) and re-published as μ + λᵢ(θᵢ + σᵢεᵢ − μ), so that the published-score draw carries the measurement error the reliability approximation implies. Three rankings orient the concentration index: distance from the best measured score (rank of θᵢ, higher meaning worse), model-implied disadvantage (rank of the drawn model's disadvantage contribution to the linear predictor), and catchment ADI. For a quantity hᵢ and ranking position Qᵢ = (rankᵢ − 0.5)/n,

$$ C = 2 Cov(hᵢ, Qᵢ) / h̄,

so a negative C means the quantity is concentrated among hospitals ranked low on the ranking. The verdict rule, fixed in advance, reads the 95% simulation interval over draws: an interval wholly below zero is regressive, wholly above zero progressive, and one that crosses zero shows no clear direction; an interval of zero width means no modeled variation, not certainty. "Regressive" describes the arithmetic of the rule as modeled, not any payment a hospital has received. The safety-net ratio is the ratio of mean per-revenue-dollar returns at safety-net hospitals to those at other hospitals. The revenue exposure coefficient Rᵢ × w × 0.039, the quantity the September draft reported as an incentive, never consults the rate curve or any other hospital's score; it is kept as a supplementary column only.

The scenarios vary what the draws cannot: the PSI-90 weight (0.10 and 0.20), the curve (concave, convex, rescaled, threshold), the scorecard (PSI-90 alone), and the revenue base (CASH2's flat share, CASH2's share with a 0.40 safety-net factor, and commercial revenue shares at commercial-to-Medicare price ratios ρ of 1.5 and 2.0, computed as ρs / (ρs + 1 − s) from the day share s). A fixed run holds every published score at its observed value. The scoring machinery was checked first against HACRP, whose rule is public: from the published inputs it reproduces 3,054 of 3,055 penalty decisions, and replacing PSI-90 with model draws predicts 627 penalties against 629 observed among 2,551 hospitals.
