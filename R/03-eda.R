# R/03-eda.R  --  Task 3.1, the exploratory pass on the frozen analytic file
#
# Reads data/analytic-v2.rds and NOTHING else (Phase 3 standing rule). Produces:
#
#   1. distributions        -- every outcome and continuous covariate: shape,
#                              skew, and whether a functional-form choice is
#                              forced (Task 3.4 spec axis).
#   2. within-block corr     -- Block A, Block B, Block C intercorrelation.
#   3. Block B collinearity  -- pairwise r, VIF, condition number, PCA, matrix
#                              determinant among SVI themes, ADI, the poverty /
#                              income measures, uninsured rate, and rurality.
#                              THIS is the empirical justification for the TIS
#                              decomposition at Tasks 3.13-3.14: marginal
#                              permutation importance misattributes variance
#                              that several measures share.
#   4. cross-block corr      -- outcome vs every covariate; Block A vs Block B
#                              (the structure / context confounding the whole
#                              decomposition has to separate).
#   5. geographic patterning -- how much PSI-90 variance sits between states,
#                              divisions, CBSAs, HSAs; the outcome gradient
#                              across catchment disadvantage and rurality.
#
# Base R + base graphics, matching R/missingness.R. Block B is read at the
# base-case _catch_tract grain (plan-amendments.md 2.4); grain is a Task 3.4
# spec-curve axis and is not explored here.
#
# Outputs: output/figures/eda-*.png, output/tables/blockB-correlation*.csv,
# output/tables/eda-*.csv, and the written reading in provenance/task3.1-eda.md.

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

## moment skewness and excess kurtosis -- n is large, a normality test would
## reject on trivial departures, so report the shape numbers themselves.
skew <- function(x) { x <- x[is.finite(x)]; m <- mean(x); s <- sd(x)
                      if (s == 0) return(NA_real_); mean((x - m)^3) / s^3 }
kurt <- function(x) { x <- x[is.finite(x)]; m <- mean(x); s <- sd(x)
                      if (s == 0) return(NA_real_); mean((x - m)^4) / s^4 - 3 }

## Pearson and Spearman on pairwise-complete observations.
cor_pc <- function(m, method = "pearson") cor(m, use = "pairwise.complete.obs", method = method)

# ==========================================================================
hdr("TASK 3.1  exploratory pass on data/analytic-v2.rds")

a <- readRDS(file.path("data", "analytic-v2.rds"))
N <- nrow(a)
cat(sprintf("  frame n = %d hospitals x %d columns\n", N, ncol(a)))
cat(sprintf("  PSI-90 present for all %d; components psi03/06/12/13 present for %d/%d/%d/%d\n",
            sum(!is.na(n_(a$psi90))), sum(!is.na(n_(a$psi03))), sum(!is.na(n_(a$psi06))),
            sum(!is.na(n_(a$psi12))), sum(!is.na(n_(a$psi13)))))

## ---- variable groups -----------------------------------------------------
## Block B base-case grain. ice / ice150 are the Index of Concentration at the
## Extremes on income (ACS B19001): (# affluent households - # poor households)
## / total, so POSITIVE = concentrated affluence, NEGATIVE = concentrated
## poverty. ice uses >=$100k vs <$25k; ice150 uses >=$150k vs <$25k. This is
## the income / poverty axis named in the verify condition; SVI theme 1 also
## loads on below-poverty share.
##
## bB_swap: the two near-duplicate vintages/variants. adi(2024)~adi2020 r=0.99
## and ice150~ice r=0.99 -- carrying both of a pair identifies neither (full-
## block VIF 50-87). DECISION (Task 3.1 follow-up): keep adi and ice150 in the
## working set; adi2020 and ice are demoted to Task 3.4 robustness swaps, never
## entered alongside their partner. The 13-measure correlation matrix still
## reports all of them -- the r=0.99 pair is the evidence for the demotion.
bB <- c(svi_ses = "svi1_catch_tract", svi_household = "svi2_catch_tract",
        svi_minority = "svi3_catch_tract", svi_housing = "svi4_catch_tract",
        adi = "adi_catch_tract", adi2020 = "adi2020_catch_tract",
        ice = "ice_catch_tract", ice150 = "ice150_catch_tract",
        uninsured = "uninsured_catch_tract", limeng = "limeng_catch_tract",
        rurality = "rurality_catch_tract", pcp_density = "pcp_density_catch_tract",
        hhi_zip = "hhi_zip")
bB_swap    <- c("adi2020", "ice")                     # robustness swaps only
bB_primary <- setdiff(names(bB), bB_swap)             # 11-measure working block

## the exact set the verify condition asks to be quantified
bB_verify <- c("svi_ses", "svi_household", "svi_minority", "svi_housing",
               "adi", "ice150", "uninsured", "rurality")

bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy",
        resident_to_bed = "resident_to_bed", teaching = "teaching",
        cmi = "cmi", volume = "volume_bills", dsh_pct = "dsh_pct",
        wage_index = "wage_index", operating_margin = "operating_margin",
        uncomp_care_pct = "uncompensated_care_pct_npr")

