# R/12-figures.R  --  Task 5.1, the final figure suite.
#
# make.R stage 38. Draws the report's eight figures in one visual grammar
# (R/fig-theme.R) into output/figures/final/, then writes a manifest of their
# sha256 hashes. It fits nothing and draws no simulation: every number it
# plots is read from a table or data product an earlier stage wrote, so the
# chain raw -> make.R stages 1-37 -> this stage is the only way a figure can
# change. The per-stage working figures in output/figures/ stay where they are
# as diagnostics; the report cites only output/figures/final/.
#
#   fig2-variance-decomposition   3.3   output/tables/variance-decomposition.csv
#   fig1-reliability-by-volume    2.2   data/analytic-v2.rds, output/tables/reliability-by-volume.csv
#   fig3-spec-curve               3.7   output/tables/spec-curve-points.csv, rashomon-set.csv
#   fig4-mcr-bounds               3.12  output/tables/mcr-bounds-block{A,B}.csv, rashomon-coef-ranges.csv
#   fig5-tis-decomposition        3.14  output/tables/tis-decomposition.csv, tis-flow-matrix.csv
#   fig6-archetype-validation     3.16  output/tables/archetype-{cells,validation}.csv
#   fig7-payment-distribution     4.3   output/tables/payment-by-stratum.csv
#   fig8-regressivity             4.4   output/tables/regressivity.csv, observed-hacrp-regressivity.csv
#
# Verify (Task 5.1): every figure regenerates from raw, none touched in an image
# editor. The manifest records each PNG's sha256 next to the inputs it read; a
# second run must reproduce every hash (the cairo PNG device is deterministic),
# and the stage checks that on each run against the previous manifest.

source(file.path("R", "fig-theme.R"))
if (!exists("sha256_file")) source(file.path("R", "provenance.R"))

hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
TB  <- function(f) read.csv(file.path("output", "tables", f), stringsAsFactors = FALSE)
SRC <- function(...) paste0("Source: make.R stage 38 (R/12-figures.R), drawn from ", paste(..., sep = ", "), ".")

hdr("TASK 5.1  the final figure suite")
INPUTS <- list()
used <- function(fig, ...) INPUTS[[fig]] <<- c(...)

# ==========================================================================
# FIGURE 1  variance decomposition, published score (primary) beside the
# reliability-weighted sensitivity (Task S2.1: the published score is the
# filled marker; the weighted fit is open and never shown alone)
# ==========================================================================
VD <- TB("variance-decomposition.csv")
used("fig2-variance-decomposition", "output/tables/variance-decomposition.csv")
BLK <- c(structure = "Structure (Block A)", community = "Community (Block B)",
         policy = "Policy (Block C)")
comp <- VD[grepl("^composite", VD$source), ]
unc  <- comp[grepl("^published", comp$version), ]; cor <- comp[grepl("^reliability-weighted", comp$version), ]
stopifnot(nrow(unc) == 4, nrow(cor) == 4)
mix  <- VD[grepl("^components", VD$source), ]
g <- function(d, b, v) d[d$block == b, v]

fig_render("fig2-variance-decomposition", 3.5, function() {
  fig_frame("How much of the variation in PSI-90 each block accounts for",
            "Shapley (LMG) share, averaged over every order of entry. Line = 95% bootstrap interval (A: hospitals resampled; B: HSAs resampled).",
            SRC("output/tables/variance-decomposition.csv (Task 3.3)"))
  fig_layout(matrix(1:2, 1), widths = c(1.12, 1))
  y <- 3:1
  ## A: the composite, both versions
  par(mar = c(3.4, 12.5, 3.1, 1.2))
  fig_panel(c(0, 0.08), c(0.5, 3.6), xat = seq(0, 0.08, 0.02), xfmt = fmt_pct(0), yaxis = FALSE,
            xlab = "share of Var(PSI-90)")
  fig_rowlabels(y, BLK)
  for (i in 1:3) {
    b <- names(BLK)[i]
    fig_ci(g(unc, b, "share"), y[i] + 0.14, g(unc, b, "ci_lo"), g(unc, b, "ci_hi"), col = FIG$blue)
    fig_ci(g(cor, b, "share"), y[i] - 0.14, g(cor, b, "ci_lo"), g(cor, b, "ci_hi"), col = FIG$grey, open = TRUE)
  }
  fig_ptitle("A", "Published composite, n = 2,569")
  fig_key(list(list(label = "published score, unweighted", type = "dot", col = FIG$blue),
               list(label = "reliability-weighted (\u03bb), sensitivity", type = "open", col = FIG$grey)),
          x = 0, y = 3.62)
  fig_note(0.08, 0.55, sprintf("Unexplained: %.1f%% unweighted, %.1f%% weighted",
                               100 * g(unc, "residual", "share"), 100 * g(cor, "residual", "share")),
           adj = c(1, 0.5), cex = 0.78)
  ## B: the components model
  par(mar = c(3.4, 1.2, 3.1, 1.2))
  mb <- mix[mix$block != "residual", ]
  xB <- c(min(0, mb$ci_lo), max(mb$ci_hi)) + c(-0.02, 0.02) * diff(range(c(0, mb$ci_lo, mb$ci_hi)))
  fig_panel(xB, c(0.5, 3.6), xat = pretty(xB, 5), xfmt = fmt_pct(0), yaxis = FALSE,
            xlab = "share of between-hospital variance (null model)")
  fig_ref(v = 0)
  for (i in 1:3) { b <- names(BLK)[i]
    fig_ci(g(mix, b, "share"), y[i], g(mix, b, "ci_lo"), g(mix, b, "ci_hi"), col = FIG$blue) }
  fig_ptitle("B", "Four PSI components, same 2,569 hospitals")
  fig_note(xB[2], grconvertY(grconvertY(3.6 + 0.155, "user", "inches") + 0.08 - 0.0, "inches", "user"),
           sprintf("Unexplained: %.1f%%", 100 * g(mix, "residual", "share")), adj = c(1, 0.5), cex = 0.85)
  fig_note(xB[2], 0.55, if (all(with(mix[mix$block != "residual", ], share >= ci_lo & share <= ci_hi)))
             "Interval: HSAs resampled whole (Task 3.3)" else "Interval misses an estimate; indicative only (Task 3.3)",
           adj = c(1, 0.5), cex = 0.78)
})
cat(sprintf("  fig2: composite community share %.2f%% -> %.2f%% under correction; structure %.2f%% -> %.2f%%\n",
            100 * g(unc, "community", "share"), 100 * g(cor, "community", "share"),
            100 * g(unc, "structure", "share"), 100 * g(cor, "structure", "share")))
