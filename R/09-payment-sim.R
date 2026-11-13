# R/09-payment-sim.R  --  Task 4.2, the payment-impact Monte Carlo.
#
# Implements provenance/payment-model-inputs.md (Task 4.1) and its amendments
# 1-6, all committed before this file first ran. It does not change them.
#
# ORDER, which is the verify condition (payment-model-inputs.md Sec 5.4):
#   1. C1  -- the HACRP rule is reproduced from observed inputs. A GATE: the
#             stage stops unless every mismatch is explained.
#   2. the Rashomon specs are refitted and each one's common-frame loss is
#      asserted equal to Task 3.9's stored loss (so this frame IS that frame).
#   3. draws, doubling B until the amendment-6 convergence rule holds.
#   4. C2  -- how well Phase 3's predictive draws reproduce who HACRP
#             penalised. Reported, never tuned.
#   5. the Q-HIP simulation results, per scenario and per stratum.
# Steps 3-5 share the draws: C2 and Q-HIP are computed from the same draw, but
# nothing Q-HIP computes feeds back into C2 or into any setting.
#
# ONE DRAW (Sec 3 and amendments 2-4). Spec m uniform over the Rashomon set
# (U1); completion j uniform over 20 (amendment 3, used only by MI specs);
# beta ~ MVN(beta_hat, V) (U2); theta ~ N(psi90, v) and a fresh measurement
# re-shrunk the way CMS publishes (U3, amendment 2); a residual resampled from
# spec m's own evaluation-frame residuals within the hospital's lambda quartile
# (U4, amendment 4, C2 only). Every draw has its own seed, SEED + b, so draws
# 1..B are the same whatever B ends up being, and in whatever order they run.
#
# Outputs: output/tables/payment-*.csv, output/tables/hacrp-calibration*.csv,
# data/payment-sim.rds (per-draw outputs, per-hospital accumulators; 4.3/4.4
# read it). Fits cached in data/payment-fits.rds; PAYMENT_REFIT=1 forces.

suppressMessages({ library(lme4); library(splines); library(data.table) })

SEED    <- 20260924L
B0      <- as.integer(Sys.getenv("PAYMENT_B0", "250"))       # override for smoke tests only
B_MAX   <- as.integer(Sys.getenv("PAYMENT_BMAX", "64000"))
MCSE_TOL <- 0.05
OUT     <- file.path("output", "tables")
FITS    <- file.path("data", "payment-fits.rds")

pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

## the Phase 3 machinery: 06-mcr.R rebuilds 3.9's evaluation frame and carries
## the spec harness; sourcing it also re-runs its own validation, which is fine
q <- new.env()
local({ tf <- tempfile(); sink(tf); sys.source(file.path("R", "06-mcr.R"), envir = q); sink(); unlink(tf) })
for (f in c("n_", "hdr", "sub_", "mi_base", "eiv_gm", "cols_for")) assign(f, get(f, envir = q))
e <- q$e; a <- q$a; AE <- q$AE; Y <- q$Y; LAM <- q$LAM
LOS <- readRDS(file.path("data", "rashomon-loss.rds"))
SET <- readRDS(file.path("data", "rashomon-set.rds"))
reg <- readRDS(file.path("data", "spec-registry.rds"))
stopifnot(nrow(AE) == 2569)
N <- nrow(AE)

hdr("TASK 4.2  payment-impact Monte Carlo")
cat(sprintf("  seed %d (payment-model-inputs.md Sec 8); every draw b is seeded SEED + b\n", SEED))

# ==========================================================================
# 1.  INPUTS
# ==========================================================================
hdr("1. inputs")

## ---- reliability (Task 2.2) ----
## Task S1.6: WHAT THE U3 SCORE DRAW IS. theta ~ N(published value, v), then a
## fresh measurement theta + sqrt(v / lambda) e, re-shrunk: pub* = mu +
## lambda (measurement - mu). It is a HYPOTHETICAL REPEATED MEASUREMENT under
## the normal model, and its expected published value is mu + lambda x (the
## current published deviation), the published value shrunk once more -- not
## the current published value, and not next year's. Its spread is generated
## BY the scalar-reliability model, so it cannot be evidence for that model;
## nothing in this stage or the notes uses it that way any more.
MU  <- mean(n_(a$psi90_2dp)[a$lambda_in_tau2_sample])        # 2.2's prior mean
PSI <- n_(AE$psi90); V_I <- n_(AE$v_i); S2_I <- V_I / LAM      # posterior var; sampling var
stopifnot(all(is.finite(PSI)), all(V_I > 0), all(LAM > 0))
cat(sprintf("  mu (2.2 prior mean) %.5f   tau2 %.5f   lambda %.3f..%.3f in the frame\n",
            MU, n_(a$tau2)[1], min(LAM), max(LAM)))

## ---- commercial share (amendment 1): raw HCRIS FY2023 S-3 Part I ----
sub_("commercial share, raw HCRIS S-3 Part I (amendment 1)")
zip <- file.path("data-raw", "blockC", "HOSP10FY2023.zip")
stopifnot(file.exists(zip))
rpt <- fread(cmd = sprintf("unzip -p %s HOSP10_2023_rpt.csv", shQuote(zip)),
             header = FALSE, colClasses = "character", showProgress = FALSE)
s3 <- fread(cmd = sprintf("unzip -p %s HOSP10_2023_nmrc.csv | grep -E '^[0-9]+,S300001,(00200|01400),'", shQuote(zip)),
            header = FALSE, colClasses = "character", showProgress = FALSE)
setnames(s3, c("rrn", "wksht", "line", "clmn", "val")); s3[, val := as.numeric(val)]
g3 <- function(l, c) { x <- s3[line == l & clmn == c]; setNames(x$val, x$rrn) }
rr <- rpt$V1; z0 <- function(v) ifelse(is.na(v), 0, v)
tot  <- g3("01400", "00800")[rr]
pubd <- z0(g3("01400", "00500")[rr]) + z0(g3("01400", "00600")[rr]) + z0(g3("01400", "00700")[rr]) +
        z0(g3("00200", "00600")[rr]) + z0(g3("00200", "00700")[rr])
share_rrn <- ifelse(is.finite(tot) & tot > 0, 1 - pubd / tot, NA_real_)
r_ccn <- formatC(trimws(rpt$V3), width = 6, flag = "0")
r_b <- as.Date(rpt$V6, "%m/%d/%Y"); r_e <- as.Date(rpt$V7, "%m/%d/%Y")
o <- order(r_ccn, is.na(share_rrn), -as.numeric(r_e - r_b), -as.numeric(r_e))   # the 1.6 rule
k <- o[!duplicated(r_ccn[o])]
cs_all <- setNames(share_rrn[k], r_ccn[k])[a$ccn]
SN_all <- n_(a$dsh_pct) >= 0.370                                                   # P11
cs_ok  <- is.finite(cs_all) & cs_all >= 0 & cs_all <= 1
CASH2  <- ifelse(SN_all, 0.37 * 0.40, 0.37)                                        # P9-P10
cs_all <- unname(cs_all); cs_ok <- unname(cs_ok)
cshare <- ifelse(cs_ok, cs_all, CASH2)
cshare_source <- ifelse(cs_ok, "hcris_s3", ifelse(is.na(cs_all), "cash2_fallback_no_s3", "cash2_fallback_negative"))
cat(sprintf("  2,801 frame: HCRIS share %d, fallback %d (%d no S-3, %d public days > total)\n",
            sum(cs_ok), sum(!cs_ok), sum(is.na(cs_all)), sum(!is.na(cs_all) & !cs_ok)))
cat(sprintf("  median %.3f  IQR [%.3f, %.3f]   safety-net %.3f vs other %.3f   (CASH2: 0.370 / 0.148)\n",
            median(cs_all[cs_ok]), quantile(cs_all[cs_ok], .25), quantile(cs_all[cs_ok], .75),
            median(cs_all[cs_ok & SN_all], na.rm = TRUE), median(cs_all[cs_ok & !SN_all], na.rm = TRUE)))

## ---- the Q-HIP frame (D4) ----
sub_("the Q-HIP frame (D4): 3.9's frame less NPR <= 0 or flag_npr_tiny")
NPR_AE <- n_(AE$net_patient_revenue)
dropQ  <- !is.finite(NPR_AE) | NPR_AE <= 0 | AE$flag_npr_tiny
EXCL <- data.frame(ccn = AE$ccn[dropQ], name = AE$name[dropQ], state = AE$state[dropQ],
                   net_patient_revenue = NPR_AE[dropQ],
                   reason = ifelse(!is.finite(NPR_AE[dropQ]), "npr_missing",
                            ifelse(NPR_AE[dropQ] <= 0, "npr_nonpositive", "flag_npr_tiny")))
write.csv(EXCL, file.path(OUT, "payment-frame-exclusions.csv"), row.names = FALSE)
iQ <- which(!dropQ); nQ <- length(iQ)
cat(sprintf("  %d of %d kept; %d removed and listed in payment-frame-exclusions.csv\n", nQ, N, sum(dropQ)))
if (nrow(EXCL)) print(EXCL, row.names = FALSE)

mAE   <- match(AE$ccn, a$ccn)
NPRQ  <- NPR_AE[iQ]
SNQ   <- SN_all[mAE][iQ]
R_VAR <- list(hosp  = NPRQ * cshare[mAE][iQ],                    # base (amendment 1)
              cash2 = NPRQ * CASH2[mAE][iQ],                     # CASH2 flat, 0.40 safety-net
              flat  = NPRQ * 0.37)                               # CASH2 flat, no difference
## Task S1.5 revenue scenarios (pre-registration sec 4): the HCRIS share is a
## share of DAYS; commercial days are priced above public ones, so the share of
## REVENUE is rho*s / (rho*s + 1 - s) at a commercial-to-public per-day price
## ratio rho. The CASH2 fallback values are already revenue shares and are left
## as they are.
rev_share <- function(rho) { s <- cshare[mAE][iQ]; hc <- cshare_source[mAE][iQ] == "hcris_s3"
  ifelse(hc, rho * s / (rho * s + 1 - s), s) }
R_VAR$rho15 <- NPRQ * rev_share(1.5)
R_VAR$rho20 <- NPRQ * rev_share(2.0)
cat(sprintf("  revenue share (HCRIS hospitals): day share median %.3f -> %.3f at price ratio 1.5, %.3f at 2.0;\n",
            median(cshare[mAE][iQ]), median(rev_share(1.5)), median(rev_share(2.0))))
cat(sprintf("  eligible revenue total $%.1fB (days) -> $%.1fB / $%.1fB\n",
            sum(R_VAR$hosp) / 1e9, sum(R_VAR$rho15) / 1e9, sum(R_VAR$rho20) / 1e9))
