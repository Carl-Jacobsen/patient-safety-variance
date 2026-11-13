# R/catchment.R  --  Task 2.4, the catchment-weighting engine
#
# Turns the Hospital Service Area File (hospital x patient-ZIP Medicare
# discharge counts) into a per-hospital weight vector over 2020 census tracts,
# so Task 2.5 can compute a discharge-weighted average of any tract-level
# Block B covariate.
#
# Base grain is ZIP -> tract (plan-amendments.md §2.2-2.4). County grain was
# withdrawn as the base case: Phase 0 measured the catchment-weighted SVI to
# correlate 0.89-0.97 with naive hospital-county assignment AT COUNTY GRAIN,
# and imputing the suppressed cells moved that by ~0.01 -- so the redundancy is
# the grain, not the suppression. Tract grain is where the weighting retains
# the within-county heterogeneity county assignment destroys.
#
# The one allocation step is ZCTA -> tract (spike-context.md §3.3). It is done
# by POPULATION weighting: a tract's share of a ZCTA is its population inside
# that ZCTA (tract population x land-area fraction of the tract lying in the
# ZCTA), normalised over the ZCTA. A ZCTA in which some slice with land has no
# SVI population falls back WHOLE to land-area share, and the count is reported
# (Task S0.4: before that repair a ZCTA could normalise people and square metres
# together, and every Connecticut slice missed its population -- see below).
#
# Suppression (87% of HSAF cells): renormalise the discharge weights over the
# OBSERVED cells. Phase 0 tested this against imputing every suppressed cell at
# 3 cases -- r >= 0.986 on all four SVI themes, mean difference < 0.004
# (plan-amendments.md §2.2, admission-gates.md A2). catch_coverage =
# obs_cases / (obs_cases + 3 x n_suppressed_cells) is recorded for EVERY frame
# hospital (gate B0.d); the constant 3 is a diagnostic only, never a weight.
#
# Fallback: a hospital with < 3 observed cells OR < 100 observed cases (gate
# B0.a) gets catch_source = "county_fallback" and is NOT in the weight table --
# Task 2.5 gives it its hospital-county covariate value directly. Phase 0
# measured 130 such hospitals (4.64%), median catch_coverage 0.829.
#
# Base R. Reads the permanent Task 1.4/1.5 layout, R/hsaf.R, and the Task 2.1
# crosswalk spine.

source(file.path("R", "hsaf.R"))

CC <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
BB <- file.path("data-raw", "blockB")
HSAF <- file.path("data-raw", "hsaf")

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
z5  <- function(x) formatC(trimws(x), width = 5, flag = "0")

## Gate B0 constants (admission-gates.md §5, committed 2026-08-26)
B0_MIN_OBS_CELLS  <- 3
B0_MIN_OBS_CASES  <- 100
B0_SUPP_CONST     <- 3        # assumed mean size of a suppressed cell, diagnostic only
B0_FALLBACK_MAX   <- 0.10     # B0.b
B0_COVERAGE_MED   <- 0.60     # B0.e
WEIGHT_PRUNE      <- 1e-6     # drop tract weights below this, then renormalise

# ==========================================================================
# ZCTA -> tract population-share allocation table
# ==========================================================================
## Returns a data.frame(zcta, tract, share) with sum(share) == 1 per zcta, plus
## an attribute `method` recording per-zcta whether every slice had a
## population (population weighting) or some fell back to area.
build_zcta_tract_alloc <- function() {
  f <- file.path(BB, "tab20_zcta520_tract20_natl.txt")
  d <- read.table(f, sep = "|", header = TRUE, quote = "", comment.char = "",
                  colClasses = "character", check.names = FALSE, fileEncoding = "UTF-8-BOM")
  d <- d[nzchar(trimws(d$GEOID_ZCTA5_20)) & nzchar(trimws(d$GEOID_TRACT_20)), ]
  d$zcta  <- z5(d$GEOID_ZCTA5_20)
  d$tract <- formatC(trimws(d$GEOID_TRACT_20), width = 11, flag = "0")
  d$part  <- n_(d$AREALAND_PART);       d$part[is.na(d$part) | d$part < 0] <- 0
  d$tland <- n_(d$AREALAND_TRACT_20)

  ## tract population from SVI 2022 (E_TOTPOP); -999 / blank -> NA
  svi <- rd(file.path(BB, "SVI_2022_US.csv"))
  tpop <- setNames(n_(svi$E_TOTPOP), formatC(trimws(svi$FIPS), width = 11, flag = "0"))
  tpop[!is.na(tpop) & tpop < 0] <- NA
  alloc_from_parts(d[, c("zcta", "tract", "part", "tland")], tpop)
}

