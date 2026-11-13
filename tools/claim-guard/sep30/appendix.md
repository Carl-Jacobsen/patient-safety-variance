# Appendix. Technical methods

The findings rest on a small number of constructions that a methodologically trained reader would need in order to reimplement the analysis without the code: the recovery of each hospital's reliability from the published intervals, the registered specification space, the Rashomon set and its bootstrap tolerance, model class reliance, and the decomposition of reliance into direct and shared parts. Each is given with its estimator, the identity it relies on and the checks it passed before any project data were used, followed by the variance decomposition and the payment quantities. Throughout, hospitals are indexed by i = 1, …, n, the published PSI-90 composite of hospital i is written θ̂ᵢ, and a fitted model f maps hospital i's covariates xᵢ to a prediction f(xᵢ), and every loss is squared error.

## A.1 Reliability recovered from the published intervals

CMS publishes, for each hospital, a PSI-90 point estimate and an interval (the Lower Estimate and Higher Estimate fields), but neither the observed numerator nor the expected rate, so the smoothing it applies cannot be reversed from the counts, but the intervals reveal it. If a published interval described sampling error around an unsmoothed rate, its width would fall with the square root of the hospital's volume, and a regression of log interval width on log Medicare volume would have a slope near −0.50. The observed slope is −0.193 (the correlation between the two logarithms is −0.863). A slope that much flatter is what a posterior interval on a shrunk estimate produces: as volume falls, the posterior rests increasingly on the common prior, and its width approaches the width of the prior instead of growing without limit, so the interval stops widening at low volume in a way that sampling error alone would not. A second diagnostic, which compares the published intervals with the spread of the published scores, points the same way. Converted to variances, the published intervals have a mean of 0.04066, which exceeds the variance of the published scores across hospitals (0.03678); for unsmoothed estimates the variance across hospitals must be at least the mean sampling variance, so that ordering is possible only if the published scores have been pulled toward a common value.

The recovery treats each published value as the posterior mean of a normal model in which hospital i's true value θᵢ is drawn from N(μ, τ²) and its unsmoothed rate yᵢ is observed with sampling variance σᵢ². The posterior mean and the reliability λᵢ, the share of the hospital's own deviation that survives into the published number, are then

$$ θ̂ᵢ = μ + λᵢ (yᵢ − μ),   λᵢ = τ² / (τ² + σᵢ²),

and the posterior variance is vᵢ = λᵢσᵢ² = τ²(1 − λᵢ), so that λᵢ = 1 − vᵢ/τ². The posterior variance comes from the published interval, vᵢ = [(uᵢ − lᵢ)/(2 × 1.96)]², where lᵢ and uᵢ are the lower and upper estimates. Averaged over hospitals, the variance of the published values is approximately τ²E[λᵢ] = τ² − E[vᵢ], which identifies the prior variance from published quantities alone:

$$ τ² = Var(θ̂) + E[vᵢ] = 0.03678 + 0.04066 = 0.07744   (τ = 0.2783).

The prior variance is computed on the 2,799 hospitals with a published interval and a positive Medicare volume and bed count, and λᵢ is then computed for all 2,801. The median hospital has λᵢ = 0.462 and the mean is 0.475; the 5th, 25th, 75th and 95th percentiles are 0.143, 0.289, 0.656 and 0.837. Reliability correlates at +0.93 with the logarithm of Medicare volume, so the share of a hospital's deviation that the composite retains is almost entirely a function of its size.

The derivation is an approximation, and its assumptions should be stated. It treats the composite as a single normal shrinkage toward one national prior, with symmetric intervals at ±1.96 posterior standard deviations and no covariates in the prior. CMS builds the composite from separately smoothed component rates and does not document its interval construction fully, so λᵢ is the reliability that this approximation implies rather than a quantity CMS reports. The intervals are published to two decimal places, which limits the precision of vᵢ for hospitals with narrow intervals, and the recovery uses the two-decimal published score for the same reason.

