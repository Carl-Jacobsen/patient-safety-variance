# R/04-spec-curve.R  --  Task 3.6, the fitting harness for the specification
# curve, and (Task 3.7, when SPEC_CURVE_FULL=1) the full run.
#
# Reads data/spec-registry.rds (the frozen 3,496-row grid, Task 3.5),
# data/analytic-v2.rds (the frozen file), and data/blockC_mice.rds (the m=20
# PMM object, for the missing = "mi" arm -- same second read as Task 3.2).
#
# WHAT IT DOES: fits every registered specification, extracts a UNIFORM result
# row, and stores coefficients / loss / diagnostics / the focal estimate in
# one data.frame. A fit that errors becomes a row with status = "failed" and a
# reason -- it is never skipped. A fit that converges with a warning or a
# singular fit becomes a row with status = "ok" and the flag set -- recorded,
# not dropped (task sheet: "Handle failures by recording them, not by skipping
# them"; "Influential points are reported, not removed").
#
# THE FOCAL ESTIMATE (`dis_effect`): the model-predicted change in the outcome
# when a hospital's community-disadvantage profile moves from the 10th to the
# 90th frame percentile on every disadvantage measure at once, each oriented so
# the "more deprived" end is the high end (ICE-150 and PCP density inverted).
# It is a JOINT contrast, not a single coefficient, because Task 3.1 established
# that Block B is too collinear for any one marginal coefficient to be stable
# (adi~ice150 r = -0.83) -- and Plan Sec 6: "the defensible claim is that no
# near-optimal model can ignore community disadvantage, not SVI theme 2
# specifically." Positive = more deprived communities have worse (higher) PSI.
# Per-measure single contrasts (b_adi, b_ice150, ...) are stored alongside for
# Task 3.8 / the TIS decomposition, on the same p10->p90 oriented scale.
#
# LEVEL OF ANALYSIS: one row per hospital in every arm. The composite is lm()
# only -- no random intercept at any level (standing rule 6: the published
# PSI-90 is already reliability-shrunk and nothing re-shrinks it; Task 3.2
# Sec 7). The component and aggregate outcomes are un-smoothed, so they carry a
# geography random intercept (1 | nest) -- the Task 3.2 approach, hospitals
# partially pooled within HSA or hospital-county per the grain axis. `grain`
# still varies the composite, through which Block B columns it reads.
#
# Blocks = A specs carry no Block B, so `dis_effect` is NA for them; they still
# record loss and convergence (they are the "community disadvantage omitted"
# comparison and a loss reference for the Rashomon step).
#
# RUNTIME: the composite / aggregate arms are lm()/lmer() (ms to ~0.1 s); the
# component arms are lmer() on a ~2,700-row hospital frame (~0.06 s); the
# missing = "mi" arms fit m = 20 times and pool by Rubin's rules (~2.4 s). With
# neither env var set the script fits a 10-spec spanning subset, writes a
# testrun object, and prints the extrapolated full-grid runtime WITHOUT
# touching data/spec-results.rds. `SPEC_CURVE_FULL=1` fits all 3,496 and writes
# data/spec-results.rds -- that is Task 3.7. A data/spec-results.rds newer than
# the registry and this script is reused as-is (keeps make.R fast).
#
# Outputs: R/04-spec-curve.R, and either output/models/spec-curve-testrun.rds
# (test) or data/spec-results.rds (full).

suppressMessages({ library(lme4); library(mice); library(splines) })

n_   <- function(x) suppressWarnings(as.numeric(x))
zsc  <- function(x, mu, sd) (x - mu) / sd
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