mix_out <- with(mix[mix$block != "residual", ], block[share < ci_lo | share > ci_hi])
if (length(mix_out))
  cat(sprintf("  fig2 NOTE: components-model point estimate lies OUTSIDE its bootstrap interval for: %s\n",
              paste(mix_out, collapse = ", ")))

# ==========================================================================
# FIGURE 2  reliability by volume
# ==========================================================================
A  <- readRDS(file.path("data", "analytic-v2.rds"))
RV <- TB("reliability-by-volume.csv")
used("fig1-reliability-by-volume", "data/analytic-v2.rds", "output/tables/reliability-by-volume.csv")
d2 <- A[is.finite(A$lambda_i) & is.finite(A$volume_bills_fy2026) & A$volume_bills_fy2026 > 0,
        c("lambda_i", "volume_bills_fy2026", "urban_rural")]
qv <- RV[RV$volume_quartile != "all", ]
LOC <- c(LURBAN = "Large urban", OURBAN = "Other urban", RURAL = "Rural")

fig_render("fig1-reliability-by-volume", 3.4, function() {
  fig_frame("Reliability of the published PSI-90 under the project's scalar approximation",
            "Under that approximation, λ = share of a hospital's own deviation the published value keeps; not a reconstruction of CMS's component smoothing.",
            SRC("data/analytic-v2.rds", "output/tables/reliability-by-volume.csv (Task 2.2)"))
  fig_layout(matrix(1:2, 1), widths = c(1.55, 1))
  ## A: lambda against volume
  par(mar = c(3.4, 3.6, 3.1, 1.2))
  xv <- log10(d2$volume_bills_fy2026)
  fig_panel(c(0.6, 4.55), c(0, 1), grid = "xy", xat = 1:4, yat = seq(0, 1, 0.25),
            xfmt = function(x) formatC(10^x, format = "d", big.mark = ","), yfmt = fmt_num(2),
            xlab = "Medicare discharges (bills), log scale", ylab = "reliability λ")
  points(xv, d2$lambda_i, pch = 16, cex = 0.32, col = grDevices::adjustcolor(FIG$blue_lt, 0.55))
  qx <- log10(qv$bills_median)
  lines(qx, qv$mean_lambda, col = FIG$blue_dk, lwd = 1.6)
  fig_ci(qv$mean_lambda, qx, col = FIG$blue_dk, horiz = FALSE, cex = 1.35)
  for (i in seq_len(nrow(qv)))
    fig_note(qx[i] - 0.07, qv$mean_lambda[i] + 0.035, sprintf("%s  %.2f", c("Q1", "Q2", "Q3", "Q4")[i], qv$mean_lambda[i]),
             adj = c(1, 0), cex = 0.8, col = FIG$ink)
  fig_ptitle("A", sprintf("By Medicare volume, n = %s", format(nrow(d2), big.mark = ",")))
  fig_key(list(list(label = "hospital", type = "dot", col = FIG$blue_lt),
               list(label = "volume-quartile mean", type = "dot", col = FIG$blue_dk)))
  ## B: lambda by hospital location
  par(mar = c(3.4, 1.2, 3.1, 1.2))
  fig_panel(c(0.5, 3.5), c(0, 1), grid = "y", xat = 1:3, yat = seq(0, 1, 0.25), xaxis = FALSE,
            yfmt = function(x) rep("", length(x)))
  set.seed(51)
  for (j in 1:3) {
    v <- d2$lambda_i[d2$urban_rural == names(LOC)[j] & !is.na(d2$urban_rural)]
    points(j + runif(length(v), -0.28, 0.28), v, pch = 16, cex = 0.32,
           col = grDevices::adjustcolor(FIG$blue_lt, 0.55))
    m <- median(v); segments(j - 0.36, m, j + 0.36, m, col = FIG$blue_dk, lwd = 2.4, lend = 1)
    fig_note(j + 0.39, m, sprintf("%.2f", m), cex = 0.8, col = FIG$ink)
    axis(1, at = j, labels = sprintf("%s\nn = %s", LOC[j], format(length(v), big.mark = ",")),
         lwd = 0, line = -0.2, cex.axis = 0.88, col.axis = FIG$ink2, padj = 0.5)
  }
  fig_ptitle("B", "By hospital location")
  fig_key(list(list(label = "median", type = "line", col = FIG$blue_dk)))
})
cat(sprintf("  fig1: quartile mean lambda %s; median by location %s\n",
            paste(sprintf("%.3f", qv$mean_lambda), collapse = " / "),
            paste(sprintf("%s %.3f", names(LOC), tapply(d2$lambda_i, d2$urban_rural, median)[names(LOC)]),
                  collapse = ", ")))

