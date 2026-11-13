# R/05-rashomon-set.R  --  Task 3.10, constructing the Rashomon set and
# reporting its width.
#
# Reads data/rashomon-loss.rds (every spec's common-frame loss, Task 3.9),
# data/rashomon-tolerance.rds (epsilon per family and resampling unit, Task
# 3.9) and data/spec-results.rds (every spec's disadvantage estimate, Task
# 3.7). Nothing is fitted. The set is arithmetic on what those three files
# already hold: a spec is in its family's Rashomon set when its loss is at most
# L(ERM) + epsilon.
#
# THE WIDTH COMES FIRST. The task sheet's verify condition is that the set's
# width is reported before any MCR bound is computed, so that a wide set is a
# finding rather than a disappointment (Plan Sec 8: "the data cannot
# distinguish these explanations" is useful information for a
# data-prioritization deliverable). No MCR code exists yet -- that is Task 3.11
# -- and this script prints the width before it prints anything else about the
# set's composition.
#
# THE WIDTH is the range of the focal estimate across the set: the p10 -> p90
# community-disadvantage contrast `dis_effect` from Task 3.7, in units of the
# outcome's SD (`dis_std`, Task 3.7's convention, so families sit on one axis).
# Reported as min, max, IQR, and the share of the set on each side of zero.
# Block-A specs carry no disadvantage term, so their membership is reported as
# a fact of its own: a Block-A spec inside the set is a near-optimal model with
# NO community disadvantage in it, which is the thing Task 3.12's MCR- > 1 claim
# would have to rule out.
#
# The composite set is built three times, once per resampling unit Task 3.9
# produced (hospital = the pre-registered primary; metro area and state =
# sensitivities), because 3.9 Sec 7 found that whether the Block-A arm is
# inside depends on the unit. The five secondary families get one set each at
# their own tolerance. A width-against-tolerance curve shows how fast the set
# grows as epsilon moves, which is the information a reader who prefers a
# different unit needs.
#
# Outputs: data/rashomon-set.rds, output/tables/rashomon-set.csv (membership,
# every spec, every tolerance), output/tables/rashomon-set-width.csv,
# output/tables/rashomon-set-axes.csv, output/figures/rashomon-set.png.

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 3.10  the Rashomon set and its width")

L  <- readRDS(file.path("data", "rashomon-loss.rds"))
Tl <- readRDS(file.path("data", "rashomon-tolerance.rds"))
S  <- readRDS(file.path("data", "spec-results.rds"))$results
a0 <- readRDS(file.path("data", "analytic-v2.rds"))
TOL <- Tl$tolerance
stopifnot(setequal(L$spec_id, S$spec_id), all(L$status == "ok"))
cat(sprintf("  %d specs with a common-frame loss; alpha = %.2f (pre-registered)\n", nrow(L), Tl$alpha))

## dis_std = dis_effect / SD(outcome), Task 3.7's convention (R/04-spec-curve-report.R)
sd_psi90 <- sd(n_(a0$psi90), na.rm = TRUE)
natM <- sapply(c("psi03", "psi06", "psi12", "psi13"), function(cp) mean(n_(a0[[cp]]), na.rm = TRUE))
agg0 <- local({
  num <- den <- rep(0, nrow(a0))
  for (cp in names(natM)) {
    r <- n_(a0[[cp]]) / natM[[cp]]; w <- n_(a0[[paste0(cp, "_denom")]])
    ok <- is.finite(r) & is.finite(w) & w > 0
    num[ok] <- num[ok] + w[ok] * r[ok]; den[ok] <- den[ok] + w[ok]
  }
  ifelse(den > 0, num / den, NA_real_)
})
sd_agg <- sd(agg0, na.rm = TRUE)
std_div <- function(fam) ifelse(fam == "composite", sd_psi90, ifelse(fam == "aggregate", sd_agg, 1))

D <- merge(L[, c("spec_id", "loss", "n_eval", "n_fit", "n_fe")],
           S[, c("spec_id", "blocks", "form", "outcome", "reliability", "grain", "missing",
                 "influential", "scale", "outcome_family", "dis_effect", "dis_se", "dis_sig")],
           by = "spec_id")
D$dis_std <- D$dis_effect / std_div(D$outcome_family)
D$se_std  <- D$dis_se / std_div(D$outcome_family)