RESULTS  <- file.path("data", "spec-results.rds")
REGF     <- file.path("data", "spec-registry.rds")
SELF     <- file.path("R", "04-spec-curve.R")
## cache (Task S0.3): a full results object is reused when its recorded key
## matches this script, the registry and the two data files byte for byte --
## make.R stays fast after Task 3.7 has run once. SPEC_CURVE_FULL=1 forces a
## refit. Under make.R --release (VP_RELEASE=1) a stale cache means the FULL
## run, never the 10-spec TEST subset.
if (!exists("cache_key")) source(file.path("R", "cache-key.R"))
SC_KEY <- cache_key(c(SELF, REGF, file.path("data", c("analytic-v2.rds", "blockC_mice.rds"))))
FULL   <- identical(Sys.getenv("SPEC_CURVE_FULL"), "1") || identical(Sys.getenv("VP_RELEASE"), "1")
CACHED <- cache_fresh(RESULTS, SC_KEY, "SPEC_CURVE_FULL")
TEST   <- !FULL && !CACHED
MI_M  <- as.integer(Sys.getenv("SPEC_CURVE_MI_M", "20"))
LAM_HI <- 0.60                         # high-reliability subsample threshold (spec-space Sec 5)
ctrl  <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5),
                     check.conv.singular = .makeCC("ignore", tol = 1e-4))

hdr(sprintf("TASK 3.6/3.7  specification-curve harness  --  mode: %s",
            if (CACHED) "CACHED (reuse data/spec-results.rds)"
            else if (TEST) "TEST (10-spec subset)" else "FULL (all registered specs)"))

reg <- readRDS(file.path("data", "spec-registry.rds"))
a   <- readRDS(file.path("data", "analytic-v2.rds"))
imp <- readRDS(file.path("data", "blockC_mice.rds"))
cat(sprintf("  registry: %d specs   frame: %d hospitals\n", nrow(reg), nrow(a)))

# ==========================================================================
# 1.  BLOCK MAPS  --  canonical name -> analytic column (Block B gets a grain
#     suffix at fit time). Identical working sets to R/03-baseline.R / Task 3.1.
# ==========================================================================
bA <- c(beds = "beds", adc = "adc", occupancy = "occupancy",
        resident_to_bed = "resident_to_bed", teaching = "teaching", cmi = "cmi",
        volume = "volume_bills", dsh_pct = "dsh_pct", wage_index = "wage_index",
        operating_margin = "operating_margin", uncomp_care = "uncompensated_care_pct_npr")
bB_base <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150",
             "uninsured", "limeng", "rurality", "pcp_density", "hhi")
bC_all  <- c(cmi_drift = "cmi_drift", contract_labor_share = "contract_labor_share",
             tort_n_reforms = "tort_n_reforms", tort_cap_total = "tort_cap_total")

## the disadvantage-contrast profile: 10 of the 11 Block B measures (hhi is a
## market-structure control, not a deprivation axis), each with the sign that
## points at "more deprived". ICE-150 is affluence-scored and PCP density is a
## resource, so both are inverted.
DIS_SIGN <- c(svi1 = 1, svi2 = 1, svi3 = 1, svi4 = 1, adi = 1, ice150 = -1,
              uninsured = 1, limeng = 1, rurality = 1, pcp_density = -1)

## form = spline splines only the continuous disadvantage measures
## (spec-space.md Sec 3). rurality (USDA RUCC, an integer 1-9 code) and
## pcp_density stay linear in both forms -- and splining RUCC at a coarse grain
## makes the ns() basis rank-deficient, which lme4 then has to drop columns for.
SPLINE_SET <- c("svi1", "svi2", "svi3", "svi4", "adi", "ice150", "uninsured", "limeng")

SUFFIX <- c(catch_tract = "_catch_tract", catch_county = "_catch_county",
            hosp_county = "_county", hsa = "_hsa")
bcol <- function(base, grain) {
  if (base == "hhi") return(if (grain == "hsa") "hhi_hsa" else "hhi_zip")
  paste0(base, SUFFIX[[grain]])
}

COMPS <- c("psi03", "psi06", "psi12", "psi13")

# ==========================================================================
# 2.  FIXED STANDARDISATION  --  computed once on the frame, reused in every
#     spec so a coefficient (and the p10/p90 contrast) means the same thing
#     across the whole curve.
# ==========================================================================
## Block A + Block C z-params
zA <- sapply(setdiff(names(bA), "teaching"),
             function(k) c(mu = mean(n_(a[[bA[[k]]]]), na.rm = TRUE),
                           sd = sd(n_(a[[bA[[k]]]]), na.rm = TRUE)))
