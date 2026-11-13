# R/blockB.R  --  Task 2.5, Block B catchment-weighted
#
# Every Block B covariate at FOUR grain variants per hospital, so the report can
# state both HOW MUCH catchment weighting changes a covariate and AT WHICH GRAIN
# it starts to matter (plan-amendments.md §2.2):
#
#   _catch_tract   discharge-weighted over the catchment's census tracts   <- base case
#   _catch_county  the same discharge weights, aggregated to county grain
#   _county        naive: the covariate of the county the hospital sits in
#   _hsa           Dartmouth Atlas service-area assignment -- SUPPRESSION-FREE,
#                  an independent check on the whole construction
#
# The informative comparison is (_catch_tract vs _county). The comparison
# (_catch_county vs _county) is the one Phase 0 found near-degenerate
# (r 0.89-0.97) -- it belongs in the report as the reason tract grain was
# chosen, NOT as evidence catchment weighting is pointless.
#
# Covariates:
#   SVI themes 1-4, uninsured rate (EP_UNINSUR), limited-English share
#     (EP_LIMENG)                    tract-native, from the SVI file
#   ICE (+ a >=$150k axis)           tract-native, from ACS B19001
#   ADI 2024 (+ 2020 vintage axis)   block group -> tract by POPULATION weighting
#                                    first (spike-context.md §3.3); a rank-of-
#                                    ranks, not a block-group ADI
#   rurality (RUCC 2023)             county-native
#   primary-care physician density   county-native, from AHRF
#   market concentration (HHI)       hospital-level, derived from the HSAF itself
#
# Fallback hospitals (gate B0.a, catch_source == "county_fallback") take their
# hospital-county value for the _catch_* variants.
#
# Base R + haven (for the AHRF SAS file, already an renv dependency). Reads the
# Task 1.4 layout, R/hsaf.R, and the Task 2.1 / 2.4 built files.

suppressPackageStartupMessages(library(haven))
source(file.path("R", "hsaf.R"))

CC   <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
BB   <- file.path("data-raw", "blockB")
ADI  <- file.path("data-raw", "blockB_adi")
ACS  <- file.path("data-raw", "blockB_acs")
HSAF <- file.path("data-raw", "hsaf")
DART <- file.path("data-raw", "dartmouth")

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
z5  <- function(x) formatC(trimws(x), width = 5, flag = "0")
svi_na <- function(x) { v <- n_(x); v[!is.na(v) & v < 0] <- NA; v }   # SVI codes missing as -999

## weighted mean that drops NA values and renormalises; returns the mean and the
## share of weight that fell on a non-missing value.
wmean <- function(values, weights) {
  ok <- !is.na(values) & !is.na(weights) & weights > 0
  if (!any(ok)) return(c(mean = NA_real_, wt = 0))
  w <- weights[ok] / sum(weights[ok])
  c(mean = sum(w * values[ok]), wt = sum(weights[ok]) / sum(weights[!is.na(weights) & weights > 0]))
}

# ==========================================================================
hdr("TASK 2.5  Block B -- catchment-weighted, four grain variants")

cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame)

cw   <- readRDS(file.path("data", "crosswalk.rds"));   cwf <- cw[match(frame, cw$ccn), ]
cat  <- readRDS(file.path("data", "catchment.rds"));   catf <- cat[match(frame, cat$ccn), ]
W    <- readRDS(file.path("data", "catchment-weights.rds"))
stopifnot(setequal(frame, cw$ccn), setequal(frame, cat$ccn))
cat(sprintf("  frame n = %d   admissible %d   county_fallback %d\n",
            N, sum(catf$catch_source == "catchment"), sum(catf$catch_source == "county_fallback")))

svt <- rd(file.path(BB, "SVI_2022_US.csv"));        svt$FIPS <- formatC(trimws(svt$FIPS), width = 11, flag = "0")
svc <- rd(file.path(BB, "SVI_2022_US_county.csv")); svc$FIPS <- z5(svc$FIPS)

