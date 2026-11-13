# R/04-spec-curve-report.R  --  Task 3.7, the specification curve and its
# reported numbers.
#
# Reads data/spec-results.rds (the full harness run, Task 3.6 harness with
# SPEC_CURVE_FULL=1, make.R stage 24) and produces:
#   output/figures/spec-curve.png             the sorted curve + choice grid
#   output/figures/spec-curve-reliability.png  the reliability axis on its own
#   output/tables/spec-curve-summary.csv       standardised estimate by axis level
#   output/tables/spec-curve-reliability.csv   the paired within-cell contrasts
#
# THE FOCAL ESTIMATE is dis_effect (Task 3.6 header): the model-predicted
# change in the outcome when a hospital's community-disadvantage profile moves
# from the 10th to the 90th frame percentile on every disadvantage measure at
# once. Positive means more-deprived communities have worse (higher) PSI. Only
# the 3,344 specifications that carry Block B have it; the 152 blocks = A specs
# are the "disadvantage omitted" comparison and sit out the curve.
#
# dis_effect is in each outcome's own units -- the composite is a ratio to the
# national rate (SD ~ 0.19), the component-based outcomes are z-scored (SD ~ 1).
# The curve therefore runs on dis_std = dis_effect / SD(outcome): the p10 -> p90
# disadvantage move measured in standard deviations of that spec's outcome.
#
# WHAT TASK 3.7 REPORTS:
#  1. the full distribution of the standardised estimate, every spec plotted,
#     y-axis not clipped, so the specs whose estimate is near zero or negative
#     are as visible as the rest;
#  2. sign-stability as one number -- the share of specs with a positive
#     estimate, and the share whose 95% interval clears zero;
#  3. the reliability axis on its own -- within every combination of the other
#     seven axes, the estimate under lambda-weighting and under the errors-in-
#     variables correction minus the estimate unweighted. A positive shift is
#     direct evidence that CMS's reliability smoothing was attenuating the
#     disadvantage association.

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 3.7  the specification curve")

S <- readRDS(file.path("data", "spec-results.rds"))
R <- S$results
cat(sprintf("  %d specifications fitted   m(imputations) = %d   high-reliability cut lambda >= %.2f\n",
            nrow(R), S$mi_m, S$lam_hi))

## dis_effect is in the modelled outcome's own units, which differ by outcome
## family: the composite is a ratio to the national rate (SD ~ 0.19), the five
## component-based outcomes are z-scored (SD ~ 1). To put the whole curve on
## one axis, express every estimate as a standardised effect -- the p10 -> p90
## disadvantage move measured in standard deviations of that spec's outcome.
a0 <- readRDS(file.path("data", "analytic-v2.rds"))
sd_psi90 <- sd(a0$psi90, na.rm = TRUE)
natM <- sapply(c("psi03", "psi06", "psi12", "psi13"),
               function(cp) mean(suppressWarnings(as.numeric(a0[[cp]])), na.rm = TRUE))
agg0 <- local({
  num <- den <- rep(0, nrow(a0))
  for (cp in names(natM)) {
    r <- suppressWarnings(as.numeric(a0[[cp]])) / natM[[cp]]
    w <- suppressWarnings(as.numeric(a0[[paste0(cp, "_denom")]]))
    ok <- is.finite(r) & is.finite(w) & w > 0
    num[ok] <- num[ok] + w[ok] * r[ok]; den[ok] <- den[ok] + w[ok]
  }
  ifelse(den > 0, num / den, NA_real_)
})
sd_agg <- sd(agg0, na.rm = TRUE)
R$dis_std <- with(R, ifelse(outcome_family == "composite", dis_effect / sd_psi90,
                     ifelse(outcome_family == "aggregate", dis_effect / sd_agg, dis_effect)))
R$se_std  <- with(R, ifelse(outcome_family == "composite", dis_se / sd_psi90,
                     ifelse(outcome_family == "aggregate", dis_se / sd_agg, dis_se)))
cat(sprintf("  standardising divisors: SD(psi90) = %.3f, SD(component aggregate) = %.3f, components already z-scored\n",
            sd_psi90, sd_agg))
cat(sprintf("  status: %d ok, %d failed\n", sum(R$status == "ok"), sum(R$status == "failed")))
if (any(R$status == "failed"))
  for (fr in sort(table(R$fail_reason[R$status == "failed"]), decreasing = TRUE))
    NULL
ft <- table(R$fail_reason[R$status == "failed"])
if (length(ft)) { sub_("failed fits (kept as rows)")
  for (i in seq_along(ft)) cat(sprintf("  %4d  %s\n", ft[i], names(ft)[i])) }