zC <- sapply(names(bC_all),
             function(k) c(mu = mean(n_(a[[bC_all[[k]]]]), na.rm = TRUE),
                           sd = sd(n_(a[[bC_all[[k]]]]), na.rm = TRUE)))
## Block B z-params AND p10/p90 quantiles, per measure per grain
zB <- list(); qB <- list()
for (g in names(SUFFIX)) for (b in bB_base) {
  x <- n_(a[[bcol(b, g)]])
  zB[[paste(b, g, sep = ".")]] <- c(mu = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE))
  qB[[paste(b, g, sep = ".")]] <- quantile(x, c(.10, .90), na.rm = TRUE, names = FALSE)
}
## component outcome z-params (raw rate and log rate)
yP <- sapply(COMPS, function(cp) {
  x <- n_(a[[cp]])
  c(mu = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE),
    lmu = mean(log(x), na.rm = TRUE), lsd = sd(log(x), na.rm = TRUE))
})
## national means for the denominator-weighted aggregate (component rate / its
## own national mean -> a mean-1 ratio, same construction logic as PSI-90,
## then denominator-weighted; positive, so log() is defined)
natMean <- yP["mu", ]
## spline knots, in z-units, fixed from the frame (df ~ 4)
knotB <- list()
for (g in names(SUFFIX)) for (b in SPLINE_SET) {
  key <- paste(b, g, sep = ".")
  z <- zsc(n_(a[[bcol(b, g)]]), zB[[key]]["mu"], zB[[key]]["sd"])
  knotB[[key]] <- list(k = quantile(z, c(.25, .5, .75), na.rm = TRUE, names = FALSE),
                       bk = quantile(z, c(.05, .95), na.rm = TRUE, names = FALSE))
}

