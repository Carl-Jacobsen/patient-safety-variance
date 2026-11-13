# R/14-geo-validation.R  --  Task S2.4, held-out validation of reduced datasets.
# make.R stage 40. POST-REVIEW: added after the critical review of 2026-10-01,
# run exactly as fixed in provenance/second-pass-preregistration.md sec 6.
#
# The question is the one a data-prioritization recommendation needs and the
# TIS ranking cannot answer: does a model fitted with fewer community measures
# predict published PSI-90 as well, for hospitals it did not see, and above all
# for hospitals in states it did not see? This stage, and not the TIS ranking,
# is the evidence for any such recommendation in the rewrite.
#
# Candidates (pre-registration sec 6). Every one takes P-best's settings --
# spec 382: composite, spline, unweighted, catch_county grain, complete-case,
# identity scale -- and its Block A and Block C terms; only Block B varies:
#   (a) no Block B  (b) all of Block B, as in P-best  (c) ADI only
#   (d) SVI themes 1-4 and the limited-English share
#   (e) the measures tagged essential in S1.2, if that set differs from (d).
# An intercept-only fit is reported beside them as a reference, not a candidate.
#
# Folds. New-area: the 51 state codes partitioned at random into five groups,
# 20 repeats. Within-area: five random hospital folds, 20 repeats. Seeds are
# SEED + r for the state partitions and SEED + 1000 + r for the hospital folds.
#
# Inside each training fold: standardization (means and SDs) and the spline
# knots (quantiles .25/.50/.75, boundary .05/.95, as in R/04-spec-curve.R) come
# from training hospitals only. P-best is complete-case, so no imputation runs.
#
# Loss: mean squared error of published PSI-90 over the held-out hospitals of a
# repeat (each hospital predicted once per repeat). Practical tolerance: a
# reduced dataset loses nothing if its mean new-area loss is within 1% of
# model (b)'s. Differences are reported with their 2.5th-97.5th percentiles
# over the 20 repeats.
#
# Checks before any fold runs: (1) the design builder, given the frame-wide
# standardization and knots R/04-spec-curve.R uses, reproduces spec 382's
# stored common-frame loss; (2) the leakage test -- permuting the held-out
# outcomes, and separately replacing held-out outcomes and covariates with
# noise, leaves every training fit unchanged, and a deliberately leaky fitter
# fails the second test.
#
# Outputs: output/tables/geo-validation.csv (one row per design x model),
# output/tables/geo-validation-repeats.csv (per repeat), the log.

suppressMessages(library(splines))
n_   <- function(x) suppressWarnings(as.numeric(x))
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
pct  <- function(x, d = 2) sprintf(paste0("%+.", d, "f%%"), 100 * x)

SEED <- 20261001
R_REP <- 20; K <- 5; TOL <- 0.01

hdr("TASK S2.4  geographic validation of reduced datasets -- stage 40 (post-review)")

a   <- readRDS(file.path("data", "analytic-v2.rds"))
reg <- readRDS(file.path("data", "spec-registry.rds"))
LOSS <- readRDS(file.path("data", "rashomon-loss.rds"))
TAGS <- read.csv(file.path("output", "tables", "driver-tags.csv"), stringsAsFactors = FALSE)
s382 <- reg[reg$spec_id == 382, ]
stopifnot(s382$blocks == "ABC", s382$form == "spline", s382$reliability == "unweighted",
          s382$grain == "catch_county", s382$missing == "complete", s382$scale == "identity",
          s382$influential == "all")

# ==========================================================================
# 1.  P-BEST'S TERMS -- the maps of R/04-spec-curve.R, catch_county grain
# ==========================================================================
bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy", resident_to_bed = "resident_to_bed",
        teaching = "teaching", cmi = "cmi", volume = "volume_bills", dsh_pct = "dsh_pct",
        wage_index = "wage_index", operating_margin = "operating_margin",
        uncomp_care = "uncompensated_care_pct_npr")