bC <- c(cmi_level = "cmi_level", cmi_drift = "cmi_drift",
        contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")

outcomes <- c(psi90 = "psi90", psi03 = "psi03", psi06 = "psi06",
              psi12 = "psi12", psi13 = "psi13",
              lambda_i = "lambda_i", v_i = "v_i", psi90_ci_width = "psi90_ci_width")

## numeric matrices, one column per measure, frame order
M <- function(map) { m <- sapply(map, function(cn) n_(a[[cn]])); colnames(m) <- names(map); m }
XB <- M(bB); XA <- M(bA); XC <- M(bC); XO <- M(outcomes)

# ==========================================================================
# 1.  DISTRIBUTIONS
# ==========================================================================
hdr("1  distributions -- shape of every outcome and continuous covariate")

dist_one <- function(nm, block, x) {
  x <- n_(x); ok <- x[is.finite(x)]
  data.frame(block = block, variable = nm, n = length(ok), n_missing = sum(!is.finite(x)),
             mean = mean(ok), sd = sd(ok), min = min(ok), q25 = quantile(ok, .25),
             median = median(ok), q75 = quantile(ok, .75), max = max(ok),
             skew = skew(ok), excess_kurt = kurt(ok),
             pct_zero = mean(ok == 0), has_neg = any(ok < 0),
             row.names = NULL, stringsAsFactors = FALSE)
}
D <- do.call(rbind, list(
  do.call(rbind, lapply(colnames(XO), function(nm) dist_one(nm, "outcome", XO[, nm]))),
  do.call(rbind, lapply(colnames(XA), function(nm) dist_one(nm, "blockA",  XA[, nm]))),
  do.call(rbind, lapply(colnames(XB), function(nm) dist_one(nm, "blockB",  XB[, nm]))),
  do.call(rbind, lapply(colnames(XC), function(nm) dist_one(nm, "blockC",  XC[, nm])))))

## functional-form flag: |skew| > 1 and strictly positive -> log is a candidate
## Task 3.4 axis; |skew| > 1 with zeros/negatives -> signed-root or spline.
D$form_note <- with(D, ifelse(abs(skew) <= 1, "approx symmetric",
                       ifelse(!has_neg & pct_zero < 0.02, "right-skewed -> log candidate",
                       ifelse(pct_zero >= 0.02, "zero-inflated -> spline / signed transform",
                              "skewed w/ negatives -> signed-root / spline"))))
write.csv(D, file.path("output", "tables", "eda-distributions.csv"), row.names = FALSE)

cat(sprintf("  %-22s %-8s %6s %8s %8s %8s %9s   %s\n",
            "variable", "block", "n", "median", "IQR", "skew", "ex.kurt", "functional form"))
for (i in seq_len(nrow(D))) {
  r <- D[i, ]
  cat(sprintf("  %-22s %-8s %6d %8.3g %8.3g %+8.2f %+9.2f   %s\n",
              r$variable, r$block, r$n, r$median, r$q75 - r$q25, r$skew, r$excess_kurt, r$form_note))
}
sk <- D[abs(D$skew) > 1, ]
cat(sprintf("\n  %d of %d measures have |skew| > 1 -- functional form is a live Task 3.4 axis for: %s\n",
            nrow(sk), nrow(D), paste(sk$variable, collapse = ", ")))
cat(sprintf("  PSI-90 itself: skew %+.2f, excess kurtosis %+.2f, %s zero, min %.3f max %.3f -- %s\n",
            D$skew[D$variable == "psi90"], D$excess_kurt[D$variable == "psi90"],
            pct(D$pct_zero[D$variable == "psi90"]), D$min[D$variable == "psi90"],
            D$max[D$variable == "psi90"], D$form_note[D$variable == "psi90"]))

## ---- figure: the outcome layer ----------------------------------------------
psi90 <- n_(a$psi90); lam <- n_(a$lambda_i)
png(file.path("output", "figures", "eda-outcome-distribution.png"), width = 1200, height = 900, res = 130)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1), mgp = c(2.3, 0.7, 0))

h <- hist(psi90, breaks = 50, col = "#6b8fb3", border = "white",
          main = "PSI-90 composite", xlab = "PSI-90 (ratio to national)")
abline(v = median(psi90), col = "#c2703d", lwd = 2)
abline(v = 1, col = "#00000055", lty = 3)
legend("topright", c(sprintf("median %.3f", median(psi90)), "national = 1.00"),
       col = c("#c2703d", "#00000055"), lwd = c(2, 1), lty = c(1, 3), bty = "n", cex = 0.8)

hist(log(psi90), breaks = 50, col = "#6b8fb3", border = "white",
     main = sprintf("log PSI-90  (skew %+.2f -> %+.2f)", skew(psi90), skew(log(psi90))),
     xlab = "log PSI-90")

plot(psi90, n_(a$psi90_ci_width), pch = 19, col = "#00000030", cex = 0.5,
     xlab = "PSI-90", ylab = "published 95% CI width",
     main = "CI width vs point estimate")
lo <- lowess(psi90, n_(a$psi90_ci_width)); lines(lo, col = "#c2703d", lwd = 2)

plot(lam, psi90, pch = 19, col = "#00000030", cex = 0.5,
     xlab = expression("reliability  " * lambda[i]), ylab = "PSI-90",
     main = "shrinkage vs outcome (low lambda pulled to 1)")
abline(h = 1, col = "#00000055", lty = 3)
lines(lowess(lam, psi90), col = "#c2703d", lwd = 2)
dev.off()
cat("\n  figure -> output/figures/eda-outcome-distribution.png\n")

## ---- figure: covariate distributions --------------------------------------
show <- list(
  c("blockA", "beds"), c("blockA", "cmi"), c("blockA", "dsh_pct"),
  c("blockA", "wage_index"), c("blockA", "operating_margin"), c("blockC", "contract_labor_share"),
  c("blockB", "adi"), c("blockB", "svi_ses"), c("blockB", "ice150"),
  c("blockB", "uninsured"), c("blockB", "rurality"), c("blockB", "pcp_density"))