## Connecticut (Task S0.4). SVI 2022 keys Connecticut tracts by the 2022 COG
## planning regions (county codes 110-190); the 2020 relationship file keys them
## by the legacy counties (001-015). The two share no tract IDs, so before this
## repair every Connecticut slice missed its population and fell back to land
## area. The 6-digit tract suffix is unique within Connecticut and the same in
## both (blockB.R, 879 of 879), so the POPULATION LOOKUP goes through the suffix.
## The allocation keeps the 2020 IDs; blockB.R remaps them later, as before.
pop_key <- function(tract, svi_fips) {
  ct22 <- svi_fips[substr(svi_fips, 1, 2) == "09"]
  map <- setNames(ct22, substr(ct22, 6, 11))
  k <- substr(tract, 1, 2) == "09"
  hit <- map[substr(tract[k], 6, 11)]
  tract[k] <- ifelse(is.na(hit), tract[k], hit)
  tract
}

## The allocation as a pure function of the relationship rows (zcta, tract,
## part = land in the slice, tland = the tract's land) and a named tract
## population vector, so the self-test can exercise it.
##
## One unit per ZCTA (Task S0.4). A ZCTA is population-weighted only if every
## slice with positive land has both a population and a land fraction, and the
## population total is positive; otherwise the WHOLE ZCTA uses land area. Before
## the repair a slice without population used its land area in square metres
## while its neighbours used people, and the two were normalised together.
## Slices with no land (water only) never decide the unit.
alloc_from_parts <- function(d, tpop) {
  d$pop  <- unname(tpop[pop_key(d$tract, names(tpop))])
  d$frac <- ifelse(!is.na(d$tland) & d$tland > 0, pmin(1, d$part / d$tland), NA_real_)
  has    <- !is.na(d$pop) & !is.na(d$frac)
  pslice <- ifelse(has, d$pop * d$frac, 0)
  ok_all <- tapply(has | d$part <= 0, d$zcta, all)
  ok_pos <- tapply(pslice, d$zcta, sum) > 0
  meth   <- ifelse(ok_all & ok_pos, "population", "area")
  d$slice <- ifelse(meth[d$zcta] == "population", pslice, d$part)
  tot <- tapply(d$slice, d$zcta, sum)
  d$share <- d$slice / tot[d$zcta]
  d <- d[is.finite(d$share) & d$share > 0, ]
  out <- d[, c("zcta", "tract", "share")]
  attr(out, "method") <- meth[names(meth) %in% d$zcta]
  attr(out, "why_area") <- c(missing_pop = sum(!ok_all), zero_pop = sum(ok_all & !ok_pos))
  out
}

# ==========================================================================
# the core function -- one hospital's tract weights
# ==========================================================================
## zip_cases : named numeric, observed (unsuppressed) Medicare cases by 5-digit ZIP
## alloc     : list, zcta -> data.frame(tract, share)  (from split() of the table)
## returns   : list(weights = data.frame(tract, weight), matched_share = <num>)
##             weights sum to 1 exactly; matched_share is the discharge weight
##             that fell on ZIPs present in the ZCTA->tract table.
catchment_weights_one <- function(zip_cases, alloc) {
  zip_cases <- zip_cases[zip_cases > 0]
  w_zip <- zip_cases / sum(zip_cases)                     # renormalise over observed cells

  present <- names(w_zip) %in% names(alloc)
  matched_share <- sum(w_zip[present])
  if (matched_share <= 0) return(list(weights = NULL, matched_share = 0))
  w_zip <- w_zip[present] / matched_share                 # renormalise over ZIPs we can place

  a <- do.call(rbind, alloc[names(w_zip)])                # tract, share  (stacked)
  a$w <- a$share * w_zip[rep(names(w_zip), vapply(alloc[names(w_zip)], nrow, integer(1)))]
  wt <- tapply(a$w, a$tract, sum)

  keep <- wt >= WEIGHT_PRUNE
  if (!any(keep)) keep <- rep(TRUE, length(wt))
  wt <- wt[keep]
  wt <- wt / sum(wt)                                      # exact sum-to-1 after pruning
  list(weights = data.frame(tract = names(wt), weight = as.numeric(wt), stringsAsFactors = FALSE),
       matched_share = matched_share)
}