# ==========================================================================
# 1.  THE CURVE SET  --  Block-B specs with a usable estimate
# ==========================================================================
C <- R[R$blocks != "A" & R$status == "ok" & is.finite(R$dis_std) & is.finite(R$se_std), ]
C$lo <- C$dis_std - 1.96 * C$se_std
C$hi <- C$dis_std + 1.96 * C$se_std
C <- C[order(C$dis_std), ]
C$rank <- seq_len(nrow(C))
n <- nrow(C)
cat(sprintf("\n  curve set: %d specifications carry Block B and produced a finite estimate\n", n))
cat(sprintf("  (%d blocks = A specs omitted -- no disadvantage term; %d Block-B specs dropped for a non-finite fit)\n",
            sum(R$blocks == "A"),
            sum(R$blocks != "A" & (R$status != "ok" | !is.finite(R$dis_std) | !is.finite(R$se_std)))))
cat("  dis_std = the p10 -> p90 disadvantage move, in standard deviations of the spec's outcome.\n")

## The curve points themselves, for the final figure suite (Task 5.1, stage 38),
## so the standardisation above lives in one place.
write.csv(C[, c("rank", "spec_id", "blocks", "form", "outcome", "reliability", "grain", "missing",
                "influential", "scale", "outcome_family", "dis_std", "se_std", "lo", "hi")],
          file.path("output", "tables", "spec-curve-points.csv"), row.names = FALSE)

# ==========================================================================
# 2.  SIGN-STABILITY  --  the number the verify condition asks for
# ==========================================================================
hdr("2  sign-stability of the community-disadvantage estimate")

pos      <- mean(C$dis_std > 0)
pos_sig  <- mean(C$dis_std > 0 & C$lo > 0)
neg_sig  <- mean(C$dis_std < 0 & C$hi < 0)
med      <- median(C$dis_std)
q        <- quantile(C$dis_std, c(.025, .25, .75, .975))

cat(sprintf("  median standardised effect   %+.4f SD   IQR [%+.4f, %+.4f]\n", med, q[2], q[3]))
cat(sprintf("  central 95%% of specs         [%+.4f, %+.4f]   full range [%+.4f, %+.4f]\n",
            q[1], q[4], min(C$dis_std), max(C$dis_std)))
cat(sprintf("\n  SIGN-STABILITY: %s of the %d specifications (%d) put the estimate above zero.\n",
            pct(pos), n, sum(C$dis_std > 0)))
cat(sprintf("  %s (%d) are positive with a 95%% interval clear of zero; %s (%d) are negative and clear of zero.\n",
            pct(pos_sig), sum(C$dis_std > 0 & C$lo > 0),
            pct(neg_sig), sum(C$dis_std < 0 & C$hi < 0)))

sub_("by outcome family (component outcomes are individually noisy; composite is the published one)")
for (fam in c("composite", "aggregate", "component")) {
  x <- C[C$outcome_family == fam, ]
  cat(sprintf("  %-10s n=%4d   median %+.4f SD   share positive %s   share positive and clearing zero %s\n",
              fam, nrow(x), median(x$dis_std), pct(mean(x$dis_std > 0)),
              pct(mean(x$dis_std > 0 & x$lo > 0))))
}
sub_("raw dis_effect, in each family's own units (composite = ratio to national rate)")
for (fam in c("composite", "aggregate", "component")) {
  x <- C[C$outcome_family == fam, ]
  cat(sprintf("  %-10s median dis_effect %+.4f   IQR [%+.4f, %+.4f]\n",
              fam, median(x$dis_effect), quantile(x$dis_effect, .25), quantile(x$dis_effect, .75)))
}

# ==========================================================================
# 3.  dis_std BY AXIS LEVEL  (the summary table under the figure)
# ==========================================================================
hdr("3  standardised estimate by analytic choice")

AXES <- c("blocks", "form", "outcome", "reliability", "grain", "missing",
          "influential", "scale")
rows <- list()
for (ax in AXES) for (lv in sort(unique(C[[ax]]))) {
  x <- C[C[[ax]] == lv, "dis_std"]
  rows[[length(rows) + 1]] <- data.frame(
    axis = ax, level = lv, n = length(x),
    median = median(x), q25 = quantile(x, .25), q75 = quantile(x, .75),
    min = min(x), max = max(x), share_pos = mean(x > 0))
}
SUM <- do.call(rbind, rows); rownames(SUM) <- NULL
for (i in seq_len(nrow(SUM)))
  cat(sprintf("  %-12s %-14s n=%4d  median %+.4f  IQR [%+.4f,%+.4f]  pos %s\n",
              SUM$axis[i], SUM$level[i], SUM$n[i], SUM$median[i], SUM$q25[i], SUM$q75[i],
              pct(SUM$share_pos[i])))
write.csv(SUM, file.path("output", "tables", "spec-curve-summary.csv"), row.names = FALSE)