bC <- c(cmi_drift = "cmi_drift", contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")
bB <- c(svi1 = "svi1_catch_county", svi2 = "svi2_catch_county", svi3 = "svi3_catch_county",
        svi4 = "svi4_catch_county", adi = "adi_catch_county", ice150 = "ice150_catch_county",
        uninsured = "uninsured_catch_county", limeng = "limeng_catch_county",
        rurality = "rurality_catch_county", pcp_density = "pcp_density_catch_county", hhi = "hhi_zip")
SPLINE_SET <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng")
CONT <- c(bA[names(bA) != "teaching"], bB, bC)

## (e): the S1.2 essential set at the primary tolerance
ESS <- TAGS$measure[TAGS$tag_primary == "essential"]
CAND <- list(a = character(0), b = names(bB), c = "adi",
             d = c("svi1", "svi2", "svi3", "svi4", "limeng"))
e_note <- if (!length(ESS)) "S1.2 tagged no measure essential, so (e) is the empty set and coincides with (a)" else
          if (setequal(ESS, CAND$d)) "the essential set equals (d)" else NA
if (is.na(e_note)) CAND$e <- ESS
cat(sprintf("  candidate (e): %s\n", if (is.na(e_note)) paste(ESS, collapse = ", ") else paste0("not fitted -- ", e_note)))
MODELS <- c(CAND, list(null = NULL))
LABEL <- c(a = "(a) no Block B", b = "(b) all of Block B (P-best)", c = "(c) ADI only",
           d = "(d) SVI themes 1-4 + limited English", e = "(e) S1.2 essential set",
           null = "intercept only (reference)")

# ==========================================================================
# 2.  THE FRAME -- complete on model (b)'s terms; every candidate is nested in
#     (b), so all of them are fitted and scored on the same hospitals
# ==========================================================================
ok <- is.finite(n_(a$psi90)) & is.finite(n_(a$teaching))
for (cl in CONT) ok <- ok & is.finite(n_(a[[cl]]))
F0 <- a[ok, ]
F0$.y <- n_(F0$psi90)
cat(sprintf("  frame: %d hospitals in %d state codes (spec 382's stored fit and evaluation n: %d / %d)\n",
            nrow(F0), length(unique(F0$state)), LOSS$n_fit[LOSS$spec_id == 382], LOSS$n_eval[LOSS$spec_id == 382]))
stopifnot(nrow(F0) == LOSS$n_fit[LOSS$spec_id == 382], !anyNA(F0$state))

# ==========================================================================
# 3.  THE DESIGN BUILDER AND THE FOLD FITTER
# ==========================================================================
## parameters from a reference set of rows: mean/sd of each continuous term,
## and the spline knots in z-units
params_of <- function(d) {
  zp <- sapply(CONT, function(cl) { x <- n_(d[[cl]]); c(mu = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE)) })
  colnames(zp) <- names(CONT)
  kn <- lapply(SPLINE_SET, function(b) {
    z <- (n_(d[[bB[[b]]]]) - zp["mu", b]) / zp["sd", b]
    list(k = quantile(z, c(.25, .5, .75), na.rm = TRUE, names = FALSE),
         bk = quantile(z, c(.05, .95), na.rm = TRUE, names = FALSE))
  })
  names(kn) <- SPLINE_SET
  list(z = zp, knots = kn)
}
## the model matrix for rows `d` under parameters `P` and Block B set `bset`
design <- function(d, P, bset) {
  if (is.null(bset)) return(matrix(1, nrow(d), 1, dimnames = list(NULL, "(Intercept)")))
  zc <- function(k, cl) (n_(d[[cl]]) - P$z["mu", k]) / P$z["sd", k]
  cols <- list(`(Intercept)` = rep(1, nrow(d)))
  for (k in names(bA)) cols[[k]] <- if (k == "teaching") n_(d$teaching) else zc(k, bA[[k]])
  for (b in bset) {
    z <- zc(b, bB[[b]])
    if (b %in% SPLINE_SET) {
      ## knots at 8 significant figures, as R/04-spec-curve.R writes them into its formula
      B <- ns(z, knots = signif(P$knots[[b]]$k, 8), Boundary.knots = signif(P$knots[[b]]$bk, 8))
      for (j in seq_len(ncol(B))) cols[[paste0(b, "_ns", j)]] <- B[, j]
    } else cols[[b]] <- z
  }
  for (k in names(bC)) cols[[k]] <- zc(k, bC[[k]])
  do.call(cbind, cols)
}
## fit on the training rows only; everything (parameters, knots, coefficients)
## is computed from d[tr, ] and nothing else
fit_fold <- function(d, tr, bset) {
  P <- params_of(d[tr, ])
  X <- design(d[tr, ], P, bset)
  b <- qr.coef(qr(X), d$.y[tr]); b[is.na(b)] <- 0
  list(P = P, b = b)
}
pred_fold <- function(f, d, te, bset) as.numeric(design(d[te, ], f$P, bset) %*% f$b)
## the deliberately leaky fitter: parameters from ALL rows, held-out included
fit_leaky <- function(d, tr, bset) {
  P <- params_of(d)
  X <- design(d[tr, ], P, bset)
  b <- qr.coef(qr(X), d$.y[tr]); b[is.na(b)] <- 0
  list(P = P, b = b)
}

