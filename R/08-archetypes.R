# R/08-archetypes.R  --  Task 3.16, validating the CASH2 Track archetypes.
#
# Everything this script decides was fixed in
# provenance/archetype-preregistration.md, committed alone before any
# cross-tabulation of safety against margin (commit cdc8669). Section numbers
# point back to it.
#
# THE QUESTION is whether Tracks 1, 2 and 3 exist as strata in the data. Task
# 3.15's criteria did not establish stable three-group structure on margin x
# PSI-90 (ICL 2 / 4 groups, gap statistic 1; Task S3.4); this task asks the
# Tracks' own question on the Tracks' own terms, with the safety axis the memo
# used. LEAPFROG GRADES WERE NOT ACQUIRED (individual grades are public; bulk research
# data need an agreement or a purchase), so the safety
# axis is the CMS Hospital overall star rating -- the fallback the task sheet
# names -- in bands 1-2 / 3 / 4-5 stars read as Leapfrog D-F / C / A-B. That
# mapping is an inference and every output says so. The star rating is read
# from the hash-registered cc_hospinfo source and is NOT added to the frozen
# analytic file: it is this task's validation target, not a covariate.
#
# THE VERDICT RULE (prereg Sec 5) is printed before the verdict and applied
# mechanically: gamma(star band, margin tercile) with a bootstrap CI, then the
# share of hospitals in the three Track cells against a 50% bar. The memo's
# per-Track parameters -- safety-net share, beds, bottom-quartile safety -- are
# checked one row each and do not move the verdict.
#
# The 23 public safety-net hospitals Task 3.15 screened for margin < -1 STAY IN
# (prereg Sec 3): rank terciles put them where Track 1 puts them. The analysis
# without them is the one stated sensitivity.
#
# Outputs: output/tables/archetype-validation.csv (one row per test, with the
# verdict), output/tables/archetype-cells.csv (the 3 x 3 table with profiles),
# output/tables/archetype-screened23.csv, output/figures/archetype-validation.png,
# data/archetypes.rds.

suppressMessages(library(mclust))    # adjustedRandIndex only

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

SEED <- 20260923; BOOT <- 2000; BAR <- 0.50
set.seed(SEED)
MEMO_SN   <- list(T1 = c(0.50, 0.70), T2 = c(0.15, 0.30), T3 = c(0.05, 0.10))   # safety_net_proportion_lo/hi
MEMO_BEDS <- c(T1 = 175, T2 = 300, T3 = 500)                                  # hospital_beds

hdr("TASK 3.16  validating the Track archetypes")
cat("  safety axis: CMS Hospital overall star rating -- the Leapfrog FALLBACK (grades not acquired)\n")
cat("  bands 1-2 / 3 / 4-5 stars read as Leapfrog D-F / C / A-B: an inference, not a published crosswalk\n")

a <- readRDS(file.path("data", "analytic-v2.rds"))
h <- read.csv(file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv"),
              colClasses = "character", check.names = FALSE)
star <- n_(h[["Hospital overall rating"]][match(a$ccn, h[["Facility ID"]])])
stopifnot(sum(!is.na(match(a$ccn, h[["Facility ID"]]))) == nrow(a))

D0 <- data.frame(ccn = a$ccn, name = a$name, state = a$state, star = star,
                 margin = n_(a$operating_margin), dsh = n_(a$dsh_pct), beds = n_(a$beds),
                 psi90 = n_(a$psi90), lambda_i = n_(a$lambda_i))
D0$screened23 <- !is.na(D0$margin) & D0$margin < -1

# ==========================================================================
# 1.  FRAME AND WHO IS OUTSIDE IT  (prereg Sec 3)
# ==========================================================================
hdr("1. frame: star rating published and margin non-missing")
inF <- !is.na(D0$star) & !is.na(D0$margin)
cat(sprintf("  %d hospitals; star published %d (%s); margin present %d; frame %d\n", nrow(D0),
            sum(!is.na(D0$star)), pct(mean(!is.na(D0$star))), sum(!is.na(D0$margin)), sum(inF)))