getcol <- function(blk, nm) switch(blk, blockA = XA[, nm], blockB = XB[, nm], blockC = XC[, nm])
png(file.path("output", "figures", "eda-covariate-distributions.png"), width = 1300, height = 1000, res = 130)
par(mfrow = c(3, 4), mar = c(3.6, 3.2, 2.6, 0.8), mgp = c(2, 0.6, 0))
for (s in show) {
  x <- n_(getcol(s[1], s[2])); x <- x[is.finite(x)]
  hist(x, breaks = 40, col = ifelse(s[1] == "blockB", "#6b8fb3", "#8a9a5b"),
       border = "white", main = sprintf("%s  (skew %+.2f)", s[2], skew(x)), xlab = "", cex.main = 0.95)
}
mtext("Task 3.1  covariate distributions   blue = Block B (catchment context)   green = Block A/C (hospital)",
      side = 1, outer = TRUE, line = -1.2, cex = 0.7, adj = 0.02)
dev.off()
cat("  figure -> output/figures/eda-covariate-distributions.png\n")

# ==========================================================================
# 2.  WITHIN-BLOCK CORRELATION
# ==========================================================================
hdr("2  within-block correlation")

heat <- function(m, file, title, w = 1100, h = 1000) {
  m <- m[nrow(m):1, ]
  png(file, width = w, height = h, res = 130)
  par(mar = c(9, 9, 3, 2))
  image(t(m), xaxt = "n", yaxt = "n", zlim = c(-1, 1),
        col = colorRampPalette(c("#2166ac", "white", "#b2182b"))(101), main = title)
  axis(1, at = seq(0, 1, length.out = ncol(m)), labels = colnames(m), las = 2, cex.axis = 0.8)
  axis(2, at = seq(0, 1, length.out = nrow(m)), labels = rownames(m), las = 1, cex.axis = 0.8)
  for (i in seq_len(nrow(m))) for (j in seq_len(ncol(m)))
    text((j - 1) / (ncol(m) - 1), (i - 1) / (nrow(m) - 1),
         sprintf("%.2f", m[i, j]), cex = 0.62,
         col = ifelse(abs(m[i, j]) > 0.6, "white", "black"))
  dev.off()
}

for (blk in list(list("A", XA), list("C", XC))) {
  R <- cor_pc(blk[[2]])
  write.csv(round(R, 4), file.path("output", "tables", sprintf("eda-block%s-correlation.csv", blk[[1]])))
  heat(R, file.path("output", "figures", sprintf("eda-corr-block%s.png", blk[[1]])),
       sprintf("Block %s intercorrelation (Pearson)", blk[[1]]),
       w = 950, h = 850)
  off <- R[upper.tri(R)]
  sub_(sprintf("Block %s: %d measures, |r| median %.2f, max %.2f",
               blk[[1]], ncol(blk[[2]]), median(abs(off)), max(abs(off))))
  wp <- which(abs(R) > 0.6 & upper.tri(R), arr.ind = TRUE)
  for (k in seq_len(nrow(wp)))
    cat(sprintf("    %-22s ~ %-22s  r = %+.2f\n",
                rownames(R)[wp[k, 1]], colnames(R)[wp[k, 2]], R[wp[k, 1], wp[k, 2]]))
}

## ---- Block B: the deliverable --------------------------------------------
## All 13 measures in the CSV -- the two r=0.99 pairs ARE the evidence for the
## working-set decision below. XBp is the 11-measure working block.
XBp <- XB[, bB_primary]
RB  <- cor_pc(XB)
RBs <- cor_pc(XB, "spearman")
write.csv(round(RB, 4),  file.path("output", "tables", "blockB-correlation.csv"))
write.csv(round(RBs, 4), file.path("output", "tables", "blockB-correlation-spearman.csv"))
heat(RB, file.path("output", "figures", "eda-corr-blockB.png"),
     "Block B intercorrelation (Pearson, _catch_tract grain)")
sub_("Block B correlation matrix -> output/tables/blockB-correlation.csv (Pearson) + -spearman.csv")
offB <- RB[upper.tri(RB)]
cat(sprintf("  %d measures, %d unique pairs. |r|: median %.2f, mean %.2f, max %.2f; %d pairs |r| >= 0.6\n",
            ncol(XB), length(offB), median(abs(offB)), mean(abs(offB)), max(abs(offB)),
            sum(abs(offB) >= 0.6)))
wp <- which(abs(RB) >= 0.6 & upper.tri(RB), arr.ind = TRUE)
wp <- wp[order(-abs(RB[wp])), , drop = FALSE]
for (k in seq_len(nrow(wp)))
  cat(sprintf("    %-16s ~ %-16s  r = %+.2f\n",
              rownames(RB)[wp[k, 1]], colnames(RB)[wp[k, 2]], RB[wp[k, 1], wp[k, 2]]))
cat(sprintf("\n  working set drops the redundant vintages: adi~adi2020 r = %+.2f, ice150~ice r = %+.2f.\n",
            RB["adi", "adi2020"], RB["ice150", "ice"]))
cat(sprintf("  keep adi + ice150 (%d-measure working block); adi2020 + ice -> Task 3.4 robustness swaps only.\n",
            length(bB_primary)))

# ==========================================================================
# 3.  BLOCK B COLLINEARITY + PC STRUCTURE -- the verify condition and the TIS motivation
# ==========================================================================
hdr("3  Block B collinearity + principal-component structure")

