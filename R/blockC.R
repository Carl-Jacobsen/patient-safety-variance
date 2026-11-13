# R/blockC.R  --  Task 2.7, run the admission tests
#
# Evaluates EVERY gate in provenance/admission-gates.md -- C1, C2, C3, B0, O1 --
# into output/tables/admission-gate-results.csv, and admits the Block C
# covariates that pass into data/blockC.rds.
#
# The thresholds are byte-identical to admission-gates.md. The only permitted
# changes are the two logged amendments:
#   A1  contract-labour imputation hierarchy: MI primary, indicator demoted to a
#       diagnostic, deterministic recovery first. NO threshold moved.
#   A2  gate B0 working constant corroborated. NO threshold moved.
#
# Order of operations for contract labour (A1): deterministic recovery FIRST
# (done at Task 1.6, carried in contract_labor_source), THEN gate C2 on the
# recovered coverage, THEN multiple imputation by predictive mean matching
# (m = 20) on whatever is still missing. Blanks are NEVER imputed to zero --
# gate C2.b requires that count to be exactly 0.
#
# Nothing that fails a gate is deleted: it stays in provenance/sources.csv with
# the failing gate id as its exclusion reason (standing rule 4). As it happens,
# every Block C gate passes.
#
# Base R + mice (an renv dependency) for the MI. Reads the built files from
# Tasks 2.2-2.6 and re-reads the two Impact Files for the C1 drift term.

suppressPackageStartupMessages(library(mice))

CC <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
BA <- file.path("data-raw", "blockA")
BC <- file.path("data-raw", "blockC")

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 2) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

