# R/16-geo-construction.R  --  Task S2.6, geography as a construction question.
# make.R stage 42. POST-REVIEW.
#
# The Sep 30 draft read the sign split between county- and tract-grain
# catchment weighting (spec 382 at -0.21 SD, spec 344 at +0.13) as a question
# finer patient-origin data would settle. The review's point: the two grains do
# not measure the same quantity. An SVI theme at tract grain is a discharge-
# weighted mean of TRACT percentile ranks (ranked among 84,000 tracts); at
# county grain it is a mean of COUNTY percentile ranks (ranked among 3,100
# counties). A change of grain changes the measurement as well as the
# aggregation.
#
# This stage holds the measurement constant and lets only the aggregation vary.
#
# SELECTION RULE (fixed before any rebuilt value was computed; note sec 1):
# rebuild every Block B measure whose two catchment grains are built from
# different quantities. That is the four SVI themes (rank among tracts vs rank
# among counties). The uninsured and limited-English shares are the same
# quantity at both grains but the county value comes from the ACS county table
# rather than from the tracts, so they are rebuilt too, making their county
# value an exact aggregate of the tract inputs. ICE (summed household counts)
# and ADI (population-weighted block-group ranks) are already exact aggregates
# at both grains; rurality and primary-care density are county-native and
# identical at both catchment grains. They are left as built.
#
# THE REBUILD. Each SVI theme becomes the mean of its estimate percentages
# (EP_* in the SVI 2022 file), each standardized against the population-
# weighted national distribution of TRACT values -- one fixed reference used at
# both grains. A county's EP is the population-weighted (E_TOTPOP) mean of its
# tracts' EPs. Catchment weighting then proceeds exactly as R/blockB.R does it:
# tract grain = discharge-weighted mean over the catchment's tracts; county
# grain = the same discharge weights summed to county, applied to county values;
# county-fallback hospitals take their own county's value at both grains.
#   theme 1  POV150 UNEMP HBURD NOHSDP UNINSUR       theme 3  MINRTY
#   theme 2  AGE65 AGE17 DISABL SNGPNT LIMENG        theme 4  MUNIT MOBILE CROWD NOVEH GROUPQ
#
# CHECKS. (1) The weighting code, fed the ORIGINAL inputs (RPL ranks and the
# county file's EPs), reproduces every original _catch_tract and _catch_county
# value in data/analytic-v2.rds for the six measures. (2) Specs 382 and 344 are
# reproduced (stored joint contrast to 1e-8) before anything is swapped.
# (3) Original and rebuilt fits share the same hospitals, outcome, terms,
# transformation rule and estimator; only the Block B columns differ.
#
# Output: output/tables/geo-construction.csv, the log.

suppressMessages(library(splines))
n_   <- function(x) suppressWarnings(as.numeric(trimws(x)))
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
rd   <- function(p) read.csv(p, colClasses = "character", check.names = FALSE, na.strings = character(0))
svi_na <- function(x) { v <- n_(x); v[!is.na(v) & v < 0] <- NA; v }

hdr("TASK S2.6  geography as a construction question -- stage 42 (post-review)")

a   <- readRDS(file.path("data", "analytic-v2.rds"))
reg <- readRDS(file.path("data", "spec-registry.rds"))
SR  <- readRDS(file.path("data", "spec-results.rds"))$results
W   <- readRDS(file.path("data", "catchment-weights.rds"))
svt <- rd(file.path("data-raw", "blockB", "SVI_2022_US.csv"))
svc <- rd(file.path("data-raw", "blockB", "SVI_2022_US_county.csv"))
svt$FIPS <- formatC(trimws(svt$FIPS), width = 11, flag = "0")
svc$FIPS <- formatC(trimws(svc$FIPS), width = 5, flag = "0")
SPECS <- c(catch_county = 382, catch_tract = 344)
REBUILD <- c("svi1", "svi2", "svi3", "svi4", "uninsured", "limeng")
THEMES <- list(svi1 = c("EP_POV150", "EP_UNEMP", "EP_HBURD", "EP_NOHSDP", "EP_UNINSUR"),
               svi2 = c("EP_AGE65", "EP_AGE17", "EP_DISABL", "EP_SNGPNT", "EP_LIMENG"),
               svi3 = c("EP_MINRTY"),
               svi4 = c("EP_MUNIT", "EP_MOBILE", "EP_CROWD", "EP_NOVEH", "EP_GROUPQ"))