V  <- XB[, bB_verify]
Vc <- V[stats::complete.cases(V), ]
cat(sprintf("  verify set (task sheet): %s\n  complete rows: %d / %d\n",
            paste(bB_verify, collapse = ", "), nrow(Vc), N))

## (a) pairwise correlation within the verify set
RV  <- cor(Vc)
RVs <- cor(Vc, method = "spearman")
offV <- RV[upper.tri(RV)]
sub_("(a) pairwise Pearson r within the verify set")
print(round(RV, 2))
cat(sprintf("\n  |r|: median %.2f, mean %.2f, max %.2f (%s ~ %s)\n",
            median(abs(offV)), mean(abs(offV)), max(abs(offV)),
            rownames(RV)[which(abs(RV) == max(abs(offV)), arr.ind = TRUE)[1, 1]],
            colnames(RV)[which(abs(RV) == max(abs(offV)), arr.ind = TRUE)[1, 2]]))

## (b) VIF / tolerance. Three views:
##   - swap pairs (13 vs 11): full-block VIF for adi2020/ice is 50-90 because
##     each has a r=0.99 partner. This is the evidence for dropping them.
##   - working block (11, swaps removed): the collinearity the models carry.
##   - verify set (8): the subset the task sheet names.
vif_of <- function(mat, cols) do.call(rbind, lapply(cols, function(nm) {
  d  <- as.data.frame(scale(mat[stats::complete.cases(mat[, cols]), cols, drop = FALSE]))
  r2 <- summary(lm(reformulate(setdiff(cols, nm), nm), data = d))$r.squared
  data.frame(measure = nm, r2_on_others = r2, tolerance = 1 - r2, vif = 1 / (1 - r2),
             row.names = NULL)
}))
vif_full <- vif_of(XB,  colnames(XB));   vif_full <- vif_full[order(-vif_full$vif), ]
vif_work <- vif_of(XBp, bB_primary);     vif_work <- vif_work[order(-vif_work$vif), ]
vif_v    <- vif_of(XB,  bB_verify);      vif_v    <- vif_v[order(-vif_v$vif), ]
vif_work$in_verify_set <- vif_work$measure %in% bB_verify

sub_("(b) VIF -- 13-measure block: adi2020 and ice are the reason for the working set")
for (i in seq_len(nrow(vif_full))) { r <- vif_full[i, ]
  cat(sprintf("    %-16s VIF = %6.1f%s\n", r$measure, r$vif,
              ifelse(r$measure %in% bB_swap, "   <-- redundant vintage, DROPPED",
              ifelse(r$vif >= 5, "   >= 5", "")))) }
sub_("(b) VIF -- 11-measure working block (adi + ice150 kept, adi2020 + ice dropped)")
for (i in seq_len(nrow(vif_work))) { r <- vif_work[i, ]
  cat(sprintf("    %-16s R2 = %.3f   tolerance = %.3f   VIF = %6.1f %s\n",
              r$measure, r$r2_on_others, r$tolerance, r$vif, ifelse(r$vif >= 5, "  <-- >= 5", ""))) }
sub_("(b) VIF -- verify set (8): each of the 8 on the other 7")
for (i in seq_len(nrow(vif_v))) { r <- vif_v[i, ]
  cat(sprintf("    %-16s R2 = %.3f   tolerance = %.3f   VIF = %6.1f %s\n",
              r$measure, r$r2_on_others, r$tolerance, r$vif, ifelse(r$vif >= 5, "  <-- >= 5", ""))) }

## (c) condition number and determinant of the verify-set correlation matrix
ev  <- eigen(RV, symmetric = TRUE)$values
cn  <- sqrt(max(ev) / min(ev))
det_RV <- det(RV)
ci  <- max(svd(scale(Vc))$d) / svd(scale(Vc))$d
sub_("(c) conditioning of the verify set")
cat(sprintf("    correlation-matrix eigenvalues: %s\n", paste(sprintf("%.3f", ev), collapse = " ")))
cat(sprintf("    condition number sqrt(lmax/lmin) = %.1f   (>30 = serious collinearity)\n", cn))
cat(sprintf("    scaled-design condition index (max) = %.1f\n", max(ci)))
cat(sprintf("    determinant of correlation matrix  = %.4f   (-> 0 as collinearity -> 1; I has det 1)\n", det_RV))