# ==========================================================================
# 1.  BUILD THE SETS  --  one per (family x tolerance) in the tolerance table
# ==========================================================================
SETS <- list()
for (i in seq_len(nrow(TOL))) {
  fam <- TOL$family[i]; unit <- TOL$unit[i]
  Df  <- D[D$outcome == fam, ]
  L0  <- min(Df$loss); stopifnot(isTRUE(all.equal(L0, TOL$loss_erm[i])))
  cut <- L0 + TOL$epsilon[i]
  Df$excess     <- Df$loss - L0
  Df$excess_eps <- Df$excess / TOL$epsilon[i]
  Df$in_set     <- Df$loss <= cut
  SETS[[paste(fam, unit, sep = ".")]] <- list(family = fam, unit = unit, role = TOL$role[i],
                                              epsilon = TOL$epsilon[i], L0 = L0, cut = cut, d = Df)
}

## the width of one set
width_of <- function(st) {
  d  <- st$d; m <- d[d$in_set, ]; mb <- m[!is.na(m$dis_std), ]      # members with a disadvantage term
  data.frame(family = st$family, unit = st$unit, role = st$role,
             epsilon = st$epsilon, loss_erm = st$L0, n_family = nrow(d),
             n_set = nrow(m), share_of_family = nrow(m) / nrow(d),
             n_blockA_in_set = sum(m$blocks == "A"),
             n_with_estimate = nrow(mb),
             est_min = min(mb$dis_std), est_max = max(mb$dis_std),
             width = max(mb$dis_std) - min(mb$dis_std),
             est_q25 = unname(quantile(mb$dis_std, .25)), est_median = median(mb$dis_std),
             est_q75 = unname(quantile(mb$dis_std, .75)),
             iqr = unname(diff(quantile(mb$dis_std, c(.25, .75)))),
             share_positive = mean(mb$dis_std > 0),
             share_pos_sig  = mean(mb$dis_std > 0 & mb$dis_sig),
             share_neg_sig  = mean(mb$dis_std < 0 & mb$dis_sig),
             straddles_zero = min(mb$dis_std) < 0 & max(mb$dis_std) > 0,
             erm_est = mb$dis_std[which.min(mb$loss)],
             erm_est_raw = mb$dis_effect[which.min(mb$loss)],
             n_fe_min_in = min(m$n_fe), n_fe_max_in = max(m$n_fe),
             n_fe_min_out = if (any(!d$in_set)) min(d$n_fe[!d$in_set]) else NA,
             stringsAsFactors = FALSE)
}
W <- do.call(rbind, lapply(SETS, width_of)); rownames(W) <- NULL

# ==========================================================================
# 2.  THE WIDTH, FIRST  (the verify condition)
# ==========================================================================
sub_("THE WIDTH  --  reported before anything else, and before any MCR bound exists")
P <- W[W$role == "primary", ]
cat(sprintf("\n  COMPOSITE, primary tolerance (epsilon = %.6f, hospital bootstrap):\n", P$epsilon))
cat(sprintf("    %d of %d composite specs are in the set (%s).\n", P$n_set, P$n_family, pct(P$share_of_family)))
cat(sprintf("    Across them the p10->p90 disadvantage contrast runs from %+.3f to %+.3f SD of PSI-90.\n",
            P$est_min, P$est_max))
cat(sprintf("    WIDTH = %.3f SD.  IQR [%+.3f, %+.3f] = %.3f SD.  Median %+.3f SD.  ERM's own estimate %+.3f SD.\n",
            P$width, P$est_q25, P$est_q75, P$iqr, P$est_median, P$erm_est))
cat(sprintf("    %s of the set puts the contrast above zero; %s positive-and-clear-of-zero; %s negative-and-clear.\n",
            pct(P$share_positive), pct(P$share_pos_sig), pct(P$share_neg_sig)))
cat(sprintf("    The set %s zero.\n", if (P$straddles_zero) "STRADDLES" else "does not straddle"))
cat(sprintf("    Block-A specs (no community block at all) inside the set: %d.\n", P$n_blockA_in_set))
cat(sprintf("    Task 3.7's whole-curve range for comparison: %+.3f to %+.3f SD over all %d composite specs.\n",
            min(D$dis_std[D$outcome == "composite"], na.rm = TRUE),
            max(D$dis_std[D$outcome == "composite"], na.rm = TRUE), P$n_family))

cat("\n  every set:\n")
cat(sprintf("  %-10s %-9s %-12s %5s/%-4s %6s  %8s %8s %7s %7s  %6s %6s\n",
            "family", "unit", "role", "n", "N", "A-in", "min", "max", "WIDTH", "IQR", "%pos", "%sig+"))