# ==========================================================================
# FIGURE 3  the specification curve
# ==========================================================================
SC <- TB("spec-curve-points.csv")
RS <- TB("rashomon-set.csv")
used("fig3-spec-curve", "output/tables/spec-curve-points.csv", "output/tables/rashomon-set.csv")
in_set <- RS$spec_id[RS$outcome == "composite" & RS$unit == "hospital" & RS$role == "primary" & RS$in_set]
SC <- SC[order(SC$rank), ]
nS <- nrow(SC); medS <- median(SC$dis_std)
AX <- list(
  blocks      = c(AB = "A + B", ABC = "A + B + C"),
  form        = c(linear = "linear", spline = "spline"),
  outcome     = c(composite = "PSI-90 composite", agg = "component aggregate", psi03 = "PSI-03",
                  psi06 = "PSI-06", psi12 = "PSI-12", psi13 = "PSI-13"),
  reliability = c(unweighted = "unweighted", weighted = "λ-weighted", subsample = "high-λ subsample",
                  eiv = "errors-in-variables"),
  grain       = c(catch_tract = "catchment, tract", catch_county = "catchment, county",
                  hosp_county = "hospital's county", hsa = "HSA"),
  missing     = c(na = "no Block C", mi = "multiple imputation", complete = "complete case", omit = "omitted"),
  influential = c(all = "all hospitals", drop_fn2329 = "drop footnote 23/29", drop_fallback = "drop fallback catchments"),
  scale       = c(identity = "identity", log = "log"))
AXN <- c(blocks = "Covariate blocks", form = "Functional form", outcome = "Outcome", reliability = "Reliability",
         grain = "Geographic grain", missing = "Block C missingness", influential = "Influential points",
         scale = "Outcome scale")
rows <- do.call(rbind, lapply(names(AX), function(a) data.frame(axis = a, level = names(AX[[a]]),
                                                                  label = unname(AX[[a]]))))
nrow_g <- nrow(rows) + length(AX) + 1                         # + one header per axis + the set row
fig_render("fig3-spec-curve", 8.4, function() {
  fig_frame("The ten-measure disadvantage contrast across every registered specification",
            sprintf("%s specifications that carry Block B, sorted by estimate: the p10-to-p90 disadvantage contrast in SDs of each outcome.",
                    format(nS, big.mark = ",")),
            SRC("output/tables/spec-curve-points.csv (Task 3.7)", "rashomon-set.csv (Task 3.10)"))
  fig_layout(matrix(1:2, 2), heights = c(1, 2.35))
  ## A: the curve
  par(mar = c(0.8, 11.5, 3.1, 5.2))
  yl <- range(c(SC$lo, SC$hi))
  fig_panel(c(1, nS), yl, grid = "y", xaxis = FALSE, yat = seq(-2, 3, 1), yfmt = fmt_sgn(0),
            ylab = "estimate, SD of outcome")
  sig <- SC$lo > 0 | SC$hi < 0
  segments(SC$rank, SC$lo, SC$rank, SC$hi, col = FIG$blue_xl, lwd = 0.35)
  fig_ref(h = 0)
  points(SC$rank[!sig], SC$dis_std[!sig], pch = 16, cex = 0.28, col = FIG$blue_lt)
  points(SC$rank[sig], SC$dis_std[sig], pch = 16, cex = 0.32, col = FIG$blue_dk)
  segments(1, medS, nS, medS, col = FIG$ink2, lwd = 0.6)
  fig_note(nS * 1.03, medS + 0.3, sprintf("median %+.2f", medS), cex = 0.78)
  fig_note(nS * 0.01, yl[2] * 0.93, sprintf("%.1f%% positive;  %.1f%% positive and clear of zero;  %.1f%% negative and clear of zero",
                                         100 * mean(SC$dis_std > 0), 100 * mean(SC$lo > 0), 100 * mean(SC$hi < 0)),
           cex = 0.8, col = FIG$ink)
  fig_ptitle("A", "The curve")
  fig_key(list(list(label = "interval clears zero", type = "dot", col = FIG$blue_dk),
               list(label = "interval spans zero", type = "dot", col = FIG$blue_lt),
               list(label = "95% interval", type = "line", col = FIG$blue_xl)))
  ## B: the choices behind each point
  par(mar = c(3.0, 11.5, 3.1, 5.2))
  fig_panel(c(1, nS), c(0.5, nrow_g + 0.5), grid = "", xat = c(1, seq(500, 3000, 500)),
            xfmt = function(x) format(x, big.mark = ","), yaxis = FALSE,
            xlab = "specification, ranked by estimate")
  y <- nrow_g
  tk <- function(r, yy, col) segments(r, yy - 0.34, r, yy + 0.34, col = col, lwd = 0.35)
  tk(SC$rank[SC$spec_id %in% in_set], y, FIG$orange)
  fig_rowlabels(y, "Rashomon set (composite)", font = 2)
  fig_note(nS * 1.01, y, sprintf("n = %d", sum(SC$spec_id %in% in_set)), cex = 0.78)
  y <- y - 1
  for (a in names(AX)) {
    fig_rowlabels(y, AXN[[a]], font = 2); y <- y - 1
    for (lv in names(AX[[a]])) {
      k <- SC[[a]] == lv
      tk(SC$rank[k], y, FIG$ink2)
      fig_rowlabels(y, AX[[a]][[lv]], col = FIG$ink2, cex = 0.86)
      fig_note(nS * 1.01, y, sprintf("%+.2f", median(SC$dis_std[k])), cex = 0.78)
      y <- y - 1
    }
  }
  fig_note(nS * 1.01, nrow_g + 1.1, "median", cex = 0.78, font = 2)
  fig_ptitle("B", "The choices behind each specification (one tick per specification)")
})
cat(sprintf("  fig3: %d specs, median %+.3f SD, %.1f%% positive; %d composite Rashomon members marked\n",
            nS, medS, 100 * mean(SC$dis_std > 0), sum(SC$spec_id %in% in_set)))

# ==========================================================================
# FIGURE 4  model class reliance bounds, and the coefficient ranges beside them
# ==========================================================================
MB <- TB("mcr-bounds-blockB.csv"); MA <- TB("mcr-bounds-blockA.csv"); CR <- TB("rashomon-coef-ranges.csv")
used("fig4-mcr-bounds", "output/tables/mcr-bounds-blockB.csv", "output/tables/mcr-bounds-blockA.csv",
     "output/tables/rashomon-coef-ranges.csv")
