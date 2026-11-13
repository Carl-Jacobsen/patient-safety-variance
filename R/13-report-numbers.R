# R/13-report-numbers.R  --  standing rule 1, enforced on the report text.
#
# make.R stage 39. "If a number appears in prose, make.R produced it." This
# stage makes that checkable. For each drafted report section it computes
# every number the section cites, from the data products and stage outputs
# that earlier stages wrote, into a registry (output/tables/report-numbers.csv:
# section, key, value, the text(s) the prose may use, and where it came from).
# It then reads report/<section>.md, pulls out every numeric token, and FAILS
# if any token is not a registered rendering of a computed number.
#
# Tokens that are not quantities are exempt by pattern, not by hand: code spans,
# measure and index names (PSI-90, SVI 1), fiscal and calendar years, dates,
# and cross-references (Table 3.1, Figure 1, section 9, Task 3.3).
#
# Numbers that come from a Phase 0-2 stage log rather than a table are read
# from that log with a strict pattern; a pattern that stops matching is a
# failure, never a silent default. Task 6.1 re-runs this on a fresh clone.

hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
TB  <- function(f) read.csv(file.path("output", "tables", f), stringsAsFactors = FALSE)
LOG <- function(f, pattern, group = 1) {
  x <- readLines(file.path("output", "tables", f), warn = FALSE)
  m <- regmatches(x, regexec(pattern, x, perl = TRUE))
  hit <- Filter(length, m)
  if (!length(hit)) stop(sprintf("pattern not found in %s: %s", f, pattern))
  as.numeric(gsub(",", "", hit[[1]][group + 1]))
}
ci  <- function(x) formatC(x, format = "d", big.mark = ",")
f   <- function(x, d) formatC(x, format = "f", digits = d)
pc  <- function(x, d = 1) paste0(f(100 * x, d), "%")
## a qualitative claim the report makes. Task S1.2: a claim that no longer
## holds is recorded and the stage runs on, so every stale claim and number is
## listed in one run; the stage still fails at the end.
CLAIMS_BAD <- character(0)
claim <- function(ok, what) if (!isTRUE(ok)) {
  CLAIMS_BAD <<- c(CLAIMS_BAD, what); cat(sprintf("  CLAIM NO LONGER HOLDS: %s\n", what)) }
sg  <- function(x, d = 2) ifelse(round(x, d) == 0, f(0, d), ifelse(x < 0, paste0("−", f(abs(x), d)), paste0("+", f(x, d))))

REG <- list()
reg <- function(sec, key, value, text, source) {
  REG[[length(REG) + 1]] <<- data.frame(section = sec, key = key, value = value,
                                        text = paste(unique(text), collapse = " | "), source = source)
}

hdr("report numbers -- registry and check")

# ==========================================================================
# SECTION 03  data construction and provenance
# ==========================================================================
S <- "03-data"
A   <- readRDS(file.path("data", "analytic-v2.rds"))
O   <- readRDS(file.path("data", "outcomes.rds"))
CAT <- readRDS(file.path("data", "catchment.rds"))
XW  <- readRDS(file.path("data", "crosswalk.rds"))
BC  <- readRDS(file.path("data", "blockC.rds"))
SRC <- read.csv(file.path("provenance", "sources.csv"), stringsAsFactors = FALSE)
UM  <- TB("unmatched-hospitals.csv")
GATE <- TB("admission-gate-results.csv")
MISS <- TB("missingness-audit.csv")
CC   <- TB("catchment-vs-county-correlation.csv")
RV   <- TB("reliability-by-volume.csv")
ADID <- TB("adi-aggregation-diagnostics.csv")

reg(S, "n_sources", nrow(SRC), ci(nrow(SRC)), "provenance/sources.csv rows")
reg(S, "n_sources_not_taken", sum(nzchar(SRC$exclusion_reason)), "Three", "sources.csv, non-empty exclusion_reason")
reg(S, "n_frame", nrow(A), ci(nrow(A)), "data/analytic-v2.rds")
reg(S, "n_blockA_model", 11, "11", "Block A terms in R/03-baseline.R and R/04-spec-curve.R (bA)")
reg(S, "n_cols", ncol(A), ci(ncol(A)), "data/analytic-v2.rds")
reg(S, "n_va", LOG("task1.2-frame.txt", "Acute Care - VA\\s+(\\d+)"), "107", "stage 3 log (Task 1.2)")
reg(S, "n_unmatched", nrow(UM), ci(nrow(UM)), "output/tables/unmatched-hospitals.csv")
reg(S, "n_zcta_fallback", sum(XW$tract_source == "zcta_fallback"), ci(sum(XW$tract_source == "zcta_fallback")),
    "data/crosswalk.rds tract_source")
cn <- sapply(c(psi06 = "psi06", psi03 = "psi03", psi12 = "psi12", psi13 = "psi13"),
             function(v) sum(is.finite(suppressWarnings(as.numeric(O[[v]])))))
for (v in names(cn)) reg(S, paste0("n_", v), cn[[v]], ci(cn[[v]]), "data/outcomes.rds")
joint <- sum(Reduce(`&`, lapply(names(cn), function(v) is.finite(suppressWarnings(as.numeric(O[[v]]))))))
reg(S, "n_joint", joint, ci(joint), "data/outcomes.rds, all four components")
reg(S, "n_joint_lost", nrow(O) - joint, ci(nrow(O) - joint), "frame minus joint")
hb <- is.finite(O$psi90) & is.finite(O$psi90_hacrp)
reg(S, "n_hacrp_both", sum(hb), ci(sum(hb)), "data/outcomes.rds")
reg(S, "r_hacrp", cor(O$psi90[hb], O$psi90_hacrp[hb]), f(cor(O$psi90[hb], O$psi90_hacrp[hb]), 4), "data/outcomes.rds")
md <- mean(O$psi90_hacrp[hb] - O$psi90[hb])
reg(S, "meandiff_hacrp", md, f(md, 5), "data/outcomes.rds, HACRP minus Care Compare")
lam <- median(A$lambda_i[A$lambda_in_tau2_sample])
## Task S2.1: every lambda is a result under the project's scalar
## approximation (Task 2.2), not a quantity CMS reports; sources say so
reg(S, "lambda_median", lam, c(f(lam, 3), pc(lam, 0)), "data/analytic-v2.rds, tau2 sample (scalar approximation)")
slope <- LOG("phase0-followup.txt", "slope log\\(CI width\\) ~ log\\(volume\\)\\s+= ([-+][0-9.]+)")
reg(S, "ci_width_volume_slope", slope, c(sg(slope, 3), f(slope, 3)),
    "stage 1b log: a diagnostic consistent with shrinkage, not an identification (total volume is not the component denominator)")
qv <- RV[RV$volume_quartile != "all", ]
reg(S, "lambda_q1", qv$mean_lambda[1], f(qv$mean_lambda[1], 2), "output/tables/reliability-by-volume.csv")
reg(S, "lambda_q4", qv$mean_lambda[4], f(qv$mean_lambda[4], 2), "output/tables/reliability-by-volume.csv")
lm_loc <- tapply(A$lambda_i, A$urban_rural, median, na.rm = TRUE)
for (k in names(lm_loc)) reg(S, paste0("lambda_med_", k), lm_loc[[k]], f(lm_loc[[k]], 2), "data/analytic-v2.rds, by urban_rural")
reg(S, "hcris_cover", LOG("task1.3-coverage.txt", "HCRIS PUF FY2023\\s+(\\d+) / \\d+") / nrow(A),
    pc(LOG("task1.3-coverage.txt", "HCRIS PUF FY2023\\s+(\\d+) / \\d+") / nrow(A)), "stage 5 log (Task 1.3)")

## HSAF suppression and catchment coverage
thr  <- LOG("task1.5-hsaf.txt", "minimum non-suppressed TOTAL_CASES\\s+(\\d+)")
sup  <- LOG("task1.5-hsaf.txt", "suppressed TOTAL_CASES cells\\s+([\\d,]+) of")
cells<- LOG("task1.5-hsaf.txt", "suppressed TOTAL_CASES cells\\s+[\\d,]+ of ([\\d,]+)")
reg(S, "hsaf_threshold", thr, ci(thr), "stage 9 log (Task 1.5)")
reg(S, "hsaf_suppressed", sup, ci(sup), "stage 9 log")
reg(S, "hsaf_cells", cells, ci(cells), "stage 9 log")
reg(S, "hsaf_supp_share", sup / cells, pc(sup / cells, 2), "stage 9 log")
cov <- median(CAT$catch_coverage)
reg(S, "coverage_median", cov, c(f(cov, 3), pc(cov, 0)), "data/catchment.rds catch_coverage")
top10 <- LOG("phase0-numbers.txt", "share of observed cases in top 10 ZIPs.*med=([\\d.]+)")
reg(S, "top10_share", top10, pc(top10, 0), "stage 1 log (Phase 0)")
reg(S, "supp_test_fill", 3, "3", "Phase 0 working constant, admission-gates.md A2")
rs <- sapply(1:4, function(k) LOG("phase0-followup.txt", sprintf("^\\s+T%d \\S.*?\\s+([\\d.]+)\\s+[-\\d.]+\\s+[\\d.]+\\s+[\\d.]+\\s+[\\d.]+\\s*$", k)))
reg(S, "supp_test_rmin", min(rs), f(floor(min(rs) * 1000) / 1000, 3), "stage 1b log, min r(obs, imputed) over SVI themes")
mdiff <- sapply(1:4, function(k) LOG("phase0-followup.txt", sprintf("^\\s+T%d \\S.*?\\s+[\\d.]+\\s+([-\\d.]+)\\s+[\\d.]+\\s+[\\d.]+\\s+[\\d.]+\\s*$", k)))
reg(S, "supp_test_maxdiff", max(abs(mdiff)), f(ceiling(max(abs(mdiff)) * 1000) / 1000, 3), "stage 1b log, bound on |mean diff|")
reg(S, "supp_test_n", LOG("phase0-followup.txt", "hospitals in the comparison:\\s+(\\d+)"),
    ci(LOG("phase0-followup.txt", "hospitals in the comparison:\\s+(\\d+)")), "stage 1b log")
fb <- sum(CAT$catch_source == "county_fallback")
reg(S, "n_fallback", fb, ci(fb), "data/catchment.rds")
reg(S, "share_fallback", fb / nrow(CAT), pc(fb / nrow(CAT), 2), "data/catchment.rds")
reg(S, "n_zero_obs", sum(CAT$n_obs_cells == 0), ci(sum(CAT$n_obs_cells == 0)), "data/catchment.rds")
b0 <- GATE$threshold[GATE$gate_id == "B0.a"]
reg(S, "b0_cells", as.numeric(sub(".*n_obs_cells >= (\\d+).*", "\\1", b0)), sub(".*n_obs_cells >= (\\d+).*", "\\1", b0), "gate B0.a threshold")
reg(S, "b0_cases", as.numeric(sub(".*obs_cases >= (\\d+).*", "\\1", b0)), sub(".*obs_cases >= (\\d+).*", "\\1", b0), "gate B0.a threshold")

## the grain comparison (Table 3.1 and the ranges in the prose)
for (i in seq_len(nrow(CC))) for (col in c("r_catchtract_county", "r_catchcounty_county", "r_catchtract_hsa"))
  reg(S, paste(CC$covariate[i], col, sep = "."), CC[[col]][i], f(CC[[col]][i], 2), "output/tables/catchment-vs-county-correlation.csv")
adi_supp <- median(ADID$bg_suppressed_share, na.rm = TRUE)
reg(S, "adi_bg_suppressed_median", adi_supp, pc(adi_supp, 1), "output/tables/adi-aggregation-diagnostics.csv")
reg(S, "n_ct", sum(A$state == "CT"), ci(sum(A$state == "CT")), "data/analytic-v2.rds")

## admission gates (Table 3.2)
reg(S, "n_gates", nrow(GATE), ci(nrow(GATE)), "output/tables/admission-gate-results.csv")
reg(S, "n_gates_pass", sum(GATE$pass), ci(sum(GATE$pass)), "admission-gate-results.csv")
for (g in c("C1", "C2", "C3", "B0", "O1")) {
  k <- sum(startsWith(GATE$gate_id, paste0(g, ".")))
  reg(S, paste0("gates_", g), k, ci(k), "admission-gate-results.csv")
}
gv <- function(id) GATE$observed[GATE$gate_id == id]
reg(S, "c1a", as.numeric(sub("%", "", gv("C1.a"))) / 100, pc(as.numeric(sub("%", "", gv("C1.a"))) / 100, 2), "gate C1.a")
reg(S, "c1c", as.numeric(sub("%", "", gv("C1.c"))) / 100, pc(as.numeric(sub("%", "", gv("C1.c"))) / 100, 2), "gate C1.c")
reg(S, "c1e", as.numeric(gv("C1.e")), gv("C1.e"), "gate C1.e")
reg(S, "c2a", as.numeric(sub("%", "", gv("C2.a"))) / 100, c(pc(as.numeric(sub("%", "", gv("C2.a"))) / 100, 2),
                                                             pc(as.numeric(sub("%", "", gv("C2.a"))) / 100, 1)), "gate C2.a")
c2e <- as.numeric(regmatches(gv("C2.e"), gregexpr("[-+][0-9.]+", gv("C2.e")))[[1]])
reg(S, "c2e_beds", c2e[1], sg(c2e[1], 2), "gate C2.e")
reg(S, "c2e_rural", c2e[2], sg(c2e[2], 2), "gate C2.e")
reg(S, "c3a_states", length(unique(A$state)), ci(length(unique(A$state))), "data/analytic-v2.rds states (gate C3.a matched 100%)")
reg(S, "c3b", as.numeric(sub(" .*", "", gv("C3.b"))), sub(" .*", "", gv("C3.b")), "gate C3.b")
reg(S, "c3c", as.numeric(gv("C3.c")), gv("C3.c"), "gate C3.c")
puf <- mean(BC$contract_labor_source == "puf_fy2023")
reg(S, "cl_puf_share", puf, pc(puf, 1), "data/blockC.rds contract_labor_source")
nim <- sum(is.na(BC$contract_labor_share))
nfl <- as.numeric(GATE$n_flagged[GATE$gate_id == "C2.d"])
reg(S, "cl_n_imputed", nim, ci(nim), "data/blockC.rds")
reg(S, "cl_n_flagged", nfl, ci(nfl), "gate C2.d")
reg(S, "cl_n_unreported", nim - nfl, ci(nim - nfl), "imputed minus out-of-range")
reg(S, "mi_m", readRDS(file.path("data", "blockC_mice.rds"))$m, "20", "data/blockC_mice.rds $m")

## missingness (Table 3.3 and prose)
reg(S, "n_audited", nrow(MISS), ci(nrow(MISS)), "output/tables/missingness-audit.csv")
full <- sum(MISS$n_missing == 0); subs <- MISS[MISS$pct_missing >= 0.5, ]
reg(S, "n_full", full, ci(full), "missingness-audit.csv")
reg(S, "n_negligible", nrow(MISS) - full - nrow(subs), ci(nrow(MISS) - full - nrow(subs)), "missingness-audit.csv")
reg(S, "n_substantive", nrow(subs), ci(nrow(subs)), "missingness-audit.csv")
for (i in seq_len(nrow(subs))) with(subs[i, ], {
  reg(S, paste0(variable, ".n_missing"), n_missing, ci(n_missing), "missingness-audit.csv")
  reg(S, paste0(variable, ".pct"), pct_missing, paste0(f(pct_missing, 1), "%"), "missingness-audit.csv")
  for (col in c("smd_log_beds", "smd_adi", "smd_svi_ses"))
    reg(S, paste0(variable, ".", col), get(col), sg(get(col), 2), "missingness-audit.csv")
})
## the complete-case frame for the A+B+C composite models (as R/04-spec-curve.R builds it)
ccols <- c("beds", "adc", "occupancy", "resident_to_bed", "teaching", "cmi", "volume_bills", "dsh_pct",
           "wage_index", "operating_margin", "uncompensated_care_pct_npr",
           paste0(c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng", "rurality",
                    "pcp_density"), "_catch_tract"), "hhi_zip",
           "cmi_drift", "contract_labor_share", "tort_n_reforms", "tort_cap_total", "psi90", "lambda_i")
ccols <- intersect(ccols, names(A))
ncc <- sum(Reduce(`&`, lapply(ccols, function(v) is.finite(suppressWarnings(as.numeric(A[[v]]))))))
reg(S, "n_cc_abc", ncc, ci(ncc), "data/analytic-v2.rds complete cases, A+B+C composite terms")
reg(S, "n_cc_left", nrow(A) - ncc, ci(nrow(A) - ncc), "frame minus complete-case frame (Task S5.2: keyed here by the inclusion flow)")

