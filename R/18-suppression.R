# R/18-suppression.R  --  Task S3.2, the suppression sensitivity at both
# catchment grains, measured on the quantities the report interprets.
# make.R stage 44. POST-REVIEW.
#
# 87% of HSAF cells (hospital x patient ZIP) are suppressed (fewer than 11
# Medicare discharges). The catchment weights renormalise over the OBSERVED
# cells. Phase 0 tested that at one fill (3 discharges per suppressed cell),
# on covariate correlations, at county grain. The review: test it at both
# grains, under several fills, on what the report reads.
#
# ALLOCATIONS (second-pass-preregistration.md sec 7): every suppressed cell
# set to 1, 3, 5.5 and 10 discharges, and 20 draws of a uniform integer on
# 1..10 per cell (seed 20261001 + draw). The fill applies to every suppressed
# cell in the file, so market concentration (HHI, built from all providers'
# cells) is rebuilt too. Which hospitals are catchment-weighted and which take
# the county fallback stays as built: gate B0 is defined on observed cells.
#
# MEASURED ON, for spec 382 (P-best, county-grain catchment) and spec 344 (its
# tract-grain sibling): the in-sample loss on the 2,569-hospital frame, the
# joint p10 -> p90 disadvantage contrast, and each hospital's rank on its
# community contribution (the fitted Block B part of its prediction, market
# concentration included). Ranks are reported for all frame hospitals and,
# separately, for the bottom decile of catchment-weighted frame hospitals by
# mapped discharges (observed discharges on ZIPs the allocation can place:
# obs_cases x zip_matched_share, from data/catchment.rds) -- the hospitals
# whose catchment rests on least observed data. Rule fixed before any filled
# output was computed. Covariate correlations are kept for continuity.
#
# CHECKS. (1) With no fill, the vectorised weight builder reproduces
# data/catchment-weights.rds, and the value tables reproduce every
# _catch_tract and _catch_county column of the ten measures and hhi_zip in
# data/analytic-v2.rds. (2) Specs 382 and 344 are reproduced (stored joint
# contrast to 1e-8, stored loss to 1e-10) before any fill is applied.
#
# This is a sensitivity check over five allocation rules, not a bound: the
# true sizes of suppressed cells are unknown and could be distributed in ways
# none of these rules represents (for example, correlated with disadvantage).
#
# SUPPLEMENTARY (added after the preregistered rows were seen): the four
# constants again with market concentration held as built.
#
# Output: output/tables/suppression-sensitivity.csv, the log. About 11 min.

suppressMessages(library(splines))
n_   <- function(x) suppressWarnings(as.numeric(trimws(x)))
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
rd   <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                       na.strings = character(0), fileEncoding = enc)
z5   <- function(x) formatC(trimws(x), width = 5, flag = "0")
svi_na <- function(x) { v <- n_(x); v[!is.na(v) & v < 0] <- NA; v }
source(file.path("R", "hsaf.R"))
BB <- file.path("data-raw", "blockB"); ADI <- file.path("data-raw", "blockB_adi"); ACS <- file.path("data-raw", "blockB_acs")
SEED <- 20261001L; FILLS <- c(1, 3, 5.5, 10); NDRAW <- 20L
WEIGHT_PRUNE <- 1e-6                                  # as R/catchment.R

hdr("TASK S3.2  suppression sensitivity -- stage 44 (post-review)")

a   <- readRDS(file.path("data", "analytic-v2.rds"))
CAT <- readRDS(file.path("data", "catchment.rds")); CAT <- CAT[match(a$ccn, CAT$ccn), ]
W0  <- readRDS(file.path("data", "catchment-weights.rds"))
SR  <- readRDS(file.path("data", "spec-results.rds"))$results
LOS <- readRDS(file.path("data", "rashomon-loss.rds"))
stopifnot(identical(CAT$ccn, a$ccn))
SPECS <- c(catch_county = 382, catch_tract = 344)

