# R/15-contrast-support.R  --  Task S2.5, the support of the joint disadvantage
# contrast. make.R stage 41. POST-REVIEW, run as fixed in
# provenance/second-pass-preregistration.md sec 7 ("Contrast support").
#
# The focal estimate of every specification (R/04-spec-curve.R) moves all ten
# disadvantage measures together from their oriented 10th to their oriented
# 90th percentile. The review asked whether any catchment looks like either end
# of that move. This stage measures it, and replaces the synthetic move with
# moves between observed catchments where the synthetic one is off support.
#
#   1. SUPPORT. Mahalanobis distance of the two synthetic profiles (all ten at
#      the least-deprived end; all ten at the most-deprived end) from the center
#      of the observed catchments, over the ten measures on the model frame; the
#      share of observed catchments at least as far out; and the distance to the
#      nearest observed catchment, against the observed catchments' own
#      nearest-neighbor distances. At every grain, and for the material-only and
#      composition-only moves as well as the joint one.
#   2. CONTRASTS, on P-best (spec 382) and its three grain siblings (344, 420,
#      458; same settings, other grains), all four members of the primary set:
#        joint synthetic p10 -> p90 (reproduces the stored estimate first);
#        material-deprivation measures only, the rest at the center;
#        demographic-composition measures only, the rest at the center;
#        OBSERVED: the median catchment of the bottom decile of a score against
#        the median catchment of its top decile, all ten measures at those two
#        catchments' own values -- for the material-deprivation score and the
#        composition score.
#      Every contrast holds Block A and Block C at the reference (0), as the
#      harness does, and is reported in SDs of PSI-90 with its standard error.
#
# Groups (pre-registration sec 7): material deprivation = ADI, ICE, SVI 1,
# SVI 4, uninsured share; composition = SVI 2, SVI 3, limited-English share;
# rurality and primary-care density apart. A score is the mean of its
# measures, standardized on the frame and signed by DIS_SIGN (+ = more deprived).
#
# Rule fixed before the run: the rewrite uses an observed contrast wherever
# fewer than 5% of observed catchments are as far from the center as the
# synthetic profile.
#
# Output: output/tables/contrast-support.csv (one row per grain x quantity), the log.

suppressMessages(library(splines))
n_   <- function(x) suppressWarnings(as.numeric(x))
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK S2.5  support of the joint disadvantage contrast -- stage 41 (post-review)")

a   <- readRDS(file.path("data", "analytic-v2.rds"))
reg <- readRDS(file.path("data", "spec-registry.rds"))
SR  <- readRDS(file.path("data", "spec-results.rds"))$results
SUPPORT_RULE <- 0.05

bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy", resident_to_bed = "resident_to_bed",
        teaching = "teaching", cmi = "cmi", volume = "volume_bills", dsh_pct = "dsh_pct",
        wage_index = "wage_index", operating_margin = "operating_margin",
        uncomp_care = "uncompensated_care_pct_npr")
bC <- c(cmi_drift = "cmi_drift", contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")
BB <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng", "rurality", "pcp_density", "hhi")
DIS_SIGN <- c(svi1 = 1, svi2 = 1, svi3 = 1, svi4 = 1, adi = 1, ice150 = -1,
              uninsured = 1, limeng = 1, rurality = 1, pcp_density = -1)
DIS <- names(DIS_SIGN)
SPLINE_SET <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng")
MATERIAL <- c("adi", "ice150", "svi1", "svi4", "uninsured")
COMPOSITION <- c("svi2", "svi3", "limeng")
APART <- c("rurality", "pcp_density")
stopifnot(setequal(c(MATERIAL, COMPOSITION, APART), DIS))
SUFFIX <- c(catch_tract = "_catch_tract", catch_county = "_catch_county", hosp_county = "_county", hsa = "_hsa")
bcol <- function(b, g) if (b == "hhi") (if (g == "hsa") "hhi_hsa" else "hhi_zip") else paste0(b, SUFFIX[[g]])
SPECS <- c(catch_county = 382, catch_tract = 344, hosp_county = 420, hsa = 458)
for (g in names(SPECS)) { s <- reg[reg$spec_id == SPECS[[g]], ]
  stopifnot(s$grain == g, s$blocks == "ABC", s$form == "spline", s$reliability == "unweighted",
            s$missing == "complete", s$scale == "identity", s$influential == "all", s$outcome == "composite") }
sd_psi90 <- sd(n_(a$psi90), na.rm = TRUE)          # the dis_std divisor (R/05-rashomon-set.R)

## frame-wide standardization and knots on the whole analytic file, as the
## harness computes them (this stage scores fitted models, it does not validate)
zpar <- function(cl) { x <- n_(a[[cl]]); c(mu = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE)) }
zq   <- function(cl) quantile(n_(a[[cl]]), c(.10, .90), na.rm = TRUE, names = FALSE)