cat(sprintf("  the 23 margin < -1 hospitals: %d in the frame (%d unrated)\n",
            sum(inF & D0$screened23), sum(D0$screened23 & is.na(D0$star))))
sub_("rated vs unrated -- is the frame selected?")
cmp <- function(k) c(n = sum(k), margin_median = median(D0$margin[k], na.rm = TRUE),
                     dsh_median = median(D0$dsh[k], na.rm = TRUE), beds_median = median(D0$beds[k], na.rm = TRUE),
                     psi90_mean = mean(D0$psi90[k]), lambda_mean = mean(D0$lambda_i[k]))
UNR <- rbind(rated = cmp(!is.na(D0$star)), unrated = cmp(is.na(D0$star)))
print(round(UNR, 3))

# ==========================================================================
# 2.  THE 3 x 3 TABLE AND ITS STATISTICS  (prereg Sec 2, 4)
# ==========================================================================
tercile <- function(x) as.integer(ceiling(3 * rank(x, ties.method = "first") / length(x)))
band    <- function(s) ifelse(s <= 2, 1L, ifelse(s == 3, 2L, 3L))     # 1 = D/F, 2 = C, 3 = A/B
BLAB <- c("1-2 stars (D/F)", "3 stars (C)", "4-5 stars (A/B)")
MLAB <- c("margin bottom third", "margin middle third", "margin top third")

## Goodman-Kruskal gamma on a table whose rows and columns are both ordered low -> high
gk_gamma <- function(tb) {
  P <- Q <- 0; R <- nrow(tb); C <- ncol(tb)
  for (i in seq_len(R - 1)) for (j in seq_len(C)) {
    if (j < C) P <- P + tb[i, j] * sum(tb[(i + 1):R, (j + 1):C])
    if (j > 1) Q <- Q + tb[i, j] * sum(tb[(i + 1):R, 1:(j - 1)])
  }
  (P - Q) / (P + Q)
}
## s = safety band (1 worst .. 3 best), m = raw margin; terciles are formed within the sample
stats_of <- function(s, m) {
  mt <- tercile(m)
  tb <- table(factor(s, 1:3), factor(mt, 1:3))
  ex <- outer(rowSums(tb), colSums(tb)) / sum(tb)
  c(gamma = gk_gamma(tb), track_share = sum(diag(tb)) / sum(tb), track_expected = sum(diag(ex)) / sum(tb),
    ratio = sum(diag(tb)) / sum(diag(ex)))
}
boot_ci <- function(s, m) {
  set.seed(SEED)
  B <- t(replicate(BOOT, { i <- sample.int(length(s), replace = TRUE); stats_of(s[i], m[i]) }))
  apply(B, 2, quantile, c(0.025, 0.975))
}
cell_table <- function(d, s) {
  d$sb <- s; d$mt <- tercile(d$margin)
  sn_cut <- quantile(d$dsh, 0.75, na.rm = TRUE)
  d$sn <- d$dsh >= sn_cut
  worst_q <- quantile(d$psi90, 0.75)
  out <- expand.grid(safety = 1:3, margin = 1:3)
  ex <- outer(tabulate(d$sb, 3), tabulate(d$mt, 3)) / nrow(d)
  out <- cbind(out, t(apply(out, 1, function(r) { k <- d$sb == r[1] & d$mt == r[2]
    c(n = sum(k), expected = ex[r[1], r[2]], safety_net_share = mean(d$sn[k], na.rm = TRUE),
      dsh_median = median(d$dsh[k], na.rm = TRUE), beds_median = median(d$beds[k], na.rm = TRUE),
      psi90_mean = mean(d$psi90[k]), psi90_worst_quartile = mean(d$psi90[k] >= worst_q),
      margin_median = median(d$margin[k]), n_screened23 = sum(d$screened23[k])) })))
  out$obs_exp <- out$n / out$expected
  out$share <- out$n / nrow(d)
  out$track <- ifelse(out$safety == out$margin, paste0("T", out$safety), "off-Track")
  attr(out, "sn_cut") <- sn_cut
  out
}