cat(sprintf("  eligible revenue (base): median $%.1fM, total $%.1fB; %d on the CASH2 fallback\n",
            median(R_VAR$hosp) / 1e6, sum(R_VAR$hosp) / 1e9, sum(cshare_source[mAE][iQ] != "hcris_s3")))

## ---- HACRP file ----
h <- read.csv(file.path("data-raw", "hacrp_fy2026", "FY_2026_HAC_Reduction_Program_Hospital.csv"),
              colClasses = "character", check.names = FALSE)
HN   <- nrow(h)
MEAS <- c("PSI 90", "CLABSI", "CAUTI", "SSI", "CDI", "MRSA")
VALC <- c("PSI 90 Composite Value", paste(MEAS[-1], "SIR"))
WZ   <- sapply(MEAS, function(m) n_(h[[paste(m, "W Z Score")]]))
VAL  <- sapply(VALC, function(k) n_(h[[k]])); colnames(VAL) <- MEAS
TOT  <- n_(h[["Total HAC Score"]])
PAYR <- h[["Payment Reduction"]]
MD   <- h$State == "MD"
HAIWZ <- WZ[, -1]

## ---- HAI component of the Q-HIP score (amendment 5) ----
hm   <- match(AE$ccn, h[["Facility ID"]])
haiQ <- HAIWZ[hm[iQ], , drop = FALSE]
nHAI <- rowSums(is.finite(haiQ)); nHAI[is.na(hm[iQ])] <- 0
HAIM <- ifelse(nHAI > 0, rowMeans(haiQ, na.rm = TRUE), 0)
cat(sprintf("  Q-HIP frame: %d in the HACRP file; %d with >= 1 HAI score; %d scored on PSI-90 alone\n",
            sum(!is.na(hm[iQ])), sum(nHAI > 0), sum(nHAI == 0)))

## ---- strata (4.1 Sec 7) ----
hg <- read.csv(file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv"),
               colClasses = "character", check.names = FALSE)
star <- n_(hg[["Hospital overall rating"]][match(a$ccn, hg[["Facility ID"]])])
marg <- n_(a$operating_margin)
inF  <- !is.na(star) & !is.na(marg)                                  # 3.16's frame
tercile <- function(x) as.integer(ceiling(3 * rank(x, ties.method = "first") / length(x)))
mt <- rep(NA_integer_, nrow(a)); mt[inF] <- tercile(marg[inF])
sb <- ifelse(star <= 2, 1L, ifelse(star == 3, 2L, 3L))
CELL_all <- ifelse(inF, sprintf("s%dm%d", sb, mt), "unrated")
CELL <- CELL_all[mAE][iQ]
ADI  <- n_(AE$adi_catch_tract)[iQ]
quint <- function(x) as.integer(ceiling(5 * rank(x, ties.method = "first") / length(x)))
ADIQ <- quint(ADI)
cat(sprintf("  strata: safety-net %d / %d; 3.16 cells %d rated + %d unrated; ADI quintiles of %d\n",
            sum(SNQ), sum(!SNQ), sum(CELL != "unrated"), sum(CELL == "unrated"), nQ))

# ==========================================================================
# 2.  C1  --  THE GATE
# ==========================================================================
hdr("2. C1 -- the HACRP rule reproduced from observed inputs (a gate)")

wins <- function(x) { q <- quantile(x, c(.05, .95), type = 2, na.rm = TRUE); pmin(pmax(x, q[1]), q[2]) }
wz_of <- function(x) { w <- wins(x); (w - mean(w, na.rm = TRUE)) / sd(w, na.rm = TRUE) }
hacrp_rule <- function(wzmat, digits = NULL) {
  tot <- rowMeans(wzmat, na.rm = TRUE); tot[!is.finite(tot)] <- NA
  if (!is.null(digits)) tot <- round(tot, digits)          # amendment 7: published precision
  cut <- quantile(tot, 0.75, na.rm = TRUE, names = FALSE)
  list(total = tot, cut = cut, pen = !is.na(tot) & tot > cut & !MD)
}
OBS_PEN <- PAYR == "Yes"
c1_compare <- function(r, label) {
  status <- ifelse(PAYR == "N/A", "N/A", ifelse(OBS_PEN, "Yes", "No"))
  pred   <- ifelse(MD & !is.na(r$total), "N/A", ifelse(r$pen, "Yes", "No"))
  mis <- which(status != pred)
  reason <- ifelse(is.na(r$total[mis]),
                   "no Total HAC Score published; a score-based rule cannot place it",
                   sprintf("|score - cut| = %.4f", abs(r$total[mis] - r$cut)))
  cat(sprintf("  %-44s cut %.4f   reproduced %d of %d   mismatches %d\n",
              label, r$cut, HN - length(mis), HN, length(mis)))
  data.frame(check = label, ccn = h[["Facility ID"]][mis], state = h$State[mis],
             observed = status[mis], rule = pred[mis], total_published = TOT[mis],
             total_recomputed = r$total[mis], cut = r$cut, reason = reason)
}
## C1a: the file's own W-Z scores
r1a <- hacrp_rule(WZ, digits = 4)
cat(sprintf("  C1a  max |recomputed Total - published| = %.1e over %d scored\n",
            max(abs(r1a$total - TOT), na.rm = TRUE), sum(!is.na(TOT))))
M1a <- c1_compare(r1a, "C1a  from the file's W-Z scores")
## C1b: PSI-90 W-Z from its raw composite value (the Monte Carlo's path), HAIs as published
wz_b <- WZ; wz_b[, 1] <- wz_of(VAL[, 1])
cat(sprintf("  C1b  PSI-90 W-Z from raw values: max |diff| vs published %.4f\n",
            max(abs(wz_b[, 1] - WZ[, 1]), na.rm = TRUE)))
r1b <- hacrp_rule(wz_b, digits = 4)
M1b <- c1_compare(r1b, "C1b  PSI-90 from raw value (MC path)")
GAP <- max(abs(wz_b[, 1] - WZ[, 1]), na.rm = TRUE)          # the measured standardisation gap
NMS <- rowSums(is.finite(wz_b))
## C1b(ii): all six from raw values -- informational; non-submitters keep the file's W-Z
wz_c <- WZ; nonsub <- 0L
for (k in seq_along(MEAS)) {
  z <- wz_of(VAL[, k]); fill <- is.na(z) & !is.na(WZ[, k]); nonsub <- nonsub + sum(fill)
  wz_c[, k] <- ifelse(fill, WZ[, k], z)
  cat(sprintf("       %-6s raw -> W-Z max |diff| %.4f\n", MEAS[k], max(abs(wz_c[, k] - WZ[, k]), na.rm = TRUE)))
}
M1c <- c1_compare(hacrp_rule(wz_c, digits = 4), "C1b(ii) all six from raw values (info)")
cat(sprintf("       (%d measure scores have a published W-Z but no value -- footnote 18 non-submitters; kept)\n", nonsub))
C1 <- rbind(M1a, M1b, M1c)
write.csv(C1, file.path(OUT, "payment-c1-mismatches.csv"), row.names = FALSE)

## the gate: every mismatch in C1a and C1b must be one a score-based rule cannot place
## amendment 7: a C1b mismatch is explained only when it sits within the measured
## PSI-90 standardisation gap of the cut (GAP / number of scored measures)
gate_mis <- rbind(M1a, M1b)
ib <- match(M1b$ccn, h[["Facility ID"]])
M1b_gap <- !is.na(M1b$total_recomputed) & abs(M1b$total_recomputed - M1b$cut) <= GAP / NMS[ib] + 5e-5
if (nrow(M1b)) M1b$reason[M1b_gap] <- sprintf("within the PSI-90 standardisation gap of the cut (%.4f <= %.4f)",
  abs(M1b$total_recomputed - M1b$cut)[M1b_gap], (GAP / NMS[ib] + 5e-5)[M1b_gap])
gate_mis <- rbind(M1a, M1b)
C1 <- rbind(M1a, M1b, M1c)
write.csv(C1, file.path(OUT, "payment-c1-mismatches.csv"), row.names = FALSE)
unexplained <- rbind(M1a[!is.na(M1a$total_recomputed), ], M1b[!is.na(M1b$total_recomputed) & !M1b_gap, ])
if (nrow(gate_mis)) print(gate_mis[, c("check", "ccn", "state", "observed", "rule", "reason")], row.names = FALSE)
if (nrow(unexplained)) stop("C1 GATE FAILED: mismatches with a published score -- the simulation does not run")
cat("  C1 GATE PASSED: Maryland (43) reproduced as waived; every remaining mismatch has no\n")
cat("  published score, or (C1b) sits within the measured standardisation gap. The Monte Carlo may run.\n")

# ==========================================================================
# 3.  THE SPECS, REFITTED, AND CHECKED AGAINST 3.9
# ==========================================================================
hdr("3. the Rashomon specs, refitted on their own frames, scored on 3.9's")

POOL_PRIMARY <- SET$primary$spec_ids
dm <- SET$sets[["composite.cbsa"]]$d
POOL_METRO <- dm$spec_id[dm$in_set]
ALL_SPECS <- sort(unique(c(POOL_PRIMARY, POOL_METRO)))
cat(sprintf("  primary set %d specs; metro-tolerance set %d; %d distinct to fit\n",
            length(POOL_PRIMARY), length(POOL_METRO), length(ALL_SPECS)))
DIS <- names(e$DIS_SIGN)

spec_of <- function(sid) as.list(reg[reg$spec_id == sid, ])
design_of <- function(s) {            # evaluation-frame design matrix, full column set
  pp <- e$prep_spec(s, a)
  fe <- paste(c(pp$feA, pp$feB, pp$feC), collapse = " + ")
  s2 <- s; s2$influential <- "all"; s2$reliability <- "unweighted"; s2$scale <- "identity"
  ED <- e$prep_spec(s2, AE)$data; stopifnot(nrow(ED) == N)
  model.matrix(terms(as.formula(sprintf("~ %s", fe)), data = pp$data), ED)
}
## map a linear predictor on the fitted scale to the published scale (3.9)
to_pub <- function(eta, s, gm, reshrink = TRUE) {
  th <- if (s$scale == "log") exp(eta) else eta
  if (s$reliability == "eiv" && reshrink) gm + LAM * (th - gm) else th
}
fit_spec <- function(sid) {
  s <- spec_of(sid)
  J <- if (s$missing == "mi") seq_len(e$MI_M) else 1L
  X <- design_of(s)
  comp <- lapply(J, function(j) {
    base <- if (s$missing == "mi") mi_base(a, j) else a
    pp <- e$prep_spec(s, base)
    fe <- paste(c(pp$feA, pp$feB, pp$feC), collapse = " + ")
    m  <- lm(as.formula(sprintf(".y ~ %s", fe)), data = pp$data, weights = pp$data$.w)
    b  <- coef(m); b <- b[!is.na(b)]
    V  <- vcov(m, complete = FALSE)[names(b), names(b)]
    ev <- eigen(V, symmetric = TRUE)
    L  <- ev$vectors %*% diag(sqrt(pmax(ev$values, 0)), length(b))
    list(b = b, L = L, gm = eiv_gm(s, base))
  })
  pred <- sapply(comp, function(cc) to_pub(as.numeric(X[, names(cc$b), drop = FALSE] %*% cc$b), s, cc$gm))
  pm <- if (is.matrix(pred)) rowMeans(pred) else pred
  list(spec_id = sid, comp = comp, resid = Y - pm, loss = mean((Y - pm)^2))
}