# ==========================================================================
# 3.  BUILD ONE SPEC'S MODELLING FRAME + FORMULA
# ==========================================================================
## returns a list: data (hospital-level or long), fe_rhs (character vector of
## RHS terms, no intercept-less tricks), nest (chr or NA), weights col name,
## the Block B canonical names in the model, a per-measure "term label" map,
## and the newdata rows for the focal contrast.
prep_spec <- function(s, base = a) {
  d <- base

  ## ---- influential-point level ----
  if (s$influential == "drop_fn2329")
    d <- d[!(d$fn_claims_discrepancy | d$fn_partial_window), ]
  else if (s$influential == "drop_fallback")
    d <- d[d$catch_source != "county_fallback", ]

  ## ---- reliability: high-reliability subsample ----
  if (s$reliability == "subsample")
    d <- d[!is.na(d$lambda_i) & d$lambda_i >= LAM_HI, ]

  ## ---- which blocks ----
  useB <- s$blocks %in% c("AB", "ABC")
  useC <- s$blocks == "ABC"
  cNames <- names(bC_all)
  if (useC && s$missing == "omit") cNames <- setdiff(cNames, "contract_labor_share")

  ## ---- Block A / C standardised columns (hospital level) ----
  for (k in setdiff(names(bA), "teaching")) d[[k]] <- zsc(n_(d[[bA[[k]]]]), zA["mu", k], zA["sd", k])
  d[["teaching"]] <- as.numeric(d[["teaching"]])
  if (useC) for (k in cNames) d[[k]] <- zsc(n_(d[[bC_all[[k]]]]), zC["mu", k], zC["sd", k])

  ## ---- Block B standardised columns at the spec's grain ----
  bUse <- if (useB) bB_base else character(0)
  for (b in bUse) {
    key <- paste(b, s$grain, sep = ".")
    d[[b]] <- zsc(n_(d[[bcol(b, s$grain)]]), zB[[key]]["mu"], zB[[key]]["sd"])
  }

  ## ---- RHS term labels ----
  termlab <- function(b) {
    if (s$form == "linear" || !(b %in% SPLINE_SET)) return(b)
    key <- paste(b, s$grain, sep = ".")
    sprintf("ns(%s, knots=c(%s), Boundary.knots=c(%s))", b,
            paste(signif(knotB[[key]]$k, 8), collapse = ","),
            paste(signif(knotB[[key]]$bk, 8), collapse = ","))
  }
  feA <- names(bA)
  feB <- if (useB) vapply(bB_base, termlab, character(1)) else character(0)
  feC <- if (useC) cNames else character(0)

  ## ---- outcome + level of analysis ----
  ## Every arm is one row per hospital. Component and aggregate outcomes carry a
  ## geography random intercept (1 | nest) -- the Task 3.2 approach: an un-
  ## smoothed outcome, hospitals partially pooled within catchment geography.
  ## The composite is lm() only, no random intercept at any level (standing
  ## rule 6 -- the published PSI-90 is already shrunk and nothing re-shrinks it;
  ## Task 3.2 Sec 7). `grain` still varies the composite via its Block B columns.
  fam  <- s$outcome_family
  nest <- if (s$nest == "county") "county_fips" else "hsa"
  d$.nest <- as.character(d[[nest]])

  if (fam == "component") {
    cp <- s$outcome
    d$.y <- if (s$scale == "log") zsc(log(n_(d[[cp]])), yP["lmu", cp], yP["lsd", cp])
            else                  zsc(n_(d[[cp]]),      yP["mu",  cp], yP["sd",  cp])
    d$.w <- n_(d[[paste0(cp, "_denom")]])
  } else if (fam == "aggregate") {
    num <- den <- rep(0, nrow(d))
    for (cp in COMPS) {
      r <- n_(d[[cp]]) / natMean[[cp]]; wc <- n_(d[[paste0(cp, "_denom")]])
      ok <- is.finite(r) & is.finite(wc) & wc > 0
      num[ok] <- num[ok] + wc[ok] * r[ok]; den[ok] <- den[ok] + wc[ok]
    }
    raw <- ifelse(den > 0, num / den, NA_real_)
    d$.y <- if (s$scale == "log") log(pmax(raw, 1e-6)) else raw
    d$.w <- den
  } else {                                     # composite
    p <- n_(d$psi90)
    if (s$reliability == "eiv") {              # un-shrink: gm + (p - gm)/lambda
      gm <- mean(p, na.rm = TRUE)
      p  <- gm + (p - gm) / pmax(n_(d$lambda_i), 1e-3)
    }
    d$.y <- if (s$scale == "log") log(pmax(p, 1e-6)) else p
    d$.w <- switch(s$reliability, unweighted = 1, weighted = n_(d$lambda_i),
                   subsample = n_(d$lambda_i), eiv = n_(d$lambda_i)^2)
  }
  dd <- d[is.finite(d$.y) & is.finite(d$.w) & d$.w > 0 &
          !is.na(d$.nest) & nzchar(d$.nest), ]

  ## drop rows with any NA in a term actually used (lm/lmer would anyway; do it
  ## explicitly so n_obs is meaningful and the same across the block comparison)
  keep <- rep(TRUE, nrow(dd))
  for (v in c(names(bA), if (useB) bB_base, if (useC) cNames)) keep <- keep & is.finite(n_(dd[[v]]))
  dd <- dd[keep, ]

  ## rescale weights to mean 1 -- WLS is invariant to the scale of the weights,
  ## but the published component denominators span 29 to 56,196, and lme4's
  ## convergence check reads that as "very large eigenvalue -- rescale variables"
  ## on ~half the mixed fits. Mean-1 weights make the convergence flag mean
  ## something real. Same fix R/03-baseline.R applied (`L$w <- L$w / mean(L$w)`).
  dd$.w <- dd$.w / mean(dd$.w)

  list(data = dd, feA = feA, feB = feB, feC = feC, bUse = bUse,
       fam = fam, nest = nest, grain = s$grain, form = s$form,
       mixed = fam %in% c("component", "aggregate"))
}

