# R/05-rashomon.R  --  Task 3.9, selecting the Rashomon tolerance by bootstrap.
#
# Reads data/spec-registry.rds (the frozen grid, Task 3.5), data/analytic-v2.rds
# and data/blockC_mice.rds. Sources R/04-spec-curve.R for its helpers only --
# that script's CACHED guard means sourcing it defines prep_spec() and the
# frozen standardisation and refits nothing.
#
# THE PROCEDURE IS PRE-REGISTERED. provenance/rashomon-preregistration.md was
# committed on its own, before this script was run, and fixes every choice made
# below: alpha, the loss, the empirical-risk-minimizer rule, the resampling
# unit, the replicate counts, and what happens to a failed replicate. Task 3.9's
# verify condition is that the tolerance came from the bootstrap rather than an
# analyst's judgement and that alpha was fixed before the quantile was computed,
# so the commit timestamp of that file is the evidence, the same device Task 3.5
# used to show the registry predated the first fit. Read it before this file.
#
# WHY A NEW LOSS. The curve's own `loss_wrmse` is computed on whatever rows and
# whatever outcome scale each spec was fitted on: the subsample arm's is over
# fewer hospitals, the log arm's is in log units, the errors-in-variables arm's
# is against an un-shrunk outcome nothing else is predicting. Those are not
# comparable, and a Rashomon set built on them would be an artefact of
# bookkeeping. So every spec is re-fitted here and scored on a COMMON EVALUATION
# FRAME fixed once per outcome family -- same hospitals, same target, same
# unweighted mean squared error -- with each spec's predictions mapped back to
# the target's natural scale first (exp() for log fits, un-z for component fits,
# re-shrinking by gm + lambda_i(yhat - gm) for the errors-in-variables arm,
# which is the exact inverse of the transform that un-shrunk it).
#
# Losses are comparable WITHIN an outcome family and not across families, since
# the target differs. Each family gets its own ERM and its own tolerance. The
# composite is primary (Plan Sec 6, Task 3.12); aggregate and the four component
# families are secondary. The composite's bootstrap is run three ways: by
# hospital (the pre-registered primary), by state (the pre-registered
# sensitivity), and by metro area (CBSA -- amendment 2, added after the first
# two were read, and labeled as such wherever it appears).
#
# RUNTIME: the loss table re-fits all 3,496 specs (~40 min, the m = 20
# imputation arms dominate) and is cached in data/rashomon-loss.rds; a cache
# newer than the registry and R/04-spec-curve.R is reused, so editing THIS file
# does not trigger a re-fit. RASHOMON_REFIT=1 forces one. The bootstrap draws
# are cached the same way in data/rashomon-boot.rds. The quantile itself is
# always recomputed from the stored draws.
#
# Outputs: data/rashomon-loss.rds (the per-spec common-frame loss table, the
# input Task 3.10 builds the set from), data/rashomon-boot.rds,
# data/rashomon-tolerance.rds, output/tables/rashomon-tolerance.csv,
# output/tables/rashomon-loss.csv, output/figures/rashomon-tolerance.png.

suppressMessages({ library(lme4); library(mice); library(splines) })

# ==========================================================================
# 0.  THE PRE-REGISTERED CONSTANTS  --  fixed in
#     provenance/rashomon-preregistration.md, committed 2026-09-10, before
#     any loss in this script was computed.
# ==========================================================================
ALPHA        <- 0.05     # tolerance = the (1 - ALPHA) quantile of excess loss
B_PRIMARY    <- 1000L    # bootstrap replicates, composite family + its sensitivity
B_SECONDARY  <- 200L     # bootstrap replicates, aggregate and component families
Q_MCSE_DRAWS <- 2000L    # second-level draws for the quantile's Monte-Carlo SE
BOOT_SEED    <- 20260910L

n_   <- function(x) suppressWarnings(as.numeric(x))
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 3.9  selecting the Rashomon tolerance by bootstrap")
cat(sprintf("\n  alpha = %.2f, fixed at provenance/rashomon-preregistration.md and committed\n", ALPHA))
cat(sprintf("  before this script ran. The tolerance is the %.0fth percentile of the\n", 100 * (1 - ALPHA)))
cat( "  bootstrap excess-loss distribution and is not chosen here.\n")

e <- new.env()
local({ tf <- tempfile(); sink(tf)
        sys.source(file.path("R", "04-spec-curve.R"), envir = e)
        sink(); unlink(tf) })
cat(sprintf("\n  helpers from R/04-spec-curve.R loaded (no re-fit): prep_spec, the frozen\n"))
cat(sprintf("  standardisation, the block maps.\n"))

reg <- readRDS(file.path("data", "spec-registry.rds"))
a   <- readRDS(file.path("data", "analytic-v2.rds"))
imp <- readRDS(file.path("data", "blockC_mice.rds"))
cat(sprintf("  registry: %d specs   frame: %d hospitals\n", nrow(reg), nrow(a)))