# ==========================================================================
# self-test -- hand-checkable, runs before anything else
# ==========================================================================
catchment_selftest <- function() {
  ## (1) allocation share on a hand example --------------------------------
  ## tract T1: pop 1000, land 100, all of it inside ZCTA Z  (part 100)
  ## tract T2: pop  200, land 100, half inside ZCTA Z       (part  50)
  ##   slice T1 = 1000 * (100/100) = 1000 ; slice T2 = 200 * (50/100) = 100
  ##   share Z->T1 = 1000/1100 ; share Z->T2 = 100/1100
  frac1 <- 100/100; frac2 <- 50/100
  s1 <- 1000 * frac1; s2 <- 200 * frac2
  stopifnot(abs(s1/(s1+s2) - 1000/1100) < 1e-12,
            abs(s2/(s1+s2) -  100/1100) < 1e-12)

  ## (2) one hospital's tract weights -------------------------------------
  ## ZCTA A -> T1 0.75, T2 0.25 ; ZCTA B -> T2 1.0 ; ZCTA C absent
  ## hospital observed cases: A 60, B 40, C 20  (total 120)
  ##   w_zip = A .5, B 1/3, C 1/6
  ##   C not placeable -> matched_share = .5 + 1/3 = 5/6
  ##   renormalised: A .6, B .4
  ##   w(T1) = .6 * .75            = .45
  ##   w(T2) = .6 * .25 + .4 * 1.0 = .55
  alloc <- list(
    A = data.frame(tract = c("T1", "T2"), share = c(0.75, 0.25)),
    B = data.frame(tract = "T2",           share = 1.0))
  r <- catchment_weights_one(c(A = 60, B = 40, C = 20), alloc)
  w <- setNames(r$weights$weight, r$weights$tract)
  stopifnot(abs(r$matched_share - 5/6) < 1e-12,
            abs(sum(w) - 1) < 1e-12,
            abs(w[["T1"]] - 0.45) < 1e-12,
            abs(w[["T2"]] - 0.55) < 1e-12)
  ## (3) Task S0.4: one unit per ZCTA, and the Connecticut population lookup -
  ## ZCTA M: T1 has a population, T2 (with land) has none -> the WHOLE ZCTA is
  ## area-weighted: shares 100/150 and 50/150, never 1000 people against 50 m2.
  ## ZCTA W: T3 has a population, T4 has none but no land -> population, T3 1.0.
  ## ZCTA C: a legacy Connecticut ID whose population is under the 2022 ID.
  dd <- data.frame(zcta  = c("M", "M", "W", "W", "C"),
                   tract = c("01001000100", "01001000200", "01001000300", "01001000400", "09001010100"),
                   part  = c(100, 50, 80, 0, 40), tland = c(100, 100, 80, 10, 40))
  tp <- c("01001000100" = 1000, "01001000300" = 500, "09120010100" = 300)
  aa <- alloc_from_parts(dd, tp)
  sh <- setNames(aa$share, paste(aa$zcta, aa$tract))
  stopifnot(abs(sh[["M 01001000100"]] - 100/150) < 1e-12, abs(sh[["M 01001000200"]] - 50/150) < 1e-12,
            abs(sh[["W 01001000300"]] - 1) < 1e-12, !("W 01001000400" %in% names(sh)),
            attr(aa, "method")[["M"]] == "area", attr(aa, "method")[["W"]] == "population",
            attr(aa, "method")[["C"]] == "population")
  cat("  catchment_selftest: PASS  (allocation share + hospital weights match by hand;\n")
  cat("                     one unit per ZCTA; Connecticut population found under its 2022 ID)\n")
  invisible(TRUE)
}

# ==========================================================================
hdr("TASK 2.4  the catchment-weighting engine")
catchment_selftest()

## ---- frame + crosswalk spine --------------------------------------------
cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame)
cw <- readRDS(file.path("data", "crosswalk.rds"))
stopifnot(setequal(frame, cw$ccn))
cwf <- cw[match(frame, cw$ccn), ]
cat(sprintf("  frame n = %d\n", N))