## the allocation functions, taken from R/catchment.R without running its stage
env_c <- new.env(); assign("BB", BB, env_c); assign("rd", rd, env_c); assign("n_", n_, env_c); assign("z5", z5, env_c)
for (ex in parse(file.path("R", "catchment.R")))
  if (is.call(ex) && identical(ex[[1]], as.name("<-")) &&
      is.name(ex[[2]]) && as.character(ex[[2]]) %in% c("build_zcta_tract_alloc", "pop_key", "alloc_from_parts")) eval(ex, env_c)

# ==========================================================================
# 1.  HSAF CELLS AND THE ALLOCATION (built once)
# ==========================================================================
sub_("HSAF cells and the ZCTA -> tract allocation")
h <- read_hsaf(file.path("data-raw", "hsaf", "Hospital_Service_Area_2023.csv"))
h$ccn <- trimws(h$MEDICARE_PROV_NUM); h$zip <- z5(h$ZIP_CD_OF_RESIDENCE); h$cases <- n_(h$TOTAL_CASES)
SUPP <- is.na(h$cases)
cat(sprintf("  HSAF cells %s, suppressed %s (%.2f%%)\n", format(nrow(h), big.mark = ","),
            format(sum(SUPP), big.mark = ","), 100 * mean(SUPP)))
## the catchment cells: frame, admissible, geographic ZIPs (R/catchment.R's filter)
bad_zip <- !nzchar(trimws(h$ZIP_CD_OF_RESIDENCE)) | h$zip %in% c("00000", "99999") | grepl("NA", h$zip)
ADM <- a$ccn[CAT$catch_source == "catchment"]
ic <- which(h$ccn %in% ADM & !bad_zip)
alloc_tbl <- env_c$build_zcta_tract_alloc()
## expansion: catchment cell -> allocation rows of its ZIP (fixed across fills)
ar <- split(seq_len(nrow(alloc_tbl)), alloc_tbl$zcta)
cz <- h$zip[ic]; present <- cz %in% names(ar)
EXP_cell <- rep(seq_along(ic), ifelse(present, lengths(ar[cz]), 0L))
EXP_arow <- unlist(ar[cz[present]], use.names = FALSE)
cell_ccn <- factor(h$ccn[ic], levels = ADM)
exp_key  <- factor(paste(h$ccn[ic][EXP_cell], alloc_tbl$tract[EXP_arow]))
key_ccn  <- sub(" .*", "", levels(exp_key)); key_tr <- sub(".* ", "", levels(exp_key))
cat(sprintf("  catchment cells %s for %d hospitals; %s expanded to tract slices\n",
            format(length(ic), big.mark = ","), length(ADM), format(length(EXP_cell), big.mark = ",")))

## one hospital-by-tract weight table from a vector of cell cases (R/catchment.R
## catchment_weights_one, vectorised): renormalise over the hospital's cells,
## then over the ZIPs the allocation can place, allocate, sum, prune, renormalise
weights_from <- function(cases) {
  cs <- ifelse(is.na(cases) | cases <= 0, 0, cases)
  tot <- rowsum(cs, cell_ccn)[, 1]; wz <- cs / tot[as.integer(cell_ccn)]
  matched <- rowsum(wz * present, cell_ccn)[, 1]
  wz2 <- wz / matched[as.integer(cell_ccn)]
  wt <- rowsum(alloc_tbl$share[EXP_arow] * wz2[EXP_cell], exp_key)[, 1]
  W <- data.frame(ccn = key_ccn, tract_geoid = key_tr, weight = wt, stringsAsFactors = FALSE)
  W <- W[W$weight > 0, ]
  keep <- W$weight >= WEIGHT_PRUNE
  anyk <- tapply(keep, W$ccn, any); keep <- keep | !anyk[W$ccn]
  W <- W[keep, ]; W$weight <- W$weight / tapply(W$weight, W$ccn, sum)[W$ccn]
  W
}

# ==========================================================================
# 2.  VALUE TABLES (R/blockB.R, the ten measures)
# ==========================================================================
sub_("value tables for the ten measures (as R/blockB.R)")
svt <- rd(file.path(BB, "SVI_2022_US.csv")); svt$FIPS <- formatC(trimws(svt$FIPS), width = 11, flag = "0")
svc <- rd(file.path(BB, "SVI_2022_US_county.csv")); svc$FIPS <- z5(svc$FIPS)
ct22 <- svt$FIPS[substr(svt$FIPS, 1, 2) == "09"]; ct_map <- setNames(ct22, substr(ct22, 6, 11))
remap_ct <- function(tr) { k <- !is.na(tr) & substr(tr, 1, 2) == "09"
  hit <- ct_map[substr(tr[k], 6, 11)]; tr[k] <- ifelse(is.na(hit), tr[k], hit); tr }
