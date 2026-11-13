# R/missingness.R  --  Task 2.6, the missingness audit
#
# Two questions, kept separate, for every analytic variable:
#
#   1. Does its missingness correlate with DISADVANTAGE?  -> report §9 Limitations.
#      Missingness concentrated in the hospitals serving the most disadvantaged
#      communities, left undisclosed, would undercut the central claim.
#
#   2. Is its missingness predicted by FULLY OBSERVED covariates?  -> the
#      evidence behind treating it as missing at random given those covariates,
#      the working assumption under which Task 2.7 imputes (plan-amendments.md
#      §3.1, admission-gates.md C2.e as amended). The regression shows that
#      missingness depends on observed covariates; it cannot show that it does
#      not also depend on the unseen values, so MAR stays an assumption (Task
#      S3.1 shifts the imputed values to see how much it matters).
#
# Task S3.1: `missing_predicted` is renamed `missing_predicted`, and `disposition`
# now records what the analysis actually does with each variable. Before, it
# read "MI" for all eight substantive variables, but only contract labor is
# imputed: the components are analyzed at their own coverage, three covariates
# are complete-case, and system membership is not in any model.
#
# The fully-observed predictor set is the Impact File structural fields, all
# >= 99.9% observed for the frame: log(beds), rurality, ownership, teaching,
# wage index, log(Medicare volume), case mix, DSH %, occupancy.
#
# Output: output/tables/missingness-audit.csv, output/figures/missingness-audit.png,
# and the written interpretation in provenance/task2.6-missingness.md.
#
# Base R. Reads data/outcomes.rds (2.2), data/blockA.rds (2.3), data/blockB.rds
# (2.5), data/blockC_contract_labor.csv (1.6).

rd  <- function(p) read.csv(p, colClasses = "character", check.names = FALSE, na.strings = character(0))
n_  <- function(x) suppressWarnings(as.numeric(x))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

## standardized difference of x between the PRESENT group and the ABSENT group.
## Same estimator as admission-gates.md C2.e and R/blockA-coverage.R. Positive =
## the value is higher among hospitals that HAVE the variable.
smd <- function(x, present) {
  a <- x[present & !is.na(x)]; b <- x[!present & !is.na(x)]
  if (length(a) < 3 || length(b) < 3) return(NA_real_)
  (mean(a) - mean(b)) / sqrt((var(a) + var(b)) / 2)
}

# ==========================================================================
hdr("TASK 2.6  the missingness audit")

o <- readRDS(file.path("data", "outcomes.rds"))
a <- readRDS(file.path("data", "blockA.rds"))
b <- readRDS(file.path("data", "blockB.rds"))
cl <- rd(file.path("data", "blockC_contract_labor.csv"))
frame <- o$ccn
stopifnot(setequal(frame, a$ccn), setequal(frame, b$ccn))
a  <- a[match(frame, a$ccn), ]; b <- b[match(frame, b$ccn), ]
cl <- cl[match(frame, cl$ccn), ]
N <- length(frame)
cat(sprintf("  frame n = %d\n", N))

## ---- the fully-observed predictor frame (Impact File structural fields) ----
P <- data.frame(
  log_beds   = log(n_(a$beds)),
  rural      = as.numeric(a$urban_rural == "RURAL"),
  own_govt   = as.numeric(a$ownership_code == "G"),
  own_fp     = as.numeric(a$ownership_code == "P"),
  teaching   = as.numeric(a$teaching),
  wage_index = n_(a$wage_index),
  log_vol    = log(n_(a$volume_bills)),
  cmi        = n_(a$cmi),
  dsh_pct    = n_(a$dsh_pct),
  occupancy  = n_(a$occupancy))
pred_ok <- stats::complete.cases(P)
cat(sprintf("  fully-observed predictor set complete for %d / %d hospitals (%s)\n",
            sum(pred_ok), N, pct(mean(pred_ok))))

