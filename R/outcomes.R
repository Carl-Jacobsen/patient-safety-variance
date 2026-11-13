# R/outcomes.R  --  Task 2.2, the outcome table
#
# Hospital-level PSI-90 and its four in-scope components (PSI-03, -06, -12, -13),
# for the 2,801-hospital frame, with:
#
#   * the composite from the SIX-DECIMAL file (gate O1.e), the CI and every
#     denominator from the provider file -- the two are complementary, not
#     redundant (spike-outcome.md §3b)
#   * footnote codes parsed as a LIST and kept mechanism-distinct: 1 / 5 / 7 /
#     13 / 19 / 23 / 29 never collapsed, code 7 (structural zero) never merged
#     with code 1 (volume suppression) -- gate O1.c
#   * the reliability quantities that stand in for the absent O/E split
#     (spike-outcome.md §5, plan-amendments.md §1): v_i the implied posterior
#     variance, tau2 the implied prior variance, lambda_i the share of a
#     hospital's true deviation that survives CMS smoothing. Reproduced from
#     stage 1b (phase0-followup.R): tau2 = 0.07744, median lambda = 0.462,
#     0.205 in the lowest volume quartile.
#   * the HACRP composite carried only as `psi90_hacrp` for the Phase 4 payment
#     anchor; the two official PSI-90 values differ (mean +0.00191, r 0.9996)
#     and that is recorded, not smoothed over -- gate O1.e
#
# Base R. Reads the permanent Task 1.2 layout plus the FY2026 Impact File
# (Medicare volume, for the reliability-by-volume quartiles) and the crosswalk
# spine from Task 2.1.

CC  <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
HAC <- file.path("data-raw", "hacrp_fy2026")
BA  <- file.path("data-raw", "blockA")

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
qtab <- function(x, label, fmt = "%.4f") {
  x <- sort(x[is.finite(x)])
  q <- quantile(x, c(.05, .25, .5, .75, .95), type = 7, names = FALSE)
  cat(sprintf("  %-34s n=%-6d min=%s p05=%s p25=%s med=%s p75=%s p95=%s max=%s\n",
              label, length(x), sprintf(fmt, x[1]), sprintf(fmt, q[1]), sprintf(fmt, q[2]),
              sprintf(fmt, q[3]), sprintf(fmt, q[4]), sprintf(fmt, q[5]), sprintf(fmt, x[length(x)])))
}

