# R/08-clusters.R  --  Task 3.15, clustering on margin and safety maturity.
#
# Reads data/analytic-v2.rds only. Everything this script chooses was fixed in
# provenance/cluster-preregistration.md, committed alone before the first
# mixture was fitted (commit 2d3659b); the section numbers below point back to
# it. Nothing here was changed after a solution was seen.
#
# THE QUESTION is whether hospitals fall into distinct groups on the two axes the
# CASH2 Tracks are stylized on -- operating margin and safety maturity -- not
# whether those groups are the Tracks (that is Task 3.16). One group is an
# admissible answer: every criterion below can return G = 1.
#
# SAFETY MATURITY is PSI-90 in two versions, both reported, neither primary
# (prereg Sec 2): PUBLISHED, which CMS has already shrunk toward the mean, and
# LAMBDA-CORRECTED, un-shrunk as gm + (psi90 - gm)/lambda_i, the transform the
# specification curve's EIV arm uses. Shrinkage tightens the cloud where volume
# is low; un-shrinking undoes that and lets the sampling noise back in. Sec 3
# measures both effects before any clustering is done.
#
# THE CRITERION is ICL over Gaussian mixtures (all 14 mclust covariance models,
# G = 1..9). ICL rather than BIC because BIC selects the best density estimate
# and adds components to fit PSI-90's skew whether or not separate groups exist;
# ICL penalizes overlapping components, so it selects separated groups. BIC's
# pick is printed beside it and does not override it. The gap statistic on
# k-means is an independent check with a different null. Disagreements are
# reported, not resolved (prereg Sec 4).
#
# A THREE-COMPONENT SOLUTION is computed for each version whatever ICL selects,
# because Task 3.16 compares the data against a three-way Track assignment. It
# is labelled FORCED everywhere it appears (prereg Sec 5).
#
# The 100-subsample stability run is the slow part; it is cached in
# data/cluster-stability.rds, keyed on the clustering frame and the settings, and
# CLUSTER_REFIT=1 forces it.
#
# Outputs: data/clusters.rds, output/tables/cluster-selection.csv (ICL and BIC
# for every G x model), output/tables/cluster-summary.csv (the selected G per
# criterion, version and screen), output/tables/cluster-profiles.csv,
# output/tables/cluster-screened.csv, output/tables/cluster-shrinkage.csv,
# output/figures/clusters.png.

suppressMessages({ library(mclust); library(cluster) })

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

SEED   <- 20260923                     # prereg Sec 4
G_RNG  <- 1:9
GAP_B  <- 500
SUB_B  <- 100; SUB_F <- 0.80
SCREEN <- c(primary = -1, sensitivity = -0.5)   # margin >= this (prereg Sec 3)
set.seed(SEED)

hdr("TASK 3.15  clustering on margin and safety maturity")
cat(sprintf("  mclust %s, cluster %s; seed %d; criterion ICL, G = %d..%d, all %d covariance models\n",
            packageVersion("mclust"), packageVersion("cluster"), SEED, min(G_RNG), max(G_RNG),
            length(mclust.options("emModelNames"))))

a <- readRDS(file.path("data", "analytic-v2.rds"))

# ==========================================================================
# 1.  SCREENING, BEFORE ANY CLUSTERING  (prereg Sec 3)
# ==========================================================================
hdr("1. screening -- fixed before clustering")
mg  <- n_(a$operating_margin)
why <- ifelse(is.na(mg) & a$operating_margin_source == "denominator < $1M", "margin NA: net patient revenue < $1M",
       ifelse(is.na(mg), "margin NA: not in HCRIS",
       ifelse(mg < SCREEN[["primary"]], "margin < -1: operating expense > 2x net patient revenue",
       ifelse(mg < SCREEN[["sensitivity"]], "sensitivity screen only: -1 <= margin < -0.5", NA))))
SCR <- data.frame(ccn = a$ccn, name = a$name, state = a$state, operating_margin = mg,
                  psi90 = n_(a$psi90), lambda_i = n_(a$lambda_i), reason = why)[!is.na(why), ]