# ==========================================================================
# SECTION 04  methods in plain language
# ==========================================================================
S <- "04-methods"
REGI <- read.csv(file.path("data", "spec-registry.csv"), stringsAsFactors = FALSE)
TOL  <- TB("rashomon-tolerance.csv"); WID <- TB("rashomon-set-width.csv")
MB   <- TB("mcr-bounds-blockB.csv"); TD <- TB("tis-decomposition.csv")
axes <- c("blocks", "form", "outcome", "reliability", "grain", "missing", "influential", "scale")
stopifnot(all(axes %in% names(REGI)))
reg(S, "n_specs", nrow(REGI), ci(nrow(REGI)), "data/spec-registry.csv")
reg(S, "n_specs_blockB", sum(REGI$blocks != "A"), ci(sum(REGI$blocks != "A")), "data/spec-registry.csv")
reg(S, "n_specs_composite", sum(REGI$outcome == "composite"), ci(sum(REGI$outcome == "composite")), "data/spec-registry.csv")
reg(S, "contrast_percentiles", c(10, 90), c("10", "90"), "the p10 -> p90 contrast, R/04-spec-curve.R")
tp <- TOL[TOL$family == "composite", ]
reg(S, "tol_B", tp$B[tp$unit == "hospital"], ci(tp$B[tp$unit == "hospital"]), "output/tables/rashomon-tolerance.csv")
reg(S, "vd_B", LOG("task3.3-variance-decomposition.txt", "composite LMG shares, B = (\\d+)"),
    ci(LOG("task3.3-variance-decomposition.txt", "composite LMG shares, B = (\\d+)")), "stage 22 log")
reg(S, "alpha_pct", 95, c("95", "95%"), "provenance/rashomon-preregistration.md sec 1 (alpha = 0.05): 95th percentile, 95% interval")
for (u in c("hospital", "cbsa", "state"))
  reg(S, paste0("tol_rel_", u), tp$epsilon_rel[tp$unit == u], pc(tp$epsilon_rel[tp$unit == u], 1), "rashomon-tolerance.csv")
wp <- WID[WID$family == "composite" & WID$unit == "hospital", ]
reg(S, "n_set", wp$n_set, ci(wp$n_set), "output/tables/rashomon-set-width.csv")
reg(S, "width_lo", wp$est_min, sg(wp$est_min, 2), "rashomon-set-width.csv")
reg(S, "width_hi", wp$est_max, sg(wp$est_max, 2), "rashomon-set-width.csv")
g <- MB[MB$group == "blockB_disadvantage", ]
reg(S, "mcr_minus_block", g$mcr_minus[g$unit == "hospital"], f(g$mcr_minus[g$unit == "hospital"], 3), "output/tables/mcr-bounds-blockB.csv")
reg(S, "mcr_minus_block_pct", g$mcr_minus[g$unit == "hospital"] - 1, pc(g$mcr_minus[g$unit == "hospital"] - 1, 1), "mcr-bounds-blockB.csv")
reg(S, "mcr_minus_block_state", g$mcr_minus[g$unit == "state"], f(g$mcr_minus[g$unit == "state"], 3), "mcr-bounds-blockB.csv")
pv <- TB("rashomon-published-subset.csv")
pv <- pv[pv$unit == "hospital" & pv$members == "unweighted" & pv$group == "blockB_disadvantage", ]
reg(S, "pub n_set hospital", pv$n_models, ci(pv$n_models), "rashomon-published-subset.csv, unweighted members (Task S2.1)")
reg(S, "pub mcr_minus hospital", pv$mcr_minus, c(f(pv$mcr_minus, 3), pc(pv$mcr_minus - 1, 1)), "rashomon-published-subset.csv")
reg(S, "mr_reference", 1, "1", "reliance of 1 = no reliance; concentration index 0 = proportional (definitions)")
reg(S, "ci_range", c(-1, 0, 1), c("\u22121", "+1", "0"), "concentration index bounds (definition)")
s3 <- TD[TD$measure == "svi3", ]
reg(S, "svi3_marg_med", s3$mr_marg_med, f(s3$mr_marg_med, 3), "output/tables/tis-decomposition.csv")
stopifnot(s3$dir_lo > 1)
PS <- readRDS(file.path("data", "payment-sim.rds"))
reg(S, "pay_B", PS$B, ci(PS$B), "data/payment-sim.rds $B")
src9 <- paste(readLines(file.path("R", "09-payment-sim.R"), warn = FALSE), collapse = "\n")
band <- regmatches(src9, regexec("else 0\\.(\\d+) \\+ 0\\.(\\d+) \\* P", src9))[[1]]
if (length(band) != 3) stop("bonus band not found in R/09-payment-sim.R")
lo <- as.numeric(paste0("0.", band[2])); wd <- as.numeric(paste0("0.", band[3]))
reg(S, "band_lo", lo, paste0(f(100 * lo, 1), "%"), "R/09-payment-sim.R rate_of()")
reg(S, "band_hi", lo + wd, paste0(f(100 * (lo + wd), 0), "%"), "R/09-payment-sim.R rate_of()")
c1 <- LOG("task4.2-payment-sim.txt", "C1a  from the file's W-Z scores.*reproduced (\\d+) of \\d+")
c1n <- LOG("task4.2-payment-sim.txt", "C1a  from the file's W-Z scores.*reproduced \\d+ of (\\d+)")
reg(S, "c1_reproduced", c1, ci(c1), "stage 35 log (Task 4.2), gate C1a")
reg(S, "c1_n", c1n, ci(c1n), "stage 35 log (Task 4.2), gate C1a")
reg(S, "gv tolerance", 0.01, "1%", "second-pass-preregistration.md sec 6")
reg(S, "gv repeats", 20, "20", "second-pass-preregistration.md sec 6")

# ==========================================================================
# SECTION 05  variance decomposition, specification curve, Rashomon width
# ==========================================================================
S <- "05-decomposition"
VD <- TB("variance-decomposition.csv")
vd <- function(src, ver, b, col = "share") VD[grepl(src, VD$source) & grepl(ver, VD$version) & VD$block == b, col]
## Task S2.1: the published score, unweighted, is the primary analysis; the
## reliability-weighted fit (scalar lambda_i) is a sensitivity analysis and is
## registered only as a pair with it (reg_pair), and the text check below
## fails any paragraph that cites a weighted share without its published
## pair. Key names end in "published" or "weighted".
VW <- c(published = "^published", weighted = "^reliability-weighted")
stopifnot(sum(grepl(VW[["published"]], VD$version)) == 4, sum(grepl(VW[["weighted"]], VD$version)) == 4)
reg_pair <- function(sec, key, fn, render, source) for (w in names(VW))
  reg(sec, paste(key, w), fn(VW[[w]]), render(fn(VW[[w]])),
      paste0(source, if (w == "published") ", published score unweighted (primary)" else
                       ", reliability-weighted, scalar lambda_i (sensitivity)"))
for (b in c("structure", "community", "policy", "residual")) {
  for (col in c("share", "ci_lo", "ci_hi"))
    reg_pair(S, if (col == "share") paste("vd", b) else paste("vd", b, col), function(v) vd("^composite", v, b, col),
             function(x) pc(x, 1), "output/tables/variance-decomposition.csv")
  for (col in c("share", "ci_lo", "ci_hi")) { v <- vd("^components", "", b, col)
    reg(S, paste("vd comp", b, col), v, c(pc(v, 1), sub("^-", "−", pc(v, 1)), pc(v, 2), sub("^-", "−", pc(v, 2))),
        "variance-decomposition.csv, components model (equal prominence, Task S2.1)") }
}
expl <- function(v) sum(sapply(c("structure", "community", "policy"), function(b) vd("^composite", v, b)))
reg_pair(S, "vd_explained", expl, function(x) pc(x, 1), "sum of block shares")
reg_pair(S, "comm_of_expl", function(v) vd("^composite", v, "community") / expl(v), function(x) pc(x, 1), "community / (A+B+C)")
reg_pair(S, "struct_of_expl", function(v) vd("^composite", v, "structure") / expl(v), function(x) pc(x, 1), "structure / (A+B+C)")
## the weighted-minus-unweighted difference is a difference between two
## descriptive allocations, never "what the smoothing conceals" (review 2026-10-01)
dshift <- vd("^composite", VW[["weighted"]], "community") - vd("^composite", VW[["published"]], "community")
reg(S, "vd_shift", dshift, c(f(100 * dshift, 1), f(100 * dshift, 2)),
    "weighted minus unweighted community share, points -- two allocations, not hidden signal")
reg(S, "n_cc_abc", ncc, ci(ncc), "complete-case A+B+C frame (as in section 03)")
reg(S, "n_cc_left", nrow(A) - ncc, ci(nrow(A) - ncc), "frame minus complete-case frame (as in section 03)")
PT <- TB("spec-curve-points.csv")
reg(S, "n_curve", nrow(PT), ci(nrow(PT)), "output/tables/spec-curve-points.csv")
reg(S, "curve_pos", mean(PT$dis_std > 0), pc(mean(PT$dis_std > 0), 1), "spec-curve-points.csv")
reg(S, "curve_med", median(PT$dis_std), sg(median(PT$dis_std), 2), "spec-curve-points.csv")
reg(S, "curve_possig", mean(PT$lo > 0), pc(mean(PT$lo > 0), 1), "spec-curve-points.csv")
stopifnot(mean(PT$hi < 0) == 0)
reg(S, "contrast_percentiles", c(10, 90), c("10", "90"), "the p10 -> p90 contrast")
reg(S, "alpha_pct", 95, c("95", "95%"), "95% interval")
SU <- TB("spec-curve-summary.csv")
su <- function(ax, lv, col) SU[SU$axis == ax & SU$level == lv, col]
for (lv in c("composite", "psi03", "psi06", "psi12", "psi13")) {
  reg(S, paste("sc", lv, "pos"), su("outcome", lv, "share_pos"), pc(su("outcome", lv, "share_pos"), 1), "spec-curve-summary.csv")
  reg(S, paste("sc", lv, "med"), su("outcome", lv, "median"), sg(su("outcome", lv, "median"), 2), "spec-curve-summary.csv") }
for (lv in c("linear", "spline")) reg(S, paste("sc form", lv), su("form", lv, "median"), sg(su("form", lv, "median"), 2), "spec-curve-summary.csv")
for (lv in c("hosp_county", "catch_county", "catch_tract")) reg(S, paste("sc grain", lv), su("grain", lv, "median"), sg(su("grain", lv, "median"), 2), "spec-curve-summary.csv")
RL <- TB("spec-curve-reliability.csv"); e <- RL[RL$contrast == "eiv", ]
reg(S, "eiv_n", nrow(e), ci(nrow(e)), "spec-curve-reliability.csv, paired composite cells")
reg(S, "eiv_up", mean(e$delta > 0), pc(mean(e$delta > 0), 1), "spec-curve-reliability.csv")
reg(S, "eiv_shift", median(e$delta), sg(median(e$delta), 2), "spec-curve-reliability.csv")
cp <- PT[PT$outcome == "composite", ]
reg(S, "comp_unw_med", median(cp$dis_std[cp$reliability == "unweighted"]), sg(median(cp$dis_std[cp$reliability == "unweighted"]), 2), "spec-curve-points.csv")
reg(S, "comp_eiv_med", median(cp$dis_std[cp$reliability == "eiv"]), sg(median(cp$dis_std[cp$reliability == "eiv"]), 2), "spec-curve-points.csv")
INF <- TB("spec-diagnostics-influence.csv"); ic <- INF[grepl("^composite", INF$anchor), ]
reg(S, "loo_hosp_max", max(ic$loo_hosp_max), f(max(ic$loo_hosp_max), 2), "spec-diagnostics-influence.csv")
stopifnot(!any(ic$loo_hosp_flip), all(INF$top_state[grepl("^composite", INF$anchor)] == "NY"))
reg(S, "ny_lo", min(ic$loo_state_max), f(min(ic$loo_state_max), 2), "spec-diagnostics-influence.csv")
reg(S, "ny_hi", max(ic$loo_state_max), f(max(ic$loo_state_max), 2), "spec-diagnostics-influence.csv")
reg(S, "n_set", wp$n_set, ci(wp$n_set), "rashomon-set-width.csv")
reg(S, "n_specs_composite", sum(REGI$outcome == "composite"), ci(sum(REGI$outcome == "composite")), "spec-registry.csv")
reg(S, "width_lo", wp$est_min, sg(wp$est_min, 2), "rashomon-set-width.csv")
reg(S, "width_hi", wp$est_max, sg(wp$est_max, 2), "rashomon-set-width.csv")
reg(S, "set_med", wp$est_median, sg(wp$est_median, 2), "rashomon-set-width.csv")
reg(S, "set_pos", wp$share_positive, pc(wp$share_positive, 1), "rashomon-set-width.csv")
reg(S, "set_possig", wp$share_pos_sig, pc(wp$share_pos_sig, 1), "rashomon-set-width.csv")
stopifnot(wp$share_neg_sig == 0)
reg(S, "erm_est", wp$erm_est, sg(wp$erm_est, 2), "rashomon-set-width.csv")
## Task S2.1: the members fitted to the published score without weights,
## beside the full set (a subset of stage 30's cached reliance, no refit)
PUB <- TB("rashomon-published-subset.csv")
pb <- function(u, m, col, g = "blockB_disadvantage") PUB[PUB$unit == u & PUB$members == m & PUB$group == g, col]
stopifnot(pb("hospital", "all", "n_models") == wp$n_set, pb("hospital", "all", "est_min") == wp$est_min)
reg_pub <- function(sec) {
  for (u in c("hospital", "cbsa", "state")) {
    reg(sec, paste("pub n_set", u), pb(u, "unweighted", "n_models"), ci(pb(u, "unweighted", "n_models")),
        "rashomon-published-subset.csv, unweighted members")
    for (col in c("est_min", "est_max", "est_median"))
      reg(sec, paste("pub", col, u), pb(u, "unweighted", col), sg(pb(u, "unweighted", col), 2),
          "rashomon-published-subset.csv, unweighted members")
    for (col in c("mcr_minus", "mcr_plus")) { v <- pb(u, "unweighted", col)
      reg(sec, paste("pub", col, u), v, c(f(v, 3), pc(v - 1, 1)), "rashomon-published-subset.csv, unweighted members") }
  }
  reg(sec, "pub best spec", pb("hospital", "unweighted", "best_spec"), as.character(pb("hospital", "unweighted", "best_spec")),
      "rashomon-published-subset.csv (P-best, second-pass-preregistration.md sec 1)")
}
reg_pub(S)
AXS <- TB("rashomon-set-axes.csv"); ax <- function(a, l, col) AXS[AXS$unit == "hospital" & AXS$axis == a & AXS$level == l, col]
for (l in c("catch_county", "catch_tract")) for (col in c("est_min", "est_max"))
  reg(S, paste("set", l, col), ax("grain", l, col), sg(ax("grain", l, col), 2), "rashomon-set-axes.csv")
stopifnot(ax("grain", "catch_county", "est_max") < 0, ax("grain", "catch_tract", "est_min") > 0)
for (col in c("est_min", "est_max")) reg(S, paste("set spline", col), ax("form", "spline", col), sg(ax("form", "spline", col), 2), "rashomon-set-axes.csv")
reg(S, "set_linear_n", ax("form", "linear", "n_in"), ci(ax("form", "linear", "n_in")), "rashomon-set-axes.csv")
for (col in c("est_min", "est_max")) reg(S, paste("set linear", col), ax("form", "linear", col), sg(ax("form", "linear", col), 2), "rashomon-set-axes.csv")
## Task S2.5: the support of the joint contrast and the contrasts that replace
## or accompany it, for the four grain members of the set (stage 41)
CS <- TB("contrast-support.csv")
reg_cs <- function(sec) {
  for (i in seq_len(nrow(CS))) { z <- CS[i, ]
    key <- paste("cs", z$grain, z$quantity, z$profile, z$end)
    if (z$quantity == "support") {
      reg(sec, paste(key, "share"), z$share_obs_as_far, c(pc(z$share_obs_as_far, 1), pc(z$share_obs_as_far, 0)), "contrast-support.csv")
      reg(sec, paste(key, "D"), z$mahalanobis, f(z$mahalanobis, 2), "contrast-support.csv, Mahalanobis distance")
    } else for (col in c("est", "se", "part_material", "part_composition", "part_apart"))
      reg(sec, paste(key, col), z[[col]], c(sg(z[[col]], 2), f(abs(z[[col]]), 2)), "contrast-support.csv, SD of PSI-90")
  }
  reg(sec, "cs support rule", 0.05, "5%", "second-pass-preregistration.md sec 7")
}
reg_cs(S)
## Task S2.6: the grain comparison with the measurement held constant (stage 42)
GC <- TB("geo-construction.csv")
reg_gc <- function(sec) for (i in seq_len(nrow(GC))) { z <- GC[i, ]
  key <- paste("gc", z$grain, z$construction, z$quantity, z$measure)
  if (z$quantity == "cross-grain correlation") reg(sec, key, z$r_grains, f(z$r_grains, 2), "geo-construction.csv")
  else if (z$quantity != "in-sample loss") reg(sec, key, z$est, c(sg(z$est, 2), f(abs(z$est), 2)), "geo-construction.csv, SD of PSI-90") }