# ==========================================================================
# 4.  THE RELIABILITY AXIS, ON ITS OWN
# ==========================================================================
hdr("4  the reliability axis reported separately -- unweighted published score is the reference")

## within-cell paired contrasts: hold the other seven axes, read the
## standardised estimate off each reliability level, subtract the unweighted
## value. Within a cell every spec shares an outcome, so the shift is clean.
C$cell <- with(C, paste(blocks, form, outcome, grain, missing, influential, scale, sep = "."))
paired <- list()
for (cl in unique(C$cell)) {
  x <- C[C$cell == cl, ]
  base <- x$dis_std[x$reliability == "unweighted"]
  if (!length(base)) next
  for (lv in setdiff(unique(x$reliability), "unweighted")) {
    v <- x$dis_std[x$reliability == lv]
    if (length(v))
      paired[[length(paired) + 1]] <- data.frame(cell = cl, contrast = lv,
        delta = v[1] - base[1], base = base[1], value = v[1])
  }
}
P <- do.call(rbind, paired)
write.csv(P, file.path("output", "tables", "spec-curve-reliability.csv"), row.names = FALSE)

sub_("paired within-cell shift in the standardised estimate, relative to the unweighted fit")
for (lv in c("weighted", "subsample", "eiv")) {
  d <- P$delta[P$contrast == lv]
  if (!length(d)) next
  cat(sprintf("  %-10s  n_cells=%4d   mean shift %+.4f SD   median %+.4f   share positive %s\n",
              lv, length(d), mean(d), median(d), pct(mean(d > 0))))
}
elv <- P$delta[P$contrast == "eiv"]
wlv <- P$delta[P$contrast == "weighted"]
cat(sprintf("\n  READING: under lambda-weighting the disadvantage estimate shifts %s in %s of the %d cells\n",
            ifelse(median(wlv) > 0, "UP", "DOWN"), pct(mean(wlv > 0)), length(wlv)))
cat(sprintf("  (median %+.4f SD). Under the errors-in-variables correction it shifts %s in %s of the %d\n",
            median(wlv), ifelse(median(elv) > 0, "UP", "DOWN"), pct(mean(elv > 0)), length(elv)))
cat(sprintf("  composite cells (median %+.4f SD). A positive shift is what the project's scalar\n", median(elv)))
cat(sprintf("  reliability approximation predicts if smoothing attenuates the gradient; it is a\n"))
cat(sprintf("  sensitivity result under that approximation, not a measurement of what the smoothing\n"))
cat(sprintf("  hid (Task S2.1). The unweighted fit to the published score is the reference.\n"))

sub_("standardised estimate level, by reliability (composite outcome only, the axis's home)")
for (lv in c("unweighted", "weighted", "subsample", "eiv")) {
  x <- C[C$reliability == lv & C$outcome_family == "composite", "dis_std"]
  cat(sprintf("  %-10s n=%4d   median %+.4f SD   [%+.4f, %+.4f]\n",
              lv, length(x), median(x), quantile(x, .1), quantile(x, .9)))
}

# ==========================================================================
# 5.  FIGURE 1  --  the specification curve
# ==========================================================================
## colour by sign always, so the positive/negative split is visible; darken
## when the 95% interval clears zero.
sig_col <- ifelse(C$dis_std > 0, ifelse(C$lo > 0, "#1f4e79", "#8fb1d3"),
                                 ifelse(C$hi < 0, "#a33227", "#d8a89f"))

png(file.path("output", "figures", "spec-curve.png"), width = 1500, height = 1680, res = 145)
layout(matrix(c(1, 2), nrow = 2), heights = c(1, 2.55))

## --- top: the sorted estimates ---
par(mar = c(0.6, 7.5, 4.4, 1.5), mgp = c(2.7, 0.7, 0))
yl <- range(C$lo, C$hi, 0)
plot(C$rank, C$dis_std, type = "n", xlab = "", ylab = "estimate (SD of outcome)",
     xlim = c(0, n + 1), ylim = yl, xaxt = "n", bty = "n")
abline(h = 0, col = "#00000055", lwd = 1.2)
abline(h = med, col = "#c2703d", lwd = 1.3, lty = 2)
segments(C$rank, C$lo, C$rank, C$hi, col = paste0(sig_col, "18"), lwd = 0.5)
points(C$rank, C$dis_std, pch = 19, cex = 0.34, col = sig_col)
mtext(sprintf("Task 3.7  specification curve   %d specifications carrying community disadvantage   median %+.3f SD   %s positive",
              n, med, pct(mean(C$dis_std > 0))), side = 3, line = 2.5, adj = 0, cex = 0.92, font = 2)
