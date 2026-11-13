# R/11-regressivity.R  --  Task 4.4, the regressivity measure; rewired Task S1.6.
#
# Reads data/payment-sim.rds (Task 4.2) only; no draws are made here.
#
# THE MEASURE AND THE RULE were fixed in payment-model-inputs.md amendment 9
# before any per-revenue-dollar index was computed, and the second-pass
# pre-registration (sec 3) moved the rule onto the FINITE PAYMENT RETURN:
#   headline = concentration index of the finite return at Delta = 0.05 PSI-90
#              units (Task S1.4) PER DOLLAR OF NET PATIENT REVENUE, ranked by
#              distance from the best measured score, by model-implied
#              disadvantage (primary) and by catchment ADI (secondary);
#   per hospital = the fundability view, reported beside it.
#   "Structurally regressive" along an axis <=> the headline index is negative
#   with a 95% simulation interval excluding zero, base scenario. The words are
#   a claim about the ARITHMETIC OF THE PAYMENT FORMULA only (Plan Sec 9), and
#   every sentence that uses them says so.
# Task S1.6 wording: an interval that crosses zero reads "no clear direction
# under the modeled uncertainty" (never "neutral"); a zero-width interval is
# the ABSENCE of modeled variation -- nothing the index depends on is drawn --
# not certainty. "Headroom" is renamed "distance from the best measured score":
# it ranks measured burden, not preventable harm. The September 30 "marginal
# incentive" (R x w x 0.039) survives only as the supplementary revenue
# exposure coefficient, whose per-NPR index is that of commercial day share.
# The observed FY 2026 HACRP cross-tabulation is associational: "over-
# represented among", never a causal verb.
#
# Outputs: output/tables/regressivity.csv, regressivity-by-stratum.csv,
# observed-hacrp-regressivity.csv, regressivity-statement.txt,
# payment-uncertainty-trace.csv, output/figures/regressivity.png.

hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
S  <- readRDS(file.path("data", "payment-sim.rds"))
D  <- S$draws; D7 <- S$draws_metro; H <- S$hospitals; B <- nrow(D)
OUT <- file.path("output", "tables")
summ <- function(x) c(mean = mean(x), lo = unname(quantile(x, .025)), hi = unname(quantile(x, .975)))
NOVAR <- "no modeled variation"
verdict <- function(lo, hi) ifelse(hi - lo < 1e-9, NOVAR,
                            ifelse(hi < 0, "regressive", ifelse(lo > 0, "progressive", "no clear direction")))
DIST <- "distance from the best measured score"

hdr("TASK 4.4 / S1.6  the regressivity measure, on the finite payment return")
cat(sprintf("  %d draws, %d hospitals; headline framing per dollar of net patient revenue (amendment 9)\n", B, nrow(H)))

# ==========================================================================
# 1.  CONCENTRATION INDICES
# ==========================================================================
hdr("1. concentration indices -- negative = concentrated where the ranking is LOW")
cat("  rankings run from least to most distance from the best measured score (theta), least to\n")
cat("  most model-implied disadvantage (v_B), least to most deprived catchment (ADI).\n")

FRAMES <- list(npr = list(tag = "npr", lab = "per NPR dollar"), hosp = list(tag = "", lab = "per hospital"))
QRET <- "finite payment return (Delta = 0.05)"
QTY  <- c(ret = QRET, open = "unearned band", pay = "bonus paid")
RANK <- c(head = DIST, vb = "model-implied disadvantage", adi = "catchment ADI")
SCN  <- unique(sub("\\.total_pay$", "", grep("\\.total_pay$", colnames(D), value = TRUE)))
SLAB <- setNames(S$scenarios$label[match(SCN, S$scenarios$scenario)], SCN)
rows <- list()
add_rows <- function(DD, scen, set) for (fr in names(FRAMES)) for (qn in names(QTY)) for (rk in names(RANK)) {
  col <- sprintf("%s.ci_%s%s_%s", scen, qn, FRAMES[[fr]]$tag, rk)
  s <- summ(DD[, col])
  rows[[length(rows) + 1]] <<- data.frame(model_set = set, scenario = scen, scenario_label = SLAB[[scen]],
    framing = FRAMES[[fr]]$lab, quantity = QTY[[qn]], ranked_by = RANK[[rk]], mean = s["mean"], lo = s["lo"], hi = s["hi"],
    share_draws_negative = mean(DD[, col] < 0), verdict = verdict(s["lo"], s["hi"]),
    headline = fr == "npr" && qn == "ret" && scen == "base" && set == "primary (194)", row.names = NULL)
}
for (sc in SCN) add_rows(D, sc, "primary (194)")
add_rows(D7, "base", sprintf("metro (%d)", length(S$pools$metro)))
## supplementary: the revenue exposure coefficient, per NPR dollar only
for (sc in SCN) for (rk in names(RANK)) { col <- sprintf("%s.ci_exponpr_%s", sc, rk); s <- summ(D[, col])
  rows[[length(rows) + 1]] <- data.frame(model_set = "primary (194)", scenario = sc, scenario_label = SLAB[[sc]],
    framing = "per NPR dollar", quantity = "revenue exposure coefficient (supplementary; payer mix)", ranked_by = RANK[[rk]],
    mean = s["mean"], lo = s["lo"], hi = s["hi"], share_draws_negative = mean(D[, col] < 0),
    verdict = verdict(s["lo"], s["hi"]), headline = FALSE, row.names = NULL) }