Reliability enters the specification space through four levels of one axis. The unweighted level fits ordinary least squares to the published value, and the weighted level uses weights λᵢ. The subsample level keeps the hospitals with λᵢ ≥ 0.60 (roughly the upper two volume quartiles) and weights them by λᵢ. The errors-in-variables level reverses the shrinkage hospital by hospital,

$$ ỹᵢ = ĝ + (θ̂ᵢ − ĝ) / λᵢ,

where ĝ is the mean published value in the fitting sample, and fits with weights λᵢ²; the reversal multiplies any error in the published deviation by 1/λᵢ, and the weights offset the resulting inflation of its variance by 1/λᵢ². The un-shrunk value is never used as an estimate for a single hospital, since at λᵢ = 0.14 its variance is inflated about fiftyfold; it is used only inside a regression across hospitals. No level fits a hierarchical model to the published composite, which would shrink it a second time. For the four components, which CMS publishes with denominators and without composite smoothing, the weighted level uses the published denominator, the subsample level keeps the same high-volume hospitals, and the errors-in-variables level is not defined.

## A.2 The specification space

The registry crosses eight analytic choices (Table A.1), whose levels multiply to 10,368 combinations. Five rules remove combinations that are undefined or identical to another: the missing-data axis applies only when Block C, which contains the one imputed covariate, is in the model; splines apply only when disadvantage measures are in the model; the errors-in-variables level applies only to the composite; the two catchment grains are identical to the Service Area grain when no Block B covariate is in the model; and dropping the catchment fallbacks changes nothing when no catchment weighting is used. The remaining 3,496 specifications were written to a registry and committed to version control before the first model was fitted. Of these, 3,344 include community disadvantage and 736 model the composite.

Table A.1. Axes of the specification space.

| Axis | Levels |
|---|---|
| Covariate blocks | A; A and B; A, B and C |
| Functional form | Linear; natural cubic splines on the eight continuous disadvantage measures |
| Outcome | PSI-90 composite; PSI-03; PSI-06; PSI-12; PSI-13; denominator-weighted aggregate of the four components |
| Reliability | Unweighted; weighted; high-reliability subsample; errors-in-variables (composite only) |
| Geographic grain | Catchment tract; catchment county; hospital county; Dartmouth Hospital Service Area |
| Missing data | Multiple imputation (m = 20); complete case; covariate omitted (only with Block C) |
| Influential hospitals | All; drop the 77 hospitals with CMS footnote 23 or 29; drop the 130 catchment fallbacks |
| Outcome scale | Identity; logarithm |

The composite is fitted by least squares, weighted as the reliability level specifies, with one row per hospital and no random effect. The component and aggregate outcomes are fitted as linear mixed models with a random intercept for the nesting geography (Hospital Service Area or county, according to the grain), and each component is standardized to its own mean and standard deviation, since the raw component rates differ roughly 500-fold in variance and the noisiest component would otherwise dominate a shared residual variance. The aggregate divides each component rate by its national mean and averages the four ratios with the published denominators as weights. Continuous covariates are standardized once on the analytic frame, and the spline knots are fixed once on the frame at the 25th, 50th and 75th percentiles of each standardized measure, with boundary knots at the 5th and 95th; rurality and primary-care density enter linearly in every specification. Multiple-imputation specifications are fitted to each of the 20 completed datasets and pooled by Rubin's rules. The focal estimate of each specification is the predicted difference in its outcome between a hospital at the 10th percentile of every disadvantage measure and one at the 90th percentile (ICE and primary-care density reversed, so that the 90th percentile is the deprived end), computed as c′β̂ with standard error (c′V̂c)^{1/2} and divided by the standard deviation of the outcome so that the outcome families share one scale.

## A.3 The Rashomon set and its tolerance

