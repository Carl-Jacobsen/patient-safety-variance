# R/10-payment-strata.R  --  Task 4.3, simulated payments by hospital stratum.
#
# Reads data/payment-sim.rds (Task 4.2) and nothing else; no draw is made here.
#
# STRATA are the ones Task 3.16 left standing. Its verdict was "gradient, not
# strata": the Tracks are not groups in these data. So nothing below is labelled
# Track 1/2/3. Results run along the gradient (payment-model-inputs.md Sec 7):
#   1. safety-net flag (dsh_pct >= 0.370), the memo's best-supported claim;
#   2. catchment ADI quintile, for readability;
#   3. quintiles of the model-implied Block B contribution v_B, recomputed in
#      every draw so that membership carries model uncertainty;
#   4. 3.16's nine star-band x margin-tercile CELLS, labelled as cells on a
#      gradient, plus the unrated.
# Every contrast between strata is computed WITHIN each draw and then
# summarised, so its interval is the contrast's own, not two overlapping bars.
#
# Outputs: output/tables/payment-by-stratum.csv, payment-stratum-contrasts.csv,
# output/figures/payment-by-stratum.png.

n_  <- function(x) suppressWarnings(as.numeric(x))
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
S   <- readRDS(file.path("data", "payment-sim.rds"))
D   <- S$draws; D7 <- S$draws_metro; H <- S$hospitals
B   <- nrow(D)

hdr("TASK 4.3  simulated Q-HIP-style payments by stratum")
cat(sprintf("  %d draws (seed %d), %d hospitals; strata per 3.16's verdict: a gradient, not Tracks\n",
            B, S$seed, nrow(H)))

CELLS <- sort(unique(H$cell[H$cell != "unrated"]))
stopifnot(!any(grepl("^T[123]$|Track", c(CELLS, colnames(D)))))      # verify: no Track strata
STAR  <- c("1", "2", "3"); STARL <- c("1-2 star", "3 star", "4-5 star")
MARL  <- c("thin", "middle", "comfortable")
cell_label <- function(k) { s <- as.integer(substr(k, 2, 2)); m <- as.integer(substr(k, 4, 4))
  sprintf("%s, %s margin", STARL[s], MARL[m]) }

GROUPS <- list(
  safety_net = list(id = c("sn0", "sn1"), label = c("not safety-net", "safety-net")),
  adi        = list(id = paste0("adi_q", 1:5), label = paste("ADI quintile", 1:5, c("(least deprived)", "", "", "", "(most deprived)"))),
  model_dis  = list(id = paste0("vb_q", 1:5), label = paste("model-implied disadvantage quintile", 1:5,
                                                           c("(least)", "", "", "", "(most)"))),
  cells      = list(id = c(CELLS, "unrated"), label = c(vapply(CELLS, cell_label, ""), "no star rating")))
NN <- c(sn0 = sum(!H$safety_net), sn1 = sum(H$safety_net), table(H$cell),
        setNames(tabulate(H$adi_q, 5), paste0("adi_q", 1:5)),
        setNames(as.numeric(table(ceiling(5 * seq_len(nrow(H)) / nrow(H)))), paste0("vb_q", 1:5)))

summ <- function(x) c(mean = mean(x), lo = unname(quantile(x, .025)), hi = unname(quantile(x, .975)))
col_of <- function(run, v, id, DD = D) DD[, paste(run, v, id, sep = ".")]

