# R/04-spec-diagnostics.R  --  Task 3.8, influence and diagnostics across the
# specification curve.
#
# Reads data/spec-results.rds (Task 3.7) and data/analytic-v2.rds. Two
# questions, per the task sheet:
#   A. does any single hospital or state drive the disadvantage estimate?
#   B. do particular specification choices sit as outliers?
#
# Nothing is removed. Influential units are reported; where dropping one
# changes a conclusion, both versions are reported (the verify condition).
#
# Part A uses ANCHOR specifications rather than the whole 3,344-spec curve,
# because leave-one-out over the full grid is 2,801 refits x 3,344 specs. The
# anchors are the composite outcome (the published one, and an lm() so
# leave-one-hospital-out is the closed-form dfbeta) at the four
# form x reliability combinations that Task 3.7 found consequential, plus two
# mixed-model anchors (the component aggregate and PSI-12) for which only
# leave-one-state-out is computed, by refit.
#
# Part B decomposes the spread in the standardised estimate. The within-cell
# contribution of each axis holds the other seven fixed and moves one. The
# main-effects analysis of variance runs on the balanced ABC subset (dropping
# the errors-in-variables level, which occurs only with the composite, so it
# cannot enter a balanced design -- Task 3.7 Sec 4 already reports it paired).
#
# Outputs: R/04-spec-diagnostics.R, output/tables/spec-diagnostics-influence.csv,
# output/tables/spec-diagnostics-axis-contribution.csv,
# output/figures/spec-diagnostics.png.

suppressMessages({ library(lme4); library(splines) })
e <- new.env()
sys.source(file.path("R", "04-spec-curve.R"), envir = e)   # prep_spec, contrast_rows, contrast_estimate

n_   <- function(x) suppressWarnings(as.numeric(x))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 3.8  influence and diagnostics across the specification curve")

S  <- readRDS(file.path("data", "spec-results.rds"))
R  <- S$results
a0 <- readRDS(file.path("data", "analytic-v2.rds"))
sd_psi90 <- sd(a0$psi90, na.rm = TRUE)
natM <- sapply(c("psi03", "psi06", "psi12", "psi13"),
               function(cp) mean(n_(a0[[cp]]), na.rm = TRUE))
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

C <- R[R$blocks != "A" & R$status == "ok", ]
C$dis_std <- C$dis_effect / std_div(C$outcome_family)

# ==========================================================================
# PART A.  DOES ANY SINGLE HOSPITAL OR STATE DRIVE THE ESTIMATE?
# ==========================================================================
hdr("A  unit influence -- leave one hospital out, leave one state out")

anchors <- list(
  list(tag = "composite / linear / unweighted", blocks = "ABC", form = "linear",
       outcome = "composite", reliability = "unweighted"),
  list(tag = "composite / linear / lambda-weighted", blocks = "ABC", form = "linear",
       outcome = "composite", reliability = "weighted"),
  list(tag = "composite / linear / errors-in-variables", blocks = "ABC", form = "linear",
       outcome = "composite", reliability = "eiv"),
  list(tag = "composite / spline / lambda-weighted", blocks = "ABC", form = "spline",
       outcome = "composite", reliability = "weighted"),
  list(tag = "component aggregate / linear / weighted", blocks = "ABC", form = "linear",
       outcome = "agg", reliability = "weighted"),
  list(tag = "PSI-12 / linear / weighted", blocks = "ABC", form = "linear",
       outcome = "psi12", reliability = "weighted"))

## fixed non-varying axis levels for every anchor
FIX <- list(grain = "catch_tract", missing = "complete", influential = "all", scale = "identity")

spec_from <- function(an) {
  s <- e$reg[e$reg$blocks == an$blocks & e$reg$form == an$form & e$reg$outcome == an$outcome &
             e$reg$reliability == an$reliability & e$reg$grain == FIX$grain &
             e$reg$missing == FIX$missing & e$reg$influential == FIX$influential &
             e$reg$scale == FIX$scale, ]
  as.list(s[1, ])
}