## ---- (d) PCA + interpretation --------------------------------------------
## Loadings are sign-arbitrary out of prcomp; orient every PC so a HIGH score
## reads as more advantaged (flip if it loads positive on the vulnerability
## measures). Interpretation labels below are read off the oriented loadings,
## not assumed.
orient_adv <- function(rot, vuln = c("svi_ses", "svi_household", "svi_minority",
                                     "svi_housing", "adi", "adi2020", "uninsured",
                                     "limeng", "rurality")) {
  for (k in seq_len(ncol(rot))) {
    v <- rot[intersect(vuln, rownames(rot)), k]
    if (sum(v[abs(v) > 0.2]) > 0) rot[, k] <- -rot[, k]   # vulnerability should load negative
  }
  rot
}
pca_report <- function(mat, cols, tag, kmax = 4) {
  m  <- mat[stats::complete.cases(mat[, cols]), cols, drop = FALSE]
  pc <- prcomp(m, scale. = TRUE)
  vex <- pc$sdev^2 / sum(pc$sdev^2); cum <- cumsum(vex)
  rot <- orient_adv(pc$rotation)
  sc  <- scale(m) %*% rot[, seq_len(min(kmax, ncol(rot)))]
  sub_(sprintf("(d) PCA -- %s (%d measures, scaled, oriented so high = advantaged)", tag, length(cols)))
  cat(sprintf("    variance explained: %s\n",
              paste(sprintf("PC%d %.0f%%", seq_along(vex), 100 * vex), collapse = "  ")))
  cat(sprintf("    cumulative: %s\n",
              paste(sprintf("PC1-%d %.0f%%", seq_along(cum), 100 * cum), collapse = "  ")))
  k <- min(kmax, ncol(rot))
  cat(sprintf("\n    loadings (PC1-%d):\n", k))
  cat(sprintf("      %-16s %s\n", "measure", paste(sprintf("  PC%d", seq_len(k)), collapse = "")))
  for (nm in rownames(rot))
    cat(sprintf("      %-16s %s\n", nm, paste(sprintf(" %+5.2f", rot[nm, seq_len(k)]), collapse = "")))
  cat("\n    PCk vs PSI-90 (does any disadvantage dimension track the outcome?):\n")
  for (kk in seq_len(k)) {
    ok <- stats::complete.cases(mat[, cols])
    cat(sprintf("      PC%d (%2.0f%% var)   r = %+.3f   rho = %+.3f\n", kk, 100 * vex[kk],
                cor(sc[, kk], psi90[ok]), cor(sc[, kk], psi90[ok], method = "spearman")))
  }
  invisible(list(pc = pc, rot = rot, vex = vex, cum = cum, scores = sc))
}
PV <- pca_report(XB,  bB_verify,  "verify set")
cat("\n    read: PC1 = general socioeconomic (dis)advantage -- every vulnerability measure\n")
cat("          moves together (~46% of the 8-measure variance).\n")
cat("          PC2 = rural/ADI deprivation  vs  urban minority/uninsured deprivation --\n")
cat("          the two are near-orthogonal directions, not one scale (~27%).\n")
cat("          PC3 = housing-type & transportation stress (SVI theme 4 nearly alone, ~11%).\n")
PW <- pca_report(XBp, bB_primary, "working block")
cat("\n    read: the working-block PCs carry the same three axes -- general advantage,\n")
cat("          rural-vs-urban character, housing/built-environment -- now with pcp_density\n")
cat("          joining PC1 (advantage), limeng joining the minority side of PC2, and hhi_zip\n")
cat("          on the rural side. First 3 PCs ~ 75%, first 4 ~ 82%.\n")

## does the outcome signal concentrate in the big PCs? (bears on PCA reduction)
## Needs ALL 8 PC scores (pca_report's $scores is truncated to kmax=4 for the
## loadings table), so recompute the full-rank rotation here.
ok8 <- stats::complete.cases(XB[, bB_verify])
full_sc  <- scale(XB[ok8, bB_verify]) %*% orient_adv(PV$pc$rotation)
## lm(y ~ all 8 PC scores) is mathematically identical to lm(y ~ 8 raw measures)
## -- PCA is just a rotation of the same 8-dimensional space -- so that R2 is a
## tautology, not reported. The comparison that matters is PC1-3 (73% of Block
## B's OWN variance) against the full 8: does the outcome signal live where the
## variance does?
r2_raw8 <- summary(lm(psi90[ok8] ~ XB[ok8, bB_verify]))$r.squared
r2_pc3  <- summary(lm(psi90[ok8] ~ full_sc[, 1:3]))$r.squared
stopifnot(abs(summary(lm(psi90[ok8] ~ full_sc))$r.squared - r2_raw8) < 1e-9)  # rotation sanity check
sub_("(d) is Block B's outcome signal concentrated in the leading PCs?")
cat(sprintf("    lm(psi90 ~ all 8 raw verify measures)          R2 = %.4f\n", r2_raw8))
cat(sprintf("    lm(psi90 ~ PC1-3 only (73%% of Block B variance)) R2 = %.4f  (%.0f%% of the full R2)\n",
            r2_pc3, 100 * r2_pc3 / r2_raw8))
cat("    => the outcome-relevant variance is NOT concentrated in the high-variance PCs -- PC1-3\n")
cat("       explain 73% of Block B's own spread but only about half of its outcome association.\n")
cat("       A reduced-PC representation would discard real signal -- PCA reduction is a Task 3.4\n")
cat("       robustness arm, not the base case.\n")

## write the collinearity table -- working block, VIF + PC1-3 loadings
coll <- merge(vif_work,
              data.frame(measure = rownames(PW$rot), pc1 = PW$rot[, 1],
                         pc2 = PW$rot[, 2], pc3 = PW$rot[, 3], row.names = NULL),
              by = "measure", all.x = TRUE)
coll <- coll[order(-coll$vif), ]
write.csv(coll, file.path("output", "tables", "eda-blockB-collinearity.csv"), row.names = FALSE)

## keep the verify-set PCA handles the figure/verify block use below
pc <- PV$pc; vex <- PV$vex; cum <- PV$cum

## ---- figure: the collinearity picture -----------------------------------
png(file.path("output", "figures", "eda-blockB-collinearity.png"), width = 1300, height = 640, res = 130)
layout(matrix(c(1, 2, 3), nrow = 1), widths = c(1.5, 1, 1))

par(mar = c(8, 8, 3, 1))
mm <- RV[nrow(RV):1, ]
image(t(mm), xaxt = "n", yaxt = "n", zlim = c(-1, 1),
      col = colorRampPalette(c("#2166ac", "white", "#b2182b"))(101),
      main = "verify set: pairwise r")