## The m = 20 completions are frozen (Task 2.7) and aligned to the analytic
## file's row order. A bootstrap resample permutes and repeats rows, so the
## completions have to travel WITH the rows rather than being re-indexed by
## position -- `.orig` is that address, and it is the whole of what
## "bootstrap after imputation" means here (pre-registration Sec 4).
a$.orig <- seq_len(nrow(a))
IMPC <- lapply(seq_len(e$MI_M), function(j) {
  cd <- mice::complete(imp, j)
  stopifnot(nrow(cd) == nrow(a))
  data.frame(contract_labor_share = cd$cl_share, beds = exp(cd$log_beds),
             volume_bills = exp(cd$log_vol), wage_index = cd$wage_index,
             cmi = cd$cmi, dsh_pct = cd$dsh_pct, occupancy = cd$occupancy,
             teaching = cd$teaching)
})

LOSSF <- file.path("data", "rashomon-loss.rds")
BOOTF <- file.path("data", "rashomon-boot.rds")
## caches keyed (Task S0.3) on the harness, the registry, the data, and the
## text of the functions in this script that compute a loss or a draw -- not on
## this whole file, so editing a printed line does not force a 40-minute refit.
## RASHOMON_REFIT=1 forces one.
if (!exists("cache_key")) source(file.path("R", "cache-key.R"))
RS_FILES <- c(file.path("R", "04-spec-curve.R"),
              file.path("data", c("spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
rs_key <- function(fn) cache_key(RS_FILES, mget(fn, envir = parent.frame(), inherits = TRUE))
LOSS_FUNS <- c("fin", "agg_of", "fit_model", "eiv_gm", "eval_design", "predict_natural", "mi_base", "spec_loss")
BOOT_FUNS <- c(LOSS_FUNS, "cluster_index", "resample", "boot_family")

# ==========================================================================
# 1.  THE COMMON EVALUATION FRAME, one per outcome family
#     (pre-registration Sec 2: complete-case A+B+C, one row per hospital,
#     intersected with the rows where that family's outcome and weight exist)
# ==========================================================================
sub_("common evaluation frames")

fin <- function(cl) is.finite(n_(a[[cl]]))
okA <- Reduce(`&`, lapply(setdiff(names(e$bA), "teaching"), function(k) fin(e$bA[[k]])))
okA <- okA & is.finite(n_(a$teaching))
bcols <- unique(unlist(lapply(names(e$SUFFIX), function(g) vapply(e$bB_base, e$bcol, character(1), grain = g))))
okB <- Reduce(`&`, lapply(bcols, fin))
okC <- Reduce(`&`, lapply(names(e$bC_all), function(k) fin(e$bC_all[[k]])))
okN <- !is.na(a$county_fips) & nzchar(as.character(a$county_fips)) &
       !is.na(a$hsa) & nzchar(as.character(a$hsa))
BASE_OK <- okA & okB & okC & okN
cat(sprintf("  complete-case A+B+C with both nestings: %d of %d hospitals\n", sum(BASE_OK), nrow(a)))

## the denominator-weighted component aggregate, on the frame (same construction
## as the harness: component rate over its own national mean, denominator-weighted)
agg_of <- function(d) {
  num <- den <- rep(0, nrow(d))
  for (cp in e$COMPS) {
    r <- n_(d[[cp]]) / e$natMean[[cp]]; w <- n_(d[[paste0(cp, "_denom")]])
    ok <- is.finite(r) & is.finite(w) & w > 0
    num[ok] <- num[ok] + w[ok] * r[ok]; den[ok] <- den[ok] + w[ok]
  }
  list(y = ifelse(den > 0, num / den, NA_real_), den = den)
}
AG <- agg_of(a)

FAMS <- c("composite", "agg", "psi03", "psi06", "psi12", "psi13")
EVAL <- list()
for (fam in FAMS) {
  keep <- BASE_OK
  if (fam == "composite") {
    keep <- keep & is.finite(n_(a$psi90)) & is.finite(n_(a$lambda_i)) & n_(a$lambda_i) > 0
    y <- n_(a$psi90)
  } else if (fam == "agg") {
    keep <- keep & is.finite(AG$y) & AG$den > 0
    y <- AG$y
  } else {
    keep <- keep & is.finite(n_(a[[fam]])) & is.finite(n_(a[[paste0(fam, "_denom")]])) &
            n_(a[[paste0(fam, "_denom")]]) > 0
    y <- n_(a[[fam]])
  }
  EVAL[[fam]] <- list(rows = which(keep), y = y[keep], dat = a[keep, , drop = FALSE])
  cat(sprintf("  %-10s n = %4d   target sd = %.4f   var = %.6f\n",
              fam, sum(keep), sd(y[keep]), var(y[keep])))
}

# ==========================================================================
# 2.  FIT ONE SPEC, PREDICT ON ITS FAMILY'S FRAME, SCORE
# ==========================================================================
## the fit, exactly as R/04-spec-curve.R fits it
fit_model <- function(s, base) {
  pp <- e$prep_spec(s, base)
  if (nrow(pp$data) < 50) stop(sprintf("modelling frame has %d rows (<50)", nrow(pp$data)))
  fe <- paste(c(pp$feA, pp$feB, pp$feC), collapse = " + ")
  m <- if (pp$mixed)
    lmer(as.formula(sprintf(".y ~ %s + (1 | .nest)", fe)), data = pp$data,
         weights = if (s$reliability == "unweighted") rep(1, nrow(pp$data)) else pp$data$.w,
         REML = TRUE, control = e$ctrl)
  else
    lm(as.formula(sprintf(".y ~ %s", fe)), data = pp$data, weights = pp$data$.w)
  list(m = m, pp = pp, mixed = pp$mixed)
}

## the grand mean the errors-in-variables arm un-shrinks around. prep_spec takes
## it after the influential and subsample filters and before the finite filter,
## so this reproduces that order exactly.
eiv_gm <- function(s, base) {
  d <- base
  if (s$influential == "drop_fn2329")      d <- d[!(d$fn_claims_discrepancy | d$fn_partial_window), ]
  else if (s$influential == "drop_fallback") d <- d[d$catch_source != "county_fallback", ]
  if (s$reliability == "subsample")        d <- d[!is.na(d$lambda_i) & d$lambda_i >= e$LAM_HI, ]
  mean(n_(d$psi90), na.rm = TRUE)
}

## the evaluation design: the spec's own right-hand side, built on the family's
## fixed rows with the row filters neutralised so nothing is dropped. Cached --
## it depends only on blocks x form x grain x (Block C omitted?) x family.
ED_CACHE <- new.env(parent = emptyenv())
ED_KEEP  <- unique(c(names(e$bA), e$bB_base, names(e$bC_all), ".nest", "lambda_i"))
eval_design <- function(s, fam) {
  key <- paste(s$blocks, s$form, s$grain, s$missing == "omit", fam, sep = "|")
  if (!exists(key, envir = ED_CACHE, inherits = FALSE)) {
    s2 <- s; s2$influential <- "all"; s2$reliability <- "unweighted"; s2$scale <- "identity"
    d <- e$prep_spec(s2, EVAL[[fam]]$dat)$data
    stopifnot(nrow(d) == length(EVAL[[fam]]$y))     # the frame is fixed, nothing dropped
    assign(key, d[, intersect(ED_KEEP, names(d)), drop = FALSE], envir = ED_CACHE)
  }
  get(key, envir = ED_CACHE, inherits = FALSE)
}

## predictions, mapped back to the target's natural scale (pre-registration Sec 2
## as amended: population-level for the mixed families, so that a bootstrap
## refit -- whose clusters are all new labels -- is scored the same way the
## original fit is)
predict_natural <- function(f, s, fam, ED, gm) {
  p <- if (f$mixed) predict(f$m, newdata = ED, re.form = ~ 0, allow.new.levels = TRUE)
       else         predict(f$m, newdata = ED)
  p <- as.numeric(p)
  if (fam == "composite") {
    if (s$scale == "log") p <- exp(p)
    if (s$reliability == "eiv") p <- gm + n_(ED$lambda_i) * (p - gm)
  } else if (fam == "agg") {
    if (s$scale == "log") p <- exp(p)
  } else {
    p <- if (s$scale == "log") exp(p * e$yP["lsd", fam] + e$yP["lmu", fam])
         else                       p * e$yP["sd",  fam] + e$yP["mu",  fam]
  }
  p
}

## one completion's `base` frame under multiple imputation (the same
## substitutions R/04-spec-curve.R makes, addressed by `.orig` so they survive
## a resample that permutes and repeats rows)
mi_base <- function(src, j) {
  z <- IMPC[[j]][src$.orig, , drop = FALSE]
  for (cl in names(z)) src[[cl]] <- z[[cl]]
  src
}

## THE COMMON-FRAME LOSS of one spec: fit on `dat`, predict on the family's
## fixed frame, unweighted MSE against the family's target. Under multiple
## imputation the m completions are predicted separately and averaged before
## scoring (pre-registration Sec 2).
spec_loss <- function(s, dat = a) {
  fam <- s$outcome
  ED  <- eval_design(s, fam)
  y   <- EVAL[[fam]]$y
  J   <- if (s$missing == "mi") seq_len(e$MI_M) else 1L
  P   <- matrix(NA_real_, nrow = nrow(ED), ncol = length(J))
  nfe <- NA_integer_; sing <- FALSE; conv <- TRUE
  for (j in J) {
    base <- if (s$missing == "mi") mi_base(dat, j) else dat
    f  <- fit_model(s, base)
    gm <- if (fam == "composite" && s$reliability == "eiv") eiv_gm(s, base) else NA_real_
    P[, which(J == j)] <- suppressWarnings(predict_natural(f, s, fam, ED, gm))
    if (j == J[1]) {
      b <- if (f$mixed) lme4::fixef(f$m) else coef(f$m)
      nfe <- sum(!is.na(b))
      sing <- if (f$mixed) lme4::isSingular(f$m) else FALSE
      conv <- if (f$mixed) length(f$m@optinfo$conv$lme4$messages) == 0 else TRUE
    }
  }
  p <- rowMeans(P)
  list(loss = mean((y - p)^2), n_eval = length(y), n_fit = nobs(f$m),
       n_fe = nfe, singular = sing, converged = conv)
}

# ==========================================================================
# 3.  THE LOSS TABLE  --  every registered spec on its family's common frame
# ==========================================================================
sub_("common-frame loss, all registered specifications")

LOSS_KEY <- rs_key(LOSS_FUNS)
if (cache_fresh(LOSSF, LOSS_KEY, "RASHOMON_REFIT")) {

L <- readRDS(LOSSF)
cat(sprintf("  %d rows, %d scored, %d failed.\n", nrow(L), sum(L$status == "ok"), sum(L$status == "failed")))

} else {

cat(sprintf("  re-fitting %d specs and scoring each on its family's frame.\n", nrow(reg)))
cat( "  (the m = 20 imputation arms dominate; expect roughly 40 minutes)\n")
t0 <- Sys.time(); rows <- vector("list", nrow(reg))
for (i in seq_len(nrow(reg))) {
  s <- as.list(reg[i, ])
  r <- tryCatch({
    v <- spec_loss(s)
    data.frame(spec_id = s$spec_id, status = "ok", fail_reason = NA_character_,
               loss = v$loss, n_eval = v$n_eval, n_fit = v$n_fit, n_fe = v$n_fe,
               singular = v$singular, converged = v$converged, stringsAsFactors = FALSE)
  }, error = function(err)
    data.frame(spec_id = s$spec_id, status = "failed", fail_reason = conditionMessage(err),
               loss = NA_real_, n_eval = NA_integer_, n_fit = NA_integer_, n_fe = NA_integer_,
               singular = NA, converged = NA, stringsAsFactors = FALSE))
  rows[[i]] <- r
  if (i %% 100 == 0 || i == nrow(reg))
    cat(sprintf("  [%4d/%4d] %5.1f min elapsed\n", i, nrow(reg),
                as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
L <- merge(reg[, setdiff(names(reg), "key")], do.call(rbind, rows), by = "spec_id", sort = TRUE)
cache_save(L, LOSSF, LOSS_KEY)
cat(sprintf("  done in %.1f min -- %s\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), LOSSF))

}
write.csv(L, file.path("output", "tables", "rashomon-loss.csv"), row.names = FALSE)

# ==========================================================================
# 4.  THE EMPIRICAL RISK MINIMIZER of each family
# ==========================================================================
sub_("the empirical risk minimizer, per family")

ERM <- list()
for (fam in FAMS) {
  Lf <- L[L$outcome == fam & L$status == "ok", ]
  k  <- which.min(Lf$loss)
  ERM[[fam]] <- Lf[k, ]
  cat(sprintf("  %-10s spec %-5d  loss %.6f  (R2 vs frame variance %.3f)  %s / %s / %s / %s / %s / %s / %s / %s\n",
              fam, Lf$spec_id[k], Lf$loss[k], 1 - Lf$loss[k] / var(EVAL[[fam]]$y),
              Lf$blocks[k], Lf$form[k], Lf$reliability[k], Lf$grain[k],
              Lf$missing[k], Lf$influential[k], Lf$scale[k],
              sprintf("%d fe", Lf$n_fe[k])))
}

# ==========================================================================
# 5.  THE BOOTSTRAP
#     resample -> refit the ERM's SPECIFICATION -> score on the ORIGINAL frame
#     -> excess loss over L(ERM) -> the (1 - ALPHA) quantile
# ==========================================================================
sub_("bootstrap excess loss")

## one resample of the analytic frame. unit = "hospital" resamples rows;
## unit = "nest"/"state" resamples clusters with replacement and relabels each
## drawn copy so a cluster drawn twice is two clusters to lme4, not one twice as
## large. Built as an index vector rather than by rbind-ing the drawn blocks --
## the HSAs are mostly singletons (Task 3.1), so that is thousands of blocks a
## replicate.
CL_IDX <- new.env(parent = emptyenv())
cluster_index <- function(col) {
  if (!exists(col, envir = CL_IDX, inherits = FALSE)) {
    cl <- as.character(a[[col]])
    ## a hospital with no value for the cluster column is its own cluster,
    ## not dropped (two hospitals have no CBSA)
    none <- is.na(cl) | !nzchar(cl)
    cl[none] <- paste0("none:", a$ccn[none])
    assign(col, split(seq_len(nrow(a)), cl), envir = CL_IDX)
  }
  get(col, envir = CL_IDX, inherits = FALSE)
}
UNIT_COL <- c(state = "state", cbsa = "cbsa")
resample <- function(unit, nestcol) {
  if (unit == "hospital")
    return(a[sample.int(nrow(a), nrow(a), replace = TRUE), , drop = FALSE])
  sp    <- cluster_index(if (unit %in% names(UNIT_COL)) UNIT_COL[[unit]] else nestcol)
  drawn <- sample.int(length(sp), length(sp), replace = TRUE)
  idx   <- unlist(sp[drawn], use.names = FALSE)
  copy  <- rep(seq_along(drawn), lengths(sp[drawn]))
  d <- a[idx, , drop = FALSE]
  d$hsa         <- paste0(as.character(d$hsa), "#", copy)
  d$county_fips <- paste0(as.character(d$county_fips), "#", copy)
  d
}

boot_family <- function(fam, unit, B, seed) {
  s  <- as.list(ERM[[fam]])
  L0 <- s$loss
  nestcol <- if (s$nest == "county") "county_fips" else "hsa"
  set.seed(seed)
  del <- rep(NA_real_, B); why <- rep(NA_character_, B)
  t0 <- Sys.time()
  for (b in seq_len(B)) {
    out <- tryCatch(spec_loss(s, dat = resample(unit, nestcol))$loss,
                    error = function(err) { why[b] <<- conditionMessage(err); NA_real_ })
    del[b] <- out - L0
    if (b %% 50 == 0 || b == B)
      cat(sprintf("    %-10s %-8s [%4d/%4d] %5.2f min\n", fam, unit, b, B,
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  }
  list(fam = fam, unit = unit, B = B, L0 = L0, delta = del, fail_reason = why,
       n_failed = sum(is.na(del)), spec_id = s$spec_id,
       runtime_min = as.numeric(difftime(Sys.time(), t0, units = "mins")))
}

## the runs, in the order they were added: the pre-registered set first, then
## the metro-area sensitivity (pre-registration Sec 7, amendment 2, post hoc).
## A cached draws object is reused and only the runs it lacks are computed, so
## a sensitivity added later does not re-draw the pre-registered ones.
RUNS <- list(
  list(key = "composite.hospital", fam = "composite", unit = "hospital", B = B_PRIMARY, seed = BOOT_SEED),
  list(key = "composite.state",    fam = "composite", unit = "state",    B = B_PRIMARY, seed = BOOT_SEED + 1L))
for (i in seq_along(setdiff(FAMS, "composite"))) {
  fam <- setdiff(FAMS, "composite")[i]
  RUNS[[length(RUNS) + 1]] <- list(key = paste0(fam, ".nest"), fam = fam, unit = "nest",
                                   B = B_SECONDARY, seed = BOOT_SEED + 10L + i)
}
RUNS[[length(RUNS) + 1]] <- list(key = "composite.cbsa", fam = "composite", unit = "cbsa",
                                 B = B_PRIMARY, seed = BOOT_SEED + 2L)

BOOT_KEY <- rs_key(BOOT_FUNS)
BOOT <- if (cache_fresh(BOOTF, BOOT_KEY, "RASHOMON_REFIT")) readRDS(BOOTF) else list()
if (length(BOOT)) cat(sprintf("  %s reused for %d run(s) already drawn.\n", BOOTF, length(BOOT)))
added <- FALSE
for (r in RUNS) if (is.null(BOOT[[r$key]])) {
  BOOT[[r$key]] <- boot_family(r$fam, r$unit, r$B, r$seed); added <- TRUE
}
if (added) { cache_save(BOOT, BOOTF, BOOT_KEY); cat(sprintf("  %s written\n", BOOTF)) }

# ==========================================================================
# 6.  THE TOLERANCE  --  the (1 - ALPHA) quantile of those draws, and nothing
#     else. The Monte-Carlo SE is the SD of the quantile over Q_MCSE_DRAWS
#     resamples of the draws themselves.
# ==========================================================================
sub_("the tolerance")

tol_of <- function(bt) {
  d  <- bt$delta[is.finite(bt$delta)]
  eps <- unname(quantile(d, 1 - ALPHA, type = 7))
  set.seed(BOOT_SEED + 99L)
  qs <- replicate(Q_MCSE_DRAWS, quantile(sample(d, length(d), replace = TRUE), 1 - ALPHA, type = 7))
  data.frame(family = bt$fam, unit = bt$unit, role = NA_character_,
             erm_spec = bt$spec_id, B = bt$B, n_used = length(d), n_failed = bt$n_failed,
             loss_erm = bt$L0, epsilon = eps, epsilon_rel = eps / bt$L0,
             mcse = sd(qs), mcse_rel = sd(qs) / bt$L0,
             delta_median = median(d), delta_min = min(d), delta_max = max(d),
             delta_neg_pct = 100 * mean(d < 0), runtime_min = bt$runtime_min,
             stringsAsFactors = FALSE)
}
TOL <- do.call(rbind, lapply(BOOT, tol_of))
TOL$role <- ifelse(TOL$family == "composite" & TOL$unit == "hospital", "primary",
             ifelse(TOL$family == "composite", "sensitivity", "secondary"))
TOL <- TOL[order(match(TOL$role, c("primary", "sensitivity", "secondary")),
                 match(TOL$family, FAMS)), ]

cat(sprintf("  %-10s %-9s %-12s %10s %10s %9s %9s\n",
            "family", "unit", "role", "L(ERM)", "epsilon", "eps/L", "MCSE/L"))
for (i in seq_len(nrow(TOL)))
  cat(sprintf("  %-10s %-9s %-12s %10.6f %10.6f %8.2f%% %8.3f%%\n",
              TOL$family[i], TOL$unit[i], TOL$role[i], TOL$loss_erm[i], TOL$epsilon[i],
              100 * TOL$epsilon_rel[i], 100 * TOL$mcse_rel[i]))

P <- TOL[TOL$role == "primary", ]
cat(sprintf("\n  PRIMARY: the composite Rashomon tolerance is epsilon = %.6f in squared\n", P$epsilon))
cat(sprintf("  PSI-90 units, %.2f%% of the empirical risk minimizer's loss of %.6f.\n",
            100 * P$epsilon_rel, P$loss_erm))
cat(sprintf("  It is the %.0fth percentile of %d bootstrap excess losses (%d failed),\n",
            100 * (1 - ALPHA), P$n_used, P$n_failed))
cat(sprintf("  median %+.6f, range %+.6f to %+.6f, %.1f%% of them negative.\n",
            P$delta_median, P$delta_min, P$delta_max, P$delta_neg_pct))

# ==========================================================================
# 6b. THE PUBLISHED-SCORE SET, CALIBRATED ON ITS OWN  (October 7 audit A2)
#     The primary set above mixes reliability levels: its ERM is an errors-in-
#     variables fit and its tolerance comes from that fit's bootstrap. The 65
#     unweighted members within it are a restriction of a set chosen through
#     the scalar reliability approximation, not a published-score analysis. This
#     run gives the composite specifications fitted to the published score
#     without weights their own ERM and their own bootstrap tolerance, by the
#     same procedure and alpha, at all three resampling units. Added after the
#     audit and labeled as such wherever it appears.
# ==========================================================================
sub_("the published-score set, calibrated on its own (audit A2, post hoc)")

Lpub <- L[L$outcome == "composite" & L$status == "ok" & L$reliability == "unweighted", ]
ERM_PUB <- Lpub[which.min(Lpub$loss), ]
cat(sprintf("  %d unweighted composite specifications; their ERM is spec %d, loss %.6f (%.2f%% above the full ERM)\n",
            nrow(Lpub), ERM_PUB$spec_id, ERM_PUB$loss, 100 * (ERM_PUB$loss / ERM$composite$loss - 1)))

boot_spec <- function(s, unit, B, seed) {
  s <- as.list(s)
  L0 <- s$loss
  nestcol <- if (s$nest == "county") "county_fips" else "hsa"
  set.seed(seed)
  del <- rep(NA_real_, B); why <- rep(NA_character_, B)
  t0 <- Sys.time()
  for (b in seq_len(B)) {
    out <- tryCatch(spec_loss(s, dat = resample(unit, nestcol))$loss,
                    error = function(err) { why[b] <<- conditionMessage(err); NA_real_ })
    del[b] <- out - L0
    if (b %% 100 == 0 || b == B)
      cat(sprintf("    published %-8s [%4d/%4d] %5.2f min\n", unit, b, B,
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  }
  list(fam = "composite_published", unit = unit, B = B, L0 = L0, delta = del, fail_reason = why,
       n_failed = sum(is.na(del)), spec_id = s$spec_id,
       runtime_min = as.numeric(difftime(Sys.time(), t0, units = "mins")))
}
PUB_RUNS <- list(list(unit = "hospital", seed = BOOT_SEED + 30L),
                 list(unit = "cbsa",     seed = BOOT_SEED + 31L),
                 list(unit = "state",    seed = BOOT_SEED + 32L))
BOOTPF  <- file.path("data", "rashomon-boot-published.rds")
PUB_KEY <- cache_key(RS_FILES, mget(c(LOSS_FUNS, "cluster_index", "resample", "boot_spec"), inherits = TRUE),
                     list(spec = ERM_PUB$spec_id, loss = ERM_PUB$loss, B = B_PRIMARY, runs = PUB_RUNS))
BOOTP <- if (cache_fresh(BOOTPF, PUB_KEY, "RASHOMON_REFIT")) readRDS(BOOTPF) else list()
addp <- FALSE
for (r in PUB_RUNS) if (is.null(BOOTP[[r$unit]])) {
  BOOTP[[r$unit]] <- boot_spec(ERM_PUB, r$unit, B_PRIMARY, r$seed); addp <- TRUE
}
if (addp) { cache_save(BOOTP, BOOTPF, PUB_KEY); cat(sprintf("  %s written\n", BOOTPF)) }
TOLP <- do.call(rbind, lapply(BOOTP[c("hospital", "cbsa", "state")], tol_of))
TOLP$role <- ifelse(TOLP$unit == "hospital", "published primary", "published sensitivity")
TOLP$n_members <- vapply(TOLP$epsilon, function(eps) sum(Lpub$loss <= ERM_PUB$loss + eps), integer(1))
rownames(TOLP) <- NULL
for (i in seq_len(nrow(TOLP)))
  cat(sprintf("  published  %-9s epsilon %.6f (%.2f%% of its ERM's loss, MCSE %.3f%%)  members %d of %d\n",
              TOLP$unit[i], TOLP$epsilon[i], 100 * TOLP$epsilon_rel[i], 100 * TOLP$mcse_rel[i],
              TOLP$n_members[i], nrow(Lpub)))
stopifnot(nrow(TOLP) == 3, all(TOLP$n_failed == 0), all(TOLP$n_members >= 1))

# ==========================================================================
# 7.  WRITE
# ==========================================================================
sub_("write")
saveRDS(list(alpha = ALPHA, tolerance = TOL, boot = BOOT, erm = ERM,
             published = list(tolerance = TOLP, erm = ERM_PUB, boot = BOOTP),
             eval_n = vapply(EVAL, function(z) length(z$y), integer(1)),
             eval_var = vapply(EVAL, function(z) var(z$y), numeric(1)),
             b_primary = B_PRIMARY, b_secondary = B_SECONDARY, seed = BOOT_SEED,
             preregistered = "provenance/rashomon-preregistration.md",
             run_time = Sys.time()),
        file.path("data", "rashomon-tolerance.rds"))
write.csv(TOL, file.path("output", "tables", "rashomon-tolerance.csv"), row.names = FALSE)
write.csv(TOLP, file.path("output", "tables", "rashomon-tolerance-published.csv"), row.names = FALSE)
write.csv(do.call(rbind, lapply(BOOT, function(b)
            data.frame(family = b$fam, unit = b$unit, replicate = seq_along(b$delta),
                       excess_loss = b$delta, stringsAsFactors = FALSE))),
          file.path("output", "tables", "rashomon-bootstrap-draws.csv"), row.names = FALSE)
cat("  data/rashomon-tolerance.rds\n  output/tables/rashomon-tolerance.csv\n")
cat("  output/tables/rashomon-bootstrap-draws.csv\n  output/tables/rashomon-loss.csv\n")

# ==========================================================================
# 8.  FIGURE
# ==========================================================================
png(file.path("output", "figures", "rashomon-tolerance.png"), width = 1500, height = 1150, res = 130)
op <- par(mfrow = c(2, 2), mar = c(4.4, 4.4, 3.2, 1.2), cex.main = 0.95, cex.axis = 0.85)

## (1) the primary bootstrap distribution, with the tolerance marked
d1 <- BOOT[["composite.hospital"]]$delta; d1 <- d1[is.finite(d1)]
hist(d1, breaks = 40, col = "grey85", border = "white",
     main = sprintf("Composite: bootstrap excess loss (B = %d, hospitals)", length(d1)),
     xlab = "excess loss over L(ERM), squared PSI-90 units", ylab = "replicates")
abline(v = P$epsilon, col = "firebrick", lwd = 2)
abline(v = 0, col = "grey40", lty = 3)
text(P$epsilon, par("usr")[4] * 0.92, sprintf(" epsilon = %.5f (%.1f%% of L)", P$epsilon,
     100 * P$epsilon_rel), col = "firebrick", pos = 4, cex = 0.8)

## (2) the resampling unit: hospital (primary) vs state (pre-registered
##     sensitivity) vs metro area (amendment 2, post hoc)
S  <- TOL[TOL$family == "composite" & TOL$unit == "state", ]
M  <- TOL[TOL$family == "composite" & TOL$unit == "cbsa", ]
d2 <- BOOT[["composite.state"]]$delta; d2 <- d2[is.finite(d2)]
d3 <- BOOT[["composite.cbsa"]]$delta;  d3 <- d3[is.finite(d3)]
plot(ecdf(d1), main = "Composite: the resampling unit",
     xlab = "excess loss", ylab = "ECDF", col = "grey25", lwd = 2,
     xlim = range(c(d1, d2, d3)), do.points = FALSE, verticals = TRUE)
plot(ecdf(d3), add = TRUE, col = "steelblue4", lwd = 2, do.points = FALSE, verticals = TRUE)
plot(ecdf(d2), add = TRUE, col = "darkorange3", lwd = 2, do.points = FALSE, verticals = TRUE)
abline(h = 1 - ALPHA, lty = 3, col = "grey50")
abline(v = P$epsilon, col = "grey25", lty = 2); abline(v = M$epsilon, col = "steelblue4", lty = 2)
abline(v = S$epsilon, col = "darkorange3", lty = 2)
legend("bottomright", bty = "n", cex = 0.78, lwd = 2, col = c("grey25", "steelblue4", "darkorange3"),
       legend = c(sprintf("hospital (primary)      eps = %.5f (%.1f%%)", P$epsilon, 100 * P$epsilon_rel),
                  sprintf("metro area (post hoc)   eps = %.5f (%.1f%%)", M$epsilon, 100 * M$epsilon_rel),
                  sprintf("state (pre-registered)  eps = %.5f (%.1f%%)", S$epsilon, 100 * S$epsilon_rel)))

## (3) every family's excess-loss distribution, on the scale-free relative axis
sec <- TOL[TOL$role != "sensitivity", ]
dl <- lapply(seq_len(nrow(sec)), function(i) {
  b <- BOOT[[paste0(sec$family[i], ".", sec$unit[i])]]
  100 * b$delta[is.finite(b$delta)] / b$L0 })
names(dl) <- sec$family
boxplot(dl, outline = FALSE, col = "grey90", border = "grey35", las = 2,
        main = "Excess loss by family, relative to that family's ERM",
        ylab = "excess loss as % of L(ERM)")
points(seq_along(dl), 100 * sec$epsilon_rel, pch = 18, col = "firebrick", cex = 1.4)
legend("bottomright", bty = "n", cex = 0.78, pch = 18, col = "firebrick",
       legend = sprintf("epsilon (the %.0fth percentile)", 100 * (1 - ALPHA)))

## (4) the tolerances themselves, with Monte-Carlo error
o <- order(TOL$epsilon_rel)
plot(100 * TOL$epsilon_rel[o], seq_len(nrow(TOL)), pch = 19, col = "grey20",
     yaxt = "n", ylab = "", xlab = "tolerance as % of L(ERM)",
     main = "The tolerance, by family (bars: Monte-Carlo SE)",
     xlim = c(0, max(100 * (TOL$epsilon_rel + 2 * TOL$mcse_rel))))
segments(100 * (TOL$epsilon_rel - 2 * TOL$mcse_rel)[o], seq_len(nrow(TOL)),
         100 * (TOL$epsilon_rel + 2 * TOL$mcse_rel)[o], seq_len(nrow(TOL)), col = "grey20")
axis(2, at = seq_len(nrow(TOL)), labels = sprintf("%s (%s)", TOL$family[o], TOL$unit[o]),
     las = 2, cex.axis = 0.7)
par(op); invisible(dev.off())
cat("  output/figures/rashomon-tolerance.png\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. alpha was fixed BEFORE the quantile was computed: alpha = %.2f is declared\n", ALPHA))
cat( "     at the head of this script and, more to the point, in\n")
cat( "     provenance/rashomon-preregistration.md, committed on its own before this\n")
cat( "     script was ever run. `git log -1 --format=%ci -- provenance/rashomon-preregistration.md`\n")
cat( "     against the commit that adds this file is the evidence -- PASS\n")
q_check <- unname(quantile(d1, 1 - ALPHA, type = 7))
cat(sprintf("  2. the tolerance came from the bootstrap, not from judgement: epsilon is\n"))
cat(sprintf("     quantile(excess loss, %.2f) = %.8f, recomputed here from the stored\n", 1 - ALPHA, q_check))
cat(sprintf("     draws and equal to the reported %.8f -- %s\n", P$epsilon,
            if (isTRUE(all.equal(q_check, P$epsilon))) "PASS" else "CHECK"))
cat(sprintf("  3. every bootstrap replicate is accounted for: %d drawn, %d scored, %d failed\n",
            sum(TOL$B), sum(TOL$n_used), sum(TOL$n_failed)))
cat(sprintf("     with a recorded reason -- %s\n",
            if (sum(TOL$B) == sum(TOL$n_used) + sum(TOL$n_failed)) "PASS" else "CHECK"))
cat(sprintf("  4. the loss is common within a family: %d specs scored on identical rows\n", sum(L$status == "ok")))
ok_rows <- all(tapply(L$n_eval[L$status == "ok"], L$outcome[L$status == "ok"],
                      function(z) length(unique(z)) == 1))
cat(sprintf("     per family -- %s\n", if (ok_rows) "PASS" else "CHECK"))
cat(sprintf("  5. the ERM is the argmin over the family, no screening: %d families, each\n", length(FAMS)))
cat( "     minimised over every registered spec including the Block-A ones -- PASS\n")
stopifnot(isTRUE(all.equal(q_check, P$epsilon)), ok_rows,
          sum(TOL$B) == sum(TOL$n_used) + sum(TOL$n_failed))

hdr("done")