SCR <- SCR[order(SCR$reason, SCR$operating_margin), ]
print(table(SCR$reason))
cat(sprintf("\n  %d hospitals in the frozen file; primary frame %d, sensitivity frame %d\n", nrow(a),
            sum(!is.na(mg) & mg >= SCREEN[["primary"]]), sum(!is.na(mg) & mg >= SCREEN[["sensitivity"]])))
sub_("the 23 screened at the primary line, worst first")
x <- SCR[grepl("^margin < -1", SCR$reason), ]
print(transform(x[, c("ccn", "name", "state", "operating_margin", "psi90")],
                operating_margin = round(operating_margin, 2), psi90 = round(psi90, 3)), row.names = FALSE)

# ==========================================================================
# 2.  THE INPUTS  (prereg Sec 2)
# ==========================================================================
frame_for <- function(cut) {
  k <- which(!is.na(mg) & mg >= cut)
  p <- n_(a$psi90)[k]; lam <- n_(a$lambda_i)[k]
  gm <- mean(p)
  data.frame(ccn = a$ccn[k], margin = mg[k], psi_pub = p, psi_cor = gm + (p - gm) / lam,
             lambda_i = lam, gm = gm)
}
FR <- lapply(SCREEN, frame_for)
VERS <- c(published = "psi_pub", corrected = "psi_cor")
zmat <- function(f, v) { m <- cbind(margin = f$margin, psi = f[[VERS[[v]]]]); scale(m) }

hdr("2. inputs on the primary frame, natural units")
f <- FR$primary
qq <- function(x) round(quantile(x, c(0, .05, .25, .5, .75, .95, 1)), 3)
print(rbind(margin = qq(f$margin), `PSI-90 published` = qq(f$psi_pub),
            `PSI-90 lambda-corrected` = qq(f$psi_cor)))
cat(sprintf("\n  gm = %.4f; SD published %.4f, corrected %.4f (ratio %.2f); corrected < 0 for %d hospitals\n",
            f$gm[1], sd(f$psi_pub), sd(f$psi_cor), sd(f$psi_cor) / sd(f$psi_pub), sum(f$psi_cor < 0)))
cat(sprintf("  r(margin, PSI-90): published %+.3f, corrected %+.3f\n",
            cor(f$margin, f$psi_pub), cor(f$margin, f$psi_cor)))

# ==========================================================================
# 3.  WHAT SHRINKAGE DOES TO THE CLOUD, BEFORE CLUSTERING  (prereg Sec 6)
# ==========================================================================
hdr("3. spread of PSI-90 by lambda quartile -- the shrinkage prediction")
f$lq <- cut(f$lambda_i, quantile(f$lambda_i, 0:4 / 4), include.lowest = TRUE, labels = paste0("Q", 1:4))
SHR <- do.call(rbind, lapply(levels(f$lq), function(q) { s <- f[f$lq == q, ]
  data.frame(lambda_quartile = q, n = nrow(s), lambda_lo = min(s$lambda_i), lambda_hi = max(s$lambda_i),
             sd_published = sd(s$psi_pub), sd_corrected = sd(s$psi_cor),
             iqr_published = IQR(s$psi_pub), iqr_corrected = IQR(s$psi_cor)) }))
print(SHR, row.names = FALSE, digits = 3)
cat(sprintf("\n  published: lowest-lambda quartile SD is %.2fx the highest's; corrected: %.2fx\n",
            SHR$sd_published[1] / SHR$sd_published[4], SHR$sd_corrected[1] / SHR$sd_corrected[4]))

# ==========================================================================
# 4.  SELECTION  (prereg Sec 4)
# ==========================================================================
best_of <- function(M) { i <- which(M == max(M, na.rm = TRUE), arr.ind = TRUE)[1, ]
  list(G = as.integer(rownames(M)[i[1]]), model = colnames(M)[i[2]], value = M[i[1], i[2]]) }
as_mat <- function(o) { M <- unclass(o)[, , drop = FALSE]; attributes(M) <- attributes(M)[c("dim", "dimnames")]; M }