Membership in the Rashomon set is decided by a loss, so the loss has to mean the same thing for every specification that competes for a place. Within each outcome family, every specification is therefore scored on a common evaluation frame: the hospitals complete on all three covariate blocks at every grain (n = 2,569 for the composite), with the family's outcome on its natural scale as the target and the unweighted mean squared error as the loss,

$$ L(f) = (1/n) Σᵢ (θ̂ᵢ − f(xᵢ))².

Predictions are returned to the target's scale before scoring. A log-scale prediction is exponentiated, a component prediction is unstandardized with the parameters that standardized it, and an errors-in-variables prediction is re-shrunk as ĝ + λᵢ(f(xᵢ) − ĝ), the inverse of the transformation that un-shrunk its outcome; without that step the errors-in-variables specifications would be scored against a target they were not predicting. Mixed-model predictions are made from the fixed effects alone, because the cluster bootstrap relabels resampled clusters, and a prediction that included random effects would penalize every bootstrap refit for clusters the original frame had not seen. Multiple-imputation specifications average their 20 predictions, one from each completed dataset, before scoring. The losses each specification reports during its own fitting are not comparable across specifications (they differ in rows, scale and target) and are not used.

The empirical risk minimizer f̂ of a family is the registered specification with the lowest loss, taken over every specification in the family, including those with no community disadvantage at all. For the composite it is an errors-in-variables specification with all three blocks, splines and county-grain catchments, at L(f̂) = 0.031883. The tolerance comes from a bootstrap of that minimizer: draw B = 1,000 resamples of hospitals, refit the same registered specification on each to obtain f̂⁽ᵇ⁾, score each refit on the original evaluation frame, and take the excess loss Δ⁽ᵇ⁾ = L(f̂⁽ᵇ⁾) − L(f̂). The tolerance ε is the 95th percentile of the Δ⁽ᵇ⁾, a level committed to version control on its own before any loss was computed. For the composite, ε = 0.001306, or 4.10% of L(f̂), and the Rashomon set is

$$ R(ε) = { f in the registry : L(f) ≤ L(f̂) + ε },

which contains 194 of the 736 composite specifications. The loss is computed in sample with no penalty for complexity, which is the empirical risk the method is defined on. Members of the set have between 26 and 51 fixed effects, and the correlation between parameter count and loss across the composite specifications is −0.03, so the set is not simply the most heavily parameterized region of the registry.

The resampling unit matters more to the tolerance than the percentile does. Resampling hospitals treats them as independent; a pre-registered sensitivity that resamples whole states gives ε = 9.31% of L(f̂), and a sensitivity added after those results were seen, resampling the 457 metropolitan areas, gives 5.10%, and the hospital tolerance remains primary because it was fixed in advance. Because a larger tolerance admits a superset of models, the reliance bounds at each tolerance are minima and maxima over nested sets.

## A.4 Model reliance and model class reliance

Model reliance follows Fisher, Rudin and Dominici (Journal of Machine Learning Research 20, 2019). For a model f and a block S of covariates, let e_orig = L(f), and let e_switch be the loss when hospital i's values of the block are replaced by hospital j's, averaged over every ordered pair:

$$ e_switch = [1/(n(n − 1))] Σ_{i≠j} (θ̂ᵢ − f(i ← j))²,   MR(f, S) = e_switch / e_orig.

The average is computed exactly rather than by sampling permutations. Under every transformation used here, the switched prediction has the form f(i ← j) = Bᵢ + CᵢVⱼ, where Vⱼ depends only on hospital j's values of the block and Bᵢ and Cᵢ only on hospital i's other covariates. On the identity scale Cᵢ = 1 and Vⱼ is the block's contribution to the linear predictor; under errors-in-variables re-shrinkage Cᵢ = λᵢ; on the log scale Cᵢ = exp(aᵢ) and Vⱼ = exp(vⱼ), since the exponential of a sum factors; and the unstandardizing of a component is affine and folds into Bᵢ and Cᵢ. Writing rᵢ = θ̂ᵢ − Bᵢ, the double sum separates,