MLAB <- c(svi1 = "SVI 1 socioeconomic", svi2 = "SVI 2 household", svi3 = "SVI 3 minority status",
          svi4 = "SVI 4 housing & transport", adi = "ADI, mean block-group rank", ice150 = "ICE (income)", uninsured = "uninsured share",
          limeng = "limited English", rurality = "rurality (RUCC)", pcp_density = "primary-care density",
          hhi = "HHI (outside the group)",
          beds = "beds", adc = "average daily census", occupancy = "occupancy", resident_to_bed = "residents per bed",
          teaching = "teaching", cmi = "case mix index", volume = "Medicare volume", dsh_pct = "DSH share",
          wage_index = "wage index", operating_margin = "operating margin", uncomp_care = "uncompensated care",
          cmi_drift = "CMI drift", contract_labor_share = "contract labor share",
          tort_n_reforms = "tort reforms (count)", tort_cap_total = "tort damage caps")
lab <- function(x) ifelse(x %in% names(MLAB), MLAB[x], x)
mcr_panel <- function(M, grp, glab, tag, ttl, left) {
  G <- M[M$group == grp, ]; P <- M[M$group != grp & M$role == "primary", ]
  P <- P[order(-P$mcr_minus), ]
  G <- G[match(c("hospital", "cbsa", "state"), G$unit), ]
  ny <- nrow(P) + 4
  par(mar = c(3.4, if (left) 11.5 else 11.5, 3.1, 1.0))
  fig_panel(c(0.99, 1.52), c(0.4, ny + 0.4), xat = seq(1, 1.5, 0.1), xfmt = fmt_num(1), yaxis = FALSE,
            xlab = "model class reliance (1 = no reliance)")
  fig_ref(v = 1)
  yb <- ny - 0:2
  fig_range(G$mcr_minus, G$mcr_plus, yb, col = c(FIG$blue_dk, FIG$grey, FIG$grey), lwd = c(5, 3, 3))
  fig_ci(G$mr_median, yb, col = FIG$ink, cex = 0.9)
  fig_rowlabels(yb[1], glab, font = 2)
  fig_rowlabels(yb[2:3], sprintf("at %s tolerance (%.1f%%)", c("metro-area", "state"), G$epsilon_pct[2:3]),
                col = FIG$ink2, cex = 0.84)
  fig_note(G$mcr_minus + 0.004, yb + 0.42, sprintf("%.3f", G$mcr_minus), adj = c(0, 0.5), cex = 0.74)
  yp <- rev(seq_len(nrow(P)))
  fig_range(P$mcr_minus, P$mcr_plus, yp, col = FIG$blue_lt, lwd = 4)
  fig_ci(P$mr_median, yp, col = FIG$ink, cex = 0.8)
  fig_rowlabels(yp, lab(P$group), col = FIG$ink2, cex = 0.86)
  fig_ptitle(tag, ttl)
}
fig_render("fig4-mcr-bounds", 8.2, function() {
  fig_frame("How much every near-optimal model relies on each block, and what they agree on",
            sprintf("Across the %d models in the Rashomon set (primary tolerance %.1f%% of the best model's loss). Bar = MCR− to MCR+, dot = median model.",
                    MB$n_models[1], MB$epsilon_pct[1]),
            SRC("output/tables/mcr-bounds-blockB.csv, mcr-bounds-blockA.csv (Task 3.12)", "rashomon-coef-ranges.csv"))
  fig_layout(rbind(1:2, c(3, 3)), heights = c(1.15, 1))
  mcr_panel(MB, "blockB_disadvantage", "Disadvantage group, all 10", "A", "Disadvantage group (primary)", TRUE)
  fig_key(list(list(label = "range over the set", type = "range", col = FIG$blue_lt),
               list(label = "median model", type = "dot", col = FIG$ink)))
  mcr_panel(MA, "blockA_structure", "Structure block, all 11", "B", "Hospital structure (secondary)", FALSE)
  ## C: coefficient ranges (contrasts), Block B and Block C
  C2 <- CR[CR$block %in% c("B disadvantage", "C policy"), ]
  C2 <- C2[order(C2$block != "B disadvantage", -C2$median), ]
  ny <- nrow(C2) + 1
  yy <- ny - seq_len(nrow(C2)) - (C2$block == "C policy") * 0 + 1
  yy[C2$block == "C policy"] <- yy[C2$block == "C policy"] - 0.6
  par(mar = c(3.4, 11.5, 3.1, 1.0))
  fig_panel(c(-1.05, 1.35), c(min(yy) - 0.6, max(yy) + 0.6), xat = seq(-1, 1.25, 0.25), xfmt = fmt_sgn(2),
            yaxis = FALSE, xlab = "SD of PSI-90 (positive = worse): 10th-to-90th percentile contrast for Block B, per SD of the covariate for Block C (C)")
  fig_ref(v = 0)
  one <- !C2$straddles_zero
  fig_range(C2$lo, C2$hi, yy, col = ifelse(one, FIG$blue, FIG$blue_lt), lwd = 4)
  fig_ci(C2$median, yy, col = FIG$ink, cex = 0.8)
  fig_rowlabels(yy, paste0(lab(C2$covariate), ifelse(C2$block == "C policy", "  (C)", "")), col = FIG$ink2, cex = 0.86)
  fig_ptitle("C", "Coefficient ranges: disadvantage measures and the admitted Block C covariates (no MCR, by design)")
  fig_key(list(list(label = "one sign across the set", type = "range", col = FIG$blue),
               list(label = "straddles zero", type = "range", col = FIG$blue_lt)))
})
cat(sprintf("  fig4: Block B MCR- %.4f (hospital) / %.4f (metro) / %.4f (state); Block A MCR- %.4f\n",
            MB$mcr_minus[MB$group == "blockB_disadvantage"][1], MB$mcr_minus[MB$group == "blockB_disadvantage"][2],
            MB$mcr_minus[MB$group == "blockB_disadvantage"][3], MA$mcr_minus[MA$group == "blockA_structure"][1]))