VT <- list(); VC <- list()
SVI_COLS <- c(svi1 = "RPL_THEME1", svi2 = "RPL_THEME2", svi3 = "RPL_THEME3", svi4 = "RPL_THEME4",
              uninsured = "EP_UNINSUR", limeng = "EP_LIMENG")
for (m in names(SVI_COLS)) { VT[[m]] <- setNames(svi_na(svt[[SVI_COLS[[m]]]]), svt$FIPS)
                             VC[[m]] <- setNames(svi_na(svc[[SVI_COLS[[m]]]]), svc$FIPS) }
ice <- rd(file.path(ACS, "acs2024_5yr_B19001_tract.csv")); ice$GEOID <- formatC(trimws(ice$GEOID), width = 11, flag = "0")
tot_t <- n_(ice$B19001_001E)
lo_t  <- rowSums(sapply(sprintf("B19001_%03dE", 2:5), function(v) n_(ice[[v]])))
h15_t <- rowSums(sapply(sprintf("B19001_%03dE", 16:17), function(v) n_(ice[[v]])))
VT$ice150 <- setNames(ifelse(tot_t > 0, (h15_t - lo_t) / tot_t, NA_real_), ice$GEOID)
icc <- aggregate(cbind(tot, lo, h15) ~ county, data.frame(county = substr(ice$GEOID, 1, 5), tot = tot_t, lo = lo_t, h15 = h15_t), sum)
VC$ice150 <- setNames(ifelse(icc$tot > 0, (icc$h15 - icc$lo) / icc$tot, NA_real_), icc$county)
bgp <- rd(file.path(ACS, "acs2024_5yr_B01003_blockgroup.csv")); bgp$GEOID <- formatC(trimws(bgp$GEOID), width = 12, flag = "0")
bgpop <- setNames(pmax(0, n_(bgp$B01003_001E)), bgp$GEOID)
ad <- rd(file.path(ADI, "US_2024_block_group_adi_v_4_0_1.csv")); ad$FIPS <- formatC(trimws(ad$FIPS), width = 12, flag = "0")
ad$rank <- suppressWarnings(as.numeric(ad$ADI_NATRANK)); ad$tract <- remap_ct(substr(ad$FIPS, 1, 11))
ad$county <- substr(ad$tract, 1, 5); ad$pop <- bgpop[paste0(ad$tract, substr(ad$FIPS, 12, 12))]; ad$pop[is.na(ad$pop)] <- 0
ob <- !is.na(ad$rank) & ad$pop > 0
VT$adi <- tapply(ad$pop[ob] * ad$rank[ob], ad$tract[ob], sum) / tapply(ad$pop[ob], ad$tract[ob], sum)
VC$adi <- tapply(ad$pop[ob] * ad$rank[ob], ad$county[ob], sum) / tapply(ad$pop[ob], ad$county[ob], sum)
ru <- rd(file.path(BB, "Ruralurbancontinuumcodes2023.csv")); ru <- ru[trimws(ru$Attribute) == "RUCC_2023", ]
VC$rurality <- setNames(n_(ru$Value), z5(ru$FIPS))
td <- tempfile(); dir.create(td); unzip(file.path(BB, "AHRF_2023-2024_SAS.zip"), exdir = td)
ah <- haven::read_sas(list.files(td, pattern = "\\.sas7bdat$", recursive = TRUE, full.names = TRUE)[1])
ah_fips <- formatC(trimws(ah$fips_st_cnty), width = 5, flag = "0")
pcp <- suppressWarnings(as.numeric(ah$phys_nf_prim_care_pc_exc_rsdt_22)); pop22 <- suppressWarnings(as.numeric(ah$popn_est_22))
VC$pcp_density <- setNames(ifelse(!is.na(pop22) & pop22 > 0, 1e5 * pcp / pop22, NA_real_), ah_fips)
cens20 <- suppressWarnings(as.numeric(ah$cens_popn_20)); ct_legacy <- ah_fips %in% sprintf("090%02d", seq(1, 15, 2))
ct_pcp <- 1e5 * sum(pcp[ct_legacy], na.rm = TRUE) / sum(cens20[ct_legacy], na.rm = TRUE)
for (pr in sprintf("091%d0", 1:9)) VC$pcp_density[pr] <- ct_pcp
COUNTY_NATIVE <- c("rurality", "pcp_density")
DIS_SIGN <- c(svi1 = 1, svi2 = 1, svi3 = 1, svi4 = 1, adi = 1, ice150 = -1,
              uninsured = 1, limeng = 1, rurality = 1, pcp_density = -1)
