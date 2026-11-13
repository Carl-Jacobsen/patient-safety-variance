# R/03-variance-decomposition.R  --  Task 3.3, the community / structure /
# residual split, and the one-sentence-with-a-number statement (Plan.md Sec 10,
# task sheet "done and good": "a JHF reader can state in one sentence, with a
# number attached, how much between-hospital PSI variation tracks community
# disadvantage rather than hospital characteristics").
#
# Reads data/analytic-v2.rds and output/models/task3.2-models.rds (Task 3.2's
# frozen fits, make.R stage 21 -- reused for cross-reference, not as the
# source of any NEW number reported here; every share and CI below is
# recomputed fresh in this script).
#
# THE METHOD: Task 3.1 found Block A and Block B entangled (wage_index~adi
# r=-0.66) and Block B internally collinear -- attributing a shared-variance
# split to "structure" or "community" by adding blocks in a fixed order is
# order-dependent and would misattribute exactly the variance Task 3.1 said
# is shared. The fix here is the same one the literature uses for this exact
# problem (Lindeman/Merenda/Gold 1980; "LMG"/Shapley-value decomposition): the
# marginal contribution of each block is averaged over all orderings in which
# it could be added, which is symmetric by construction and requires no
# assumption about which block "gets credit" for shared variance. With three
# blocks that is 6 orderings over 8 subset models (nothing, A, B, C, AB, AC,
# BC, ABC) -- computed once, memoised, reused across all 6 orderings.
#
# TWO decompositions, for two different reasons:
#  1. THE COMPOSITE (psi90), reported TWICE -- the published score, unweighted
#     (plain OLS; PRIMARY, Task S2.1) and, beside it, reliability-weighted
#     (WLS, weights = lambda_i; a SENSITIVITY analysis). lambda_i is the
#     project's scalar approximation to CMS's smoothing (Task 2.2), not a
#     quantity CMS reports. Weighting does not undo smoothing; it changes
#     which hospitals dominate the variance being decomposed, so the two
#     estimate different descriptive allocations and the gap between them is
#     NOT a measure of what the smoothing conceals (review 2026-10-01,
#     "Recast the reliability and variance findings"). The two always appear
#     together.
#  2. THE COMPONENTS model (Task 3.2's PRIMARY fit, on the four components,
#     which carry no composite smoothing), decomposing the between-hospital
#     variance component itself (var_hospital, the `ccn:hsa` term) the same
#     LMG way. A different target from the composite's, reported with equal
#     prominence (Task S2.1): its community share is not distinguishable
#     from zero.
#
# Task S2.1 (second pass) reordered every printout, the table and the
# statement so that the published score leads, and dropped the reading of the
# weighted-minus-unweighted gap as hidden signal. Shares and intervals are
# unchanged; only order, labels and the statement moved.
#
# Uncertainty: nonparametric bootstrap (hospitals resampled with replacement)
# for the composite, B = 1000, cheap (~5ms/lm fit). For the components model,
# a CLUSTER bootstrap over the top level of the nesting: HSAs resampled with
# replacement, each drawn HSA taken whole and relabelled (HSA and its ccns) so
# a cluster drawn twice enters as two independent clusters. B = 1000, ~3 s/rep
# (~50 min), cached in data/variance-decomp-boot.rds; VD_REFIT=1 forces.
#
# AMENDMENT 2026-09-28 (Task 5.1 follow-up): the original components bootstrap
# resampled HOSPITALS into their true HSA, B = 150. A hospital drawn twice then
# puts two identical copies in one HSA, which the (1 | hsa/ccn) model reads as
# HSA-level signal: over 25 draws var(ccn:hsa) in the null model fell from
# 0.306 to 0.121 and var(hsa) rose from 0.051 to 0.254, inflating every share
# (structure 0.19 vs point 0.075) -- which is why the interval excluded its own
# point estimate. Resampling whole HSAs reproduces the point-estimate variance
# components (0.303 / 0.052). Point estimates and the composite side unchanged.
# See provenance/task3.3-variance-decomposition.md, amendment 1.
#
# Outputs: R/03-variance-decomposition.R, output/tables/variance-
# decomposition.csv (both composite versions + the components model),
# output/figures/variance-decomposition.png, and the candidate sentence.

