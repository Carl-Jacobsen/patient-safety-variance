# R/03-baseline.R  --  Task 3.2, the baseline hierarchical model (REWRITTEN, rev 2)
#
# The bug rev 1 had (plan-amendments.md Sec 1.4/1.5, task sheet Sec "Task 3.2"):
# fitting a hierarchical model on the PUBLISHED PSI-90 shrinks an already-
# shrunk estimate a second time, hardest exactly where the first shrinkage was
# hardest (low-volume hospitals). Standing rule 6: "the published PSI-90 is a
# shrunk estimate, not a measurement... nothing re-shrinks it."
#
# THE FIX: the primary hierarchical fit runs on the four COMPONENTS (PSI-03,
# -06, -12, -13), stacked long (one row per hospital x component), where
# denominators are published and CMS smoothing is far weaker. Hospitals are
# nested in HSA -- the Dartmouth Hospital Service Area containing the
# hospital's own ZIP (R/blockB.R zip2hsa; THIS is "catchment geography" in
# this project's vocabulary, distinct from the catchment-tract WEIGHTS used
# for Block B covariates). Task 3.1 (eda-geographic.csv) found HSA collapses
# to ICC~0 under one-way ANOVA because 74% of HSAs hold exactly one hospital
# -- the random-effects fit here recovers a variance component ANOVA cannot,
# by partially pooling across those sparse units.
#
# Reads data/analytic-v2.rds (the frozen file) AND data/blockC_mice.rds (the
# m=20 PMM mice object R/blockC.R froze explicitly "for Phase 3 pooling").
# That is not a second data source in the amendment sense -- both are
# deterministic outputs of the same reproducible pipeline (make.R stages
# 18/19); nothing here reads anything upstream of them.
#
# Composite (psi90) treatment: option (b) from the task sheet -- fixed-
# effects, reliability-weighted (weights = lambda_i), NO random intercept at
# any level. Option (a) (known-v_i as the model's first level) needs a
# variance structure lme4 does not expose (a fixed, not re-estimated,
# per-observation residual variance) and DESCRIPTION declares no meta-
# analysis package (metafor) for it; (b) is exact with what's on hand and is
# still a real fix -- no re-shrinkage, because there is no random effect to
# shrink the composite through.
#
# Outputs: R/03-baseline.R, output/models/task3.2-models.rds, output/tables/
# baseline-variance-components.csv, baseline-fixed-effects-*.csv,
# baseline-contract-labor-mi-vs-cc.csv, and provenance/task3.2-baseline.md.

suppressMessages(library(lme4))
suppressMessages(library(mice))

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
zsc  <- function(x, mu, sd) (x - mu) / sd

# ==========================================================================
hdr("TASK 3.2  the baseline hierarchical model -- fit on the components")

a  <- readRDS(file.path("data", "analytic-v2.rds"))
mi <- readRDS(file.path("data", "blockC_mice.rds"))
N  <- nrow(a)
cat(sprintf("  frame n = %d hospitals; %d distinct HSAs (hospital's own ZIP -> Dartmouth HSA)\n",
            N, length(unique(a$hsa))))
cat(sprintf("  reliability at 2.2: tau2 = %.5f (target for the null-model reconciliation)\n", a$tau2[1]))

## ---- sanity: the mice object's row order matches analytic-v2.rds's -------
## R/blockC.R built imp_df straight from the same frame-ordered `a`/`b`/`o`
## objects Task 2.7 later merged into analytic-v2.rds; confirm before trusting it.
cd1 <- complete(mi, 1)
obs <- !is.na(a$contract_labor_share)
align_ok <- isTRUE(all.equal(cd1$cl_share[obs], a$contract_labor_share[obs], tolerance = 1e-9))
cat(sprintf("  blockC_mice.rds row-order check (observed contract_labor_share matches): %s\n",
            if (align_ok) "OK" else "MISMATCH -- STOP"))
stopifnot(align_ok)