## the design for one grain; rows given as a data frame of raw columns
make_design <- function(g) {
  cols <- c(bA, setNames(vapply(BB, bcol, character(1), g = g), BB), bC)
  Z <- sapply(cols[names(cols) != "teaching"], zpar)
  KN <- lapply(setNames(SPLINE_SET, SPLINE_SET), function(b) {
    z <- (n_(a[[cols[[b]]]]) - Z["mu", b]) / Z["sd", b]
    list(k = signif(quantile(z, c(.25, .5, .75), na.rm = TRUE, names = FALSE), 8),
         bk = signif(quantile(z, c(.05, .95), na.rm = TRUE, names = FALSE), 8))
  })
  ## X from z-unit values (a data frame with one column per term, in z units)
  X_of <- function(zd) {
    out <- list(`(Intercept)` = rep(1, nrow(zd)))
    for (k in names(bA)) out[[k]] <- zd[[k]]
    for (b in BB) if (b %in% SPLINE_SET) {
      B <- ns(zd[[b]], knots = KN[[b]]$k, Boundary.knots = KN[[b]]$bk)
      for (j in seq_len(ncol(B))) out[[paste0(b, "_ns", j)]] <- B[, j]
    } else out[[b]] <- zd[[b]]
    for (k in names(bC)) out[[k]] <- zd[[k]]
    do.call(cbind, out)
  }
  ## raw rows -> z-unit frame
  z_of <- function(d) {
    zd <- data.frame(row.names = seq_len(nrow(d)))
    for (k in names(cols)) zd[[k]] <- if (k == "teaching") n_(d$teaching)
                                     else (n_(d[[cols[[k]]]]) - Z["mu", k]) / Z["sd", k]
    zd
  }
  list(cols = cols, Z = Z, X_of = X_of, z_of = z_of)
}