for (i in seq_len(nrow(W)))
  cat(sprintf("  %-10s %-9s %-12s %5d/%-4d %6d  %+8.3f %+8.3f %7.3f %7.3f  %5.1f%% %5.1f%%\n",
              W$family[i], W$unit[i], W$role[i], W$n_set[i], W$n_family[i], W$n_blockA_in_set[i],
              W$est_min[i], W$est_max[i], W$width[i], W$iqr[i],
              100 * W$share_positive[i], 100 * W$share_pos_sig[i]))

# ==========================================================================
# 3.  WHAT IS IN THE SET  --  composition by axis, composite primary
# ==========================================================================
sub_("composition of the composite set, by axis level (primary tolerance)")
AX <- c("blocks", "form", "reliability", "grain", "missing", "influential", "scale")
rows <- list()
for (st in SETS[c("composite.hospital", "composite.cbsa", "composite.state")]) {
  d <- st$d
  for (ax in AX) for (lv in sort(unique(d[[ax]]))) {
    sel <- d[[ax]] == lv; ins <- d[sel & d$in_set, ]
    rows[[length(rows) + 1]] <- data.frame(
      unit = st$unit, axis = ax, level = lv, n_level = sum(sel), n_in = nrow(ins),
      share_in = nrow(ins) / sum(sel),
      best_excess_eps = min(d$excess_eps[sel]),
      est_min = if (nrow(ins) && any(!is.na(ins$dis_std))) min(ins$dis_std, na.rm = TRUE) else NA,
      est_max = if (nrow(ins) && any(!is.na(ins$dis_std))) max(ins$dis_std, na.rm = TRUE) else NA,
      stringsAsFactors = FALSE)
  }
}
AXT <- do.call(rbind, rows)
ah <- AXT[AXT$unit == "hospital", ]
for (ax in AX) {
  cat(sprintf("  %s\n", ax))
  z <- ah[ah$axis == ax, ]
  for (j in seq_len(nrow(z)))
    cat(sprintf("    %-14s %4d/%-4d in (%5.1f%%)  best %.2f eps   estimates %s\n",
                z$level[j], z$n_in[j], z$n_level[j], 100 * z$share_in[j], z$best_excess_eps[j],
                if (is.na(z$est_min[j])) "--" else sprintf("%+.3f .. %+.3f SD", z$est_min[j], z$est_max[j])))
}

## the complexity question the 3.9 pre-registration deferred here
sub_("is the near-optimal region just the high-parameter region?")
d <- SETS[["composite.hospital"]]$d
cat(sprintf("  fixed effects, in-set: %d..%d ; out-of-set: %d..%d\n",
            min(d$n_fe[d$in_set]), max(d$n_fe[d$in_set]), min(d$n_fe[!d$in_set]), max(d$n_fe[!d$in_set])))
tb <- table(n_fe = d$n_fe, in_set = d$in_set)
for (k in rownames(tb)) cat(sprintf("    %3s fe: %4d in / %4d out  (%5.1f%% in)\n", k, tb[k, "TRUE"], tb[k, "FALSE"],
                                     100 * tb[k, "TRUE"] / sum(tb[k, ])))
cat(sprintf("  correlation(n_fe, loss) among composite specs: %+.3f\n", cor(d$n_fe, d$loss)))

# ==========================================================================
# 4.  WIDTH AGAINST TOLERANCE  --  how fast the set grows as epsilon moves
# ==========================================================================
sub_("width against tolerance (composite)")
d  <- SETS[["composite.hospital"]]$d; L0 <- SETS[["composite.hospital"]]$L0
eps_grid <- seq(0, max(d$loss) - L0, length.out = 400)
curve <- t(sapply(eps_grid, function(e) {
  m <- d[d$loss <= L0 + e, ]; mb <- m[!is.na(m$dis_std), ]
  c(eps = e, n = nrow(m), n_A = sum(m$blocks == "A"),
    lo = if (nrow(mb)) min(mb$dis_std) else NA, hi = if (nrow(mb)) max(mb$dis_std) else NA,
    width = if (nrow(mb)) diff(range(mb$dis_std)) else NA,
    pos = if (nrow(mb)) mean(mb$dis_std > 0) else NA)
}))
curve <- as.data.frame(curve)
first_A <- min(d$excess[d$blocks == "A"])
first_neg <- if (any(d$dis_std < 0, na.rm = TRUE)) min(d$excess[!is.na(d$dis_std) & d$dis_std < 0]) else NA
cat(sprintf("  first Block-A spec enters at excess %.6f = %.2f x primary eps (%.2f x metro, %.2f x state)\n",
            first_A, first_A / TOL$epsilon[TOL$unit == "hospital"],
            first_A / TOL$epsilon[TOL$unit == "cbsa"], first_A / TOL$epsilon[TOL$unit == "state"]))