DIS <- names(DIS_SIGN)

## catchment values for all frame hospitals; fallback hospitals keep their built
## value (their county's), which no fill can change
FB <- CAT$catch_source == "county_fallback"
catch_values <- function(W) {
  W$tract_geoid <- remap_ct(W$tract_geoid); W$county <- substr(W$tract_geoid, 1, 5)
  Wc <- aggregate(weight ~ ccn + county, W, sum)
  wm <- function(ccn, w, v) { ok <- !is.na(v)
    num <- rowsum(w[ok] * v[ok], ccn[ok])[, 1]; den <- rowsum(w[ok], ccn[ok])[, 1]
    out <- (num / den)[a$ccn]; names(out) <- NULL; out }
  out <- list()
  for (m in DIS) for (g in c("catch_tract", "catch_county")) {
    v <- if (m %in% COUNTY_NATIVE || g == "catch_county") wm(Wc$ccn, Wc$weight, unname(VC[[m]][Wc$county]))
         else wm(W$ccn, W$weight, unname(VT[[m]][W$tract_geoid]))
    v[FB] <- n_(a[[paste0(m, "_", g)]])[FB]
    out[[paste0(m, "_", g)]] <- v
  }
  out
}
## market concentration (R/blockB.R sec 4) from a vector of cell cases, all providers
zip_okH <- nzchar(h$ccn) & !h$zip %in% c("00000", "99999")
hhi_from <- function(cases) {
  k <- zip_okH & !is.na(cases); x <- data.frame(prov = h$ccn[k], zip = h$zip[k], cases = cases[k])
  zt <- tapply(x$cases, x$zip, sum); x$share <- x$cases / zt[x$zip]
  hz <- tapply(x$share^2, x$zip, sum) * 1e4
  f <- x[x$prov %in% a$ccn, ]
  num <- rowsum(f$cases * hz[f$zip], f$prov)[, 1]; den <- rowsum(f$cases, f$prov)[, 1]
  unname((num / den)[a$ccn])
}

# ==========================================================================
# 3.  CHECK 1 -- no fill reproduces the built weights and columns
# ==========================================================================
sub_("check 1: observed cells only reproduce the built weights, columns and HHI")
Wb <- weights_from(h$cases[ic])
k0 <- paste(W0$ccn, W0$tract_geoid); kb <- paste(Wb$ccn, Wb$tract_geoid)
stopifnot(setequal(k0, kb))
dw <- max(abs(W0$weight - Wb$weight[match(k0, kb)]))
cat(sprintf("  weights: %s rows, same hospital-tract pairs, max |diff| %.1e\n", format(nrow(Wb), big.mark = ","), dw))
stopifnot(dw < 1e-12)
V0 <- catch_values(Wb)
for (nm in names(V0)) { ref <- n_(a[[nm]]); got <- V0[[nm]]; both <- is.finite(ref) & is.finite(got)
  mx <- max(abs(ref[both] - got[both]))
  if (!(mx < 1e-10 && identical(is.na(ref), is.na(got)))) stop(sprintf("check 1 fails on %s: %.2e", nm, mx)) }
hb <- hhi_from(h$cases); hr <- n_(a$hhi_zip); both <- is.finite(hr) & is.finite(hb)
cat(sprintf("  %d catchment columns reproduced (max |diff| < 1e-10, same NAs); hhi_zip max |diff| %.1e\n",
            length(V0), max(abs(hr[both] - hb[both]))))