# ==========================================================================
# 1.  CATCHMENT WEIGHTING, as R/blockB.R does it
# ==========================================================================
## Connecticut: weights are on 2020 tract codes, SVI on 2022 planning-region
## codes; same 6-digit suffix (R/blockB.R, provenance/task2.5-blockB.md sec 2)
ct22 <- svt$FIPS[substr(svt$FIPS, 1, 2) == "09"]
ct_map <- setNames(ct22, substr(ct22, 6, 11))
remap_ct <- function(tr) { k <- !is.na(tr) & substr(tr, 1, 2) == "09"
  hit <- ct_map[substr(tr[k], 6, 11)]; tr[k] <- ifelse(is.na(hit), tr[k], hit); tr }
W$tract_geoid <- remap_ct(W$tract_geoid)
W$county <- substr(W$tract_geoid, 1, 5)
Wc <- aggregate(weight ~ ccn + county, W, sum)
W_by <- split(W[, c("tract_geoid", "weight")], W$ccn)
Wc_by <- split(Wc[, c("county", "weight")], Wc$ccn)
wmean <- function(v, w) { ok <- !is.na(v) & !is.na(w) & w > 0
  if (!any(ok)) NA_real_ else sum(w[ok] * v[ok]) / sum(w[ok]) }
FB <- a$catch_source == "county_fallback"
## both catchment grains for one measure, given tract and county value tables
catch_both <- function(vt, vc) {
  ct <- cc <- rep(NA_real_, nrow(a))
  for (i in seq_len(nrow(a))) {
    f <- a$ccn[i]
    if (FB[i]) { ct[i] <- cc[i] <- unname(vc[a$county_fips[i]]); next }
    wt <- W_by[[f]]; wc <- Wc_by[[f]]
    if (!is.null(wt)) ct[i] <- wmean(vt[wt$tract_geoid], wt$weight)
    if (!is.null(wc)) cc[i] <- wmean(vc[wc$county], wc$weight)
  }
  list(catch_tract = ct, catch_county = cc)
}

# ==========================================================================
# 2.  CHECK 1 -- the original inputs reproduce the original columns
# ==========================================================================
sub_("check 1: the weighting code reproduces the built columns from the original inputs")
ORIG_COL <- c(svi1 = "RPL_THEME1", svi2 = "RPL_THEME2", svi3 = "RPL_THEME3", svi4 = "RPL_THEME4",
              uninsured = "EP_UNINSUR", limeng = "EP_LIMENG")
ORIG <- list()
for (m in REBUILD) {
  vt <- setNames(svi_na(svt[[ORIG_COL[[m]]]]), svt$FIPS)
  vc <- setNames(svi_na(svc[[ORIG_COL[[m]]]]), svc$FIPS)
  ORIG[[m]] <- catch_both(vt, vc)
  for (g in c("catch_tract", "catch_county")) {
    ref <- n_(a[[paste0(m, "_", g)]]); got <- ORIG[[m]][[g]]
    both <- is.finite(ref) & is.finite(got)
    mx <- if (any(both)) max(abs(ref[both] - got[both])) else NA
    cat(sprintf("  %-10s %-13s max |diff| %.1e   NA agree %s\n", m, g, mx,
                identical(is.na(ref), is.na(got))))
    stopifnot(mx < 1e-10, identical(is.na(ref), is.na(got)))
  }
}
cat("  PASS -- every original catchment value reproduced\n")

# ==========================================================================
# 3.  THE REBUILD -- estimate percentages, one reference, exact aggregation
# ==========================================================================
sub_("rebuild: SVI themes from estimate percentages; county = population-weighted tracts")
pop <- n_(svt$E_TOTPOP); pop[is.na(pop) | pop < 0] <- 0
county_of <- substr(svt$FIPS, 1, 5)
EPS <- unique(c(unlist(THEMES), "EP_UNINSUR", "EP_LIMENG"))
ep_t <- sapply(EPS, function(v) svi_na(svt[[v]]))           # tracts x EPs
rownames(ep_t) <- svt$FIPS
## county EP: population-weighted mean of its tracts' EPs
ep_c <- sapply(EPS, function(v) { x <- ep_t[, v]; ok <- !is.na(x) & pop > 0
  tapply(x[ok] * pop[ok], county_of[ok], sum) / tapply(pop[ok], county_of[ok], sum) })