## --- Connecticut: 2020 legacy geography -> 2022 COG planning regions --------
## For the 2022 ACS vintage CT replaced its 8 counties with 9 COG planning
## regions and renumbered every tract. Every Block B source here (SVI, ACS/ICE,
## ADI, RUCC, AHRF) is on the new 09110-09190 geography; the catchment weights
## (Census 2020 ZCTA->tract relationship file) and the Task 2.1 crosswalk are on
## legacy 090xx codes. The map is EXACT: 2020 CT tract 09XXXsuffix -> 2022 CT
## tract 09YYYsuffix, same 6-digit suffix, and every suffix is unique within CT
## (verified: 879 tracts, 879 distinct suffixes, 879/879 matched). See
## provenance/task2.5-blockB.md §2.
ct22 <- svt$FIPS[substr(svt$FIPS, 1, 2) == "09"]
ct_suffix_map <- setNames(ct22, substr(ct22, 6, 11))
remap_ct <- function(tr) {
  k <- !is.na(tr) & substr(tr, 1, 2) == "09"
  hit <- ct_suffix_map[substr(tr[k], 6, 11)]
  tr[k] <- ifelse(is.na(hit), tr[k], hit)
  tr
}
n_ct_remapped <- sum(substr(W$tract_geoid, 1, 2) == "09")
W$tract_geoid <- remap_ct(W$tract_geoid)
cw_tract22 <- remap_ct(cwf$census_tract)
cat(sprintf("  Connecticut geography: %d catchment tract-weight rows remapped 2020 -> 2022 codes\n",
            n_ct_remapped))

## a hospital's own "county": legacy FIPS elsewhere, COG planning region in CT.
## In CT take it from the (remapped) location tract; where that is missing, the
## weight-max planning region of the catchment.
W$county <- substr(W$tract_geoid, 1, 5)
Wc <- aggregate(weight ~ ccn + county, W, sum)
pr_modal <- tapply(seq_len(nrow(Wc)), Wc$ccn, function(ix) Wc$county[ix][which.max(Wc$weight[ix])])
hosp_county <- ifelse(catf$catch_source == "county_fallback" & !is.na(catf$fallback_county_fips),
                      catf$fallback_county_fips, cwf$county_fips)
is_ct <- cwf$state == "CT"
hosp_county[is_ct] <- ifelse(!is.na(cw_tract22[is_ct]) & substr(cw_tract22[is_ct], 1, 2) == "09",
                             substr(cw_tract22[is_ct], 1, 5),
                             unname(pr_modal[frame[is_ct]]))
names(hosp_county) <- frame

# ==========================================================================
# 1. covariate value tables:  v_tract (11-digit)  and  v_county (5-digit)
# ==========================================================================
sub_("SVI 2022 -- four themes, uninsured, limited-English (tract + county)")
SVI_COLS <- c(svi1 = "RPL_THEME1", svi2 = "RPL_THEME2", svi3 = "RPL_THEME3", svi4 = "RPL_THEME4",
              uninsured = "EP_UNINSUR", limeng = "EP_LIMENG")
v_tract <- list(); v_county <- list()
for (nm in names(SVI_COLS)) {
  v_tract[[nm]]  <- setNames(svi_na(svt[[SVI_COLS[nm]]]), svt$FIPS)
  v_county[[nm]] <- setNames(svi_na(svc[[SVI_COLS[nm]]]), svc$FIPS)
}
for (nm in names(SVI_COLS))
  cat(sprintf("  %-10s tract %s valid   county %s valid\n", nm,
              pct(mean(!is.na(v_tract[[nm]]))), pct(mean(!is.na(v_county[[nm]])))))