# ==========================================================================
# 4.  CHECK 1 -- the builder reproduces spec 382's stored loss
# ==========================================================================
sub_("check 1: the design builder reproduces spec 382")
## R/04-spec-curve.R standardizes and places knots on the whole analytic file
P_all <- params_of(a)
Xb <- design(F0, P_all, CAND$b)
bb <- qr.coef(qr(Xb), F0$.y)
loss382 <- mean((F0$.y - Xb %*% bb)^2)
ref382 <- LOSS$loss[LOSS$spec_id == 382]
cat(sprintf("  columns %d (stored n_fe %d); loss %.12f vs stored %.12f; rel diff %.1e\n",
            ncol(Xb), LOSS$n_fe[LOSS$spec_id == 382], loss382, ref382, abs(loss382 / ref382 - 1)))
stopifnot(ncol(Xb) == LOSS$n_fe[LOSS$spec_id == 382], abs(loss382 / ref382 - 1) < 1e-10)
cat("  PASS\n")

# ==========================================================================
# 5.  FOLDS
# ==========================================================================
STATES <- sort(unique(F0$state))
fold_new <- function(r) {
  set.seed(SEED + r)
  g <- sample(rep(seq_len(K), length.out = length(STATES)))
  setNames(g, STATES)[F0$state]
}
fold_within <- function(r) {
  set.seed(SEED + 1000 + r)
  sample(rep(seq_len(K), length.out = nrow(F0)))
}
FOLDS <- list(new_area = lapply(seq_len(R_REP), fold_new), within_area = lapply(seq_len(R_REP), fold_within))
fs <- table(unlist(lapply(FOLDS$new_area, function(f) as.integer(table(factor(f, 1:K))))))
cat(sprintf("\n  new-area held-out fold sizes over %d repeats: %d to %d hospitals (median %d)\n", R_REP,
            min(as.integer(names(fs))), max(as.integer(names(fs))),
            as.integer(median(unlist(lapply(FOLDS$new_area, function(f) as.integer(table(f))))))))

# ==========================================================================
# 6.  CHECK 2 -- leakage
# ==========================================================================
sub_("check 2: leakage -- held-out rows cannot move a training fit")
same_fit <- function(f1, f2) identical(f1$b, f2$b) && identical(f1$P, f2$P)
leak_test <- function(fitter, perturb) {
  bad <- 0; n <- 0
  for (dz in names(FOLDS)) { fo <- FOLDS[[dz]][[1]]
    for (k in seq_len(K)) { tr <- which(fo != k); te <- which(fo == k)
      for (m in names(CAND)) {
        f0 <- fitter(F0, tr, MODELS[[m]])
        d2 <- perturb(F0, te, k)
        f1 <- fitter(d2, tr, MODELS[[m]])
        n <- n + 1; if (!same_fit(f0, f1)) bad <- bad + 1
      }
    }
  }
  c(fits = n, changed = bad)
}
perm_y <- function(d, te, k) { set.seed(SEED + 500 + k); d$.y[te] <- d$.y[te][sample(length(te))]; d }
noise_all <- function(d, te, k) {
  set.seed(SEED + 600 + k)
  d$.y[te] <- rnorm(length(te), 5, 3)
  for (cl in CONT) d[[cl]][te] <- rnorm(length(te), 50, 40)
  d
}
L1 <- leak_test(fit_fold, perm_y)
L2 <- leak_test(fit_fold, noise_all)
L3 <- leak_test(fit_leaky, noise_all)
cat(sprintf("  held-out outcomes permuted:                 %d fits, %d changed\n", L1["fits"], L1["changed"]))
cat(sprintf("  held-out outcomes and covariates as noise:  %d fits, %d changed\n", L2["fits"], L2["changed"]))
cat(sprintf("  the same, with a leaky fitter (parameters from all rows): %d of %d changed\n", L3["changed"], L3["fits"]))
stopifnot(L1["changed"] == 0, L2["changed"] == 0, L3["changed"] == L3["fits"])
cat("  PASS -- the fold fitter sees training rows only, and the test would catch one that did not\n")