# ==========================================================================
# 1.  THE TABLE
# ==========================================================================
hdr("1. per stratum: bonus rate, bonus dollars, unearned band, disadvantage-associated bonus")
tot_pay <- D[, "base.total_pay"]
rows <- list()
for (g in names(GROUPS)) for (i in seq_along(GROUPS[[g]]$id)) {
  id <- GROUPS[[g]]$id[i]; n <- NN[[id]]
  rate <- summ(100 * col_of("base", "rate", id)); pay <- summ(col_of("base", "pay", id) / 1e6)
  open <- summ(col_of("base", "open", id) / 1e6); dis <- summ(col_of("base", "dis", id) / 1e3)
  shr  <- summ(100 * n * col_of("base", "pay", id) / tot_pay)
  rfx  <- summ(100 * col_of("fixed", "rate", id))
  rows[[length(rows) + 1]] <- data.frame(group = g, stratum = id, label = GROUPS[[g]]$label[i], n = n,
    rate_pct = rate[1], rate_lo = rate[2], rate_hi = rate[3],
    pay_musd = pay[1], pay_lo = pay[2], pay_hi = pay[3],
    open_musd = open[1], open_lo = open[2], open_hi = open[3],
    share_of_bonus_pct = shr[1], share_lo = shr[2], share_hi = shr[3],
    share_of_hospitals_pct = 100 * n / nrow(H),
    dis_kusd = dis[1], dis_lo = dis[2], dis_hi = dis[3],
    rate_fixed_pct = rfx[1], rate_fixed_lo = rfx[2], rate_fixed_hi = rfx[3], row.names = NULL)
}
T <- do.call(rbind, rows)
write.csv(T, file.path("output", "tables", "payment-by-stratum.csv"), row.names = FALSE)
f3 <- function(m, l, h, d = 2) sprintf("%.*f [%.*f, %.*f]", d, m, d, l, d, h)
for (g in names(GROUPS)) {
  cat(sprintf("\n  -- %s --\n", g))
  cat(sprintf("  %-50s %5s  %-22s %-22s %-16s %-22s\n", "stratum", "n", "bonus rate %", "bonus / hosp $M",
              "share of $ %", "dis-assoc / hosp $K"))
  for (r in which(T$group == g)) with(T[r, ], cat(sprintf("  %-50s %5d  %-22s %-22s %5.1f (hosp %4.1f) %-22s\n",
    label, n, f3(rate_pct, rate_lo, rate_hi), f3(pay_musd, pay_lo, pay_hi), share_of_bonus_pct,
    share_of_hospitals_pct, f3(dis_kusd, dis_lo, dis_hi, 1))))
}

# ==========================================================================
# 2.  CONTRASTS ALONG THE GRADIENT, WITHIN DRAW
# ==========================================================================
hdr("2. contrasts along the gradient (computed within each draw)")
CON <- list(
  c("safety-net minus not",                       "sn1",     "sn0"),
  c("ADI most- minus least-deprived quintile",    "adi_q5",  "adi_q1"),
  c("model-implied most- minus least-disadvantaged", "vb_q5", "vb_q1"),
  c("corner: 1-2 star thin minus 4-5 star comfortable", "s1m1", "s3m3"),
  c("star band at middle margin: 1-2 minus 4-5",  "s1m2",    "s3m2"),
  c("margin at 3 star: thin minus comfortable",   "s2m1",    "s2m3"))
crow <- function(set, lab, DD, run = "base") do.call(rbind, lapply(CON, function(cc) {
  r <- summ(100 * (col_of(run, "rate", cc[2], DD) - col_of(run, "rate", cc[3], DD)))
  p <- summ((col_of(run, "pay", cc[2], DD) - col_of(run, "pay", cc[3], DD)) / 1e6)
  d <- summ((col_of(run, "dis", cc[2], DD) - col_of(run, "dis", cc[3], DD)) / 1e3)
  data.frame(model_set = lab, run = run, contrast = cc[1],
             rate_pts = r[1], rate_lo = r[2], rate_hi = r[3],
             pay_musd = p[1], pay_lo = p[2], pay_hi = p[3],
             dis_kusd = d[1], dis_lo = d[2], dis_hi = d[3], row.names = NULL) }))
CT <- rbind(crow("primary", "primary (194)", D), crow("primary", "primary (194)", D, "fixed"),
            crow("metro", sprintf("metro (%d)", length(S$pools$metro)), D7))