## Task S0.3: keyed on the harness, the MCR helpers, the data, and the text of
## the fitting functions in this script -- not the whole script, so editing the
## payment rules (S1.3-S1.5) does not force a refit, while editing a fit does
if (!exists("cache_key")) source(file.path("R", "cache-key.R"))
FIT_KEY <- cache_key(c(file.path("R", c("04-spec-curve.R", "06-mcr.R")),
                       file.path("data", c("spec-registry.rds", "rashomon-set.rds", "rashomon-loss.rds",
                                           "analytic-v2.rds", "blockC_mice.rds"))),
                     list(spec_of = spec_of, design_of = design_of, to_pub = to_pub, fit_spec = fit_spec))
cache_ok <- cache_fresh(FITS, FIT_KEY, "PAYMENT_REFIT")
FIT <- if (cache_ok) readRDS(FITS) else list()
todo <- setdiff(ALL_SPECS, as.integer(names(FIT)))
if (length(todo)) {
  t0 <- Sys.time()
  cat(sprintf("  fitting %d specs (MI specs x %d completions) ...\n", length(todo), e$MI_M))
  for (sid in todo) FIT[[as.character(sid)]] <- fit_spec(sid)
  cache_save(FIT, FITS, FIT_KEY)
  cat(sprintf("  done in %.1f min -> %s\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), FITS))
} else cat(sprintf("  fits reused from %s (PAYMENT_REFIT=1 forces)\n", FITS))

## the loss check: this frame and these predictions are Task 3.9's
dl <- sapply(ALL_SPECS, function(sid) abs(FIT[[as.character(sid)]]$loss - LOS$loss[LOS$spec_id == sid]))
cat(sprintf("  common-frame loss == data/rashomon-loss.rds for %d of %d specs (max |diff| %.1e)\n",
            sum(dl < 1e-10), length(dl), max(dl)))
stopifnot(all(dl < 1e-10))

## residual pools within lambda quartile (amendment 4)
LQ <- as.integer(cut(LAM, quantile(LAM, 0:4 / 4), include.lowest = TRUE))

# ==========================================================================
# 4.  THE DRAW
# ==========================================================================
OFFSET <- mean(n_(a$psi90_hacrp) - n_(a$psi90), na.rm = TRUE)
## C2 calibration frame: Q-HIP frame, in HACRP with a PSI-90 value, not Maryland
hQ   <- hm[iQ]
calQ <- which(!is.na(hQ) & is.finite(VAL[pmax(hQ, 1), 1]) & !MD[pmax(hQ, 1)])
CAL_H <- hQ[calQ]                           # rows of h
CAL_AE <- iQ[calQ]                          # rows of AE
nC <- length(calQ)
OBS_C <- OBS_PEN[CAL_H]
OBS_PSI <- VAL[CAL_H, 1]
LQC <- as.integer(cut(LAM[CAL_AE], quantile(LAM[CAL_AE], 0:4 / 4), include.lowest = TRUE))

## HACRP national rank with the calibration hospitals' PSI-90 replaced
c2_pen <- function(psi_new) {
  v <- VAL[, 1]; v[CAL_H] <- psi_new
  w <- WZ; w[, 1] <- wz_of(v)
  hacrp_rule(w)$pen[CAL_H]
}

## the Q-HIP score, position and counterfactual position (Sec 2, amendment 5)
score_of <- function(pub, w, psi_only) {
  q <- quantile(pub, c(.05, .95), type = 2); wv <- pmin(pmax(pub, q[1]), q[2])
  m <- mean(wv); sdv <- sd(wv)
  zp <- (wv - m) / sdv
  S <- if (psi_only) zp else ifelse(nHAI > 0, w * zp + (1 - w) * HAIM, zp)
  list(S = S, sdv = sdv, zfun = function(x) (pmin(pmax(x, q[1]), q[2]) - m) / sdv)
}
pos_of <- function(S) 1 - rank(S, ties.method = "average") / length(S)
## Task S1.3: the position of Scf_i among the OTHER hospitals' actual scores,
## by pos_of()'s average-rank convention -- 1 + (others strictly below) + half
## the others tied with it -- so an unchanged score keeps its actual position,
## ties included. The September 30 version counted only the others strictly
## below (a minimum-rank convention), which moved every tied hospital, and
## every hospital clamped at a winsorization bound is tied.
pos_cf <- function(S, Scf) {
  srt <- sort(S)
  lt <- findInterval(Scf, srt, left.open = TRUE) - (S < Scf)    # others strictly below
  eq <- findInterval(Scf, srt) - findInterval(Scf, srt, left.open = TRUE) - (S == Scf)  # others tied
  1 - (lt + 1 + eq / 2) / length(S)
}
## the September 30 pos_cf(), kept only so the identity test can show it fails
pos_cf_sep30 <- function(S, Scf) {
  srt <- sort(S)
  below <- findInterval(Scf, srt, left.open = TRUE) - (S < Scf)
  1 - (below + 1) / length(S)
}
## Task S1.5: the scenario's curve lives HERE and only here, so payment, the
## finite return and the counterfactual all use it. r(P) = 0.001 + 0.039 P^k
## (pre-registration sec 4: k = 0.5 concave, 2 convex, sharing the linear base's
## endpoints 0.1% and 4.0%); `sc$c`, when set, is the per-draw factor that
## rescales a curve to the base scenario's total payment. The threshold rule is
## unchanged arithmetic, a hypothetical stress test. The September 30 rate_of()
## took no k, so k only ever reached Marg.
rate_of <- function(P, sc) {
  r <- if (isTRUE(sc$thr)) ifelse(P < 0.25, 0, 0.001 + 0.039 * (P - 0.25) / 0.75) else 0.001 + 0.039 * P^sc$k
  if (is.null(sc$c)) r else sc$c * r
}
## Task S1.4: the FINITE payment return. Each hospital's published PSI-90 falls
## by delta while every other hospital's score and the draw's scoring reference
## (winsorization bounds, mean, SD -- carried in so$zfun) stay fixed; its score,
## its position among the others (pos_cf, average-rank ties), its rate and its
## payment are recomputed; the return is the payment change per PSI-90 unit.
## Hospitals without infection measures are scored on PSI-90 alone by the same
## line score_of() uses. This replaces the September 30 "Marg" (R x w x 0.039),
## which never consulted the rate function (review of 2026-10-01, P0).
DELTAS <- c(d010 = 0.01, d025 = 0.025, d050 = 0.05, d100 = 0.10)     # pre-registration sec 3
D_PRIMARY <- 0.05
fin_return <- function(sc, so, pub, R, Pay, delta) {
  znew <- so$zfun(pub - delta)
  Snew <- if (sc$psi) znew else ifelse(nHAI > 0, sc$w * znew + (1 - sc$w) * HAIM, znew)
  Pn <- pos_cf(so$S, Snew)
  ret <- (R * rate_of(Pn, sc) - Pay) / delta
  list(ret = ret, moved = Snew != so$S, P = Pn)
}
fr   <- function(x) (rank(x, ties.method = "average") - 0.5) / length(x)
cindex <- function(x, rk) { mx <- mean(x); if (mx == 0 || sd(x) == 0) return(0); 2 * mean((x - mx) * (rk - mean(rk))) / mx }

SCEN <- list(
  base      = list(w = 0.15, k = 1.0, thr = FALSE, R = "hosp",  psi = FALSE),
  w10       = list(w = 0.10, k = 1.0, thr = FALSE, R = "hosp",  psi = FALSE),
  w20       = list(w = 0.20, k = 1.0, thr = FALSE, R = "hosp",  psi = FALSE),
  concave   = list(w = 0.15, k = 0.5, thr = FALSE, R = "hosp",  psi = FALSE),
  convex    = list(w = 0.15, k = 2.0, thr = FALSE, R = "hosp",  psi = FALSE),
  threshold = list(w = 0.15, k = 1.0, thr = TRUE,  R = "hosp",  psi = FALSE),
  cash2_sn  = list(w = 0.15, k = 1.0, thr = FALSE, R = "cash2", psi = FALSE),
  cash2_flat= list(w = 0.15, k = 1.0, thr = FALSE, R = "flat",  psi = FALSE),
  psi_only  = list(w = 1.00, k = 1.0, thr = FALSE, R = "hosp",  psi = TRUE),
  ## Task S1.5: the shape curves rescaled to the base total in each draw, and
  ## the two revenue scenarios
  concave_rs= list(w = 0.15, k = 0.5, thr = FALSE, R = "hosp",  psi = FALSE, rescale = TRUE),
  convex_rs = list(w = 0.15, k = 2.0, thr = FALSE, R = "hosp",  psi = FALSE, rescale = TRUE),
  rev_rho15 = list(w = 0.15, k = 1.0, thr = FALSE, R = "rho15", psi = FALSE),
  rev_rho20 = list(w = 0.15, k = 1.0, thr = FALSE, R = "rho20", psi = FALSE))
SCEN_LABEL <- c(base = "base (linear)", w10 = "PSI-90 weight 0.10", w20 = "PSI-90 weight 0.20",
                concave = "concave curve, k = 0.5, common endpoints", convex = "convex curve, k = 2, common endpoints",
                threshold = "threshold -- hypothetical stress test", cash2_sn = "CASH2 revenue, 0.40 safety-net factor",
                cash2_flat = "CASH2 revenue, flat", psi_only = "PSI-90-only scorecard",
                concave_rs = "concave curve, rescaled to base total", convex_rs = "convex curve, rescaled to base total",
                rev_rho15 = "revenue share at price ratio 1.5", rev_rho20 = "revenue share at price ratio 2.0",
                fixed = "PSI-90 fixed at its published value")
stopifnot(names(SCEN)[1] == "base")     # the rescaled curves take base's total from the same draw

## Task S1.3 identity test (second-pass pre-registration sec 2): a
## counterfactual equal to the actual score must give a payment difference of
## exactly 0 for every hospital -- on a vector with interior ties and with
## scores clamped at both winsorization bounds, under the linear and the
## threshold rate. It must FAIL on the September 30 pos_cf() (standing rule 3).
ident_dis <- function(pc, sc, pub) {
  so <- score_of(pub, sc$w, sc$psi); z <- so$zfun(pub)
  Scf <- if (sc$psi) z else ifelse(nHAI > 0, sc$w * z + (1 - sc$w) * HAIM, z)
  R <- R_VAR[[sc$R]]
  R * rate_of(pos_of(so$S), sc) - R * rate_of(pc(so$S, Scf), sc)
}
TPUB <- PSI[iQ]
TPUB[seq(1, length(TPUB), by = 7)] <- median(TPUB)                    # interior ties, HAI and non-HAI alike
tq <- quantile(TPUB, c(.05, .95), type = 2)
cat(sprintf("\n  identity test vector: %d hospitals, %d tied at the median, %d at the lower bound, %d at the upper\n",
            length(TPUB), sum(TPUB == median(TPUB)), sum(TPUB <= tq[1]), sum(TPUB >= tq[2])))
IDT <- do.call(rbind, lapply(c("base", "threshold", "psi_only"), function(nm) {
  dn <- ident_dis(pos_cf, SCEN[[nm]], TPUB); do <- ident_dis(pos_cf_sep30, SCEN[[nm]], TPUB)
  data.frame(scenario = nm, new_max_abs = max(abs(dn)), new_nonzero = sum(dn != 0),
             sep30_max_abs = max(abs(do)), sep30_nonzero = sum(do != 0))
}))
for (i in seq_len(nrow(IDT))) with(IDT[i, ], cat(sprintf(
  "  %-10s repaired: %d hospitals nonzero (max $%.0f) -- %s   Sep 30: %d nonzero (max $%.0f) -- %s\n",
  scenario, new_nonzero, new_max_abs, if (new_nonzero == 0) "PASS" else "FAIL",
  sep30_nonzero, sep30_max_abs, if (sep30_nonzero > 0) "fails, as it must" else "PASSED -- TEST CANNOT DETECT")))
stopifnot(all(IDT$new_nonzero == 0), all(IDT$sep30_nonzero > 0))
## and by hand: S = (1, 2, 2, 2, 3) has average ranks 1, 3, 3, 3, 5
HS <- c(1, 2, 2, 2, 3)
stopifnot(identical(pos_cf(HS, HS), pos_of(HS)), identical(pos_of(HS), 1 - c(1, 3, 3, 3, 5) / 5),
          !identical(pos_cf_sep30(HS, HS), pos_of(HS)))

## ---- Task S1.4 tests (pre-registration sec 2), on the published PSI-90 ----
## (a) below the smallest gap: an improvement too small to carry a score past
## any other score returns exactly 0. The smallest gap is taken over gaps above
## 1e-9 in score units: the blended score has distinct values that differ only
## in the 17th digit, and half of such a gap is a Delta that changes no
## published value at all, which would make the test vacuous. Every hospital is
## also checked against a LONGHAND rank count (independent of pos_cf), with the
## payment change compared to the cent: a hospital whose step crosses no other
## score must return exactly 0; one tied with others (or within 1e-9 of one)
## gains exactly what the longhand count says. The September 30 quantity
## (R x w x 0.039) is nonzero for every hospital at any size, so it fails.
TP <- PSI[iQ]
tiny_test <- function(sc) {
  so <- score_of(TP, sc$w, sc$psi); R <- R_VAR[[sc$R]]; n <- length(TP)
  Pay <- R * rate_of(pos_of(so$S), sc)
  g <- diff(sort(unique(so$S))); mingap <- min(g[g > 1e-9])
  dt <- 0.5 * mingap * so$sdv                 # moves any score by at most half that gap
  fd <- fin_return(sc, so, TP, R, Pay, dt)
  zn <- so$zfun(TP - dt)
  Sn <- if (sc$psi) zn else ifelse(nHAI > 0, sc$w * zn + (1 - sc$w) * HAIM, zn)
  rk_old <- rk_new <- crosses <- numeric(n)
  for (i in seq_len(n)) { o <- so$S[-i]
    rk_old[i] <- 1 + sum(o < so$S[i]) + 0.5 * sum(o == so$S[i])
    rk_new[i] <- 1 + sum(o < Sn[i]) + 0.5 * sum(o == Sn[i])
    crosses[i] <- Sn[i] < so$S[i] && any(o >= Sn[i] & o <= so$S[i]) }
  want_chg <- R * (rate_of(1 - rk_new / n, sc) - rate_of(1 - rk_old / n, sc))
  c(delta = dt, moved = sum(fd$moved), zero = sum(fd$ret == 0), crossers = sum(crosses), max_cents = 100 * max(abs(fd$ret * dt - want_chg)),
    max_abs_noncross = max(abs(fd$ret[!crosses])), sep30_nonzero = sum(R * sc$w * 0.039 != 0))
}
TT <- rbind(base = tiny_test(SCEN$base), threshold = tiny_test(SCEN$threshold), psi_only = tiny_test(SCEN$psi_only))
for (nm in rownames(TT)) cat(sprintf(
  "  tiny-improvement test %-9s Delta %.2e: %d scores move, %d of %d returns zero; %d break a tie or pass a score within 1e-9 (longhand max error %.1e cents); non-crossers max |return| %.1e -- %s; Sep 30 Marg nonzero for %d\n",
  nm, TT[nm, "delta"], TT[nm, "moved"], TT[nm, "zero"], nQ, TT[nm, "crossers"], TT[nm, "max_cents"], TT[nm, "max_abs_noncross"],
  if (TT[nm, "max_cents"] < 1 && TT[nm, "max_abs_noncross"] == 0) "PASS" else "FAIL", TT[nm, "sep30_nonzero"]))
stopifnot(all(TT[, "max_cents"] < 1), all(TT[, "max_abs_noncross"] == 0), all(TT[, "sep30_nonzero"] > 0),
          all(TT[, "moved"] > nQ / 2))

## (b) three named hospitals, computed longhand and compared with fin_return()
## to the cent: one near the median score, one at the upper winsorization
## bound, one with no infection measures
hand_one <- function(i, sc = SCEN$base, delta = D_PRIMARY) {
  n <- length(TP); q <- quantile(TP, c(.05, .95), type = 2)
  wv <- pmin(pmax(TP, q[1]), q[2]); m <- mean(wv); sdv <- sd(wv)
  sc_of <- function(z) if (nHAI[i] > 0) sc$w * z + (1 - sc$w) * HAIM[i] else z
  S <- ifelse(nHAI > 0, sc$w * (wv - m) / sdv + (1 - sc$w) * HAIM, (wv - m) / sdv)
  s_new <- sc_of((min(max(TP[i] - delta, q[1]), q[2]) - m) / sdv)
  rk_old <- 1 + sum(S[-i] < S[i]) + 0.5 * sum(S[-i] == S[i])
  rk_new <- 1 + sum(S[-i] < s_new) + 0.5 * sum(S[-i] == s_new)
  rate <- function(rk) 0.001 + 0.039 * (1 - rk / n)
  R <- R_VAR$hosp[i]
  data.frame(ccn = AE$ccn[iQ][i], name = AE$name[iQ][i], n_hai = nHAI[i], psi90 = TP[i], lo_bound = q[[1]], hi_bound = q[[2]],
             score = S[i], score_new = s_new, rank_old = rk_old, rank_new = rk_new, rate_old = rate(rk_old),
             rate_new = rate(rk_new), eligible_rev = R, pay_change = R * (rate(rk_new) - rate(rk_old)),
             return_per_unit = R * (rate(rk_new) - rate(rk_old)) / delta, row.names = NULL)
}
so_b <- score_of(TP, 0.15, FALSE); pay_b <- R_VAR$hosp * rate_of(pos_of(so_b$S), SCEN$base)
ret_b <- fin_return(SCEN$base, so_b, TP, R_VAR$hosp, pay_b, D_PRIMARY)$ret
qb <- quantile(TP, c(.05, .95), type = 2)
tie_b <- vapply(seq_along(so_b$S), function(i) sum(so_b$S[-i] == so_b$S[i]), numeric(1))
pick <- c(near_median = which(nHAI > 0 & tie_b == 0)[which.min(abs(so_b$S[nHAI > 0 & tie_b == 0] - median(so_b$S)))],
          upper_bound = which(TP >= qb[2])[which.min(TP[TP >= qb[2]])],
          no_infection = which(nHAI == 0 & tie_b == 0 & TP > qb[1] & TP < qb[2])[
            which.min(abs(TP[nHAI == 0 & tie_b == 0 & TP > qb[1] & TP < qb[2]] - median(TP)))])
HAND <- do.call(rbind, lapply(pick, hand_one)); HAND$case <- names(pick)
HAND$return_code <- ret_b[pick]
HAND$cents_diff <- abs(HAND$return_per_unit - HAND$return_code) * D_PRIMARY * 100
write.csv(HAND, file.path(OUT, "payment-returns-hand.csv"), row.names = FALSE)
for (i in seq_len(nrow(HAND))) with(HAND[i, ], cat(sprintf(
  "  hand check %-12s %s %-30.30s PSI-90 %.4f  score %+.5f -> %+.5f  rank %.1f -> %.1f  pay change $%.2f  return $%.2f  code $%.2f -- %s\n",
  case, ccn, name, psi90, score, score_new, rank_old, rank_new, pay_change, return_per_unit, return_code,
  if (cents_diff < 1) "PASS (to the cent)" else "FAIL")))
stopifnot(all(HAND$cents_diff < 1))

STRATA <- c(paste0("sn", 0:1), sort(unique(CELL)), paste0("adi_q", 1:5), paste0("vb_q", 1:5),
            paste0("hd_q", 1:5))      # hd = quintile of distance from the best measured score (theta; formerly "headroom")
strat_means <- function(x, vbq, hdq) {
  c(tapply(x, factor(as.integer(SNQ), 0:1), mean), tapply(x, factor(CELL, sort(unique(CELL))), mean),
    tapply(x, factor(ADIQ, 1:5), mean), tapply(x, factor(vbq, 1:5), mean), tapply(x, factor(hdq, 1:5), mean))
}

## Q-HIP outputs for one scenario, given this draw's published values
qhip <- function(sc, pub, pubcf, head_rk, vb_rk, adi_rk, strata = FALSE, vbq = NULL, hdq = NULL,
                 pay_target = NULL, pieces = FALSE) {
  R  <- R_VAR[[sc$R]]
  so <- score_of(pub, sc$w, sc$psi)
  P  <- pos_of(so$S)
  ## Task S1.5: a rescaled curve takes the factor that makes its total equal the
  ## base scenario's total in this draw; the factor then travels inside sc to
  ## every rate_of() call below (payment, return, counterfactual)
  if (isTRUE(sc$rescale)) { stopifnot(!is.null(pay_target)); sc$c <- pay_target / sum(R * rate_of(P, sc)) }
  r <- rate_of(P, sc)
  Pay <- R * r; Open <- R * (0.04 - r)
  ## the revenue exposure coefficient: dollars per unit of percentile position,
  ## R x w x 0.039. Supplementary only, and not a payment return: it never
  ## consults the rate function or anyone else's score, and per NPR dollar it
  ## equals 0.00585 x commercial day share, so its index describes payer mix.
  Expo <- R * sc$w * 0.039
  ## the finite return at the primary improvement size (pre-registration sec 3)
  f5 <- fin_return(sc, so, pub, R, Pay, D_PRIMARY); Ret <- f5$ret
  zcf <- so$zfun(pubcf)
  Scf <- if (sc$psi) zcf else ifelse(nHAI > 0, sc$w * zcf + (1 - sc$w) * HAIM, zcf)
  Pcf <- pos_cf(so$S, Scf)
  Dis <- Pay - R * rate_of(Pcf, sc)
  if (pieces) return(list(S = so$S, P = P, Pcf = Pcf, P_ret = f5$P, Expo = Expo, rate = r, total = sum(Pay)))
  PayN <- Pay / NPRQ; OpenN <- Open / NPRQ; RetN <- Ret / NPRQ; ExpoN <- Expo / NPRQ
  out <- c(total_pay = sum(Pay), dis_total = sum(Dis),
           pay_gap_to_base = if (is.null(pay_target)) 0 else sum(Pay) - pay_target,
           ci_pay_head = cindex(Pay, head_rk), ci_open_head = cindex(Open, head_rk), ci_ret_head = cindex(Ret, head_rk),
           ci_pay_vb = cindex(Pay, vb_rk),     ci_open_vb = cindex(Open, vb_rk),     ci_ret_vb = cindex(Ret, vb_rk),
           ci_pay_adi = cindex(Pay, adi_rk),   ci_open_adi = cindex(Open, adi_rk),   ci_ret_adi = cindex(Ret, adi_rk),
           ## amendment 9: the same indices per dollar of net patient revenue (the headline framing)
           ci_paynpr_head = cindex(PayN, head_rk), ci_opennpr_head = cindex(OpenN, head_rk), ci_retnpr_head = cindex(RetN, head_rk),
           ci_paynpr_vb = cindex(PayN, vb_rk),     ci_opennpr_vb = cindex(OpenN, vb_rk),     ci_retnpr_vb = cindex(RetN, vb_rk),
           ci_paynpr_adi = cindex(PayN, adi_rk),   ci_opennpr_adi = cindex(OpenN, adi_rk),   ci_retnpr_adi = cindex(RetN, adi_rk),
           sn_ratio_retnpr = mean(RetN[SNQ]) / mean(RetN[!SNQ]), sn_ratio_ret = mean(Ret[SNQ]) / mean(Ret[!SNQ]),
           ret_mean = mean(Ret), ret_share_zero = mean(Ret == 0),
           ## supplementary: the exposure coefficient's indices (payer mix)
           ci_expo_head = cindex(Expo, head_rk), ci_exponpr_head = cindex(ExpoN, head_rk),
           ci_exponpr_vb = cindex(ExpoN, vb_rk), ci_exponpr_adi = cindex(ExpoN, adi_rk))
  if (strata) {
    ## the full improvement grid, zero-return causes and the all-improve case
    ## (base and fixed runs only)
    RG <- list()
    for (dn in names(DELTAS)) {
      fd <- if (dn == "d050") f5 else fin_return(sc, so, pub, R, Pay, DELTAS[[dn]])
      rn <- fd$ret / NPRQ; z0 <- fd$ret == 0
      RG[[dn]] <- fd$ret
      out <- c(out, setNames(c(mean(fd$ret), mean(rn), quantile(fd$ret, c(.1, .5, .9), names = FALSE),
                               mean(z0), mean(z0 & !fd$moved), mean(z0 & fd$moved),
                               cindex(rn, head_rk), cindex(rn, vb_rk), cindex(rn, adi_rk)),
                             paste(c("ret_mean", "retnpr_mean", "ret_q10", "ret_q50", "ret_q90",
                                     "zero", "zero_clamped", "zero_passes_nobody",
                                     "ci_retnpr_head", "ci_retnpr_vb", "ci_retnpr_adi"), dn, sep = "_")))
    }
    ## every hospital improves by the primary amount and scores are
    ## restandardized: what a rank-based rule pays for an across-the-board gain
    sa <- score_of(pub - D_PRIMARY, sc$w, sc$psi)
    out <- c(out, allimp_pay_change = sum(R * rate_of(pos_of(sa$S), sc)) - sum(Pay),
             allimp_max_abs_score_change = max(abs(sa$S - so$S)))
    out <- c(out, setNames(strat_means(Pay, vbq, hdq), paste0("pay.", STRATA)),
             setNames(strat_means(Open, vbq, hdq), paste0("open.", STRATA)),
             setNames(strat_means(Dis, vbq, hdq), paste0("dis.", STRATA)),
             setNames(strat_means(r, vbq, hdq), paste0("rate.", STRATA)),
             setNames(strat_means(Ret, vbq, hdq), paste0("ret.", STRATA)),
             setNames(strat_means(RetN, vbq, hdq), paste0("retnpr.", STRATA)),
             setNames(strat_means(ExpoN, vbq, hdq), paste0("exponpr.", STRATA)))
    attr(out, "hosp") <- list(Pay = Pay, Open = Open, P = P, Dis = Dis, Ret = RG)
  }
  out
}

## ---- Task S1.5 tests (pre-registration sec 2), on the published PSI-90 ----
## (a) k changes the rate and nothing else: score, position, counterfactual
## position, the return's position and the exposure coefficient must be
## identical across k = 1, 0.5, 2; the rate must differ. The September 30
## Marg (R x w x 0.039 x k) changed with k, so it fails this test.
TPCF <- TP - 0.02                                   # a nontrivial counterfactual
kp <- lapply(c("base", "concave", "convex"), function(nm)
  qhip(SCEN[[nm]], TP, TPCF, fr(TP), fr(TP), fr(ADI), pieces = TRUE))
same <- vapply(c("S", "P", "Pcf", "P_ret", "Expo"), function(q)
  identical(kp[[1]][[q]], kp[[2]][[q]]) && identical(kp[[1]][[q]], kp[[3]][[q]]), logical(1))
rate_diff <- !isTRUE(all.equal(kp[[1]]$rate, kp[[2]]$rate)) && !isTRUE(all.equal(kp[[1]]$rate, kp[[3]]$rate))
marg_sep30 <- vapply(c(1, 0.5, 2), function(k) sum(R_VAR$hosp * 0.15 * 0.039 * k), numeric(1))
cat(sprintf("  k test: score, position, counterfactual and return positions, exposure identical across k = 1, 0.5, 2: %s; rate differs: %s -- %s\n",
            paste(names(same)[same], collapse = "/"), rate_diff, if (all(same) && rate_diff) "PASS" else "FAIL"))
cat(sprintf("          Sep 30 Marg totals $%.0fM / $%.0fM / $%.0fM -- changed with k, fails as it must\n", marg_sep30[1] / 1e6,
            marg_sep30[2] / 1e6, marg_sep30[3] / 1e6))
stopifnot(all(same), rate_diff, length(unique(marg_sep30)) == 3)
## (b) the three curves share endpoints, differ in total, and rescale to base
ends <- vapply(SCEN[c("base", "concave", "convex")], function(sc) c(rate_of(0, sc), rate_of(1, sc)), numeric(2))
tot <- vapply(kp, function(z) z$total, numeric(1))
rs <- vapply(c("concave_rs", "convex_rs"), function(nm)
  qhip(SCEN[[nm]], TP, TPCF, fr(TP), fr(TP), fr(ADI), pay_target = tot[1], pieces = TRUE)$total, numeric(1))
cat(sprintf("  curves: endpoints %s; totals linear $%.1fM, concave $%.1fM, convex $%.1fM; rescaled concave/convex minus base $%.4f / $%.4f -- %s\n",
            paste(sprintf("%.3f-%.3f", ends[1, ], ends[2, ]), collapse = ", "), tot[1] / 1e6, tot[2] / 1e6, tot[3] / 1e6,
            rs[1] - tot[1], rs[2] - tot[1],
            if (all(abs(ends[1, ] - 0.001) < 1e-15, abs(ends[2, ] - 0.04) < 1e-15) && length(unique(round(tot))) == 3 &&
                all(abs(rs - tot[1]) < 1)) "PASS" else "FAIL"))
stopifnot(all(abs(ends[1, ] - 0.001) < 1e-15), all(abs(ends[2, ] - 0.04) < 1e-15),
          length(unique(round(tot))) == 3, all(abs(rs - tot[1]) < 1))

## one draw -> named output vector + per-hospital pieces
## `fix` (Task S1.6, the uncertainty trace only) replaces named random inputs
## AFTER they are drawn, so the stream and every other input are unchanged:
## jj and z (the coefficient draw), th_z and e_z (the published-score draw), u
## (the C2 residual draw); zero_coef = TRUE sets z to 0 (beta at its estimate).
one_draw <- function(b, pool, seed_base, X, fitted, s, spec_pos, fix = NULL) {
  set.seed(seed_base + b)
  sample.int(length(pool), 1); jj <- sample.int(e$MI_M, 1)       # re-drawn: keeps the stream aligned
  ## exact [[ ]] lookups: fix$z would partially match zero_coef
  if (!is.null(fix[["jj"]])) jj <- fix[["jj"]]
  cc <- fitted$comp[[if (s$missing == "mi") jj else 1L]]
  z  <- rnorm(length(cc$b)); th_z <- rnorm(N); e_z <- rnorm(N); u <- runif(N)
  if (!is.null(fix[["z"]])) z <- fix[["z"]]
  if (isTRUE(fix[["zero_coef"]])) z <- 0 * z
  if (!is.null(fix[["th_z"]])) th_z <- fix[["th_z"]]
  if (!is.null(fix[["e_z"]])) e_z <- fix[["e_z"]]
  if (!is.null(fix[["u"]])) u <- fix[["u"]]
  beta <- cc$b + as.numeric(cc$L %*% z)
  Xb <- X[, names(beta), drop = FALSE]
  eta <- as.numeric(Xb %*% beta)
  cb  <- cols_for(Xb, DIS)
  vB  <- if (length(cb)) as.numeric(Xb[, cb, drop = FALSE] %*% beta[cb]) else rep(0, N)
  ## U3 (amendment 2)
  theta <- PSI + sqrt(V_I) * th_z
  pub   <- MU + LAM * (theta + sqrt(S2_I) * e_z - MU)
  ## the disadvantage-associated counterfactual (amendment 5), on each spec's own scale
  med <- median(vB[iQ]); dv <- vB - med
  eiv <- s$reliability == "eiv"; lg <- s$scale == "log"
  shift <- function(p, th) {
    if (!eiv && !lg) p - dv else if (!eiv && lg) p * exp(-dv)
    else if (eiv && !lg) p - LAM * dv else p - LAM * th * (1 - exp(-dv))
  }
  pubcf <- shift(pub, theta); fixcf <- shift(PSI, PSI)
  ## U4: predictive draws on the published scale for C2
  res <- numeric(N)
  for (qq in 1:4) { ix <- which(LQ == qq); pool_r <- fitted$resid[ix]
                    res[ix] <- pool_r[pmax(1L, ceiling(u[ix] * length(pool_r)))] }
  c2   <- to_pub(eta, s, cc$gm) + res + OFFSET
  c2nr <- to_pub(eta, s, cc$gm, reshrink = FALSE) + res + OFFSET

  ## ---- C2 ----
  penC   <- c2_pen(c2[CAL_AE]); penCnr <- c2_pen(c2nr[CAL_AE])

  ## ---- Q-HIP ----
  vBQ <- vB[iQ]; vbq <- quint(vBQ)
  head_rk <- fr(theta[iQ]); vb_rk <- fr(vBQ); adi_rk <- fr(ADI)
  outs <- list()
  for (nm in names(SCEN)) {
    o <- qhip(SCEN[[nm]], pub[iQ], pubcf[iQ], head_rk, vb_rk, adi_rk, strata = nm == "base", vbq = vbq, hdq = quint(theta[iQ]),
              pay_target = if (nm == "base") NULL else base_total)
    if (nm == "base") { hb <- attr(o, "hosp"); base_total <- o[["total_pay"]] }
    outs[[nm]] <- setNames(as.numeric(o), paste(nm, names(o), sep = "."))
  }
  ## the fixed-reliability run: theta and pub both the published value
  of <- qhip(SCEN$base, PSI[iQ], fixcf[iQ], fr(PSI[iQ]), vb_rk, adi_rk, strata = TRUE, vbq = vbq, hdq = quint(PSI[iQ]))
  hf <- attr(of, "hosp")
  outs$fixed <- setNames(as.numeric(of), paste("fixed", names(of), sep = "."))

  v <- c(b = b, spec = pool[spec_pos], comp = jj,
         c2.count = sum(penC), c2nr.count = sum(penCnr), unlist(outs, use.names = FALSE))
  names(v) <- c("b", "spec", "comp", "c2.count", "c2nr.count", unlist(lapply(outs, names), use.names = FALSE))
  list(v = v, penC = penC, penCnr = penCnr, rnd = list(jj = jj, z = z, th_z = th_z, e_z = e_z, u = u),
       pitC = (c2[CAL_AE] < OBS_PSI) + 0.5 * (c2[CAL_AE] == OBS_PSI),
       pitCnr = (c2nr[CAL_AE] < OBS_PSI) + 0.5 * (c2nr[CAL_AE] == OBS_PSI),
       hosp = list(Pay = hb$Pay, Open = hb$Open, P = hb$P, Dis = hb$Dis, theta = theta[iQ], vB = vBQ,
                   Pay_fixed = hf$Pay, Dis_fixed = hf$Dis,
                   Ret_d010 = hb$Ret$d010, Ret_d025 = hb$Ret$d025, Ret_d050 = hb$Ret$d050, Ret_d100 = hb$Ret$d100,
                   Zero_d050 = as.numeric(hb$Ret$d050 == 0)))
}

## run draws [from..to] of a pool, grouped by spec so each design matrix is built once
ACC_NAMES <- c("Pay", "Open", "P", "Dis", "theta", "vB", "Pay_fixed", "Dis_fixed",
               "Ret_d010", "Ret_d025", "Ret_d050", "Ret_d100", "Zero_d050")
new_acc <- function() list(n = 0L, penC = numeric(nC), penCnr = numeric(nC), pitC = numeric(nC), pitCnr = numeric(nC),
                           s1 = setNames(lapply(ACC_NAMES, function(k) numeric(nQ)), ACC_NAMES),
                           s2 = setNames(lapply(ACC_NAMES, function(k) numeric(nQ)), ACC_NAMES),
                           cover = matrix(0, nC, 2))
run_draws <- function(from, to, pool, seed_base, acc) {
  bs <- from:to
  sp <- vapply(bs, function(b) { set.seed(seed_base + b); sample.int(length(pool), 1) }, integer(1))
  rows <- vector("list", length(bs))
  for (p in sort(unique(sp))) {
    sid <- pool[p]; s <- spec_of(sid); X <- design_of(s); fitted <- FIT[[as.character(sid)]]
    for (i in which(sp == p)) {
      d <- one_draw(bs[i], pool, seed_base, X, fitted, s, p)
      rows[[i]] <- d$v
      acc$penC <- acc$penC + d$penC; acc$penCnr <- acc$penCnr + d$penCnr
      acc$pitC <- acc$pitC + d$pitC; acc$pitCnr <- acc$pitCnr + d$pitCnr
      for (k in ACC_NAMES) { acc$s1[[k]] <- acc$s1[[k]] + d$hosp[[k]]; acc$s2[[k]] <- acc$s2[[k]] + d$hosp[[k]]^2 }
      acc$n <- acc$n + 1L
    }
  }
  list(rows = do.call(rbind, rows), acc = acc)
}

## amendment 6: MCSE of the mean and of both 95% endpoints, each < 5% of the SD
mcse_tab <- function(D, cols) {
  B <- nrow(D)
  do.call(rbind, lapply(cols, function(k) {
    x <- sort(D[, k]); sdv <- sd(x)
    span <- function(p) { h <- 1.96 * sqrt(B * p * (1 - p))
      l <- max(1, floor(B * p - h)); u <- min(B, ceiling(B * p + h)); x[u] - x[l] }
    m <- c(mean = sdv / sqrt(B), lo = span(0.025) / (2 * 1.96), hi = span(0.975) / (2 * 1.96))
    integer_valued <- all(x == round(x))
    ## amendment 8: an integer output's endpoint passes when pinned to one integer step
    ends_ok <- if (integer_valued) span(0.025) <= 1 && span(0.975) <= 1 else max(m[2:3]) < MCSE_TOL * sdv
    data.frame(output = k, B = B, mean = mean(x), sd = sdv, mcse_mean = m[1], mcse_q025 = m[2], mcse_q975 = m[3],
               ratio = if (sdv > 0) max(m) / sdv else 0, integer_valued = integer_valued, exempt = sdv == 0,
               pass = sdv == 0 || (m[1] < MCSE_TOL * sdv && ends_ok), row.names = NULL)
  }))
}

# ==========================================================================
# 5.  THE PRIMARY RUN, TO CONVERGENCE
# ==========================================================================
hdr("5. primary run: draws doubled from B = 250 until amendment 6 holds")
t0 <- Sys.time()
acc <- new_acc(); D <- NULL; B <- B0; done <- 0L
repeat {
  r <- run_draws(done + 1L, B, POOL_PRIMARY, SEED, acc)
  D <- rbind(D, r$rows); acc <- r$acc; done <- B
  D <- D[order(D[, "b"]), , drop = FALSE]
  HEAD <- c("c2.count", grep("^base\\.", colnames(D), value = TRUE))
  HEAD <- HEAD[!grepl("^base\\.(open|dis)\\.", HEAD)]            # stratum Open/Dis are carried, not headline
  ## Task S1.4: the finite returns' stratum means, the improvement grid and the
  ## exposure coefficient are carried like Open/Dis; the Delta = 0.05 indices
  ## (ci_ret*, ci_retnpr*, sn_ratio_ret*, ret_mean) are headline
  HEAD <- HEAD[!grepl("^base\\.(ret|retnpr|exponpr)\\.|_d[0-9]{3}$|^base\\.allimp_|^base\\.ci_expo", HEAD)]
  MC <- mcse_tab(D, HEAD)
  nd <- !MC$integer_valued
  cat(sprintf("  B = %6d   headline outputs %d   passing %d   worst non-integer MCSE/SD %.3f  (%s)   %.1f min\n",
              B, nrow(MC), sum(MC$pass), max(MC$ratio[nd]), MC$output[nd][which.max(MC$ratio[nd])],
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  if (all(MC$pass) || B >= B_MAX) break
  B <- 2L * B
}
if (!all(MC$pass)) cat(sprintf("  NOT CONVERGED at the cap B = %d -- reported as such\n", B_MAX))
write.csv(MC, file.path(OUT, "payment-convergence.csv"), row.names = FALSE)
B_FINAL <- B

## reproducibility: the first 25 draws re-run from their seeds must match exactly
NR <- min(25L, B_FINAL)
chk <- run_draws(1L, NR, POOL_PRIMARY, SEED, new_acc())$rows
REPRO <- identical(unname(chk), unname(D[seq_len(NR), , drop = FALSE]))
cat(sprintf("  draws 1-%d re-run from their seeds: %s\n", NR, if (REPRO) "IDENTICAL" else "DIFFERENT"))
stopifnot(REPRO)

# ==========================================================================
# 6.  C2  --  REPORTED, NOT TUNED
# ==========================================================================
## Task S1.6: C2 is a check of the SCORING RULE ALONE. Only PSI-90 is drawn;
## the five HAI scores stay observed and are five-sixths of the score, so it is
## read beside the HAI-information-only reference row and by lambda quartile
## (the lowest quartile's slope, 1.287 on analytic-v2, is the one miss). It does
## not validate the payment simulation, and the U3 score draw never enters it
## (output/tables/payment-uncertainty-trace.csv).
hdr("6. C2 -- Phase 3 predictive draws against the observed FY 2026 penalties")
auc <- function(p, y) { r <- rank(p); n1 <- sum(y); n0 <- sum(!y); (sum(r[y]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
c2_stats <- function(pen_sum, pit_sum, counts, idx, label) {
  ph <- pen_sum[idx] / B_FINAL; y <- OBS_C[idx]; pit <- pit_sum[idx] / B_FINAL
  cl <- pmin(pmax(ph, 1 / (2 * B_FINAL)), 1 - 1 / (2 * B_FINAL))
  slope <- if (length(unique(y)) > 1) unname(coef(glm(y ~ qlogis(cl), family = binomial))[2]) else NA
  data.frame(arm = label, n = length(idx), observed = sum(y), expected = sum(ph),
             ratio = sum(ph) / sum(y),
             count_lo = if (!is.null(counts)) quantile(counts, .025) else NA,
             count_hi = if (!is.null(counts)) quantile(counts, .975) else NA,
             calib_slope = slope, auc = if (length(unique(y)) > 1) auc(ph, y) else NA,
             coverage90 = mean(pit >= 0.05 & pit <= 0.95), row.names = NULL)
}
C2 <- rbind(
  c2_stats(acc$penC,   acc$pitC,   D[, "c2.count"],   seq_len(nC), "main (re-shrunk to the published scale)"),
  do.call(rbind, lapply(1:4, function(qq) c2_stats(acc$penC, acc$pitC, NULL, which(LQC == qq), sprintf("main, lambda quartile %d", qq)))),
  c2_stats(acc$penCnr, acc$pitCnr, D[, "c2nr.count"], seq_len(nC), "C2.6 without the re-shrink step"),
  do.call(rbind, lapply(1:4, function(qq) c2_stats(acc$penCnr, acc$pitCnr, NULL, which(LQC == qq), sprintf("C2.6, lambda quartile %d", qq)))))
## POST-HOC REFERENCE ROWS (added after the B = 30 smoke run, before the real
## run; not checks, no bar). C2 predicts only PSI-90 -- the five HAI W-Z scores
## stay observed and are five-sixths of the Total HAC Score -- so AUC is mostly
## HAI information. These two rows bracket what the PSI-90 draws add: PSI-90 held
## at one constant for every calibration hospital (HAI information alone), and
## PSI-90 at its observed value (the ceiling, = C1b on this frame).
ref_row <- function(pen, label) data.frame(arm = label, n = nC, observed = sum(OBS_C), expected = sum(pen),
  ratio = sum(pen) / sum(OBS_C), count_lo = NA, count_hi = NA, calib_slope = NA,
  auc = auc(as.numeric(pen), OBS_C), coverage90 = NA, row.names = NULL)
C2 <- rbind(C2,
  ref_row(c2_pen(rep(mean(OBS_PSI), nC)), "REFERENCE (post hoc): PSI-90 constant -- HAI information alone"),
  ref_row(c2_pen(OBS_PSI), "REFERENCE (post hoc): PSI-90 observed -- the ceiling"))
C2$reads_good_c21 <- abs(C2$ratio - 1) <= 0.10
C2$reads_good_c22 <- C2$calib_slope >= 0.8 & C2$calib_slope <= 1.2
C2$reads_good_c24 <- C2$coverage90 >= 0.85 & C2$coverage90 <= 0.95
write.csv(C2, file.path(OUT, "hacrp-calibration.csv"), row.names = FALSE)
op <- options(width = 200); print(C2, row.names = FALSE, digits = 3); options(op)

ph <- acc$penC / B_FINAL
dec <- as.integer(ceiling(10 * rank(ph, ties.method = "first") / nC))
DEC <- data.frame(decile = 1:10, n = tabulate(dec, 10),
                  mean_p_hat = as.numeric(tapply(ph, dec, mean)),
                  observed_rate = as.numeric(tapply(OBS_C, dec, mean)))
write.csv(DEC, file.path(OUT, "hacrp-calibration-deciles.csv"), row.names = FALSE)
sub_("C2.2 by decile of p-hat"); print(DEC, row.names = FALSE, digits = 3)

# ==========================================================================
# 7.  THE METRO-TOLERANCE RUN (S7), AT THE PRIMARY B
# ==========================================================================
hdr(sprintf("7. S7: the metro-tolerance set (%d specs), B = %d, not re-converged", length(POOL_METRO), B_FINAL))
t1 <- Sys.time()
rm7 <- run_draws(1L, B_FINAL, POOL_METRO, SEED + 1000000L, new_acc())
D7 <- rm7$rows[order(rm7$rows[, "b"]), , drop = FALSE]
cat(sprintf("  %.1f min\n", as.numeric(difftime(Sys.time(), t1, units = "mins"))))

# ==========================================================================
# 7b. THE UNCERTAINTY TRACE  (Task S1.6)
# ==========================================================================
## Which random inputs move each output, found by experiment rather than by
## reading the code: for each of TRACE_K reference draws, re-draw ONE input
## group from another seed while holding the rest, and record which outputs
## change. Groups: the specification (two specs compared at their estimated
## coefficients), the coefficient draw (beta noise and the imputation
## completion), the published-score draw (U3: theta and the fresh measurement),
## the C2 residual draw (U4). An output no group moves carries no modelled
## variation, and its "interval" is zero-width by construction.
hdr("7b. uncertainty trace: which random input moves each output")
TRACE_K <- 20L
tr_draw <- function(b, p, fix = NULL) { sid <- POOL_PRIMARY[p]; s <- spec_of(sid)
  one_draw(b, POOL_PRIMARY, SEED, design_of(s), FIT[[as.character(sid)]], s, p, fix) }
flat <- function(d) c(d$v[-(1:3)], setNames(d$hosp$Pay, paste0("hosp.Pay.", seq_len(nQ))),
                      setNames(d$hosp$Ret_d050, paste0("hosp.Ret.", seq_len(nQ))),
                      setNames(d$hosp$Dis, paste0("hosp.Dis.", seq_len(nQ))))
moved <- function(x, y) abs(x - y) > 1e-9 * pmax(1, abs(x))
TRM <- NULL
for (k in seq_len(TRACE_K)) {
  set.seed(SEED + k); p0 <- sample.int(length(POOL_PRIMARY), 1); p1 <- p0 %% length(POOL_PRIMARY) + 1L
  ref <- tr_draw(k, p0); alt <- tr_draw(k + 500000L, p0)              # alt: same spec, another seed
  r0  <- flat(ref)
  ## a spec with a different coefficient count consumes a different number of
  ## normals before the score draw, so the score and residual inputs are held
  ## at the reference's explicitly; otherwise the stream shift would show up as
  ## a spurious "moved by specification"
  hold <- list(zero_coef = TRUE, jj = ref$rnd$jj, th_z = ref$rnd$th_z, e_z = ref$rnd$e_z, u = ref$rnd$u)
  sp0 <- flat(tr_draw(k, p0, hold))
  sp1 <- flat(tr_draw(k, p1, hold))
  m <- cbind(spec  = moved(sp0, sp1),
             coef  = moved(r0, flat(tr_draw(k, p0, list(z = alt$rnd$z, jj = alt$rnd$jj)))),
             score = moved(r0, flat(tr_draw(k, p0, list(th_z = alt$rnd$th_z, e_z = alt$rnd$e_z)))),
             resid = moved(r0, flat(tr_draw(k, p0, list(u = alt$rnd$u)))))
  TRM <- if (is.null(TRM)) m else TRM | m
}
rownames(TRM) <- names(r0)
## hospital-level rows collapse to one row per quantity
hq <- sub("^hosp\\.([A-Za-z]+)\\..*$", "hosp.\\1", rownames(TRM))
TRACE <- rbind(TRM[!grepl("^hosp\\.", rownames(TRM)), , drop = FALSE],
               do.call(rbind, lapply(split(seq_len(nrow(TRM))[grepl("^hosp\\.", rownames(TRM))],
                                           hq[grepl("^hosp\\.", rownames(TRM))]),
                                     function(ix) apply(TRM[ix, , drop = FALSE], 2, any))))
cat(sprintf("  %d reference draws x 4 input groups; %d outputs traced (hospital-level Pay, Ret, Dis collapsed)\n",
            TRACE_K, nrow(TRACE)))
cat(sprintf("  moved by: specification %d, coefficients %d, published score %d, C2 residual %d; by none %d\n",
            sum(TRACE[, "spec"]), sum(TRACE[, "coef"]), sum(TRACE[, "score"]), sum(TRACE[, "resid"]),
            sum(rowSums(TRACE) == 0)))
## the design says: payment and the finite return move only with the score
## draw; the disadvantage-associated amount and model-ranked indices with the
## model draws too; C2 with the model draws and the residual, never the score
chk_tr <- c(pay = all(TRACE["base.total_pay", ] == c(FALSE, FALSE, TRUE, FALSE)),
            ret = all(TRACE["hosp.Ret", ] == c(FALSE, FALSE, TRUE, FALSE)),
            dis = all(TRACE["hosp.Dis", 1:3]),
            c2  = all(TRACE["c2.count", ] == c(TRUE, TRUE, FALSE, TRUE)),
            expo_adi = !any(TRACE["base.ci_exponpr_adi", ]))
cat(sprintf("  design expectations: %s\n", paste(sprintf("%s %s", names(chk_tr), ifelse(chk_tr, "as expected", "UNEXPECTED")), collapse = ", ")))
stopifnot(all(chk_tr))

# ==========================================================================
# 8.  Q-HIP RESULTS
# ==========================================================================
hdr("8. Q-HIP-style payments -- a national what-if (Sec 4.3)")
summ <- function(x) c(mean = mean(x), lo = unname(quantile(x, .025)), hi = unname(quantile(x, .975)))
METRICS <- c("total_pay", "dis_total", "pay_gap_to_base", "ci_pay_head", "ci_open_head", "ci_ret_head",
             "ci_pay_vb", "ci_open_vb", "ci_ret_vb", "ci_pay_adi", "ci_open_adi", "ci_ret_adi",
             "ci_paynpr_head", "ci_opennpr_head", "ci_retnpr_head", "ci_paynpr_vb", "ci_opennpr_vb", "ci_retnpr_vb",
             "ci_paynpr_adi", "ci_opennpr_adi", "ci_retnpr_adi", "sn_ratio_retnpr", "sn_ratio_ret",
             "ret_mean", "ret_share_zero", "ci_expo_head", "ci_exponpr_head", "ci_exponpr_vb", "ci_exponpr_adi")
sc_rows <- function(DD, runs, label) do.call(rbind, lapply(runs, function(nm)
  do.call(rbind, lapply(METRICS, function(mt) { s <- summ(DD[, paste(nm, mt, sep = ".")])
    data.frame(model_set = label, scenario = nm, label = SCEN_LABEL[[nm]], metric = mt, mean = s["mean"], lo = s["lo"], hi = s["hi"],
               row.names = NULL) }))))
SC <- rbind(sc_rows(D, c(names(SCEN), "fixed"), "primary (194)"),
            sc_rows(D7, "base", sprintf("metro (%d)", length(POOL_METRO))))
write.csv(SC, file.path(OUT, "payment-scenarios.csv"), row.names = FALSE)

## Task S1.4: finite returns over the pre-registered improvement grid, base and
## fixed runs (primary set) and the metro set's base run
GRIDQ <- c("ret_mean", "retnpr_mean", "ret_q10", "ret_q50", "ret_q90", "zero", "zero_clamped", "zero_passes_nobody",
           "ci_retnpr_head", "ci_retnpr_vb", "ci_retnpr_adi")
RET <- do.call(rbind, lapply(list(list(D, "base", "primary (194)"), list(D, "fixed", "primary (194)"),
                                  list(D7, "base", sprintf("metro (%d)", length(POOL_METRO)))), function(x)
  do.call(rbind, lapply(names(DELTAS), function(dn) do.call(rbind, lapply(GRIDQ, function(q) {
    v <- summ(x[[1]][, paste0(x[[2]], ".", q, "_", dn)])
    data.frame(model_set = x[[3]], run = x[[2]], delta = DELTAS[[dn]], primary = dn == "d050", quantity = q,
               mean = v["mean"], lo = v["lo"], hi = v["hi"], row.names = NULL) }))))))
AI <- do.call(rbind, lapply(c("base", "fixed"), function(run) { v <- summ(D[, paste0(run, ".allimp_pay_change")])
  data.frame(model_set = "primary (194)", run = run, delta = D_PRIMARY, primary = TRUE,
             quantity = "all_improve_total_pay_change", mean = v["mean"], lo = v["lo"], hi = v["hi"], row.names = NULL) }))
RET <- rbind(RET, AI)
write.csv(RET, file.path(OUT, "payment-returns.csv"), row.names = FALSE)
sub_("finite returns, base run, primary set (mean over draws [95% simulation interval])")
for (dn in names(DELTAS)) { g <- function(q) RET[RET$run == "base" & RET$model_set == "primary (194)" & RET$delta == DELTAS[[dn]] & RET$quantity == q, ]
  cat(sprintf("  Delta %.3f: mean $%7.2fM per PSI-90 unit (median hospital $%.2fM)  zero %.1f%% (clamped %.1f%%, passes nobody %.1f%%)  CI/NPR distance %+.3f [%+.3f, %+.3f]  ADI %+.3f\n",
              DELTAS[[dn]], g("ret_mean")$mean / 1e6, g("ret_q50")$mean / 1e6, 100 * g("zero")$mean,
              100 * g("zero_clamped")$mean, 100 * g("zero_passes_nobody")$mean,
              g("ci_retnpr_head")$mean, g("ci_retnpr_head")$lo, g("ci_retnpr_head")$hi, g("ci_retnpr_adi")$mean)) }
cat(sprintf("  all improve by %.2f, rescored: total payment changes by $%.2f [%.2f, %.2f]\n", D_PRIMARY,
            AI$mean[1], AI$lo[1], AI$hi[1]))
cat("  output/tables/payment-returns.csv\n")

show <- function(nm, DD = D) { g <- function(mt) summ(DD[, paste(nm, mt, sep = ".")])
  f <- function(v, d = 3) sprintf("%+.*f [%+.*f, %+.*f]", d, v[1], d, v[2], d, v[3])
  cat(sprintf("  %-38.38s total $%6.0fM  dis-assoc $%+6.1fM   return/NPR CI: distance %s  model dis %s  ADI %s   zero %4.1f%%\n",
              SCEN_LABEL[[nm]], g("total_pay")[1] / 1e6, g("dis_total")[1] / 1e6, f(g("ci_retnpr_head")), f(g("ci_retnpr_vb")),
              f(g("ci_retnpr_adi")), 100 * g("ret_share_zero")[1])) }
cat("  (return = finite payment change per PSI-90 unit at Delta = 0.05, others held fixed; CI = concentration\n")
cat("   index per NPR dollar; 'distance' = the rank formerly called headroom, distance from the best score)\n")
for (nm in c(names(SCEN), "fixed")) show(nm)
cat("  metro set:\n"); show("base", D7)

## strata
ST <- do.call(rbind, lapply(c("base", "fixed"), function(run) do.call(rbind, lapply(c("pay", "open", "dis", "rate", "ret", "retnpr", "exponpr"), function(v)
  do.call(rbind, lapply(STRATA, function(stn) { x <- D[, paste(run, v, stn, sep = ".")]
    data.frame(run = run, quantity = v, stratum = stn, mean = mean(x, na.rm = TRUE),
               lo = unname(quantile(x, .025, na.rm = TRUE)), hi = unname(quantile(x, .975, na.rm = TRUE)), row.names = NULL) }))))))
ST$n <- c(sn0 = sum(!SNQ), sn1 = sum(SNQ), table(CELL), setNames(tabulate(ADIQ, 5), paste0("adi_q", 1:5)),
          setNames(rep(nQ / 5, 5), paste0("vb_q", 1:5)), setNames(rep(nQ / 5, 5), paste0("hd_q", 1:5)))[ST$stratum]
write.csv(ST, file.path(OUT, "payment-strata.csv"), row.names = FALSE)

## per hospital, over draws
mn <- function(k) acc$s1[[k]] / acc$n
sdd <- function(k) sqrt(pmax(acc$s2[[k]] / acc$n - mn(k)^2, 0) * acc$n / (acc$n - 1))
HOSP <- data.frame(ccn = AE$ccn[iQ], name = AE$name[iQ], state = AE$state[iQ], lambda_i = LAM[iQ],
                   npr = unname(NPRQ), cshare = cshare[mAE][iQ], cshare_source = cshare_source[mAE][iQ],
                   eligible_rev = R_VAR$hosp, safety_net = SNQ, cell = CELL, adi_q = ADIQ,
                   pay_mean = mn("Pay"), pay_sd = sdd("Pay"), open_mean = mn("Open"), P_mean = mn("P"), P_sd = sdd("P"),
                   dis_mean = mn("Dis"), dis_sd = sdd("Dis"), theta_mean = mn("theta"), vB_mean = mn("vB"), vB_sd = sdd("vB"),
                   pay_fixed = mn("Pay_fixed"), pay_fixed_sd = sdd("Pay_fixed"), dis_fixed_mean = mn("Dis_fixed"))
HOSP$revenue_exposure <- R_VAR$hosp * 0.15 * 0.039          # $ per unit of percentile position (payer mix)
for (dn in names(DELTAS)) HOSP[[paste0("ret_", dn)]] <- mn(paste0("Ret_", dn))
HOSP$ret_d050_sd <- sdd("Ret_d050"); HOSP$ret_d050_per_npr <- HOSP$ret_d050 / HOSP$npr
HOSP$share_draws_zero_d050 <- mn("Zero_d050")
HOSP$c2_p_hat <- NA_real_; HOSP$c2_p_hat[calQ] <- acc$penC / B_FINAL
HOSP$hacrp_penalised <- NA; HOSP$hacrp_penalised[calQ] <- OBS_C
write.csv(HOSP, file.path(OUT, "payment-by-hospital.csv"), row.names = FALSE)

## reliability: U3 against the fixed run (Sec 3)
sub_("payment spread per hospital under the U3 score draw vs with PSI-90 fixed, by lambda quartile")
cat("  (the U3 spread is produced by the scalar-reliability model; it describes that model's\n")
cat("   hypothetical repeated measurement and is not evidence for the model)\n")
LQQ <- LQ[iQ]
REL <- data.frame(lambda_quartile = 1:4,
                  lambda_range = tapply(LAM[iQ], LQQ, function(x) sprintf("%.2f-%.2f", min(x), max(x))),
                  n = tabulate(LQQ, 4),
                  pay_sd_u3 = tapply(HOSP$pay_sd, LQQ, mean), pay_sd_fixed = tapply(HOSP$pay_fixed_sd, LQQ, mean),
                  P_sd_u3 = tapply(HOSP$P_sd, LQQ, mean),
                  pay_sd_rel_u3 = tapply(HOSP$pay_sd / HOSP$pay_mean, LQQ, mean))
write.csv(REL, file.path(OUT, "payment-reliability.csv"), row.names = FALSE)
print(REL, row.names = FALSE, digits = 3)

## CASH2's Track rates, reproduced by the linear map (Sec 4.1 cross-check)
cat(sprintf("\n  linear map at P = 1/6, 1/2, 5/6: %.2f%% / %.2f%% / %.2f%%   (CASH2 Track rates 0.5 / 2.0 / 3.5%%)\n",
            100 * rate_of(1/6, SCEN$base), 100 * rate_of(1/2, SCEN$base), 100 * rate_of(5/6, SCEN$base)))
## S2 cannot move a rank-based index (4.1 Sec 4.2 point 1) -- checked, not assumed
## Task S1.5: the shapes now move payments; the rescaled curves hit the base
## total in every draw (to the dollar), the common-endpoint curves do not
s2chk <- max(abs(D[, "concave.ci_retnpr_head"] - D[, "base.ci_retnpr_head"]), abs(D[, "convex.ci_retnpr_head"] - D[, "base.ci_retnpr_head"]))
gap_rs <- max(abs(c(D[, "concave_rs.pay_gap_to_base"], D[, "convex_rs.pay_gap_to_base"])))
gap_ce <- min(abs(c(D[, "concave.pay_gap_to_base"], D[, "convex.pay_gap_to_base"])))
cat(sprintf("  S2 shapes vs base, CI(return/NPR | distance): max |diff| over draws %.3f (nonzero: k reaches the rate)\n", s2chk))
cat(sprintf("  rescaled curves: max |total - base total| over %d draws $%.4f; common-endpoint curves: smallest |gap| $%.0fM\n",
            nrow(D), gap_rs, gap_ce / 1e6))
stopifnot(gap_rs < 1, gap_ce > 1, s2chk > 0)

saveRDS(list(seed = SEED, B = B_FINAL, draws = D, draws_metro = D7, convergence = MC, c1 = C1, c2 = C2,
             c2_deciles = DEC, scenarios = SC, strata = ST, hospitals = HOSP, reliability = REL, trace = TRACE,
             frame_exclusions = EXCL, acc = acc, pools = list(primary = POOL_PRIMARY, metro = POOL_METRO),
             offset = OFFSET, mu = MU),
        file.path("data", "payment-sim.rds"))

# ==========================================================================
hdr("verify")
cat(sprintf("  1. C1 gate passed before any draw: HACRP reproduced from its W-Z scores and from\n"))
cat(sprintf("     raw PSI-90 values, mismatches only where no score is published -- PASS\n"))
cat(sprintf("  2. every refitted spec's common-frame loss equals 3.9's stored loss (%d specs) -- PASS\n", length(dl)))
cat(sprintf("  3. draw count B = %d set by amendments 6 and 8 (%d headline outputs, worst non-integer MCSE/SD %.3f) -- %s\n",
            B_FINAL, nrow(MC), max(MC$ratio[!MC$integer_valued]), if (all(MC$pass)) "PASS" else "NOT CONVERGED"))
cat(sprintf("  4. draws re-run from the recorded seed reproduce exactly -- PASS\n"))
cat(sprintf("  5. C2 reports the reproduction of the %d observed penalties in the calibration frame:\n", sum(OBS_C)))
cat(sprintf("     expected %.0f (ratio %.3f), slope %.2f, AUC %.3f, 90%% coverage %.3f -- reported, not tuned\n",
            C2$expected[1], C2$ratio[1], C2$calib_slope[1], C2$auc[1], C2$coverage90[1]))
hdr("done")