# ==========================================================================
# FIGURE 5  TIS: direct vs shared reliance, the flow matrix, the ranking
# ==========================================================================
TD <- TB("tis-decomposition.csv"); FL <- TB("tis-flow-matrix.csv")
used("fig5-tis-decomposition", "output/tables/tis-decomposition.csv", "output/tables/tis-flow-matrix.csv")
fig_render("fig5-tis-decomposition", 7.6, function() {
  fig_frame("Which disadvantage measures earn their importance, and which borrow it",
            "Reliance split into a direct part (what no other measure can reconstruct) and a shared part on loan from correlated neighbors; medians over the set.",
            SRC("output/tables/tis-decomposition.csv, tis-flow-matrix.csv (Task 3.14)"))
  fig_layout(rbind(1:2, 3:4), heights = c(1, 1.05))
  ## A: waterfall, direct then shared
  T1 <- TD; T1$dir <- T1$mr_dir_med - 1; T1$tot <- T1$dir + T1$delta_med
  T1 <- T1[order(T1$tot), ]; y <- seq_len(nrow(T1))
  par(mar = c(3.4, 9.5, 3.1, 1.0))
  fig_panel(c(-0.005, 0.037), c(0.4, nrow(T1) + 0.6), xat = seq(0, 0.035, 0.01), xfmt = fmt_num(2), yaxis = FALSE,
            xlab = "excess reliance over 1")
  fig_ref(v = 0)
  segments(0, y + 0.13, T1$dir, y + 0.13, col = FIG$blue, lwd = 5.5, lend = 1)
  segments(T1$dir, y - 0.13, T1$tot, y - 0.13, col = FIG$orange, lwd = 5.5, lend = 1)
  points(T1$tot, y - 0.13, pch = 21, bg = FIG$ink, col = FIG$surf, cex = 0.85)
  fig_rowlabels(y, lab(T1$measure), col = FIG$ink2, cex = 0.86)
  fig_ptitle("A", "Direct and shared reliance")
  fig_key(list(list(label = "direct", type = "range", col = FIG$blue),
               list(label = "shared", type = "range", col = FIG$orange),
               list(label = "marginal", type = "dot", col = FIG$ink)))
  ## B: TIS across the set
  T2 <- TD[order(TD$tis_med), ]; y <- seq_len(nrow(T2))
  par(mar = c(3.4, 9.5, 3.1, 1.0))
  fig_panel(c(0.995, 1.075), c(0.4, nrow(T2) + 0.6), xat = seq(1, 1.07, 0.02), xfmt = fmt_num(2), yaxis = FALSE,
            xlab = "total importance score (TIS)")
  fig_ref(v = 1)
  fig_range(T2$tis_lo, T2$tis_hi, y, col = ifelse(T2$cannot_ignore, FIG$blue, FIG$blue_lt), lwd = 4)
  fig_ci(T2$tis_med, y, col = FIG$ink, cex = 0.8)
  fig_rowlabels(y, lab(T2$measure), col = FIG$ink2, cex = 0.86)
  fig_ptitle("B", "Driver ranking, range over the set")
  fig_key(list(list(label = "direct reliance > 1 in every fitted member", type = "range", col = FIG$blue),
               list(label = "sender term only", type = "range", col = FIG$blue_lt)))
  ## C: flow matrix
  ms <- TD$measure[order(-TD$tis_med)]
  M <- matrix(0, length(ms), length(ms), dimnames = list(ms, ms))
  for (i in seq_len(nrow(FL))) if (FL$from[i] %in% ms && FL$to[i] %in% ms) M[FL$from[i], FL$to[i]] <- FL$flow[i]
  lim <- max(abs(M)); k <- length(ms)
  par(mar = c(4.2, 9.5, 3.1, 3.2))
  plot.new(); plot.window(c(0.5, k + 0.5), c(0.5, k + 0.5), xaxs = "i", yaxs = "i")
  for (i in 1:k) for (j in 1:k)
    rect(j - 0.5, k - i + 0.5, j + 0.5, k - i + 1.5, border = FIG$surf, lwd = 1.2,
         col = if (i == j) FIG$surf else fig_div_col(M[i, j], lim))
  SH <- c(svi1 = "SVI 1", svi2 = "SVI 2", svi3 = "SVI 3", svi4 = "SVI 4", adi = "ADI rank", ice150 = "ICE",
          uninsured = "unins.", limeng = "lim. Eng.", rurality = "rural", pcp_density = "PCP")
  fig_rowlabels(k:1, lab(ms), col = FIG$ink2, cex = 0.8)
  axis(1, at = 1:k, labels = SH[ms], las = 2, lwd = 0, line = -0.6, cex.axis = 0.8, col.axis = FIG$ink2)
  mtext("lender (column)", side = 1, line = 3.3, cex = 0.8, col = FIG$ink2)
  ## colour key
  op <- par(xpd = NA); cols <- fig_diverging(41)
  for (s in seq_along(cols)) rect(k + 0.8, 0.5 + (s - 1) * k / 41, k + 1.2, 0.5 + s * k / 41, col = cols[s], border = NA)
  text(k + 1.35, c(0.6, k / 2 + 0.5, k + 0.4), sprintf("%+.3f", c(-lim, 0, lim)), adj = 0, cex = 0.66, col = FIG$ink2)
  par(op)
  fig_ptitle("C", "Flow matrix: row's reliance on loan from column")
  ## D: Shapley vs TIS
  par(mar = c(3.4, 4.2, 3.1, 1.0))
  fig_panel(c(0, 0.0205), c(1.003, 1.030), grid = "xy", xat = seq(0, 0.015, 0.005), yat = seq(1.005, 1.03, 0.005),
            xfmt = fmt_num(3), yfmt = fmt_num(3), xlab = "Shapley share of R² (at the best model)",
            ylab = "TIS, median over the set")
  points(TD$shapley, TD$tis_med, pch = 21, bg = ifelse(TD$cannot_ignore, FIG$blue, FIG$blue_lt), col = FIG$surf,
         cex = 1.25, lwd = 1.1)
  ly <- fig_repel(TD$shapley + 0.0004, TD$tis_med, lab(TD$measure), cex = 0.74)
  fig_note(TD$shapley + 0.0004, ly, lab(TD$measure), cex = 0.74)
  rho <- cor(TD$shapley, TD$tis_med, method = "spearman")
  fig_ptitle("D", sprintf("Shapley and TIS answer different questions (Spearman %+.2f)", rho))
})
cat(sprintf("  fig5: TIS order %s\n", paste(TD$measure[order(-TD$tis_med)], collapse = " > ")))