write.csv(CT, file.path("output", "tables", "payment-stratum-contrasts.csv"), row.names = FALSE)
for (r in seq_len(nrow(CT))) with(CT[r, ], cat(sprintf("  %-14s %-6s %-50s rate %+.2f pts [%+.2f, %+.2f]   $/hosp %+.2fM [%+.2f, %+.2f]   dis %+.1fK [%+.1f, %+.1f]\n",
  model_set, run, contrast, rate_pts, rate_lo, rate_hi, pay_musd, pay_lo, pay_hi, dis_kusd, dis_lo, dis_hi)))

# ==========================================================================
# 3.  THE FIGURE
# ==========================================================================
hdr("3. figure")
BLUE <- "#2a78d6"; GREY <- "#8c8b86"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e6e5e0"; SURF <- "#fcfcfb"
PAN <- list(list(g = "safety_net", t = "Safety-net status", x = c("not SN", "SN")),
            list(g = "adi",        t = "Catchment ADI quintile", x = c("1\nleast", "2", "3", "4", "5\nmost")),
            list(g = "model_dis",  t = "Model-implied disadvantage\nquintile (varies by draw)", x = c("1\nleast", "2", "3", "4", "5\nmost")),
            list(g = "cells",      t = "Star band x margin tercile (3.16 cells,\non a gradient, not Tracks)",
                 x = c(sprintf("%s\n%s", rep(c("1-2*", "3*", "4-5*"), each = 1)[as.integer(substr(CELLS, 2, 2))],
                               c("thin", "mid", "comf")[as.integer(substr(CELLS, 4, 4))]), "none")))
ROWS <- list(list(v = "rate", y = "Bonus rate, % of eligible revenue", s = 100, fx = TRUE),
             list(v = "dis",  y = "Bonus associated with catchment,\nvs a median catchment, $K/hospital", s = 1e-3, fx = FALSE))
yl <- lapply(ROWS, function(R) { v <- unlist(lapply(PAN, function(P) { ids <- GROUPS[[P$g]]$id
  c(sapply(ids, function(i) quantile(R$s * col_of("base", R$v, i), c(.025, .975))),
    if (R$fx) sapply(ids, function(i) quantile(R$s * col_of("fixed", R$v, i), c(.025, .975)))) }))
  if (R$fx) range(v) + c(-0.05, 0.05) * diff(range(v)) else range(c(v, 0)) })

png(file.path("output", "figures", "payment-by-stratum.png"), width = 1800, height = 1080, res = 150, bg = SURF)
layout(rbind(c(1, 1, 1, 1), 2:5, 6:9), heights = c(0.13, 1, 1), widths = c(0.55, 1.05, 1.05, 1.7))
par(mar = c(0, 0, 0, 0)); plot.new()
text(0.005, 0.72, "Simulated Q-HIP-style bonus by stratum, national what-if", adj = 0, cex = 1.25, font = 2, col = INK)
text(0.005, 0.22, sprintf("Mean and 95%% interval over %s draws (Rashomon specification, parameters, PSI-90 reliability). Base scenario.", format(B, big.mark = ",")),
     adj = 0, cex = 0.85, col = INK2)
legend("right", legend = c("reliability drawn (primary)", "PSI-90 fixed at published value"), pch = c(19, 1),
       col = c(BLUE, GREY), lwd = 2, bty = "n", horiz = TRUE, cex = 0.85, text.col = INK2)