axis(1, seq(0, 1, length.out = ncol(mm)), colnames(mm), las = 2, cex.axis = 0.75)
axis(2, seq(0, 1, length.out = nrow(mm)), rownames(mm), las = 1, cex.axis = 0.75)
for (i in seq_len(nrow(mm))) for (j in seq_len(ncol(mm)))
  text((j - 1) / (ncol(mm) - 1), (i - 1) / (nrow(mm) - 1), sprintf("%.2f", mm[i, j]),
       cex = 0.7, col = ifelse(abs(mm[i, j]) > 0.6, "white", "black"))

par(mar = c(8, 4, 3, 1))
vt <- vif_v[order(vif_v$vif), ]
barplot(vt$vif, names.arg = vt$measure, horiz = TRUE, las = 1, border = NA,
        col = ifelse(vt$vif >= 5, "#c2703d", "#6b8fb3"), xlab = "VIF (verify set, 8 measures)",
        main = "variance inflation", cex.names = 0.75)
abline(v = 5, col = "#00000066", lty = 2)

par(mar = c(4, 4, 3, 1))
bpx <- barplot(100 * vex, names.arg = paste0("PC", seq_along(vex)), border = NA, col = "#6b8fb3",
               ylim = c(0, 100), ylab = "% variance (bars) / cumulative (line)",
               main = sprintf("PCA scree (PC1 = %.0f%%)", 100 * vex[1]))
lines(bpx, 100 * cum, type = "b", pch = 19, col = "#c2703d")
abline(h = 90, col = "#00000055", lty = 3)
text(bpx[length(bpx)], 93, "90%", pos = 2, cex = 0.7, col = "#00000088")
dev.off()
cat("\n  figure -> output/figures/eda-blockB-collinearity.png\n")

sub_("verify -- collinearity is quantified")
cat(sprintf("    pairwise |r| up to %.2f; verify-set VIF up to %.1f (%s), working-block VIF up to %.1f;\n",
            max(abs(offV)), max(vif_v$vif), vif_v$measure[which.max(vif_v$vif)], max(vif_work$vif)))
cat(sprintf("    correlation-matrix condition number %.1f, determinant %.4f; PC1+PC2 carry %.0f%% of the 8-measure variance.\n",
            cn, det_RV, 100 * sum(vex[1:2])))
cat("    => marginal permutation importance would split shared variance arbitrarily between\n")
cat("       collinear measures. The TIS decomposition (Tasks 3.13-3.14) separates the direct\n")
cat("       from the shared attribution; MCR (3.11-3.12) bounds reliance across the near-optimal set.\n")

# ==========================================================================
# 4.  CROSS-BLOCK CORRELATION
# ==========================================================================
hdr("4  cross-block correlation")

## outcome vs every covariate
allX <- cbind(XA, XB, XC)
blkOf <- c(rep("A", ncol(XA)), rep("B", ncol(XB)), rep("C", ncol(XC)))
oc <- do.call(rbind, lapply(seq_len(ncol(allX)), function(j) {
  x <- allX[, j]
  cp <- cor.test(psi90, x, method = "pearson")
  data.frame(block = blkOf[j], covariate = colnames(allX)[j],
             r_pearson = unname(cp$estimate), p_pearson = cp$p.value,
             r_spearman = suppressWarnings(cor(psi90, x, use = "pairwise.complete.obs", method = "spearman")),
             n = sum(is.finite(x)), row.names = NULL)
}))
oc <- oc[order(-abs(oc$r_pearson)), ]
write.csv(oc, file.path("output", "tables", "eda-outcome-correlations.csv"), row.names = FALSE)
sub_("PSI-90 vs each covariate (ranked by |Pearson r|)")
cat(sprintf("  %-24s %-6s %10s %10s %8s\n", "covariate", "block", "r(Pear)", "r(Spear)", "n"))
for (i in seq_len(nrow(oc))) {
  r <- oc[i, ]
  cat(sprintf("  %-24s %-6s %+10.3f %+10.3f %8d%s\n",
              r$covariate, r$block, r$r_pearson, r$r_spearman, r$n,
              ifelse(r$p_pearson < 0.05, "  *", "")))
}
cat(sprintf("\n  strongest Block B correlate of PSI-90: %s (r = %+.3f)\n",
            oc$covariate[oc$block == "B"][1], oc$r_pearson[oc$block == "B"][1]))
cat(sprintf("  strongest Block A correlate of PSI-90: %s (r = %+.3f)\n",
            oc$covariate[oc$block == "A"][1], oc$r_pearson[oc$block == "A"][1]))

## Block A vs Block B -- the structure / context entanglement
RAB <- cor(XA, XB, use = "pairwise.complete.obs")
write.csv(round(RAB, 4), file.path("output", "tables", "eda-crossblock-correlation.csv"))
heat(RAB, file.path("output", "figures", "eda-crossblock-AB.png"),
     "Block A (rows) x Block B (cols)  Pearson r", w = 1200, h = 900)
sub_("Block A x Block B -- |r| >= 0.3 (hospital structure entangled with catchment context)")
wp <- which(abs(RAB) >= 0.3, arr.ind = TRUE)
wp <- wp[order(-abs(RAB[wp])), , drop = FALSE]
for (k in seq_len(nrow(wp)))
  cat(sprintf("    A:%-18s ~ B:%-16s  r = %+.2f\n",
              rownames(RAB)[wp[k, 1]], colnames(RAB)[wp[k, 2]], RAB[wp[k, 1], wp[k, 2]]))