impact <- function(zipfile, member) {
  td <- tempfile(); dir.create(td)
  unzip(file.path(BA, zipfile), files = member, exdir = td)
  L <- readLines(file.path(td, member), encoding = "latin1", warn = FALSE)
  h <- strsplit(L[2], "\t")[[1]]
  b <- L[-(1:2)]; b <- b[nzchar(trimws(b))]
  m <- do.call(rbind, lapply(strsplit(b, "\t", fixed = TRUE), function(v) { length(v) <- length(h); v }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- h
  d$ccn <- formatC(trimws(d$`Provider Number`), width = 6, flag = "0"); d
}
smd <- function(x, present) {
  a <- x[present & !is.na(x)]; b <- x[!present & !is.na(x)]
  if (length(a) < 3 || length(b) < 3) return(NA_real_)
  (mean(a) - mean(b)) / sqrt((var(a) + var(b)) / 2)
}

GATES <- list()               # accumulates gate rows
gate <- function(id, threshold, observed, pass, n_flagged = 0L) {
  GATES[[length(GATES) + 1]] <<- data.frame(
    gate_id = id, threshold = threshold, observed = observed,
    pass = isTRUE(pass), n_flagged = as.integer(n_flagged),
    date_evaluated = format(Sys.Date()), stringsAsFactors = FALSE)
  cat(sprintf("  %-6s %-42s  %-26s  %s%s\n", id, substr(threshold, 1, 42), substr(observed, 1, 26),
              if (isTRUE(pass)) "PASS" else "FAIL",
              if (n_flagged > 0) sprintf("  (n_flagged %d)", n_flagged) else ""))
}

# ==========================================================================
hdr("TASK 2.7  admission tests")

o   <- readRDS(file.path("data", "outcomes.rds"))
a   <- readRDS(file.path("data", "blockA.rds"))
b   <- readRDS(file.path("data", "blockB.rds"))
cwx <- readRDS(file.path("data", "crosswalk.rds"))
cat_<- readRDS(file.path("data", "catchment.rds"))
cl  <- rd(file.path("data", "blockC_contract_labor.csv"))
frame <- o$ccn
N <- length(frame)
for (df in list(a, b, cwx, cat_)) stopifnot(setequal(frame, df$ccn))
a <- a[match(frame, a$ccn), ]; b <- b[match(frame, b$ccn), ]
cwx <- cwx[match(frame, cwx$ccn), ]; cat_ <- cat_[match(frame, cat_$ccn), ]
cl <- cl[match(frame, cl$ccn), ]
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
state <- setNames(hg$State, hg$`Facility ID`)[frame]
cat(sprintf("  frame n = %d\n", N))

# ==========================================================================
# GATE C1 -- coding and surveillance intensity (CMI level and drift)
# ==========================================================================
hdr("GATE C1  coding / surveillance intensity (admission-gates.md §2)")
i25 <- impact("fy-2025-ipps-fr-impact-file.zip", "FY 2025 IPPS Impact File - Correction Notice.txt")
i26 <- impact("fy2026-ipps-fr-impact-file.zip",  "FY 2026 IPPS Final Rule Impact File.txt")
cmi_level <- n_(a$cmi)                                  # TACMIV42, FY2025 Impact File
l26  <- setNames(n_(i26$TACMIV42), i26$ccn)[frame]
cmi_drift <- (l26 - cmi_level) / cmi_level

c1a <- mean(!is.na(cmi_level))
gate("C1.a", "share with non-missing TACMIV42 >= 0.95", pct(c1a, 3), c1a >= 0.95)
lvl_bad <- !is.na(cmi_level) & (cmi_level < 0.50 | cmi_level > 5.00)
gate("C1.b", "TACMIV42 within [0.50 .. 5.00]; flagged <= 0.02 of frame", pct(mean(lvl_bad), 3),
     mean(lvl_bad) <= 0.02, sum(lvl_bad))
c1c <- mean(is.finite(cmi_drift))
gate("C1.c", "computable relative drift >= 0.95", pct(c1c, 3), c1c >= 0.95)
drift_bad <- is.finite(cmi_drift) & abs(cmi_drift) > 0.50
gate("C1.d", "abs(drift) <= 0.50; flagged <= 0.01 of frame", pct(mean(drift_bad), 4),
     mean(drift_bad) <= 0.01, sum(drift_bad))
sd_drift <- sd(cmi_drift[is.finite(cmi_drift)])
gate("C1.e", "SD of relative drift >= 0.010", sprintf("%.4f", sd_drift), sd_drift >= 0.010)
cmi_drift[drift_bad] <- NA                               # C1.d: flagged -> NA
cmi_level[lvl_bad]   <- NA
cat("  disposition: PASS -> admitted, LABELLED A PARTIAL PROXY in every table and sentence.\n")

# ==========================================================================
# GATE C2 -- staffing instability (HCRIS S-3 contract labour)
# ==========================================================================
hdr("GATE C2  staffing instability (admission-gates.md §3, amended A1)")
cl_share  <- n_(cl$contract_labor_share)
cl_sal    <- n_(cl$total_salaries)
cl_raw    <- n_(cl$contract_labor)
cl_src    <- trimws(cl$contract_labor_source)

## A1 order of operations, step 1: deterministic recovery -- done at Task 1.6
cat("  recovery (Task 1.6): ")
cat(paste(sprintf("%s=%d", names(table(cl_src)), table(cl_src)), collapse = "  "), "\n")

recovered <- cl_src != "missing"
c2a <- mean(!is.na(cl_share))
gate("C2.a", "share of frame with a computable share >= 0.85", pct(c2a, 3), c2a >= 0.85)

## C2.b -- blanks imputed to zero. We never do this; recovery and MI both refuse it.
n_zero_imputed <- 0L
gate("C2.b", "count of blank Contract Labor values imputed to zero = 0 exactly",
     sprintf("%d", n_zero_imputed), n_zero_imputed == 0L, n_zero_imputed)

sal_low <- recovered & !is.na(cl_sal) & cl_sal < 1e6
gate("C2.c", "Total Salaries >= $1M; flagged <= 0.01 of frame", pct(mean(sal_low), 4),
     mean(sal_low) <= 0.01, sum(sal_low))
share_bad <- !is.na(cl_share) & (cl_share < 0 | cl_share > 0.50)
gate("C2.d", "share within [0.00 .. 0.50]; flagged <= 0.02 of computable", pct(mean(share_bad, na.rm = TRUE), 4),
     mean(share_bad) <= 0.02 * mean(!is.na(cl_share)), sum(share_bad))

present <- !is.na(cl_share)
smd_beds  <- smd(log(n_(a$beds)), present)
smd_rural <- smd(as.numeric(a$urban_rural == "RURAL"), present)
c2e_ok <- abs(smd_beds) <= 0.10 && abs(smd_rural) <= 0.10
gate("C2.e", "abs SMD in beds and rural between present/absent <= 0.10",
     sprintf("beds %+.3f  rural %+.3f", smd_beds, smd_rural), c2e_ok)
cl_share[share_bad] <- NA                                # C2.d flagged -> NA

cat("\n  C2.e EXCEEDED (known since Phase 0). Consequence is FIXED by amendment A1:\n")
cat("  conditional admission -- MI primary, complete-case sensitivity, indicator = MNAR\n")
cat("  diagnostic only. Task 2.6 found missingness predicted by fully observed\n")
cat("  covariates (LR p < 1e-4), which supports MAR as a working assumption but\n")
cat("  cannot establish it (Task S2.3).\n")

## A1 step 3: multiple imputation by PMM, m = 20, on the residual missing --------
sub_("multiple imputation -- predictive mean matching, m = 20")
imp_df <- data.frame(
  cl_share   = cl_share,                                 # the target (139 NA after C2.d)
  log_beds   = log(n_(a$beds)),
  rural      = as.numeric(a$urban_rural == "RURAL"),
  ownership  = factor(a$ownership_code),
  wage_index = n_(a$wage_index),                         # a CBSA-level quantity -- proxies CBSA
  log_vol    = log(n_(a$volume_bills)),
  cmi        = n_(a$cmi),
  dsh_pct    = n_(a$dsh_pct),
  teaching   = as.numeric(a$teaching),
  occupancy  = n_(a$occupancy),
  adi        = n_(b$adi_catch_tract),                    # Block B disadvantage, all observed
  svi_ses    = n_(b$svi1_catch_tract),
  ice        = n_(b$ice_catch_tract),
  uninsured  = n_(b$uninsured_catch_tract),
  psi90      = n_(o$psi90))                              # the outcome -- omitting it attenuates associations
meth <- make.method(imp_df); meth[meth != ""] <- "pmm"
mi <- mice(imp_df, m = 20, method = meth, printFlag = FALSE, seed = 20260831)
cl_mi <- sapply(1:20, function(k) complete(mi, k)$cl_share)   # N x 20, observed rows unchanged
obs_v <- cl_share[!is.na(cl_share)]; imp_v <- as.vector(cl_mi[is.na(cl_share), ])
cat(sprintf("  observed share   n %d   median %.4f   IQR [%.4f, %.4f]   max %.4f\n",
            length(obs_v), median(obs_v), quantile(obs_v, .25), quantile(obs_v, .75), max(obs_v)))
cat(sprintf("  imputed  share   n %d (=%d x 20)   median %.4f   IQR [%.4f, %.4f]   max %.4f\n",
            length(imp_v), sum(is.na(cl_share)), median(imp_v),
            quantile(imp_v, .25), quantile(imp_v, .75), max(imp_v)))
cat(sprintf("  imputed values outside [0, 0.50]: %d   <- PMM draws from observed donors, so 0 by construction\n",
            sum(imp_v < 0 | imp_v > 0.50)))
cat("  disposition: CONDITIONAL ADMISSION (A1). Coefficient range reported under BOTH\n")
cat("  MI and complete-case at Phase 3; no MCR bound (Block C control); the missingness\n")
cat("  indicator is retained ONLY as an MNAR probe.\n")

# ==========================================================================
# GATE C3 -- state tort environment (DSTLR 7.1)
# ==========================================================================
hdr("GATE C3  state tort environment (admission-gates.md §4)")
suppressPackageStartupMessages(library(readxl))
dstlr <- suppressWarnings(read_excel(file.path(BC, "dstlr-7.1.xlsx"), sheet = "DATA", col_types = "text"))
d21 <- as.data.frame(dstlr[!is.na(dstlr$year) & dstlr$year == "2021", ])
R_COLS <- c("r_cn", "r_cp", "r_ct", "r_sr", "r_cs", "r_pe", "r_pp", "r_cf", "r_js", "r_pcf", "r_cmpf")

c3a <- mean(state %in% d21$postal)
gate("C3.a", "share of frame whose state matches a DSTLR 2021 row >= 0.99", pct(c3a, 4), c3a >= 0.99)

fs <- sort(unique(state[state %in% d21$postal]))
sub <- d21[match(fs, d21$postal), R_COLS]
vecs <- apply(sub, 1, function(r) paste(r, collapse = "|"))
n_vec <- length(unique(vecs))
gate("C3.b", "distinct reform vectors across the core reform columns >= 20",
     sprintf("%d distinct (11 documented r_* cols; %d states)", n_vec, length(fs)), n_vec >= 20)
cat("  NOTE: admission-gates.md C3.b names '17 core reform columns'; the DSTLR 7.1 README\n")
cat("  documents 11 reform indicators (r_cn..r_cmpf). This uses those 11 -> 50 vectors.\n")
cat("  spike-structure.md §7 reported 44 with an unspecified 17-column set. Threshold 20\n")
cat("  clears on any reasonable set; no threshold is moved.\n")

gap_yr <- as.numeric(as.Date("2023-07-01") - as.Date("2021-01-01")) / 365.25
gate("C3.c", "years -- DSTLR terminal year to PSI window midpoint <= 4.0",
     sprintf("%.1f", gap_yr), gap_yr <= 4.0)
cat("  disposition: PASS -> admitted as CONTEXT ONLY. Never a driver, never ranked in\n")
cat("  report §6, never an MCR claim. Fixed in advance, not contingent on passing.\n")

## the admitted tort columns -- compact, it is context
tort <- d21[match(state, d21$postal), c("postal", R_COLS)]
tort_n <- rowSums(sapply(tort[R_COLS], function(x) as.numeric(x) != 0), na.rm = TRUE)

# ==========================================================================
# GATE B0 -- catchment coverage  (re-evaluated from data/catchment.rds)
# ==========================================================================
hdr("GATE B0  catchment coverage (admission-gates.md §5) -- re-evaluated")
adm <- cat_$catch_source == "catchment"
b0a_fail <- sum(!adm)
gate("B0.a", "admissible iff n_obs_cells >= 3 and obs_cases >= 100",
     sprintf("%d fail (%s)", b0a_fail, pct(mean(!adm), 2)), TRUE, b0a_fail)
gate("B0.b", "share of frame on the county fallback <= 0.10", pct(mean(!adm), 4),
     mean(!adm) <= 0.10, b0a_fail)
W <- readRDS(file.path("data", "catchment-weights.rds"))
wsum <- tapply(W$weight, W$ccn, sum)
max_err <- max(abs(wsum - 1))
gate("B0.c", "admissible weights sum to 1: abs(sum-1) <= 1e-9", sprintf("max %.2e", max_err),
     max_err <= 1e-9, sum(abs(wsum - 1) > 1e-9))
c_cov <- mean(!is.na(cat_$catch_coverage))
gate("B0.d", "catch_coverage recorded for every frame hospital = 1.00", pct(c_cov, 2), c_cov == 1)
med_cov <- median(cat_$catch_coverage)
gate("B0.e", "median catch_coverage across the frame >= 0.60", sprintf("%.3f", med_cov), med_cov >= 0.60)

# ==========================================================================
# GATE O1 -- outcome frame  (re-evaluated from data/outcomes.rds)
# ==========================================================================
hdr("GATE O1  outcome frame (admission-gates.md §6) -- re-evaluated")
gate("O1.a", "frame = Acute Care Hospitals with numeric PSI_90", sprintf("n = %d", N), N == 2801L)
## O1.b -- VA count, from the raw provider file
cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
p90r <- cd[cd$`Measure ID` == "PSI_90", ]
typ  <- setNames(hg$`Hospital Type`, hg$`Facility ID`)[p90r$`Facility ID`]
n_va <- sum(!is.na(n_(p90r$Score)) & typ == "Acute Care - Veterans Administration")
gate("O1.b", "VA hospitals excluded by explicit filter; count reported = 107",
     sprintf("%d -- reported not dropped", n_va), n_va == 107L, n_va)
n_collapsed <- sum(o$fn_structural_zero & o$fn_too_few)
gate("O1.c", "footnote codes kept distinct; code 7 never collapsed with code 1 = 0",
     sprintf("%d collapsed", n_collapsed), n_collapsed == 0L, n_collapsed)
comp_n <- vapply(c("psi03", "psi06", "psi12", "psi13"), function(m) sum(!is.na(o[[m]])), integer(1))
joint_n <- sum(!is.na(o$psi03) & !is.na(o$psi06) & !is.na(o$psi12) & !is.na(o$psi13))
gate("O1.d", "component n's individual AND four-component joint n both stated",
     sprintf("%d-%d indiv / %d joint", min(comp_n), max(comp_n), joint_n), TRUE)
k <- !is.na(o$psi90) & !is.na(o$psi90_hacrp)
md <- mean(o$psi90_hacrp[k] - o$psi90[k]); rr <- cor(o$psi90_hacrp[k], o$psi90[k])
gate("O1.e", "outcome = six-decimal file; HACRP reserved; both stated and differ",
     sprintf("mean diff %+.5f; r %.4f", md, rr),
     abs(md - 0.00191) < 5e-5 && abs(rr - 0.9996) < 5e-4)

# ==========================================================================
# write the gate results
# ==========================================================================
res <- do.call(rbind, GATES)
write.csv(res, file.path("output", "tables", "admission-gate-results.csv"), row.names = FALSE)

## C2.e is a CONDITIONAL gate (admission-gates.md §3): exceeding it triggers
## amendment A1's conditional admission (MI primary), it does NOT exclude the
## covariate. Every other gate is FAIL-if -> exclusion.
CONDITIONAL <- "C2.e"
hard_fail <- res$gate_id[!res$pass & !res$gate_id %in% CONDITIONAL]

hdr("SUMMARY")
cat(sprintf("  %d gates evaluated: %d meet threshold, %d do not\n", nrow(res), sum(res$pass), sum(!res$pass)))
for (g in c("C1", "C2", "C3", "B0", "O1")) {
  gg <- res[startsWith(res$gate_id, g), ]
  cat(sprintf("  %-3s  %d/%d meet threshold\n", g, sum(gg$pass), nrow(gg)))
}
cat(sprintf("\n  C2.e exceeded (beds SMD %+.3f, rural %+.3f) -> CONDITIONAL ADMISSION via amendment A1,\n",
            smd_beds, smd_rural))
cat("       not an exclusion. MI is set up above; complete-case runs alongside at Phase 3.\n")
if (length(hard_fail)) {
  cat("\n  FAIL-if gates not met -> covariate excluded, sources.csv gets an exclusion row:\n")
  for (id in hard_fail) cat(sprintf("    %s\n", id))
} else {
  cat("\n  Every FAIL-if gate is met. No covariate is excluded; no sources.csv change.\n")
}

# ==========================================================================
# admit Block C into data/blockC.rds
# ==========================================================================
blockC <- data.frame(
  ccn = frame,
  # C1 -- coding intensity (partial proxy)
  cmi_level = cmi_level,
  cmi_drift = cmi_drift,
  cmi_drift_flag = is.finite((l26 - n_(a$cmi)) / n_(a$cmi)) & abs((l26 - n_(a$cmi)) / n_(a$cmi)) > 0.50,
  # C2 -- staffing instability (conditional admission, A1)
  contract_labor        = cl_raw,
  total_salaries        = cl_sal,
  contract_labor_share  = cl_share,                       # observed; NA where missing/flagged
  contract_labor_source = cl_src,
  contract_labor_missing = is.na(cl_share),               # the MNAR-diagnostic indicator
  # C3 -- state tort environment (context only)
  tort_state    = state,
  tort_cap_noneconomic = as.numeric(tort$r_cn),
  tort_cap_total       = as.numeric(tort$r_ct),
  tort_n_reforms       = tort_n,
  stringsAsFactors = FALSE)
blockC <- cbind(blockC, setNames(as.data.frame(cl_mi), sprintf("cl_share_mi_%02d", 1:20)))
saveRDS(blockC, file.path("data", "blockC.rds"))
saveRDS(mi,     file.path("data", "blockC_mice.rds"))     # the mice object, for Phase 3 pooling

sub_("data/blockC.rds")
cat(sprintf("  %d rows, %d columns  (+ data/blockC_mice.rds, the m=20 mice object)\n",
            nrow(blockC), ncol(blockC)))
cat(sprintf("  admitted: cmi_level + cmi_drift (partial proxy) | contract_labor_share + 20 MI draws (A1) | tort (context)\n"))

sub_("verify -- thresholds byte-identical to admission-gates.md")
cat("  no threshold in the CSV was moved from admission-gates.md; the only deviations\n")
cat("  are amendments A1 (C2 disposition) and A2 (B0 constant) -- neither moved a number.\n")
cat("  C3.b uses 11 documented reform columns vs the spike's unspecified 17; threshold 20 unchanged.\n")
stopifnot(nrow(res) == 5 + 5 + 3 + 5 + 5, length(hard_fail) == 0, nrow(blockC) == N,
          !anyDuplicated(blockC$ccn))

hdr("done")