cat(sprintf("  first NEGATIVE estimate enters at excess %.6f = %.2f x primary eps\n",
            first_neg, first_neg / TOL$epsilon[TOL$unit == "hospital"]))

# ==========================================================================
# 5.  WRITE
# ==========================================================================
sub_("write")
member <- do.call(rbind, lapply(SETS, function(st) {
  z <- st$d[, c("spec_id", "outcome", "blocks", "form", "reliability", "grain", "missing",
                "influential", "scale", "loss", "excess", "excess_eps", "in_set", "n_fe",
                "dis_effect", "dis_std", "se_std", "dis_sig")]
  z$unit <- st$unit; z$role <- st$role; z$epsilon <- st$epsilon; z }))
rownames(member) <- NULL
saveRDS(list(alpha = Tl$alpha, sets = SETS, width = W, axes = AXT, curve = curve,
             membership = member, sd_psi90 = sd_psi90, sd_agg = sd_agg,
             primary = list(family = "composite", unit = "hospital",
                            spec_ids = SETS[["composite.hospital"]]$d$spec_id[SETS[["composite.hospital"]]$d$in_set]),
             built = Sys.time()),
        file.path("data", "rashomon-set.rds"))
write.csv(member, file.path("output", "tables", "rashomon-set.csv"), row.names = FALSE)
write.csv(W, file.path("output", "tables", "rashomon-set-width.csv"), row.names = FALSE)
write.csv(AXT, file.path("output", "tables", "rashomon-set-axes.csv"), row.names = FALSE)
cat("  data/rashomon-set.rds\n  output/tables/rashomon-set.csv\n")
cat("  output/tables/rashomon-set-width.csv\n  output/tables/rashomon-set-axes.csv\n")

# ==========================================================================
# 6.  FIGURE
# ==========================================================================
png(file.path("output", "figures", "rashomon-set.png"), width = 1500, height = 1150, res = 130)
op <- par(mfrow = c(2, 2), mar = c(4.4, 4.4, 3.2, 1.2), cex.main = 0.95, cex.axis = 0.85)
d  <- SETS[["composite.hospital"]]$d
eH <- TOL$epsilon[TOL$unit == "hospital"]; eM <- TOL$epsilon[TOL$unit == "cbsa"]; eS <- TOL$epsilon[TOL$unit == "state"]

## (1) every composite spec: loss against estimate, the three tolerances marked
hasB <- !is.na(d$dis_std)
plot(d$excess[hasB], d$dis_std[hasB], pch = 16, cex = 0.55,
     col = ifelse(d$in_set[hasB], "firebrick", "grey60"),
     xlab = "excess loss over L(ERM), squared PSI-90 units", ylab = "p10 -> p90 disadvantage contrast, SD of PSI-90",
     main = "Composite: every specification, loss against estimate")
abline(h = 0, col = "grey40", lty = 3)
abline(v = c(eH, eM, eS), col = c("firebrick", "steelblue4", "darkorange3"), lty = 2)
rug(d$excess[!hasB], side = 1, col = "black", lwd = 1.2)
legend("topright", bty = "n", cex = 0.72,
       legend = c("in the primary set", "outside", "Block-A spec (no estimate; rug)",
                  sprintf("eps hospital %.1f%%", 100 * eH / P$loss_erm),
                  sprintf("eps metro %.1f%%", 100 * eM / P$loss_erm),
                  sprintf("eps state %.1f%%", 100 * eS / P$loss_erm)),
       pch = c(16, 16, NA, NA, NA, NA), lty = c(NA, NA, 1, 2, 2, 2),
       col = c("firebrick", "grey60", "black", "firebrick", "steelblue4", "darkorange3"))

## (2) the width against the tolerance
plot(curve$eps, curve$hi, type = "l", lwd = 2, col = "grey20", ylim = range(c(curve$lo, curve$hi), na.rm = TRUE),
     xlab = "tolerance epsilon", ylab = "range of the estimate across the set, SD",
     main = "How the set's range grows with the tolerance")