# ==========================================================================
# 1.  FIT THE FOUR MEMBERS AND REPRODUCE THEIR STORED CONTRASTS
# ==========================================================================
sub_("fit spec 382 and its grain siblings; reproduce the stored joint contrast")
## each grain is built inside its own function call: a closure made in a bare
## top-level loop would capture the LAST grain's D, b and V (the first draft of
## this stage did exactly that; the closure check below now guards it)
build_grain <- function(g) {
  D <- make_design(g)
  ok <- is.finite(n_(a$psi90))
  for (cl in D$cols) ok <- ok & is.finite(n_(a[[cl]]))
  d <- a[ok, ]
  zd <- D$z_of(d); X <- D$X_of(zd); y <- n_(d$psi90)
  m <- lm.fit(X, y)
  b <- m$coefficients; rk <- m$rank
  sig2 <- sum(m$residuals^2) / (nrow(X) - rk)
  keep <- !is.na(b)
  V <- matrix(0, length(b), length(b), dimnames = list(names(b), names(b)))
  V[keep, keep] <- sig2 * chol2inv(qr.R(qr(X[, keep, drop = FALSE])))
  b[!keep] <- 0
  ## a contrast between two z-unit Block B profiles (Block A and C at 0). A
  ## profile may hold several rows (one per catchment); the design rows are then
  ## averaged, so the contrast is the mean difference in the model's Block B part
  contrast <- function(hi, lo) {
    xbar <- function(p) {
      n <- length(p[[1]])
      Z0 <- as.data.frame(lapply(setNames(names(D$cols), names(D$cols)), function(k) rep(0, n)))
      for (k in names(p)) Z0[[k]] <- p[[k]]
      colMeans(D$X_of(Z0))
    }
    cv <- xbar(hi) - xbar(lo)
    ## the model is additive in the measures, so the contrast splits exactly by
    ## which measures' columns carry it
    part <- function(set) { cols <- grep(paste0("^(", paste(set, collapse = "|"), ")(_ns[0-9]+)?$"), names(cv))
      sum(cv[cols] * b[cols]) / sd_psi90 }
    c(est = sum(cv * b) / sd_psi90, se = sqrt(as.numeric(t(cv) %*% V %*% cv)) / sd_psi90,
      part_material = part(MATERIAL), part_composition = part(COMPOSITION), part_apart = part(APART))
  }
  ## the oriented synthetic ends, in z units
  qz <- sapply(DIS, function(k) (zq(D$cols[[k]]) - D$Z["mu", k]) / D$Z["sd", k])
  most  <- setNames(ifelse(DIS_SIGN > 0, qz[2, ], qz[1, ]), DIS)
  least <- setNames(ifelse(DIS_SIGN > 0, qz[1, ], qz[2, ]), DIS)
  joint <- contrast(as.list(most), as.list(least))
  st <- SR[SR$spec_id == SPECS[[g]], ]
  ref <- c(est = st$dis_effect / sd_psi90, se = st$dis_se / sd_psi90)
  cat(sprintf("  %-12s spec %3d  n %4d  joint %+.6f (stored %+.6f)  se %.6f (stored %.6f)\n", g, SPECS[[g]],
              nrow(X), joint["est"], ref["est"], joint["se"], ref["se"]))
  stopifnot(abs(joint["est"] - ref["est"]) < 1e-8, abs(joint["se"] - ref["se"]) < 1e-8)
  list(D = D, d = d, zd = zd, contrast = contrast, most = most, least = least, joint = joint)
}
FIT <- lapply(setNames(names(SPECS), names(SPECS)), build_grain)
## closure check: each grain's stored contrast function, called now, still
## gives that grain's stored joint estimate
for (g in names(FIT)) {
  re <- FIT[[g]]$contrast(as.list(FIT[[g]]$most), as.list(FIT[[g]]$least))
  stopifnot(abs(re[["est"]] - SR$dis_effect[SR$spec_id == SPECS[[g]]] / sd_psi90) < 1e-8)
}
cat("  PASS -- all four stored joint contrasts reproduced to 1e-8, and each grain's contrast\n")
cat("          function still reproduces its own after all four are built\n")