## fit an anchor, return model + contrast vector + data + the dis_effect
fit_anchor <- function(s) {
  pp <- e$prep_spec(s, a0)
  fe <- paste(c(pp$feA, pp$feB, pp$feC), collapse = " + ")
  is_mer <- pp$mixed
  m <- if (is_mer)
    lmer(as.formula(sprintf(".y ~ %s + (1 | .nest)", fe)), data = pp$data,
         weights = if (s$reliability == "unweighted") rep(1, nrow(pp$data)) else pp$data$.w,
         REML = TRUE, control = e$ctrl)
  else
    lm(as.formula(sprintf(".y ~ %s", fe)), data = pp$data, weights = pp$data$.w)
  fe_terms <- terms(as.formula(sprintf("~ %s", fe)), data = pp$data)
  nd <- e$contrast_rows(pp)
  ce <- e$contrast_estimate(m, fe_terms, nd, is_mer)
  list(m = m, cvec = ce$cvec, data = pp$data, est = ce$est, se = ce$se,
       is_mer = is_mer, fam = pp$fam)
}

INF <- list()
for (an in anchors) {
  s <- spec_from(an); fa <- fit_anchor(s)
  d <- fa$data; div <- std_div(fa$fam)
  est0 <- fa$est / div
  beta <- if (fa$is_mer) lme4::fixef(fa$m) else coef(fa$m)
  nm <- intersect(names(fa$cvec), names(beta[!is.na(beta)]))
  cc <- fa$cvec[nm]

  ## leave-one-HOSPITAL-out (closed form for lm via dfbeta; skipped for lmer)
  if (!fa$is_mer) {
    db <- stats::dfbeta(fa$m)                       # n x p change in beta on deleting row i
    d_hosp <- as.numeric(db[, nm, drop = FALSE] %*% cc) / div   # delta in dis_std
    ho <- order(-abs(d_hosp))[1:8]
    hosp_tab <- data.frame(ccn = d$ccn[ho], state = d$state[ho],
                           delta_std = d_hosp[ho], new_est = est0 - d_hosp[ho])
    max_h <- max(abs(d_hosp)); flip_h <- any(sign(est0 - d_hosp) != sign(est0))
  } else {
    hosp_tab <- NULL; max_h <- NA; flip_h <- NA
    d_hosp <- NA
  }

  ## leave-one-STATE-out (refit)
  unwtd <- s$reliability == "unweighted"
  sts <- sort(unique(d$state))
  d_state <- vapply(sts, function(st) {
    di <- d[d$state != st, ]
    di$.wfit <- if (unwtd) 1 else di$.w
    mi <- if (fa$is_mer)
      suppressWarnings(lmer(formula(fa$m), data = di, weights = .wfit,
                            REML = TRUE, control = e$ctrl))
    else lm(formula(fa$m), data = di, weights = .wfit)
    b <- if (fa$is_mer) lme4::fixef(mi) else coef(mi)
    nmi <- intersect(names(cc), names(b[!is.na(b)]))
    est0 - sum(cc[nmi] * b[nmi]) / div
  }, numeric(1))
  so <- order(-abs(d_state))[1:6]
  state_tab <- data.frame(state = sts[so], delta_std = d_state[so],
                          new_est = est0 - d_state[so])
  max_s <- max(abs(d_state)); flip_s <- any(sign(est0 - d_state) != sign(est0))

  cat(sprintf("\n  %s\n", an$tag))
  cat(sprintf("    dis_std = %+.3f SD (se %.3f)\n", est0, fa$se / div))
  if (!fa$is_mer)
    cat(sprintf("    leave-one-hospital-out: max |shift| = %.4f SD (%.1f%% of the estimate); sign flips: %s\n",
                max_h, 100 * max_h / abs(est0), flip_h))
  cat(sprintf("    leave-one-state-out:    max |shift| = %.4f SD (%.1f%% of the estimate); sign flips: %s\n",
              max_s, 100 * max_s / abs(est0), flip_s))
  cat(sprintf("    most influential state: %s (shift %+.4f SD -> %+.3f)\n",
              state_tab$state[1], -state_tab$delta_std[1], state_tab$new_est[1]))

  INF[[length(INF) + 1]] <- data.frame(
    anchor = an$tag, dis_std = est0, se_std = fa$se / div,
    loo_hosp_max = max_h, loo_hosp_flip = flip_h,
    loo_state_max = max_s, loo_state_flip = flip_s,
    top_state = state_tab$state[1], top_state_new_est = state_tab$new_est[1],
    top_hosp = if (is.null(hosp_tab)) NA else hosp_tab$ccn[1],
    top_hosp_new_est = if (is.null(hosp_tab)) NA else hosp_tab$new_est[1])
}
INFT <- do.call(rbind, INF)
write.csv(INFT, file.path("output", "tables", "spec-diagnostics-influence.csv"), row.names = FALSE)