# ==========================================================================
# FIGURE 6  archetype validation
# ==========================================================================
AC <- TB("archetype-cells.csv"); AV <- TB("archetype-validation.csv")
used("fig6-archetype-validation", "output/tables/archetype-cells.csv", "output/tables/archetype-validation.csv")
st <- AC[AC$arm == "star", ]
gam <- AV[AV$claim == "C1 gradient (gamma)" & grepl("primary", AV$track), ]
tcs <- AV[AV$claim == "C2 Track-cell share" & grepl("primary", AV$track), ]
sn  <- AV[AV$claim == "C3 safety-net share", ]
memo_sn <- do.call(rbind, lapply(strsplit(sn$memo, "-"), as.numeric))
trk <- st[st$track %in% c("T1", "T2", "T3"), ]; trk <- trk[order(trk$track), ]
memo_beds <- as.numeric(strsplit(AV$memo[AV$claim == "C4 beds rise with Track"], " / ")[[1]])
fig_render("fig6-archetype-validation", 3.7, function() {
  stopifnot(AV$result[AV$claim == "VERDICT"] == "GRADIENT, NOT STRATA")   # the title states the verdict
  fig_frame("Gradient, not strata: hospitals concentrate only modestly in the three Track cells",
            sprintf("CMS star rating x operating-margin tercile. Gradient γ = %+.2f [%+.2f, %+.2f]; Track cells hold %.0f%% of hospitals (independence 33%%; operational bar 50%%).",
                    gam$estimate, gam$ci_lo, gam$ci_hi, 100 * tcs$estimate),
            SRC("output/tables/archetype-cells.csv, archetype-validation.csv (Task 3.16)"))
  fig_layout(matrix(1:3, 1), widths = c(1.35, 1, 1))
  ## A: observed / expected heatmap
  par(mar = c(3.4, 6.0, 3.1, 0.8))
  plot.new(); plot.window(c(0.5, 3.5), c(0.5, 3.5), xaxs = "i", yaxs = "i")
  lim <- log(1.3)
  for (r in seq_len(nrow(st))) with(st[r, ], {
    fc <- fig_div_col(log(obs_exp), lim); tc <- fig_on(fc)
    rect(margin - 0.5, safety - 0.5, margin + 0.5, safety + 0.5, border = FIG$surf, lwd = 2, col = fc)
    text(margin, safety + 0.06, sprintf("%.2f×", obs_exp), cex = 1.0, col = tc, font = 2)
    text(margin, safety - 0.18, sprintf("n = %d", n), cex = 0.8, col = tc)
    if (track != "off-Track") {
      rect(margin - 0.47, safety - 0.47, margin + 0.47, safety + 0.47, border = FIG$ink, lwd = 1.6)
      text(margin - 0.4, safety + 0.36, track, adj = c(0, 0.5), cex = 0.8, font = 2, col = tc)
    }
  })
  axis(1, at = 1:3, labels = c("thin", "middle", "comfortable"), lwd = 0, line = -0.6, cex.axis = 0.88, col.axis = FIG$ink2)
  mtext("operating-margin tercile", side = 1, line = 1.7, cex = 0.8, col = FIG$ink2)
  fig_rowlabels(1:3, c("1-2 stars", "3 stars", "4-5 stars"), col = FIG$ink2, cex = 0.88)
  fig_ptitle("A", "Observed / expected under independence")
  ## B: safety-net share per Track
  par(mar = c(3.4, 3.8, 3.1, 0.8))
  fig_panel(c(0.5, 3.5), c(0, 0.75), grid = "y", xat = 1:3, yat = seq(0, 0.75, 0.25), yfmt = fmt_pct(0),
            xfmt = function(x) c("T1", "T2", "T3")[x], ylab = "safety-net share")
  rect(1:3 - 0.3, memo_sn[, 1], 1:3 + 0.3, memo_sn[, 2], col = FIG$band, border = NA)
  fig_ci(sn$estimate, 1:3, sn$ci_lo, sn$ci_hi, horiz = FALSE)
  fig_note(1:3 + 0.33, sn$estimate, sn$result, cex = 0.74)
  fig_ptitle("B", "Safety-net share")
  fig_key(list(list(label = "memo range", type = "box", col = FIG$band),
               list(label = "observed", type = "dot", col = FIG$blue)))
  ## C: beds per Track
  fig_panel(c(0.5, 3.5), c(0, 550), grid = "y", xat = 1:3, yat = seq(0, 500, 100),
            xfmt = function(x) c("T1", "T2", "T3")[x], ylab = "median beds")
  fig_ci(memo_beds, 1:3, col = FIG$grey, open = TRUE, horiz = FALSE)
  fig_ci(trk$beds_median, 1:3, horiz = FALSE)
  fig_ptitle("C", "Median beds")
  fig_key(list(list(label = "memo input", type = "open", col = FIG$grey),
               list(label = "cell", type = "dot", col = FIG$blue)))
})
cat(sprintf("  fig6: gamma %+.3f, Track-cell share %.3f, beds %s vs memo %s\n", gam$estimate, tcs$estimate,
            paste(trk$beds_median, collapse = "/"), paste(memo_beds, collapse = "/")))