# ==========================================================================
# 2.  SUPPORT  --  Mahalanobis distance over the ten measures, model frame
# ==========================================================================
sub_("support: how far each synthetic profile sits from observed catchments")
ROWS <- list()
addrow <- function(...) ROWS[[length(ROWS) + 1]] <<- data.frame(..., stringsAsFactors = FALSE)
mdist <- function(P, mu, Si) { Dv <- sweep(P, 2, mu); sqrt(rowSums((Dv %*% Si) * Dv)) }
for (g in names(FIT)) {
  F <- FIT[[g]]
  M <- as.matrix(F$zd[, DIS])                     # observed catchments, z units, model frame
  mu <- colMeans(M); Si <- solve(cov(M))
  d_obs <- mdist(M, mu, Si)
  ## nearest-neighbor distance among observed catchments (the scale of "near")
  ## October 7 audit A4: chol(Si) returns the upper factor U with t(U) %*% U = Si,
  ## so for ROW vectors x the whitening is x %*% t(U) (|x t(U)|^2 = x Si x'). The
  ## S2.5 run used M %*% U, which is not a Mahalanobis whitening; the radial
  ## distance (mdist) was right, the nearest-neighbor distances were not.
  U <- chol(Si)
  W <- M %*% t(U)                                 # whitened, so Euclidean = Mahalanobis
  ## checked against direct quadratic forms on 200 random pairs of observed rows
  set.seed(20261012)
  pr <- matrix(sample.int(nrow(M), 400, replace = TRUE), ncol = 2)
  qf <- vapply(seq_len(nrow(pr)), function(k) { dv <- M[pr[k, 1], ] - M[pr[k, 2], ]; sqrt(sum((dv %*% Si) * dv)) }, numeric(1))
  ew <- sqrt(rowSums((W[pr[, 1], , drop = FALSE] - W[pr[, 2], , drop = FALSE])^2))
  stopifnot(max(abs(qf - ew)) < 1e-8)
  ## over DISTINCT profiles: at county and HSA grain many hospitals share one
  ## catchment profile, and a zero distance to a twin says nothing about support
  Wu <- unique(round(W, 10))
  nn_obs <- vapply(seq_len(nrow(Wu)), function(i) sqrt(min(colSums((t(Wu[-i, , drop = FALSE]) - Wu[i, ])^2))), numeric(1))
  centre <- setNames(mu, DIS)
  profs <- list(joint = list(most = F$most, least = F$least, set = DIS),
                material = list(set = MATERIAL), composition = list(set = COMPOSITION))
  for (pn in names(profs)) {
    set <- profs[[pn]]$set
    for (end in c("most", "least")) {
      v <- centre; v[set] <- (if (end == "most") F$most else F$least)[set]
      dv <- mdist(matrix(v, 1), mu, Si)
      w <- as.numeric(matrix(v, 1) %*% t(U))
      stopifnot(abs(sqrt(sum((w - colMeans(W))^2)) - dv) < 1e-8)   # the center, whitened, gives the radial distance
      nn <- sqrt(min(colSums((t(W) - w)^2)))
      addrow(grain = g, spec_id = SPECS[[g]], quantity = "support", profile = pn, end = end,
             n_frame = nrow(M), mahalanobis = dv, share_obs_as_far = mean(d_obs >= dv),
             nn_distance = nn, nn_obs_median = median(nn_obs), nn_obs_p95 = unname(quantile(nn_obs, .95)),
             nn_share_obs_as_isolated = mean(nn_obs >= nn), obs_mahalanobis_max = max(d_obs),
             off_support = mean(d_obs >= dv) < SUPPORT_RULE,
             est = NA, se = NA, lo_ccn = NA, hi_ccn = NA, score_lo = NA, score_hi = NA,
             part_material = NA, part_composition = NA, part_apart = NA)
    }
  }
}

# ==========================================================================
# 3.  CONTRASTS  --  synthetic by group, and between observed catchments
# ==========================================================================
## the scores, standardized and signed on each grain's model frame
score_of <- function(zd, set) { S <- sweep(as.matrix(zd[, set, drop = FALSE]), 2, DIS_SIGN[set], `*`)
  S <- scale(S); rowMeans(S) }