## Impact file reader -- same as R/blockA-coverage.R and R/crosswalk.R.
impact <- function(zipfile, member) {
  td <- tempfile(); dir.create(td)
  unzip(file.path(BA, zipfile), files = member, exdir = td)
  L <- readLines(file.path(td, member), encoding = "latin1", warn = FALSE)
  h <- strsplit(L[2], "\t")[[1]]
  b <- L[-(1:2)]; b <- b[nzchar(trimws(b))]
  m <- do.call(rbind, lapply(strsplit(b, "\t", fixed = TRUE),
                             function(v) { length(v) <- length(h); v }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- h
  d$ccn <- formatC(trimws(d$`Provider Number`), width = 6, flag = "0")
  d
}

## footnote string -> logical: does this row carry code `k`?  Footnotes are
## comma-concatenated multi-codes (spike-outcome.md §6).
has_code <- function(fn, k) vapply(strsplit(fn, ",\\s*"), function(v) k %in% trimws(v), logical(1))

COMPS <- c("PSI_03", "PSI_06", "PSI_12", "PSI_13")
CODES <- c(too_few = "1", not_available = "5", structural_zero = "7",
           not_calculable = "13", out_of_frame = "19", claims_discrepancy = "23",
           partial_window = "29")

# ==========================================================================
hdr("TASK 2.2  the outcome table")

cd  <- rd(file.path(CC,  "Complications_and_Deaths-Hospital.csv"))
s6  <- rd(file.path(CC,  "CMS_PSI_6_decimal_file.csv"))
hg  <- rd(file.path(CC,  "Hospital_General_Information.csv"))
fnc <- rd(file.path(CC,  "Footnote_Crosswalk.csv"))
md  <- rd(file.path(CC,  "Measure_Dates.csv"))
hac <- rd(file.path(HAC, "FY_2026_HAC_Reduction_Program_Hospital.csv"))
i26 <- impact("fy2026-ipps-fr-impact-file.zip", "FY 2026 IPPS Final Rule Impact File.txt")

## ---- the spine ---------------------------------------------------------
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame)
cat(sprintf("  frame n = %d\n", N))

cw <- readRDS(file.path("data", "crosswalk.rds"))
stopifnot(setequal(frame, cw$ccn))
cat("  crosswalk spine (Task 2.1): every frame CCN present, no extras\n")

## reporting window, triangulated (spike-outcome.md §1): provider file, the
## six-decimal file, and Measure_Dates all state the same PSI-90 window.
w_prov <- unique(paste(p90$`Start Date`, p90$`End Date`))
w_md   <- md[md$`Measure ID` == "PSI_90", c("Start Date", "End Date")]
cat(sprintf("  PSI-90 window: %s  (Measure_Dates: %s .. %s)\n",
            w_prov[1], w_md$`Start Date`, w_md$`End Date`))
MEAS_START <- "2022-07-01"; MEAS_END <- "2024-06-30"

# ==========================================================================
# 1. PSI-90 composite
# ==========================================================================
sub_("PSI-90 -- six-decimal Rate (outcome), provider-file Score + CI")
r6  <- s6[s6$`Measure ID` == "PSI_90", ]
P   <- p90[match(frame, p90$`Facility ID`), ]
rate6 <- setNames(n_(r6$Rate), r6$`Facility ID`)[frame]

out <- data.frame(ccn = frame, stringsAsFactors = FALSE)
out$psi90            <- unname(rate6)                       # six-decimal, THE outcome
out$psi90_2dp        <- n_(P$Score)                         # provider file, basis of the CI
out$psi90_lower      <- n_(P$`Lower Estimate`)
out$psi90_upper      <- n_(P$`Higher Estimate`)
out$psi90_ci_width   <- out$psi90_upper - out$psi90_lower
out$psi90_denominator <- NA_real_                           # published "Not Applicable"
out$psi90_compared_national <- trimws(P$`Compared to National`)
out$psi90_footnote   <- trimws(P$Footnote)

cat(sprintf("  numeric six-decimal Rate   %d / %d\n", sum(!is.na(out$psi90)), N))
cat(sprintf("  numeric 2-dp Score         %d / %d   (identical quantity, 2 dp)\n",
            sum(!is.na(out$psi90_2dp)), N))
cat(sprintf("  numeric CI (both bounds)   %d / %d\n",
            sum(!is.na(out$psi90_lower) & !is.na(out$psi90_upper)), N))
cat(sprintf("  Denominator                all 'Not Applicable' for the composite -> NA\n"))
d62 <- out$psi90 - out$psi90_2dp
cat(sprintf("  six-decimal vs 2-dp Score  max |diff| %.5f  (rounding only; %d agree at 2 dp)\n",
            max(abs(d62), na.rm = TRUE), sum(abs(d62) < 5e-3, na.rm = TRUE)))

## ---- footnotes: parse as a list, keep the seven codes distinct (O1.c) ----
sub_("footnote codes on PSI-90 -- parsed as a list, kept mechanism-distinct")
for (nm in names(CODES)) out[[paste0("fn_", nm)]] <- has_code(out$psi90_footnote, CODES[[nm]])
seen <- sort(unique(unlist(strsplit(out$psi90_footnote[nzchar(out$psi90_footnote)], ",\\s*"))))
for (k in seen)
  cat(sprintf("  code %-3s  n=%-4d  %s\n", k, sum(has_code(out$psi90_footnote, k)),
              fnc$`Footnote Text`[match(k, fnc$Footnote)]))
multi <- grepl(",", out$psi90_footnote)
cat(sprintf("  rows carrying more than one code: %d\n", sum(multi)))
n_collapsed <- sum(out$fn_structural_zero & out$fn_too_few)
cat(sprintf("\n  GATE O1.c  code 7 never collapsed with code 1: %d collapsed  ->  %s\n",
            n_collapsed, if (n_collapsed == 0) "PASS" else "FAIL"))
cat(sprintf("  GATE O1.c  all seven codes representable and distinct: %s\n",
            if (all(paste0("fn_", names(CODES)) %in% names(out))) "PASS" else "FAIL"))

# ==========================================================================
# 2. Components -- six-decimal Rate, provider-file Denominator + CI
# ==========================================================================
sub_("components PSI-03 / -06 / -12 / -13 -- rate, denominator, CI, footnote")
for (m in COMPS) {
  tag <- tolower(sub("PSI_", "psi", m))
  cm  <- cd[cd$`Measure ID` == m, ]
  s6m <- s6[s6$`Measure ID` == m, ]
  out[[tag]]            <- setNames(n_(s6m$Rate), s6m$`Facility ID`)[frame]           # six-decimal rate
  out[[paste0(tag, "_2dp")]]   <- setNames(n_(cm$Score), cm$`Facility ID`)[frame]
  out[[paste0(tag, "_denom")]] <- setNames(n_(cm$Denominator), cm$`Facility ID`)[frame] # at-risk pop
  out[[paste0(tag, "_lower")]] <- setNames(n_(cm$`Lower Estimate`), cm$`Facility ID`)[frame]
  out[[paste0(tag, "_upper")]] <- setNames(n_(cm$`Higher Estimate`), cm$`Facility ID`)[frame]
  out[[paste0(tag, "_footnote")]] <- setNames(trimws(cm$Footnote), cm$`Facility ID`)[frame]
  cat(sprintf("  %-7s rate %4d (%s)   denom %4d   footnote codes: %s\n",
              m, sum(!is.na(out[[tag]])), pct(mean(!is.na(out[[tag]]))),
              sum(!is.na(out[[paste0(tag, "_denom")]])),
              paste(sort(unique(unlist(strsplit(out[[paste0(tag, "_footnote")]][nzchar(out[[paste0(tag, "_footnote")]])], ",\\s*")))), collapse = " ")))
}
allfour <- rowSums(!is.na(out[, tolower(sub("PSI_", "psi", COMPS))])) == 4L
cat(sprintf("\n  GATE O1.d  component n's stated individually AND jointly: %d..%d individual, %d joint\n",
            min(colSums(!is.na(out[, tolower(sub("PSI_", "psi", COMPS))]))),
            max(colSums(!is.na(out[, tolower(sub("PSI_", "psi", COMPS))]))), sum(allfour)))

# ==========================================================================
# 3. Reliability -- the empirical-Bayes shrinkage (stands in for the O/E split)
# ==========================================================================
## Reproduces stage 1b (phase0-followup.R) exactly: tau2 is identified on the
## hospitals that have a published CI AND a positive FY2026 Medicare volume and
## bed count; lambda_i = 1 - v_i/tau2 is then applied to every hospital with a
## CI. v_i = ((upper - lower)/2/1.96)^2.
sub_("empirical-Bayes shrinkage -- v_i, tau2, lambda_i")

I26 <- i26[match(frame, i26$ccn), ]
bills <- n_(I26$Bills)                       # Medicare volume, FY2026 Impact File
beds  <- n_(I26$Beds)
out$volume_bills_fy2026 <- bills

out$v_i <- (out$psi90_ci_width / 2 / 1.96)^2

est <- !is.na(out$psi90_2dp) & !is.na(out$v_i) & !is.na(bills) & !is.na(beds) & bills > 0 & beds > 0
varpub <- mean((out$psi90_2dp[est] - mean(out$psi90_2dp[est]))^2)   # population variance of the PUBLISHED value
tau2   <- varpub + mean(out$v_i[est])
out$tau2 <- tau2
out$lambda_i <- 1 - out$v_i / tau2
out$lambda_in_tau2_sample <- est

cat(sprintf("  hospitals identifying tau2 (CI + FY2026 volume + beds): %d\n", sum(est)))
cat(sprintf("  Var(published PSI-90, 2 dp)      = %.5f\n", varpub))
cat(sprintf("  mean implied posterior variance  = %.5f\n", mean(out$v_i[est])))
cat(sprintf("  => implied prior variance tau^2   = %.5f   (tau = %.4f)\n", tau2, sqrt(tau2)))
qtab(out$lambda_i[est], "lambda = 1 - v/tau2", "%.3f")
cat(sprintf("  mean lambda = %.3f\n", mean(out$lambda_i[est])))

## the diagnostic in its own right (plan-amendments.md §1.2)
cat(sprintf("  within-hospital mean variance %.5f %s between-hospital variance %.5f\n",
            mean(out$v_i[est]), if (mean(out$v_i[est]) > varpub) ">" else "<=", varpub))
cat("  (mean within > between is arithmetically impossible for unshrunk estimates --\n")
cat("   by itself proof that heavy smoothing has been applied)\n")

sub_("VERIFY against stage 1b (phase0-followup.R)")
chk <- function(label, got, want, tol) {
  ok <- abs(got - want) < tol
  cat(sprintf("  %-40s got %.5f  want %.5f  ->  %s\n", label, got, want, if (ok) "OK" else "MISMATCH"))
  ok
}
v_ok <- c(
  chk("tau2",                  tau2,                              0.07744, 5e-5),
  chk("tau",                   sqrt(tau2),                        0.2783,  5e-4),
  chk("Var(published)",        varpub,                            0.03678, 5e-5),
  chk("mean posterior variance", mean(out$v_i[est]),              0.04066, 5e-5),
  chk("median lambda",         median(out$lambda_i[est]),         0.462,   5e-4),
  chk("mean lambda",           mean(out$lambda_i[est]),           0.475,   5e-4),
  chk("n identifying tau2",    sum(est),                          2799,    0.5))

# ==========================================================================
# 4. reliability by Medicare-volume quartile  (the Phase 0 quartile table)
# ==========================================================================
sub_("reliability by volume quartile -- reproduces plan-amendments.md §1.3")
dq <- out[est, ]
qb <- cut(dq$volume_bills_fy2026, quantile(dq$volume_bills_fy2026, 0:4/4),
          include.lowest = TRUE, labels = c("Q1 low", "Q2", "Q3", "Q4 high"))
rel <- do.call(rbind, lapply(levels(qb), function(l) {
  g <- qb == l
  data.frame(volume_quartile = l, n = sum(g),
             bills_min = min(dq$volume_bills_fy2026[g]),
             bills_median = median(dq$volume_bills_fy2026[g]),
             bills_max = max(dq$volume_bills_fy2026[g]),
             mean_v = mean(dq$v_i[g]),
             mean_lambda = mean(dq$lambda_i[g]),
             median_lambda = median(dq$lambda_i[g]),
             stringsAsFactors = FALSE)
}))
rel <- rbind(rel, data.frame(volume_quartile = "all", n = nrow(dq),
                             bills_min = min(dq$volume_bills_fy2026),
                             bills_median = median(dq$volume_bills_fy2026),
                             bills_max = max(dq$volume_bills_fy2026),
                             mean_v = mean(dq$v_i), mean_lambda = mean(dq$lambda_i),
                             median_lambda = median(dq$lambda_i)))
write.csv(rel, file.path("output", "tables", "reliability-by-volume.csv"), row.names = FALSE)
for (i in seq_len(nrow(rel)))
  cat(sprintf("  %-8s n=%-5d  median Medicare cases %5.0f   mean lambda %.3f   median lambda %.3f\n",
              rel$volume_quartile[i], rel$n[i], rel$bills_median[i], rel$mean_lambda[i], rel$median_lambda[i]))

q_want <- c("Q1 low" = 0.205, "Q2" = 0.381, "Q3" = 0.559, "Q4 high" = 0.755)
q_got  <- setNames(rel$mean_lambda[match(names(q_want), rel$volume_quartile)], names(q_want))
q_ok   <- all(abs(q_got - q_want) < 5e-4)
cat(sprintf("\n  VERIFY quartile mean lambda vs Phase 0: %s\n",
            if (q_ok) "OK" else paste("MISMATCH", paste(sprintf("%s %.3f", names(q_got), q_got), collapse = " "))))

## rurality split (printed, not tabled -- the quartile table is the deliverable)
rural <- I26$URGEO == "RURAL"
cat(sprintf("  mean lambda  rural %.3f (n=%d)   non-rural %.3f (n=%d)\n",
            mean(out$lambda_i[est & rural]), sum(est & rural),
            mean(out$lambda_i[est & !rural]), sum(est & !rural)))

# ==========================================================================
# 5. HACRP -- Phase 4 payment anchor only; record that the two values differ
# ==========================================================================
sub_("HACRP composite -- reserved for Phase 4; the two official values differ (O1.e)")
hi <- match(frame, hac$`Facility ID`)
out$psi90_hacrp            <- n_(hac$`PSI 90 Composite Value`)[hi]
out$psi90_hacrp_wz         <- n_(hac$`PSI 90 W Z Score`)[hi]
out$hacrp_total_hac_score  <- n_(hac$`Total HAC Score`)[hi]
out$hacrp_payment_reduction<- trimws(hac$`Payment Reduction`)[hi]

k <- !is.na(out$psi90) & !is.na(out$psi90_hacrp)
dif <- out$psi90_hacrp[k] - out$psi90[k]
cat(sprintf("  paired hospitals (both official PSI-90 present) : %d\n", sum(k)))
cat(sprintf("  Pearson r                                       : %.6f\n", cor(out$psi90_hacrp[k], out$psi90[k])))
cat(sprintf("  mean difference (HACRP - Care Compare)          : %+.6f\n", mean(dif)))
cat(sprintf("  SD / 99th pct |diff| / max |diff|               : %.6f / %.6f / %.6f\n",
            sd(dif), quantile(abs(dif), .99, names = FALSE), max(abs(dif))))
cat(sprintf("  exact agreement to 5 dp                         : %d of %d\n", sum(abs(dif) < 5e-5), sum(k)))
cat("  Payment Reduction (frame): "); print(table(out$hacrp_payment_reduction, useNA = "ifany"))
e_ok <- abs(mean(dif) - 0.00191) < 5e-5 && abs(cor(out$psi90_hacrp[k], out$psi90[k]) - 0.9996) < 5e-4
cat(sprintf("  GATE O1.e  outcome = six-decimal file; HACRP reserved; both values stated & differ -> %s\n",
            if (e_ok) "PASS" else "CHECK"))

# ==========================================================================
# 6. measure metadata ("measure version")
# ==========================================================================
out$measure_start <- MEAS_START
out$measure_end   <- MEAS_END
out$measure_period <- "2022Q3-2024Q2"
## The CMS PSI software version for FY2026 is not resolved in public sources
## (spike-outcome.md §9.1; FY2025 used v13.0, the FY2026 fact sheet names no
## version). It does not block: the published values are fixed and hashed, and
## the design is a single cross-section. Carried as NA so the gap is visible.
out$psi_software_version <- NA_character_

# ==========================================================================
# 7. distributions -- must match spike-outcome.md §7 / phase0-numbers.R
# ==========================================================================
sub_("distributions, six-decimal file -- frame-restricted")
qtab(out$psi90, "PSI_90 (ratio)", "%.4f")
for (m in COMPS) qtab(out[[tolower(sub("PSI_", "psi", m))]], m, "%.4f")
cat("  spike-outcome.md §7 / phase0-numbers.R measure these on the WHOLE six-decimal\n")
cat("  file (PSI_90 n=2,908, median 0.9621); restricting to the frame shifts the\n")
cat("  median a few thousandths (0.9611) and is the correct comparand from here on.\n")

sub_("component denominators within the frame -- vs spike-outcome.md §7")
for (m in COMPS) qtab(out[[paste0(tolower(sub("PSI_", "psi", m)), "_denom")]],
                      paste(m, "denominator"), "%.0f")

# ==========================================================================
# 8. freeze the outcome table
# ==========================================================================
saveRDS(out, file.path("data", "outcomes.rds"))
sub_("data/outcomes.rds")
cat(sprintf("  %d rows, %d columns\n", nrow(out), ncol(out)))
cat("  columns: ", paste(names(out), collapse = ", "), "\n")

sub_("gate summary")
gates <- c(
  "O1.c  footnote codes distinct, 7 != 1"       = (n_collapsed == 0),
  "O1.d  component n's individual and joint"    = TRUE,
  "O1.e  six-decimal outcome, HACRP reserved"   = e_ok,
  "reliability reproduces stage 1b"             = all(v_ok),
  "lambda quartile table reproduces Phase 0"    = q_ok)
for (nm in names(gates)) cat(sprintf("  %-44s %s\n", nm, if (gates[[nm]]) "PASS" else "FAIL"))
if (!all(unlist(gates))) stop("Task 2.2 verification failed -- see above")

hdr("done")