## disadvantage measures, base-case grain
DIS <- data.frame(
  adi        = n_(b$adi_catch_tract),
  svi_ses    = n_(b$svi1_catch_tract),
  ice        = -n_(b$ice_catch_tract),           # sign so that "higher = more deprived"
  uninsured  = n_(b$uninsured_catch_tract))

# ==========================================================================
# the variable inventory
# ==========================================================================
V <- list(
  # outcome layer
  list(block = "outcome",  name = "psi90",              x = n_(o$psi90)),
  list(block = "outcome",  name = "psi03",              x = n_(o$psi03)),
  list(block = "outcome",  name = "psi06",              x = n_(o$psi06)),
  list(block = "outcome",  name = "psi12",              x = n_(o$psi12)),
  list(block = "outcome",  name = "psi13",              x = n_(o$psi13)),
  list(block = "outcome",  name = "lambda_i",           x = n_(o$lambda_i)),
  # Block A
  list(block = "blockA",   name = "beds",               x = n_(a$beds)),
  list(block = "blockA",   name = "occupancy",          x = n_(a$occupancy)),
  list(block = "blockA",   name = "resident_to_bed",    x = n_(a$resident_to_bed)),
  list(block = "blockA",   name = "dsh_pct",            x = n_(a$dsh_pct)),
  list(block = "blockA",   name = "wage_index",         x = n_(a$wage_index)),
  list(block = "blockA",   name = "cmi",                x = n_(a$cmi)),
  list(block = "blockA",   name = "volume_bills",       x = n_(a$volume_bills)),
  list(block = "blockA",   name = "ownership",          x = ifelse(is.na(a$ownership), NA, 1)),
  list(block = "blockA",   name = "operating_margin",   x = n_(a$operating_margin)),
  list(block = "blockA",   name = "uncompensated_care", x = n_(a$uncompensated_care)),
  list(block = "blockA",   name = "system_member",      x = ifelse(a$has_owner_record, 1, NA)),
  # Block B (base case: _catch_tract)
  list(block = "blockB",   name = "svi1_catch_tract",   x = n_(b$svi1_catch_tract)),
  list(block = "blockB",   name = "svi2_catch_tract",   x = n_(b$svi2_catch_tract)),
  list(block = "blockB",   name = "svi3_catch_tract",   x = n_(b$svi3_catch_tract)),
  list(block = "blockB",   name = "svi4_catch_tract",   x = n_(b$svi4_catch_tract)),
  list(block = "blockB",   name = "uninsured_catch_tract", x = n_(b$uninsured_catch_tract)),
  list(block = "blockB",   name = "limeng_catch_tract", x = n_(b$limeng_catch_tract)),
  list(block = "blockB",   name = "ice_catch_tract",    x = n_(b$ice_catch_tract)),
  list(block = "blockB",   name = "adi_catch_tract",    x = n_(b$adi_catch_tract)),
  list(block = "blockB",   name = "adi2020_catch_tract",x = n_(b$adi2020_catch_tract)),
  list(block = "blockB",   name = "rurality_catch_tract", x = n_(b$rurality_catch_tract)),
  list(block = "blockB",   name = "pcp_density_catch_tract", x = n_(b$pcp_density_catch_tract)),
  list(block = "blockB",   name = "hhi_zip",            x = n_(b$hhi_zip)),
  # Block C candidate
  list(block = "blockC",   name = "contract_labor_share", x = n_(cl$contract_labor_share))
)

# ==========================================================================
# the audit
# ==========================================================================
## what the analysis does with each substantive variable (Task S3.1)
TREAT <- list(
  psi03 = "not imputed: component outcome, suppressed when cases are too few; analyzed at its own coverage",
  psi12 = "not imputed: component outcome, suppressed when cases are too few; analyzed at its own coverage",
  psi13 = "not imputed: component outcome, suppressed or no eligible cases; analyzed at its own coverage",
  contract_labor_share = "multiple imputation (PMM, m = 20) in the MI arm, under a MAR working assumption; complete-case and omit arms beside it",
  operating_margin = "complete-case: left out of any model that uses it (undefined when net patient revenue < $1M)",
  uncompensated_care = "complete-case: left out of any model that uses it",
  hhi_zip = "complete-case: left out of any model that uses it",
  system_member = "not in any model")