## the two contrast rows (hospital-level covariate profile: every disadvantage
## measure at its oriented p10 / p90, everything else at the reference 0).
contrast_rows <- function(pp) {
  base <- setNames(as.list(rep(0, length(names(bA)) + length(pp$bUse) +
                               length(pp$feC))),
                   c(names(bA), pp$bUse, pp$feC))
  base$teaching <- 0
  hi <- lo <- base
  for (b in pp$bUse) {
    key <- paste(b, pp$grain, sep = ".")
    q   <- (qB[[key]] - zB[[key]]["mu"]) / zB[[key]]["sd"]     # p10,p90 in z-units
    sgn <- if (b %in% names(DIS_SIGN)) DIS_SIGN[[b]] else 0
    if (sgn == 0) { hi[[b]] <- 0; lo[[b]] <- 0 }              # hhi: no contrast
    else if (sgn > 0) { hi[[b]] <- q[2]; lo[[b]] <- q[1] }
    else              { hi[[b]] <- q[1]; lo[[b]] <- q[2] }
  }
  rbind(as.data.frame(hi), as.data.frame(lo))
}

# ==========================================================================
# 4.  FIT ONE SPEC  ->  one uniform result row
# ==========================================================================
RESULT_COLS <- c("spec_id", "status", "fail_reason", "n_obs", "n_hosp",
                 "converged", "singular", "lme4_msg", "m_imp",
                 "dis_effect", "dis_se", "dis_sign", "dis_sig",
                 paste0("b_", names(DIS_SIGN)), paste0("se_", names(DIS_SIGN)),
                 "loss_wrmse", "logLik", "AIC", "deviance",
                 "var_geo", "var_hosp", "var_resid", "icc_geo", "runtime_s")

blank_row <- function(spec_id) {
  r <- as.list(rep(NA, length(RESULT_COLS))); names(r) <- RESULT_COLS
  r$spec_id <- spec_id; r$status <- "failed"; r
}

## contrast value + SE from a fitted lm / merMod, given the fixed-effect terms
## object built on the training data and the hi/lo newdata.
contrast_estimate <- function(m, fe_terms, nd, is_mer) {
  MM <- model.matrix(fe_terms, nd)
  cvec <- MM[1, ] - MM[2, ]
  beta <- if (is_mer) lme4::fixef(m) else coef(m)
  V    <- as.matrix(vcov(m))
  nm   <- intersect(names(cvec), names(beta[!is.na(beta)]))
  cc   <- cvec[nm]
  list(est = sum(cc * beta[nm]), se = sqrt(as.numeric(t(cc) %*% V[nm, nm] %*% cc)),
       cvec = cvec, dropped = setdiff(names(cvec), nm))
}

## per-measure single contrast: zero the contrast vector except one measure's
## term columns, recompute est/SE.
measure_effects <- function(cvec, m, is_mer, feB, bUse, V, beta) {
  out_e <- setNames(rep(NA_real_, length(DIS_SIGN)), names(DIS_SIGN))
  out_s <- out_e
  for (i in seq_along(bUse)) {
    b <- bUse[i]; if (!(b %in% names(DIS_SIGN))) next
    lab <- feB[i]
    cols <- grep(sprintf("^(ns\\(%s,|%s$)", b, b), names(cvec))
    if (!length(cols)) next
    cc <- rep(0, length(cvec)); names(cc) <- names(cvec); cc[cols] <- cvec[cols]
    nm <- intersect(names(cc)[cc != 0], names(beta[!is.na(beta)]))
    if (!length(nm)) next
    out_e[b] <- sum(cc[nm] * beta[nm])
    out_s[b] <- sqrt(as.numeric(t(cc[nm]) %*% V[nm, nm] %*% cc[nm]))
  }
  list(e = out_e, s = out_s)
}