# ==========================================================================
# FIGURE 7  simulated payment distribution by stratum
# ==========================================================================
PB <- TB("payment-by-stratum.csv")
used("fig7-payment-distribution", "output/tables/payment-by-stratum.csv")
PG <- list(list(g = "adi", t = "Catchment ADI quintile", x = c("1\nleast", "2", "3", "4", "5\nmost")),
           list(g = "model_dis", t = "Model disadvantage", x = c("1\nleast", "2", "3", "4", "5\nmost")),
           list(g = "safety_net", t = "Safety net", x = c("no", "yes")),
           list(g = "cells", t = "Star band x margin tercile",
                x = c(rep(c("thin", "mid", "comf"), 3), "\u2013"),
                grp = list(at = c(2, 5, 8, 10), lab = c("1-2 stars", "3 stars", "4-5 stars", "unrated"))))
fig_render("fig7-payment-distribution", 5.2, function() {
  fig_frame("Where a Q-HIP-style bonus would go: the rate is nearly flat, the dollars are not",
            "Simulated national what-if, base scenario. Dot = mean over draws, line = 95% interval (Rashomon specification, parameters, PSI-90 reliability).",
            SRC("output/tables/payment-by-stratum.csv (Task 4.3)"))
  fig_layout(rbind(1:4, 5:8), widths = c(5, 5, 2.9, 9.6))
  yr <- list(rate = c(1.2, 2.65), pay = c(0, 3.8))
  for (row in c("rate", "pay")) for (pi in seq_along(PG)) {
    P <- PG[[pi]]; D <- PB[PB$group == P$g, ]; k <- nrow(D)
    par(mar = c(if (row == "pay") 3.4 else 1.0, if (pi == 1) 5.2 else 1.0, 3.1, 0.6))
    fig_panel(c(0.4, k + 0.6), yr[[row]], grid = "y", xat = seq_len(k), xaxis = FALSE,
              yat = if (row == "rate") seq(1.25, 2.5, 0.25) else 0:3,
              yfmt = if (pi == 1) (if (row == "rate") function(x) sprintf("%.2f%%", x) else function(x) sprintf("$%.0fM", x))
                     else function(x) rep("", length(x)),
              ylab = if (pi == 1) (if (row == "rate") "bonus, % of eligible revenue" else "bonus per hospital") else NULL,
              ylab_line = 3.4)
    if (row == "rate") {
      fig_ci(D$rate_fixed_pct, seq_len(k) + 0.17, col = FIG$grey, open = TRUE, horiz = FALSE)
      fig_ci(D$rate_pct, seq_len(k) - 0.08, D$rate_lo, D$rate_hi, horiz = FALSE)
      fig_ptitle(LETTERS[pi], P$t)
      if (pi == 1) fig_key(list(list(label = "reliability drawn", type = "dot", col = FIG$blue),
                                list(label = "PSI-90 fixed at published", type = "open", col = FIG$grey)))
    } else {
      fig_ci(D$pay_musd, seq_len(k), D$pay_lo, D$pay_hi, horiz = FALSE)
      fig_xlabels(seq_len(k), P$x, cex = 0.8)
      if (!is.null(P$grp)) fig_xlabels(P$grp$at, P$grp$lab, line = 1.3, cex = 0.8, col = FIG$ink)
    }
  }
})
cat(sprintf("  fig7: ADI Q1 $%.2fM vs Q5 $%.2fM per hospital; rate %.2f%% vs %.2f%%\n",
            PB$pay_musd[PB$stratum == "adi_q1"], PB$pay_musd[PB$stratum == "adi_q5"],
            PB$rate_pct[PB$stratum == "adi_q1"], PB$rate_pct[PB$stratum == "adi_q5"]))