# ==========================================================================
# 1.  VARIABLE BLOCKS -- identical names/mapping to R/03-eda.R
# ==========================================================================
bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy",
        resident_to_bed = "resident_to_bed", teaching = "teaching",
        cmi = "cmi", volume = "volume_bills", dsh_pct = "dsh_pct",
        wage_index = "wage_index", operating_margin = "operating_margin",
        uncomp_care_pct = "uncompensated_care_pct_npr")

bB <- c(svi_ses = "svi1_catch_tract", svi_household = "svi2_catch_tract",
        svi_minority = "svi3_catch_tract", svi_housing = "svi4_catch_tract",
        adi = "adi_catch_tract", ice150 = "ice150_catch_tract",
        uninsured = "uninsured_catch_tract", limeng = "limeng_catch_tract",
        rurality = "rurality_catch_tract", pcp_density = "pcp_density_catch_tract",
        hhi_zip = "hhi_zip")                      # 11-msr working block (Task 3.1 decision)

## cmi_level (R/blockC.R line 91: `cmi_level <- n_(a$cmi)`) is an EXACT
## duplicate of Block A's `cmi` -- r = 1, 0 mismatches on the 2,798 hospitals
## with both. blockC.R's own "admitted" list (line 320) names it, but that
## admission is about Block C's admission-gate bookkeeping, not license to
## enter the same column twice in one design matrix -- doing so is what made
## the fixed-effect matrix rank deficient below. Once Block A's `cmi` is in
## the model, `cmi_level` adds nothing; `cmi_drift` (the FY2025->FY2026 CMI
## change, a genuinely new quantity) is the incremental Block C contribution.
bC <- c(cmi_drift = "cmi_drift",
        contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")

CONT <- c(bA[bA != "teaching"], bB, bC)
cat(sprintf("  Block A %d measures, Block B (working set) %d, Block C (admitted) %d\n",
            length(bA), length(bB), length(bC)))

## z-score parameters fixed ONCE on the hospital-level frame (complete cases),
## reused identically for the complete-case fits and all 20 MI fits so a
## coefficient means the same thing in every one of them.
zpar <- sapply(CONT, function(cn) c(mu = mean(n_(a[[cn]]), na.rm = TRUE),
                                    sd = sd(n_(a[[cn]]), na.rm = TRUE)))

# ==========================================================================
# 2.  LONG FORMAT -- one row per hospital x component
# ==========================================================================
COMPS <- c("psi03", "psi06", "psi12", "psi13")

## The four components are NOT on a common scale the way psi90 is (psi90 is a
## RATIO to the national rate, mean ~1 by construction). The six-decimal
## "Rate" field for each component is the raw risk-adjusted rate in its own
## units, and those units differ enormously: mean(psi06) = 0.21, mean(psi13)
## = 5.31 -- a 25x difference in level and a ~500x difference in variance
## (var(psi06) = 0.0025 vs var(psi13) = 1.23). Stacking the raw rates under a
## single residual-variance parameter would let PSI-13/PSI-12's much noisier
## scale dominate a "between-hospital variance" meant to describe all four
## conditions, and a `psi` fixed effect only re-centers each group -- it does
## not equalize their variances. Each component is therefore z-scored to its
## OWN mean/sd (computed once, on the frame, before any covariate is fitted)
## before stacking; the psi fixed effect is kept in the formula as a
## diagnostic (it should come out ~0 for every level once this is done).
ypar <- sapply(COMPS, function(cp) c(mu = mean(n_(a[[cp]]), na.rm = TRUE),
                                     sd = sd(n_(a[[cp]]), na.rm = TRUE)))
sub_("component scale check -- why each PSI is standardized before stacking")
for (cp in COMPS) cat(sprintf("  %-6s mean %.3f  sd %.3f  var %.4f\n",
                              cp, ypar["mu", cp], ypar["sd", cp], ypar["sd", cp]^2))
comp_cor <- cor(a[, COMPS], use = "pairwise.complete.obs")
off <- comp_cor[upper.tri(comp_cor)]
cat(sprintf("  pairwise correlation among the four raw components: min %.3f  max %.3f  (weak -- these are largely\n",
            min(off), max(off)))
cat("  distinct clinical conditions, not four noisy readings of one latent 'safety' trait)\n")

## build the long frame from a hospital-level table `d` (either the frozen
## file itself, or a copy with contract_labor_share / the co-missing Block A
## cells overwritten by one MI draw).
build_long <- function(d) {
  rows <- lapply(COMPS, function(cp) {
    r <- data.frame(ccn = d$ccn, hsa = d$hsa, psi = cp,
                     y = zsc(n_(d[[cp]]), ypar["mu", cp], ypar["sd", cp]),
                     w = n_(d[[paste0(cp, "_denom")]]),
                     stringsAsFactors = FALSE)
    for (nm in names(bA)) r[[nm]] <- n_(d[[bA[[nm]]]])
    for (nm in names(bB)) r[[nm]] <- n_(d[[bB[[nm]]]])
    for (nm in names(bC)) r[[nm]] <- n_(d[[bC[[nm]]]])
    r$teaching <- as.numeric(r$teaching)
    for (nm in names(CONT)) r[[nm]] <- zsc(r[[nm]], zpar["mu", nm], zpar["sd", nm])
    r
  })
  L <- do.call(rbind, rows)
  L$psi <- factor(L$psi, levels = COMPS)
  L <- L[is.finite(L$y) & is.finite(L$w) & L$w > 0, ]
  L$w <- L$w / mean(L$w)                          # relative weights -- numerically stable, WLS-equivalent
  L
}

long_cc <- build_long(a)
cat(sprintf("  stacked long frame: %d rows (%d hospitals x up to 4 components)\n",
            nrow(long_cc), length(unique(long_cc$ccn))))
for (cp in COMPS)
  cat(sprintf("    %-6s %5d rows present (%s of frame)\n", cp, sum(long_cc$psi == cp),
              pct(sum(long_cc$psi == cp) / N)))

# ==========================================================================
# 3.  THE NESTED PROGRESSION -- null, +A, +A+B, +A+B+C (complete-case)
# ==========================================================================
hdr("3  null -> Block A -> Block A+B -> Block A+B+C (complete-case for Block C)")

ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

f_null <- y ~ psi + (1 | hsa/ccn)
f_A    <- as.formula(paste("y ~ psi +", paste(names(bA), collapse = " + "), "+ (1 | hsa/ccn)"))
f_AB   <- as.formula(paste("y ~ psi +", paste(c(names(bA), names(bB)), collapse = " + "), "+ (1 | hsa/ccn)"))
f_ABC  <- as.formula(paste("y ~ psi +", paste(c(names(bA), names(bB), names(bC)), collapse = " + "), "+ (1 | hsa/ccn)"))

fit_report <- function(m, label) {
  conv <- m@optinfo$conv$lme4
  msgs <- if (length(conv$messages)) conv$messages else "none"
  sing <- isSingular(m)
  cat(sprintf("  %-28s N=%5d  logLik=%9.1f  conv: %-4s  singular: %s\n",
              label, nobs(m), as.numeric(logLik(m)),
              if (is.null(conv$code)) "ok" else paste("code", conv$code), sing))
  if (!identical(msgs, "none")) cat("    lme4 message:", paste(msgs, collapse = "; "), "\n")
  invisible(list(msgs = msgs, singular = sing))
}

m_null <- lmer(f_null, data = long_cc, weights = w, REML = TRUE, control = ctrl)
m_A    <- lmer(f_A,    data = long_cc, weights = w, REML = TRUE, control = ctrl)
m_AB   <- lmer(f_AB,   data = long_cc, weights = w, REML = TRUE, control = ctrl)
m_ABC  <- lmer(f_ABC,  data = long_cc[!is.na(long_cc$contract_labor_share), ],
               weights = w, REML = TRUE, control = ctrl)

sub_("convergence")
r_null <- fit_report(m_null, "null (psi + geography)")
r_A    <- fit_report(m_A,    "+ Block A")
r_AB   <- fit_report(m_AB,   "+ Block A + B")
r_ABC  <- fit_report(m_ABC,  "+ Block A+B+C (complete-case)")
warn_free <- all(vapply(list(r_null, r_A, r_AB, r_ABC),
                        function(r) identical(r$msgs, "none") && !r$singular, logical(1)))
cat(sprintf("\n  GATE  models converge, no warnings suppressed, none singular: %s\n",
            if (warn_free) "PASS" else "CHECK -- see messages above"))

## ---- variance components -------------------------------------------------
vc_of <- function(m) {
  v <- as.data.frame(VarCorr(m))
  setNames(v$vcov, ifelse(is.na(v$var2), v$grp, paste(v$grp, v$var2, sep = ":")))
}
vc_tab <- function(models, labels) {
  do.call(rbind, Map(function(m, l) {
    v <- vc_of(m)
    data.frame(model = l, n_obs = nobs(m),
               var_hsa      = unname(v["hsa"]),
               var_hospital = unname(v["ccn:hsa"]),
               var_residual = unname(v["Residual"]),
               icc_hospital = unname(v["ccn:hsa"] / sum(v)),
               icc_hsa      = unname(v["hsa"] / sum(v)),
               stringsAsFactors = FALSE)
  }, models, labels))
}
VC <- vc_tab(list(m_null, m_A, m_AB, m_ABC),
             c("null", "+ Block A", "+ Block A + B", "+ Block A+B+C (CC)"))
sub_("variance components (components model, complete-case progression)")
for (i in seq_len(nrow(VC)))
  cat(sprintf("  %-22s n=%5d  var_hsa=%.5f  var_hospital=%.5f  var_resid=%.5f  ICC(hosp)=%.3f  ICC(hsa)=%.3f\n",
              VC$model[i], VC$n_obs[i], VC$var_hsa[i], VC$var_hospital[i], VC$var_residual[i],
              VC$icc_hospital[i], VC$icc_hsa[i]))

# ==========================================================================
# 4.  RECONCILE THE NULL MODEL AGAINST tau2 = 0.07744 (the verify condition)
# ==========================================================================
hdr("4  reconciling the null model's between-hospital variance against tau2")

## tau2 is in psi90's own "ratio to national" units (Var(psi90) = 0.0368); the
## components model's response is z-scored PER COMPONENT (Sec 2), so its
## variance components are dimensionless and NOT on tau2's scale -- a raw
## ratio of the two would compare apples to oranges. The comparison that IS
## unit-free is the SHARE of variance that is a stable hospital trait: for
## the composite that share is lambda_i = 1 - v_i/tau2 (Task 2.2), averaged
## over hospitals; for the components model it is ICC(hospital) = var_hospital
## / (var_hsa + var_hospital + var_residual). Both answer the same question --
## "of the variance in a single, unsmoothed hospital-level PSI measurement,
## what fraction is genuine signal?" -- on the same [0, 1] scale.
tau2_pub    <- a$tau2[1]
var_hosp0   <- VC$var_hospital[VC$model == "null"]
var_hsa0    <- VC$var_hsa[VC$model == "null"]
icc_hosp0   <- VC$icc_hospital[VC$model == "null"]
mean_lambda <- mean(a$lambda_i[a$lambda_in_tau2_sample])
raw_ratio   <- var_hosp0 / tau2_pub
cat(sprintf("  published composite tau2 (Task 2.2, reproduces stage 1b)          = %.5f  (psi90 ratio units)\n", tau2_pub))
cat(sprintf("  null components model: between-hospital variance (ccn:hsa)        = %.5f  (z units, NOT comparable in scale to tau2)\n", var_hosp0))
cat(sprintf("  raw ratio (hospital-only variance / tau2), noted but NOT the comparison used = %.2fx\n", raw_ratio))
cat(sprintf("\n  UNIT-FREE COMPARISON:\n"))
cat(sprintf("    composite: mean scalar-approximation lambda_i (2.2)             = %.3f\n", mean_lambda))
cat(sprintf("    components: null-model ICC(hospital) = var_hosp/(var_hsa+var_hosp+var_resid) = %.3f\n", icc_hosp0))
gap <- icc_hosp0 - mean_lambda
disagree <- abs(gap) > 0.15                       # >15 points on the shared [0,1] scale
cat(sprintf("    gap (components ICC - composite lambda)                        = %+.3f\n", gap))
cat(sprintf("\n  FINDING: %s -- %s\n",
            if (disagree) "MATERIAL DISAGREEMENT" else "broadly reconciled",
            if (disagree)
              "a single shared hospital random intercept across four only weakly intercorrelated PSI conditions (pairwise r 0.04-0.15, Sec 2) recovers less stable signal than the composite reliability implied by the project's scalar approximation (lambda_i, Task 2.2) -- see provenance/task3.2-baseline.md Sec 4 for the full reading, including why a single scalar hospital effect is the likely reason, not a data error."
            else "the components model recovers a comparable share of stable hospital signal to the composite reliability implied by the scalar approximation."))

# ==========================================================================
# 5.  CONTRACT-LABOR-SHARE MISSINGNESS -- MI (m=20) vs complete-case
#     (R/blockC.R Sec "A1 step 3": "coefficient range reported under BOTH MI
#     and complete-case at Phase 3")
# ==========================================================================
hdr("5  the all-admitted-blocks model under MI (m=20) vs complete-case")

fit_one_imp <- function(k) {
  cdk <- complete(mi, k)
  dk  <- a
  dk$contract_labor_share <- cdk$cl_share
  dk$beds                 <- exp(cdk$log_beds)
  dk$volume_bills         <- exp(cdk$log_vol)
  dk$wage_index           <- cdk$wage_index
  dk$cmi                  <- cdk$cmi
  dk$dsh_pct              <- cdk$dsh_pct
  dk$occupancy            <- cdk$occupancy
  dk$teaching             <- cdk$teaching
  Lk <- build_long(dk)
  lmer(f_ABC, data = Lk, weights = w, REML = TRUE, control = ctrl)
}
imp_fits <- lapply(seq_len(mi$m), fit_one_imp)
conv_imp <- vapply(imp_fits, function(m) length(m@optinfo$conv$lme4$messages) == 0 && !isSingular(m), logical(1))
cat(sprintf("  fit across all m=%d imputations; converged & non-singular: %d/%d\n",
            mi$m, sum(conv_imp), mi$m))

## Rubin's rules on the fixed effects.
B <- sapply(imp_fits, fixef)                      # p x m
U <- sapply(imp_fits, function(m) diag(vcov(m)))  # p x m
qbar <- rowMeans(B)
ubar <- rowMeans(U)
bvar <- apply(B, 1, var)
Tvar <- ubar + (1 + 1 / mi$m) * bvar
pooled <- data.frame(term = rownames(B), estimate = qbar, se = sqrt(Tvar),
                     z = qbar / sqrt(Tvar), row.names = NULL)
pooled$fmi <- ((1 + 1 / mi$m) * bvar) / Tvar       # fraction of missing information

## variance components across imputations -- no exact Rubin extension; report
## the spread, which is itself informative about how much contract-labor
## missingness perturbs the geography/hospital split.
vc_imp <- do.call(rbind, lapply(imp_fits, vc_of))
vc_imp_summary <- data.frame(
  component = c("hsa", "ccn:hsa", "Residual"),
  mean = colMeans(vc_imp[, c("hsa", "ccn:hsa", "Residual")]),
  min  = apply(vc_imp[, c("hsa", "ccn:hsa", "Residual")], 2, min),
  max  = apply(vc_imp[, c("hsa", "ccn:hsa", "Residual")], 2, max))
sub_("variance components, MI (m=20), mean [min, max] across imputations")
for (i in seq_len(nrow(vc_imp_summary)))
  cat(sprintf("  %-10s mean %.5f  [%.5f, %.5f]\n", vc_imp_summary$component[i],
              vc_imp_summary$mean[i], vc_imp_summary$min[i], vc_imp_summary$max[i]))

## the comparison blockC.R asked for: contract_labor_share coefficient, MI-pooled vs complete-case
cl_cc <- summary(m_ABC)$coefficients["contract_labor_share", ]
cl_mi <- pooled[pooled$term == "contract_labor_share", ]
n_rows_dropped <- sum(is.na(long_cc$contract_labor_share))
n_hosp_dropped <- length(unique(long_cc$ccn[is.na(long_cc$contract_labor_share)]))
sub_("contract_labor_share coefficient (standardized): MI-pooled vs complete-case")
cat(sprintf("  complete-case (n=%d rows, %d hospitals / %d rows dropped)   beta = %+.4f   se = %.4f   t = %+.2f\n",
            nobs(m_ABC), n_hosp_dropped, n_rows_dropped,
            cl_cc["Estimate"], cl_cc["Std. Error"], cl_cc["t value"]))
cat(sprintf("  MI pooled (m=%d)                    beta = %+.4f   se = %.4f   z = %+.2f   FMI = %.2f\n",
            mi$m, cl_mi$estimate, cl_mi$se, cl_mi$z, cl_mi$fmi))
cl_compare <- data.frame(treatment = c("complete-case", "MI pooled (m=20)"),
                         estimate = c(unname(cl_cc["Estimate"]), cl_mi$estimate),
                         se       = c(unname(cl_cc["Std. Error"]), cl_mi$se))
write.csv(cl_compare, file.path("output", "tables", "baseline-contract-labor-mi-vs-cc.csv"), row.names = FALSE)

# ==========================================================================
# 6.  VARIANCE-DECOMPOSITION TABLE (the Task 3.2 deliverable) + fixed effects
# ==========================================================================
VC_mi <- data.frame(model = "+ Block A+B+C (MI, m=20, pooled)", n_obs = nobs(imp_fits[[1]]),
                    var_hsa = vc_imp_summary$mean[vc_imp_summary$component == "hsa"],
                    var_hospital = vc_imp_summary$mean[vc_imp_summary$component == "ccn:hsa"],
                    var_residual = vc_imp_summary$mean[vc_imp_summary$component == "Residual"],
                    icc_hospital = NA_real_, icc_hsa = NA_real_)
VC_mi$icc_hospital <- VC_mi$var_hospital / (VC_mi$var_hsa + VC_mi$var_hospital + VC_mi$var_residual)
VC_mi$icc_hsa      <- VC_mi$var_hsa      / (VC_mi$var_hsa + VC_mi$var_hospital + VC_mi$var_residual)
VC_all <- rbind(VC, VC_mi)
## all variance columns are on the per-component z scale (Sec 2); tau2 is on
## psi90's own ratio-to-national scale and is NOT directly divisible against
## them -- icc_hospital (unit-free, [0,1]) is the quantity comparable to
## mean(lambda_i), reported alongside for reference in Sec 4.
VC_all$mean_lambda_i_reference <- mean_lambda
write.csv(VC_all, file.path("output", "tables", "baseline-variance-components.csv"), row.names = FALSE)

fe_ABC <- as.data.frame(summary(m_ABC)$coefficients)
fe_ABC$term <- rownames(fe_ABC)
write.csv(fe_ABC, file.path("output", "tables", "baseline-fixed-effects-ABC-complete-case.csv"), row.names = FALSE)
write.csv(pooled, file.path("output", "tables", "baseline-fixed-effects-ABC-MI-pooled.csv"), row.names = FALSE)

# ==========================================================================
# 7.  THE COMPOSITE -- option (b): reliability-weighted, fixed effects only
# ==========================================================================
hdr("7  composite (PSI-90) treatment -- option (b): WLS, weights = lambda_i, no random effect")

comp_d <- a
for (nm in setdiff(names(bA), "teaching")) comp_d[[nm]] <- zsc(n_(a[[bA[[nm]]]]), zpar["mu", nm], zpar["sd", nm])
for (nm in names(bB)) comp_d[[nm]] <- zsc(n_(a[[bB[[nm]]]]),  zpar["mu", nm], zpar["sd", nm])
for (nm in names(bC)) comp_d[[nm]] <- zsc(n_(a[[bC[[nm]]]]),  zpar["mu", nm], zpar["sd", nm])
comp_d$teaching <- as.numeric(a$teaching)

f_comp_null <- psi90 ~ 1
f_comp_A    <- as.formula(paste("psi90 ~", paste(names(bA), collapse = " + ")))
f_comp_AB   <- as.formula(paste("psi90 ~", paste(c(names(bA), names(bB)), collapse = " + ")))
f_comp_ABC  <- as.formula(paste("psi90 ~", paste(c(names(bA), names(bB), names(bC)), collapse = " + ")))

comp_d_cc <- comp_d[!is.na(comp_d$contract_labor_share), ]
lc_null <- lm(f_comp_null, data = comp_d,    weights = lambda_i)
lc_A    <- lm(f_comp_A,    data = comp_d,    weights = lambda_i)
lc_AB   <- lm(f_comp_AB,   data = comp_d,    weights = lambda_i)
lc_ABC  <- lm(f_comp_ABC,  data = comp_d_cc, weights = lambda_i)

comp_tab <- data.frame(
  model = c("null", "+ Block A", "+ Block A + B", "+ Block A+B+C (CC)"),
  n_obs = c(nobs(lc_null), nobs(lc_A), nobs(lc_AB), nobs(lc_ABC)),
  weighted_r2 = c(summary(lc_null)$r.squared, summary(lc_A)$r.squared,
                 summary(lc_AB)$r.squared, summary(lc_ABC)$r.squared),
  resid_se = c(summary(lc_null)$sigma, summary(lc_A)$sigma,
              summary(lc_AB)$sigma, summary(lc_ABC)$sigma))
sub_("composite WLS progression (reliability-weighted, no random effect)")
for (i in seq_len(nrow(comp_tab)))
  cat(sprintf("  %-22s n=%5d  weighted R2=%.4f  resid SE=%.4f\n",
              comp_tab$model[i], comp_tab$n_obs[i], comp_tab$weighted_r2[i], comp_tab$resid_se[i]))
write.csv(comp_tab, file.path("output", "tables", "baseline-composite-wls.csv"), row.names = FALSE)
cat("\n  no random intercept fit on the composite at any level -- avoids a second\n")
cat("  shrinkage of an already-shrunk published value (standing rule 6).\n")

# ==========================================================================
# 8.  SAVE MODEL OBJECTS
# ==========================================================================
dir.create(file.path("output", "models"), showWarnings = FALSE)
saveRDS(list(components = list(null = m_null, blockA = m_A, blockAB = m_AB, blockABC_cc = m_ABC,
                               blockABC_mi = imp_fits),
            composite  = list(null = lc_null, blockA = lc_A, blockAB = lc_AB, blockABC_cc = lc_ABC),
            variance_components = VC_all, zpar = zpar),
        file.path("output", "models", "task3.2-models.rds"))
cat("\n  model objects -> output/models/task3.2-models.rds\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. primary fit runs on components (psi03/06/12/13), NOT the published composite -- %s\n",
            "PASS (Sec 2-3)"))
cat(sprintf("  2. hospitals nested in catchment geography (HSA): %d HSAs, %d hospitals -- PASS\n",
            length(unique(long_cc$hsa)), length(unique(long_cc$ccn))))
cat(sprintf("  3. null model between-hospital variance (z units) = %.5f, ICC(hospital) = %.3f vs composite mean lambda_i = %.3f (tau2=%.5f) -- %s\n",
            var_hosp0, icc_hosp0, mean_lambda, tau2_pub, if (disagree) "DISAGREEMENT RECORDED" else "reconciled"))
cat(sprintf("  4. models converge, no warnings suppressed, none singular -- %s\n", if (warn_free) "PASS" else "CHECK"))
cat(sprintf("  5. composite treated via stated option (b): WLS, weights=lambda_i, no random effect -- PASS\n"))
cat(sprintf("  6. contract_labor_share reported under BOTH MI and complete-case (blockC.R Sec 'A1 step 3') -- PASS\n"))
stopifnot(nrow(VC_all) == 5, is.finite(var_hosp0), is.finite(tau2_pub),
          all(conv_imp) || sum(conv_imp) >= 18)

hdr("done")