# ==========================================================================
# 7.  RUN
# ==========================================================================
sub_("held-out loss, 20 repeats x 5 folds, both designs")
t0 <- Sys.time()
REP <- list()
for (dz in names(FOLDS)) for (r in seq_len(R_REP)) {
  fo <- FOLDS[[dz]][[r]]
  for (m in names(MODELS)) {
    p <- rep(NA_real_, nrow(F0))
    for (k in seq_len(K)) { tr <- which(fo != k); te <- which(fo == k)
      p[te] <- pred_fold(fit_fold(F0, tr, MODELS[[m]]), F0, te, MODELS[[m]]) }
    stopifnot(!anyNA(p))
    REP[[length(REP) + 1]] <- data.frame(design = dz, repeat_id = r, model = m, loss = mean((F0$.y - p)^2))
  }
}
REP <- do.call(rbind, REP)
cat(sprintf("  %d repeat-level losses in %.1f s\n", nrow(REP), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
base <- REP[REP$model == "b", c("design", "repeat_id", "loss")]; names(base)[3] <- "loss_b"
REP <- merge(REP, base, by = c("design", "repeat_id"))
REP$diff <- REP$loss - REP$loss_b
REP$rel_diff <- REP$diff / REP$loss_b
REP <- REP[order(REP$design, REP$model, REP$repeat_id), ]
write.csv(REP, file.path("output", "tables", "geo-validation-repeats.csv"), row.names = FALSE)

q <- function(x, p) unname(quantile(x, p))
SUM <- do.call(rbind, lapply(split(REP, list(REP$design, REP$model), drop = TRUE), function(z) {
  m <- z$model[1]
  data.frame(design = z$design[1], model = m, label = LABEL[[m]],
             n_blockB = if (is.null(MODELS[[m]])) NA else length(MODELS[[m]]),
             n_terms = if (m == "null") 1 else ncol(design(F0[1:5, ], P_all, MODELS[[m]])),
             loss_mean = mean(z$loss), loss_lo = q(z$loss, .025), loss_hi = q(z$loss, .975),
             diff_mean = mean(z$diff), diff_lo = q(z$diff, .025), diff_hi = q(z$diff, .975),
             rel_diff_mean = mean(z$rel_diff), rel_diff_lo = q(z$rel_diff, .025), rel_diff_hi = q(z$rel_diff, .975),
             share_repeats_better_than_b = mean(z$diff < 0),
             r2_heldout = 1 - mean(z$loss) / mean(REP$loss[REP$design == z$design[1] & REP$model == "null"]),
             share_repeats_within_tol = if (m %in% setdiff(names(CAND), "b")) mean(z$rel_diff <= TOL) else NA,
             ## the pre-registered rule: mean new-area loss within 1% of (b)'s; (b) is the reference
             within_tolerance = if (z$design[1] == "new_area" && m %in% setdiff(names(CAND), "b"))
                                  mean(z$rel_diff) <= TOL else NA)
}))
SUM$design <- factor(SUM$design, c("new_area", "within_area"))
SUM <- SUM[order(SUM$design, match(SUM$model, names(MODELS))), ]
SUM$design <- as.character(SUM$design); rownames(SUM) <- NULL
SUM$e_note <- if (is.na(e_note)) "" else e_note
## share of Block B's held-out gain over (a) that a reduced dataset keeps,
## (loss_a - loss_m) / (loss_a - loss_b), per repeat then summarized
G <- merge(REP[REP$model %in% c("c", "d", "e"), c("design", "repeat_id", "model", "loss", "loss_b")],
           setNames(REP[REP$model == "a", c("design", "repeat_id", "loss")], c("design", "repeat_id", "loss_a")))
G$kept <- (G$loss_a - G$loss) / (G$loss_a - G$loss_b)
GK <- aggregate(kept ~ design + model, G, function(x) c(mean = mean(x), lo = q(x, .025), hi = q(x, .975)))
GK <- data.frame(design = GK$design, model = GK$model, gain_kept = GK$kept[, "mean"],
                 gain_kept_lo = GK$kept[, "lo"], gain_kept_hi = GK$kept[, "hi"])
SUM <- merge(SUM, GK, by = c("design", "model"), all.x = TRUE, sort = FALSE)
SUM <- SUM[order(match(SUM$design, c("new_area", "within_area")), match(SUM$model, names(MODELS))), ]
rownames(SUM) <- NULL
SUM$in_sample_loss_b <- ref382
SUM$in_sample_r2_b <- 1 - ref382 / mean((F0$.y - mean(F0$.y))^2)
write.csv(SUM, file.path("output", "tables", "geo-validation.csv"), row.names = FALSE)

for (dz in c("new_area", "within_area")) {
  sub_(sprintf("%s  (%s)", dz, if (dz == "new_area") "held-out states -- the tolerance applies here" else "held-out hospitals in seen states"))
  cat(sprintf("  %-38s %9s %9s  %-26s %-24s %s\n", "model", "loss", "R2 out", "vs (b), relative [2.5-97.5]", "", "within 1% (repeats)"))
  z <- SUM[SUM$design == dz, ]
  for (i in seq_len(nrow(z)))
    cat(sprintf("  %-38s %9.6f %8.1f%%  %8s [%8s, %8s]  better than (b) in %3.0f%% of repeats  %s\n",
                z$label[i], z$loss_mean[i], 100 * z$r2_heldout[i], pct(z$rel_diff_mean[i]), pct(z$rel_diff_lo[i]),
                pct(z$rel_diff_hi[i]), 100 * z$share_repeats_better_than_b[i],
                paste0(if (is.na(z$within_tolerance[i])) "" else if (z$within_tolerance[i]) "yes" else "no",
                       if (is.na(z$share_repeats_within_tol[i])) "" else sprintf(" (%.0f%%)", 100 * z$share_repeats_within_tol[i]))))
}
sub_("share of Block B's held-out gain over (a) that each reduced dataset keeps")
for (i in which(!is.na(SUM$gain_kept)))
  cat(sprintf("  %-12s %-38s %5.0f%%  [%4.0f%%, %4.0f%%]\n", SUM$design[i], SUM$label[i], 100 * SUM$gain_kept[i],
              100 * SUM$gain_kept_lo[i], 100 * SUM$gain_kept_hi[i]))
cat(sprintf("\n  in-sample loss of (b), spec 382 on the full frame: %.6f (R2 %.1f%%) -- held-out R2 is the\n",
            ref382, 100 * SUM$in_sample_r2_b[1]))
cat("  honest figure for prediction; the in-sample one includes the fit's own optimism\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. spec 382 reproduced by the builder before any fold ran -- PASS\n"))
cat(sprintf("  2. leakage: permuted held-out outcomes changed %d of %d training fits; noise in held-out\n", L1["changed"], L1["fits"]))
cat(sprintf("     outcomes and covariates changed %d; a leaky fitter is caught (%d of %d) -- PASS\n", L2["changed"], L3["changed"], L3["fits"]))
cat(sprintf("  3. new-area and within-area results reported separately; the 1%% tolerance is applied\n"))
cat(sprintf("     to new-area loss only -- PASS\n"))
cat(sprintf("  4. labeled post-review; (e): %s\n", if (is.na(e_note)) "fitted" else e_note))
stopifnot(nrow(SUM) == 2 * length(MODELS), all(is.finite(SUM$loss_mean)))
hdr("done")