RG <- do.call(rbind, rows)
## safety-net ratio: mean return at safety-net hospitals / at the rest
for (sc in SCN) for (k in c("retnpr", "ret")) {
  s <- summ(D[, sprintf("%s.sn_ratio_%s", sc, k)])
  RG <- rbind(RG, data.frame(model_set = "primary (194)", scenario = sc, scenario_label = SLAB[[sc]],
    framing = if (k == "retnpr") "per NPR dollar" else "per hospital", quantity = QRET,
    ranked_by = "safety-net / not (ratio of means)", mean = s["mean"], lo = s["lo"], hi = s["hi"],
    share_draws_negative = NA, verdict = ifelse(s["hi"] - s["lo"] < 1e-9, NOVAR, ifelse(s["hi"] < 1, "lower at safety-net",
      ifelse(s["lo"] > 1, "higher at safety-net", "no clear difference"))),
    headline = FALSE, row.names = NULL))
}
write.csv(RG, file.path(OUT, "regressivity.csv"), row.names = FALSE)

HL <- RG[RG$scenario == "base" & RG$model_set == "primary (194)" & RG$quantity == QRET, ]
f3 <- function(m, l, h) sprintf("%+.3f [%+.3f, %+.3f]", m, l, h)
cat("\n  BASE SCENARIO, finite payment return at Delta = 0.05:\n")
for (r in seq_len(nrow(HL))) with(HL[r, ], cat(sprintf("  %-15s %-40s %-26s %s%s\n", framing, ranked_by,
  if (grepl("ratio", ranked_by)) sprintf("%.3f [%.3f, %.3f]", mean, lo, hi) else f3(mean, lo, hi), verdict,
  if (headline) "   <- HEADLINE" else "")))

cat("\n  headline index across the scenario grid (per NPR dollar, finite return):\n")
for (rk in RANK) { x <- RG[RG$framing == "per NPR dollar" & RG$quantity == QRET & RG$ranked_by == rk, ]
  cat(sprintf("  %-38s %s\n", rk, paste(sprintf("%s %+.3f%s", x$scenario, x$mean,
      ifelse(x$verdict == "regressive", "*", ifelse(x$verdict == "progressive", "+", ifelse(x$verdict == NOVAR, "0", "")))),
      collapse = "  "))) }
cat("  (* interval below zero, + above zero, 0 zero-width; unmarked = no clear direction)\n")

# ==========================================================================
# 2.  THE RETURN AGAINST DISTANCE, DISADVANTAGE AND DEPRIVATION, BY STRATUM
# ==========================================================================
hdr("2. finite return by stratum")
STR <- list(distance = paste0("hd_q", 1:5), model_dis = paste0("vb_q", 1:5), adi = paste0("adi_q", 1:5),
            safety_net = c("sn0", "sn1"))
LAB <- list(distance = paste("distance-from-best quintile", 1:5, c("(nearest)", "", "", "", "(farthest)")),
            model_dis = paste("model-implied disadvantage quintile", 1:5, c("(least)", "", "", "", "(most)")),
            adi = paste("ADI quintile", 1:5, c("(least deprived)", "", "", "", "(most deprived)")),
            safety_net = c("not safety-net", "safety-net"))
BS <- do.call(rbind, lapply(names(STR), function(g) do.call(rbind, lapply(seq_along(STR[[g]]), function(i) {
  id <- STR[[g]][i]; m <- summ(1e4 * D[, paste0("base.retnpr.", id)]); h <- summ(D[, paste0("base.ret.", id)] / 1e3)
  o <- summ(D[, paste0("base.open.", id)] / 1e6); r <- summ(100 * D[, paste0("base.rate.", id)])
  data.frame(group = g, stratum = id, label = LAB[[g]][i],
             ret_per_npr_bp = m[1], ret_per_npr_lo = m[2], ret_per_npr_hi = m[3],
             ret_per_hosp_k = h[1], ret_per_hosp_lo = h[2], ret_per_hosp_hi = h[3],
             unearned_m = o[1], unearned_lo = o[2], unearned_hi = o[3],
             bonus_rate_pct = r[1], bonus_rate_lo = r[2], bonus_rate_hi = r[3], row.names = NULL) }))))
write.csv(BS, file.path(OUT, "regressivity-by-stratum.csv"), row.names = FALSE)
cat("  finite return = payment change per PSI-90 unit at Delta = 0.05; per NPR in basis points of NPR\n")
cat(sprintf("  %-44s %-24s %-24s %-22s\n", "", "per NPR dollar, bp", "per hospital, $K", "bonus rate, %"))
for (r in seq_len(nrow(BS))) with(BS[r, ], cat(sprintf("  %-44s %-24s %-24s %-22s\n", label,
  sprintf("%.1f [%.1f, %.1f]", ret_per_npr_bp, ret_per_npr_lo, ret_per_npr_hi),
  sprintf("%.0f [%.0f, %.0f]", ret_per_hosp_k, ret_per_hosp_lo, ret_per_hosp_hi),
  sprintf("%.2f [%.2f, %.2f]", bonus_rate_pct, bonus_rate_lo, bonus_rate_hi))))