suppressMessages(library(lme4))

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
zsc  <- function(x, mu, sd) (x - mu) / sd

set.seed(20260902)

# ==========================================================================
hdr("TASK 3.3  variance decomposition -- community vs structure vs residual")

a      <- readRDS(file.path("data", "analytic-v2.rds"))
mods32 <- readRDS(file.path("output", "models", "task3.2-models.rds"))
N <- nrow(a)
cat(sprintf("  frame n = %d hospitals; cross-referencing Task 3.2 (make.R stage 21) fits, not reusing them for new numbers\n", N))

# ==========================================================================
# 1.  VARIABLE BLOCKS -- identical to R/03-baseline.R (same cmi_level fix:
#     cmi_level is an exact duplicate of Block A's cmi, r=1, dropped there
#     and here for the same reason -- see 03-baseline.R's comment).
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
        hhi_zip = "hhi_zip")

bC <- c(cmi_drift = "cmi_drift", contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")

blocks <- list(structure = names(bA), community = names(bB), policy = names(bC))
CONT   <- c(bA[bA != "teaching"], bB, bC)
zpar   <- sapply(CONT, function(cn) c(mu = mean(n_(a[[cn]]), na.rm = TRUE),
                                      sd = sd(n_(a[[cn]]), na.rm = TRUE)))

## a generic Shapley/LMG share calculator -- averages the marginal
## contribution of each block over every ordering in which it can be added.
## `charfun(vars)` is any "how much does this set of covariates explain"
## function (weighted R2 for the composite, between-hospital variance
## reduction for the mixed model); memoised so each of the 8 subsets is
## evaluated exactly once regardless of how many of the 6 orderings use it.
permutations <- function(x) {
  if (length(x) <= 1) return(list(x))
  out <- list()
  for (i in seq_along(x)) for (p in permutations(x[-i])) out[[length(out) + 1]] <- c(x[i], p)
  out
}
shapley_shares <- function(blocks, charfun) {
  nm <- names(blocks); cache <- new.env()
  key <- function(s) if (length(s) == 0) "EMPTY_SET" else paste(sort(s), collapse = "+")
  val <- function(s) { k <- key(s)
    if (!exists(k, envir = cache, inherits = FALSE)) assign(k, charfun(unlist(blocks[s], use.names = FALSE)), envir = cache)
    get(k, envir = cache, inherits = FALSE) }
  perms <- permutations(nm)
  shares <- setNames(numeric(length(nm)), nm)
  for (p in perms) {
    prev <- character(0); prevV <- val(character(0))
    for (b in p) { curV <- val(c(prev, b)); shares[b] <- shares[b] + (curV - prevV)
                   prev <- c(prev, b); prevV <- curV }
  }
  list(shares = shares / length(perms), full = val(nm), empty = val(character(0)))
}

# ==========================================================================
# 2.  THE COMPOSITE -- LMG shares, uncorrected (OLS) vs corrected (WLS, lambda_i)
# ==========================================================================
hdr("2  composite (psi90) -- LMG decomposition, published score (primary) and reliability-weighted (sensitivity)")

comp_d <- a
for (nm in setdiff(names(bA), "teaching")) comp_d[[nm]] <- zsc(n_(a[[bA[[nm]]]]), zpar["mu", nm], zpar["sd", nm])
for (nm in names(bB)) comp_d[[nm]] <- zsc(n_(a[[bB[[nm]]]]), zpar["mu", nm], zpar["sd", nm])
for (nm in names(bC)) comp_d[[nm]] <- zsc(n_(a[[bC[[nm]]]]), zpar["mu", nm], zpar["sd", nm])
comp_d$teaching <- as.numeric(a$teaching)

## ALL 8 subset models are fit on the SAME sample (complete-case for Block C's
## contract_labor_share) so every R2 in the LMG average is comparable -- an
## R2 computed on a different N is not on the same scale.
## Complete-case across EVERY variable in ANY of the three blocks, not just
## contract_labor_share -- lm() silently drops rows missing any variable in
## its OWN formula, so unless every subset is restricted to a single common
## sample up front, the 8 R2's the LMG average compares are each computed on
## a slightly different N and are not actually comparable. This matches Task
## 3.2 Sec 7's ABC complete-case N exactly (2,569) -- a direct cross-check.
comp_cc <- comp_d[stats::complete.cases(comp_d[, c(names(bA), names(bB), names(bC))]), ]
cat(sprintf("  common sample for all 8 subset fits (complete-case across ALL Block A+B+C variables): n = %d\n", nrow(comp_cc)))

r2_of <- function(vars, data, w) {
  if (length(vars) == 0) return(0)
  f <- as.formula(paste("psi90 ~", paste(vars, collapse = " + ")))
  summary(lm(f, data = data, weights = w))$r.squared
}

lmg_composite <- function(w) shapley_shares(blocks, function(vars) r2_of(vars, comp_cc, w))

## object names kept from Task 3.3: `uncorrected` = the published score,
## unweighted (PRIMARY); `corrected` = reliability-weighted (SENSITIVITY)
res_uncorrected <- lmg_composite(rep(1, nrow(comp_cc)))
res_corrected   <- lmg_composite(comp_cc$lambda_i)

print_lmg <- function(res, label) {
  sub_(label)
  for (b in names(res$shares))
    cat(sprintf("  %-10s share = %.4f  (%.1f%% of R2 = %.4f)\n",
                b, res$shares[b], 100 * res$shares[b] / res$full, res$full))
  cat(sprintf("  R2(full model)      = %.4f\n", res$full))
  cat(sprintf("  residual (1 - R2)   = %.4f\n", 1 - res$full))
}
print_lmg(res_uncorrected, "PRIMARY: published score, unweighted (OLS, weights = 1)")
print_lmg(res_corrected,   "SENSITIVITY: reliability-weighted (WLS, weights = lambda_i, scalar approximation)")

cat(sprintf("\n  difference in community's share (weighted - unweighted) = %+.4f  (%+.2f points)\n",
            res_corrected$shares["community"] - res_uncorrected$shares["community"],
            100 * (res_corrected$shares["community"] - res_uncorrected$shares["community"])))
cat("  The two are different descriptive allocations of variation in the published\n")
cat("  score: weighting changes which hospitals dominate the variance, it does not undo\n")
cat("  smoothing. The difference is not read as community signal the smoothing hid.\n")

## ---- bootstrap CIs, composite side (hospitals resampled with replacement) --
B1 <- 1000
cat(sprintf("\n  bootstrapping composite LMG shares, B = %d (hospitals resampled with replacement)...\n", B1))
boot_composite <- function(w_is_lambda) {
  out <- matrix(NA_real_, B1, 4, dimnames = list(NULL, c("structure", "community", "policy", "residual")))
  for (i in seq_len(B1)) {
    idx <- sample(nrow(comp_cc), replace = TRUE)
    db  <- comp_cc[idx, ]
    wb  <- if (w_is_lambda) db$lambda_i else rep(1, nrow(db))
    r   <- shapley_shares(blocks, function(vars) r2_of(vars, db, wb))
    out[i, ] <- c(r$shares, 1 - r$full)
  }
  out
}
t0 <- Sys.time()
boot_unc <- boot_composite(FALSE)
boot_cor <- boot_composite(TRUE)
cat(sprintf("  done in %.1f s\n", as.numeric(Sys.time() - t0, units = "secs")))

ci <- function(m) apply(m, 2, quantile, c(.025, .975))
ci_unc <- ci(boot_unc); ci_cor <- ci(boot_cor)

# ==========================================================================
# 3.  THE COMPONENTS MODEL -- LMG on the between-hospital variance component
# ==========================================================================
hdr("3  components model (Task 3.2's primary fit) -- LMG on var(hospital)")

COMPS <- c("psi03", "psi06", "psi12", "psi13")
ypar <- sapply(COMPS, function(cp) c(mu = mean(n_(a[[cp]]), na.rm = TRUE), sd = sd(n_(a[[cp]]), na.rm = TRUE)))

build_long <- function(d) {
  rows <- lapply(COMPS, function(cp) {
    r <- data.frame(ccn = d$ccn, hsa = d$hsa, psi = cp,
                     y = zsc(n_(d[[cp]]), ypar["mu", cp], ypar["sd", cp]),
                     w = n_(d[[paste0(cp, "_denom")]]), stringsAsFactors = FALSE)
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
  ## October 7 audit A1: every covariate of every block observed, so all eight
  ## subset models are fitted to the same component rows. Without this each
  ## lmer() call dropped the rows missing ITS terms, and the Shapley average
  ## credited blocks with changes of sample (10,619 rows for the null model,
  ## 9,782 for the full one).
  L <- L[stats::complete.cases(L[, c(names(bA), names(bB), names(bC))]), ]
  L$w <- L$w / mean(L$w)
  L
}
long_cc <- build_long(a)
## the declared frame: the composite's 2,569 hospitals, nothing else
stopifnot(setequal(unique(long_cc$ccn), comp_cc$ccn))
cat(sprintf("  components frame (complete on every covariate of every block): %d component rows from %d hospitals,\n",
            nrow(long_cc), length(unique(long_cc$ccn))))
cat("  the same hospitals as the composite decomposition\n")
ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

vc_of <- function(m) { v <- as.data.frame(VarCorr(m)); setNames(v$vcov, ifelse(is.na(v$var2), v$grp, paste(v$grp, v$var2, sep = ":"))) }
var_hosp <- function(vars, data) {
  f <- if (length(vars) == 0) y ~ psi + (1 | hsa/ccn) else
       as.formula(paste("y ~ psi +", paste(vars, collapse = " + "), "+ (1 | hsa/ccn)"))
  m <- lmer(f, data = data, weights = w, REML = TRUE, control = ctrl)
  ## audit A1 invariant: no subset model may drop a row of the declared frame
  if (nobs(m) != nrow(data)) stop(sprintf("subset {%s} fitted %d of %d rows", paste(vars, collapse = ","), nobs(m), nrow(data)))
  vc_of(m)["ccn:hsa"]
}

t0 <- Sys.time()
lmg_mixed <- shapley_shares(blocks, function(vars) {
  v0 <- var_hosp(character(0), long_cc)             # var_hospital of the null model, held fixed
  v0 - var_hosp(vars, long_cc)                       # REDUCTION in var_hospital -- the "explained" quantity
})
cat(sprintf("  8-subset fit (point estimate) in %.1f s\n", as.numeric(Sys.time() - t0, units = "secs")))

var_hosp_null <- var_hosp(character(0), long_cc)
mixed_shares_norm <- lmg_mixed$shares / var_hosp_null   # fraction of the null model's between-hospital variance
mixed_residual    <- 1 - sum(mixed_shares_norm)          # unexplained by any admitted block

sub_("components model -- share of the NULL model's between-hospital variance (var_hospital) explained")
for (b in names(mixed_shares_norm))
  cat(sprintf("  %-10s share = %.4f  (%.1f%% of var_hospital(null) = %.5f)\n",
              b, mixed_shares_norm[b], 100 * mixed_shares_norm[b], var_hosp_null))
cat(sprintf("  residual (unexplained hospital variance) = %.4f  (%.1f%%)\n", mixed_residual, 100 * mixed_residual))
## Task 3.2's null model is fitted to all 2,801 hospitals; this one, since the
## audit A1 repair, to the 2,569 of the declared frame, so the two now differ
## by design and the comparison is printed, not tested
cat(sprintf("\n  Task 3.2's stage 21 null model (all hospitals): var_hospital = %.5f; this frame's: %.5f\n",
            mods32$variance_components$var_hospital[mods32$variance_components$model == "null"], var_hosp_null))

## ---- cluster bootstrap, components side (HSAs resampled whole) ----------
B2 <- 1000
SEED2 <- 20260928
BOOT2F <- file.path("data", "variance-decomp-boot.rds")
if (!exists("cache_key")) source(file.path("R", "cache-key.R"))
cat(sprintf("\n  bootstrapping components-model LMG shares, B = %d (cluster bootstrap: HSAs resampled with\n", B2))
cat("  replacement, each drawn HSA taken whole and relabelled, so a cluster drawn twice enters as\n")
cat("  two independent clusters)...\n")
## audit A1: HSAs are drawn from the declared frame, so every replicate holds
## only frame hospitals and build_long()'s complete-case step drops nothing
A_FR <- a[a$ccn %in% comp_cc$ccn, ]
HSAS <- unique(A_FR$hsa)
stopifnot(!anyNA(HSAS))
resample_stack <- function() {
  pick <- sample(HSAS, length(HSAS), replace = TRUE)
  rows <- split(seq_len(nrow(A_FR)), A_FR$hsa)[pick]
  ab <- A_FR[unlist(rows, use.names = FALSE), ]
  k  <- rep(seq_along(pick), lengths(rows))
  ab$hsa <- paste0(ab$hsa, "_c", k)                  # each drawn cluster copy is its own HSA
  ab$ccn <- paste0(ab$ccn, "_c", k)
  build_long(ab)
}
boot_run <- function() {
  set.seed(SEED2)
  out <- matrix(NA_real_, B2, 4, dimnames = list(NULL, c("structure", "community", "policy", "residual")))
  for (i in seq_len(B2)) {
    Lb <- resample_stack()
    r  <- shapley_shares(blocks, function(vars) { v0 <- var_hosp(character(0), Lb); v0 - var_hosp(vars, Lb) })
    v0 <- var_hosp(character(0), Lb)
    out[i, ] <- c(r$shares / v0, 1 - sum(r$shares / v0))
  }
  out
}
## keyed (Task S0.3) on the analytic file, the settings, and the text of every
## function the draws run -- not on this file, so editing a printed line does
## not re-draw 85 minutes of bootstrap. VD_REFIT=1 forces a redraw.
key2 <- cache_key(file.path("data", "analytic-v2.rds"),
                  list(boot_run = boot_run, resample_stack = resample_stack, build_long = build_long,
                       shapley_shares = shapley_shares, var_hosp = var_hosp),
                  list(B = B2, seed = SEED2, scheme = "hsa-cluster, whole HSA relabelled", blocks = blocks))
if (cache_fresh(BOOT2F, key2, "VD_REFIT")) {
  boot_mixed <- readRDS(BOOT2F)$boot
} else {
  t0 <- Sys.time()
  boot_mixed <- boot_run()
  cat(sprintf("  done in %.1f s (%.2f s/rep)\n", as.numeric(Sys.time() - t0, units = "secs"),
              as.numeric(Sys.time() - t0, units = "secs") / B2))
  cache_save(list(boot = boot_mixed, built = Sys.time()), BOOT2F, key2)
}
cat(sprintf("  failed replicates: %d of %d\n", sum(!complete.cases(boot_mixed)), B2))
cat(sprintf("  bootstrap mean vs point: %s\n", paste(sprintf("%s %.4f vs %.4f", c("structure", "community", "policy"),
            colMeans(boot_mixed, na.rm = TRUE)[1:3], mixed_shares_norm[c("structure", "community", "policy")]), collapse = "; ")))
ci_mixed <- apply(boot_mixed, 2, quantile, c(.025, .975), na.rm = TRUE)
inside <- sapply(c("structure", "community", "policy"), function(b)
  mixed_shares_norm[b] >= ci_mixed[1, b] && mixed_shares_norm[b] <= ci_mixed[2, b])
cat(sprintf("  point estimate inside its own 95%% interval: %s -- %s\n",
            paste(sprintf("%s %s", names(inside), ifelse(inside, "yes", "NO")), collapse = ", "),
            if (all(inside)) "PASS" else "FAIL"))

# ==========================================================================
# 3b. WHAT THE SHARES DO NOT TEST, AND WHAT THEY ARE NOT  (October 7 audit)
# ==========================================================================
hdr("3b  paired differences and the other community quantities (audit A3, A12)")

## A12: overlapping marginal intervals do not test a difference. The paired
## difference, structure minus community, from the same bootstrap replicates.
pdiff <- function(m) { d <- m[, "structure"] - m[, "community"]; d <- d[is.finite(d)]
  c(est = NA_real_, lo = unname(quantile(d, .025)), hi = unname(quantile(d, .975)), share_pos = mean(d > 0)) }
DIFF <- rbind(
  data.frame(source = "composite, published unweighted", t(pdiff(boot_unc))),
  data.frame(source = "composite, reliability-weighted", t(pdiff(boot_cor))),
  data.frame(source = "components", t(pdiff(boot_mixed))))
DIFF$est <- c(res_uncorrected$shares["structure"] - res_uncorrected$shares["community"],
              res_corrected$shares["structure"] - res_corrected$shares["community"],
              mixed_shares_norm["structure"] - mixed_shares_norm["community"])
for (i in seq_len(nrow(DIFF)))
  cat(sprintf("  %-34s structure - community = %+.4f  (paired 95%% interval %+.4f to %+.4f; %.1f%% of replicates > 0)\n",
              DIFF$source[i], DIFF$est[i], DIFF$lo[i], DIFF$hi[i], 100 * DIFF$share_pos[i]))

## A3: the Shapley share is an average increment in R2 over orders of entry.
## It is not the variance of the fitted community term, not the community block
## alone, not the block added last, and not a bound on any adjustment. The
## four quantities, from the same OLS fit, to show they differ.
f_full <- lm(as.formula(paste("psi90 ~", paste(c(names(bA), names(bB), names(bC)), collapse = " + "))), data = comp_cc)
X_B <- model.matrix(f_full)[, names(bB), drop = FALSE]
fit_B <- drop(X_B %*% coef(f_full)[names(bB)])
ALT <- data.frame(quantity = c("shapley_share", "alone", "added_last", "fitted_term_var", "fitted_term_sd"),
                  value = c(res_uncorrected$shares["community"],
                            r2_of(names(bB), comp_cc, rep(1, nrow(comp_cc))),
                            res_uncorrected$full - r2_of(c(names(bA), names(bC)), comp_cc, rep(1, nrow(comp_cc))),
                            var(fit_B) / var(comp_cc$psi90),
                            sd(fit_B) / sd(comp_cc$psi90)))
for (i in seq_len(nrow(ALT))) cat(sprintf("  community %-16s %.5f\n", ALT$quantity[i], ALT$value[i]))
cat("  (shares of Var(psi90) except fitted_term_sd, in outcome SDs; they answer different questions)\n")
write.csv(rbind(data.frame(kind = "paired_difference", key = DIFF$source, est = DIFF$est, lo = DIFF$lo, hi = DIFF$hi),
                data.frame(kind = "community_quantity", key = ALT$quantity, est = ALT$value, lo = NA, hi = NA)),
          file.path("output", "tables", "variance-decomposition-extra.csv"), row.names = FALSE)

# ==========================================================================
# 4.  THE VARIANCE-DECOMPOSITION TABLE
# ==========================================================================
hdr("4  the deliverable -- output/tables/variance-decomposition.csv")

mk_rows <- function(source, version, shares, ci_mat) {
  data.frame(source = source, version = version,
             block = c("structure", "community", "policy", "residual"),
             share = c(unname(shares["structure"]), unname(shares["community"]),
                      unname(shares["policy"]), unname(1 - shares["structure"] - shares["community"] - shares["policy"])),
             ci_lo = ci_mat[1, c("structure", "community", "policy", "residual")],
             ci_hi = ci_mat[2, c("structure", "community", "policy", "residual")],
             row.names = NULL)
}
VD <- rbind(
  mk_rows("composite (psi90)", "published, unweighted (OLS) -- primary", res_uncorrected$shares, ci_unc),
  mk_rows("composite (psi90)", "reliability-weighted (WLS, scalar lambda_i) -- sensitivity", res_corrected$shares, ci_cor),
  mk_rows("components (Task 3.2 model form, declared frame)", "between-hospital variance component (components carry no composite smoothing)",
          mixed_shares_norm, ci_mixed))
write.csv(VD, file.path("output", "tables", "variance-decomposition.csv"), row.names = FALSE)
print(VD)

# ==========================================================================
# 5.  FIGURE
# ==========================================================================
## Residual runs 88-91% in both decompositions and would swamp the bars a
## reader actually needs to compare (structure vs community vs policy) --
## dropped from the chart itself and reported instead as a text annotation,
## with the y-axis zoomed to the three explanatory blocks.
png(file.path("output", "figures", "variance-decomposition.png"), width = 1300, height = 650, res = 130)
par(mfrow = c(1, 2), mar = c(5, 4.5, 4, 1))

bar_panel <- function(shares_list, cis_list, labels, title, cols, resid_pct) {
  blk <- c("structure", "community", "policy")
  M <- sapply(shares_list, function(s) s[blk])
  ymax <- max(sapply(cis_list, function(x) max(x["97.5%", blk], na.rm = TRUE)), 0.08, na.rm = TRUE) * 1.15
  bp <- barplot(M, beside = TRUE, col = cols, ylim = c(0, ymax),
                names.arg = labels, legend.text = blk, args.legend = list(x = "topright", bty = "n", cex = 0.75),
                ylab = "share of Var(psi90) / var(hospital)", main = title, cex.main = 0.95, cex.names = 0.85, las = 1)
  for (j in seq_along(shares_list)) for (i in seq_along(blk)) {
    lo <- cis_list[[j]]["2.5%", blk[i]]; hi <- cis_list[[j]]["97.5%", blk[i]]
    if (is.finite(lo) && is.finite(hi)) arrows(bp[i, j], lo, bp[i, j], hi, angle = 90, code = 3, length = 0.03)
  }
  mtext(resid_pct, side = 3, line = 0.2, cex = 0.7, col = "#00000099")
}
bar_panel(list(uncorrected = res_uncorrected$shares, corrected = res_corrected$shares),
          list(uncorrected = ci_unc, corrected = ci_cor),
          c("published,\nunweighted", "reliability-\nweighted"), "Composite (psi90)",
          c("#8a9a5b", "#6b8fb3", "#b08968"),
          sprintf("residual (unexplained): %s unweighted, %s weighted -- not shown, bars would dwarf these",
                  pct(1 - res_uncorrected$full), pct(1 - res_corrected$full)))

bar_panel(list(components = mixed_shares_norm), list(components = ci_mixed),
          "components model", "Components model (share of null var(hospital))",
          c("#8a9a5b", "#6b8fb3", "#b08968"),
          sprintf("residual (unexplained hospital variance): %s -- not shown, bar would dwarf these", pct(mixed_residual)))
dev.off()
cat("\n  figure -> output/figures/variance-decomposition.png\n")

# ==========================================================================
# 6.  THE STATEMENT (Plan.md Sec 10), published score first (Task S2.1)
# ==========================================================================
hdr("6  the statement -- published score first, weighted beside it, components with equal weight")

## `share` is an LMG share of TOTAL Var(psi90) -- "how much of the variation
## tracks X" -- not a share of R2. The share of the explained part answers the
## "rather than" half and is the secondary number. Task S2.1: the published
## score leads; the reliability-weighted share sits in the same statement as
## a share of reliability-weighted variation; the components share follows
## with the same prominence; the residual is stated as conditional.
u_c <- res_uncorrected$shares["community"]; u_s <- res_uncorrected$shares["structure"]
w_c <- res_corrected$shares["community"]
k_c <- mixed_shares_norm["community"]
sentence <- sprintf(paste0(
  "The community block (Block B: the ten disadvantage and access measures and market concentration) is associated with an estimated %s (95%% interval %s to %s) of the ",
  "variation in published PSI-90 across hospitals, against %s (%s to %s) for hospital structure (Block A); ",
  "of the %s the three blocks explain together, community accounts for %s and structure for %s. ",
  "Weighting each hospital by its reliability under the project's scalar approximation gives %s (%s to %s) ",
  "of reliability-weighted variation, a different descriptive allocation rather than a correction. ",
  "On the four component measures, community accounts for %s (%s to %s) of the between-hospital variance, ",
  "an interval that includes zero. The %s left unexplained is conditional on these linear covariates, the ",
  "complete-case frame and squared-error loss; it is not the share of harm unrelated to hospitals or communities."),
  pct(u_c), pct(ci_unc["2.5%", "community"]), pct(ci_unc["97.5%", "community"]),
  pct(u_s), pct(ci_unc["2.5%", "structure"]), pct(ci_unc["97.5%", "structure"]),
  pct(res_uncorrected$full), pct(u_c / res_uncorrected$full), pct(u_s / res_uncorrected$full),
  pct(w_c), pct(ci_cor["2.5%", "community"]), pct(ci_cor["97.5%", "community"]),
  pct(k_c, 2), pct(ci_mixed["2.5%", "community"], 2), pct(ci_mixed["97.5%", "community"], 2),
  pct(1 - res_uncorrected$full))
cat("\n  ", sentence, "\n", sep = "")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. community/structure/residual split reported, with uncertainty (bootstrap CIs) -- PASS\n"))
## Task S2.1: the weighted result never without the unweighted one, the
## published score first, the components beside them, and none of the
## shrinkage-recovery readings the review retired.
pos <- function(x) regexpr(x, sentence, fixed = TRUE)[1]
order_ok <- pos(pct(u_c)) > 0 && pos(pct(w_c)) > pos(pct(u_c)) && pos(pct(k_c, 2)) > 0
banned <- c("conceal", "reveal", "recover", "hidden", "hides", "corrected", "un-shrunk", "unshrunk")
hit <- banned[vapply(banned, function(b) grepl(b, sentence, ignore.case = TRUE), logical(1))]
tbl_ok <- identical(VD$version[c(1, 5)], c("published, unweighted (OLS) -- primary",
                                           "reliability-weighted (WLS, scalar lambda_i) -- sensitivity"))
cat(sprintf("  2. published score first, weighted beside it, components in the same statement -- %s\n",
            if (order_ok && tbl_ok) "PASS" else "FAIL"))
cat(sprintf("  3. statement free of the retired shrinkage-recovery wording (%d terms) -- %s\n",
            length(banned), if (!length(hit)) "PASS" else paste("FAIL:", paste(hit, collapse = ", "))))
stopifnot(nrow(VD) == 12, all(is.finite(VD$share)), order_ok, tbl_ok, !length(hit),
          abs(sum(res_uncorrected$shares) + (1 - res_uncorrected$full) - 1) < 1e-9,
          abs(sum(res_corrected$shares)   + (1 - res_corrected$full)   - 1) < 1e-9)

hdr("done")