sub_("reading")
cat(sprintf("  Largest leave-one-state-out shift across the six anchors: %.4f SD.\n", max(INFT$loo_state_max)))
cat(sprintf("  Largest leave-one-hospital-out shift (composite anchors): %.4f SD.\n",
            max(INFT$loo_hosp_max, na.rm = TRUE)))
cat(sprintf("  Any single-unit removal that flips an anchor's sign: %s.\n",
            if (any(c(INFT$loo_hosp_flip, INFT$loo_state_flip), na.rm = TRUE)) "YES -- see table" else "none"))

# ==========================================================================
# PART B.  DO PARTICULAR SPECIFICATION CHOICES SIT AS OUTLIERS?
# ==========================================================================
hdr("B  which axes move the estimate, and which levels are outliers")

AXES <- c("blocks", "form", "outcome", "reliability", "grain", "missing", "influential", "scale")

## --- within-cell contribution: hold the other axes, move one ---
## `blocks` has no within-cell variation -- every cell fixes a missing-data
## level, and missing = "na" occurs only with AB while mi/complete/omit occur
## only with ABC, so the blocks axis is perfectly confounded with it. It is
## reported instead as a paired AB-vs-ABC shift (Sec below).
sub_("within-cell spread attributable to each axis (SD of dis_std within a cell)")
wc <- list()
for (ax in setdiff(AXES, "blocks")) {
  others <- setdiff(AXES, ax)
  key <- apply(C[, others], 1, paste, collapse = "|")
  parts <- split(C$dis_std, key)
  parts <- parts[vapply(parts, length, integer(1)) >= 2]
  within_sd <- vapply(parts, sd, numeric(1))
  within_rg <- vapply(parts, function(v) diff(range(v)), numeric(1))
  wc[[length(wc) + 1]] <- data.frame(axis = ax, n_cells = length(parts),
    mean_within_sd = mean(within_sd), median_within_range = median(within_rg))
  cat(sprintf("  %-12s  cells=%4d   mean within-cell SD = %.3f   median within-cell range = %.3f\n",
              ax, length(parts), mean(within_sd), median(within_rg)))
}
WC <- do.call(rbind, wc)

sub_("adding Block C -- paired AB(na) vs mean ABC(mi/complete/omit), other axes fixed")
kk <- with(C, paste(form, outcome, reliability, grain, influential, scale, sep = "|"))
abc_shift <- vapply(unique(kk), function(k) {
  x <- C[kk == k, ]
  ab <- x$dis_std[x$blocks == "AB"]; ac <- x$dis_std[x$blocks == "ABC"]
  if (length(ab) && length(ac)) mean(ac) - ab[1] else NA_real_
}, numeric(1))
abc_shift <- abc_shift[is.finite(abc_shift)]
cat(sprintf("  n_cells = %d   mean shift %+.3f SD   median %+.3f   share moving the estimate down %s\n",
            length(abc_shift), mean(abc_shift), median(abc_shift), pct(mean(abc_shift < 0))))

## --- main-effects variance decomposition on the balanced ABC subset ---
sub_("analysis of variance, balanced ABC subset (eiv excluded -- composite-only)")
bal <- C[C$blocks == "ABC" & C$reliability %in% c("unweighted", "weighted", "subsample"), ]
cat(sprintf("  n = %d specifications (form x outcome x reliability x grain x missing x influential x scale)\n", nrow(bal)))
av <- aov(dis_std ~ form + outcome + reliability + grain + missing + influential + scale, data = bal)
ss <- summary(av)[[1]][, "Sum Sq"]
names(ss) <- trimws(rownames(summary(av)[[1]]))
eta2 <- ss / sum(ss)
for (nm in names(sort(eta2[names(eta2) != "Residuals"], decreasing = TRUE)))
  cat(sprintf("  %-12s  eta^2 = %.3f\n", nm, eta2[nm]))
cat(sprintf("  %-12s  eta^2 = %.3f  (spec-to-spec noise within a fully specified cell)\n",
            "Residuals", eta2["Residuals"]))
WC$eta2_balanced <- eta2[match(WC$axis, names(eta2))]
write.csv(WC, file.path("output", "tables", "spec-diagnostics-axis-contribution.csv"), row.names = FALSE)