sub_("ICE -- ACS B19001, tract; county by summing the household counts")
ice <- rd(file.path(ACS, "acs2024_5yr_B19001_tract.csv"))
ice$GEOID <- formatC(trimws(ice$GEOID), width = 11, flag = "0")
LO  <- sprintf("B19001_%03dE", 2:5); HI <- sprintf("B19001_%03dE", 14:17); H15 <- sprintf("B19001_%03dE", 16:17)
tot_t <- n_(ice$B19001_001E)
lo_t  <- rowSums(sapply(LO, function(v) n_(ice[[v]])))
hi_t  <- rowSums(sapply(HI, function(v) n_(ice[[v]])))
h15_t <- rowSums(sapply(H15, function(v) n_(ice[[v]])))
v_tract$ice    <- setNames(ifelse(tot_t > 0, (hi_t  - lo_t) / tot_t, NA_real_), ice$GEOID)
v_tract$ice150 <- setNames(ifelse(tot_t > 0, (h15_t - lo_t) / tot_t, NA_real_), ice$GEOID)
icc <- data.frame(county = substr(ice$GEOID, 1, 5), tot = tot_t, lo = lo_t, hi = hi_t, h15 = h15_t)
icc <- aggregate(cbind(tot, lo, hi, h15) ~ county, icc, sum)
v_county$ice    <- setNames(ifelse(icc$tot > 0, (icc$hi  - icc$lo) / icc$tot, NA_real_), icc$county)
v_county$ice150 <- setNames(ifelse(icc$tot > 0, (icc$h15 - icc$lo) / icc$tot, NA_real_), icc$county)
cat(sprintf("  ice   tract %s valid   county %s valid   (median tract %+.3f)\n",
            pct(mean(!is.na(v_tract$ice))), pct(mean(!is.na(v_county$ice))), median(v_tract$ice, na.rm = TRUE)))

sub_("ADI -- block group -> tract / county by population weighting")
bgp <- rd(file.path(ACS, "acs2024_5yr_B01003_blockgroup.csv"))
bgp$GEOID <- formatC(trimws(bgp$GEOID), width = 12, flag = "0")
bgpop <- setNames(pmax(0, n_(bgp$B01003_001E)), bgp$GEOID)

adi_rollup <- function(adi_file, vintage) {
  a <- rd(file.path(ADI, adi_file))
  a$FIPS <- formatC(trimws(a$FIPS), width = 12, flag = "0")
  rank  <- suppressWarnings(as.numeric(a$ADI_NATRANK))   # GQ / PH / GQ-PH / QDI -> NA
  supp  <- is.na(rank) & nzchar(trimws(a$ADI_NATRANK))
  gq    <- grepl("GQ", trimws(a$ADI_NATRANK))
  a$rank <- rank; a$supp <- supp; a$gq <- gq
  a$tract  <- remap_ct(substr(a$FIPS, 1, 11))     # ADI 2020 uses legacy CT codes
  a$county <- substr(a$tract, 1, 5)
  a$pop <- bgpop[paste0(a$tract, substr(a$FIPS, 12, 12))]   # bg pop is on 2022 CT codes
  a$pop[is.na(a$pop)] <- 0
  roll <- function(key) {
    obs <- !is.na(a$rank) & a$pop > 0
    num <- tapply(a$pop[obs] * a$rank[obs], a[[key]][obs], sum)
    den <- tapply(a$pop[obs],               a[[key]][obs], sum)
    val <- num / den
    n_bg   <- tapply(rep(1L, nrow(a)),   a[[key]], sum)
    n_supp <- tapply(as.integer(a$supp), a[[key]], sum)
    n_gq   <- tapply(as.integer(a$gq),   a[[key]], sum)
    list(val = val, n_bg = n_bg, n_supp = n_supp, n_gq = n_gq)
  }
  list(tract = roll("tract"), county = roll("county"),
       gq_total = sum(gq), supp_total = sum(supp), vintage = vintage,
       bg = a[, c("FIPS", "tract", "county", "rank", "supp", "gq", "pop")])
}
adi24 <- adi_rollup("US_2024_block_group_adi_v_4_0_1.csv", "2024")
adi20 <- adi_rollup("US_2020_ADI_Census_Block_Group_v4_0_1.csv", "2020")
v_tract$adi      <- adi24$tract$val;  v_county$adi      <- adi24$county$val
v_tract$adi2020  <- adi20$tract$val;  v_county$adi2020  <- adi20$county$val
cat(sprintf("  ADI 2024: %s block groups suppressed (GQ %s), tract roll-up covers %s of tracts\n",
            format(adi24$supp_total, big.mark = ","), format(adi24$gq_total, big.mark = ","),
            pct(mean(!is.na(v_tract$adi)))))
cat(sprintf("  ADI 2020: %s suppressed (GQ %s)\n",
            format(adi20$supp_total, big.mark = ","), format(adi20$gq_total, big.mark = ",")))