$$ Σ_{i≠j} (rᵢ − CᵢVⱼ)² = n Σᵢ rᵢ² − 2 (Σᵢ rᵢCᵢ)(Σⱼ Vⱼ) + (Σᵢ Cᵢ²)(Σⱼ Vⱼ²) − Σᵢ (rᵢ − CᵢVᵢ)²,

so the reliance of each model costs order n rather than order n² and carries no simulation error. Multiple-imputation specifications average m predictions inside the loss, which adds an m × m matrix of cross-products to the quadratic term and leaves the computation exact. On the identity scale the separation also gives MR − 1 = 2 Cov(r, u)/e_orig, where uᵢ is the block's contribution and the covariance uses the divisor n − 1: a model relies on a block exactly when the block's contribution covaries positively with the part of the outcome the rest of the model leaves unexplained.

Model class reliance takes the extremes over the Rashomon set, MCR⁻(ε) = min MR(f, S) and MCR⁺(ε) = max MR(f, S) for f in R(ε). Because the set is drawn from an enumerated registry, the reported MCR⁻ is an upper bound on the MCR⁻ of any richer class that contains the registry, and MCR⁺ a lower bound on its MCR⁺. The loss used for reliance is the same common-frame loss that decides membership, and the implementation asserts that the two agree to 1e-10.

Fifteen checks ran and had to pass before the implementation read any project data. In a hand-worked case with θ̂ = (1, 2, 3, 6) and a block contribution v = (1, 2, 3, 4), e_orig = 1, the sum over ordered pairs is 80 − 4 = 76, e_switch = 76/12 and MR = 19/3, and the implementation reproduces that value. The closed form matches brute force over all ordered pairs to 1e-9 under additive, row-scaled and multiplicative transformations and under imputation with m = 5. Reliance is exactly 1 for a zero or constant contribution, and in the population case θ = x + e with unit variances, where MR tends to 3, a sample of 400,000 gives 2.9931.

## A.5 Direct and shared reliance

The total importance score divides each disadvantage measure's reliance into a part that is its own and a part that rests on information correlated measures also carry. For a model and measure j, let vⱼ be the measure's contribution to the linear predictor, the columns of its basis multiplied by their coefficients, so that a spline basis is permuted as a unit. Regress vⱼ on the other nine contributions with an intercept,

$$ vⱼ = α₀ + Σ_{k≠j} αₖvₖ + eⱼ,   v̂ⱼ = vⱼ − eⱼ.

Marginal reliance MR_marg(j) permutes vⱼ whole, while direct reliance MR_dir(j) permutes only the residual eⱼ, the part of the measure that no combination of the others reconstructs, and holds v̂ⱼ fixed; the switched prediction, in which hospital i keeps its own value of v̂ⱼ and takes another hospital's residual, keeps the separable form Bᵢ + CᵢVⱼ with v̂ⱼ folded into Bᵢ, so it too is computed exactly. The difference Δⱼ = MR_marg(j) − MR_dir(j) is the part of the measure's apparent reliance that comes from its correlations. Because the least-squares projection satisfies Var(v̂ⱼ) = Σₖ αₖ Cov(vₖ, vⱼ), Δⱼ divides among the neighbors as a flow table,

$$ F[j, k] = Δⱼ αₖ Cov(vₖ, vⱼ) / Σ_{k′≠j} αₖ′ Cov(vₖ′, vⱼ),   with Σ_{k≠j} F[j, k] = Δⱼ,

and the share of measure j's reliance that is shared is Δⱼ/(MR_marg(j) − 1), reported as zero when Δⱼ is not positive. The total importance score credits measure k with its direct reliance and with the positive flows from k into every other measure,

$$ TIS(k) = MR_dir(k) + Σ_{j≠k} max(F[j, k], 0),