## the median catchment of a decile: the hospital whose score is nearest the
## decile's median (ties to the lower CCN, so the pick is reproducible)
median_of_decile <- function(sc, which_dec) {
  dec <- cut(rank(sc, ties.method = "first"), quantile(seq_along(sc), 0:10 / 10), include.lowest = TRUE, labels = FALSE)
  i <- which(dec == which_dec); md <- median(sc[i])
  i[order(abs(sc[i] - md), i)[1]]
}
RAWDIFF <- list()
for (g in names(FIT)) {
  F <- FIT[[g]]
  for (pn in c("material", "composition")) {
    set <- if (pn == "material") MATERIAL else COMPOSITION
    hi <- as.list(setNames(rep(0, length(DIS)), DIS)); lo <- hi     # the rest at the frame-wide center
    hi[set] <- F$most[set]; lo[set] <- F$least[set]
    ce <- F$contrast(hi, lo)
    addrow(grain = g, spec_id = SPECS[[g]], quantity = "synthetic contrast", profile = pn, end = "p10->p90 group only",
           n_frame = nrow(F$zd), mahalanobis = NA, share_obs_as_far = NA, nn_distance = NA, nn_obs_median = NA,
           nn_obs_p95 = NA, nn_share_obs_as_isolated = NA, obs_mahalanobis_max = NA, off_support = NA,
           est = ce[["est"]], se = ce[["se"]], lo_ccn = NA, hi_ccn = NA, score_lo = NA, score_hi = NA,
           part_material = ce[["part_material"]], part_composition = ce[["part_composition"]], part_apart = ce[["part_apart"]])
    sc <- score_of(F$zd, set)
    il <- median_of_decile(sc, 1); ih <- median_of_decile(sc, 10)
    ## all ten measures at the two observed catchments' own values; market
    ## concentration (hhi) stays at the reference, as in the harness's contrast
    hi_o <- as.list(F$zd[ih, DIS]); lo_o <- as.list(F$zd[il, DIS])
    co <- F$contrast(hi_o, lo_o)
    M <- as.matrix(F$zd[, DIS]); mu <- colMeans(M); Si <- solve(cov(M))
    addrow(grain = g, spec_id = SPECS[[g]], quantity = "observed contrast", profile = pn,
           end = "median catchment, top vs bottom decile of the score",
           n_frame = nrow(F$zd), mahalanobis = max(mdist(M[c(il, ih), , drop = FALSE], mu, Si)),
           share_obs_as_far = NA, nn_distance = 0, nn_obs_median = NA, nn_obs_p95 = NA,
           nn_share_obs_as_isolated = NA, obs_mahalanobis_max = NA, off_support = FALSE,
           est = co[["est"]], se = co[["se"]], lo_ccn = F$d$ccn[il], hi_ccn = F$d$ccn[ih],
           score_lo = sc[il], score_hi = sc[ih],
           part_material = co[["part_material"]], part_composition = co[["part_composition"]], part_apart = co[["part_apart"]])
    ## SUPPLEMENTARY, not pre-registered: the same move averaged over every
    ## catchment in the bottom and top deciles, which does not rest on one
    ## hospital's idiosyncratic profile
    dec <- cut(rank(sc, ties.method = "first"), quantile(seq_along(sc), 0:10 / 10), include.lowest = TRUE, labels = FALSE)
    cm <- F$contrast(as.list(F$zd[dec == 10, DIS]), as.list(F$zd[dec == 1, DIS]))
    ## audit A5: cm is a FITTED contrast (the model's prediction averaged over
    ## the deciles' observed community profiles, everything else at reference),
    ## not a difference in observed scores. The raw difference in mean published
    ## PSI-90 between the same deciles is kept beside it, so the two are never
    ## confused.
    RAWDIFF[[paste(g, pn)]] <- (mean(n_(F$d$psi90[dec == 10])) - mean(n_(F$d$psi90[dec == 1]))) / sd_psi90
    addrow(grain = g, spec_id = SPECS[[g]], quantity = "observed contrast, decile means (supplementary)", profile = pn,
           end = "all catchments, top vs bottom decile of the score",
           n_frame = nrow(F$zd), mahalanobis = NA, share_obs_as_far = NA, nn_distance = NA, nn_obs_median = NA,
           nn_obs_p95 = NA, nn_share_obs_as_isolated = NA, obs_mahalanobis_max = NA, off_support = FALSE,
           est = cm[["est"]], se = cm[["se"]], lo_ccn = NA, hi_ccn = NA,
           score_lo = mean(sc[dec == 1]), score_hi = mean(sc[dec == 10]),
           part_material = cm[["part_material"]], part_composition = cm[["part_composition"]], part_apart = cm[["part_apart"]])
  }
  addrow(grain = g, spec_id = SPECS[[g]], quantity = "synthetic contrast", profile = "joint", end = "p10->p90 all ten",
         n_frame = nrow(F$zd), mahalanobis = NA, share_obs_as_far = NA, nn_distance = NA, nn_obs_median = NA,
         nn_obs_p95 = NA, nn_share_obs_as_isolated = NA, obs_mahalanobis_max = NA, off_support = NA,
         est = F$joint[["est"]], se = F$joint[["se"]], lo_ccn = NA, hi_ccn = NA, score_lo = NA, score_hi = NA,
         part_material = F$joint[["part_material"]], part_composition = F$joint[["part_composition"]],
         part_apart = F$joint[["part_apart"]])
}
OUT <- do.call(rbind, ROWS)
OUT$raw_outcome_diff <- NA_real_
isdec <- OUT$quantity == "observed contrast, decile means (supplementary)"
OUT$raw_outcome_diff[isdec] <- unlist(RAWDIFF[paste(OUT$grain[isdec], OUT$profile[isdec])])
OUT$quantity[isdec] <- "fitted contrast over observed decile profiles (supplementary)"
OUT$grain <- factor(OUT$grain, names(SPECS)); OUT <- OUT[order(OUT$grain, OUT$quantity, OUT$profile, OUT$end), ]
OUT$grain <- as.character(OUT$grain); rownames(OUT) <- NULL
write.csv(OUT, file.path("output", "tables", "contrast-support.csv"), row.names = FALSE)