## ---- HSAF: hospital x patient-ZIP Medicare discharges ------------------
sub_("HSAF CY 2023 -- observed cells, renormalised over suppression")
h <- read_hsaf(file.path(HSAF, "Hospital_Service_Area_2023.csv"))
h$ccn   <- trimws(h$MEDICARE_PROV_NUM)
h$zip   <- z5(h$ZIP_CD_OF_RESIDENCE)
h$cases <- n_(h$TOTAL_CASES)                       # literal '*' -> NA (suppressed)
bad_zip <- !nzchar(trimws(h$ZIP_CD_OF_RESIDENCE)) | h$zip %in% c("00000", "99999") | grepl("NA", h$zip)
cat(sprintf("  HSAF rows %s  (EOF row dropped by read_hsaf: %d)\n",
            format(nrow(h), big.mark = ","), attr(h, "hsaf_dropped_rows")))
cat(sprintf("  non-geographic ZIP rows dropped: %s file-wide, %s among frame hospitals\n",
            format(sum(bad_zip), big.mark = ","),
            format(sum(bad_zip & h$ccn %in% frame), big.mark = ",")))
hf <- h[h$ccn %in% frame & !bad_zip, c("ccn", "zip", "cases")]

## per-hospital cell tallies (gate B0.a / B0.d inputs)
by_h <- split(hf, hf$ccn)
tally <- do.call(rbind, lapply(names(by_h), function(f) {
  x <- by_h[[f]]
  data.frame(ccn = f, n_cells = nrow(x), n_obs_cells = sum(!is.na(x$cases)),
             n_supp_cells = sum(is.na(x$cases)), obs_cases = sum(x$cases, na.rm = TRUE),
             n_zips_observed = length(unique(x$zip[!is.na(x$cases)])),
             stringsAsFactors = FALSE)
}))
M <- data.frame(ccn = frame, stringsAsFactors = FALSE)
M <- merge(M, tally, by = "ccn", all.x = TRUE, sort = FALSE)
M <- M[match(frame, M$ccn), ]
for (v in c("n_cells", "n_obs_cells", "n_supp_cells", "obs_cases", "n_zips_observed"))
  M[[v]][is.na(M[[v]])] <- 0
M$in_hsaf <- frame %in% names(by_h)

## gate B0.d -- catch_coverage for EVERY frame hospital
M$catch_coverage <- ifelse(M$obs_cases + B0_SUPP_CONST * M$n_supp_cells > 0,
                           M$obs_cases / (M$obs_cases + B0_SUPP_CONST * M$n_supp_cells), 0)

## gate B0.a -- admissibility
M$admissible <- M$in_hsaf & M$n_obs_cells >= B0_MIN_OBS_CELLS & M$obs_cases >= B0_MIN_OBS_CASES
M$catch_source <- ifelse(M$admissible, "catchment", "county_fallback")
M$fallback_county_fips <- ifelse(M$admissible, NA_character_, cwf$county_fips)

cat(sprintf("  frame hospitals in HSAF                 %d / %d\n", sum(M$in_hsaf), N))
cat(sprintf("  absent from HSAF (auto-fallback)        %d   %s\n",
            sum(!M$in_hsaf), paste(frame[!M$in_hsaf], collapse = " ")))
cat(sprintf("  median observed cells / cases (adm.)    %d / %s\n",
            median(M$n_obs_cells[M$admissible]),
            format(round(median(M$obs_cases[M$admissible])), big.mark = ",")))

# ==========================================================================
# build the weight table -- admissible hospitals only
# ==========================================================================
sub_("ZCTA -> tract allocation (population weighting, area fallback)")
alloc_tbl <- build_zcta_tract_alloc()
meth <- attr(alloc_tbl, "method")
alloc <- split(alloc_tbl[, c("tract", "share")], alloc_tbl$zcta)
cat(sprintf("  ZCTAs %s   tract slices %s   sum(share)==1 per ZCTA: %s\n",
            format(length(alloc), big.mark = ","), format(nrow(alloc_tbl), big.mark = ","),
            all(abs(tapply(alloc_tbl$share, alloc_tbl$zcta, sum) - 1) < 1e-9)))
why <- attr(alloc_tbl, "why_area")
cat(sprintf("  allocation method: %s of ZCTAs population-weighted, %s area-weighted whole\n",
            pct(mean(meth == "population")), pct(mean(meth == "area"))))