run_arm <- function(label, d, s) {
  st <- stats_of(s, d$margin); ci <- boot_ci(s, d$margin); ct <- cell_table(d, s)
  list(label = label, n = nrow(d), stats = st, ci = ci, cells = ct,
       rho = cor(if (label == "star") d$star else -d$psi90, d$margin, method = "spearman"))
}

F1 <- D0[inF, ]
ARMS <- list(
  star        = run_arm("star", F1, band(F1$star)),
  star_no23   = run_arm("star", F1[!F1$screened23, ], band(F1$star[!F1$screened23])),
  psi90       = run_arm("psi90", F1, 4L - tercile(F1$psi90))   # lowest PSI-90 third = band 3 (best)
)

PLAB <- c("PSI-90 worst third", "PSI-90 middle third", "PSI-90 best third")
show_arm <- function(A, title) {
  sub_(title)
  rl <- if (A$label == "psi90") PLAB else BLAB
  tb <- matrix(A$cells$n, 3, 3, dimnames = list(rl, MLAB))
  rt <- matrix(A$cells$obs_exp, 3, 3, dimnames = list(rl, MLAB))
  cat("  counts (rows: safety band, worst -> best; columns: margin tercile, thin -> comfortable)\n")
  print(tb)
  cat("  observed / expected under independence\n"); print(round(rt, 2))
  cat(sprintf("  n = %d   gamma = %+.3f [%+.3f, %+.3f]   Spearman rho(safety, margin) = %+.3f\n", A$n,
              A$stats["gamma"], A$ci[1, "gamma"], A$ci[2, "gamma"], A$rho))
  cat(sprintf("  Track cells hold %s [%s, %s] of hospitals; independence expects %s; ratio %.2f [%.2f, %.2f]\n",
              pct(A$stats["track_share"]), pct(A$ci[1, "track_share"]), pct(A$ci[2, "track_share"]),
              pct(A$stats["track_expected"]), A$stats["ratio"], A$ci[1, "ratio"], A$ci[2, "ratio"]))
}

hdr("2. the 3 x 3 table -- star rating (primary), full frame")
show_arm(ARMS$star, "star band x margin tercile, all rated hospitals incl. the 23")

# ==========================================================================
# 3.  THE VERDICT  (prereg Sec 5, applied mechanically)
# ==========================================================================
hdr("3. verdict -- the pre-registered rule")
cat("  not supported        : gamma CI includes or lies below zero\n")
cat(sprintf("  gradient, not strata : gamma CI above zero, Track cells < %s\n", pct(BAR, 0)))
cat(sprintf("  supported as strata  : gamma CI above zero, Track cells >= %s\n\n", pct(BAR, 0)))
verdict_of <- function(A) if (A$ci[1, "gamma"] <= 0) "NOT SUPPORTED" else
  if (A$stats["track_share"] < BAR) "GRADIENT, NOT STRATA" else "SUPPORTED AS STRATA"
VERDICT <- verdict_of(ARMS$star)
cat(sprintf("  VERDICT (star rating, full frame): %s\n", VERDICT))
cat(sprintf("  beside it, not replacing it -- without the 23: %s;  PSI-90 arm: %s\n",
            verdict_of(ARMS$star_no23), verdict_of(ARMS$psi90)))

sub_("plurality (C2)")
ct <- ARMS$star$cells
trk <- ct[ct$track != "off-Track", ]
cat(sprintf("  Track cells: T1 %d, T2 %d, T3 %d; T2 largest Track cell: %s; largest cell overall: %s x %s (%d)\n",
            trk$n[1], trk$n[2], trk$n[3], trk$n[2] == max(trk$n),
            BLAB[ct$safety[which.max(ct$n)]], MLAB[ct$margin[which.max(ct$n)]], max(ct$n)))

# ==========================================================================
# 4.  THE MEMO'S PER-TRACK PARAMETERS  (C3 - C5)
# ==========================================================================
hdr("4. the memo's per-Track parameters against the hospitals in each Track cell")
wilson <- function(x, n, z = 1.96) { p <- x / n; c0 <- p + z^2 / (2 * n); w <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
  c((c0 - w), (c0 + w)) / (1 + z^2 / n) }