audit <- do.call(rbind, lapply(V, function(v) {
  miss <- is.na(v$x)
  nm <- sum(miss)
  row <- data.frame(block = v$block, variable = v$name, n = N - nm,
                    n_missing = nm, pct_missing = 100 * mean(miss),
                    smd_log_beds = NA_real_, smd_rural = NA_real_, smd_dsh = NA_real_,
                    smd_forprofit = NA_real_,
                    smd_adi = NA_real_, smd_svi_ses = NA_real_, smd_ice_deprived = NA_real_,
                    smd_uninsured = NA_real_,
                    disadvantage_differential = NA, mar_lr_p = NA_real_,
                    mar_pseudo_r2 = NA_real_, missing_predicted = NA,
                    disposition = "complete, no missingness", stringsAsFactors = FALSE)
  if (nm == 0) return(row)

  present <- !miss
  row$smd_log_beds  <- smd(P$log_beds,  present)
  row$smd_rural     <- smd(P$rural,     present)
  row$smd_dsh       <- smd(P$dsh_pct,   present)
  row$smd_forprofit <- smd(P$own_fp,    present)
  row$smd_adi          <- smd(DIS$adi,       present)
  row$smd_svi_ses      <- smd(DIS$svi_ses,   present)
  row$smd_ice_deprived <- smd(DIS$ice,       present)
  row$smd_uninsured    <- smd(DIS$uninsured, present)
  row$disadvantage_differential <-
    any(abs(c(row$smd_adi, row$smd_svi_ses, row$smd_ice_deprived, row$smd_uninsured)) > 0.10, na.rm = TRUE)

  ## MAR-plausibility: logistic missing ~ fully-observed covariates
  if (nm >= 10) {
    d <- data.frame(miss = as.integer(miss), P)[pred_ok, ]
    m1 <- tryCatch(suppressWarnings(
                     stats::glm(miss ~ log_beds + rural + own_govt + own_fp + teaching +
                                wage_index + log_vol + cmi + dsh_pct + occupancy,
                                data = d, family = "binomial")),
                   error = function(e) NULL)
    if (!is.null(m1)) {
      m0 <- suppressWarnings(stats::glm(miss ~ 1, data = d, family = "binomial"))
      row$mar_lr_p       <- stats::pchisq(m0$deviance - m1$deviance,
                                          df = m1$df.null - m1$df.residual, lower.tail = FALSE)
      row$mar_pseudo_r2  <- 1 - m1$deviance / m0$deviance
      row$missing_predicted   <- row$mar_lr_p < 0.05
    }
  } else {
    row$missing_predicted <- NA          # too few to model; handled as negligible below
  }

  row$disposition <-
    if (!is.null(TREAT[[v$name]]))               TREAT[[v$name]]
    else if (nm / N < 0.005)                     "complete-case, negligible (<0.5%)"
    else                                         "complete-case"
  row
}))
write.csv(audit, file.path("output", "tables", "missingness-audit.csv"), row.names = FALSE)

sub_("missingness by variable")
cat(sprintf("  %-24s %6s %8s   %8s %8s %8s   %7s %7s   %s\n",
            "variable", "n_miss", "pct", "SMD beds", "SMD rur", "SMD ADI", "LR p", "psR2", "disposition"))