## the one fixed reference: population-weighted national tract mean and SD
ref <- sapply(EPS, function(v) { x <- ep_t[, v]; ok <- !is.na(x) & pop > 0
  mu <- sum(pop[ok] * x[ok]) / sum(pop[ok]); c(mu = mu, sd = sqrt(sum(pop[ok] * (x[ok] - mu)^2) / sum(pop[ok]))) })
theme_score <- function(M, eps) {
  Z <- sweep(sweep(M[, eps, drop = FALSE], 2, ref["mu", eps]), 2, ref["sd", eps], "/")
  rowMeans(Z)                                              # NA if any component missing
}
REB <- list()
for (m in REBUILD) {
  if (m %in% names(THEMES)) {
    vt <- setNames(theme_score(ep_t, THEMES[[m]]), svt$FIPS)
    vc <- theme_score(ep_c, THEMES[[m]]); names(vc) <- rownames(ep_c)
  } else {
    v <- if (m == "uninsured") "EP_UNINSUR" else "EP_LIMENG"
    vt <- setNames(ep_t[, v], svt$FIPS); vc <- setNames(ep_c[, v], rownames(ep_c))
  }
  REB[[m]] <- catch_both(vt, vc)
}

## cross-grain agreement, original against rebuilt, on the model frame below
# ==========================================================================
# 4.  THE MODELS -- spec 382 / 344's design, any Block B columns
# ==========================================================================
bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy", resident_to_bed = "resident_to_bed",
        teaching = "teaching", cmi = "cmi", volume = "volume_bills", dsh_pct = "dsh_pct",
        wage_index = "wage_index", operating_margin = "operating_margin",
        uncomp_care = "uncompensated_care_pct_npr")