fit_spec <- function(s) {
  t0 <- Sys.time(); row <- blank_row(s$spec_id)
  out <- tryCatch({
    completions <- if (s$missing == "mi") seq_len(MI_M) else 1L
    fits <- vector("list", length(completions))
    for (j in seq_along(completions)) {
      base <- a
      if (s$missing == "mi") {
        cd <- mice::complete(imp, completions[j])
        base$contract_labor_share <- cd$cl_share
        base$beds <- exp(cd$log_beds); base$volume_bills <- exp(cd$log_vol)
        base$wage_index <- cd$wage_index; base$cmi <- cd$cmi
        base$dsh_pct <- cd$dsh_pct; base$occupancy <- cd$occupancy
        base$teaching <- cd$teaching
      }
      pp <- prep_spec(s, base)
      if (nrow(pp$data) < 50) stop(sprintf("modelling frame has %d rows (<50)", nrow(pp$data)))
      fe <- paste(c(pp$feA, pp$feB, pp$feC), collapse = " + ")
      is_mer <- pp$mixed
      if (is_mer) {
        m <- lmer(as.formula(sprintf(".y ~ %s + (1 | .nest)", fe)),
                  data = pp$data,
                  weights = if (s$reliability == "unweighted") rep(1, nrow(pp$data)) else pp$data$.w,
                  REML = TRUE, control = ctrl)
      } else {
        m <- lm(as.formula(sprintf(".y ~ %s", fe)), data = pp$data, weights = pp$data$.w)
      }
      fe_terms <- terms(as.formula(sprintf("~ %s", fe)), data = pp$data)
      nd <- contrast_rows(pp)
      ce <- if (length(pp$bUse)) contrast_estimate(m, fe_terms, nd, is_mer) else NULL
      beta <- if (is_mer) lme4::fixef(m) else coef(m)
      V <- as.matrix(vcov(m))
      me <- if (!is.null(ce))
              measure_effects(ce$cvec, m, is_mer, pp$feB, pp$bUse, V, beta) else NULL
      ## loss + fit
      res <- residuals(m)
      wts <- weights(m); if (is.null(wts)) wts <- rep(1, length(res))
      wrmse <- sqrt(sum(wts * res^2) / sum(wts))
      vc <- if (is_mer) { v <- as.data.frame(VarCorr(m))
              c(geo = v$vcov[v$grp == ".nest"], hosp = NA_real_, resid = v$vcov[v$grp == "Residual"])
            } else c(geo = NA_real_, hosp = NA_real_, resid = sigma(m)^2)
      fits[[j]] <- list(
        n_obs = nobs(m), n_hosp = length(unique(pp$data$ccn)),
        conv = if (is_mer) length(m@optinfo$conv$lme4$messages) == 0 else TRUE,
        sing = if (is_mer) isSingular(m) else FALSE,
        msg = if (is_mer && length(m@optinfo$conv$lme4$messages))
                paste(m@optinfo$conv$lme4$messages, collapse = "; ") else NA_character_,
        dis_e = if (!is.null(ce)) ce$est else NA_real_,
        dis_v = if (!is.null(ce)) ce$se^2 else NA_real_,
        me_e = if (!is.null(me)) me$e else setNames(rep(NA_real_, length(DIS_SIGN)), names(DIS_SIGN)),
        me_v = if (!is.null(me)) me$s^2 else setNames(rep(NA_real_, length(DIS_SIGN)), names(DIS_SIGN)),
        wrmse = wrmse, ll = as.numeric(logLik(m)), aic = AIC(m),
        dev = if (is_mer) deviance(m, REML = FALSE) else deviance(m),
        vc = vc)
    }
    ## pool across completions (Rubin) -- trivial when length == 1
    pool1 <- function(est, var) {
      qbar <- mean(est); ubar <- mean(var); bvar <- if (length(est) > 1) var(est) else 0
      Tv <- ubar + (1 + 1 / length(est)) * bvar
      c(est = qbar, se = sqrt(Tv))
    }
    dis <- pool1(vapply(fits, `[[`, numeric(1), "dis_e"),
                 vapply(fits, `[[`, numeric(1), "dis_v"))
    meE <- sapply(names(DIS_SIGN), function(b)
      pool1(vapply(fits, function(f) f$me_e[[b]], numeric(1)),
            vapply(fits, function(f) f$me_v[[b]], numeric(1))))
    f1 <- fits[[1]]
    row$status <- "ok"; row$fail_reason <- NA
    row$n_obs <- f1$n_obs; row$n_hosp <- f1$n_hosp
    row$converged <- all(vapply(fits, `[[`, logical(1), "conv"))
    row$singular  <- any(vapply(fits, `[[`, logical(1), "sing"))
    row$lme4_msg  <- f1$msg; row$m_imp <- length(fits)
    row$dis_effect <- unname(dis["est"]); row$dis_se <- unname(dis["se"])
    row$dis_sign <- if (is.na(dis["est"])) NA else sign(dis["est"])
    row$dis_sig  <- if (is.na(dis["est"])) NA else abs(dis["est"] / dis["se"]) > 1.96
    for (b in names(DIS_SIGN)) { row[[paste0("b_", b)]] <- meE["est", b]
                                 row[[paste0("se_", b)]] <- meE["se", b] }
    row$loss_wrmse <- mean(vapply(fits, `[[`, numeric(1), "wrmse"))
    row$logLik <- mean(vapply(fits, `[[`, numeric(1), "ll"))
    row$AIC <- mean(vapply(fits, `[[`, numeric(1), "aic"))
    row$deviance <- mean(vapply(fits, `[[`, numeric(1), "dev"))
    vcm <- rowMeans(vapply(fits, function(f) unname(f$vc[c("geo", "hosp", "resid")]), numeric(3)))
    row$var_geo <- vcm[1]; row$var_hosp <- vcm[2]; row$var_resid <- vcm[3]
    row$icc_geo <- if (is.na(vcm[1])) NA else vcm[1] / sum(vcm[c(1, 3)], na.rm = TRUE)
    row
  }, error = function(e) { row$fail_reason <- conditionMessage(e); row })
  out$runtime_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  as.data.frame(out, stringsAsFactors = FALSE)
}