computed separately for each of the 194 models in the Rashomon set and reported as a median and range. A measure of pure noise scores 1, and a noise measure correlated with a real signal receives a small credit from the flow table but no direct reliance, so it ranks below any measure that carries signal of its own.

The flows, and Δ itself, can be negative in this application. The usual guarantee that Δⱼ ≥ 0 holds when the model is the least-squares fit to the same data on which reliance is computed, because the normal equations then remove the cross-terms. No specification in this project meets that condition, since each is fitted on its own frame (weighted, subsampled, un-shrunk or logged) and scored on the common evaluation frame, and 41.3% of the measure-by-model values of Δ are negative. A negative Δ means that a measure's correlations lower its apparent reliance, the pattern known as suppression. The score takes the positive part of each flow for that reason, and a signed version that sums the flows without truncation is reported beside it.

Thirty checks ran before any project data were read. The decomposition MR_marg = MR_dir + Δ and the flow identity Σₖ F[j, k] = Δⱼ hold exactly in a correlated synthetic design, and a measure orthogonal to the others has Δ = 0. When X₁ = 0.8X₂ + 0.6ξ, the reconstructable share of X₁ returns as 0.64, and all of Δ₁ flows to X₂. When X₁ = 0.6X₂ + 0.8X₃ plus noise, with X₂ and X₃ uncorrelated, the flow must divide 0.36 to 0.64, and it divides 0.361 to 0.639. A measure that its neighbors reconstruct exactly has MR_dir = 1, and the contribution-space formulas reduce exactly to the single-column formulas when a measure has one column. The Shapley decomposition of R² used for comparison is computed exactly over all 2¹⁰ subsets of the ten measures and sums to R².

## A.6 The variance decomposition and the payment quantities

The variance decomposition assigns to each of the K = 3 covariate blocks its average gain in explained variance over every order of entry,

$$ φ_b = Σ_{S ⊆ blocks∖{b}} [|S|! (K − |S| − 1)! / K!] [R²(S ∪ {b}) − R²(S)],

so that the three shares sum to the R² of the model with all three blocks. On the composite, R² is the ordinary or reliability-weighted coefficient of determination. On the components, the quantity divided is the hospital variance component of the null mixed model, and each block's share is the reduction in that component it accounts for. Intervals come from 1,000 bootstrap resamples, of hospitals for the composite and of whole Hospital Service Areas for the components, since resampling hospitals into Service Areas would place duplicate hospitals in one area and understate the variation between hospitals.

In the payment simulation, hospital i's eligible revenue is Eᵢ = NPRᵢ × cᵢ, its net patient revenue multiplied by its commercial share. Its safety score Sᵢ combines the standardized PSI-90 (winsorized at the 5th and 95th percentiles) with weight w = 0.15 and the mean of its standardized infection measures with weight 1 − w, and its position is Pᵢ = 1 − rank(Sᵢ)/n, so that the safest hospitals have the highest positions. The bonus rate rises linearly with position,

$$ rᵢ = 0.001 + 0.039 Pᵢ,

from 0.1% to 4% of eligible revenue, and in the threshold variant rᵢ = 0 for Pᵢ < 0.25 and 0.001 + 0.039(Pᵢ − 0.25)/0.75 above it. The incentive to improve is Mᵢ = Eᵢ × w × 0.039, a fixed 0.585% of eligible revenue for every hospital, so that per dollar of net patient revenue it equals 0.00585 cᵢ and varies only with commercial share. The concentration index of a quantity hᵢ along a ranking is

$$ C = 2 Cov(hᵢ, Rᵢ) / h̄,   Rᵢ = (rankᵢ − 0.5)/n,

with the ranking oriented so that a higher Rᵢ means more improvement headroom or a more disadvantaged catchment. A negative C means the quantity is concentrated among hospitals ranked low, so a negative index for the incentive to improve, with a 95% interval over the simulation draws that excludes zero, is the pre-registered condition for calling the formula structurally regressive along that ranking, a statement about the arithmetic of the formula alone.