reg_gc(S)
RSET <- TB("rashomon-set.csv")
lin_in <- RSET[RSET$outcome == "composite" & RSET$unit == "hospital" & RSET$in_set & RSET$form == "linear", ]
stopifnot(all(lin_in$reliability == "eiv"))
reg(S, "blockA_best_eps", ax("blocks", "A", "best_excess_eps"), f(ax("blocks", "A", "best_excess_eps"), 2), "rashomon-set-axes.csv")
p12 <- WID[WID$family == "psi12", ]; stopifnot(p12$share_positive == 1)
reg(S, "psi12_n", p12$n_set, ci(p12$n_set), "rashomon-set-width.csv")
reg(S, "psi12_lo", p12$est_min, sg(p12$est_min, 2), "rashomon-set-width.csv")
reg(S, "psi12_hi", p12$est_max, sg(p12$est_max, 2), "rashomon-set-width.csv")

# ==========================================================================
# SECTION 06  drivers: MCR, coefficient ranges, TIS, Model 2 tags
# ==========================================================================
## Task S5.2: the September 30 "drivers" section is now section 6, community
## associations across models and geography; the TIS keys below it move to the
## supplement's registry label (supp-tis)
S <- "06-associations"
## Task S2.4: the held-out validation (stage 40) is the evidence for any
## data-prioritization statement; registered here for the rewrite of 06 and 10
GV <- TB("geo-validation.csv")
reg_gv <- function(sec) for (i in seq_len(nrow(GV))) { g <- GV[i, ]
  key <- paste("gv", g$design, g$model)
  reg(sec, paste(key, "r2"), g$r2_heldout, pc(g$r2_heldout, 1), "geo-validation.csv, held-out R2")
  if (g$model %in% c("a", "c", "d", "e", "null")) for (col in c("rel_diff_mean", "rel_diff_lo", "rel_diff_hi")) {
    v <- g[[col]]; reg(sec, paste(key, col), v, c(pc(v, 1), pc(v, 2), sub("^-", "\u2212", pc(v, 2)), paste0("+", pc(v, 2))),
                       "geo-validation.csv, loss relative to model (b), mean and 2.5-97.5 over 20 repeats") }
  if (!is.na(g$gain_kept)) for (col in c("gain_kept", "gain_kept_lo", "gain_kept_hi"))
    reg(sec, paste(key, col), g[[col]], pc(g[[col]], 0), "geo-validation.csv, share of Block B's held-out gain kept")
  if (!is.na(g$share_repeats_within_tol))
    reg(sec, paste(key, "share_within_tol"), g$share_repeats_within_tol, pc(g$share_repeats_within_tol, 0), "geo-validation.csv")
}
reg_gv(S)
reg_gc(S)
reg_cs(S)
reg(S, "set_pos", wp$share_positive, pc(wp$share_positive, 1), "rashomon-set-width.csv")
reg(S, "n_specs_composite", sum(REGI$outcome == "composite"), ci(sum(REGI$outcome == "composite")), "spec-registry.csv")
reg(S, "n_set cbsa", gb_n <- MB$n_models[MB$group == "blockB_disadvantage" & MB$unit == "cbsa"], ci(gb_n), "mcr-bounds-blockB.csv")
reg(S, "repeat percentiles", c(2.5, 97.5), c("2.5", "97.5"), "the 2.5th-97.5th percentile range over repeats (definition)")
reg(S, "gv in-sample r2 b", GV$in_sample_r2_b[1], pc(GV$in_sample_r2_b[1], 1), "geo-validation.csv, spec 382 in sample")
reg(S, "gv tolerance", 0.01, "1%", "second-pass-preregistration.md sec 6")
reg(S, "gv repeats", 20, "20", "second-pass-preregistration.md sec 6")
MA <- TB("mcr-bounds-blockA.csv"); CRG <- TB("rashomon-coef-ranges.csv"); TG <- TB("driver-tags.csv")
FLW <- TB("tis-flow-matrix.csv")
reg(S, "n_set", wp$n_set, ci(wp$n_set), "rashomon-set-width.csv")
reg(S, "width_lo", wp$est_min, sg(wp$est_min, 2), "rashomon-set-width.csv")
reg(S, "width_hi", wp$est_max, sg(wp$est_max, 2), "rashomon-set-width.csv")
gb <- MB[MB$group == "blockB_disadvantage", ]; ga <- MA[MA$group == "blockA_structure", ]
reg(S, "mcrB_minus_pct", gb$mcr_minus[gb$unit == "hospital"] - 1, pc(gb$mcr_minus[gb$unit == "hospital"] - 1, 1), "mcr-bounds-blockB.csv")
reg_pub(S)
reg(S, "mcrB_med_pct", gb$mr_median[gb$unit == "hospital"] - 1, pc(gb$mr_median[gb$unit == "hospital"] - 1, 1), "mcr-bounds-blockB.csv")
for (u in c("hospital", "cbsa", "state")) {
  reg(S, paste("mcrB minus", u), gb$mcr_minus[gb$unit == u], f(gb$mcr_minus[gb$unit == u], 3), "mcr-bounds-blockB.csv")
  reg(S, paste("mcrA minus", u), ga$mcr_minus[ga$unit == u], f(ga$mcr_minus[ga$unit == u], 3), "mcr-bounds-blockA.csv") }
reg(S, "mcrB plus", gb$mcr_plus[gb$unit == "hospital"], f(gb$mcr_plus[gb$unit == "hospital"], 3), "mcr-bounds-blockB.csv")
reg(S, "mcrA plus", ga$mcr_plus[ga$unit == "hospital"], f(ga$mcr_plus[ga$unit == "hospital"], 3), "mcr-bounds-blockA.csv")
stopifnot(gb$share_above_one[gb$unit == "hospital"] == 1)
mh <- MB[MB$unit == "hospital" & MB$group != "blockB_disadvantage", ]
for (i in seq_len(nrow(mh))) reg(S, paste("mcr minus", mh$group[i]), mh$mcr_minus[i], f(mh$mcr_minus[i], 3), "mcr-bounds-blockB.csv")
for (g in c("ice150", "limeng")) reg(S, paste("mcr plus", g), mh$mcr_plus[mh$group == g], f(mh$mcr_plus[mh$group == g], 3), "mcr-bounds-blockB.csv")
ah <- MA[MA$unit == "hospital", ]
for (g in c("beds", "volume", "operating_margin")) reg(S, paste("mcrA minus", g), ah$mcr_minus[ah$group == g], f(ah$mcr_minus[ah$group == g], 3), "mcr-bounds-blockA.csv")
reg(S, "mcrA plus beds", ah$mcr_plus[ah$group == "beds"], f(ah$mcr_plus[ah$group == "beds"], 3), "mcr-bounds-blockA.csv")
oth <- ah[!ah$group %in% c("blockA_structure", "beds", "volume", "operating_margin"), ]
stopifnot(all(oth$mcr_minus < 1.01))
for (lv in c("AB", "ABC")) reg(S, paste("sc blocks", lv), SU$median[SU$axis == "blocks" & SU$level == lv],
    sg(SU$median[SU$axis == "blocks" & SU$level == lv], 2), "spec-curve-summary.csv")
reg(S, "one_pct", 0.01, "1%", "the 1% threshold used in the sentence (checked: no other Block A covariate's MCR- exceeds 1.01)")
reg(S, "mr_reference", 1, "1", "reliance of 1 = no reliance")
reg(S, "contrast_percentiles", c(10, 90), c("10", "90"), "the p10 -> p90 contrast")
for (i in seq_len(nrow(CRG))) for (col in c("lo", "hi"))
  reg(S, paste("coef", CRG$covariate[i], col), CRG[[col]][i], sg(CRG[[col]][i], 2), "rashomon-coef-ranges.csv")
## Task S5.2: the TIS method is exploratory and lives in the supplement (S5.4);
## the September 30 prose's TIS claims are retired with that prose, so the
## claim() checks on them are removed rather than left failing
S <- "B-importance"
## Task S5.4: the supplement's account of the repaired method (B.1-B.3)
reg(S, "consts", c(0, 1, 3), c("0", "1", "3"), "definitions: zero flow, no reliance, the population MR of the two-predictor check")
reg(S, "n_set", wp$n_set, ci(wp$n_set), "rashomon-set-width.csv")
reg(S, "n_specs_composite", sum(REGI$outcome == "composite"), ci(sum(REGI$outcome == "composite")), "spec-registry.csv")
reg(S, "n_pairs", 10 * sum(REGI$outcome == "composite"), ci(10 * sum(REGI$outcome == "composite")), "736 specifications x 10 measures")
INV <- TB("tis-invariants.csv")
for (cn_ in c("inv1_pred", "inv2_loss", "inv3_marg")) { v <- max(INV[[cn_]]); ex <- floor(log10(v)); mt <- v / 10^ex
  reg(S, paste("worst", cn_), v, c(sprintf("%.2f", mt), sprintf("%d", ex)), "tis-invariants.csv, worst case as mantissa and exponent") }
for (k in c("marginal reliance, repaired: ([0-9.]+),", "marginal reliance, repaired: [0-9.]+, ([0-9.]+)",
            "September 30 code: ([0-9.]+),", "September 30 code: [0-9.]+, ([0-9.]+)",
            "fitted proxy TIS ([0-9.]+) vs", "vs signal ([0-9.]+);")) { v <- LOG("task3.13-tis.txt", k)
  reg(S, paste("synthetic", k), v, f(v, 4), "stage 31 log (Task S1.1 synthetic checks)") }
reg(S, "excess total", LOG("task3.14-tis-run.txt", "is ([0-9.]+) and the part"), f(LOG("task3.14-tis-run.txt", "is ([0-9.]+) and the part"), 4), "stage 32 log")
reg(S, "excess shared", LOG("task3.14-tis-run.txt", "shared is \\+([0-9.]+),"), f(LOG("task3.14-tis-run.txt", "shared is \\+([0-9.]+),"), 4), "stage 32 log")
reg(S, "neg delta", LOG("task3.14-tis-run.txt", "Across the set, ([0-9.]+)% of every") / 100, pc(LOG("task3.14-tis-run.txt", "Across the set, ([0-9.]+)% of every") / 100, 1), "stage 32 log")
v <- LOG("task3.14-tis-run.txt", "largest single flow: \\S+ <- \\S+ at \\+([0-9.]+)")
reg(S, "flow max", v, paste0("+", f(v, 4)), "stage 32 log")
v <- LOG("task3.14-tis-run.txt", "Shapley ranking against TIS ranking: \\+([0-9.]+)")
reg(S, "shapley rho 3dp", v, paste0("+", f(v, 3)), "stage 32 log")
for (i in seq_len(nrow(TD))) {
  reg(S, paste("marg", TD$measure[i]), TD$mr_marg_med[i], f(TD$mr_marg_med[i], 3), "tis-decomposition.csv")
  reg(S, paste("dir", TD$measure[i]), TD$mr_dir_med[i], f(TD$mr_dir_med[i], 3), "tis-decomposition.csv") }
reg(S, "n_measures", 10, "ten", "Block B disadvantage measures in the TIS")
reg(S, "tis_total", LOG("task3.14-tis-run.txt", "marginal excess reliance\\s*$|is ([0-9.]+) and the part"),
    f(LOG("task3.14-tis-run.txt", "is ([0-9.]+) and the part"), 3), "stage 32 log")
reg(S, "tis_shared", LOG("task3.14-tis-run.txt", "shared is \\+([0-9.]+),"), f(LOG("task3.14-tis-run.txt", "shared is \\+([0-9.]+),"), 3), "stage 32 log")
reg(S, "tis_shared_pct", LOG("task3.14-tis-run.txt", "or ([0-9.]+)% of the total") / 100,
    pc(LOG("task3.14-tis-run.txt", "or ([0-9.]+)% of the total") / 100, 1), "stage 32 log")
ad <- TD[TD$measure == "adi", ]
reg(S, "adi_r2", ad$r2_on_rest, pc(ad$r2_on_rest, 0), "tis-decomposition.csv")
reg(S, "adi_loan", ad$shared_share, pc(ad$shared_share, 1), "tis-decomposition.csv")
adi_in <- FLW[FLW$from == "adi" & FLW$to != "adi", ]; adi_in <- adi_in[order(-adi_in$flow), ]
reg(S, "svi3_marg_med", s3$mr_marg_med, f(s3$mr_marg_med, 3), "tis-decomposition.csv")
big <- FLW[FLW$from != FLW$to, ]; big <- big[which.max(abs(big$flow)), ]
reg(S, "flow_max", big$flow, sg(big$flow, 3), "tis-flow-matrix.csv")
off <- FLW[FLW$from != FLW$to, ]
lent <- tapply(off$flow, off$to, sum); borrowed <- tapply(off$flow, off$from, sum)   # gross, as 3.14 computes them
reg(S, "top_lender", max(lent), sg(max(lent), 3), "tis-flow-matrix.csv, total lent (column sum)")
reg(S, "top_borrower", max(borrowed), sg(max(borrowed), 3), "tis-flow-matrix.csv, total borrowed (row sum)")
for (i in seq_len(nrow(TD))) {
  reg(S, paste("tis", TD$measure[i]), TD$tis_med[i], f(TD$tis_med[i], 3), "tis-decomposition.csv")
  reg(S, paste("tis lo", TD$measure[i]), TD$tis_lo[i], f(TD$tis_lo[i], 3), "tis-decomposition.csv")
  reg(S, paste("tis hi", TD$measure[i]), TD$tis_hi[i], f(TD$tis_hi[i], 3), "tis-decomposition.csv") }
reg(S, "n_direct", sum(TD$cannot_ignore), c(ci(sum(TD$cannot_ignore)), "Seven"), "tis-decomposition.csv")
rho <- cor(TD$shapley, TD$tis_med, method = "spearman")
reg(S, "shapley_rho", rho, sg(rho, 2), "tis-decomposition.csv")
for (i in seq_len(nrow(TG))) {
  reg(S, paste("dir lo", TG$measure[i]), TG$dir_lo[i], f(TG$dir_lo[i], 4), "output/tables/driver-tags.csv")
  reg(S, paste("loan", TG$measure[i]), TG$on_loan[i], pc(TG$on_loan[i], 0), "driver-tags.csv") }
reg(S, "half", 0.5, "half", "tag rule threshold")
reg(S, "n_essential", sum(TG$tag == "essential"), "four", "driver-tags.csv")

# ==========================================================================
# THE TRACK ARCHETYPES  (supplement; Task S5.2 folds the main-report uses into
# sections 02 and 08 below)
# ==========================================================================
S <- "supp-archetypes"
AV <- TB("archetype-validation.csv"); AC <- TB("archetype-cells.csv"); S23 <- TB("archetype-screened23.csv")
av <- function(claim, track) AV[AV$claim == claim & grepl(track, AV$track, fixed = TRUE), ]
stopifnot(AV$result[AV$claim == "VERDICT"] == "GRADIENT, NOT STRATA")
for (tr in c("primary", "without the 23", "PSI-90 terciles")) {
  g1 <- av("C1 gradient (gamma)", tr); g2 <- av("C2 Track-cell share", tr)
  reg(S, paste("gamma", tr), g1$estimate, sg(g1$estimate, 2), "archetype-validation.csv")
  reg(S, paste("cells", tr), g2$estimate, pc(g2$estimate, 1), "archetype-validation.csv")
  if (tr == "primary") {
    for (col in c("ci_lo", "ci_hi")) { reg(S, paste("gamma", col), g1[[col]], sg(g1[[col]], 2), "archetype-validation.csv")
                                       reg(S, paste("cells", col), g2[[col]], pc(g2[[col]], 1), "archetype-validation.csv") } } }
reg(S, "independence", 1 / 3, pc(1 / 3, 1), "product of margins, 3 x 3 with tercile columns")
reg(S, "bar", 0.5, c("50%", "50"), "provenance/archetype-preregistration.md sec 5")
reg(S, "alpha_pct", 95, c("95", "95%"), "95% interval")
st <- AC[AC$arm == "star", ]
reg(S, "n_frame", sum(st$n), ci(sum(st$n)), "archetype-cells.csv, star arm")
for (tr in c("T1", "T2", "T3")) { x <- st[st$track == tr, ]
  reg(S, paste("obsexp", tr), x$obs_exp, f(x$obs_exp, 2), "archetype-cells.csv")
  reg(S, paste("n", tr), x$n, ci(x$n), "archetype-cells.csv")
  reg(S, paste("beds", tr), x$beds_median, ci(x$beds_median), "archetype-cells.csv") }