stopifnot(max(abs(hr[both] - hb[both])) < 1e-8, identical(is.na(hr), is.na(hb)))

# ==========================================================================
# 4.  THE MODELS -- spec 382 / 344's design (as R/16-geo-construction.R)
# ==========================================================================
bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy", resident_to_bed = "resident_to_bed",
        teaching = "teaching", cmi = "cmi", volume = "volume_bills", dsh_pct = "dsh_pct",
        wage_index = "wage_index", operating_margin = "operating_margin",
        uncomp_care = "uncompensated_care_pct_npr")
bC <- c(cmi_drift = "cmi_drift", contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")
BBm <- c(DIS, "hhi")
SPLINE_SET <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng")
sd_psi90 <- sd(n_(a$psi90), na.rm = TRUE)
frame_for <- function(g, V, hhi) {
  d <- data.frame(ccn = a$ccn, psi90 = n_(a$psi90), stringsAsFactors = FALSE)
  for (k in names(bA)) d[[k]] <- if (k == "teaching") as.numeric(a$teaching) else n_(a[[bA[[k]]]])
  for (k in names(bC)) d[[k]] <- n_(a[[bC[[k]]]])
  for (b in DIS) d[[b]] <- V[[paste0(b, "_", g)]]
  d$hhi <- hhi
  d
}
fit_design <- function(d, keep) {
  cont <- setdiff(c(names(bA), BBm, names(bC)), "teaching")
  Z <- sapply(cont, function(k) c(mu = mean(d[[k]], na.rm = TRUE), sd = sd(d[[k]], na.rm = TRUE)))
  KN <- lapply(setNames(SPLINE_SET, SPLINE_SET), function(b) { z <- (d[[b]] - Z["mu", b]) / Z["sd", b]
    list(k = signif(quantile(z, c(.25, .5, .75), na.rm = TRUE, names = FALSE), 8),
         bk = signif(quantile(z, c(.05, .95), na.rm = TRUE, names = FALSE), 8)) })
  zq <- sapply(DIS, function(k) (quantile(d[[k]], c(.1, .9), na.rm = TRUE, names = FALSE) - Z["mu", k]) / Z["sd", k])
  X_of <- function(zd) {
    out <- list(`(Intercept)` = rep(1, nrow(zd)))
    for (k in names(bA)) out[[k]] <- zd[[k]]
    for (b in BBm) if (b %in% SPLINE_SET) {
      B <- ns(zd[[b]], knots = KN[[b]]$k, Boundary.knots = KN[[b]]$bk)
      for (j in seq_len(ncol(B))) out[[paste0(b, "_ns", j)]] <- B[, j]
    } else out[[b]] <- zd[[b]]
    for (k in names(bC)) out[[k]] <- zd[[k]]
    do.call(cbind, out)
  }
  zd <- d[keep, ]
  for (k in cont) zd[[k]] <- (zd[[k]] - Z["mu", k]) / Z["sd", k]
  X <- X_of(zd); m <- lm.fit(X, zd$psi90); b <- m$coefficients; b[is.na(b)] <- 0
  most <- setNames(ifelse(DIS_SIGN > 0, zq[2, ], zq[1, ]), DIS); least <- setNames(ifelse(DIS_SIGN > 0, zq[1, ], zq[2, ]), DIS)
  zero <- as.data.frame(lapply(setNames(c(names(bA), BBm, names(bC)), c(names(bA), BBm, names(bC))), function(k) 0))
  H <- zero; L <- zero; for (k in DIS) { H[[k]] <- most[[k]]; L[[k]] <- least[[k]] }
  XX <- X_of(rbind(H, L, zd[1:5, names(H)])); cv <- XX[1, ] - XX[2, ]
  bcols <- grep(paste0("^(", paste(BBm, collapse = "|"), ")(_ns[0-9]+)?$"), colnames(X))
  list(n = nrow(X), loss = mean(m$residuals^2), joint = sum(cv * b) / sd_psi90,
       contrib = as.numeric(X[, bcols, drop = FALSE] %*% b[bcols]))
}
complete_rows <- function(d) { ok <- is.finite(d$psi90)
  for (k in setdiff(names(d), "ccn")) ok <- ok & is.finite(d[[k]]); ok }

sub_("check 2: specs 382 and 344 reproduced from the rebuilt columns")
FR0 <- lapply(setNames(names(SPECS), names(SPECS)), function(g) frame_for(g, V0, hb))
KEEP <- complete_rows(FR0$catch_county) & complete_rows(FR0$catch_tract)
BASE <- list()
for (g in names(SPECS)) {
  f <- fit_design(FR0[[g]], KEEP); st <- SR[SR$spec_id == SPECS[[g]], ]
  sl <- LOS$loss[LOS$spec_id == SPECS[[g]]]
  cat(sprintf("  %-12s spec %d  n %d  joint %+.6f (stored %+.6f)  loss %.8f (stored %.8f)\n", g, SPECS[[g]],
              f$n, f$joint, st$dis_effect / sd_psi90, f$loss, sl))
  stopifnot(f$n == 2569, abs(f$joint - st$dis_effect / sd_psi90) < 1e-8, abs(f$loss - sl) < 1e-10)
  BASE[[g]] <- f
}
cat("  PASS\n")

## the bottom decile by mapped discharges, among catchment-weighted frame hospitals
mapped <- n_(CAT$obs_cases) * n_(CAT$zip_matched_share)
fr <- which(KEEP)
cw_fr <- fr[!FB[fr]]
cut10 <- quantile(mapped[cw_fr], 0.10, names = FALSE)
LOWD <- KEEP & !FB & mapped <= cut10
cat(sprintf("  frame %d: %d catchment-weighted, %d county fallback; bottom decile by mapped discharges: %d hospitals (<= %.0f discharges)\n",
            length(fr), length(cw_fr), sum(FB[fr]), sum(LOWD), cut10))
cat(sprintf("  suppressed share of their cells: median %.1f%% (all catchment-weighted: %.1f%%)\n",
            100 * median(n_(CAT$n_supp_cells)[LOWD] / n_(CAT$n_cells)[LOWD]),
            100 * median(n_(CAT$n_supp_cells)[cw_fr] / n_(CAT$n_cells)[cw_fr])))

# ==========================================================================
# 5.  THE ALLOCATIONS
# ==========================================================================
hdr("allocations: every suppressed cell filled, both grains")
rk <- function(x) rank(x, ties.method = "average")
grp <- list(all = rep(TRUE, length(fr)), low_decile = LOWD[fr], fallback = FB[fr])
ROWS <- list()
run_fill <- function(label, fill_vec, draw = NA, hhi_built = FALSE) {
  cases <- h$cases; cases[SUPP] <- fill_vec
  Wf <- weights_from(cases[ic]); Vf <- catch_values(Wf); hf <- if (hhi_built) hb else hhi_from(cases)
  for (g in names(SPECS)) {
    d <- frame_for(g, Vf, hf)
    stopifnot(all(complete_rows(d)[KEEP]))
    f <- fit_design(d, KEEP); b0 <- BASE[[g]]
    r0 <- rk(b0$contrib); r1 <- rk(f$contrib); drk <- abs(r1 - r0)
    cov_r <- sapply(DIS, function(m) cor(FR0[[g]][[m]][KEEP], d[[m]][KEEP]))
    for (gn in names(grp)) { s <- grp[[gn]]
      ROWS[[length(ROWS) + 1]] <<- data.frame(
        allocation = label, draw = draw, grain = g, spec_id = SPECS[[g]], group = gn, n = sum(s),
        loss = f$loss, loss_change_pct = 100 * (f$loss / b0$loss - 1),
        joint = f$joint, joint_change = f$joint - b0$joint,
        rank_spearman = cor(r0[s], r1[s]), rank_change_median = median(drk[s]),
        rank_change_p90 = quantile(drk[s], .9, names = FALSE), rank_change_max = max(drk[s]),
        contrib_r = cor(b0$contrib[s], f$contrib[s]),
        cov_r_min = min(cov_r), cov_r_min_measure = names(which.min(cov_r)),
        hhi_r = cor(FR0[[g]]$hhi[KEEP][s], d$hhi[KEEP][s]), stringsAsFactors = FALSE)
    }
  }
}
t0 <- Sys.time()
for (c_ in FILLS) { run_fill(sprintf("constant %s", format(c_)), c_); cat(sprintf("  constant %-4s done\n", format(c_))) }
for (b in seq_len(NDRAW)) { set.seed(SEED + b); run_fill("uniform 1-10", sample.int(10L, sum(SUPP), replace = TRUE), b) }
cat(sprintf("  %d uniform draws done (%.0f s in all)\n", NDRAW, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
## SUPPLEMENTARY, added after the rows above were seen (note sec 4): the same
## constants with market concentration kept as built, so that the movement can
## be split between the ten disadvantage measures and HHI
for (c_ in FILLS) run_fill(sprintf("constant %s, HHI as built", format(c_)), c_, hhi_built = TRUE)
cat("  supplementary: constants with HHI as built done\n")
OUT <- do.call(rbind, ROWS)
write.csv(OUT, file.path("output", "tables", "suppression-sensitivity.csv"), row.names = FALSE)

# ==========================================================================
# 6.  RESULTS
# ==========================================================================
sub_("constants: loss, joint contrast, community-contribution ranks")
cat(sprintf("  %-14s %-12s %-10s %8s %9s %8s %7s %7s %7s %6s %7s\n", "allocation", "grain", "group", "loss %",
            "joint", "d joint", "rho", "med d", "p90 d", "max d", "cov r"))
pr <- function(x) for (i in seq_len(nrow(x))) with(x[i, ], cat(sprintf(
  "  %-14s %-12s %-10s %+8.3f %+9.4f %+8.4f %7.4f %7.1f %7.1f %6.0f %7.4f\n", allocation, grain, group, loss_change_pct,
  joint, joint_change, rank_spearman, rank_change_median, rank_change_p90, rank_change_max, cov_r_min)))
pr(OUT[is.na(OUT$draw) & !grepl("HHI as built", OUT$allocation), ])
sub_("SUPPLEMENTARY (post hoc): constants with market concentration kept as built")
pr(OUT[grepl("HHI as built", OUT$allocation), ])
sub_("uniform 1-10, 20 draws: median [max] over draws")
U <- OUT[!is.na(OUT$draw), ]
for (g in names(SPECS)) for (gn in names(grp)) { x <- U[U$grain == g & U$group == gn, ]
  cat(sprintf("  %-12s %-10s loss %+.3f%% [%+.3f]  d joint %+.4f [%+.4f..%+.4f]  rho %.4f [min %.4f]  max rank d %.0f [%.0f]\n",
              g, gn, median(x$loss_change_pct), max(abs(x$loss_change_pct)), median(x$joint_change), min(x$joint_change),
              max(x$joint_change), median(x$rank_spearman), min(x$rank_spearman), median(x$rank_change_max), max(x$rank_change_max))) }

LD <- OUT[OUT$group == "low_decile", ]
cat(sprintf("\n  LOW-WEIGHT DECILE (%d hospitals): largest rank change on the community contribution, any allocation,\n", sum(LOWD)))
for (g in names(SPECS)) { x <- LD[LD$grain == g & !grepl("HHI as built", LD$allocation), ]; i <- which.max(x$rank_change_max)
  cat(sprintf("    %-12s %.0f positions of %d (%s%s); all hospitals: %.0f\n", g, x$rank_change_max[i], length(fr), x$allocation[i],
              if (is.na(x$draw[i])) "" else sprintf(", draw %d", x$draw[i]),
              max(OUT$rank_change_max[OUT$grain == g & OUT$group == "all" & !grepl("HHI as built", OUT$allocation)]))) }

# ==========================================================================
hdr("verify")
cat("  1. no fill reproduces the built weights, every catchment column and hhi_zip, and specs\n")
cat("     382/344 (joint 1e-8, loss 1e-10), before any fill -- PASS\n")
cat(sprintf("  2. the low-weight decile's largest rank change is reported as a number (above)\n"))
cat("  3. a sensitivity check over five allocation rules; the true suppressed sizes are unknown,\n")
cat("     so nothing here bounds the effect of suppression\n")
hdr("done")