cat(sprintf("    area-weighted because a slice with land lacks a population: %d; population total zero: %d\n",
            why[["missing_pop"]], why[["zero_pop"]]))
ctz <- unique(alloc_tbl$zcta[substr(alloc_tbl$tract, 1, 2) == "09"])
cat(sprintf("  Connecticut: %d ZCTAs touch a CT tract, %d of them population-weighted\n",
            length(ctz), sum(meth[ctz] == "population")))

sub_("per-hospital tract weights")
adm <- frame[M$admissible]
obs_by_h <- lapply(split(hf[!is.na(hf$cases), ], hf$ccn[!is.na(hf$cases)]),
                   function(x) tapply(x$cases, x$zip, sum))
wt_list <- vector("list", length(adm))
zip_matched <- setNames(rep(NA_real_, length(adm)), adm)
for (i in seq_along(adm)) {
  f <- adm[i]
  r <- catchment_weights_one(obs_by_h[[f]], alloc)
  zip_matched[f] <- r$matched_share
  if (!is.null(r$weights)) { r$weights$ccn <- f; wt_list[[i]] <- r$weights }
}
W <- do.call(rbind, wt_list)
W <- W[, c("ccn", "tract", "weight")]
names(W)[names(W) == "tract"] <- "tract_geoid"

## per-hospital summary of the weights
wsum <- tapply(W$weight, W$ccn, sum)
ntr  <- tapply(W$weight, W$ccn, length)
M$n_tracts        <- unname(ntr[M$ccn])
M$weight_sum      <- unname(wsum[M$ccn])
M$zip_matched_share <- unname(zip_matched[M$ccn])

cat(sprintf("  admissible hospitals weighted           %d\n", length(adm)))
cat(sprintf("  weight rows (hospital x tract)          %s\n", format(nrow(W), big.mark = ",")))
cat(sprintf("  tracts per catchment: median %d  p05 %d  p95 %d\n",
            median(M$n_tracts, na.rm = TRUE),
            quantile(M$n_tracts, .05, na.rm = TRUE, names = FALSE),
            quantile(M$n_tracts, .95, na.rm = TRUE, names = FALSE)))
cat(sprintf("  discharge weight placed on mappable ZIPs: median %s  min %s\n",
            pct(median(M$zip_matched_share, na.rm = TRUE), 2),
            pct(min(M$zip_matched_share, na.rm = TRUE), 2)))
M$flag_low_zip_match <- !is.na(M$zip_matched_share) & M$zip_matched_share < 0.90
low <- M[which(M$flag_low_zip_match), ]
low <- low[order(low$zip_matched_share), ]
cat(sprintf("  hospitals below 90%% mappable-ZIP weight: %d  (weights still valid, built on less of the base)\n",
            nrow(low)))
for (i in seq_len(nrow(low)))
  cat(sprintf("    %s  %-34s %s  %s mapped\n", low$ccn[i],
              substr(cwf$name[match(low$ccn[i], frame)], 1, 34),
              cwf$state[match(low$ccn[i], frame)], pct(low$zip_matched_share[i], 1)))

# ==========================================================================
# gate B0
# ==========================================================================
hdr("GATE B0 -- catchment coverage (admission-gates.md §5)")

max_sum_err <- max(abs(M$weight_sum[M$admissible] - 1))
b0 <- data.frame(
  gate_id = c("B0.a", "B0.b", "B0.c", "B0.d", "B0.e"),
  predicate = c("hospital admissible iff n_obs_cells >= 3 and obs_cases >= 100",
                "share of frame on the county fallback",
                "catchment weights sum to 1 per admissible hospital",
                "catch_coverage recorded for every frame hospital",
                "median catch_coverage across the frame"),
  threshold = c("per-hospital FLAG", sprintf("<= %.2f", B0_FALLBACK_MAX),
                "abs(sum - 1) <= 1e-9", "= 1.00 of frame", sprintf(">= %.2f", B0_COVERAGE_MED)),
  observed = c(sprintf("%d fail (%s)", sum(!M$admissible), pct(mean(!M$admissible), 2)),
               pct(mean(!M$admissible), 4),
               sprintf("max abs(sum-1) = %.2e", max_sum_err),
               pct(mean(!is.na(M$catch_coverage)), 2),
               sprintf("%.3f", median(M$catch_coverage))),
  pass = c(TRUE,
           mean(!M$admissible) <= B0_FALLBACK_MAX,
           max_sum_err <= 1e-9,
           all(!is.na(M$catch_coverage)),
           median(M$catch_coverage) >= B0_COVERAGE_MED),
  n_flagged = c(sum(!M$admissible), sum(!M$admissible), sum(M$admissible & abs(M$weight_sum - 1) > 1e-9),
                sum(is.na(M$catch_coverage)), 0),
  stringsAsFactors = FALSE)