# ==========================================================================
# 5.  SELECT SPECS  --  10-spanning subset in TEST mode, all in FULL mode
# ==========================================================================
if (CACHED) {

R <- readRDS(RESULTS)$results
cat(sprintf("\n  data/spec-results.rds is newer than the registry and this script -- reused (no refit).\n"))
cat(sprintf("  %d rows: %d ok, %d failed, %d non-converged (flagged, kept).\n",
            nrow(R), sum(R$status == "ok"), sum(R$status == "failed"),
            sum(!R$converged & R$status == "ok", na.rm = TRUE)))
cat("\n"); hdr("done (cached)")

} else {

if (TEST) {
  cand <- c(
    which(reg$blocks == "A" & reg$outcome == "composite")[1],
    which(reg$blocks == "A" & reg$outcome == "psi13")[1],
    which(reg$outcome == "composite" & reg$reliability == "eiv")[1],
    which(reg$outcome == "composite" & reg$reliability == "subsample")[1],
    which(reg$outcome == "psi13"     & reg$missing == "mi" & reg$form == "spline")[1],
    which(reg$outcome == "agg"       & reg$form == "spline")[1],
    which(reg$outcome == "psi06"     & reg$form == "spline" & reg$blocks == "ABC")[1],
    which(reg$outcome == "composite" & reg$blocks == "AB" & reg$form == "linear")[1],
    which(reg$outcome == "psi03"     & reg$missing == "omit")[1],
    which(reg$outcome == "psi12"     & reg$grain == "hsa" & reg$blocks == "ABC")[1],
    which(reg$outcome == "composite" & reg$grain == "hosp_county")[1],
    which(reg$outcome == "agg"       & reg$missing == "mi")[1])
  pick <- head(unique(na.omit(cand)), 10)
  todo <- reg[pick, ]
} else {
  todo <- reg
}
cat(sprintf("\n  fitting %d spec(s)%s\n", nrow(todo),
            if (TEST) sprintf(" (ids: %s)", paste(todo$spec_id, collapse = ", ")) else ""))

# ==========================================================================
# 6.  RUN
# ==========================================================================
res <- vector("list", nrow(todo))
for (i in seq_len(nrow(todo))) {
  res[[i]] <- fit_spec(as.list(todo[i, ]))
  if (TEST || i %% 100 == 0)
    cat(sprintf("  [%4d/%4d] spec %-5d  %-7s  %-9s  %6.2fs  %s\n", i, nrow(todo),
                todo$spec_id[i], todo$outcome[i], res[[i]]$status, res[[i]]$runtime_s,
                if (res[[i]]$status == "failed") res[[i]]$fail_reason
                else sprintf("dis=%s", ifelse(is.na(res[[i]]$dis_effect), "NA",
                                              sprintf("%+.4f", res[[i]]$dis_effect)))))
}
R <- do.call(rbind, res)
R <- merge(reg, R, by = "spec_id", all.x = !TEST, all.y = TEST, sort = TRUE)

# ==========================================================================
# 7.  RUNTIME ESTIMATE  (task sheet: "Runtime for the full grid is estimated
#     before launching it.")
# ==========================================================================
sub_("runtime")
rt <- setNames(R$runtime_s, R$spec_id)
per_mode <- tapply(R$runtime_s, list(paste(R$outcome_family, ifelse(R$missing == "mi", "mi", "single"))), mean)
cat("  mean seconds per spec, by family x missing:\n")
for (k in names(per_mode)) cat(sprintf("    %-22s %6.3f s\n", k, per_mode[k]))
if (TEST) {
  key <- paste(reg$outcome_family, ifelse(reg$missing == "mi", "mi", "single"))
  fallback <- mean(R$runtime_s)
  est <- sum(ifelse(key %in% names(per_mode), per_mode[key], fallback))
  cat(sprintf("\n  EXTRAPOLATED full-grid runtime (%d specs): %.0f s  =  %.1f min  =  %.2f h\n",
              nrow(reg), est, est / 60, est / 3600))
  cat(sprintf("  (mi specs modelled at m = %d fits each; composite/agg are lm and cheap)\n", MI_M))
}

# ==========================================================================
# 8.  WRITE
# ==========================================================================
sub_("write")
if (TEST) {
  saveRDS(list(results = R, registry_rows = todo, mode = "test", mi_m = MI_M),
          file.path("output", "models", "spec-curve-testrun.rds"))
  cat("  output/models/spec-curve-testrun.rds\n")
  cat(sprintf("  status: %d ok, %d failed of %d\n",
              sum(R$status == "ok"), sum(R$status == "failed"), nrow(R)))
} else {
  cache_save(list(results = R, mi_m = MI_M, lam_hi = LAM_HI, fit_time = Sys.time()),
             RESULTS, SC_KEY)
  write.csv(R[, setdiff(names(R), "key")], file.path("data", "spec-results.csv"), row.names = FALSE)
  cat(sprintf("  data/spec-results.rds  --  %d rows, %d ok, %d failed\n",
              nrow(R), sum(R$status == "ok"), sum(R$status == "failed")))
}

# ==========================================================================
hdr("verify")
nf <- sum(R$status == "failed")
cat(sprintf("  1. every spec produced a row (%d rows / %d requested) -- %s\n",
            nrow(R), nrow(todo), if (nrow(R) == nrow(todo)) "PASS" else "CHECK"))
cat(sprintf("  2. failures are rows with a reason, not skips: %d failed", nf))
if (nf) cat(" -> ", paste(unique(R$fail_reason[R$status == "failed"]), collapse = " | "))
cat(sprintf("  --  %s\n", if (nf == 0 || all(nzchar(R$fail_reason[R$status == "failed"]))) "PASS" else "CHECK"))
cat(sprintf("  3. non-convergence / singular fits are FLAGGED and kept: %d non-conv, %d singular, still in the object -- PASS\n",
            sum(!R$converged & R$status == "ok", na.rm = TRUE),
            sum(R$singular & R$status == "ok", na.rm = TRUE)))
cat(sprintf("  4. focal estimate present for every Block-B spec: %d/%d -- %s\n",
            sum(!is.na(R$dis_effect)), sum(R$blocks != "A"),
            if (sum(!is.na(R$dis_effect)) == sum(R$blocks != "A" & R$status == "ok")) "PASS" else "CHECK (see failed)"))
if (TEST) cat("  5. runtime for the full grid estimated above, BEFORE the full run -- PASS\n")
stopifnot(nrow(R) == nrow(todo),
          all(R$status %in% c("ok", "failed")),
          all(R$status == "ok" | !is.na(R$fail_reason)))

hdr("done")
if (TEST) cat("\n  TEST run only. Task 3.7 runs the full grid with SPEC_CURVE_FULL=1.\n\n")

}  # end !CACHED