cat("  NOTE: this is a population-weighted rank-of-ranks, NOT a block-group ADI (spike-context.md §3.3)\n")

sub_("rurality (RUCC 2023) and primary-care physician density (AHRF) -- county-native")
ru <- rd(file.path(BB, "Ruralurbancontinuumcodes2023.csv"))
ru <- ru[trimws(ru$Attribute) == "RUCC_2023", ]
v_county$rurality <- setNames(n_(ru$Value), z5(ru$FIPS))
v_tract$rurality  <- NULL   # county-native

td <- tempfile(); dir.create(td)
unzip(file.path(BB, "AHRF_2023-2024_SAS.zip"), exdir = td)
sasf <- list.files(td, pattern = "\\.sas7bdat$", recursive = TRUE, full.names = TRUE)[1]
ah <- haven::read_sas(sasf)
ah_fips <- formatC(trimws(ah$fips_st_cnty), width = 5, flag = "0")
pcp <- suppressWarnings(as.numeric(ah$phys_nf_prim_care_pc_exc_rsdt_22))   # patient-care primary-care physicians, non-fed, 2022
pop22 <- suppressWarnings(as.numeric(ah$popn_est_22))
v_county$pcp_density <- setNames(ifelse(!is.na(pop22) & pop22 > 0, 1e5 * pcp / pop22, NA_real_), ah_fips)
v_tract$pcp_density  <- NULL
## AHRF splits CT: physician counts sit on the 8 LEGACY counties (09001-09015,
## no popn_est_22), population sits on the 9 planning regions (09110-09190, no
## physician data). Mapping physicians to planning regions needs a legacy->COG
## crosswalk we do not have, so CT planning regions get CT's STATEWIDE
## primary-care density (legacy-county physicians over 2020 census population).
## Flagged; CT is 25 hospitals, and RUCC -- the other county-native covariate --
## was updated to the new geography and needs no such patch.
cens20 <- suppressWarnings(as.numeric(ah$cens_popn_20))
ct_legacy <- substr(ah_fips, 1, 5) %in% sprintf("090%02d", seq(1, 15, 2))
ct_pcp_state <- 1e5 * sum(pcp[ct_legacy], na.rm = TRUE) / sum(cens20[ct_legacy], na.rm = TRUE)
for (pr in sprintf("091%d0", 1:9)) v_county$pcp_density[pr] <- ct_pcp_state
cat(sprintf("  PCP density    CT planning regions set to CT statewide (%.1f/100k) -- AHRF still splits CT\n",
            ct_pcp_state))
cat(sprintf("  RUCC 2023      %s of counties      (1 metro .. 9 most rural; frame counties %s covered)\n",
            format(sum(!is.na(v_county$rurality)), big.mark = ","),
            pct(mean(unique(hosp_county) %in% names(v_county$rurality)[!is.na(v_county$rurality)]))))
cat(sprintf("  PCP density    %s of counties      per 100k, median %.1f\n",
            format(sum(!is.na(v_county$pcp_density)), big.mark = ","),
            median(v_county$pcp_density, na.rm = TRUE)))

COUNTY_NATIVE <- c("rurality", "pcp_density")
ALL_COV <- c("svi1", "svi2", "svi3", "svi4", "uninsured", "limeng", "ice", "ice150",
             "adi", "adi2020", "rurality", "pcp_density")

# ==========================================================================
# 2. HSA -> tract weight table (Dartmouth, suppression-free) for the _hsa variant
# ==========================================================================
sub_("Dartmouth HSA assignment -- building the suppression-free _hsa geography")
tdz <- tempfile(); dir.create(tdz)
unzip(file.path(DART, "ZipHsaHrr19.csv.zip"), files = "ZipHsaHrr19.csv", exdir = tdz)
dart <- rd(file.path(tdz, "ZipHsaHrr19.csv"))
dart$zip <- z5(dart$zipcode19); dart$hsa <- trimws(dart$hsanum)

## ZCTA -> tract population shares (same construction as R/catchment.R) + ZCTA pop
zt <- read.table(file.path(BB, "tab20_zcta520_tract20_natl.txt"), sep = "|", header = TRUE,
                 quote = "", comment.char = "", colClasses = "character", check.names = FALSE,
                 fileEncoding = "UTF-8-BOM")