stopifnot(which.max(st$n) == which(st$track == "T3"), st$n[st$track == "T2"] == min(st$n[st$track != "off-Track"]))
ari <- AV$estimate[AV$claim == "3.15 forced-3 vs Track cells (ARI)" & AV$track == "published"]
reg(S, "ari", ari, sg(ari, 3), "archetype-validation.csv"); reg(S, "ari_zero", 0, "0", "ARI = 0 is chance agreement (definition)")
sn <- AV[AV$claim == "C3 safety-net share", ]
for (i in 1:3) for (col in c("estimate", "ci_lo", "ci_hi")) reg(S, paste("sn", i, col), sn[[col]][i], pc(sn[[col]][i], 1), "archetype-validation.csv")
memo <- unlist(strsplit(sn$memo, "-")); memo_pct <- as.numeric(memo) * 100
reg(S, "memo_sn", memo_pct, c(formatC(memo_pct, format = "d"), paste0(formatC(memo_pct, format = "d"), "%")), "archetype-validation.csv memo ranges")
mb <- as.numeric(strsplit(AV$memo[AV$claim == "C4 beds rise with Track"], " / ")[[1]])
reg(S, "memo_beds", mb, ci(mb), "archetype-validation.csv memo")
c5 <- AV[AV$claim == "C5 Track 1 safety in bottom quartile (PSI-90)", ]
for (col in c("estimate", "ci_lo", "ci_hi")) reg(S, paste("c5", col), c5[[col]], pc(c5[[col]], 1), "archetype-validation.csv")
reg(S, "chance_quartile", 0.25, "25%", "a quartile by chance")
reg(S, "n23", nrow(S23), ci(nrow(S23)), "archetype-screened23.csv")
stopifnot(all(S23$margin < -1))
reg(S, "margin_cut", -1, "−100%", "prereg sec 3: margin < -1")
rated23 <- S23[is.finite(S23$star), ]
reg(S, "n23_rated", nrow(rated23), ci(nrow(rated23)), "archetype-screened23.csv")
reg(S, "n23_t1", sum(rated23$star <= 2), ci(sum(rated23$star <= 2)), "archetype-screened23.csv")
stopifnot(sum(rated23$star == 3) > nrow(rated23) / 2)
unr <- function(k) LOG("task3.16-archetypes.txt", paste0("^", k, "\\s+(\\d+)\\s+([-0-9.]+)\\s+([0-9.]+)\\s+(\\d+)\\s+([0-9.]+)\\s+([0-9.]+)"), 1)
U <- regmatches(readLines(file.path("output", "tables", "task3.16-archetypes.txt")),
                regexec("^(rated|unrated)\\s+(\\d+)\\s+([-0-9.]+)\\s+([0-9.]+)\\s+(\\d+)\\s+([0-9.]+)\\s+([0-9.]+)", readLines(file.path("output", "tables", "task3.16-archetypes.txt"))))
U <- do.call(rbind, Filter(length, U)); stopifnot(nrow(U) == 2)
un <- U[U[, 2] == "unrated", ]; ra <- U[U[, 2] == "rated", ]
reg(S, "n_unrated", as.numeric(un[3]), ci(as.numeric(un[3])), "stage 34 log")
reg(S, "unrated_share", as.numeric(un[3]) / nrow(A), pc(as.numeric(un[3]) / nrow(A), 1), "stage 34 log / frame")
reg(S, "beds_unrated", as.numeric(un[6]), un[6], "stage 34 log"); reg(S, "beds_rated", as.numeric(ra[6]), ra[6], "stage 34 log")
reg(S, "lam_unrated", as.numeric(un[8]), f(as.numeric(un[8]), 2), "stage 34 log"); reg(S, "lam_rated", as.numeric(ra[8]), f(as.numeric(ra[8]), 2), "stage 34 log")

# ==========================================================================
# SECTION 07  payment consequences (section 08 until Task S5.2)
# ==========================================================================
S <- "07-payment"
PBS <- TB("payment-by-stratum.csv"); GAPT <- TB("payment-gap-decomposition.csv"); HB <- TB("payment-by-hospital.csv")
CAL <- TB("hacrp-calibration.csv"); OBS <- TB("observed-hacrp-regressivity.csv"); RG <- TB("regressivity.csv")
BS <- TB("regressivity-by-stratum.csv")
reg(S, "band_lo", lo, paste0(f(100 * lo, 1), "%"), "R/09-payment-sim.R rate_of()")
reg(S, "band_hi", lo + wd, paste0(f(100 * (lo + wd), 0), "%"), "R/09-payment-sim.R rate_of()")
## Task S1.6: the Sep 30 "marginal incentive per eligible dollar" (w x 3.9%) is
## now the revenue exposure coefficient's per-eligible-dollar constant
mg <- 100 * 0.15 * 0.039
reg(S, "expo_pct", mg, paste0(f(mg, 3), "%"), "revenue exposure coefficient, R/09-payment-sim.R (w x 0.039)")
cs <- function(d) mean(d$cshare)
reg(S, "cs_sn", cs(HB[HB$safety_net, ]), f(cs(HB[HB$safety_net, ]), 3), "payment-by-hospital.csv")
reg(S, "cs_notsn", cs(HB[!HB$safety_net, ]), f(cs(HB[!HB$safety_net, ]), 3), "payment-by-hospital.csv")
reg(S, "cs_q5", cs(HB[HB$adi_q == 5, ]), f(cs(HB[HB$adi_q == 5, ]), 3), "payment-by-hospital.csv")
reg(S, "cs_q1", cs(HB[HB$adi_q == 1, ]), f(cs(HB[HB$adi_q == 1, ]), 3), "payment-by-hospital.csv")
reg(S, "c1_reproduced", c1, ci(c1), "stage 35 log"); reg(S, "c1_n", c1n, ci(c1n), "stage 35 log")
cm <- CAL[grepl("^main \\(re-shrunk", CAL$arm), ]; q1l <- CAL[CAL$arm == "main, lambda quartile 1", ]
reg(S, "c2_expected", cm$expected, ci(round(cm$expected)), "hacrp-calibration.csv")
reg(S, "c2_observed", cm$observed, ci(cm$observed), "hacrp-calibration.csv")
reg(S, "c2_n", cm$n, ci(cm$n), "hacrp-calibration.csv")
reg(S, "c2_auc", cm$auc, pc(cm$auc, 1), "hacrp-calibration.csv")
hai <- LOG("task4.2-payment-sim.txt", "HAI information alone.*?([0-9.]+)\\s+NA\\s+TRUE")
reg(S, "c2_auc_hai", hai, pc(hai, 1), "stage 35 log, post-hoc reference row")
reg(S, "c2_slope_q1", q1l$calib_slope, f(q1l$calib_slope, 2), "hacrp-calibration.csv")
reg(S, "slope_bar", c(0.8, 1.2), c("0.8", "1.2"), "provenance/payment-model-inputs.md sec 5.3 bar")
tot <- LOG("task4.2-payment-sim.txt", "^\\s+base \\(linear\\)\\s+total \\$\\s*(\\d+)M")
reg(S, "total_bn", tot / 1000, f(tot / 1000, 2), "stage 35 log, base scenario")
pb <- function(st, col) PBS[PBS$stratum == st, col]
for (st in c("adi_q1", "adi_q5", "s1m1", "s3m3", "unrated", "sn0", "sn1", "vb_q1", "vb_q5")) {
  reg(S, paste("rate", st), pb(st, "rate_pct"), paste0(f(pb(st, "rate_pct"), 2), "%"), "payment-by-stratum.csv")
  reg(S, paste("pay", st), pb(st, "pay_musd"), f(pb(st, "pay_musd"), 2), "payment-by-stratum.csv") }
reg(S, "share_bonus_q5", pb("adi_q5", "share_of_bonus_pct") / 100, pc(pb("adi_q5", "share_of_bonus_pct") / 100, 1), "payment-by-stratum.csv")
reg(S, "share_hosp_q5", pb("adi_q5", "share_of_hospitals_pct") / 100, pc(pb("adi_q5", "share_of_hospitals_pct") / 100, 0), "payment-by-stratum.csv")
reg(S, "share_bonus_sn", pb("sn1", "share_of_bonus_pct") / 100, pc(pb("sn1", "share_of_bonus_pct") / 100, 1), "payment-by-stratum.csv")
reg(S, "share_hosp_sn", pb("sn1", "share_of_hospitals_pct") / 100, pc(pb("sn1", "share_of_hospitals_pct") / 100, 1), "payment-by-stratum.csv")
reg(S, "n_unrated_pay", pb("unrated", "n"), ci(pb("unrated", "n")), "payment-by-stratum.csv")
reg(S, "dis_q1_k", pb("adi_q1", "dis_kusd"), ci(round(pb("adi_q1", "dis_kusd")) * 1000), "payment-by-stratum.csv ($)")
reg(S, "dis_q5_k", pb("adi_q5", "dis_kusd"), ci(abs(round(pb("adi_q5", "dis_kusd"))) * 1000), "payment-by-stratum.csv ($)")
for (i in 2:4) reg(S, paste("gap", GAPT$component[i]), GAPT$share_of_total[i], pc(GAPT$share_of_total[i], 1), "payment-gap-decomposition.csv")
reg(S, "npr_q5", GAPT$q5[2] / 1e6, ci(round(GAPT$q5[2] / 1e6)), "payment-gap-decomposition.csv")
reg(S, "npr_q1", GAPT$q1[2] / 1e6, ci(round(GAPT$q1[2] / 1e6)), "payment-gap-decomposition.csv")
## Task S1.6: the finite payment return replaces the marginal incentive and
## "headroom" is "distance from the best measured score"; the Sep 30 verdicts
## the prose states are recorded as claims, not asserted
RDIST <- "distance from the best measured score"
rgv <- function(sc, fr, rk) RG[RG$model_set == "primary (194)" & RG$scenario == sc & RG$framing == fr &
                               grepl("^finite payment return", RG$quantity) & RG$ranked_by == rk, ]
for (sc in c("base", "threshold", "cash2_sn", "fixed")) for (fr in c("per NPR dollar", "per hospital"))
  for (rk in c(RDIST, "model-implied disadvantage", "catchment ADI")) { x <- rgv(sc, fr, rk)
    for (col in c("mean", "lo", "hi")) reg(S, paste(sc, fr, rk, col), x[[col]], sg(x[[col]], 3), "regressivity.csv") }
claim(rgv("base", "per NPR dollar", "catchment ADI")$verdict == "regressive", "07: regressive by catchment ADI")
## Task S5.2: the claims the rewritten section 7 makes (the Sep 30 "neutral"
## and "flat share zeroes" claims are retired with that prose)
claim(rgv("base", "per NPR dollar", RDIST)$verdict == "no clear direction", "07: no clear direction against distance from the best score")
md0 <- rgv("base", "per NPR dollar", "model-implied disadvantage")
claim(md0$verdict == "regressive" && md0$hi > -0.001, "07: model-implied disadvantage on the edge (interval just excludes zero)")
claim(rgv("cash2_sn", "per NPR dollar", "catchment ADI")$verdict == "no clear direction", "07: ADI no clear direction under CASH2's 0.40 factor")
reg(S, "sn_factor", 0.4, "0.40", "CASH2 safety-net factor (scenario cash2_sn)")
bsv <- function(st) BS$ret_per_npr_bp[BS$stratum == st]
reg(S, "bp_q5", bsv("adi_q5"), f(bsv("adi_q5"), 2), "regressivity-by-stratum.csv")
reg(S, "bp_q1", bsv("adi_q1"), f(bsv("adi_q1"), 2), "regressivity-by-stratum.csv")
snr <- RG[RG$model_set == "primary (194)" & RG$scenario == "base" & RG$ranked_by == "safety-net / not (ratio of means)", ]
r_npr <- snr$mean[snr$framing == "per NPR dollar"]; r_h <- snr$mean[snr$framing == "per hospital"]
reg(S, "sn_ratio_npr", r_npr, f(r_npr, 2), "regressivity.csv"); reg(S, "sn_less_pct", 1 - r_npr, pc(1 - r_npr, 0), "regressivity.csv")
reg(S, "sn_ratio_hosp", r_h, f(r_h, 2), "regressivity.csv")
for (g in c("ADI Q5 / Q1", "safety-net / not", "model-implied Q5 / Q1")) { x <- OBS[OBS$group == "rate ratio" & OBS$stratum == g, ]
  for (col in c("share", "lo", "hi")) reg(S, paste("hacrp", g, col), x[[col]], f(x[[col]], 2), "observed-hacrp-regressivity.csv") }
for (st in c("s1m1", "s3m3")) { x <- OBS[grepl("^cells", OBS$group) & OBS$stratum == st, ]
  reg(S, paste("hacrp cell", st), x$share, pc(x$share, 1), "observed-hacrp-regressivity.csv") }
reg(S, "quintile_share", 0.2, "20%", "a fifth of hospitals")
reg(S, "alpha_pct", 95, c("95", "95%"), "95% interval")

# ==========================================================================
# SECTION 08  what remains open (section 09, limitations, until Task S5.2)
# ==========================================================================
S <- "08-open"
reg(S, "lambda_median", lam, c(f(lam, 3), pc(lam, 0)), "data/analytic-v2.rds, tau2 sample (scalar approximation)")
for (q in c("p05", "p25", "p75", "p95")) { v <- LOG("phase0-followup.txt", paste0(q, "=([0-9.]+)"))
  reg(S, paste("lambda", q), v, f(v, 2), "stage 1b log, lambda distribution") }
reg(S, "lambda_q1", qv$mean_lambda[1], f(qv$mean_lambda[1], 3), "reliability-by-volume.csv")
reg(S, "lambda_q4", qv$mean_lambda[4], f(qv$mean_lambda[4], 3), "reliability-by-volume.csv")
for (k in c("log Medicare volume", "rural indicator", "DSH patient pct", "Medicaid day share")) {
  v <- LOG("phase0-followup.txt", paste0("corr\\(lambda, ", k, "\\s*\\) = ([-+][0-9.]+)"))
  reg(S, paste("corr", k), v, sg(v, 2), "stage 1b log") }
for (k in c("RURAL", "NON-RURAL")) { v <- LOG("phase0-followup.txt", paste0("mean lambda  ", k, "\\s+([0-9.]+)"))
  reg(S, paste("lambda", k), v, f(v, 3), "stage 1b log") }
reg(S, "eiv_up", mean(e$delta > 0), pc(mean(e$delta > 0), 1), "spec-curve-reliability.csv")
reg(S, "n_psi13", cn[["psi13"]], ci(cn[["psi13"]]), "data/outcomes.rds")
reg(S, "n_frame", nrow(A), ci(nrow(A)), "data/analytic-v2.rds")
reg(S, "hsaf_threshold", thr, ci(thr), "stage 9 log")
reg(S, "hsaf_supp_share", sup / cells, pc(sup / cells, 2), "stage 9 log")
reg(S, "coverage_median", cov, pc(cov, 0), "data/catchment.rds")
reg(S, "supp_test_rmin", min(rs), f(floor(min(rs) * 1000) / 1000, 3), "stage 1b log")
reg(S, "supp_test_n", LOG("phase0-followup.txt", "hospitals in the comparison:\\s+(\\d+)"),
    ci(LOG("phase0-followup.txt", "hospitals in the comparison:\\s+(\\d+)")), "stage 1b log")