grade <- function(est, ci, rng) if (est >= rng[1] && est <= rng[2]) "pass" else
  if (ci[2] >= rng[1] && ci[1] <= rng[2]) "partial" else "fail"
cat(sprintf("  safety-net = dsh_pct >= %.3f (top quartile of the frame); pass = point estimate in the memo's\n", attr(ct, "sn_cut")))
cat("  range, partial = Wilson 95% CI overlaps it, fail = no overlap\n\n")
ROWS <- list()
for (k in 1:3) {
  r <- trk[k, ]; tk <- paste0("T", k)
  x <- round(r$safety_net_share * r$n); ci <- wilson(x, r$n)
  g <- grade(r$safety_net_share, ci, MEMO_SN[[tk]])
  cat(sprintf("  C3 %s  safety-net share %s [%s, %s] vs memo %s-%s  -> %s   (median DSH %.3f, n %d)\n", tk,
              pct(r$safety_net_share), pct(ci[1]), pct(ci[2]), pct(MEMO_SN[[tk]][1], 0), pct(MEMO_SN[[tk]][2], 0),
              g, r$dsh_median, r$n))
  ROWS[[length(ROWS) + 1]] <- data.frame(claim = "C3 safety-net share", track = tk, estimate = r$safety_net_share,
    ci_lo = ci[1], ci_hi = ci[2], memo = sprintf("%.2f-%.2f", MEMO_SN[[tk]][1], MEMO_SN[[tk]][2]), result = g)
}
bd <- trk$beds_median
g4 <- if (bd[1] < bd[2] && bd[2] < bd[3]) "pass" else "fail"
cat(sprintf("\n  C4 median beds T1 %.0f / T2 %.0f / T3 %.0f vs memo 175 / 300 / 500; ordering T1 < T2 < T3 -> %s\n",
            bd[1], bd[2], bd[3], g4))
ROWS[[length(ROWS) + 1]] <- data.frame(claim = "C4 beds rise with Track", track = "T1/T2/T3", estimate = NA,
  ci_lo = NA, ci_hi = NA, memo = "175 / 300 / 500", result = g4,
  note = sprintf("median beds %.0f / %.0f / %.0f", bd[1], bd[2], bd[3]))
w1 <- trk$psi90_worst_quartile[1]; ci5 <- wilson(round(w1 * trk$n[1]), trk$n[1])
g5 <- if (ci5[1] > 0.5) "pass" else if (ci5[2] >= 0.5) "partial" else "fail"
cat(sprintf("  C5 T1 in the worst PSI-90 quartile: %s [%s, %s] vs 'bottom quartile' (majority) -> %s\n",
            pct(w1), pct(ci5[1]), pct(ci5[2]), g5))
ROWS[[length(ROWS) + 1]] <- data.frame(claim = "C5 Track 1 safety in bottom quartile (PSI-90)", track = "T1",
  estimate = w1, ci_lo = ci5[1], ci_hi = ci5[2], memo = "majority in worst quartile", result = g5)

sub_("safety-net share in every cell (rows safety worst -> best, columns margin thin -> comfortable)")
print(round(matrix(ct$safety_net_share, 3, 3, dimnames = list(BLAB, MLAB)), 3))
sub_("median beds in every cell")
print(matrix(ct$beds_median, 3, 3, dimnames = list(BLAB, MLAB)))

# ==========================================================================
# 5.  BESIDE THE VERDICT: WITHOUT THE 23, AND PSI-90 AS THE SAFETY AXIS
# ==========================================================================
hdr("5. sensitivity and secondary arm -- reported beside the verdict, never replacing it")
show_arm(ARMS$star_no23, "star band x margin tercile, WITHOUT the 23 margin < -1 hospitals")
show_arm(ARMS$psi90, "PSI-90 tercile (published; best third = bottom row) x margin tercile")