zt <- zt[nzchar(trimws(zt$GEOID_ZCTA5_20)) & nzchar(trimws(zt$GEOID_TRACT_20)), ]
zt$zcta <- z5(zt$GEOID_ZCTA5_20)
zt$tract <- remap_ct(formatC(trimws(zt$GEOID_TRACT_20), width = 11, flag = "0"))   # CT 2020 -> 2022
zt$part <- n_(zt$AREALAND_PART); zt$part[is.na(zt$part) | zt$part < 0] <- 0
zt$tland <- n_(zt$AREALAND_TRACT_20)
tpop <- setNames(svi_na(svt$E_TOTPOP), svt$FIPS)
zt$pop <- tpop[zt$tract]
zt$frac <- ifelse(!is.na(zt$tland) & zt$tland > 0, pmin(1, zt$part / zt$tland), NA_real_)
zt$slice <- ifelse(!is.na(zt$pop) & !is.na(zt$frac), zt$pop * zt$frac, zt$part)
zcta_pop <- tapply(zt$slice, zt$zcta, sum)
zt$share <- zt$slice / zcta_pop[zt$zcta]
zt <- zt[is.finite(zt$share) & zt$share > 0, ]

## hospital's HSA: from its ZIP (crosswalk zip5), Dartmouth plurality assignment
zip2hsa <- setNames(dart$hsa, dart$zip)
hosp_hsa <- zip2hsa[cwf$zip5]; names(hosp_hsa) <- frame
cat(sprintf("  frame hospitals with a Dartmouth HSA: %d / %d\n", sum(!is.na(hosp_hsa)), N))

## HSA -> tract weights, only for HSAs a frame hospital sits in
need_hsa <- unique(hosp_hsa[!is.na(hosp_hsa)])
d2 <- dart[dart$hsa %in% need_hsa & dart$zip %in% names(zcta_pop), ]
d2$zpop <- as.numeric(zcta_pop[d2$zip])
zt_by <- split(zt[, c("tract", "share")], zt$zcta)
hsa_wt <- list()
for (s in need_hsa) {
  zz <- d2[d2$hsa == s, ]
  if (!nrow(zz)) next
  a <- do.call(rbind, Map(function(z, wp) { x <- zt_by[[z]]; x$w <- x$share * wp; x },
                          zz$zip, zz$zpop))
  agg <- tapply(a$w, a$tract, sum)
  hsa_wt[[s]] <- data.frame(tract = names(agg), weight = as.numeric(agg) / sum(agg),
                            stringsAsFactors = FALSE)
}
cat(sprintf("  HSA -> tract weight tables built for %d HSAs\n", length(hsa_wt)))

## precompute HSA-level covariate values
hsa_val <- function(cvname) {
  cn <- cvname %in% COUNTY_NATIVE
  vapply(need_hsa, function(s) {
    hw <- hsa_wt[[s]]; if (is.null(hw)) return(NA_real_)
    if (cn) {
      cc <- substr(hw$tract, 1, 5)
      w  <- tapply(hw$weight, cc, sum)
      wmean(v_county[[cvname]][names(w)], as.numeric(w))["mean"]
    } else {
      wmean(v_tract[[cvname]][hw$tract], hw$weight)["mean"]
    }
  }, numeric(1))
}

# ==========================================================================
# 3. assemble the four variants for every covariate
# ==========================================================================
sub_("computing the four grain variants per covariate")
W_by  <- split(W[, c("tract_geoid", "weight")], W$ccn)
Wc_by <- split(Wc[, c("county", "weight")],     Wc$ccn)

B <- data.frame(ccn = frame, catch_source = catf$catch_source,
                catch_coverage = catf$catch_coverage,
                county_fips = unname(hosp_county), hsa = unname(hosp_hsa),
                stringsAsFactors = FALSE)