for (i in which(audit$n_missing > 0)) {
  r <- audit[i, ]
  cat(sprintf("  %-24s %6d %7s   %+8.3f %+8.3f %+8.3f   %7s %7s   %s\n",
              r$variable, r$n_missing, pct(r$pct_missing / 100),
              r$smd_log_beds, r$smd_rural, r$smd_adi,
              ifelse(is.na(r$mar_lr_p), "-", format.pval(r$mar_lr_p, digits = 2, eps = 1e-4)),
              ifelse(is.na(r$mar_pseudo_r2), "-", sprintf("%.3f", r$mar_pseudo_r2)),
              r$disposition))
}
cat(sprintf("\n  %d of %d audited variables carry missingness; %d are fully observed.\n",
            sum(audit$n_missing > 0), nrow(audit), sum(audit$n_missing == 0)))

# ==========================================================================
# the two questions, answered explicitly (the verify condition)
# ==========================================================================
q1  <- audit[audit$n_missing > 0, ]
sub <- q1[q1$pct_missing >= 0.5, ]           # the substantive-missingness variables
neg <- q1[q1$pct_missing <  0.5, ]

sub_("Q1  does missingness correlate with disadvantage?  (-> report Limitations)")
for (i in seq_len(nrow(sub))) {
  r <- sub[i, ]
  dsmd <- c(ADI = r$smd_adi, `SVI-SES` = r$smd_svi_ses, `ICE(deprived)` = r$smd_ice_deprived,
            uninsured = r$smd_uninsured)
  if (all(is.na(dsmd))) { cat(sprintf("  %-24s n/a\n", r$variable)); next }
  worst <- names(dsmd)[which.max(abs(dsmd))]
  cat(sprintf("  %-24s %s   (largest: %s SMD %+.3f%s)\n", r$variable,
              if (isTRUE(r$disadvantage_differential)) "YES -- differential" else "no  -- balanced",
              worst, dsmd[worst], if (abs(dsmd[[worst]]) > 0.10) "" else "  < 0.10"))
}
cat(sprintf("  %d negligible-missingness variables (<0.5%%): %s -- complete-case\n",
            nrow(neg), paste(neg$variable, collapse = ", ")))

## Task S2.3: a predicted-missingness regression supports MAR as a working
## assumption; it cannot establish it (missingness may still depend on the
## unseen values). Task S3.1: the printout names each variable's actual
## treatment instead of implying that all eight are imputed
sub_("Q2  is missingness predicted by fully observed covariates?  (consistent with MAR; cannot establish it)")
for (i in seq_len(nrow(sub))) {
  r <- sub[i, ]
  cat(sprintf("  %-24s %s\n", r$variable,
              if (is.na(r$missing_predicted)) "n/a -- too few to model"
              else if (r$missing_predicted) sprintf("YES  (LR p %s, pseudo-R2 %.3f)\n  %-24s   treatment: %s",
                                               format.pval(r$mar_lr_p, digits = 2, eps = 1e-4), r$mar_pseudo_r2,
                                               "", r$disposition)
              else sprintf("NO   (LR p %.2f)\n  %-24s   treatment: %s", r$mar_lr_p, "", r$disposition)))
}

not_predicted <- sub$variable[!is.na(sub$missing_predicted) & !sub$missing_predicted]
if (length(not_predicted)) {
  cat(sprintf("\n  missingness not predicted by observed covariates for: %s\n",
              paste(not_predicted, collapse = ", ")))
} else {
  cat("\n  Missingness is predicted by observed covariates for every modellable variable.\n")
  cat("  That is consistent with MAR and cannot establish it. Only contract labor is\n")
  cat("  imputed (stage 18, MAR as a working assumption; stage 43 shifts the imputed values).\n")
}

## reproduce the Phase 0 contract-labour figure for continuity
cl_row <- audit[audit$variable == "contract_labor_share", ]
cat(sprintf("\n  contract labour (now %s missing, post-recovery): SMD beds %+.3f, rural %+.3f\n",
            pct(cl_row$pct_missing / 100), cl_row$smd_log_beds, cl_row$smd_rural))
cat("  Phase 0 measured this PRE-recovery (9.2%% missing): beds +0.462, rural -0.269 (admission-gates.md C2.e).\n")
cat("  Deterministic recovery at Task 1.6 (raw S-3 + FY2022) removed the recoverable part;\n")
cat("  the audit above is the state MI actually operates on.\n")