bC <- c(cmi_drift = "cmi_drift", contract_labor_share = "contract_labor_share",
        tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")
BB <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng", "rurality", "pcp_density", "hhi")
DIS_SIGN <- c(svi1 = 1, svi2 = 1, svi3 = 1, svi4 = 1, adi = 1, ice150 = -1,
              uninsured = 1, limeng = 1, rurality = 1, pcp_density = -1)
DIS <- names(DIS_SIGN)
SPLINE_SET <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng")
MATERIAL <- c("adi", "ice150", "svi1", "svi4", "uninsured"); COMPOSITION <- c("svi2", "svi3", "limeng")
APART <- c("rurality", "pcp_density")
sd_psi90 <- sd(n_(a$psi90), na.rm = TRUE)

## a data frame of raw columns for one grain and one construction
frame_for <- function(g, construction) {
  d <- data.frame(ccn = a$ccn, psi90 = n_(a$psi90), stringsAsFactors = FALSE)
  for (k in names(bA)) d[[k]] <- if (k == "teaching") as.numeric(a$teaching) else n_(a[[bA[[k]]]])
  for (k in names(bC)) d[[k]] <- n_(a[[bC[[k]]]])
  for (b in BB) d[[b]] <- n_(a[[if (b == "hhi") "hhi_zip" else paste0(b, "_", g)]])
  if (construction == "rebuilt") for (m in REBUILD) d[[m]] <- REB[[m]][[g]]
  d
}
## fit spec 382/344's design on rows `keep` of d; standardization and knots on
## ALL hospitals of d (the harness's frame-wide rule, the same for every fit)
fit_design <- function(d, keep) {
  cont <- setdiff(c(names(bA), BB, names(bC)), "teaching")
  Z <- sapply(cont, function(k) c(mu = mean(d[[k]], na.rm = TRUE), sd = sd(d[[k]], na.rm = TRUE)))
  KN <- lapply(setNames(SPLINE_SET, SPLINE_SET), function(b) { z <- (d[[b]] - Z["mu", b]) / Z["sd", b]
    list(k = signif(quantile(z, c(.25, .5, .75), na.rm = TRUE, names = FALSE), 8),
         bk = signif(quantile(z, c(.05, .95), na.rm = TRUE, names = FALSE), 8)) })
  zq <- sapply(DIS, function(k) (quantile(d[[k]], c(.1, .9), na.rm = TRUE, names = FALSE) - Z["mu", k]) / Z["sd", k])
  X_of <- function(zd) {
    out <- list(`(Intercept)` = rep(1, nrow(zd)))
    for (k in names(bA)) out[[k]] <- zd[[k]]
    for (b in BB) if (b %in% SPLINE_SET) {
      B <- ns(zd[[b]], knots = KN[[b]]$k, Boundary.knots = KN[[b]]$bk)
      for (j in seq_len(ncol(B))) out[[paste0(b, "_ns", j)]] <- B[, j]
    } else out[[b]] <- zd[[b]]
    for (k in names(bC)) out[[k]] <- zd[[k]]
    do.call(cbind, out)
  }
  zd <- d[keep, ]
  for (k in cont) zd[[k]] <- (zd[[k]] - Z["mu", k]) / Z["sd", k]
  X <- X_of(zd); y <- zd$psi90
  m <- lm.fit(X, y); b <- m$coefficients; keepb <- !is.na(b)
  sig2 <- sum(m$residuals^2) / (nrow(X) - m$rank)
  V <- matrix(0, length(b), length(b)); V[keepb, keepb] <- sig2 * chol2inv(qr.R(qr(X[, keepb, drop = FALSE])))
  b[!keepb] <- 0
  most <- setNames(ifelse(DIS_SIGN > 0, zq[2, ], zq[1, ]), DIS)
  least <- setNames(ifelse(DIS_SIGN > 0, zq[1, ], zq[2, ]), DIS)
  zero <- as.data.frame(lapply(setNames(c(names(bA), BB, names(bC)), c(names(bA), BB, names(bC))), function(k) 0))
  H <- zero; L <- zero; for (k in DIS) { H[[k]] <- most[[k]]; L[[k]] <- least[[k]] }
  ## the two contrast rows are evaluated together with frame rows: ns() on a
  ## single row fails for some boundary configurations
  XX <- X_of(rbind(H, L, zd[1:5, names(H)]))
  cv <- XX[1, ] - XX[2, ]
  part <- function(set) { cols <- grep(paste0("^(", paste(set, collapse = "|"), ")(_ns[0-9]+)?$"), names(cv))
    c(est = sum(cv[cols] * b[cols]) / sd_psi90,
      se = sqrt(as.numeric(t(cv[cols]) %*% V[cols, cols] %*% cv[cols])) / sd_psi90) }
  list(n = nrow(X), cols = colnames(X), loss = mean(m$residuals^2),
       joint = c(est = sum(cv * b) / sd_psi90, se = sqrt(as.numeric(t(cv) %*% V %*% cv)) / sd_psi90),
       parts = rbind(material = part(MATERIAL), composition = part(COMPOSITION), apart = part(APART)),
       measure = t(sapply(DIS, part)))
}
complete_rows <- function(d) { ok <- is.finite(d$psi90)
  for (k in setdiff(names(d), "ccn")) ok <- ok & is.finite(d[[k]]); ok }

# ==========================================================================
# 5.  CHECK 2 -- the stored specs, then the common sample
# ==========================================================================
sub_("check 2: specs 382 and 344 reproduced with the original columns")
for (g in names(SPECS)) {
  d <- frame_for(g, "original"); f <- fit_design(d, complete_rows(d))
  st <- SR[SR$spec_id == SPECS[[g]], ]
  cat(sprintf("  %-12s spec %d  n %d  joint %+.6f (stored %+.6f)\n", g, SPECS[[g]], f$n,
              f$joint[["est"]], st$dis_effect / sd_psi90))
  stopifnot(abs(f$joint[["est"]] - st$dis_effect / sd_psi90) < 1e-8)
}
cat("  PASS\n")
## one common sample: complete at both grains under both constructions
FR <- list()
for (g in names(SPECS)) for (cs in c("original", "rebuilt")) FR[[paste(g, cs)]] <- frame_for(g, cs)
KEEP <- Reduce(`&`, lapply(FR, complete_rows))
cat(sprintf("  common sample, complete at both grains under both constructions: %d hospitals\n", sum(KEEP)))

# ==========================================================================
# 6.  FIT ALL FOUR AND COMPARE
# ==========================================================================
sub_("the four fits: {county, tract} x {original, rebuilt}, same hospitals, same model")
FITS <- lapply(FR, fit_design, keep = KEEP)
stopifnot(length(unique(vapply(FITS, `[[`, integer(1), "n"))) == 1,
          length(unique(lapply(FITS, `[[`, "cols"))) == 1,
          all(vapply(FR, function(d) identical(d$psi90[KEEP], FR[[1]]$psi90[KEEP]), logical(1))))
## only Block B columns differ between the four frames
for (nm in names(FR)) {
  same <- vapply(setdiff(names(FR[[nm]]), BB), function(k) identical(FR[[nm]][[k]], FR[[1]][[k]]), logical(1))
  stopifnot(all(same))
}
cat("  same hospitals, same outcome, same columns, same estimator; only Block B values differ -- PASS\n")

OUT <- list()
add <- function(...) OUT[[length(OUT) + 1]] <<- data.frame(..., stringsAsFactors = FALSE)
for (nm in names(FITS)) { f <- FITS[[nm]]; g <- sub(" .*", "", nm); cs <- sub(".* ", "", nm)
  add(grain = g, construction = cs, quantity = "joint", measure = "all ten", est = f$joint[["est"]], se = f$joint[["se"]], r_grains = NA)
  for (p in rownames(f$parts)) add(grain = g, construction = cs, quantity = "part", measure = p,
                                   est = f$parts[p, "est"], se = f$parts[p, "se"], r_grains = NA)
  for (k in DIS) add(grain = g, construction = cs, quantity = "measure", measure = k,
                     est = f$measure[k, "est"], se = f$measure[k, "se"], r_grains = NA)
  add(grain = g, construction = cs, quantity = "in-sample loss", measure = "", est = f$loss, se = NA, r_grains = NA)
}
for (cs in c("original", "rebuilt")) for (k in DIS)
  add(grain = "tract vs county", construction = cs, quantity = "cross-grain correlation", measure = k, est = NA, se = NA,
      r_grains = cor(FR[[paste("catch_tract", cs)]][[k]][KEEP], FR[[paste("catch_county", cs)]][[k]][KEEP]))
OUT <- do.call(rbind, OUT)
## tract minus county, per construction
DIFF <- do.call(rbind, lapply(c("original", "rebuilt"), function(cs) {
  t_ <- OUT[OUT$grain == "catch_tract" & OUT$construction == cs & OUT$quantity %in% c("joint", "part", "measure"), ]
  c_ <- OUT[OUT$grain == "catch_county" & OUT$construction == cs & OUT$quantity %in% c("joint", "part", "measure"), ]
  data.frame(grain = "tract minus county", construction = cs, quantity = t_$quantity, measure = t_$measure,
             est = t_$est - c_$est, se = NA, r_grains = NA)
}))
OUT <- rbind(OUT, DIFF)
write.csv(OUT, file.path("output", "tables", "geo-construction.csv"), row.names = FALSE)

sub_("cross-grain correlation of each measure on the common sample")
cg <- OUT[OUT$quantity == "cross-grain correlation", ]
for (k in DIS) cat(sprintf("  %-12s original %.3f   rebuilt %.3f%s\n", k, cg$r_grains[cg$measure == k & cg$construction == "original"],
                           cg$r_grains[cg$measure == k & cg$construction == "rebuilt"],
                           if (k %in% REBUILD) "" else "   (not rebuilt: same quantity at both grains)"))
sub_("contrasts in SD of PSI-90: county, tract, and tract minus county")
show <- function(q, ms) for (k in ms) {
  v <- function(g, cs) OUT$est[OUT$grain == g & OUT$construction == cs & OUT$quantity == q & OUT$measure == k]
  cat(sprintf("  %-12s original: county %+.3f tract %+.3f diff %+.3f   rebuilt: county %+.3f tract %+.3f diff %+.3f\n", k,
              v("catch_county", "original"), v("catch_tract", "original"), v("tract minus county", "original"),
              v("catch_county", "rebuilt"), v("catch_tract", "rebuilt"), v("tract minus county", "rebuilt")))
}
show("joint", "all ten"); show("part", c("material", "composition", "apart")); show("measure", DIS)

# ==========================================================================
hdr("verify")
jd <- function(cs) OUT$est[OUT$grain == "tract minus county" & OUT$construction == cs & OUT$quantity == "joint"]
cat(sprintf("  1. original columns reproduced from the original inputs; specs 382 and 344 reproduced -- PASS\n"))
cat(sprintf("  2. outcome, sample (%d), terms, transformation rule and estimator identical across the\n", sum(KEEP)))
cat(sprintf("     four fits; only the Block B values differ -- PASS\n"))
cat(sprintf("  3. joint contrast, tract minus county: %+.3f with the original construction, %+.3f rebuilt\n",
            jd("original"), jd("rebuilt")))
hdr("done")