for (cv in ALL_COV) {
  cn <- cv %in% COUNTY_NATIVE
  hv <- setNames(hsa_val(cv), need_hsa)

  ct <- cc <- co <- hs <- rep(NA_real_, N)
  ctw <- rep(NA_real_, N)
  for (i in seq_len(N)) {
    f <- frame[i]; fips <- hosp_county[f]
    co[i] <- unname(v_county[[cv]][fips])
    hs[i] <- if (!is.na(B$hsa[i])) unname(hv[B$hsa[i]]) else NA_real_

    if (catf$catch_source[i] == "county_fallback") {
      ct[i] <- cc[i] <- co[i]; ctw[i] <- if (!is.na(co[i])) 1 else 0
    } else if (cn) {
      wc <- Wc_by[[f]]
      r <- wmean(v_county[[cv]][wc$county], wc$weight)
      ct[i] <- cc[i] <- r["mean"]; ctw[i] <- r["wt"]
    } else {
      wt <- W_by[[f]]
      rt <- wmean(v_tract[[cv]][wt$tract_geoid], wt$weight);  ct[i] <- rt["mean"]; ctw[i] <- rt["wt"]
      wc <- Wc_by[[f]]
      cc[i] <- wmean(v_county[[cv]][wc$county], wc$weight)["mean"]
    }
  }
  B[[paste0(cv, "_catch_tract")]]  <- ct
  B[[paste0(cv, "_catch_county")]] <- cc
  B[[paste0(cv, "_county")]]       <- co
  B[[paste0(cv, "_hsa")]]          <- hs
  B[[paste0(cv, "_catch_tract_wt")]] <- ctw
}

# ==========================================================================
# 4. market concentration (HHI) -- hospital-level, from the HSAF
# ==========================================================================
sub_("market concentration (HHI) -- derived from the HSAF, ZIP and HSA markets")
h <- read_hsaf(file.path(HSAF, "Hospital_Service_Area_2023.csv"))
h$prov <- trimws(h$MEDICARE_PROV_NUM); h$zip <- z5(h$ZIP_CD_OF_RESIDENCE); h$cases <- n_(h$TOTAL_CASES)
h <- h[!is.na(h$cases) & nzchar(h$prov) & !h$zip %in% c("00000", "99999"), ]
## ZIP market: every provider's share of observed discharges in the ZIP (all providers, not just the frame)
zip_tot <- tapply(h$cases, h$zip, sum)
h$share <- h$cases / zip_tot[h$zip]
hhi_zip <- tapply(h$share^2, h$zip, sum) * 1e4                    # classic 0-10000 scale
## HSA market (Dartmouth): provider share of HSA discharges
h$hsa <- zip2hsa[h$zip]
hh <- h[!is.na(h$hsa), ]
key <- paste(hh$prov, hh$hsa)
prov_hsa <- tapply(hh$cases, key, sum)
split_k <- do.call(rbind, strsplit(names(prov_hsa), " "))
phd <- data.frame(prov = split_k[, 1], hsa = split_k[, 2], cases = as.numeric(prov_hsa))
hsa_tot <- tapply(phd$cases, phd$hsa, sum)
phd$share <- phd$cases / hsa_tot[phd$hsa]
hhi_hsa <- tapply(phd$share^2, phd$hsa, sum) * 1e4

## hospital-level: discharge-weighted mean of ZIP HHI over the hospital's own ZIPs
fh <- h[h$prov %in% frame, ]
hhi_zip_hosp <- sapply(split(fh, fh$prov), function(x)
  sum((x$cases / sum(x$cases)) * hhi_zip[x$zip], na.rm = TRUE))
B$hhi_zip <- unname(hhi_zip_hosp[frame])
B$hhi_hsa <- unname(hhi_hsa[hosp_hsa])
cat(sprintf("  HHI_zip  present %s   median %.0f   (10000 = pure monopoly ZIP)\n",
            pct(mean(!is.na(B$hhi_zip))), median(B$hhi_zip, na.rm = TRUE)))
cat(sprintf("  HHI_hsa  present %s   median %.0f\n",
            pct(mean(!is.na(B$hhi_hsa))), median(B$hhi_hsa, na.rm = TRUE)))
cat("  NOTE: HSAF suppression hides small providers' ZIP presence, so both HHIs are\n")
cat("  biased UPWARD (fewer competitors counted). Reported, carried, flagged here.\n")