select_one <- function(X) {
  icl <- as_mat(mclustICL(X, G = G_RNG, verbose = FALSE))
  bic <- as_mat(mclustBIC(X, G = G_RNG, verbose = FALSE))
  bi <- best_of(icl); bb <- best_of(bic)
  ## the forced G = 3: ICL's best covariance model at G = 3
  f3 <- icl["3", ]; m3 <- names(which.max(f3))
  set.seed(SEED)
  gp <- clusGap(X, FUNcluster = kmeans, nstart = 25, iter.max = 50, K.max = max(G_RNG), B = GAP_B,
                d.power = 2, spaceH0 = "scaledPCA", verbose = FALSE)
  kg <- maxSE(gp$Tab[, "gap"], gp$Tab[, "SE.sim"], method = "Tibs2001SEmax")
  list(icl = icl, bic = bic, icl_best = bi, bic_best = bb, gap = gp$Tab, gap_k = kg,
       fit_icl = Mclust(X, G = bi$G, modelNames = bi$model, verbose = FALSE),
       fit_3   = Mclust(X, G = 3, modelNames = m3, verbose = FALSE))
}

hdr("4. selection -- ICL (the criterion), BIC and the gap statistic (reported beside it)")
t0 <- Sys.time()
SEL <- list()
for (sc in names(SCREEN)) for (v in names(VERS)) {
  k <- paste(sc, v, sep = ".")
  SEL[[k]] <- select_one(zmat(FR[[sc]], v))
  s <- SEL[[k]]
  cat(sprintf("  %-22s n=%4d   ICL -> G=%d (%s)   BIC -> G=%d (%s)   gap -> k=%d\n", k, nrow(FR[[sc]]),
              s$icl_best$G, s$icl_best$model, s$bic_best$G, s$bic_best$model, s$gap_k))
}
cat(sprintf("  (%.1f s)\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))

sub_("ICL by G, best covariance model at each G, primary screen")
icl_by_G <- function(s) apply(s$icl, 1, max, na.rm = TRUE)
bic_by_G <- function(s) apply(s$bic, 1, max, na.rm = TRUE)
print(round(rbind(`ICL published` = icl_by_G(SEL$primary.published), `ICL corrected` = icl_by_G(SEL$primary.corrected),
                  `BIC published` = bic_by_G(SEL$primary.published), `BIC corrected` = bic_by_G(SEL$primary.corrected)), 1))
sub_("gap statistic, primary screen")
print(round(rbind(`gap published` = SEL$primary.published$gap[, "gap"], `SE published` = SEL$primary.published$gap[, "SE.sim"],
                  `gap corrected` = SEL$primary.corrected$gap[, "gap"], `SE corrected` = SEL$primary.corrected$gap[, "SE.sim"]), 4))

# ==========================================================================
# 5.  SELECTION STABILITY OVER 80% SUBSAMPLES  (prereg Sec 4)
# ==========================================================================
hdr(sprintf("5. stability -- ICL's G over %d subsamples of %s, primary screen", SUB_B, pct(SUB_F, 0)))
ST_PATH <- file.path("data", "cluster-stability.rds")
stability_run <- function() sapply(names(VERS), function(v) {
  X <- zmat(FR$primary, v); set.seed(SEED)
  vapply(seq_len(SUB_B), function(b) {
    i <- sample.int(nrow(X), floor(SUB_F * nrow(X)))
    best_of(as_mat(mclustICL(X[i, ], G = G_RNG, verbose = FALSE)))$G }, integer(1)) })
## keyed (Task S0.3) on the frame's contents, the settings, and the text of the
## functions the subsamples run -- not on this file, so editing the report does
## not force an 80-minute re-run. CLUSTER_REFIT=1 forces one.
if (!exists("cache_key")) source(file.path("R", "cache-key.R"))
frame_f <- tempfile(fileext = ".rds")
saveRDS(FR$primary[, c("ccn", "margin", "psi_pub", "psi_cor")], frame_f, version = 3)
key <- cache_key(character(0),
                 list(stability_run = stability_run, zmat = zmat, best_of = best_of, as_mat = as_mat),
                 list(frame = sha256_file(frame_f), G = G_RNG, B = SUB_B, f = SUB_F, seed = SEED,
                      vers = VERS, mclust = as.character(packageVersion("mclust"))))
unlink(frame_f)
if (cache_fresh(ST_PATH, key, "CLUSTER_REFIT")) {
  ST <- readRDS(ST_PATH)
} else {
  t0 <- Sys.time()
  ST <- list(G = stability_run())
  cache_save(ST, ST_PATH, key)
  cat(sprintf("  computed in %.1f min, cached\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
for (v in names(VERS)) {
  g0 <- SEL[[paste0("primary.", v)]]$icl_best$G
  tb <- table(factor(ST$G[, v], levels = G_RNG))
  cat(sprintf("  %-10s full-frame G=%d; agreement %s; subsample G distribution: %s\n", v, g0,
              pct(mean(ST$G[, v] == g0)), paste(sprintf("%d:%d", G_RNG, tb)[tb > 0], collapse = "  ")))
}

# ==========================================================================
# 6.  PROFILES  (prereg Sec 6)
# ==========================================================================
profile_of <- function(fit, fr, label) {
  cl <- fit$classification
  ## order clusters by mean published PSI-90 so labels read best -> worst safety
  o <- order(tapply(fr$psi_pub, cl, mean)); cl <- match(cl, o)
  P <- do.call(rbind, lapply(sort(unique(cl)), function(j) { s <- fr[cl == j, ]
    data.frame(solution = label, cluster = j, n = nrow(s), share = nrow(s) / nrow(fr),
               margin_mean = mean(s$margin), margin_median = median(s$margin),
               psi_pub_mean = mean(s$psi_pub), psi_pub_median = median(s$psi_pub),
               psi_cor_mean = mean(s$psi_cor), psi_cor_median = median(s$psi_cor),
               lambda_mean = mean(s$lambda_i),
               mean_uncertainty = mean(fit$uncertainty[cl == j])) }))
  list(P = P, cl = cl)
}
hdr("6. cluster profiles, primary screen (clusters ordered by mean published PSI-90, best first)")
PR <- list(); ASG <- data.frame(ccn = FR$primary$ccn)
for (v in names(VERS)) {
  s <- SEL[[paste0("primary.", v)]]
  for (w in c("selected", "forced3")) {
    fit <- if (w == "selected") s$fit_icl else s$fit_3
    lab <- sprintf("%s %s G=%d (%s)", v, if (w == "selected") "ICL-selected" else "FORCED", fit$G, fit$modelName)
    p <- profile_of(fit, FR$primary, lab)
    PR[[paste(v, w)]] <- p$P; ASG[[paste(v, w, sep = "_")]] <- p$cl
    sub_(lab)
    print(transform(p$P[, -1], share = pct(share)), row.names = FALSE, digits = 3)
  }
}
PROF <- do.call(rbind, PR)

sub_("sensitivity screen (margin >= -0.5): profiles of the ICL-selected solutions")
for (v in names(VERS)) {
  s <- SEL[[paste0("sensitivity.", v)]]
  p <- profile_of(s$fit_icl, FR$sensitivity, sprintf("sensitivity %s ICL-selected G=%d (%s)", v, s$fit_icl$G, s$fit_icl$modelName))
  PROF <- rbind(PROF, p$P)
  cat(sprintf("  %s: G=%d (%s)\n", v, s$fit_icl$G, s$fit_icl$modelName))
  print(transform(p$P[, -1], share = pct(share)), row.names = FALSE, digits = 3)
}

sub_("agreement between the published and corrected forced-3 assignments")
tb <- table(published = ASG$published_forced3, corrected = ASG$corrected_forced3); print(tb)
cat(sprintf("  adjusted Rand index %.3f\n", adjustedRandIndex(ASG$published_forced3, ASG$corrected_forced3)))

# ==========================================================================
# 7.  OUTPUTS
# ==========================================================================
long_crit <- function(M, crit, sc, v) data.frame(screen = sc, version = v, criterion = crit,
  G = as.integer(rep(rownames(M), ncol(M))), model = rep(colnames(M), each = nrow(M)), value = as.vector(M))
SELT <- do.call(rbind, lapply(names(SEL), function(k) { p <- strsplit(k, ".", fixed = TRUE)[[1]]
  rbind(long_crit(SEL[[k]]$icl, "ICL", p[1], p[2]), long_crit(SEL[[k]]$bic, "BIC", p[1], p[2]),
        data.frame(screen = p[1], version = p[2], criterion = "gap", G = G_RNG, model = "kmeans",
                   value = SEL[[k]]$gap[, "gap"])) }))
SUMT <- do.call(rbind, lapply(names(SEL), function(k) { p <- strsplit(k, ".", fixed = TRUE)[[1]]; s <- SEL[[k]]
  data.frame(screen = p[1], version = p[2], n = nrow(FR[[p[1]]]),
             icl_G = s$icl_best$G, icl_model = s$icl_best$model, bic_G = s$bic_best$G,
             bic_model = s$bic_best$model, gap_k = s$gap_k,
             stability_agree = if (p[1] == "primary") mean(ST$G[, p[2]] == s$icl_best$G) else NA) }))

dir.create(file.path("output", "figures"), showWarnings = FALSE, recursive = TRUE)
write.csv(SELT, file.path("output", "tables", "cluster-selection.csv"), row.names = FALSE)
write.csv(SUMT, file.path("output", "tables", "cluster-summary.csv"), row.names = FALSE)
write.csv(PROF, file.path("output", "tables", "cluster-profiles.csv"), row.names = FALSE)
write.csv(SCR,  file.path("output", "tables", "cluster-screened.csv"), row.names = FALSE)
write.csv(SHR,  file.path("output", "tables", "cluster-shrinkage.csv"), row.names = FALSE)
saveRDS(list(frame = FR, assignments = ASG, summary = SUMT, profiles = PROF, stability = ST$G,
             selection = lapply(SEL, function(s) s[c("icl", "bic", "icl_best", "bic_best", "gap", "gap_k")]),
             prereg = "provenance/cluster-preregistration.md"),
        file.path("data", "clusters.rds"))

## figure: top row the two clouds coloured by ICL's selection; bottom row the
## criteria against G, with G = 3 marked so a reader sees where Three would sit
png(file.path("output", "figures", "clusters.png"), width = 1500, height = 1250, res = 130)
op <- par(mfrow = c(2, 2), mar = c(4.2, 4.4, 3, 1), mgp = c(2.4, 0.7, 0))
pal <- c("#2b6cb0", "#c05621", "#2f855a", "#6b46c1", "#b7791f", "#c53030", "#319795", "#97266d", "#4a5568")
fr <- FR$primary
for (v in names(VERS)) {
  s <- SEL[[paste0("primary.", v)]]; cl <- ASG[[paste0(v, "_selected")]]
  y <- fr[[VERS[[v]]]]
  plot(fr$margin, y, pch = 16, cex = 0.45, col = adjustcolor(pal[cl], 0.55),
       xlab = "operating margin (HCRIS FY2023)",
       ylab = if (v == "published") "PSI-90, published (shrunk)" else "PSI-90, lambda-corrected (un-shrunk)",
       main = sprintf("%s: ICL selects G = %d (%s); gap k = %d", v, s$icl_best$G, s$icl_best$model, s$gap_k),
       cex.main = 0.95)
  abline(h = fr$gm[1], v = median(fr$margin), col = "grey60", lty = 3)
}
for (crit in c("ICL", "gap")) {
  yy <- sapply(names(VERS), function(v) { s <- SEL[[paste0("primary.", v)]]
    if (crit == "ICL") icl_by_G(s) else s$gap[, "gap"] })
  if (crit == "ICL") yy <- sweep(yy, 2, apply(yy, 2, max))    # relative to each version's best
  matplot(G_RNG, yy, type = "b", pch = 16, lty = 1, col = c("#2b6cb0", "#c05621"), xlab = "G (components / k)",
          ylab = if (crit == "ICL") "ICL minus its maximum" else "gap statistic",
          main = if (crit == "ICL") "ICL by G (best covariance model at each G)" else "gap statistic by k (k-means, B = 500)",
          cex.main = 0.95)
  abline(v = 3, col = "grey60", lty = 3)
  legend(if (crit == "ICL") "bottomleft" else "bottomright", c("published", "lambda-corrected"),
         col = c("#2b6cb0", "#c05621"), pch = 16, bty = "n", cex = 0.85)
}
par(op); invisible(dev.off())
cat("\n  wrote output/tables/cluster-{selection,summary,profiles,screened,shrinkage}.csv,",
    "output/figures/clusters.png, data/clusters.rds\n")