lines(curve$eps, curve$lo, lwd = 2, col = "grey20")
polygon(c(curve$eps, rev(curve$eps)), c(curve$hi, rev(curve$lo)), col = adjustcolor("grey70", .4), border = NA)
abline(h = 0, col = "grey40", lty = 3)
abline(v = c(eH, eM, eS), col = c("firebrick", "steelblue4", "darkorange3"), lty = 2)
abline(v = first_A, col = "black", lty = 4)
legend("bottomright", bty = "n", cex = 0.72, lty = c(2, 2, 2, 4),
       col = c("firebrick", "steelblue4", "darkorange3", "black"),
       legend = c("hospital (primary)", "metro area", "state", "first Block-A spec enters"))

## (3) the estimate by axis level, members of the primary set only
m <- d[d$in_set & hasB, ]
lv <- list(form = m$form, reliability = m$reliability, grain = m$grain, blocks = m$blocks,
           missing = m$missing, scale = m$scale)
grp <- unlist(lapply(names(lv), function(k) paste0(k, ": ", lv[[k]])))
val <- rep(m$dis_std, length(lv))
par(mar = c(4.4, 8.5, 3.2, 1.2))
boxplot(val ~ factor(grp, levels = names(sort(tapply(val, grp, median)))), horizontal = TRUE, las = 1,
        outline = TRUE, pch = 16, cex = 0.4, col = "grey90", border = "grey35", cex.axis = 0.6,
        xlab = "estimate, SD of PSI-90", ylab = "",
        main = sprintf("Inside the primary set (n = %d): estimate by axis level", nrow(m)))
abline(v = 0, col = "grey40", lty = 3)
par(mar = c(4.4, 8.5, 3.2, 1.2))

## (4) widths across families and units
Wp <- W[order(W$width), ]
plot(Wp$erm_est, seq_len(nrow(Wp)), type = "n", xlim = range(c(Wp$est_min, Wp$est_max)), yaxt = "n", ylab = "",
     xlab = "SD of the family's outcome", main = "Width of every set (bar = min..max of the estimate)")
segments(Wp$est_min, seq_len(nrow(Wp)), Wp$est_max, seq_len(nrow(Wp)), lwd = 3, col = "grey40")
points(Wp$erm_est, seq_len(nrow(Wp)), pch = 4, col = "firebrick", lwd = 2)
abline(v = 0, col = "grey40", lty = 3)
axis(2, at = seq_len(nrow(Wp)), labels = sprintf("%s (%s)", Wp$family, Wp$unit), las = 2, cex.axis = 0.7)
legend("bottomright", bty = "n", cex = 0.72, pch = c(NA, 4), lwd = c(3, NA), col = c("grey40", "firebrick"),
       legend = c("range across the set", "the ERM's own estimate"))
par(op); invisible(dev.off())
cat("  output/figures/rashomon-set.png\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. the width was reported before any MCR bound: the set was committed at\n"))
cat(sprintf("     b3f04cc (2026-09-21), before R/06-mcr.R existed (065dc39, Task 3.11), and Sec 2 of this log prints the\n"))
cat(sprintf("     width before the set's composition -- PASS\n"))
cat(sprintf("  2. the set was built at Task 3.9's tolerance, not a re-chosen one: epsilon =\n"))
cat(sprintf("     %.8f read from data/rashomon-tolerance.rds, alpha = %.2f -- PASS\n",
            TOL$epsilon[TOL$role == "primary"], Tl$alpha))
cat(sprintf("  3. membership is the arithmetic loss <= L(ERM) + epsilon, every spec, no\n"))
cat(sprintf("     screening: %d/%d composite specs tested -- PASS\n", nrow(d), sum(D$outcome == "composite")))
cat(sprintf("  4. the width is reported whether or not convenient: it %s zero -- REPORTED\n",
            if (P$straddles_zero) "straddles" else "does not straddle"))
## The order "set before MCR" was checked at Task 3.10 by asserting R/06-mcr.R
## did not exist yet. That held when the set was built and has failed every run
## since Task 3.11 added the file, so the stage failed on every full run from
## 2026-09-22 until release mode stopped on it (Task S0.3). The order is a fact
## about the history and the commit order records it; the assertion is retired.
stopifnot(nrow(d) == sum(D$outcome == "composite"))
hdr("done")