sub_("the 23 margin < -1 hospitals by name")
S23 <- D0[D0$screened23, c("ccn", "name", "state", "margin", "star", "dsh", "beds", "psi90")]
S23$safety_net <- S23$dsh >= attr(ct, "sn_cut")
S23 <- S23[order(S23$margin), ]
print(transform(S23, margin = round(margin, 2), dsh = round(dsh, 3), psi90 = round(psi90, 3)), row.names = FALSE)
cat(sprintf("\n  of the %d rated: star bands 1-2 / 3 / 4-5 = %s; safety-net %d of %d\n", sum(!is.na(S23$star)),
            paste(tabulate(band(S23$star[!is.na(S23$star)]), 3), collapse = " / "),
            sum(S23$safety_net, na.rm = TRUE), nrow(S23)))

# ==========================================================================
# 6.  AGAINST TASK 3.15's FORCED THREE -- a comparison, not evidence
# ==========================================================================
hdr("6. Task 3.15's FORCED G = 3 against the Track cells (comparison only, 3.15 prereg Sec 5)")
CL <- readRDS(file.path("data", "clusters.rds"))$assignments
F1$track <- with(list(sb = band(F1$star), mt = tercile(F1$margin)),
  ifelse(sb == mt, paste0("T", sb), "off-Track"))
j <- match(CL$ccn, F1$ccn); ok <- !is.na(j)
ARI <- c()
for (v in c("published", "corrected")) {
  f3 <- CL[[paste0(v, "_forced3")]][ok]; tr <- F1$track[j[ok]]
  ARI[v] <- adjustedRandIndex(f3, tr)
  cat(sprintf("\n  %s forced-3 (cluster 1 = best mean PSI-90) x Track cell, n = %d, ARI %.3f\n", v, sum(ok), ARI[v]))
  print(table(forced3 = f3, track = tr))
}

# ==========================================================================
# 7.  OUTPUTS
# ==========================================================================
arm_row <- function(A, nm) data.frame(claim = c("C1 gradient (gamma)", "C2 Track-cell share"), track = nm,
  estimate = A$stats[c("gamma", "track_share")], ci_lo = A$ci[1, c("gamma", "track_share")],
  ci_hi = A$ci[2, c("gamma", "track_share")],
  memo = c("> 0", sprintf(">= %.2f (independence %.3f)", BAR, A$stats["track_expected"])),
  result = c(if (A$ci[1, "gamma"] > 0) "pass" else "fail", if (A$stats["track_share"] >= BAR) "pass" else "fail"))
VAL <- rbind(
  data.frame(claim = "VERDICT", track = "star, full frame", estimate = NA, ci_lo = NA, ci_hi = NA,
             memo = "prereg Sec 5", result = VERDICT, note = "safety axis = CMS star rating, the Leapfrog fallback"),
  cbind(arm_row(ARMS$star, "star, full frame (primary)"), note = ""),
  cbind(arm_row(ARMS$star_no23, "star, without the 23 (sensitivity)"), note = ""),
  cbind(arm_row(ARMS$psi90, "PSI-90 terciles (secondary)"), note = ""),
  data.frame(claim = "C2 Track 2 is the plurality", track = "T2", estimate = trk$n[2] / sum(ct$n), ci_lo = NA,
             ci_hi = NA, memo = "largest group", result = if (trk$n[2] == max(ct$n)) "pass" else "fail",
             note = sprintf("Track cells T1 %d / T2 %d / T3 %d; largest cell %d (%s x %s)", trk$n[1], trk$n[2],
                            trk$n[3], max(ct$n), BLAB[ct$safety[which.max(ct$n)]], MLAB[ct$margin[which.max(ct$n)]])),
  do.call(rbind, lapply(ROWS, function(r) { if (is.null(r$note)) r$note <- ""; r })),
  data.frame(claim = "3.15 forced-3 vs Track cells (ARI)", track = c("published", "corrected"), estimate = ARI,
             ci_lo = NA, ci_hi = NA, memo = "comparison only", result = "", note = ""))
rownames(VAL) <- NULL
CELLS <- do.call(rbind, lapply(names(ARMS), function(k) cbind(arm = k, ARMS[[k]]$cells)))
CELLS$safety_label <- ifelse(CELLS$arm == "psi90", PLAB[CELLS$safety],
                             BLAB[CELLS$safety])