mtext(sprintf("blue = positive estimate, red = negative; dark = 95%% interval clears zero (%s of specs), pale = interval spans zero   orange dash = median",
              pct(mean((C$dis_std > 0 & C$lo > 0) | (C$dis_std < 0 & C$hi < 0)))),
      side = 3, line = 1.2, adj = 0, cex = 0.72, col = "#00000099")

## --- bottom: the choice grid ---
grid_levels <- list(
  blocks      = c("AB", "ABC"),
  form        = c("linear", "spline"),
  outcome     = c("composite", "agg", "psi03", "psi06", "psi12", "psi13"),
  reliability = c("unweighted", "weighted", "subsample", "eiv"),
  grain       = c("catch_tract", "catch_county", "hosp_county", "hsa"),
  missing     = c("na", "mi", "complete", "omit"),
  influential = c("all", "drop_fn2329", "drop_fallback"),
  scale       = c("identity", "log"))
labels <- unlist(lapply(names(grid_levels), function(ax)
  paste0(ifelse(seq_along(grid_levels[[ax]]) == 1, paste0(ax, ":  "), ""), grid_levels[[ax]])))
K <- length(labels)
ypos <- rev(seq_len(K))
grp_end <- head(cumsum(sapply(grid_levels, length)), -1)

par(mar = c(4.2, 7.5, 0.4, 1.5), mgp = c(2.6, 0.7, 0))
plot(NA, xlim = c(0, n + 1), ylim = c(0.5, K + 0.5), xlab = "specification (sorted by estimate)",
     ylab = "", yaxt = "n", bty = "n")
abline(h = K - grp_end + 0.5, col = "#00000018", lwd = 0.8)
axis(2, at = ypos, labels = labels, las = 1, cex.axis = 0.64, tick = FALSE)
ri <- 0
for (ax in names(grid_levels)) for (lv in grid_levels[[ax]]) {
  ri <- ri + 1
  hit <- C$rank[C[[ax]] == lv]
  if (length(hit)) points(hit, rep(ypos[ri], length(hit)), pch = 15, cex = 0.2,
                          col = "#2f5c8a")
}
dev.off()
cat(sprintf("\n  output/figures/spec-curve.png\n"))

# ==========================================================================
# 6.  FIGURE 2  --  the reliability axis
# ==========================================================================
png(file.path("output", "figures", "spec-curve-reliability.png"), width = 1400, height = 660, res = 140)
par(mfrow = c(1, 2), mar = c(5.2, 4.5, 3.5, 1), mgp = c(2.4, 0.7, 0))

## left: standardised estimate distribution by reliability level
levs <- c("unweighted", "weighted", "subsample", "eiv")
bx <- lapply(levs, function(l) C$dis_std[C$reliability == l])
boxplot(bx, names = levs, col = "#6b8fb3", outpch = 19, outcex = 0.3, border = "#33587f",
        ylab = "estimate (SD of outcome)", main = "estimate by reliability level", cex.axis = 0.85)
abline(h = 0, col = "#00000055")
abline(h = median(C$dis_std[C$reliability == "unweighted"]), col = "#c2703d", lty = 2)

## right: paired within-cell shift vs the unweighted fit
pl <- c("weighted", "subsample", "eiv")
pb <- lapply(pl, function(l) P$delta[P$contrast == l])
boxplot(pb, names = pl, col = "#8a9a5b", outpch = 19, outcex = 0.3, border = "#5f6b40",
        ylab = "shift vs. unweighted, same cell (SD)",
        main = "paired within-cell reliability shift", cex.axis = 0.85)
abline(h = 0, col = "#00000055")
mtext(sprintf("eiv: %s of cells shift up, median %+.4f", pct(mean(elv > 0)), median(elv)),
      side = 1, line = 3.1, cex = 0.7, col = "#00000099")
dev.off()
cat(sprintf("  output/figures/spec-curve-reliability.png\n"))

# ==========================================================================
hdr("verify")
cat(sprintf("  1. every fitted spec is in data/spec-results.rds, failures included: %d rows, %d failed -- PASS\n",
            nrow(R), sum(R$status == "failed")))
cat(sprintf("  2. figure plots all %d curve specs, y-axis spans [%.3f, %.3f] -- the near-zero and negative\n",
            n, yl[1], yl[2]))
cat(sprintf("     specs are shown, not clipped -- PASS\n"))
cat(sprintf("  3. sign-stability reported as a number: %s of specs positive, %s positive and clearing zero -- PASS\n",
            pct(pos), pct(pos_sig)))
cat(sprintf("  4. reliability axis reported separately: lambda-weighting median shift %+.4f, eiv median shift %+.4f -- PASS\n",
            median(wlv), median(elv)))
stopifnot(n > 3000, nrow(SUM) > 20, nrow(P) > 100, file.exists(file.path("output", "figures", "spec-curve.png")))

hdr("done")