cat(sprintf("\n  Block A x Block B |r|: median %.2f, max %.2f -- the decomposition must separate these.\n",
            median(abs(RAB)), max(abs(RAB))))

## ---- figure: outcome-correlation forest --------------------------------
png(file.path("output", "figures", "eda-outcome-correlations.png"), width = 1050, height = 1100, res = 130)
par(mar = c(4.5, 11, 3, 2))
of <- oc[order(oc$r_pearson), ]
cols <- c(A = "#8a9a5b", B = "#6b8fb3", C = "#b08968")[of$block]
bp <- barplot(of$r_pearson, horiz = TRUE, names.arg = of$covariate, las = 1, border = NA,
              col = cols, xlim = range(c(-0.35, 0.35, of$r_pearson)),
              xlab = "Pearson correlation with PSI-90", cex.names = 0.72,
              main = "What moves with the outcome")
abline(v = 0, col = "#00000066")
legend("bottomright", c("Block A hospital", "Block B context", "Block C policy"),
       fill = c("#8a9a5b", "#6b8fb3", "#b08968"), border = NA, bty = "n", cex = 0.75)
dev.off()
cat("\n  figure -> output/figures/eda-outcome-correlations.png\n")

# ==========================================================================
# 5.  GEOGRAPHIC PATTERNING OF THE OUTCOME
# ==========================================================================
hdr("5  geographic patterning of PSI-90")

## state -> census region / division (base R lookup + DC)
div <- setNames(as.character(state.division), state.abb)
reg <- setNames(as.character(state.region),   state.abb)
div["DC"] <- "South Atlantic"; reg["DC"] <- "South"
a$division <- div[a$state]; a$region <- reg[a$state]

## variance of PSI-90 sitting BETWEEN geographic units: one-way ANOVA ICC.
## The estimate is only stable when units hold several hospitals each -- with
## mostly-singleton units (HSA, county) between and within variance are not
## separately identified and the moment estimator collapses toward 0. Report
## the mean unit size alongside so an unstable row reads as unstable.
icc_between <- function(y, g) {
  ok <- is.finite(y) & !is.na(g); y <- y[ok]; g <- factor(g[ok])
  if (nlevels(g) < 2) return(c(icc = NA, k = nlevels(g), per = NA, singleton = NA))
  af <- anova(lm(y ~ g))
  msb <- af$`Mean Sq`[1]; msw <- af$`Mean Sq`[2]
  n <- length(y); k <- nlevels(g); sz <- tabulate(g)
  n0 <- (n - sum(sz^2) / n) / (k - 1)
  vb <- max(0, (msb - msw) / n0)
  c(icc = vb / (vb + msw), k = k, per = n / k, singleton = mean(sz == 1))
}
geo <- do.call(rbind, lapply(
  list(state = a$state, division = a$division, region = a$region,
       cbsa = a$cbsa, hsa = a$hsa, catch_county = a$county_fips),
  function(g) { r <- icc_between(psi90, g)
                data.frame(icc = r["icc"], n_units = r["k"],
                           mean_per_unit = r["per"], pct_singleton = r["singleton"]) }))
geo$grouping <- rownames(geo)
geo$stable <- geo$mean_per_unit >= 2 & geo$pct_singleton < 0.8
geo <- geo[, c("grouping", "n_units", "mean_per_unit", "pct_singleton", "icc", "stable")]
write.csv(geo, file.path("output", "tables", "eda-geographic.csv"), row.names = FALSE)
sub_("share of PSI-90 variance between geographic units (one-way ANOVA ICC)")
for (i in seq_len(nrow(geo)))
  cat(sprintf("    %-14s %5d units  %5.1f hosp/unit  %3.0f%% singleton   ICC = %.3f%s\n",
              geo$grouping[i], geo$n_units[i], geo$mean_per_unit[i], 100 * geo$pct_singleton[i],
              geo$icc[i], ifelse(geo$stable[i], "", "   (sparse -- not identified)")))
cat(sprintf("\n  ~%.0f%% of PSI-90 variance is between states; ~%.0f%% between census divisions; ~%.0f%% between CBSAs.\n",
            100 * geo$icc[geo$grouping == "state"], 100 * geo$icc[geo$grouping == "division"],
            100 * geo$icc[geo$grouping == "cbsa"]))
cat("  HSA and county rows are mostly-singleton -- ICC not separately identified there; a\n")
cat("  random-effects fit (Task 3.2) borrows strength across sparse units where the ANOVA moment estimator cannot.\n")
cat("  Catchment geography is the nesting level for the baseline model (Task 3.2).\n")

## outcome gradient across disadvantage and rurality. Every measure is oriented
## so Q1 = least disadvantaged, Q4 = most (ICE is affluence-signed, so flip it).
qgrad <- function(x, label, q = 4) {
  ok <- is.finite(x) & is.finite(psi90)
  grp <- cut(x[ok], breaks = quantile(x[ok], seq(0, 1, length.out = q + 1)),
             include.lowest = TRUE, labels = paste0("Q", seq_len(q)))
  m <- tapply(psi90[ok], grp, mean); s <- tapply(psi90[ok], grp, function(z) sd(z) / sqrt(length(z)))
  data.frame(measure = label, quartile = names(m), mean_psi90 = as.numeric(m),
             se = as.numeric(s), row.names = NULL)
}
grad <- do.call(rbind, list(
  qgrad( n_(a$adi_catch_tract),        "ADI (catchment)"),
  qgrad( n_(a$svi1_catch_tract),       "SVI socioeconomic"),
  qgrad(-n_(a$ice150_catch_tract),     "ICE-150 (sign flipped: high = poor)"),
  qgrad( n_(a$uninsured_catch_tract),  "uninsured rate"),
  qgrad( n_(a$rurality_catch_tract),   "rurality")))