write.csv(b0, file.path("output", "tables", "catchment-gate-B0.csv"), row.names = FALSE)
for (i in seq_len(nrow(b0)))
  cat(sprintf("  %-5s  %-52s  %-22s  %s\n", b0$gate_id[i], substr(b0$predicate[i], 1, 52),
              b0$observed[i], if (b0$pass[i]) "PASS" else "FAIL"))

## fallback hospitals, enumerated (admission-gates.md §5 requires this file)
fb <- M[!M$admissible, ]
fb <- data.frame(
  ccn = fb$ccn, name = cwf$name[match(fb$ccn, frame)], state = cwf$state[match(fb$ccn, frame)],
  county_fips = fb$fallback_county_fips,
  in_hsaf = fb$in_hsaf, n_obs_cells = fb$n_obs_cells, obs_cases = fb$obs_cases,
  n_supp_cells = fb$n_supp_cells, catch_coverage = round(fb$catch_coverage, 3),
  reason = ifelse(!fb$in_hsaf, "absent from HSAF",
           ifelse(fb$n_obs_cells < B0_MIN_OBS_CELLS & fb$obs_cases < B0_MIN_OBS_CASES, "< 3 cells and < 100 cases",
           ifelse(fb$n_obs_cells < B0_MIN_OBS_CELLS, "< 3 observed cells", "< 100 observed cases"))),
  stringsAsFactors = FALSE)
fb <- fb[order(fb$state, fb$ccn), ]
write.csv(fb, file.path("output", "tables", "catchment-fallback-hospitals.csv"), row.names = FALSE)

sub_("county-fallback hospitals -- output/tables/catchment-fallback-hospitals.csv")
cat(sprintf("  %d hospitals (%s of the frame)\n", nrow(fb), pct(nrow(fb) / N, 2)))
cat("  by reason: "); print(table(fb$reason))
cat("  by rurality: ")
ur <- cwf$urgeo[match(fb$ccn, frame)]
print(table(ifelse(is.na(ur), "unknown", ur)))
cat(sprintf("  vs frame rurality: %s RURAL\n", pct(mean(cwf$urgeo == "RURAL", na.rm = TRUE))))

# ==========================================================================
# freeze
# ==========================================================================
catchment <- M[, c("ccn", "catch_source", "catch_coverage", "admissible", "in_hsaf",
                   "n_cells", "n_obs_cells", "n_supp_cells", "obs_cases",
                   "n_zips_observed", "n_tracts", "weight_sum", "zip_matched_share",
                   "flag_low_zip_match", "fallback_county_fips")]
saveRDS(catchment, file.path("data", "catchment.rds"))
saveRDS(W,         file.path("data", "catchment-weights.rds"))

sub_("data/catchment.rds  +  data/catchment-weights.rds")
cat(sprintf("  catchment.rds          %d rows (one per frame hospital), %d cols\n",
            nrow(catchment), ncol(catchment)))
cat(sprintf("  catchment-weights.rds  %s rows (ccn x tract_geoid x weight), %d admissible hospitals\n",
            format(nrow(W), big.mark = ","), length(unique(W$ccn))))
cat(sprintf("  catch_source: %s\n",
            paste(sprintf("%s=%d", names(table(catchment$catch_source)), table(catchment$catch_source)), collapse = "  ")))

sub_("gate summary")
for (i in seq_len(nrow(b0)))
  cat(sprintf("  %-5s %s\n", b0$gate_id[i], if (b0$pass[i]) "PASS" else "FAIL"))
stopifnot(nrow(catchment) == N, !anyDuplicated(catchment$ccn),
          all(b0$pass), nrow(W) > 0,
          all(abs(tapply(W$weight, W$ccn, sum) - 1) < 1e-9))
if (!all(b0$pass)) stop("gate B0 failed -- see above")

hdr("done")