# ==========================================================================
# FIGURE 8  regressivity
# ==========================================================================
RG <- TB("regressivity.csv"); OB <- TB("observed-hacrp-regressivity.csv")
used("fig8-regressivity", "output/tables/regressivity.csv", "output/tables/observed-hacrp-regressivity.csv")
## Task S1.6: the finite payment return replaces the marginal incentive, and
## "headroom" is "distance from the best measured score"
## Task S3.3: RK matches the table's ranked_by keys; only the display labels (RKL)
## carry the ADI definition (a catchment average of published block-group ranks)
RK <- c("distance from the best measured score", "model-implied disadvantage", "catchment ADI")
R8 <- RG[RG$model_set == "primary (194)" & grepl("^finite payment return", RG$quantity) & RG$ranked_by %in% RK, ]
RKL <- c("distance from best", "model-implied disadvantage", "catchment ADI (mean BG rank)")[match(RK, RK)]
rowsR <- expand.grid(r = RK, f = c("per NPR dollar", "per hospital"), stringsAsFactors = FALSE)
fig_render("fig8-regressivity", 4.3, function() {
  fig_frame("Who a 0.05 improvement pays, per revenue dollar and per hospital, and who HACRP penalizes today",
            "Project-defined rank rule with CASH2's bonus band and revenue share. Negative index = return concentrated where distance or disadvantage is low.",
            SRC("output/tables/regressivity.csv, observed-hacrp-regressivity.csv (Task 4.4)"))
  fig_layout(matrix(1:2, 1), widths = c(1.25, 1))
  ## A: forest
  y <- c(7, 6, 5, 3, 2, 1)
  par(mar = c(3.4, 12.5, 3.1, 5.6))
  xl8 <- c(min(-0.25, floor(20 * min(R8$lo[!grepl("ratio", R8$ranked_by)])) / 20), 0.07)
  fig_panel(xl8, c(0.4, 8.2), xat = seq(xl8[1], 0.05, 0.05), xfmt = fmt_sgn(2), yaxis = FALSE,
            xlab = "concentration index")
  fig_ref(v = 0)
  for (i in seq_len(nrow(rowsR))) {
    S <- R8[R8$framing == rowsR$f[i] & R8$ranked_by == rowsR$r[i], ]
    o <- S[S$scenario != "base", ]; b <- S[S$scenario == "base", ]
    segments(o$mean, y[i] - 0.2, o$mean, y[i] + 0.2, col = FIG$grey, lwd = 0.9)
    fig_ci(b$mean, y[i], b$lo, b$hi)
    ## Task S5.5: the label says what the interval shows, in the report's words. An
    ## interval that excludes zero by less than 0.001 is "on the edge" (S1.6), and
    ## no label says "regressive", which the report reserves for the arithmetic claim.
    edge <- b$verdict %in% c("regressive", "progressive") && min(abs(c(b$lo, b$hi))) < 0.001
    vb <- if (b$verdict == "no clear direction") "no clear dir." else if (b$verdict == "no modeled variation") "no variation"
          else if (edge) "on the edge" else if (b$verdict == "regressive") "below zero" else "above zero"
    fig_note(0.075, y[i], paste0(vb, if (b$lo == b$hi) "*" else ""), cex = 0.8,
             col = if (b$verdict %in% c("no clear direction", "no modeled variation")) FIG$ink2 else FIG$ink,
             font = if (b$verdict %in% c("no clear direction", "no modeled variation") || edge) 1 else 2)
  }
  fig_rowlabels(y, paste("by", RKL[match(rowsR$r, RK)]), col = FIG$ink2, cex = 0.86)
  fig_rowlabels(c(8, 4), c("Per NPR dollar (headline)", "Per hospital"), font = 2)
  fig_note(xl8[1], 0.45, "* zero width: no modeled variation", cex = 0.72)
  fig_ptitle("A", "Simulated finite payment return")
  fig_key(list(list(label = "base scenario", type = "dot", col = FIG$blue),
               list(label = "other scenarios", type = "tick", col = FIG$grey)))
  ## B: observed HACRP penalty share
  OBG <- list(adi = "adi", md = "model_dis (mean v_B)", sn = "safety_net")
  D <- rbind(OB[OB$group == OBG$adi, ], OB[OB$group == OBG$md, ], OB[OB$group == OBG$sn, ])
  x <- c(1:5, 7:11, 13, 14.4)
  frame <- with(OB[OB$group == "safety_net", ], sum(penalised) / sum(n))
  par(mar = c(3.4, 3.8, 3.1, 0.8))
  fig_panel(c(0.3, 15), c(0, 0.4), grid = "y", yat = seq(0, 0.4, 0.1), yfmt = fmt_pct(0), xaxis = FALSE,
            ylab = "share of hospitals penalized")
  segments(0.3, frame, 15, frame, col = FIG$ink2, lwd = 0.8)
  fig_note(6, frame + 0.01, sprintf("all\n%.0f%%", 100 * frame), adj = c(0.5, 0), cex = 0.74)
  fig_ci(D$share, x, D$lo, D$hi, horiz = FALSE)
  fig_xlabels(x, c("1", "2", "3", "4", "5", "1", "2", "3", "4", "5", "no", "yes"))
  fig_xlabels(c(3, 9, 13.7), c("catchment ADI\nquintile", "model-implied\ndisadvantage", "safety\nnet"), line = 1.2,
              cex = 0.8, col = FIG$ink)
  fig_ptitle("B", "Observed HACRP penalty, FY 2026")
})
cat(sprintf("  fig8: per-NPR verdicts %s\n", paste(sprintf("%s=%s", R8$ranked_by, R8$verdict)[R8$scenario == "base" & R8$framing == "per NPR dollar"], collapse = ", ")))

# ==========================================================================
# MANIFEST  and the regeneration check
# ==========================================================================
hdr("manifest")
MF <- file.path(FIG_DIR, "MANIFEST.csv")
prev <- if (file.exists(MF)) read.csv(MF, stringsAsFactors = FALSE) else NULL
figs <- sort(names(INPUTS))
man <- data.frame(figure = paste0(figs, ".png"),
                  sha256 = vapply(file.path(FIG_DIR, paste0(figs, ".png")), sha256_file, ""),
                  bytes  = file.size(file.path(FIG_DIR, paste0(figs, ".png"))),
                  device = FIG_DEVICE, dpi = FIG$dpi,
                  inputs = vapply(figs, function(f) paste(INPUTS[[f]], collapse = "; "), ""),
                  row.names = NULL)
write.csv(man, MF, row.names = FALSE)
for (i in seq_len(nrow(man))) cat(sprintf("  %-34s %s  %8d bytes\n", man$figure[i], substr(man$sha256[i], 1, 16), man$bytes[i]))
stray <- setdiff(list.files(FIG_DIR, pattern = "\\.png$"), man$figure)
if (length(stray)) stop("files in output/figures/final/ that this stage did not draw: ", paste(stray, collapse = ", "))
if (!is.null(prev)) {
  m <- merge(prev[, c("figure", "sha256")], man[, c("figure", "sha256")], by = "figure", all = TRUE,
             suffixes = c("_prev", "_now"))
  same <- m$sha256_prev == m$sha256_now
  cat(sprintf("\n  against the previous manifest: %d of %d figures byte-identical\n", sum(same, na.rm = TRUE), nrow(m)))
  if (any(!same | is.na(same))) cat("  changed: ", paste(m$figure[!same | is.na(same)], collapse = ", "),
                                   "  (expected only when an input table or this script changed)\n")
}

hdr("verify")
cat(sprintf("  %d figures drawn by this stage, all through R/fig-theme.R; no other file in output/figures/final/ -- PASS\n", nrow(man)))
cat("  every input is a table or data product written by an earlier make.R stage (listed per figure in MANIFEST.csv) -- PASS\n")
hdr("done")