# ==========================================================================
# 3.  OBSERVED FY 2026 HACRP PENALTIES  (associational)
# ==========================================================================
hdr("3. observed FY 2026 HACRP penalties -- associational, not a projection")
C <- H[!is.na(H$hacrp_penalised), ]
C$vbq <- as.integer(ceiling(5 * rank(C$vB_mean, ties.method = "first") / nrow(C)))
base_rate <- mean(C$hacrp_penalised)
wilson <- function(x, n) { p <- x / n; z <- 1.96; d <- 1 + z^2 / n
  c((p + z^2 / (2 * n) - z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / d,
    (p + z^2 / (2 * n) + z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / d) }
tab <- function(g, lev, lab, group) do.call(rbind, lapply(seq_along(lev), function(i) {
  k <- g == lev[i]; x <- sum(C$hacrp_penalised[k]); n <- sum(k); w <- wilson(x, n)
  data.frame(group = group, stratum = lab[i], n = n, penalised = x, share = x / n, lo = w[1], hi = w[2],
             ratio_to_frame = (x / n) / base_rate, row.names = NULL) }))
cells <- sort(unique(C$cell))
OB <- rbind(tab(C$safety_net, c(FALSE, TRUE), c("not safety-net", "safety-net"), "safety_net"),
            tab(C$adi_q, 1:5, LAB$adi, "adi"),
            tab(C$vbq, 1:5, LAB$model_dis, "model_dis (mean v_B)"),
            tab(C$cell, cells, cells, "cells (3.16, a gradient)"))
rr <- function(k1, k0, label) { a <- sum(C$hacrp_penalised[k1]); n1 <- sum(k1); c0 <- sum(C$hacrp_penalised[k0]); n0 <- sum(k0)
  est <- (a / n1) / (c0 / n0); se <- sqrt(1 / a - 1 / n1 + 1 / c0 - 1 / n0)
  data.frame(group = "rate ratio", stratum = label, n = n1 + n0, penalised = a + c0, share = est,
             lo = exp(log(est) - 1.96 * se), hi = exp(log(est) + 1.96 * se), ratio_to_frame = NA, row.names = NULL) }
cix <- function(y, rkv, label) { r <- (rank(rkv, ties.method = "average") - 0.5) / length(rkv)
  set.seed(S$seed); bt <- replicate(2000, { i <- sample.int(length(y), replace = TRUE)
    2 * mean((y[i] - mean(y[i])) * (r[i] - mean(r[i]))) / mean(y[i]) })
  data.frame(group = "concentration index", stratum = label, n = length(y), penalised = sum(y),
             share = 2 * mean((y - mean(y)) * (r - mean(r))) / mean(y),
             lo = unname(quantile(bt, .025)), hi = unname(quantile(bt, .975)), ratio_to_frame = NA, row.names = NULL) }
OB <- rbind(OB, rr(C$adi_q == 5, C$adi_q == 1, "ADI Q5 / Q1"), rr(C$safety_net, !C$safety_net, "safety-net / not"),
            rr(C$vbq == 5, C$vbq == 1, "model-implied Q5 / Q1"),
            cix(as.numeric(C$hacrp_penalised), C$adi_q, "penalty ranked by ADI quintile (hospital bootstrap)"),
            cix(as.numeric(C$hacrp_penalised), C$vB_mean, "penalty ranked by mean v_B (hospital bootstrap)"))
write.csv(OB, file.path(OUT, "observed-hacrp-regressivity.csv"), row.names = FALSE)
cat(sprintf("  calibration frame %d hospitals, %d penalised (%.1f%%); Maryland excluded as waived\n",
            nrow(C), sum(C$hacrp_penalised), 100 * base_rate))
for (r in seq_len(nrow(OB))) with(OB[r, ], cat(sprintf("  %-26s %-48s n %4d  %-9s %.3f [%.3f, %.3f]\n",
  group, stratum, n, if (group %in% c("rate ratio", "concentration index")) "" else sprintf("pen %3d", penalised), share, lo, hi)))

# ==========================================================================
# 3b. THE ALL-IMPROVE RESULT AND ITS SCORING REFERENCE  (October 7 audit A6)
#     Stage 35's all-improve experiment lowers every published PSI-90 by 0.05
#     and RESCORES: winsorization bounds, mean and SD are recomputed, so a
#     common shift leaves every z-score, rank and payment where it was ($0).
#     That is a property of this rule with a recalculated reference and fixed
#     revenues, not of every rank-based rule. Here the same shift is scored
#     against the ORIGINAL reference (the one the individual finite return
#     holds fixed), at the published scores, using stage 35's own functions.
#     A diagnostic alternative, not a prediction.
# ==========================================================================
hdr("3b. all-improve: recalculated vs fixed scoring reference (audit A6)")
local({
  lhs <- function(x) if (is.call(x) && as.character(x[[1]])[1] %in% c("<-", "=")) as.character(x[[2]])[1] else ""
  ev <- new.env()
  for (x in parse(file.path("R", "09-payment-sim.R"))) if (lhs(x) %in% c("score_of", "pos_of", "rate_of")) eval(x, ev)
  an <- readRDS(file.path("data", "analytic-v2.rds"))
  hr <- read.csv(file.path("data-raw", "hacrp_fy2026", "FY_2026_HAC_Reduction_Program_Hospital.csv"),
                 colClasses = "character", check.names = FALSE)
  hm <- match(H$ccn, hr[["Facility ID"]])
  W  <- sapply(paste(c("CLABSI", "CAUTI", "SSI", "CDI", "MRSA"), "W Z Score"), function(k) suppressWarnings(as.numeric(hr[[k]][hm])))
  ev$nHAI <- rowSums(is.finite(W)); ev$nHAI[is.na(hm)] <- 0
  ev$HAIM <- ifelse(ev$nHAI > 0, rowMeans(W, na.rm = TRUE), 0)
  pub <- as.numeric(an$psi90[match(H$ccn, an$ccn)]); R <- H$eligible_rev
  sc  <- list(w = 0.15, k = 1, thr = FALSE, psi = FALSE)
  so  <- ev$score_of(pub, 0.15, FALSE); P0 <- ev$pos_of(so$S); pay <- R * ev$rate_of(P0, sc)
  stopifnot(max(abs(pay - H$pay_fixed)) < 0.01)              # reproduces stage 35's fixed-score payments
  sa  <- ev$score_of(pub - 0.05, 0.15, FALSE)                # reference recalculated (stage 35)
  zf  <- so$zfun(pub - 0.05)                                 # reference held at the original
  Sf  <- ifelse(ev$nHAI > 0, 0.15 * zf + 0.85 * ev$HAIM, zf)
  Pf  <- ev$pos_of(Sf)
  AIR <<- data.frame(reference = c("recalculated", "fixed at original"),
                     total_change = c(sum(R * ev$rate_of(ev$pos_of(sa$S), sc)) - sum(pay), sum(R * ev$rate_of(Pf, sc)) - sum(pay)),
                     n_rank_changes = c(sum(ev$pos_of(sa$S) != P0), sum(Pf != P0)),
                     n_hospitals = length(pub), n_no_infection = sum(ev$nHAI == 0))
})
write.csv(AIR, file.path(OUT, "all-improve-reference.csv"), row.names = FALSE)
for (i in seq_len(nrow(AIR))) cat(sprintf("  reference %-18s total payment change $%+.0f   positions changed %d of %d\n",
                                          AIR$reference[i], AIR$total_change[i], AIR$n_rank_changes[i], AIR$n_hospitals[i]))
stopifnot(abs(AIR$total_change[1]) < 1e-3)

# ==========================================================================
# 4.  THE PLAIN-LANGUAGE STATEMENT  (generated from the numbers above)
# ==========================================================================
hdr("4. plain-language statement")
g  <- function(rk) HL[HL$framing == "per NPR dollar" & HL$ranked_by == rk, ]
gh <- function(rk) HL[HL$framing == "per hospital" & HL$ranked_by == rk, ]
snr <- RG[RG$scenario == "base" & RG$framing == "per NPR dollar" & grepl("ratio", RG$ranked_by), ]
snh <- RG[RG$scenario == "base" & RG$framing == "per hospital" & grepl("ratio", RG$ranked_by), ]
sg <- function(sc, rk) RG[RG$model_set == "primary (194)" & RG$scenario == sc & RG$framing == "per NPR dollar" &
                          RG$quantity == QRET & RG$ranked_by == rk, ]
QUAL <- "a statement about the arithmetic of the payment formula, not about anyone's intent or about payments any hospital has received"
## the predicate of "Against <axis>, the return ...". A verdict whose deciding
## endpoint lies within two Monte Carlo standard errors of zero (amendment 6's
## endpoint MCSE, base-scenario headline columns) is reported with that caveat:
## the rule reads it one way, but the simulation cannot tell it from zero.
MCV <- S$convergence
fragile <- function(x, col) {
  if (is.null(col) || !col %in% MCV$output || x$verdict %in% c("no clear direction", NOVAR)) return("")
  r <- MCV[MCV$output == col, ]; end <- if (x$verdict == "regressive") x$hi else x$lo
  se <- if (x$verdict == "regressive") r$mcse_q975 else r$mcse_q025
  if (abs(end) < 2 * se) sprintf(". Its deciding endpoint (%+.4f) lies within %.1f Monte Carlo standard errors (%.4f) of zero, so the verdict follows the pre-registered rule but is not robust to simulation error", end, abs(end) / se, se) else ""
}
vtext <- function(x, axis, col = NULL) paste0(switch(x$verdict,
  regressive  = sprintf("is structurally regressive (%s): index %+.3f [%+.3f, %+.3f]", QUAL, x$mean, x$lo, x$hi),
  "no clear direction" = sprintf("shows no clear direction under the modeled uncertainty: index %+.3f [%+.3f, %+.3f], an interval that crosses zero", x$mean, x$lo, x$hi),
  progressive = sprintf("is tilted toward the hospitals with more %s: index %+.3f [%+.3f, %+.3f]", axis, x$mean, x$lo, x$hi),
  sprintf("has index %+.3f with no modeled variation: nothing the index depends on is drawn, so its zero-width interval reflects the absence of modeled variation, not certainty", x$mean)),
  fragile(x, col))
ob_adi <- OB[OB$stratum == "ADI Q5 / Q1", ]; ob_sn <- OB[OB$stratum == "safety-net / not", ]
ob_vb  <- OB[OB$stratum == "model-implied Q5 / Q1", ]
cs_sn <- mean(H$cshare[H$safety_net]); cs_ot <- mean(H$cshare[!H$safety_net])
cs_a1 <- mean(H$cshare[H$adi_q == 1]); cs_a5 <- mean(H$cshare[H$adi_q == 5])
## the return per ELIGIBLE dollar, by ADI fifth (hospital means over draws; descriptive)
pe <- H$ret_d050 / H$eligible_rev
pe1 <- mean(pe[H$adi_q == 1]); pe5 <- mean(pe[H$adi_q == 5])
xa <- g("catchment ADI"); xv <- g("model-implied disadvantage"); xh <- g(DIST)
ai <- summ(D[, "base.allimp_pay_change"])
expo_adi <- RG[RG$scenario == "base" & grepl("exposure", RG$quantity) & RG$ranked_by == "catchment ADI", ]
## every scenario whose verdict differs from base, on the two primary axes
ch <- RG[RG$framing == "per NPR dollar" & RG$quantity == QRET & RG$model_set == "primary (194)" &
         RG$ranked_by %in% c(DIST, "model-implied disadvantage") & RG$scenario != "base", ]
ch <- ch[ch$verdict != HL$verdict[match(paste("per NPR dollar", ch$ranked_by), paste(HL$framing, HL$ranked_by))], ]
STMT <- c(
  "REGRESSIVITY -- plain-language statement (Task 4.4, rewired Task S1.6; generated by R/11-regressivity.R from the numbers it reports)",
  "",
  "The measure: how much more a hospital is paid if its PSI-90 improves by 0.05 while every other hospital's score stays where it is -- the finite payment return -- per dollar of its net patient revenue, under a Q-HIP-style payment modeled on CASH2's mechanics (payment-model-inputs.md, amendment 9; second-pass pre-registration sec 3). A national what-if. The intervals are 95% simulation intervals over the specification, coefficient and published-score draws (output/tables/payment-uncertainty-trace.csv says which draws move which number).",
  "",
  sprintf("1. Against %s, the return %s. That ranking orders hospitals by measured burden, not by preventable harm.", DIST, vtext(xh, DIST, "base.ci_retnpr_head")),
  sprintf("2. Against catchment disadvantage as the Phase 3 models rank it (the pre-registered primary ranking), the return %s. That ranking orders catchments by how much the models associate them with worse PSI-90, not by deprivation as such: limited-English share runs against it (Task 3.12).", vtext(xv, "that ranking", "base.ci_retnpr_vb")),
  sprintf("3. Against catchment deprivation (ADI, the secondary ranking), the return %s. In the most-deprived fifth of catchments a hospital's return is %.1f basis points of revenue per PSI-90 unit, against %.1f in the least-deprived fifth.",
          vtext(xa, "catchment deprivation", "base.ci_retnpr_adi"), BS$ret_per_npr_bp[BS$stratum == "adi_q5"], BS$ret_per_npr_bp[BS$stratum == "adi_q1"]),
  sprintf("4. Per revenue dollar, safety-net hospitals' return is %.2f [%.2f, %.2f] times that of other hospitals.", snr$mean, snr$lo, snr$hi),
  sprintf("5. Two things set a hospital's return per revenue dollar. One is how much of its revenue is commercial -- %.3f at safety-net hospitals against %.3f at others, and %.3f in the most-deprived ADI fifth against %.3f in the least. The other is how many hospitals a 0.05 improvement carries it past, which depends on where it sits in the distribution: per commercial dollar the return averages %.3f%% in the most-deprived ADI fifth and %.3f%% in the least.",
          cs_sn, cs_ot, cs_a5, cs_a1, 100 * pe5, 100 * pe1),
  sprintf("6. If every hospital improves by 0.05 at once and the scoring reference (winsorization bounds, mean, SD) is recalculated, ranks and bonus payments are unchanged under this rule with revenues fixed: total payment changes by $%.0f [%.0f, %.0f]. Held at the original reference instead, the same shift changes %d of %d positions and total payment by $%.1fM, a diagnostic alternative (clipping at the winsorization bounds and the %d hospitals scored on PSI-90 alone break the symmetry), not a prediction.", ai[1], ai[2], ai[3], AIR$n_rank_changes[2], AIR$n_hospitals[2], AIR$total_change[2] / 1e6, AIR$n_no_infection[2]),
  sprintf("7. Under a hypothetical stress test -- the lowest-scoring quarter earns nothing, a rule CASH2's participation statistic does not establish -- against %s the return %s, and against the models' ranking it %s.",
          DIST, vtext(sg("threshold", DIST), DIST), vtext(sg("threshold", "model-implied disadvantage"), "the models' disadvantage ranking")),
  if (nrow(ch)) sprintf("   Scenarios that change a verdict in 1 or 2: %s. Rescaled curves share their unscaled indices (an index is scale-free). Scenarios not named leave both verdicts unchanged.",
      paste(sprintf("%s -- %s, %+.3f [%+.3f, %+.3f]", ch$scenario_label, ifelse(ch$verdict == "regressive",
        sprintf("structurally regressive along %s, as arithmetic of the formula", ch$ranked_by),
        ifelse(ch$verdict == "progressive", sprintf("tilted toward more %s", ch$ranked_by),
        ifelse(ch$verdict == NOVAR, sprintf("no modeled variation along %s", ch$ranked_by),
               sprintf("no clear direction along %s", ch$ranked_by)))),
        ch$mean, ch$lo, ch$hi), collapse = "; ")) else "   No other scenario changes a verdict in 1 or 2.",
  sprintf("8. Per hospital rather than per revenue dollar, the index by the models' ranking is %+.3f [%+.3f, %+.3f], and safety-net hospitals' return is %.2f [%.2f, %.2f] times other hospitals'. That is the fundability view and is mostly hospital size, not a property of the formula.",
          gh("model-implied disadvantage")$mean, gh("model-implied disadvantage")$lo, gh("model-implied disadvantage")$hi, snh$mean, snh$lo, snh$hi),
  sprintf("9. The September 30 'marginal incentive' (eligible revenue x 0.15 x 0.039) is kept only as a revenue exposure coefficient. It never consulted the rate function, and per revenue dollar it is a fixed multiple of commercial day share, so its index along ADI (%+.3f) %s and describes payer mix.",
          expo_adi$mean, if (expo_adi$verdict == NOVAR) "has a zero-width interval because neither ADI nor commercial share is drawn -- the absence of modeled variation, not certainty --" else "varies"),
  sprintf("10. The Medicare program running today: in FY 2026, hospitals in the most-deprived fifth of catchments were over-represented among those penalized under HACRP, at %.2f times the rate of the least-deprived fifth [%.2f, %.2f]; by the models' ranking, %.2f times [%.2f, %.2f]. Safety-net hospitals were penalized at %.2f times the rate of others [%.2f, %.2f]%s. This describes who was penalized; it is associational and says nothing about why.",
          ob_adi$share, ob_adi$lo, ob_adi$hi, ob_vb$share, ob_vb$lo, ob_vb$hi, ob_sn$share, ob_sn$lo, ob_sn$hi,
          if (ob_sn$lo <= 1 && ob_sn$hi >= 1) ", an interval that includes parity" else ""),
  "",
  "Wherever 'structurally regressive' appears it describes the arithmetic of the payment formula as modeled -- a national what-if on CASH2's mechanics -- not intent, and not realized Q-HIP payments, which are not public.")
writeLines(STMT, file.path(OUT, "regressivity-statement.txt"))
cat(paste(strwrap(STMT, 100, exdent = 3), collapse = "\n"), "\n")

# ==========================================================================
# 5.  FIGURE
# ==========================================================================
hdr("5. figure")
BLUE <- "#2a78d6"; ORANGE <- "#eb6834"; GREY <- "#8c8b86"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e6e5e0"; SURF <- "#fcfcfb"
png(file.path("output", "figures", "regressivity.png"), width = 1800, height = 900, res = 150, bg = SURF)
layout(rbind(c(1, 1), c(2, 3)), heights = c(0.14, 1), widths = c(1.25, 1))
par(mar = c(0, 0, 0, 0)); plot.new()
text(0.005, 0.70, "Who a 0.05 improvement pays, and who the program running today penalizes", adj = 0, cex = 1.2, font = 2, col = INK)
text(0.005, 0.20, "Left: concentration index of the finite payment return at a 0.05 PSI-90 improvement (Q-HIP-style, simulated, base scenario, mean and 95% interval over draws; grey ticks = other scenarios). Right: observed FY 2026 HACRP.",
     adj = 0, cex = 0.78, col = INK2)
## left: forest of concentration indices
ord <- expand.grid(rk = RANK, fr = c("per NPR dollar", "per hospital"), stringsAsFactors = FALSE)
ny <- nrow(ord); yy <- rev(seq_len(ny))
xr <- range(c(RG$lo[RG$quantity == QRET & !grepl("ratio", RG$ranked_by)],
              RG$hi[RG$quantity == QRET & !grepl("ratio", RG$ranked_by)], 0))
par(mar = c(3.8, 17, 1.5, 1), mgp = c(2.3, 0.5, 0), tcl = -0.2, las = 1, col.axis = INK2, cex.axis = 0.78)
plot(NA, xlim = xr, ylim = c(0.5, ny + 0.5), yaxt = "n", xlab = "", ylab = "", bty = "n")
abline(v = pretty(xr), col = GRID, lwd = 0.8); abline(v = 0, col = INK2, lwd = 1)
mtext("concentration index  (negative = concentrated where distance from best / disadvantage is LOW)", side = 1, line = 2.3, cex = 0.66, col = INK2)
for (i in seq_len(ny)) {
  x  <- RG[RG$model_set == "primary (194)" & RG$quantity == QRET & RG$ranked_by == ord$rk[i] & RG$framing == ord$fr[i], ]
  b0 <- x[x$scenario == "base", ]; oth <- x[x$scenario != "base", ]
  segments(oth$mean, yy[i] - 0.18, oth$mean, yy[i] + 0.18, col = GREY, lwd = 1)
  col <- if (ord$fr[i] == "per NPR dollar") BLUE else ORANGE
  segments(b0$lo, yy[i], b0$hi, yy[i], col = col, lwd = 2.5); points(b0$mean, yy[i], pch = 19, col = col, cex = 1.2)
  axis(2, at = yy[i], labels = sprintf("%s, ranked by %s", ord$fr[i], ord$rk[i]), lwd = 0, cex.axis = 0.74)
}
## right: observed penalised share
ob <- OB[OB$group %in% c("safety_net", "adi"), ]
k <- nrow(ob); xs <- c(1, 2, 3.5, 4.5, 5.5, 6.5, 7.5)
par(mar = c(3.8, 3.6, 1.5, 1))
plot(NA, xlim = c(0.5, 8), ylim = c(0, max(ob$hi) * 1.08), xaxt = "n", xlab = "", ylab = "", bty = "n")
abline(h = pretty(c(0, max(ob$hi))), col = GRID, lwd = 0.8); abline(h = base_rate, col = INK2, lty = 2)
text(8, base_rate, "frame", pos = 3, cex = 0.65, col = INK2)
segments(xs, ob$lo, xs, ob$hi, col = BLUE, lwd = 2.5); points(xs, ob$share, pch = 19, col = BLUE, cex = 1.2)
axis(1, at = xs, labels = c("not SN", "SN", "ADI 1\nleast", "2", "3", "4", "5\nmost"), lwd = 0, padj = 0.5, cex.axis = 0.72)
mtext("share penalised under HACRP, FY 2026", side = 2, line = 2.4, cex = 0.66, col = INK2, las = 0)
dev.off()
cat("  -> output/figures/regressivity.png\n")

# ==========================================================================
# 6.  THE UNCERTAINTY TRACE  (Task S1.6)
# ==========================================================================
## Stage 35 found, by experiment, which random inputs move each simulated
## output (S$trace). Here every output is put in a family, each family gets an
## interval type, and the non-simulated intervals of stages 36-37 are added,
## so that every payment number the rewrite cites has a row naming its interval.
hdr("6. uncertainty trace -> output/tables/payment-uncertainty-trace.csv")
TR <- S$trace
stopifnot(!is.null(TR), all(c("spec", "coef", "score", "resid") %in% colnames(TR)))
QN <- c(pay = "bonus paid", open = "unearned band", ret = "finite return", expo = "revenue exposure coefficient")
RN <- c(head = DIST, vb = "model-implied disadvantage", adi = "catchment ADI")
KIND <- function(id) ifelse(grepl("^sn", id), "safety-net", ifelse(grepl("^adi_q", id), "ADI quintile",
                     ifelse(grepl("^vb_q", id), "model-implied disadvantage quintile",
                     ifelse(grepl("^hd_q", id), "distance-from-best quintile", "star x margin cell"))))
fam_of <- function(x) {
  if (grepl("^hosp\\.", x)) return(c("per hospital", c(hosp.Pay = "payment (per hospital, mean and SD over draws)",
    hosp.Ret = "finite return (per hospital, mean and SD over draws)", hosp.Dis = "disadvantage-associated payment (per hospital)")[[x]]))
  if (grepl("^c2(nr)?\\.count$", x)) return(c("C2", "HACRP check: expected penalty count"))
  sc <- sub("\\..*$", "", x); m <- sub("^[^.]+\\.", "", x)
  f <- if (m == "total_pay") "total payment"
  else if (m == "dis_total") "disadvantage-associated payment, total"
  else if (m == "pay_gap_to_base") "rescaled total minus base total"
  else if (grepl("^ci_(pay|open|ret|expo)(npr)?_(head|vb|adi)$", m)) {
    q <- sub("^ci_(pay|open|ret|expo).*$", "\\1", m); r <- sub("^.*_(head|vb|adi)$", "\\1", m)
    sprintf("concentration index: %s, %s, ranked by %s", QN[[q]], if (grepl("npr_", m)) "per NPR dollar" else "per hospital", RN[[r]]) }
  else if (grepl("^sn_ratio_", m)) "safety-net / other ratio of mean finite return"
  else if (m %in% c("ret_mean", "ret_share_zero")) "finite return at Delta 0.05: mean and share zero"
  else if (grepl("^allimp_", m)) "all-improve total payment change"
  else if (grepl("_d(010|025|050|100)$", m)) "finite return over the Delta grid (mean, quantiles, zero shares, indices)"
  else if (grepl("^(pay|rate|open)\\.", m)) sprintf("payment by stratum (%s)", KIND(sub("^[a-z]+\\.", "", m)))
  else if (grepl("^dis\\.", m)) sprintf("disadvantage-associated payment by stratum (%s)", KIND(sub("^dis\\.", "", m)))
  else if (grepl("^(ret|retnpr)\\.", m)) sprintf("finite return by stratum (%s)", KIND(sub("^[a-z]+\\.", "", m)))
  else if (grepl("^exponpr\\.", m)) sprintf("revenue exposure by stratum (%s)", KIND(sub("^exponpr\\.", "", m)))
  else NA_character_
  c(sc, f)
}
FM <- t(vapply(rownames(TR), fam_of, character(2)))
stopifnot(!anyNA(FM[, 2]))                     # every simulated output has a family
ILAB <- c(spec = "specification", coef = "coefficients (incl. imputation completion)",
          score = "published-score draw (U3, hypothetical repeated measurement)", resid = "C2 residual draw (U4)")
itype <- function(mv) if (!any(mv)) "zero-width: no modeled variation (nothing it depends on is drawn)" else
  paste0("95% simulation interval over draws of: ", paste(ILAB[names(mv)[mv]], collapse = "; "))
key <- paste(FM[, 1], FM[, 2], sep = "\r")
TRC <- do.call(rbind, lapply(split(seq_len(nrow(TR)), key), function(ix) {
  mv <- apply(TR[ix, , drop = FALSE], 2, any)
  data.frame(source = "stage 35 draws (traced by experiment)", scenario = FM[ix[1], 1], output = FM[ix[1], 2],
             n_columns = length(ix), spec = mv[["spec"]], coef = mv[["coef"]], score = mv[["score"]], resid = mv[["resid"]],
             interval_type = itype(mv), row.names = NULL) }))
TRC <- TRC[order(TRC$scenario != "base", TRC$scenario, TRC$output), ]
## intervals that are not simulation intervals over the stage 35 draws
ANA <- data.frame(source = c(rep("stage 36", 3), "stage 35 tables", "stage 35 tables", rep("stage 35 C2", 2), rep("stage 37 observed HACRP", 3), "stage 37 statement"),
  scenario = c("base", "base", "base", "base", "base", "C2", "C2", "observed", "observed", "observed", "base"),
  output = c("between-stratum contrasts (payment-stratum-contrasts.csv)",
             "ADI quintile 5/1 dollar gap split (payment-gap-decomposition.csv)",
             "share of dollars by stratum (payment-by-stratum.csv)",
             "per-hospital means and SDs (payment-by-hospital.csv)",
             "payment spread by lambda quartile (payment-reliability.csv)",
             "C2 calibration slope, AUC, 90% coverage (hacrp-calibration.csv)",
             "C2 reference rows: HAI information alone (AUC 0.879) and observed PSI-90 (the ceiling)",
             "penalized share by stratum (observed-hacrp-regressivity.csv)",
             "penalty rate ratios: ADI Q5/Q1, model-implied Q5/Q1, safety-net/not",
             "penalty concentration indices (ADI quintile, mean v_B)",
             "return per commercial dollar by ADI fifth (statement item 5)"),
  spec = c(NA, FALSE, NA, NA, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
  coef = c(NA, FALSE, NA, NA, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
  score = c(NA, FALSE, NA, NA, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
  resid = c(NA, FALSE, NA, NA, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
  interval_type = c("95% simulation interval of the contrast computed within each draw; inputs as the strata compared (rows above)",
                    "point estimate from hospital means over draws; no interval",
                    "95% simulation interval over draws; inputs as 'payment by stratum' above",
                    "mean and SD over draws per hospital; inputs as the hospital-level rows above (revenue exposure: none)",
                    "SD over the U3 draw: the scalar-reliability model's own hypothetical repeated measurement, not evidence for it",
                    "point values computed from draw-averaged penalty probabilities; no interval (inputs: specification, coefficients, C2 residual)",
                    "deterministic reference rows; no interval",
                    "Wilson 95% binomial interval over hospitals; no simulation input",
                    "95% interval on the log rate ratio (normal approximation); no simulation input",
                    "hospital bootstrap, 2,000 resamples; no simulation input",
                    "descriptive mean of hospital means over draws; no interval"),
  n_columns = NA, stringsAsFactors = FALSE)
TRACE_OUT <- rbind(TRC, ANA[, names(TRC)])
write.csv(TRACE_OUT, file.path(OUT, "payment-uncertainty-trace.csv"), row.names = FALSE)
cat(sprintf("  %d simulated output columns in %d families, plus %d non-simulated interval rows\n",
            nrow(TR), nrow(TRC), nrow(ANA)))
for (i in which(TRC$scenario == "base" & !grepl("stratum|grid", TRC$output)))
  cat(sprintf("  %-70.70s %s\n", TRC$output[i], sub("95% simulation interval over draws of: ", "sim: ", TRC$interval_type[i])))
## coverage: every metric in the scenario and returns tables maps to a traced column
SCt <- read.csv(file.path(OUT, "payment-scenarios.csv")); RETt <- read.csv(file.path(OUT, "payment-returns.csv"))
need <- unique(c(paste(SCt$scenario[SCt$model_set == "primary (194)"], SCt$metric[SCt$model_set == "primary (194)"], sep = "."),
                 paste0(RETt$run[RETt$quantity != "all_improve_total_pay_change"], ".",
                        RETt$quantity[RETt$quantity != "all_improve_total_pay_change"], "_",
                        names(c(d010 = 0.01, d025 = 0.025, d050 = 0.05, d100 = 0.1))[match(RETt$delta[RETt$quantity != "all_improve_total_pay_change"], c(0.01, 0.025, 0.05, 0.1))])))
miss <- setdiff(need, rownames(TR))
cat(sprintf("  coverage: %d scenario/return outputs, %d without a traced column\n", length(need), length(miss)))
stopifnot(!length(miss))

# ==========================================================================
hdr("verify")
cat("  1. 'structurally regressive' appears only with the arithmetic-of-the-formula qualifier:\n")
uses <- grep("structurally regressive", STMT, value = TRUE)
ok1 <- all(grepl("arithmetic", uses)); cat(sprintf("     %d uses, all qualified -- %s\n", length(uses), if (ok1) "PASS" else "FAIL"))
causal <- "\\b(causes?|caused|drives?|driven|leads? to|results? in|because of)\\b"
ok2 <- !any(grepl(causal, STMT[grepl("HACRP|penalised", STMT)], ignore.case = TRUE))
cat(sprintf("  2. the observed-penalty sentences carry no causal verb -- %s\n", if (ok2) "PASS" else "FAIL"))
ok3 <- !any(grepl("\\bneutral\\b|headroom", STMT, ignore.case = TRUE))
cat(sprintf("  3. no interval is called 'neutral' and 'headroom' is gone (distance from the best measured score) -- %s\n",
            if (ok3) "PASS" else "FAIL"))
stopifnot(ok1, ok2, ok3)
hdr("done")