## --- which single levels are outliers (extreme within their cells) ---
sub_("level outliers -- within-cell deviation from the cell median, by level")
lev_out <- list()
for (ax in AXES) {
  others <- setdiff(AXES, ax)
  key <- apply(C[, others], 1, paste, collapse = "|")
  med <- ave(C$dis_std, key, FUN = median)
  dev <- C$dis_std - med
  for (lv in sort(unique(C[[ax]]))) {
    x <- dev[C[[ax]] == lv]
    lev_out[[length(lev_out) + 1]] <- data.frame(axis = ax, level = lv,
      median_dev = as.numeric(median(x)),
      p95_abs_dev = as.numeric(quantile(abs(x), .95)), n = length(x))
  }
}
LO <- do.call(rbind, lev_out); rownames(LO) <- NULL
LO <- LO[order(-LO$p95_abs_dev), ]
for (i in 1:10)
  cat(sprintf("  %-12s %-13s  median shift %+.3f   95th pct |shift| %.3f\n",
              LO$axis[i], LO$level[i], LO$median_dev[i], LO$p95_abs_dev[i]))

# ==========================================================================
# FIGURE
# ==========================================================================
png(file.path("output", "figures", "spec-diagnostics.png"), width = 1500, height = 900, res = 140)
layout(matrix(c(1, 2, 3, 4), nrow = 2, byrow = TRUE))

## 1-2: leave-one-state-out for two composite anchors
for (an in anchors[c(2, 3)]) {
  s <- spec_from(an); fa <- fit_anchor(s); d <- fa$data; div <- std_div(fa$fam)
  est0 <- fa$est / div
  beta <- coef(fa$m); nm <- intersect(names(fa$cvec), names(beta[!is.na(beta)])); cc <- fa$cvec[nm]
  sts <- sort(unique(d$state))
  ds <- vapply(sts, function(st) {
    di <- d[d$state != st, ]; di$.wfit <- di$.w
    mi <- lm(formula(fa$m), data = di, weights = .wfit)
    b <- coef(mi); nmi <- intersect(names(cc), names(b[!is.na(b)]))
    (est0 - sum(cc[nmi] * b[nmi]) / div)
  }, numeric(1))
  o <- order(ds)
  par(mar = c(4, 3.5, 3, 1), mgp = c(2.1, 0.6, 0))
  plot(seq_along(sts), (est0 - ds)[o], pch = 19, cex = 0.6, col = "#2f5c8a",
       xlab = "state left out (sorted)", ylab = "anchor estimate (SD)", main = an$tag, cex.main = 0.9)
  abline(h = est0, col = "#c2703d", lty = 2); abline(h = 0, col = "#00000055")
  text(3, est0, "full sample", pos = 3, cex = 0.7, col = "#c2703d")
}

## 3: within-cell SD by axis
par(mar = c(4, 7, 3, 1), mgp = c(2.1, 0.6, 0))
o <- order(WC$mean_within_sd)
barplot(WC$mean_within_sd[o], names.arg = WC$axis[o], horiz = TRUE, las = 1, border = NA,
        col = "#6b8fb3", xlab = "mean within-cell SD of the estimate (SD units)",
        main = "how much each axis moves the estimate", cex.main = 0.9, cex.names = 0.85)

## 4: eta^2 balanced subset
par(mar = c(4, 7, 3, 1), mgp = c(2.1, 0.6, 0))
ev <- sort(eta2[!names(eta2) %in% c("Residuals")], decreasing = FALSE)
barplot(ev, names.arg = names(ev), horiz = TRUE, las = 1, border = NA, col = "#8a9a5b",
        xlab = "share of variance in the estimate (balanced ABC subset)",
        main = "analysis of variance, main effects", cex.main = 0.9, cex.names = 0.85)
dev.off()
cat(sprintf("\n  output/figures/spec-diagnostics.png\n"))

# ==========================================================================
hdr("verify")
cat(sprintf("  1. influential units reported, not removed: %d anchors x (leave-one-hospital, leave-one-state) in\n", nrow(INFT)))
cat("     output/tables/spec-diagnostics-influence.csv -- PASS\n")
flips <- any(c(INFT$loo_hosp_flip, INFT$loo_state_flip), na.rm = TRUE)
cat(sprintf("  2. does dropping any single unit change a conclusion: %s\n",
            if (flips) "YES -- both versions in the table" else "NO -- no single hospital or state flips an anchor's sign"))
cat(sprintf("  3. specification-choice outliers reported: axis contributions + level deviations, %d rows -- PASS\n", nrow(LO)))
stopifnot(nrow(INFT) == length(anchors), nrow(WC) == length(AXES) - 1L,
          file.exists(file.path("output", "figures", "spec-diagnostics.png")))

hdr("done")