write.csv(grad, file.path("output", "tables", "eda-outcome-gradient.csv"), row.names = FALSE)
sub_("PSI-90 mean by quartile of catchment disadvantage / rurality")
for (mn in unique(grad$measure)) {
  g <- grad[grad$measure == mn, ]
  cat(sprintf("    %-30s  Q1 %.3f  ->  Q4 %.3f   (delta %+.3f)\n",
              mn, g$mean_psi90[1], g$mean_psi90[4], g$mean_psi90[4] - g$mean_psi90[1]))
}

## outcome by hospital urban/rural
sub_("PSI-90 by hospital location (Impact File urban/rural)")
ur <- tapply(psi90, a$urban_rural, function(z) c(n = length(z), mean = mean(z), median = median(z)))
for (nm in names(ur)) if (!is.na(nm))
  cat(sprintf("    %-8s n = %4d   mean %.3f   median %.3f\n", nm, ur[[nm]]["n"], ur[[nm]]["mean"], ur[[nm]]["median"]))

## ---- figure: geography --------------------------------------------------
png(file.path("output", "figures", "eda-geographic.png"), width = 1300, height = 1000, res = 130)
par(mfrow = c(2, 2), mar = c(7, 4, 3, 1), mgp = c(2.3, 0.7, 0))

ord <- names(sort(tapply(psi90, a$division, median)))
boxplot(psi90 ~ factor(a$division, levels = ord), las = 2, col = "#6b8fb3", outpch = 19,
        outcol = "#00000022", ylab = "PSI-90", xlab = "", main = "PSI-90 by census division", cex.axis = 0.7)
abline(h = 1, col = "#00000055", lty = 3)

par(mar = c(4, 4, 3, 1))
g <- grad[grad$measure == "ADI (catchment)", ]
plot(1:4, g$mean_psi90, type = "b", pch = 19, col = "#c2703d", lwd = 2, ylim = range(grad$mean_psi90),
     xaxt = "n", xlab = "catchment disadvantage quartile", ylab = "mean PSI-90",
     main = "outcome gradient across disadvantage")
axis(1, 1:4, paste0("Q", 1:4))
for (mn in setdiff(unique(grad$measure), "ADI (catchment)")) {
  gg <- grad[grad$measure == mn, ]
  lines(1:4, gg$mean_psi90, type = "b", pch = 1, col = "#00000055")
}
legend("topleft", c("ADI", "other disadvantage / rurality measures"),
       col = c("#c2703d", "#00000055"), lwd = c(2, 1), pch = c(19, 1), bty = "n", cex = 0.75)

par(mar = c(7, 4, 3, 1))
gb <- barplot(geo$icc, names.arg = c("state", "division", "region", "CBSA", "HSA", "catch county"),
              las = 2, border = NA, cex.names = 0.8, ylab = "ICC",
              col = ifelse(geo$stable, "#6b8fb3", "#c9c9c9"),
              main = "PSI-90 variance between geographic units")
text(gb[!geo$stable], 0.004, "sparse", srt = 90, pos = 4, cex = 0.65, col = "#00000077")

ur2 <- tapply(psi90, a$urban_rural, mean); ur2 <- ur2[!is.na(names(ur2))]
bp <- barplot(ur2, col = "#8a9a5b", border = NA, ylab = "mean PSI-90", ylim = c(0.9, 1.05),
              main = "PSI-90 by hospital location", xpd = FALSE)
abline(h = 1, col = "#00000055", lty = 3)
dev.off()
cat("\n  figure -> output/figures/eda-geographic.png\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. distributions written for %d measures; %d have |skew| > 1 (functional form -> Task 3.4).\n",
            nrow(D), sum(abs(D$skew) > 1)))
cat(sprintf("  2. within-block correlation matrices: Block A (%d), Block B (%d), Block C (%d).\n",
            ncol(XA), ncol(XB), ncol(XC)))
cat(sprintf("  3. Block B collinearity QUANTIFIED among %s:\n", paste(bB_verify, collapse = ", ")))
cat(sprintf("       pairwise |r| max %.2f; verify-set VIF max %.1f; condition number %.1f; corr-matrix det %.4f; PC1+PC2 %.0f%%.\n",
            max(abs(offV)), max(vif_v$vif), cn, det_RV, 100 * sum(vex[1:2])))
cat("       => empirical justification for TIS (3.13-3.14) recorded.\n")
cat(sprintf("  4. cross-block: PSI-90 vs %d covariates; Block A x Block B max |r| %.2f.\n",
            nrow(oc), max(abs(RAB))))
cat(sprintf("  5. geographic patterning: state ICC %.3f, division ICC %.3f; outcome gradient across ADI quartiles delta %+.3f.\n",
            geo$icc[geo$grouping == "state"], geo$icc[geo$grouping == "division"],
            {g <- grad[grad$measure == "ADI (catchment)", ]; g$mean_psi90[4] - g$mean_psi90[1]}))
stopifnot(file.exists(file.path("output", "tables", "blockB-correlation.csv")),
          nrow(D) > 20, is.finite(cn), is.finite(det_RV),
          nrow(geo) == 6, all(is.finite(oc$r_pearson)))

hdr("done")
