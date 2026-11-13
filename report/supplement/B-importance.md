# B. Direct and shared reliance (exploratory)

The total importance score (TIS) divides each disadvantage measure's reliance into a part that is its own and a part that rests on information correlated measures also carry, and from that split it ranks the measures. The September draft used the ranking to recommend a minimum community dataset. An external review found that the implementation scored each measure inside a model that had lost the other nine disadvantage measures, so the reliance it reported was not the fitted model's; the repair, its checks and the rerun are below. After the repair no measure is tagged essential or substitutable under the threshold fixed in advance (only the limited-English share's unique part clears it, at the primary tolerance alone), the September recommendation does not survive, and no finding in the main report rests on this method. It is reported here as exploratory, with its lineage.

## B.1 The method

For a model in the Rashomon set and disadvantage measure j, let vⱼ be the measure's contribution to the linear predictor (the columns of its basis multiplied by their coefficients, so a spline basis is permuted as a unit). Regress vⱼ on the other nine contributions with an intercept,

$$ vⱼ = α₀ + Σ_{k≠j} αₖvₖ + eⱼ,   v̂ⱼ = vⱼ − eⱼ.

Marginal reliance MR_marg(j) permutes vⱼ whole; direct reliance MR_dir(j) permutes only the residual eⱼ, the part of the contribution not explained by this linear projection on the other nine contributions, and holds v̂ⱼ fixed. Being orthogonal to that projection is not the same as being independent of the other measures given everything else, so permuting eⱼ is not a draw from the measure's conditional distribution, and "direct" means only "outside the linear projection". On the log scale the contributions that enter the regression are the exponentiated ones, exp(vⱼ), because those are the factors the prediction multiplies; the definition above is therefore on the linear-predictor scale for identity-scale specifications and on the exponentiated scale for log-scale ones. Both use the exact ordered-pair computation of section A.4, which requires the switched prediction in the form Bᵢ + CᵢVⱼ. The repair concerns what goes into Bᵢ and Cᵢ. The fixed part for measure j must be the full model minus measure j alone: on the identity scale Bᵢ = B0ᵢ + C0ᵢ Σ_{k≠j} vₖᵢ with Cᵢ = C0ᵢ, and on the log scale Bᵢ = B0ᵢ with Cᵢ = C0ᵢ Π_{k≠j} exp(vₖᵢ), where B0 and C0 carry everything outside the ten measures (and, for errors-in-variables specifications, the re-shrinkage). For direct reliance, v̂ⱼ is folded into Bᵢ as well. For imputed specifications the fixed part is built within each completion and then pooled. The September implementation used B0 and C0 for every measure, which dropped the other nine contributions.

The difference Δⱼ = MR_marg(j) − MR_dir(j) is the part of the measure's apparent reliance that comes from its correlations. Because the least-squares projection satisfies Var(v̂ⱼ) = Σₖ αₖ Cov(vₖ, vⱼ), Δⱼ divides among the neighbors as a flow table,

$$ F[j, k] = Δⱼ αₖ Cov(vₖ, vⱼ) / Σ_{k′≠j} αₖ′ Cov(vₖ′, vⱼ),   with Σ_{k≠j} F[j, k] = Δⱼ,

and the shared share of measure j is Δⱼ/(MR_marg(j) − 1), reported as zero when Δⱼ is not positive. The score credits measure k with its direct reliance and the positive flows from k into every other measure,

$$ TIS(k) = MR_dir(k) + Σ_{j≠k} max(F[j, k], 0),

computed for each of the 194 models in the Rashomon set and reported as a median and range; TIS_net, which sums the flows without truncation, is reported beside it. The method allocates all of Δⱼ by the projection's terms. The derivation it descends from allocates the cross-term of the decomposition separately, and that separate allocation was not computed. The flow table is an accounting identity for this projection, not a validated attribution of shared information, and the method has not been defended well enough for its tags to support decisions about which data to collect.

## B.2 Checks

Three invariants are checked on all 736 composite specifications on every run, and the stage stops if any fails or if any passes on the September implementation. The prediction rebuilt from the fixed part and vⱼ equals the model's own prediction (worst case 1.78e-15 against a tolerance of `1e-10`); the baseline loss equals the loss that decided Rashomon membership (worst 5.00e-15); and marginal reliance equals the model class reliance computation of section A.4 in all 7,360 specification-by-measure pairs (worst 1.35e-13). On the September implementation the third invariant failed in most of those pairs.

In synthetic data with two independent predictors, where marginal reliance tends to 3, the repaired code gives 2.9251 and 3.0858 against 1.9392 and 2.0686 from the September code. A proxy whose model coefficient is exactly zero has direct reliance 1 and ranks below the signal it copies. The method has one known property that the checks log rather than test: when a proxy's coefficient is fitted rather than fixed at zero (true value 0, estimate near zero), the flow split, which does not depend on the size of the neighbor's coefficient, hands the proxy the signal's whole Δ, so the proxy's TIS (2.2764) exceeds the signal's (1.7177). That property is a further reason the ranking is treated as exploratory.

## B.3 Results

Summed over the ten measures, the median model's marginal excess reliance is 0.2006, of which 0.0828 (41.3%) is shared. Δ is negative in 6.4% of measure-by-model pairs. The largest mean flow is to the limited-English share from SVI 3 (+0.0162). TIS and TIS_net rank the measures identically, and the rank correlation of TIS with Shapley shares at the best model is +0.394. Table S2 gives the measures in TIS order, and Figure S3 shows the split.

Table S2. Direct and shared reliance across the 194 models of the primary Rashomon set (medians, with the lowest direct reliance and the TIS range), and the exploratory tag.

| Measure | Marginal | Direct | Lowest direct | Shared share | TIS (range) | Tag |
|---|---|---|---|---|---|---|
| limited-English share | 1.045 | 1.020 | 1.0066 | 52% | 1.039 (1.011 to 1.078) | useful |
| SVI 3 | 1.031 | 1.019 | 1.0020 | 46% | 1.034 (1.010 to 1.073) | useful |
| uninsured share | 1.029 | 1.025 | 1.0000 | 18% | 1.027 (1.002 to 1.058) | optional |
| ICE | 1.018 | 1.006 | 1.0012 | 63% | 1.019 (1.004 to 1.070) | optional |
| SVI 1 | 1.015 | 1.011 | 1.0001 | 19% | 1.018 (1.002 to 1.081) | optional |
| rurality | 1.010 | 1.005 | 1.0001 | 50% | 1.016 (1.007 to 1.040) | useful |
| ADI | 1.009 | 1.004 | 1.0004 | 43% | 1.013 (1.004 to 1.077) | optional |
| SVI 4 | 1.009 | 1.007 | 1.0019 | 13% | 1.010 (1.004 to 1.034) | optional |
| SVI 2 | 1.007 | 1.007 | 1.0000 | 4% | 1.008 (1.004 to 1.033) | optional |
| primary-care density | 1.001 | 1.000 | 0.9992 | 20% | 1.005 (1.001 to 1.014) | optional |

The tags follow the four-tag rule with a practical threshold of 1.005 fixed in advance: a measure is essential if its lowest direct reliance exceeds the threshold and less than half its reliance is shared, substitutable if its lowest direct reliance exceeds the threshold and half or more is shared, useful if only its lowest TIS exceeds the threshold, and optional otherwise, with the lowest values taken over the metropolitan-area set, which contains the primary set. No measure is essential or substitutable. The three useful tags are the closest calls, and each becomes optional as the tolerance widens; at the state tolerance every measure is optional.