# ==========================================================================
# 5. ADI aggregation diagnostics -- per hospital, catchment block-group suppression
# ==========================================================================
sub_("ADI aggregation diagnostics -- output/tables/adi-aggregation-diagnostics.csv")
bg24 <- adi24$bg
bg24$n_supp <- as.integer(bg24$supp); bg24$n_gq <- as.integer(bg24$gq); bg24$n_bg <- 1L
bg_by_tract <- aggregate(cbind(n_bg, n_supp, n_gq) ~ tract, bg24, sum)
tract_nbg  <- setNames(bg_by_tract$n_bg,   bg_by_tract$tract)
tract_supp <- setNames(bg_by_tract$n_supp, bg_by_tract$tract)
tract_gq   <- setNames(bg_by_tract$n_gq,   bg_by_tract$tract)

adi_diag <- do.call(rbind, lapply(seq_len(N), function(i) {
  f <- frame[i]
  if (catf$catch_source[i] == "county_fallback")
    return(data.frame(ccn = f, catch_source = "county_fallback", n_catch_tracts = NA_integer_,
                      bg_in_catchment = NA_real_, bg_suppressed_share = NA_real_,
                      bg_gq_share = NA_real_, adi_catch_tract = B$adi_catch_tract[i],
                      adi_catch_tract_wt = B$adi_catch_tract_wt[i], stringsAsFactors = FALSE))
  wt <- W_by[[f]]
  nb <- tract_nbg[wt$tract_geoid];  ns <- tract_supp[wt$tract_geoid]; ng <- tract_gq[wt$tract_geoid]
  nb[is.na(nb)] <- 0; ns[is.na(ns)] <- 0; ng[is.na(ng)] <- 0
  data.frame(ccn = f, catch_source = "catchment", n_catch_tracts = nrow(wt),
             bg_in_catchment = sum(wt$weight * nb),
             bg_suppressed_share = sum(wt$weight * ns) / max(sum(wt$weight * nb), 1e-9),
             bg_gq_share = sum(wt$weight * ng) / max(sum(wt$weight * nb), 1e-9),
             adi_catch_tract = B$adi_catch_tract[i], adi_catch_tract_wt = B$adi_catch_tract_wt[i],
             stringsAsFactors = FALSE)
}))
write.csv(adi_diag, file.path("output", "tables", "adi-aggregation-diagnostics.csv"), row.names = FALSE)
adm_d <- adi_diag[adi_diag$catch_source == "catchment", ]
cat(sprintf("  catchment block groups per hospital: median %.0f\n", median(adm_d$bg_in_catchment)))
cat(sprintf("  weighted share of catchment block groups suppressed: median %s  p95 %s\n",
            pct(median(adm_d$bg_suppressed_share)), pct(quantile(adm_d$bg_suppressed_share, .95, names = FALSE))))
cat(sprintf("  ... of which GQ (group quarters -- prisons, dorms, nursing homes): median %s\n",
            pct(median(adm_d$bg_gq_share))))

# ==========================================================================
# 6. the diagnostic tables
# ==========================================================================
hdr("DIAGNOSTIC -- how much weighting changes each covariate, and at which grain")

corr <- do.call(rbind, lapply(ALL_COV, function(cv) {
  a <- B[[paste0(cv, "_catch_tract")]];  b <- B[[paste0(cv, "_catch_county")]]
  d <- B[[paste0(cv, "_county")]];       e <- B[[paste0(cv, "_hsa")]]
  k <- !is.na(a) & !is.na(d)
  data.frame(covariate = cv, n = sum(k),
             r_catchtract_county  = cor(a[k], d[k]),
             r_catchcounty_county = cor(b[!is.na(b) & !is.na(d)], d[!is.na(b) & !is.na(d)]),
             r_catchtract_catchcounty = cor(a[!is.na(a) & !is.na(b)], b[!is.na(a) & !is.na(b)]),
             r_catchtract_hsa = if (sum(!is.na(a) & !is.na(e)) > 10) cor(a[!is.na(a) & !is.na(e)], e[!is.na(a) & !is.na(e)]) else NA_real_,
             mad_catchtract_county  = mean(abs(a[k] - d[k])),
             mad_catchcounty_county = mean(abs(b[!is.na(b) & !is.na(d)] - d[!is.na(b) & !is.na(d)])),
             stringsAsFactors = FALSE)
}))
write.csv(corr, file.path("output", "tables", "catchment-vs-county-correlation.csv"), row.names = FALSE)
cat(sprintf("  %-11s %6s  %10s %10s %10s  %9s %9s\n", "covariate", "n",
            "r(ct,co)", "r(cc,co)", "r(ct,hsa)", "MAD ct-co", "MAD cc-co"))