CELLS$margin_label <- MLAB[CELLS$margin]
write.csv(VAL,   file.path("output", "tables", "archetype-validation.csv"), row.names = FALSE)
write.csv(CELLS, file.path("output", "tables", "archetype-cells.csv"), row.names = FALSE)
write.csv(S23,   file.path("output", "tables", "archetype-screened23.csv"), row.names = FALSE)
saveRDS(list(verdict = VERDICT, arms = ARMS, validation = VAL, unrated = UNR, frame = F1,
             prereg = "provenance/archetype-preregistration.md"), file.path("data", "archetypes.rds"))

## figure: (a) obs/exp heat map with counts, Track cells outlined; (b) safety-net share per
## Track cell against the memo's range; (c) median beds per Track cell against the memo
png(file.path("output", "figures", "archetype-validation.png"), width = 1650, height = 620, res = 130)
op <- par(mfrow = c(1, 3), mar = c(4.5, 7.8, 3.2, 1), mgp = c(2.6, 0.7, 0))
rt <- matrix(ct$obs_exp, 3, 3); nn <- matrix(ct$n, 3, 3)
ramp <- colorRampPalette(c("#2b6cb0", "#f7f7f7", "#c05621"))(101)
colr <- ramp[pmin(101, pmax(1, round(50 + 50 * log2(rt) / 0.6)))]
plot(NA, xlim = c(0.5, 3.5), ylim = c(0.5, 3.5), axes = FALSE, xlab = "operating margin tercile", ylab = "",
     main = sprintf("%s\ngamma %+.2f; Track cells %s (independence %s)", VERDICT, ARMS$star$stats["gamma"],
                    pct(ARMS$star$stats["track_share"], 0), pct(ARMS$star$stats["track_expected"], 0)), cex.main = 0.9)
for (i in 1:3) for (k in 1:3) {
  rect(k - 0.5, i - 0.5, k + 0.5, i + 0.5, col = colr[i + 3 * (k - 1)], border = "white")
  text(k, i, sprintf("%d\n%.2fx", nn[i, k], rt[i, k]), cex = 0.9)
}
for (i in 1:3) rect(i - 0.5, i - 0.5, i + 0.5, i + 0.5, border = "black", lwd = 2.5)
axis(1, 1:3, c("thin", "middle", "comfortable"), tick = FALSE)
axis(2, 1:3, c("1-2 stars\n(D/F)", "3 stars\n(C)", "4-5 stars\n(A/B)"), las = 1, tick = FALSE)
text(1:3, 1:3 + 0.36, paste0("T", 1:3), font = 2, cex = 0.85)

par(mar = c(4.5, 4.4, 3.2, 1))
sn <- trk$safety_net_share; cis <- t(sapply(1:3, function(k) wilson(round(sn[k] * trk$n[k]), trk$n[k])))
plot(1:3, sn, ylim = c(0, 0.8), xlim = c(0.5, 3.5), pch = 16, axes = FALSE, xlab = "", ylab = "safety-net share (top-quartile DSH)",
     main = "C3: safety-net share per Track\n(grey = memo's range)", cex.main = 0.9)
for (k in 1:3) rect(k - 0.3, MEMO_SN[[k]][1], k + 0.3, MEMO_SN[[k]][2], col = "grey85", border = NA)
arrows(1:3, cis[, 1], 1:3, cis[, 2], angle = 90, code = 3, length = 0.05); points(1:3, sn, pch = 16)
abline(h = 0.25, lty = 3, col = "grey50"); axis(1, 1:3, paste0("T", 1:3)); axis(2, las = 1); box()

plot(1:3, bd, ylim = c(0, max(600, bd * 1.1)), xlim = c(0.5, 3.5), pch = 16, axes = FALSE, xlab = "",
     ylab = "median beds", main = "C4: size per Track\n(open = memo's archetype)", cex.main = 0.9)
points(1:3, MEMO_BEDS, pch = 1, cex = 1.4); axis(1, 1:3, paste0("T", 1:3)); axis(2, las = 1); box()
par(op); invisible(dev.off())
cat("\n  wrote output/tables/archetype-{validation,cells,screened23}.csv, output/figures/archetype-validation.png,",
    "data/archetypes.rds\n")