rth <- min(CC$r_catchtract_hsa[CC$covariate %in% c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng")])
reg(S, "r_tract_hsa_min", rth, f(rth, 2), "catchment-vs-county-correlation.csv, min over Table 3.1 rows")
reg(S, "n_fallback", fb, ci(fb), "data/catchment.rds"); reg(S, "share_fallback", fb / nrow(CAT), pc(fb / nrow(CAT), 2), "data/catchment.rds")
reg(S, "n_ct", sum(A$state == "CT"), ci(sum(A$state == "CT")), "data/analytic-v2.rds")
gap <- LOG("phase0-numbers.txt", "GAP = ([0-9.]+) years")
reg(S, "svi_gap", gap, f(gap, 1), "stage 1 log (Phase 0)")
reg(S, "tort_gap", as.numeric(gv("C3.c")), gv("C3.c"), "gate C3.c")
reg(S, "c1e", as.numeric(gv("C1.e")), gv("C1.e"), "gate C1.e")
cd <- CRG[CRG$covariate == "cmi_drift", ]; stopifnot(cd$straddles_zero)
reg(S, "n_cc_abc", ncc, ci(ncc), "complete-case A+B+C frame")
reg(S, "n_cc_left", nrow(A) - ncc, ci(nrow(A) - ncc), "frame minus complete-case frame")
reg(S, "n_specs_composite", sum(REGI$outcome == "composite"), ci(sum(REGI$outcome == "composite")), "spec-registry.csv")
reg(S, "tol_rel_state", tp$epsilon_rel[tp$unit == "state"], pc(tp$epsilon_rel[tp$unit == "state"], 1), "rashomon-tolerance.csv")
reg(S, "mcrB_state", gb$mcr_minus[gb$unit == "state"], f(gb$mcr_minus[gb$unit == "state"], 3), "mcr-bounds-blockB.csv")
reg(S, "width_lo", wp$est_min, sg(wp$est_min, 2), "rashomon-set-width.csv")
reg(S, "width_hi", wp$est_max, sg(wp$est_max, 2), "rashomon-set-width.csv")
for (col in c("share", "ci_lo", "ci_hi")) { v <- vd("^components", "", "community", col)
  reg(S, paste("vd comp community", col), v, c(pc(v, 1), sub("^-", "−", pc(v, 1))), "variance-decomposition.csv") }
## Task S2.1: the residual of the published-score fit is primary; it is
## conditional on the covariates, the complete-case frame and the loss
res_c <- vd("^composite", VW[["published"]], "residual")
reg(S, "residual", res_c, c(pc(res_c, 0), pc(res_c, 1)), "variance-decomposition.csv, published-score residual (conditional)")
res_w <- vd("^composite", VW[["weighted"]], "residual")
reg(S, "residual weighted", res_w, c(pc(res_w, 0), pc(res_w, 1)), "variance-decomposition.csv, reliability-weighted residual (sensitivity)")
reg(S, "n_unrated", as.numeric(un[3]), ci(as.numeric(un[3])), "stage 34 log")
reg(S, "unrated_share", as.numeric(un[3]) / nrow(A), pc(as.numeric(un[3]) / nrow(A), 1), "stage 34 log / frame")
stopifnot(sum(startsWith(HB$cshare_source, "cash2_fallback")) == 16)
reg(S, "c2_slope_q1", q1l$calib_slope, f(q1l$calib_slope, 2), "hacrp-calibration.csv")
reg(S, "slope_bar", c(0.8, 1.2), c("0.8", "1.2"), "payment-model-inputs.md sec 5.3 bar")
cl <- MISS[MISS$variable == "contract_labor_share", ]
reg(S, "cl_missing", cl$n_missing, ci(cl$n_missing), "missingness-audit.csv")
reg(S, "cl_pct", cl$pct_missing, paste0(f(cl$pct_missing, 1), "%"), "missingness-audit.csv")
reg(S, "n_joint", joint, ci(joint), "data/outcomes.rds")
## Task 5.6 verify: no limitation without its number where Phase 0 produced one.
## These are the renderings the rev-2 task sheet names; each must appear in section 09.
REQUIRED_09 <- c(lambda_median = f(lam, 3), lambda_q1 = f(qv$mean_lambda[1], 3),
                 corr_volume = sg(LOG("phase0-followup.txt", "corr\\(lambda, log Medicare volume\\s*\\) = ([-+][0-9.]+)"), 2),
                 svi_gap = f(gap, 1), tort_gap = gv("C3.c"), hsaf = pc(sup / cells, 2),
                 supp_r = f(floor(min(rs) * 1000) / 1000, 3), coverage = pc(cov, 0), fallback = ci(fb))

## Task S3.1: the inclusion flow (stage 43). Every keyed row must equal the
## frame count registered above for that key, or the stage stops.
IFL <- TB("inclusion-flow.csv")
for (i in which(nzchar(IFL$registry_key))) {
  k <- strsplit(IFL$registry_key[i], "|", fixed = TRUE)[[1]]
  r <- Filter(function(d) d$section[1] == k[1] && d$key[1] == k[2], REG)
  if (length(r) != 1) stop(sprintf("inclusion flow: %s matched %d registry entries", IFL$registry_key[i], length(r)))
  if (r[[1]]$value != IFL$n_after[i])
    stop(sprintf("inclusion flow does not reconcile: %s = %s, flow row %d (%s) = %s",
                 IFL$registry_key[i], r[[1]]$value, IFL$order[i], IFL$step[i], IFL$n_after[i]))
}
cat(sprintf("  inclusion flow: %d keyed rows reconcile to the registry\n", sum(nzchar(IFL$registry_key))))
MN <- TB("mnar-sensitivity.csv")
clraw <- read.csv(file.path("data", "blockC_contract_labor.csv"), colClasses = "character")
clraw <- suppressWarnings(as.numeric(clraw$contract_labor_share[match(A$ccn, clraw$ccn)]))
for (S in c("03-data", "08-open")) {
  for (i in seq_len(nrow(IFL))) { z <- IFL[i, ]; key <- paste("if", z$frame, z$step)
    reg(S, key, z$n_after, ci(z$n_after), "inclusion-flow.csv")
    if (is.finite(z$n_removed) && z$n_removed > 0) reg(S, paste(key, "removed"), z$n_removed, ci(z$n_removed), "inclusion-flow.csv") }
  reg(S, "cl orig missing", sum(is.na(clraw)), ci(sum(is.na(clraw))), "blockC_contract_labor.csv, missing after recovery")
  scr <- sum(!is.na(clraw) & (clraw < 0 | clraw > 0.5))
  reg(S, "cl screened", scr, ci(scr), "blockC_contract_labor.csv, outside [0, 0.50] (gate C2.d)")
  reg(S, "cl imputed", sum(is.na(A$contract_labor_share)), ci(sum(is.na(A$contract_labor_share))), "data/analytic-v2.rds")
  sdo <- sd(A$contract_labor_share, na.rm = TRUE)
  reg(S, "cl sd observed", sdo, c(f(sdo, 3), f(sdo, 4), pc(sdo, 1)), "data/analytic-v2.rds, SD of observed share")
  reg(S, "mnar deltas", c(0.5, 1), c("0.5", "1", "±0.5", "±1"), "second-pass-preregistration.md sec 7")
  for (i in seq_len(nrow(MN))) { z <- MN[i, ]
    key <- paste("mnar", z$anchor, sprintf("%+.1f", z$delta), if (z$clamped) "clamped" else "")
    reg(S, paste(key, "community"), z$community_share, c(pc(z$community_share, 1), pc(z$community_share, 2)), "mnar-sensitivity.csv, LMG share")
    reg(S, paste(key, "community change"), 100 * z$community_change, c(sg(100 * z$community_change, 2), f(abs(100 * z$community_change), 2)), "mnar-sensitivity.csv, percentage points")
    reg(S, paste(key, "mr"), z$mr_disadvantage, c(f(z$mr_disadvantage, 3), f(z$mr_disadvantage, 4)), "mnar-sensitivity.csv")
    reg(S, paste(key, "mr change"), z$mr_change, c(sg(z$mr_change, 4), f(abs(z$mr_change), 4)), "mnar-sensitivity.csv")
    reg(S, paste(key, "coef"), z$coef_contract_labor, c(sg(z$coef_contract_labor, 3), f(z$coef_contract_labor, 3)), "mnar-sensitivity.csv, per SD of observed share")
    reg(S, paste(key, "n_fit"), z$n_fit, ci(z$n_fit), "mnar-sensitivity.csv") }
}
## Task S3.2: the suppression sensitivity (stage 44); constants row by row,
## the 20 uniform draws as median and extreme over draws
SS <- TB("suppression-sensitivity.csv")
## Registered in section 09 only, and the loss and contrast (the same for every
## hospital group) once per allocation and grain: a registry this size would
## otherwise start matching unrelated numbers in the Sep 30 prose.
reg_ss <- function(sec, key, x) {
  if (x$group == "all") {
    reg(sec, paste(key, "loss pct"), x$loss_change_pct, paste0(c(sg(x$loss_change_pct, 2), f(abs(x$loss_change_pct), 2)), "%"), "suppression-sensitivity.csv")
    reg(sec, paste(key, "joint"), x$joint, c(sg(x$joint, 2), sg(x$joint, 3)), "suppression-sensitivity.csv, SD of PSI-90")
    reg(sec, paste(key, "joint change"), x$joint_change, c(sg(x$joint_change, 3), f(abs(x$joint_change), 3)), "suppression-sensitivity.csv, SD of PSI-90") }
  reg(sec, paste(key, "rho"), x$rank_spearman, c(f(x$rank_spearman, 3), f(x$rank_spearman, 4)), "suppression-sensitivity.csv")
  reg(sec, paste(key, "rank median"), x$rank_change_median, c(f(x$rank_change_median, 0), f(x$rank_change_median, 1)), "suppression-sensitivity.csv, positions")
  reg(sec, paste(key, "rank p90"), x$rank_change_p90, c(f(x$rank_change_p90, 0), f(x$rank_change_p90, 1)), "suppression-sensitivity.csv, positions")
  reg(sec, paste(key, "rank max"), x$rank_change_max, c(f(x$rank_change_max, 0), ci(round(x$rank_change_max))), "suppression-sensitivity.csv, positions")
  reg(sec, paste(key, "n"), x$n, ci(x$n), "suppression-sensitivity.csv")
  reg(sec, paste(key, "cov r min"), x$cov_r_min, f(x$cov_r_min, 3), "suppression-sensitivity.csv") }
for (S in "06-associations") {
  K <- SS[is.na(SS$draw), ]
  for (i in seq_len(nrow(K))) reg_ss(S, paste("ss", K$allocation[i], K$grain[i], K$group[i]), K[i, ])
  U <- SS[!is.na(SS$draw), ]
  for (g in unique(U$grain)) for (gn in unique(U$group)) { x <- U[U$grain == g & U$group == gn, ]
    md <- x[1, ]; for (col in c("loss_change_pct", "joint", "joint_change", "rank_spearman", "rank_change_median", "rank_change_p90", "rank_change_max", "cov_r_min")) md[[col]] <- median(x[[col]])
    reg_ss(S, paste("ss uniform median", g, gn), md)
    ex <- x[1, ]; ex$loss_change_pct <- x$loss_change_pct[which.max(abs(x$loss_change_pct))]
    ex$joint_change <- x$joint_change[which.max(abs(x$joint_change))]; ex$joint <- ex$joint_change + (md$joint - md$joint_change)
    ex$rank_spearman <- min(x$rank_spearman); ex$rank_change_median <- max(x$rank_change_median)
    ex$rank_change_p90 <- max(x$rank_change_p90); ex$rank_change_max <- max(x$rank_change_max); ex$cov_r_min <- min(x$cov_r_min)
    reg_ss(S, paste("ss uniform extreme", g, gn), ex) }
  reg(S, "ss fills", c(1, 3, 5.5, 10), c("1", "3", "5.5", "10"), "second-pass-preregistration.md sec 7")
  reg(S, "ss draws", 20, c("20", "twenty"), "second-pass-preregistration.md sec 7")
  reg(S, "ss uniform range", c(1, 10), c("1", "10"), "second-pass-preregistration.md sec 7")
}
## Task S3.3: ownership and system membership in Block A (stage 45), section 06 (Task S5.2)
OWN <- TB("ownership-sensitivity.csv")
for (i in seq_len(nrow(OWN))) { z <- OWN[i, ]; key <- paste("own", z$anchor, z$version)
  reg("06-associations", paste(key, "joint"), z$joint, c(sg(z$joint, 2), sg(z$joint, 3)), "ownership-sensitivity.csv, SD of PSI-90")
  reg("06-associations", paste(key, "community"), z$community_share, c(pc(z$community_share, 1), pc(z$community_share, 2)), "ownership-sensitivity.csv, LMG share")
  reg("06-associations", paste(key, "mr"), z$mr_disadvantage, c(f(z$mr_disadvantage, 3), f(z$mr_disadvantage, 4)), "ownership-sensitivity.csv")
  if (z$version != "as fitted") {
    b <- OWN[OWN$anchor == z$anchor & OWN$version == "as fitted", ]
    lc <- 100 * (z$loss / b$loss - 1)
    reg("06-associations", paste(key, "loss change pct"), lc, paste0(c(sg(lc, 2), f(abs(lc), 1), f(abs(lc), 2)), "%"), "ownership-sensitivity.csv")
    for (cf in c("government", "proprietary", "system")) {
      reg("06-associations", paste(key, "b", cf), z[[paste0("b_", cf)]], c(sg(z[[paste0("b_", cf)]], 3), f(abs(z[[paste0("b_", cf)]]), 3)), "ownership-sensitivity.csv, PSI-90 units")
      reg("06-associations", paste(key, "se", cf), z[[paste0("se_", cf)]], f(z[[paste0("se_", cf)]], 3), "ownership-sensitivity.csv") } } }
## Task S3.4: the cluster criteria together, the full table and the band
## alternatives (stage 46), section 07 only
CLS <- TB("cluster-summary.csv"); ACF <- TB("archetype-cells-full.csv"); ABS <- TB("archetype-bands-sensitivity.csv")
for (i in seq_len(nrow(CLS))) { z <- CLS[i, ]; key <- paste("cl", z$screen, z$version)
  reg("supp-archetypes", paste(key, "icl G"), z$icl_G, ci(z$icl_G), "cluster-summary.csv")
  reg("supp-archetypes", paste(key, "gap k"), z$gap_k, ci(z$gap_k), "cluster-summary.csv")
  if (is.finite(z$stability_agree)) reg("supp-archetypes", paste(key, "agreement"), z$stability_agree, pc(z$stability_agree, 0), "cluster-summary.csv") }
reg("supp-archetypes", "cl n primary", CLS$n[CLS$screen == "primary"][1], ci(CLS$n[CLS$screen == "primary"][1]), "cluster-summary.csv")
reg("supp-archetypes", "cl subsamples", c(100, 80), c("100", "80%"), "stage 33 log, stability design")
for (i in seq_len(nrow(ACF))) { z <- ACF[i, ]; key <- paste("cells", z$arm, z$safety, z$margin)
  reg("supp-archetypes", paste(key, "n"), z$n, ci(z$n), "archetype-cells-full.csv") }
for (arm in unique(ACF$arm)) { x <- ACF[ACF$arm == arm, ]; off <- sum(x$n[x$cell == "off-diagonal"])
  reg("supp-archetypes", paste("cells", arm, "off-diagonal"), off, ci(off), "archetype-cells-full.csv")
  reg("supp-archetypes", paste("cells", arm, "off-diagonal share"), off / sum(x$n), pc(off / sum(x$n), 1), "archetype-cells-full.csv")
  cr <- x$n[x$safety == 1 & x$margin == 3] + x$n[x$safety == 3 & x$margin == 1]
  reg("supp-archetypes", paste("cells", arm, "opposite corners"), cr, ci(cr), "archetype-cells-full.csv") }
for (i in which(ABS$row != "cell")) { z <- ABS[i, ]; key <- paste("bands", z$design, z$row)
  fmt <- if (z$row %in% c("gamma")) function(v) sg(v, 3) else if (z$row == "observed / expected") function(v) f(v, 2) else function(v) pc(v, 1)
  reg("supp-archetypes", key, z$estimate, fmt(z$estimate), "archetype-bands-sensitivity.csv")
  if (is.finite(z$ci_lo)) { reg("supp-archetypes", paste(key, "lo"), z$ci_lo, fmt(z$ci_lo), "archetype-bands-sensitivity.csv")
                            reg("supp-archetypes", paste(key, "hi"), z$ci_hi, fmt(z$ci_hi), "archetype-bands-sensitivity.csv") } }

# ==========================================================================
# Task S5.2: the rewritten report's own blocks. Section 02 (the question and
# CASH2), payment scenarios for section 07, and section 08 (what remains open);
# the Track material is folded into 02 and 08 from the supplement's block.
# ==========================================================================
copy_reg <- function(to, from, keys) for (k in keys) {
  r <- Filter(function(d) d$section[1] == from && d$key[1] == k, REG)
  if (length(r) != 1) stop(sprintf("copy_reg: %s / %s matched %d entries", from, k, length(r)))
  x <- r[[1]]; x$section <- to; x$source <- paste0(x$source, " (via ", from, ")"); REG[[length(REG) + 1]] <<- x }

## SECTION 02. The six CASH2 values are quoted external values: CASH2's own
## verification script, outside make.R and outside the repository (S3.5 note
## sec 1), so they are written here with the script's hash as their source.
S <- "02-question"
CASH2_SRC <- "quoted external value: CASH memo/Models/verify_models.py (sha256 e05e3946...cf63f05), rerun in Task S3.5"
for (x in list(c("roi vbp T1", 4.31), c("roi vbp T2", 10.38), c("roi vbp T3", 9.42),
               c("roi nobonus T1", 2.68), c("roi nobonus T2", 5.44), c("roi nobonus T3", 2.92)))
  reg(S, x[1], as.numeric(x[2]), x[2], CASH2_SRC)
reg(S, "n_tracks", 3, c("3", "three"), "CASH2's three Tracks (definition)")
for (i in 1:3) reg(S, paste("sn", i), sn$estimate[i], c(pc(sn$estimate[i], 1), pc(sn$estimate[i], 0)), "archetype-validation.csv")
copy_reg(S, "supp-archetypes", c("memo_sn", "memo_beds", "beds T3"))
for (i in c(1, 3)) for (col in c("ci_lo", "ci_hi")) copy_reg(S, "supp-archetypes", paste("sn", i, col))
copy_reg(S, "03-data", c("n_frame"))

## SECTION 03 additions: the limits the rewrite states at their point of use in
## the data section (Task 5.6's required Phase 0 numbers, now checked across
## sections 02-08 rather than in a limitations section)
reg("03-data", "lambda_q1_3dp", qv$mean_lambda[1], f(qv$mean_lambda[1], 3), "reliability-by-volume.csv")
reg("03-data", "lambda_q4_3dp", qv$mean_lambda[4], f(qv$mean_lambda[4], 3), "reliability-by-volume.csv")
v <- LOG("phase0-followup.txt", "corr\\(lambda, log Medicare volume\\s*\\) = ([-+][0-9.]+)")
reg("03-data", "corr log Medicare volume", v, sg(v, 2), "stage 1b log")
reg("03-data", "svi_gap", gap, f(gap, 1), "stage 1 log (Phase 0)")
reg("03-data", "tort_gap", as.numeric(gv("C3.c")), gv("C3.c"), "gate C3.c")

## SECTION 07 additions: every scenario's indices, ratio and total from
## payment-scenarios.csv, and the scenario verdict counts the prose cites
PSC <- TB("payment-scenarios.csv"); PSC <- PSC[PSC$model_set == "primary (194)", ]
S <- "07-payment"
for (i in seq_len(nrow(PSC))) { z <- PSC[i, ]
  key <- paste("ps", z$scenario, z$metric)
  if (z$metric %in% c("ci_retnpr_head", "ci_retnpr_vb", "ci_retnpr_adi"))
    for (col in c("mean", "lo", "hi")) reg(S, paste(key, col), z[[col]], c(sg(z[[col]], 3)), "payment-scenarios.csv")
  if (z$metric == "sn_ratio_retnpr")
    for (col in c("mean", "lo", "hi")) reg(S, paste(key, col), z[[col]], f(z[[col]], 2), "payment-scenarios.csv")
  if (z$metric == "total_pay") reg(S, paste(key, "bn"), z$mean / 1e9, c(f(z$mean / 1e9, 2), f(z$mean / 1e9, 1)), "payment-scenarios.csv, $ billion")
}
md_v <- RG[RG$model_set == "primary (194)" & RG$framing == "per NPR dollar" & grepl("^finite payment return", RG$quantity) &
           RG$ranked_by == "model-implied disadvantage", ]
oth <- md_v[md_v$scenario != "base", ]
reg(S, "n_other_scenarios", nrow(oth), ci(nrow(oth)), "regressivity.csv, scenarios other than base")
reg(S, "n_md_unclear", sum(oth$verdict == "no clear direction"), ci(sum(oth$verdict == "no clear direction")),
    "regressivity.csv, model-implied disadvantage verdicts other than base")
reg(S, "md_share_neg", md0$share_draws_negative, pc(md0$share_draws_negative, 1), "regressivity.csv, base, share of draws below zero")
reg(S, "md_hi_4dp", md0$hi, sg(md0$hi, 4), "regressivity.csv, base upper endpoint")
reg(S, "delta", 0.05, "0.05", "the finite improvement in PSI-90 (R/09-payment-sim.R)")
reg(S, "psi_weight", 0.15, c("15%", "0.15"), "CASH2 PSI-90 weight (payment-model-inputs.md)")
reg(S, "psi_weight_alt", c(0.10, 0.20), c("0.10", "0.20"), "PSI-90 weight scenarios")
reg(S, "rho", c(1.5, 2.0), c("1.5", "2.0"), "commercial price ratio scenarios")
reg(S, "curve_k", c(0.5, 2), c("0.5", "2"), "rate-curve exponent scenarios")
reg(S, "n_measures_scorecard", 6, c("6", "six"), "HACRP measures in the base scorecard")
reg(S, "penalty_pct", 0.01, "1%", "HACRP payment reduction")
reg(S, "n_frame_pay", nrow(HB), ci(nrow(HB)), "payment-by-hospital.csv")
reg(S, "pay_B", PS$B, ci(PS$B), "data/payment-sim.rds $B")
reg(S, "zero", 0, c("0", "$0"), "all-improve payment change, zero by construction (regressivity statement item 6)")
for (k in c(q5 = "per commercial dollar the return averages ([0-9.]+)% in the most", q1 = "fifth and ([0-9.]+)% in the least")) {
  v <- LOG("regressivity-statement.txt", k); reg(S, paste("ret per commercial", k), v / 100, paste0(f(v, 3), "%"), "regressivity statement item 5") }
reg(S, "n_hai", 5, "five", "HACRP infection measures") 
reg(S, "parity", 1, "1", "ratio of 1 = parity (definition)")

## SECTION 08: the Track instability (from the supplement's block) and the
## follow-ups; the rest of its registry is the former limitations block
S <- "08-open"
copy_reg(S, "supp-archetypes", c("cells star (primary) off-diagonal", "cells star (primary) off-diagonal share", "cl n primary"))
for (i in seq_len(nrow(CLS))) { z <- CLS[i, ]; if (z$screen != "primary") next
  key <- paste("cl", z$screen, z$version)
  reg(S, paste(key, "icl G"), z$icl_G, ci(z$icl_G), "cluster-summary.csv")
  reg(S, paste(key, "gap k"), z$gap_k, ci(z$gap_k), "cluster-summary.csv")
  if (is.finite(z$stability_agree)) reg(S, paste(key, "agreement"), z$stability_agree, pc(z$stability_agree, 0), "cluster-summary.csv") }
reg(S, "cl subsamples", c(100, 80), c("100", "80%"), "stage 33 log, stability design")
reg(S, "n_followups", 4, c("4", "four"), "provenance/follow-ups.md rows")
copy_reg(S, "07-payment", c("c2_slope_q1"))
copy_reg(S, "07-payment", c("slope_bar"))
copy_reg(S, "supp-archetypes", c("n_frame"))

## SECTION 01, the summary (S5.3 rewrites it; these keys follow the new layout)
for (S in "01-summary") {
  copy_reg(S, "03-data", c("n_frame", "hsaf_supp_share"))
  ## Task S2.1: published score first; every weighted key travels with its pair
  copy_reg(S, "05-decomposition", c(as.vector(outer(c("vd community", "vd community ci_lo", "vd community ci_hi",
                                                      "vd structure", "vd structure ci_lo", "vd structure ci_hi",
                                                      "vd residual", "vd_explained", "comm_of_expl", "struct_of_expl"),
                                                    c("published", "weighted"), paste)),
                                    "vd comp community share", "vd comp community ci_lo", "vd comp community ci_hi",
                                    "pub n_set hospital", "pub est_min hospital", "pub est_max hospital", "pub mcr_minus hospital",
                                    "width_lo", "width_hi", "alpha_pct"))
  copy_reg(S, "06-associations", c("mcrB_minus_pct"))
  reg_gv(S)
  reg_gc(S)
  copy_reg(S, "07-payment", c("base per NPR dollar catchment ADI mean", "base per NPR dollar catchment ADI lo", "base per NPR dollar catchment ADI hi",
                              "bp_q5", "bp_q1", "sn_ratio_npr",
                              "hacrp ADI Q5 / Q1 share", "hacrp ADI Q5 / Q1 lo", "hacrp ADI Q5 / Q1 hi"))
  copy_reg(S, "08-open", c("residual", "cl n primary"))
  ## Task S5.3: the summary's own citations, each copied from its section
  copy_reg(S, "03-data", c("n_cc_abc"))
  copy_reg(S, "05-decomposition", c("vd residual ci_lo published", "vd residual ci_hi published"))
  copy_reg(S, "04-methods", c("n_set", "contrast_percentiles"))
  copy_reg(S, "06-associations", c("mcrB minus state", "ss constant 10 catch_county low_decile rho",
                                   "ss constant 10 catch_county low_decile n", "gv repeats"))
  copy_reg(S, "07-payment", c("c2_n", "zero", "sn_factor", "base per NPR dollar model-implied disadvantage mean",
                              "base per NPR dollar model-implied disadvantage lo", "md_hi_4dp"))
  copy_reg(S, "supp-archetypes", c("n_frame"))
}

## ==========================================================================
## Task S5.4: the technical supplement's blocks (report/supplement/). Numbers
## computed in an earlier block are copied by key pattern; the rest are read
## from stage logs and tables here, or are named constants of a definition.
## ==========================================================================
copy_pat <- function(to, from, pat) { k <- unique(unlist(lapply(Filter(function(d) d$section[1] == from && grepl(pat, d$key[1]), REG), function(d) d$key[1])))
  if (!length(k)) stop(sprintf("copy_pat: no keys in %s match %s", from, pat)); copy_reg(to, from, k) }
defs <- function(sec, key, v, src) reg(sec, key, v, as.character(v), paste("definition:", src))

S <- "A-methods"
L22 <- function(p) LOG("task2.2-outcomes.txt", p)
reg(S, "slope theory", -0.5, "−0.50", "definition: interval width under pure sampling error falls with the square root of volume")
v <- LOG("phase0-followup.txt", "slope log\\(CI width\\) ~ log\\(volume\\)\\s+= ([-+][0-9.]+)"); reg(S, "ci slope", v, sg(v, 3), "stage 1b log")
v <- LOG("phase0-followup.txt", "corr\\(log CI width, log Medicare volume\\) = ([-+][0-9.]+)"); reg(S, "ci corr", v, sg(v, 3), "stage 1b log")
for (k in c(var_pub = "Var\\(published PSI-90, 2 dp\\)\\s+= ([0-9.]+)", mean_v = "mean implied posterior variance\\s+= ([0-9.]+)",
            tau2 = "implied prior variance tau\\^2\\s+= ([0-9.]+)")) reg(S, names(which(c(var_pub = k, mean_v = k, tau2 = k) == k))[1], L22(k), f(L22(k), 5), "stage 4 log (Task 2.2)")
reg(S, "tau", L22("\\(tau = ([0-9.]+)\\)"), f(L22("\\(tau = ([0-9.]+)\\)"), 4), "stage 4 log (Task 2.2)")
reg(S, "n_tau", L22("hospitals identifying tau2 \\(CI \\+ FY2026 volume \\+ beds\\): (\\d+)"), ci(L22("hospitals identifying tau2 \\(CI \\+ FY2026 volume \\+ beds\\): (\\d+)")), "stage 4 log")
for (q in c("p05", "p25", "med", "p75", "p95")) reg(S, paste("lambda", q), L22(paste0("n=2799.*?", q, "=([0-9.]+)")), f(L22(paste0("n=2799.*?", q, "=([0-9.]+)")), 3), "stage 4 log")
reg(S, "lambda mean", L22("mean lambda = ([0-9.]+)"), f(L22("mean lambda = ([0-9.]+)"), 3), "stage 4 log")
copy_reg(S, "03-data", c("n_frame", "corr log Medicare volume", "n_cc_abc", "n_fallback"))
defs(S, "z95", 1.96, "the 95% normal quantile in the interval-to-variance conversion"); defs(S, "two", 2, "interval half-width")
defs(S, "subsample cut", "0.60", "high-reliability subsample, lambda >= 0.60 (spec registry)")
reg(S, "naive grid", LOG("task3.5-spec-registry.txt", "full grid rows: (\\d+)"), ci(LOG("task3.5-spec-registry.txt", "full grid rows: (\\d+)")), "stage 17 log")
copy_reg(S, "04-methods", c("n_specs", "n_specs_blockB", "n_specs_composite", "n_set", "tol_B", "pub n_set hospital", "alpha_pct", "contrast_percentiles", "c1_reproduced", "c1_n", "gv repeats", "gv tolerance", "band_lo", "band_hi"))
reg(S, "n_fn2329", LOG("task3.5-spec-registry.txt", "drop_fn2329 removes (\\d+) hospitals"), ci(LOG("task3.5-spec-registry.txt", "drop_fn2329 removes (\\d+) hospitals")), "stage 17 log")
defs(S, "footnotes", c(23, 29), "CMS footnote codes"); reg(S, "mi_m", 20, "20", "data/blockC_mice.rds $m")
defs(S, "knots", c(5, 25, 50, 75, 95), "spline knot percentiles and winsorization percentiles")
defs(S, "small ints", c(1, 2, 3, 4, 6, 12, 19, 76), "worked example and formula constants (R/06-mcr.R hand case: theta (1,2,3,6), v (1,2,3,4), 76/12 = 19/3)")
reg(S, "loss_erm", tp$loss_erm[tp$unit == "hospital"], f(tp$loss_erm[tp$unit == "hospital"], 6), "rashomon-tolerance.csv")
reg(S, "eps", tp$epsilon[tp$unit == "hospital"], f(tp$epsilon[tp$unit == "hospital"], 6), "rashomon-tolerance.csv")
for (u in c("hospital", "cbsa", "state")) reg(S, paste("eps rel", u), tp$epsilon_rel[tp$unit == u], pc(tp$epsilon_rel[tp$unit == u], 2), "rashomon-tolerance.csv")
for (k in c("in-set: (\\d+)\\.\\.", "in-set: \\d+\\.\\.(\\d+)")) reg(S, paste("fe", k), LOG("task3.10-rashomon-set.txt", k), as.character(LOG("task3.10-rashomon-set.txt", k)), "stage 26 log")
v <- LOG("task3.10-rashomon-set.txt", "correlation\\(n_fe, loss\\) among composite specs: ([-+0-9.]+)"); reg(S, "fe corr", v, sg(v, 3), "stage 26 log")
reg(S, "pbest", 382, "382", "rashomon-published-subset.csv best_spec (P-best)")
v <- LOG("task3.11-mcr.txt", "MR -> 3\\s+got\\s+([0-9.]+)"); reg(S, "mr pop", v, f(v, 4), "stage 28 log")
reg(S, "vd_B", 1000, "1,000", "stage 22 log (B = 1000)")
copy_reg(S, "05-decomposition", c("cs support rule"))
defs(S, "n_states", 51, "state codes in the frame (50 states and DC)"); defs(S, "folds", 5, "folds per repeat")
reg(S, "repeat percentiles", c(2.5, 97.5), c("2.5", "97.5"), "definition")
defs(S, "pay consts", c(0.15, 0.001, 0.039, 0.5, 0.25, 0.75, 0.05, 0.10, 0.20, 0.40, 1.5, 2.0), "payment rule constants, R/09-payment-sim.R SCEN and rate_of()")
reg(S, "pay consts fmt", c(0.10, 0.20, 0.40, 2.0), c("0.10", "0.20", "0.40", "2.0"), "definition: payment scenario constants as printed")
reg(S, "zero", 0, "0", "definition")
copy_reg(S, "07-payment", c("c2_expected", "c2_observed", "c2_n"))

S <- "C-sensitivity"
copy_reg(S, "03-data", c("lambda_q1_3dp", "lambda_q4_3dp", "hsaf_suppressed", "n_cc_abc"))
copy_reg(S, "05-decomposition", c("n_curve", "curve_pos", "curve_med", "curve_possig", "width_lo", "width_hi"))
copy_pat(S, "06-associations", "^ss constant [0-9.]+ catch_(county|tract) (all|low_decile)")
copy_reg(S, "06-associations", c("ss fills", "ss draws", "ss uniform range"))
copy_pat(S, "06-associations", "^own ")
copy_pat(S, "03-data", "^mnar M_(best|median) [-+]1\\.0 +(community|mr)$|^mnar M_(best|median) \\+0\\.0 +(community|mr)$")
copy_reg(S, "03-data", c("cl sd observed", "cl imputed", "mnar deltas"))
copy_pat(S, "supp-archetypes", "^cells star \\(primary\\) ")
copy_reg(S, "08-open", c("cl n primary", "cl subsamples"))
copy_pat(S, "08-open", "^cl primary ")
reg(S, "mnar n_fit", 2700, "2,700", "mnar-sensitivity.csv n_fit")
reg(S, "anchors", c(80, 157, 344, 382, 610), c("80", "157", "344", "382", "610"), "anchor specification IDs (second-pass-preregistration.md sec 1)")
reg(S, "consts", c(0, 1, 4), c("0", "1", "4"), "definitions (shift of zero; star-band labels 1 to 2 and 4 to 5)")
x <- ACF[ACF$arm == "star (primary)", ]; reg(S, "diag", sum(x$n[x$cell != "off-diagonal"]), ci(sum(x$n[x$cell != "off-diagonal"])), "archetype-cells-full.csv, the three Track cells")
reg(S, "n_frame star", sum(x$n), ci(sum(x$n)), "archetype-cells-full.csv")
v <- max(abs(MN$community_change[!MN$clamped])) * 100; reg(S, "mnar max change", v, f(v, 2), "mnar-sensitivity.csv, largest change in percentage points")

## ==========================================================================
## Task S7.4: the October 7 audit's corrections. Every number the corrected
## prose adds, registered in each section that cites it, from the stage
## outputs S7.1-S7.3 wrote.
## ==========================================================================
regm <- function(secs, key, value, text, source) for (sc in secs) reg(sc, key, value, text, source)
## A9: the evaluation frame is not the fitting frame
RL <- TB("rashomon-loss.csv"); RL <- RL[RL$outcome == "composite" & RL$status == "ok", ]
regm(c("04-methods", "A-methods", "03-data"), "n_fit min", min(RL$n_fit), ci(min(RL$n_fit)), "rashomon-loss.csv, composite n_fit")
regm(c("04-methods", "A-methods", "03-data"), "n_fit max", max(RL$n_fit), ci(max(RL$n_fit)), "rashomon-loss.csv, composite n_fit")
regm(c("04-methods", "06-associations"), "n_cc_abc", ncc, ci(ncc), "complete-case A+B+C frame")
CSA <- TB("contrast-support.csv")
n_hsa <- CSA$n_frame[CSA$grain == "hsa"][1]
regm(c("06-associations", "A-methods"), "n hsa anchor", n_hsa, ci(n_hsa), "contrast-support.csv n_frame, spec 458")
regm("A-methods", "grain siblings", c(344, 420, 458), c("344", "420", "458"), "contrast-support.csv spec_id")
## A2: the published-score set, calibrated on its own (stage 27 sec 6b, stage 30)
TP7 <- TB("rashomon-tolerance-published.csv"); tpu <- function(u, col) TP7[TP7$unit == u, col]
regm(c("04-methods", "06-associations", "A-methods", "01-summary"), "pubcal n_unweighted", sum(RL$reliability == "unweighted"),
     ci(sum(RL$reliability == "unweighted")), "rashomon-loss.csv, unweighted composite specifications")
regm(c("04-methods", "06-associations", "A-methods", "01-summary"), "pubcal erm", tpu("hospital", "erm_spec"), as.character(tpu("hospital", "erm_spec")),
     "rashomon-tolerance-published.csv erm_spec")
for (u in c("hospital", "cbsa", "state")) {
  regm(c("04-methods", "A-methods"), paste("pubcal eps rel", u), tpu(u, "epsilon_rel"), c(pc(tpu(u, "epsilon_rel"), 1), pc(tpu(u, "epsilon_rel"), 2)),
       "rashomon-tolerance-published.csv")
  regm(c("04-methods", "06-associations", "A-methods", "01-summary"), paste("pubcal n", u), tpu(u, "n_members"), ci(tpu(u, "n_members")),
       "rashomon-tolerance-published.csv n_members")
}
regm("A-methods", "pubcal loss", tpu("hospital", "loss_erm"), f(tpu("hospital", "loss_erm"), 6), "rashomon-tolerance-published.csv loss_erm")
regm("A-methods", "pubcal above full erm", tpu("hospital", "loss_erm") / tp$loss_erm[tp$unit == "hospital"] - 1,
     pc(tpu("hospital", "loss_erm") / tp$loss_erm[tp$unit == "hospital"] - 1, 2), "published ERM loss over the full ERM's")
PUB7 <- TB("rashomon-published-subset.csv")
pcb <- function(u, col) PUB7[PUB7$unit == u & PUB7$members == "published" & PUB7$group == "blockB_disadvantage", col]
for (u in c("hospital", "cbsa", "state")) {
  stopifnot(pcb(u, "n_models") == tpu(u, "n_members"))
  for (col in c("mcr_minus", "mcr_plus")) regm(c("06-associations", "01-summary"), paste("pubcal", col, u), pcb(u, col), f(pcb(u, col), 3), "rashomon-published-subset.csv, members = published")
  for (col in c("est_min", "est_max")) regm(c("06-associations", "01-summary"), paste("pubcal", col, u), pcb(u, col), c(sg(pcb(u, col), 2), sg(pcb(u, col), 3)), "rashomon-published-subset.csv, members = published")
}
claim(all(sapply(c("hospital", "cbsa", "state"), pcb, col = "mcr_minus") > 1), "06: published-score set's reliance bound above 1 at all three tolerances")
claim(pcb("hospital", "est_min") < 0 && pcb("hospital", "est_max") > 0, "06: published-score set's contrast range straddles zero")
## A4: nearest-neighbor support, corrected (stage 41)
cn <- function(g, e, col) CSA[CSA$grain == g & CSA$quantity == "support" & CSA$profile == "joint" & CSA$end == e, col]
regm(c("06-associations", "A-methods"), "nn county most", cn("catch_county", "most", "nn_distance"), f(cn("catch_county", "most", "nn_distance"), 2), "contrast-support.csv nn_distance (corrected, S7.2)")
regm(c("06-associations", "A-methods"), "nn county p95", cn("catch_county", "most", "nn_obs_p95"), f(cn("catch_county", "most", "nn_obs_p95"), 2), "contrast-support.csv nn_obs_p95")
regm(c("06-associations", "A-methods", "01-summary"), "nn county most share", cn("catch_county", "most", "nn_share_obs_as_isolated"),
     pc(cn("catch_county", "most", "nn_share_obs_as_isolated"), 1), "contrast-support.csv nn_share_obs_as_isolated")
regm("A-methods", "nn county least", cn("catch_county", "least", "nn_distance"), f(cn("catch_county", "least", "nn_distance"), 2), "contrast-support.csv nn_distance")
regm("A-methods", "nn county least share", cn("catch_county", "least", "nn_share_obs_as_isolated"),
     pc(cn("catch_county", "least", "nn_share_obs_as_isolated"), 1), "contrast-support.csv")
claim(cn("catch_county", "most", "nn_distance") > cn("catch_county", "most", "nn_obs_p95"), "06: county most-disadvantaged end farther from observed profiles than the observed NN p95")
## A5: raw outcome differences beside the fitted decile contrasts
for (pn in c("material", "composition")) { v <- CSA$raw_outcome_diff[CSA$grain == "catch_county" & is.finite(CSA$raw_outcome_diff) & CSA$profile == pn]
  regm("06-associations", paste("raw decile diff", pn), v, c(sg(v, 2), f(abs(v), 2)), "contrast-support.csv raw_outcome_diff (S7.2)") }
## A1/A3/A12: the components frame, paired differences, other community quantities (stage 22)
VX <- TB("variance-decomposition-extra.csv")
vx <- function(k) VX$est[VX$key == k]
regm(c("05-decomposition", "A-methods"), "community alone", vx("alone"), pc(vx("alone"), 1), "variance-decomposition-extra.csv")
regm(c("05-decomposition", "A-methods"), "community added last", vx("added_last"), pc(vx("added_last"), 1), "variance-decomposition-extra.csv")
regm(c("05-decomposition", "A-methods"), "community fitted var", vx("fitted_term_var"), pc(vx("fitted_term_var"), 1), "variance-decomposition-extra.csv")
regm(c("05-decomposition", "A-methods"), "community fitted sd", vx("fitted_term_sd"), f(vx("fitted_term_sd"), 2), "variance-decomposition-extra.csv")
regm(c("A-methods"), "vd community published", vd("^composite", "^published", "community"), pc(vd("^composite", "^published", "community"), 1), "variance-decomposition.csv")
for (k in VX$key[VX$kind == "paired_difference"]) for (col in c("est", "lo", "hi")) { v <- VX[[col]][VX$key == k]
  regm(c("05-decomposition", "01-summary"), paste("pdiff", k, col), v, c(pc(v, 1), sub("^-", "−", pc(v, 1)), pc(v, 2), sub("^-", "−", pc(v, 2)), sg(100 * v, 1)), "variance-decomposition-extra.csv, paired bootstrap") }
for (col in c("share", "ci_lo", "ci_hi")) { v <- vd("^components", "", "community", col)
  regm(c("A-methods"), paste("vd comp community", col), v, c(pc(v, 1), sub("^-", "−", pc(v, 1)), pc(v, 2), sub("^-", "−", pc(v, 2))), "variance-decomposition.csv, components model") }
COMPS7 <- c("psi03", "psi06", "psi12", "psi13")
rows_all <- sum(sapply(COMPS7, function(cp) { y <- suppressWarnings(as.numeric(A[[cp]])); w <- suppressWarnings(as.numeric(A[[paste0(cp, "_denom")]]))
  is.finite(y) & is.finite(w) & w > 0 }))
rows_cc <- LOG("task3.3-variance-decomposition.txt", "components frame \\(complete on every covariate of every block\\): (\\d+) component rows")
regm(c("05-decomposition", "A-methods"), "comp rows all", rows_all, ci(rows_all), "data/analytic-v2.rds, component rows with an outcome and a positive denominator (the October 7 null model's frame)")
regm(c("05-decomposition", "A-methods"), "comp rows frame", rows_cc, ci(rows_cc), "stage 22 log, components frame")
## A6: the all-improve reference (stage 37)
AIR7 <- TB("all-improve-reference.csv"); afx <- AIR7[AIR7$reference == "fixed at original", ]
regm(c("07-payment", "A-methods", "01-summary"), "allimp fixed ref positions", afx$n_rank_changes, ci(afx$n_rank_changes), "all-improve-reference.csv")
regm(c("07-payment", "A-methods", "01-summary"), "allimp fixed ref change", afx$total_change / 1e6, f(abs(afx$total_change) / 1e6, 1), "all-improve-reference.csv, $ million")
regm(c("07-payment", "A-methods", "01-summary"), "n_frame_pay", afx$n_hospitals, ci(afx$n_hospitals), "all-improve-reference.csv")
regm("A-methods", "n no infection", afx$n_no_infection, ci(afx$n_no_infection), "all-improve-reference.csv, scored on PSI-90 alone")
## A12: basis points for the 0.05 step itself
for (st in c("adi_q5", "adi_q1")) regm(c("07-payment"), paste("bp step", st), bsv(st) * 0.05, f(bsv(st) * 0.05, 2), "regressivity-by-stratum.csv x 0.05")
## A2: the fixed-score payment run beside the base run, in the summary and supplement
psf <- function(sc, m, col = "mean") PSC[PSC$scenario == sc & PSC$metric == m, col]
regm(c("C-sensitivity", "01-summary"), "fixed adi", psf("fixed", "ci_retnpr_adi"), sg(psf("fixed", "ci_retnpr_adi"), 3), "payment-scenarios.csv, fixed")
regm(c("C-sensitivity", "01-summary"), "fixed sn", psf("fixed", "sn_ratio_retnpr"), f(psf("fixed", "sn_ratio_retnpr"), 2), "payment-scenarios.csv, fixed")
regm(c("C-sensitivity", "01-summary"), "base adi", psf("base", "ci_retnpr_adi"), sg(psf("base", "ci_retnpr_adi"), 3), "payment-scenarios.csv, base")
regm(c("C-sensitivity", "01-summary"), "base sn", psf("base", "sn_ratio_retnpr"), f(psf("base", "sn_ratio_retnpr"), 2), "payment-scenarios.csv, base")
for (col in c("mean", "lo", "hi")) regm("01-summary", paste("fixed vb", col), psf("fixed", "ci_retnpr_vb", col), sg(psf("fixed", "ci_retnpr_vb", col), 3), "payment-scenarios.csv, fixed")
claim(psf("fixed", "ci_retnpr_adi") < 0 && psf("base", "ci_retnpr_adi") < 0, "07: ADI concentration negative under both fixed and drawn scores")
copy_reg("01-summary", "07-payment", "parity")
copy_reg("01-summary", "04-methods", "gv tolerance")
## the sources sections: no quantities

S <- "D-registry"
for (i in 1:8) { sec <- c("01-summary", "02-question", "03-data", "04-methods", "05-decomposition", "06-associations", "07-payment", "08-open")[i]
  nr <- sum(vapply(REG, function(d) d$section[1] == sec, logical(1))); reg(S, paste("rows", sec), nr, ci(nr), "registry rows in this run") }

REGDF <- do.call(rbind, REG)
write.csv(REGDF, file.path("output", "tables", "report-numbers.csv"), row.names = FALSE)
cat(sprintf("  registry: %d numbers across %d section(s) -> output/tables/report-numbers.csv\n",
            nrow(REGDF), length(unique(REGDF$section))))
if (ncc != 2569) cat(sprintf("  NOTE: complete-case A+B+C frame is %d here; Task 3.2/3.9 report 2,569\n", ncc))

# ==========================================================================
# THE CHECK  --  every numeric token in a drafted section must be registered
# ==========================================================================
EXEMPT <- c("`[^`]*`",                                        # code spans
            "\\d{4}-\\d{2}-\\d{2}", "PSI-\\d+", "SVI \\d", "FY \\d{4}", "\\b(19|20)\\d{2}\\b(?!,\\d)",
            "Tables? \\d+(\\.\\d+)?", "Figures? \\d+", "sections? \\d+(\\.\\d+)?( (through|and|to) \\d+)?",
            "Task \\d+\\.\\d+", "^#+ \\d+(\\.\\d+)?",
            ## Task S5.4: the supplement's own cross-references (Figure S3, Table S2, A.4)
            "Figures? S\\d+", "Tables? S\\d+", "\\b[A-F]\\.\\d+\\b",
            ## Task S7.4: dates written out (the October 7 audit)
            "(January|February|March|April|May|June|July|August|September|October|November|December) \\d{1,2}\\b", "Block [ABC]", "ZIP\\+4", "theme \\d", "Model \\d", "CASH2", "\\d(\u2013\\d)? stars?", "Tracks? \\d( / \\d / \\d)?", "\\d\u2013\\d stars?")
norm <- function(x) { x <- gsub("−", "-", x); x <- sub("^\\+", "", x); x }
check_section <- function(sec) {
  path <- file.path("report", paste0(sec, ".md"))
  if (!file.exists(path)) path <- file.path("report", "supplement", paste0(sec, ".md"))   # Task S5.4
  if (!file.exists(path)) { cat(sprintf("  %-10s not drafted yet -- skipped\n", sec)); return(TRUE) }
  txt <- readLines(path, warn = FALSE)
  ok_texts <- norm(trimws(unlist(strsplit(REGDF$text[REGDF$section == sec], " \\| "))))
  bad <- character(0); n_tok <- 0
  for (i in seq_along(txt)) {
    line <- txt[i]
    for (p in EXEMPT) line <- gsub(paste0("(?i)", p), " ", line, perl = TRUE)
    tok <- regmatches(line, gregexpr("[+−-]?\\d[\\d,]*(\\.\\d+)?%?", line, perl = TRUE))[[1]]
    tok <- sub("[,.]$", "", tok)
    n_tok <- n_tok + length(tok)
    miss <- tok[!(norm(tok) %in% ok_texts | sub("^-", "", norm(tok)) %in% ok_texts)]
    if (length(miss)) bad <- c(bad, sprintf("line %d: %s", i, paste(unique(miss), collapse = ", ")))
  }
  cat(sprintf("  %-10s %d numeric tokens, %d unregistered\n", sec, n_tok, length(bad)))
  for (b in bad) cat("      ", b, "\n")
  length(bad) == 0
}
## Task S5.4: every drafted section file is checked, registry block or not, so a
## supplement section with no block fails on its first number instead of passing unread
FILES_SEC <- c(sub("\\.md$", "", list.files("report", pattern = "^[0-9][0-9]-.*\\.md$")),
               sub("\\.md$", "", list.files(file.path("report", "supplement"), pattern = "^[A-Z]-.*\\.md$")))
res <- vapply(union(unique(REGDF$section), FILES_SEC), check_section, logical(1))

## Plan sec 9 / Task 5.5 verify: "structurally regressive" is a claim about
## the arithmetic of the incentive formula and must say so wherever it appears.
## Mechanically: every sentence that uses the phrase also uses "arithmetic".
sr_ok <- TRUE
for (path in list.files(c("report", file.path("report", "supplement")), pattern = "\\.md$", full.names = TRUE)) {
  txt <- paste(readLines(path, warn = FALSE), collapse = " ")
  sents <- unlist(strsplit(txt, "(?<=[.;])\\s+(?=[A-Z])", perl = TRUE))
  hit <- sents[grepl("structurally regressive", sents, ignore.case = TRUE)]
  bad <- hit[!grepl("arithmetic", hit, ignore.case = TRUE)]
  cat(sprintf("  %-28s 'structurally regressive' in %d sentence(s), %d without 'arithmetic'\n", basename(path), length(hit), length(bad)))
  for (b in bad) cat("      ", substr(b, 1, 160), "\n")
  if (length(bad)) sr_ok <- FALSE
}
res <- c(res, structurally_regressive = sr_ok)

## Standing rule 3 / plan sec 9 / Task 5.7 verify: no causal verbs anywhere in
## the report text, negated or not. Technical names are exempt by pattern.
CAUSAL <- "\\b(caus(e|es|ed|ing)|driv(e|es|en|ing)|drivers?|leads? to|led to|results? in|resulted in|impacts?|impacted)\\b"
CAUSAL_OK <- c("driver script", "Impact Files?", "`https?://[^`]*`")   # October 13 audit: reference links
cv_ok <- TRUE
for (path in list.files(c("report", file.path("report", "supplement")), pattern = "\\.md$", full.names = TRUE)) {
  L <- readLines(path, warn = FALSE)
  for (p in CAUSAL_OK) L <- gsub(p, " ", L)
  h <- grep(CAUSAL, L, ignore.case = TRUE, perl = TRUE)
  for (i in h) cat(sprintf("  CAUSAL VERB %s line %d: %s\n", basename(path), i,
                           regmatches(L[i], regexpr(paste0(".{0,30}", CAUSAL, ".{0,30}"), L[i], ignore.case = TRUE, perl = TRUE))))
  if (length(h)) cv_ok <- FALSE
}
cat(sprintf("  causal-verb scan over report/*.md: %s\n", if (cv_ok) "none found" else "FOUND (above)"))
res <- c(res, no_causal_verbs = cv_ok)
## Task S5.2: limits are stated at their point of use, so Task 5.6's required
## Phase 0 numbers are looked for across sections 02-08, not in one section
MAIN <- file.path("report", c("02-question.md", "03-data.md", "04-methods.md", "05-decomposition.md",
                              "06-associations.md", "07-payment.md", "08-open.md"))
if (all(file.exists(MAIN))) {
  tmain <- paste(unlist(lapply(MAIN, readLines, warn = FALSE)), collapse = " ")
  missr <- REQUIRED_09[!vapply(REQUIRED_09, function(x) grepl(x, tmain, fixed = TRUE), logical(1))]
  cat(sprintf("  sections 02-08: %d of %d required Phase 0 numbers present%s\n", length(REQUIRED_09) - length(missr),
              length(REQUIRED_09), if (length(missr)) paste0(" -- MISSING: ", paste(names(missr), collapse = ", ")) else ""))
  res <- c(res, limitations_numbers = !length(missr))
}
## Task S2.1 verify, in the prose: (a) a paragraph that cites a reliability-
## weighted decomposition share also cites its published-score pair; (b) a
## section that cites the composite community share also cites the components
## model's community share (equal prominence).
para_split <- function(path) { L <- readLines(path, warn = FALSE); L[nzchar(trimws(L))] }
## a rendering as a whole token: "3.3%" must not match inside "33.3%"
has_tok <- function(x, P) grepl(paste0("(?<![0-9.])", gsub(".", "\\.", x, fixed = TRUE)), P, perl = TRUE)
pair_ok <- TRUE
for (sec in intersect(unique(REGDF$section), sub("\\.md$", "", list.files(c("report", file.path("report", "supplement")), pattern = "\\.md$")))) {
  pp <- file.path("report", paste0(sec, ".md")); if (!file.exists(pp)) pp <- file.path("report", "supplement", paste0(sec, ".md"))
  P <- para_split(pp)
  for (b in c("community", "structure", "residual")) {
    w <- pc(vd("^composite", VW[["weighted"]], b), 1); u <- pc(vd("^composite", VW[["published"]], b), 1)
    hit <- which(has_tok(w, P) & grepl("reliab|\u03bb|weight|corrected", P, ignore.case = TRUE) & !has_tok(u, P))
    for (i in hit) { pair_ok <- FALSE
      cat(sprintf("  WEIGHTED WITHOUT PUBLISHED %s: %s %s cited without %s -- \"%s...\"\n", sec, b, w, u, substr(P[i], 1, 90))) }
  }
  T <- paste(P, collapse = " ")
  cu <- pc(vd("^composite", VW[["published"]], "community"), 1); cw <- pc(vd("^composite", VW[["weighted"]], "community"), 1)
  kc <- vd("^components", "", "community")
  cites <- (has_tok(cu, P) | has_tok(cw, P)) & grepl("communit", P, ignore.case = TRUE) & grepl("variation|variance", P)
  if (any(cites) && !any(has_tok(pc(kc, 1), T), has_tok(pc(kc, 2), T))) { pair_ok <- FALSE
    cat(sprintf("  COMPONENTS SHARE MISSING %s: composite community share cited, components share (%s) not\n", sec, pc(kc, 2))) }
}
cat(sprintf("  published score beside every weighted share, components beside the composite: %s\n",
            if (pair_ok) "yes" else "NO (above)"))
res <- c(res, weighted_with_published = pair_ok)

## Task S2.1 verify, in the regenerated text: no stage log says the intervals
## reveal or recover how much CMS shrank a hospital, or reads the weighted
## result as what smoothing concealed.
SHRINK_BAD <- c("reveal", "conceal", "the composite hides", "recovers? about [0-9]+% of the true",
                "un-attenuat", "signature of an interval", "what (CMS.s )?(reliability )?smoothing",
                ## Task S2.3: the credible-model and imputation wording, in generated text too
                "every credible model", "no credible model", "no near-optimal model",
                "MI (is )?licensed|licenses MI|MI NOT licensed", "MI is unbiased")
gen_ok <- TRUE
for (lg in list.files(file.path("output", "tables"), pattern = "\\.txt$", full.names = TRUE)) {
  if (basename(lg) == "report-numbers.txt") next
  L <- readLines(lg, warn = FALSE)
  for (pt in SHRINK_BAD) for (i in grep(pt, L, ignore.case = TRUE, perl = TRUE)) { gen_ok <- FALSE
    cat(sprintf("  SHRINKAGE-RECOVERY TEXT %s line %d: %s\n", basename(lg), i, trimws(substr(L[i], 1, 100)))) }
}
cat(sprintf("  stage logs free of shrinkage-recovery language: %s\n", if (gen_ok) "yes" else "NO (above)"))
res <- c(res, generated_text_shrinkage = gen_ok)
## Task S2.3: claim guards. The number check above cannot tell when a correct
## number carries an unsupported meaning (review 2026-10-01); these rules catch
## the meanings the review retired. Each rule is a sentence-level pattern, and
## a rule may require a second pattern in the same sentence (`with`) or forbid
## one (`unless`); `para` widens `with` to the whole paragraph. The guard runs
## twice: on the Sep 30 prose kept in tools/claim-guard/sep30/, where every
## rule the review names must fire (else the guard has gone blind and the stage
## stops), and on report/, where any hit fails the stage.
mb_p <- MB[MB$group == "blockB_disadvantage" & MB$unit == "hospital", "mcr_minus"]
mb_s <- MB[MB$group == "blockB_disadvantage" & MB$unit == "state", "mcr_minus"]
GUARD <- list(
  every_credible = list(re = "\\bevery (one of the [0-9,]+ |single )?credible models?\\b"),
  no_credible    = list(re = "\\bno credible models?\\b"),
  ## the same universal claim without the word: the set read as every model
  ## the data admit rather than the fitted members examined
  universal_set  = list(re = paste0("\\bevery model (that|which) fits|\\bevery model the (data|evidence)|",
                                    "(models?|data|evidence)[^.;]{0,30}(cannot|can't|could not) (rule out|tell apart|distinguish)|",
                                    "none of them can do without|\\bno near-optimal model")),
  reveal_shrink  = list(re = "\\breveal", with = "shr[ia]nk|shrunk|smooth|reliab|λ|lambda|interval"),
  neutral        = list(re = "\\bneutral\\b", unless = "no clear direction"),
  conservative   = list(re = "\\bconservative\\b",
                        with = "bias|result|estimate|understat|overstat|attenuat|direction|error|toward zero"),
  imputation     = list(re = "\\blicen[cs]\\w*|\\bunbiased\\b", para = TRUE,
                        with = "imput|\\bMI\\b|missing at random|\\bMAR\\b"),
  no_precedent   = list(re = "\\bno precedent|without precedent|\\bunprecedented|\\bfirst (study|analysis|application) to\\b"),
  confidence_set = list(re = "confidence set|confidence region", also = "(Rashomon|tolerance)[^.]*\\bconfidence\\b"),
  bound_alone    = list(re = paste0("(?<![0-9.])", gsub(".", "\\.", f(mb_p, 3), fixed = TRUE), "|(?<![0-9.])",
                                    gsub(".", "\\.", pc(mb_p - 1, 1), fixed = TRUE)),
                        with = "relian|scrambl|MCR", unless = gsub(".", "\\.", f(mb_s, 3), fixed = TRUE)),
  ## Task S3.4: the clustering read as finding no groups, a criterion quoted
  ## without the other, and the Leapfrog access wording
  separated_groups = list(re = "\\bno (clearly )?(separated|separate|distinct) (groups|clusters)|\\bseparated (groups|clusters)"),
  icl_alone      = list(re = "\\bICL\\b", unless = "gap statistic"),
  gap_alone      = list(re = "\\bgap statistic\\b", unless = "\\bICL\\b|Estimating the number of clusters"),
  leapfrog_sold  = list(re = "\\bsold (rather than|, not|and not) published|\\bsold, not published")
)
## October 7 audit: the meanings that audit retired. Each must fire on the
## Oct 7 prose kept in tools/claim-guard/oct7/, as the Sep 30 rules must on
## theirs, so that passing the old guards is never read as passing the new ones.
OBH <- TB("observed-hacrp-regressivity.csv"); ob_a <- OBH[OBH$stratum == "ADI Q5 / Q1", ]
GUARD_OCT7 <- list(
  variance_ceiling = list(re = "\\bceiling\\b|between nothing and about one twentieth|somewhere between nothing",
                          with = "communit|adjust|variation|varian|share", unless = "\\bno ceiling|read as a ceiling"),
  real_places      = list(re = "describes? real (places|catchments)|describes existing places", unless = "said to describe"),
  fitted_as_observed = list(re = "rather than read from the models|decile-mean observed|observed contrasts?\\b[^.]*decile"),
  equivalence      = list(re = "\\bequivalen(t|ce)\\b", with = "1%|margin|tolerance|full block|held-out|repeat",
                          unless = "(not|rather than) a (formal )?(statistical )?equivalence test|tolerance called equivalence|\\bno equivalence|without an equivalence range"),
  cash2_specified  = list(re = "as CASH2 specified it|CASH2-specified rule"),
  relative_zero    = list(re = "cannot fund improvement|any purely relative rule|(pays?|payment)[^.]{0,60}\\$0",
                          unless = "reference|recalculat|restandardi"),
  sensitivity_only = list(re = "bears on the sensitivity analyses only|every primary result uses the published score"),
  rr_bootstrap     = list(re = paste0(gsub(".", "\\.", f(ob_a$lo, 2), fixed = TRUE), " to ", gsub(".", "\\.", f(ob_a$hi, 2), fixed = TRUE),
                                      "|rate ratio|penaliz"), with = "bootstrap"),
  fitted_and_scored = list(re = "fitted and scored on|every composite model is fitted|that every composite model is fitted"),
  components_all   = list(re = "across all [0-9,]+ hospitals", with = "component"),
  cov_positive     = list(re = "covariances?( among the components)? (are|is) positive|\\bbiased low\\b|too low",
                          with = "reliab|λ|lambda|covarian", unless = "not establish|does not show|do not show|conditional|assum")
)
GUARD <- c(GUARD, GUARD_OCT7)
## the rules the review names, which must fire on the Sep 30 prose
GUARD_MUST <- c("every_credible", "no_credible", "universal_set", "reveal_shrink", "neutral", "conservative",
                "imputation", "no_precedent", "bound_alone", "separated_groups", "leapfrog_sold")
run_guard <- function(dir) {
  hits <- list()
  for (path in list.files(dir, pattern = "\\.md$", full.names = TRUE)) {
    P <- readLines(path, warn = FALSE); P <- P[nzchar(trimws(P))]
    for (pi in seq_along(P)) {
      S_ <- unlist(strsplit(P[pi], "(?<=[.;])\\s+(?=[A-Z(])", perl = TRUE))
      for (rn in names(GUARD)) { g <- GUARD[[rn]]
        for (s in S_) {
          m <- grepl(g$re, s, ignore.case = TRUE, perl = TRUE) ||
               (!is.null(g$also) && grepl(g$also, s, ignore.case = TRUE, perl = TRUE))
          if (m && !is.null(g$with))
            m <- grepl(g$with, if (isTRUE(g$para)) P[pi] else s, ignore.case = TRUE, perl = TRUE)
          if (m && !is.null(g$unless)) m <- !grepl(g$unless, s, ignore.case = TRUE, perl = TRUE)
          if (m) hits[[length(hits) + 1]] <- data.frame(file = basename(path), para = pi, rule = rn,
                                                        text = substr(trimws(s), 1, 110))
        }
      }
    }
  }
  if (length(hits)) do.call(rbind, hits) else data.frame(file = character(), para = integer(), rule = character(), text = character())
}
G30 <- run_guard(file.path("tools", "claim-guard", "sep30"))
n30 <- table(factor(G30$rule, levels = names(GUARD)))
cat(sprintf("  claim guard on the Sep 30 prose: %d hits -- %s\n", nrow(G30),
            paste(sprintf("%s %d", names(n30), n30), collapse = ", ")))
blind <- GUARD_MUST[n30[GUARD_MUST] == 0]
if (length(blind)) stop("claim guard no longer fires on the Sep 30 prose for: ", paste(blind, collapse = ", "))
G07 <- run_guard(file.path("tools", "claim-guard", "oct7"))
n07 <- table(factor(G07$rule, levels = names(GUARD)))
cat(sprintf("  claim guard on the Oct 7 prose: %d hits -- %s\n", nrow(G07),
            paste(sprintf("%s %d", names(GUARD_OCT7), n07[names(GUARD_OCT7)]), collapse = ", ")))
blind7 <- names(GUARD_OCT7)[n07[names(GUARD_OCT7)] == 0]
if (length(blind7)) stop("claim guard no longer fires on the Oct 7 prose for: ", paste(blind7, collapse = ", "))
GNOW <- rbind(run_guard("report"), run_guard(file.path("report", "supplement")))   # Task S5.4
write.csv(GNOW, file.path("output", "tables", "claim-guard-hits.csv"), row.names = FALSE)
for (i in seq_len(nrow(GNOW)))
  cat(sprintf("  CLAIM GUARD %-14s %-18s para %2d: %s\n", GNOW$rule[i], GNOW$file[i], GNOW$para[i], GNOW$text[i]))
cat(sprintf("  claim guard on report/: %d hit(s)%s\n", nrow(GNOW),
            if (nrow(GNOW)) " -> output/tables/claim-guard-hits.csv" else ""))
res <- c(res, claim_guard = !nrow(GNOW))
res <- c(res, qualitative_claims = !length(CLAIMS_BAD))
if (length(CLAIMS_BAD)) cat(sprintf("  %d qualitative claim(s) no longer hold:\n%s\n", length(CLAIMS_BAD),
                                    paste("    -", CLAIMS_BAD, collapse = "\n")))
hdr("verify")
cat(sprintf("  every number in the drafted sections is a registered rendering of a computed value -- %s\n",
            if (all(res)) "PASS" else "FAIL"))
## Task S4.1: under make.R --release --defer-prose (VP_DEFER_PROSE=1) the
## checks of the report PROSE are reported and do not stop the stage. The one
## check of generated stage text is never deferred.
PROSE_CHECKS <- setdiff(names(res), "generated_text_shrinkage")
if (identical(Sys.getenv("VP_DEFER_PROSE"), "1")) {
  if (!isTRUE(res[["generated_text_shrinkage"]])) stop("generated stage text carries retired language (never deferred)")
  if (!all(res)) cat(sprintf("\n  PROSE CHECKS DEFERRED (--defer-prose): %d failing -- %s\n  They are enforced again when S5.5 runs make.R --release without the flag.\n",
                             sum(!res), paste(names(res)[!res], collapse = ", ")))
} else if (!all(res)) stop("report text carries numbers make.R did not produce: ", paste(names(res)[!res], collapse = ", "))
hdr("done")