for (i in seq_len(nrow(corr)))
  cat(sprintf("  %-11s %6d  %10.4f %10.4f %10s  %9.4f %9.4f\n", corr$covariate[i], corr$n[i],
              corr$r_catchtract_county[i], corr$r_catchcounty_county[i],
              ifelse(is.na(corr$r_catchtract_hsa[i]), "-", sprintf("%.4f", corr$r_catchtract_hsa[i])),
              corr$mad_catchtract_county[i], corr$mad_catchcounty_county[i]))
cat("\n  READ: r(catch_county, county) is the near-degenerate Phase 0 comparison (grain,\n")
cat("  not weighting). r(catch_tract, county) is the informative one -- where it drops\n")
cat("  below r(catch_county, county), tract grain is retaining heterogeneity county\n")
cat("  assignment destroys.\n")

grainc <- do.call(rbind, lapply(ALL_COV, function(cv) do.call(rbind, lapply(
  c("catch_tract", "catch_county", "county", "hsa"), function(g) {
    x <- B[[paste0(cv, "_", g)]]; x <- x[!is.na(x)]
    data.frame(covariate = cv, variant = g, n = length(x), mean = mean(x), sd = sd(x),
               p05 = quantile(x, .05, names = FALSE), p50 = median(x),
               p95 = quantile(x, .95, names = FALSE), stringsAsFactors = FALSE)
  }))))
write.csv(grainc, file.path("output", "tables", "catchment-grain-comparison.csv"), row.names = FALSE)

# ==========================================================================
# 7. freeze
# ==========================================================================
variant_cols <- as.vector(t(outer(ALL_COV, c("_catch_tract", "_catch_county", "_county", "_hsa"), paste0)))
wt_cols <- paste0(ALL_COV, "_catch_tract_wt")
blockB <- B[, c("ccn", "catch_source", "catch_coverage", "county_fips", "hsa",
                variant_cols, "hhi_zip", "hhi_hsa", wt_cols)]
saveRDS(blockB, file.path("data", "blockB.rds"))

sub_("data/blockB.rds")
cat(sprintf("  %d rows, %d columns\n", nrow(blockB), ncol(blockB)))
cat(sprintf("  %d covariates x 4 grain variants + HHI(zip,hsa) + retained-weight columns\n", length(ALL_COV)))

sub_("verify")
missing_variants <- variant_cols[!variant_cols %in% names(blockB)]
allfour <- all(vapply(ALL_COV, function(cv)
  all(paste0(cv, c("_catch_tract", "_catch_county", "_county", "_hsa")) %in% names(blockB)), logical(1)))
cat(sprintf("  all four variants present for every covariate: %s\n", if (allfour) "YES" else "NO"))
cat(sprintf("  fallback hospitals: _catch_tract == _county for a tract-native covariate: %s\n",
            if (all(abs(B$svi1_catch_tract[B$catch_source == "county_fallback"] -
                        B$svi1_county[B$catch_source == "county_fallback"]) < 1e-9, na.rm = TRUE)) "YES" else "NO"))
cat(sprintf("  county-native _catch_tract == _catch_county exactly: %s\n",
            if (all(abs(B$rurality_catch_tract - B$rurality_catch_county) < 1e-9, na.rm = TRUE)) "YES" else "NO"))
r_cc <- corr$r_catchcounty_county[corr$covariate %in% c("svi1","svi2","svi3","svi4")]
cat(sprintf("  SVI r(catch_county, county) in 0.89-0.97 (corroborates Phase 0): %s  [%s]\n",
            if (all(r_cc >= 0.85 & r_cc <= 0.99)) "YES" else "CHECK",
            paste(sprintf("%.3f", r_cc), collapse = " ")))
stopifnot(nrow(blockB) == N, !anyDuplicated(blockB$ccn), allfour, length(missing_variants) == 0)

hdr("done")