# ==========================================================================
# the figure
# ==========================================================================
fig <- q1[order(-q1$pct_missing), ]
fig <- fig[fig$pct_missing >= 0.3, ]      # variables worth plotting
png(file.path("output", "figures", "missingness-audit.png"), width = 1100, height = 780, res = 130)
par(mfrow = c(1, 2), mar = c(4.5, 9, 3.5, 1), mgp = c(2.3, 0.7, 0))

## left: missingness rate
bp <- barplot(rev(fig$pct_missing), horiz = TRUE, names.arg = rev(fig$variable), las = 1,
              col = ifelse(rev(fig$disadvantage_differential), "#c2703d", "#6b8fb3"),
              border = NA, xlab = "% of frame missing", cex.names = 0.78,
              main = "Missingness rate")
text(rev(fig$pct_missing), bp, sprintf(" %.1f%%", rev(fig$pct_missing)), pos = 4, cex = 0.7, xpd = NA)
legend("bottomright", c("differential w/ disadvantage", "balanced"),
       fill = c("#c2703d", "#6b8fb3"), border = NA, bty = "n", cex = 0.72)

## right: standardized-difference forest (present - absent)
par(mar = c(4.5, 0.5, 3.5, 1))
yy <- seq_len(nrow(fig))
xr <- range(c(-0.6, 0.6, fig$smd_log_beds, fig$smd_rural, fig$smd_adi), na.rm = TRUE)
plot(NA, xlim = xr, ylim = c(0.5, nrow(fig) + 0.5), yaxt = "n", ylab = "", yaxs = "i",
     xlab = "standardized difference  (present - absent)", main = "Who is missing?")
rect(-0.10, 0.5, 0.10, nrow(fig) + 0.5, col = "#00000010", border = NA)
abline(v = 0, col = "#00000055"); abline(v = c(-0.1, 0.1), col = "#00000030", lty = 3)
for (j in rev(yy)) {
  r <- fig[nrow(fig) - j + 1, ]
  points(r$smd_log_beds, j, pch = 19, col = "#2b6cb0", cex = 1.1)
  points(r$smd_rural,    j, pch = 17, col = "#c05621", cex = 1.1)
  points(r$smd_adi,      j, pch = 15, col = "#2f855a", cex = 1.1)
}
legend("topright", c("log(beds)", "rural indicator", "ADI (disadvantage)"),
       pch = c(19, 17, 15), col = c("#2b6cb0", "#c05621", "#2f855a"), bty = "n", cex = 0.72)
mtext("Task 2.6 missingness audit  -  shaded band = |SMD| < 0.10 balance threshold",
      side = 1, line = 3.2, outer = TRUE, cex = 0.68, adj = 0.02)
dev.off()
cat(sprintf("\n  figure -> output/figures/missingness-audit.png  (%d variables)\n", nrow(fig)))

# ==========================================================================
sub_("verify")
cat(sprintf("  Q1 (disadvantage differential) answered for all %d variables with missingness; %d differential\n",
            nrow(q1), sum(q1$disadvantage_differential, na.rm = TRUE)))
cat(sprintf("  Q2 (MAR plausibility) answered for all %d substantive (>=0.5%%) variables:\n", nrow(sub)))
cat(sprintf("     missingness predicted %d   not predicted %d   too few to model %d\n",
            sum(sub$missing_predicted, na.rm = TRUE),
            sum(!sub$missing_predicted, na.rm = TRUE),
            sum(is.na(sub$missing_predicted))))
cat(sprintf("  %d negligible-missingness variables -> complete-case; %d fully observed\n",
            nrow(neg), sum(audit$n_missing == 0)))
stopifnot(nrow(audit) == length(V), !any(is.na(audit$disposition)),
          all(!is.na(sub$missing_predicted) | sub$n_missing < 10))

hdr("done")