for (g in names(SPECS)) {
  sub_(sprintf("%s  (spec %d)", g, SPECS[[g]]))
  s <- OUT[OUT$grain == g & OUT$quantity == "support", ]
  cat(sprintf("  %-12s %-6s  Mahalanobis %5.2f  observed as far %6.2f%%  nearest observed %5.2f (obs NN median %.2f, p95 %.2f; %5.1f%% as isolated)%s\n",
              s$profile, s$end, s$mahalanobis, 100 * s$share_obs_as_far, s$nn_distance, s$nn_obs_median,
              s$nn_obs_p95, 100 * s$nn_share_obs_as_isolated, ifelse(s$off_support, "  OFF SUPPORT", "")), sep = "")
  cat(sprintf("  (largest observed distance from the center: %.2f; frame n = %d)\n", s$obs_mahalanobis_max[1], s$n_frame[1]))
  k <- OUT[OUT$grain == g & OUT$quantity != "support", ]
  cat(sprintf("  %-46s %-12s %+.3f SD (se %.3f)  [material %+.3f, composition %+.3f, rurality+pcp %+.3f]%s\n",
              k$quantity, k$profile, k$est, k$se, k$part_material, k$part_composition, k$part_apart,
              ifelse(is.na(k$lo_ccn), "", sprintf("   CCN %s -> %s (score %+.2f -> %+.2f)", k$lo_ccn, k$hi_ccn, k$score_lo, k$score_hi))), sep = "")
}

# ==========================================================================
hdr("verify")
J <- OUT[OUT$quantity == "support" & OUT$profile == "joint", ]
cat("  share of observed catchments at least as far from the center as the joint synthetic profile:\n")
for (i in seq_len(nrow(J))) cat(sprintf("    %-12s %-6s %.2f%%  -> %s\n", J$grain[i], J$end[i], 100 * J$share_obs_as_far[i],
                                        if (J$off_support[i]) "below 5%: the rewrite uses an observed contrast" else "5% or more"))
cat("  1. all four stored joint contrasts reproduced before any new quantity -- PASS\n")
cat("  2. material deprivation and composition contrasted separately, synthetic and observed -- PASS\n")
k_ <- OUT[OUT$quantity != "support", ]
stopifnot(max(abs(k_$part_material + k_$part_composition + k_$part_apart - k_$est)) < 1e-10)
cat("  3. every contrast splits exactly into its material, composition and other parts -- PASS\n")
stopifnot(nrow(OUT) == 4 * (6 + 7), all(is.finite(OUT$est[OUT$quantity != "support"])))
hdr("done")