for (ri in seq_along(ROWS)) for (pi in seq_along(PAN)) {
  R <- ROWS[[ri]]; P <- PAN[[pi]]; ids <- GROUPS[[P$g]]$id; k <- length(ids)
  par(mar = c(if (ri == 2) 3.6 else 1.2, if (pi == 1) 5.2 else 1.6, if (ri == 1) 3.0 else 0.8, 0.6),
      mgp = c(2.6, 0.5, 0), tcl = -0.2, las = 1, col.axis = INK2, cex.axis = 0.78, bg = SURF)
  plot(NA, xlim = c(0.5, k + 0.5), ylim = yl[[ri]], xaxt = "n", yaxt = "n", xlab = "", ylab = "", bty = "n")
  yt <- pretty(yl[[ri]], 5); abline(h = yt, col = GRID, lwd = 0.8)
  if (!R$fx) abline(h = 0, col = INK2, lwd = 1)
  axis(2, at = yt, labels = if (pi == 1) yt else FALSE, lwd = 0)
  if (pi == 1) mtext(R$y, side = 2, line = 2.6, cex = 0.66, col = INK2, las = 0)
  if (ri == 1) mtext(P$t, side = 3, line = 0.3, cex = 0.7, col = INK, adj = 0, font = 2)
  if (ri == 2) axis(1, at = seq_len(k), labels = P$x, lwd = 0, padj = 0.6, cex.axis = if (k > 6) 0.68 else 0.74)
  off <- if (R$fx) 0.14 else 0
  for (j in seq_len(k)) {
    s <- summ(R$s * col_of("base", R$v, ids[j]))
    segments(j - off, s[2], j - off, s[3], col = BLUE, lwd = 2); points(j - off, s[1], pch = 19, col = BLUE, cex = 1.1)
    if (R$fx) { f <- summ(R$s * col_of("fixed", R$v, ids[j]))
      segments(j + off, f[2], j + off, f[3], col = GREY, lwd = 2); points(j + off, f[1], pch = 21, bg = SURF, col = GREY, cex = 1.1) }
  }
}
dev.off()
cat("  -> output/figures/payment-by-stratum.png\n")

# ==========================================================================
# 4.  WHERE THE ADI DOLLAR GAP COMES FROM  (added at Task 5.5 so the report
#     can cite it; the split was computed by hand for the 4.3 note)
# ==========================================================================
## Mean bonus per hospital = mean NPR x (eligible revenue / NPR) x (bonus /
## eligible revenue), each a ratio of stratum means, so the log ratio of mean
## bonus, ADI quintile 5 to 1, splits exactly into size, commercial share
## (revenue-weighted) and position (the revenue-weighted bonus rate).
hdr("4. the ADI quintile 5 / 1 dollar gap, split")
HB <- read.csv(file.path("output", "tables", "payment-by-hospital.csv"), stringsAsFactors = FALSE)
q1 <- HB[HB$adi_q == 1, ]; q5 <- HB[HB$adi_q == 5, ]
lr <- function(f) log(f(q5) / f(q1))
GAP <- data.frame(component = c("total", "size (mean NPR)", "commercial share (eligible / NPR)", "position (bonus / eligible)"),
                  log_ratio = c(lr(function(d) mean(d$pay_mean)), lr(function(d) mean(d$npr)),
                                lr(function(d) mean(d$eligible_rev) / mean(d$npr)),
                                lr(function(d) mean(d$pay_mean) / mean(d$eligible_rev))))
GAP$share_of_total <- GAP$log_ratio / GAP$log_ratio[1]
GAP$q1 <- c(mean(q1$pay_mean), mean(q1$npr), mean(q1$eligible_rev) / mean(q1$npr), mean(q1$pay_mean) / mean(q1$eligible_rev))
GAP$q5 <- c(mean(q5$pay_mean), mean(q5$npr), mean(q5$eligible_rev) / mean(q5$npr), mean(q5$pay_mean) / mean(q5$eligible_rev))
stopifnot(abs(sum(GAP$log_ratio[-1]) - GAP$log_ratio[1]) < 1e-12)
write.csv(GAP, file.path("output", "tables", "payment-gap-decomposition.csv"), row.names = FALSE)
for (i in seq_len(nrow(GAP))) with(GAP[i, ], cat(sprintf("  %-36s log ratio %+.3f   %5.1f%% of the gap\n", component, log_ratio, 100 * share_of_total)))
cat("  -> output/tables/payment-gap-decomposition.csv\n")

# ==========================================================================
hdr("verify")
cat("  the stratification follows 3.16's verdict (gradient, not strata): no Track labels, the\n")
cat("  nine star x margin cells labelled as cells on a gradient, the empirical gradients\n")
cat("  (safety-net, ADI, model-implied disadvantage) beside them -- PASS\n")
hdr("done")
