# R/06-mcr.R  --  Task 3.11, model class reliance: the implementation and its
# validation. Task 3.12 runs it on the real set; this file establishes that it
# is correct first.
#
# MODEL RELIANCE (Fisher, Rudin and Dominici 2019, "All Models are Wrong, but
# Many are Useful", JMLR 20(177)). For a model f and a variable or group of
# variables X1, model reliance is the ratio of the loss when X1 is scrambled to
# the loss when it is not:
#
#     MR(f) = e_switch(f) / e_orig(f)
#
# with the SWITCH estimator averaging over every ordered pair of observations
# rather than over random permutations:
#
#     e_switch(f) = 1/(n(n-1)) * sum_{i != j} L( f(x1_j, x2_i), y_i )
#
# MR = 1 means the model's loss is unchanged when X1 is scrambled, so the model
# does not rely on X1 at all. MR > 1 means scrambling X1 costs fit.
#
# MODEL CLASS RELIANCE is the range of MR over a Rashomon set:
#
#     MCR-(eps) = min MR(f),   MCR+(eps) = max MR(f)   over f in R(eps)
#
# MCR- > 1 is the claim worth having (Plan Sec 6): no near-optimal model can
# ignore this variable. Here R(eps) is the finite set Task 3.10 constructed, so
# these are bounds over an ENUMERATED class, which matters for how the claim is
# stated -- see the note in Sec 4 and `provenance/task3.11-mcr.md`.
#
# WHY NO PERMUTATIONS ARE DRAWN. Every back-transform in this project puts the
# permuted prediction in one shape,
#
#     p_{i<-j} = B_i + C_i * V_j
#
# with B_i and C_i built from row i and V_j from row j alone: identity-scale
# fits give C_i = 1 and V_j = the permuted columns' linear predictor; the
# errors-in-variables arm's re-shrinking gives C_i = lambda_i; a log-scale fit
# gives C_i = exp(a_i) and V_j = exp(v_j), since exp(a_i + v_j) factors; a
# component fit's un-z-scoring is affine and folds into B and C. The double sum
# over ordered pairs then collapses to sums over i and over j separately, so
# e_switch is EXACT in O(n) rather than approximated by sampling permutations.
# Multiple imputation averages m predictions before the loss is taken, which
# leaves an m x m cross-product matrix in the quadratic term and is likewise
# exact. Sec 2 checks the closed form against brute force over all ordered
# pairs, and against a Monte-Carlo permutation estimator written separately.
#
# ORDER OF THIS FILE. Section 2 validates. Section 3 builds the machinery for
# real specifications. Section 4 runs it on a handful of them. The validation
# runs FIRST and halts the stage on failure, which is Task 3.11's verify
# condition: the implementation reproduces hand-computable answers before it is
# trusted on the data.
#
# Outputs: R/06-mcr.R, output/tables/mcr-validation.csv,
# output/tables/mcr-smoke.csv.

suppressMessages({ library(lme4); library(splines) })

n_   <- function(x) suppressWarnings(as.numeric(x))
hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
TOLNUM <- 1e-9

hdr("TASK 3.11  model class reliance -- implementation and validation")

# ==========================================================================
# 1.  THE ESTIMATOR
# ==========================================================================
## Both `Cm` and `Vm` are n x m matrices, one column per imputation completion
## (m = 1 for everything else). The prediction for row i, taking the permuted
## block from row j, is B_i + mean_m( Cm[i,m] * Vm[j,m] ).
switch_loss <- function(y, B, Cm, Vm) {
  Cm <- as.matrix(Cm); Vm <- as.matrix(Vm)
  stopifnot(length(y) == length(B), nrow(Cm) == length(y), dim(Cm) == dim(Vm))
  n <- length(y); m <- ncol(Cm)
  d      <- y - B                      # what the un-permuted block has to explain
  p_self <- rowMeans(Cm * Vm)          # its own contribution, averaged over completions
  S1 <- colSums(Vm)                    # m-vector
  S2 <- crossprod(Vm)                  # m x m
  tot <- n * sum(d^2) -
         (2 / m) * sum(d * (Cm %*% S1)) +
         (1 / m^2) * sum(rowSums((Cm %*% S2) * Cm))
  diag_term <- sum((d - p_self)^2)
  list(e_orig   = diag_term / n,
       e_switch = (tot - diag_term) / (n * (n - 1)),
       n = n, m = m)
}
model_reliance <- function(y, B, Cm, Vm) {
  z <- switch_loss(y, B, Cm, Vm); z$mr <- z$e_switch / z$e_orig; z
}

## the same quantity computed the slow, obvious way -- every ordered pair
switch_loss_bruteforce <- function(y, B, Cm, Vm) {
  Cm <- as.matrix(Cm); Vm <- as.matrix(Vm); n <- length(y); tot <- 0
  for (i in seq_len(n)) for (j in seq_len(n)) if (i != j)
    tot <- tot + (y[i] - B[i] - mean(Cm[i, ] * Vm[j, ]))^2
  list(e_orig = mean((y - B - rowMeans(Cm * Vm))^2), e_switch = tot / (n * (n - 1)))
}

## and a third way: sample permutations, the estimator most implementations use
switch_loss_montecarlo <- function(y, B, Cm, Vm, R = 4000, seed = 1) {
  Cm <- as.matrix(Cm); Vm <- as.matrix(Vm); n <- length(y); set.seed(seed)
  v <- replicate(R, {
    k <- sample.int(n); ok <- k != seq_len(n)
    mean((y[ok] - B[ok] - rowMeans(Cm[ok, , drop = FALSE] * Vm[k[ok], , drop = FALSE]))^2)
  })
  mean(v)
}

# ==========================================================================
# 2.  VALIDATION  --  before the implementation touches the project's data
# ==========================================================================
hdr("VALIDATION  (Task 3.11 verify: a known answer, reproduced, first)")
V <- list(); chk <- function(name, got, want, tol = TOLNUM, note = "") {
  ok <- is.finite(got) && is.finite(want) && abs(got - want) <= tol
  V[[length(V) + 1]] <<- data.frame(check = name, got = got, want = want,
                                    abs_diff = abs(got - want), tol = tol,
                                    pass = ok, note = note, stringsAsFactors = FALSE)
  cat(sprintf("  %-46s got %14.9f  want %14.9f  %s\n", name, got, want, if (ok) "PASS" else "FAIL"))
  ok
}

sub_("1. a hand-computable case, worked on paper")
y <- c(1, 2, 3, 6); Bt <- rep(0, 4); Ct <- matrix(1, 4, 1); Vt <- matrix(c(1, 2, 3, 4), 4, 1)
cat("  y = (1, 2, 3, 6); the permuted block contributes v = (1, 2, 3, 4); B = 0, C = 1.\n")
cat("  e_orig  = mean((y - v)^2) = mean(0, 0, 0, 4) = 1.\n")
cat("  sum_i sum_j (y_i - v_j)^2 = n*sum(y^2) - 2*sum(y)*sum(v) + n*sum(v^2)\n")
cat("                            = 4(50) - 2(12)(10) + 4(30) = 200 - 240 + 120 = 80.\n")
cat("  the i = j terms are sum((y - v)^2) = 4, so sum_{i != j} = 80 - 4 = 76,\n")
cat("  e_switch = 76 / (4*3) = 19/3, and MR = (19/3) / 1 = 19/3 = 6.333333333.\n")
z <- model_reliance(y, Bt, Ct, Vt)
chk("hand case: e_orig", z$e_orig, 1)
chk("hand case: e_switch", z$e_switch, 19 / 3)
chk("hand case: MR", z$mr, 19 / 3)
chk("hand case: brute force agrees", switch_loss_bruteforce(y, Bt, Ct, Vt)$e_switch, 19 / 3)

sub_("2. closed form against brute force over all ordered pairs")
set.seed(3011)
rnd <- function(n) list(y = rnorm(n), B = rnorm(n), C = matrix(rnorm(n), n, 1), V = matrix(rnorm(n), n, 1))
g <- rnd(40)
chk("additive, C = 1: brute force",
    model_reliance(g$y, g$B, matrix(1, 40, 1), g$V)$e_switch,
    switch_loss_bruteforce(g$y, g$B, matrix(1, 40, 1), g$V)$e_switch)
chk("row-varying C (the EIV re-shrink): brute force",
    model_reliance(g$y, g$B, g$C, g$V)$e_switch,
    switch_loss_bruteforce(g$y, g$B, g$C, g$V)$e_switch)
lg <- list(y = exp(rnorm(40)), B = rep(0, 40), C = matrix(exp(rnorm(40)), 40, 1), V = matrix(exp(rnorm(40)), 40, 1))
chk("multiplicative (a log-scale fit): brute force",
    model_reliance(lg$y, lg$B, lg$C, lg$V)$e_switch,
    switch_loss_bruteforce(lg$y, lg$B, lg$C, lg$V)$e_switch)
mi <- list(y = rnorm(30), B = rnorm(30), C = matrix(rnorm(150), 30, 5), V = matrix(rnorm(150), 30, 5))
chk("m = 5 completions averaged: brute force",
    model_reliance(mi$y, mi$B, mi$C, mi$V)$e_switch,
    switch_loss_bruteforce(mi$y, mi$B, mi$C, mi$V)$e_switch)

sub_("3. a variable the model does not use has MR exactly 1")
z0 <- model_reliance(g$y, g$B, g$C, matrix(0, 40, 1))
chk("zero coefficient: MR", z0$mr, 1)
zc <- model_reliance(g$y, g$B, g$C, matrix(2.5, 40, 1))
chk("constant contribution: MR", zc$mr, 1)

sub_("4. a population value known in closed form")
## y = x + e with Var(x) = Var(e) = 1 and the model fitted correctly. Writing
## r = y - (everything but x) = y and u = x, e_orig = Var(e) = 1 and
## e_switch = e_orig + 2*Cov(r, u) = 1 + 2*Var(x) = 3, so MR -> 3.
set.seed(11)
N <- 400000; x <- rnorm(N); yy <- x + rnorm(N)
b <- coef(lm(yy ~ x))
zs <- model_reliance(yy, rep(b[1], N), matrix(1, N, 1), matrix(b[2] * x, N, 1))
chk("y = x + e, Var(x) = Var(e) = 1: MR -> 3", zs$mr, 3, tol = 0.02, note = "n = 4e5")

## and the general identity for an orthogonal design:
##   MR = 1 + 2 * beta1^2 * Var(X1) / e_orig
set.seed(12)
N <- 200000; x1 <- rnorm(N, sd = 2); x2 <- rnorm(N); yy <- 0.7 * x1 - 1.3 * x2 + rnorm(N, sd = 1.5)
fit <- lm(yy ~ x1 + x2); bb <- coef(fit)
eo <- mean(residuals(fit)^2)
want <- 1 + 2 * bb[["x1"]]^2 * var(x1) * (N - 1) / N / eo
zo <- model_reliance(yy, bb[1] + bb[["x2"]] * x2, matrix(1, N, 1), matrix(bb[["x1"]] * x1, N, 1))
chk("orthogonal design: MR = 1 + 2 b1^2 Var(X1) / e_orig", zo$mr, want, tol = 1e-4)

sub_("5. the closed form against a Monte-Carlo permutation estimator")
mc <- switch_loss_montecarlo(g$y, g$B, matrix(1, 40, 1), g$V, R = 20000)
chk("sampled permutations converge to the closed form",
    model_reliance(g$y, g$B, matrix(1, 40, 1), g$V)$e_switch, mc, tol = 0.02,
    note = "R = 20000 draws")

sub_("6. structural properties")
chk("MR is invariant to rescaling the loss", model_reliance(2 * y, 2 * Bt, Ct, 2 * Vt)$mr, z$mr)
chk("permuting a block of zero width leaves the loss alone",
    switch_loss(g$y, g$B, g$C, matrix(0, 40, 1))$e_switch,
    switch_loss(g$y, g$B, g$C, matrix(0, 40, 1))$e_orig)

VAL <- do.call(rbind, V)
write.csv(VAL, file.path("output", "tables", "mcr-validation.csv"), row.names = FALSE)
cat(sprintf("\n  %d checks, %d passed, %d failed -> output/tables/mcr-validation.csv\n",
            nrow(VAL), sum(VAL$pass), sum(!VAL$pass)))
if (!all(VAL$pass)) stop("MCR validation failed; the implementation is not trusted on real data")
cat("  the implementation is validated. Only now does it read the project's data.\n")

# ==========================================================================
# 3.  THE MACHINERY FOR A REAL SPECIFICATION
# ==========================================================================
hdr("the machinery, on real specifications")

e <- new.env()
local({ tf <- tempfile(); sink(tf)
        sys.source(file.path("R", "04-spec-curve.R"), envir = e)
        sink(); unlink(tf) })
a   <- readRDS(file.path("data", "analytic-v2.rds"))
imp <- readRDS(file.path("data", "blockC_mice.rds"))
LOS <- readRDS(file.path("data", "rashomon-loss.rds"))
SET <- readRDS(file.path("data", "rashomon-set.rds"))
reg <- readRDS(file.path("data", "spec-registry.rds"))
a$.orig <- seq_len(nrow(a))
IMPC <- lapply(seq_len(e$MI_M), function(j) {
  cd <- mice::complete(imp, j)
  data.frame(contract_labor_share = cd$cl_share, beds = exp(cd$log_beds),
             volume_bills = exp(cd$log_vol), wage_index = cd$wage_index,
             cmi = cd$cmi, dsh_pct = cd$dsh_pct, occupancy = cd$occupancy,
             teaching = cd$teaching)
})
mi_base <- function(src, j) { z <- IMPC[[j]][src$.orig, , drop = FALSE]
  for (cl in names(z)) src[[cl]] <- z[[cl]]; src }

## The evaluation frame, rebuilt to Task 3.9's definition. Sec 5 asserts that
## the loss recomputed here equals the stored loss to machine precision, which
## is what guarantees this frame is that frame and not a drifted copy.
fin <- function(cl) is.finite(n_(a[[cl]]))
okA <- Reduce(`&`, lapply(setdiff(names(e$bA), "teaching"), function(k) fin(e$bA[[k]]))) & is.finite(n_(a$teaching))
bcols <- unique(unlist(lapply(names(e$SUFFIX), function(g) vapply(e$bB_base, e$bcol, character(1), grain = g))))
okB <- Reduce(`&`, lapply(bcols, fin))
okC <- Reduce(`&`, lapply(names(e$bC_all), function(k) fin(e$bC_all[[k]])))
okN <- !is.na(a$county_fips) & nzchar(as.character(a$county_fips)) & !is.na(a$hsa) & nzchar(as.character(a$hsa))
KEEP <- okA & okB & okC & okN & is.finite(n_(a$psi90)) & is.finite(n_(a$lambda_i)) & n_(a$lambda_i) > 0
AE   <- a[KEEP, , drop = FALSE]
Y    <- n_(AE$psi90); LAM <- n_(AE$lambda_i)
cat(sprintf("  composite evaluation frame rebuilt: n = %d (Task 3.9 had 2569)\n", nrow(AE)))

eiv_gm <- function(s, base) {
  d <- base
  if (s$influential == "drop_fn2329")        d <- d[!(d$fn_claims_discrepancy | d$fn_partial_window), ]
  else if (s$influential == "drop_fallback") d <- d[d$catch_source != "county_fallback", ]
  if (s$reliability == "subsample")          d <- d[!is.na(d$lambda_i) & d$lambda_i >= e$LAM_HI, ]
  mean(n_(d$psi90), na.rm = TRUE)
}

## fit one completion and return the evaluation-frame design matrix, the
## coefficients, and the pieces of the back-transform
spec_pieces <- function(s, base) {
  pp <- e$prep_spec(s, base)
  fe <- paste(c(pp$feA, pp$feB, pp$feC), collapse = " + ")
  m  <- if (pp$mixed)
    lmer(as.formula(sprintf(".y ~ %s + (1 | .nest)", fe)), data = pp$data,
         weights = if (s$reliability == "unweighted") rep(1, nrow(pp$data)) else pp$data$.w,
         REML = TRUE, control = e$ctrl)
  else lm(as.formula(sprintf(".y ~ %s", fe)), data = pp$data, weights = pp$data$.w)
  s2 <- s; s2$influential <- "all"; s2$reliability <- "unweighted"; s2$scale <- "identity"
  ED <- e$prep_spec(s2, AE)$data
  stopifnot(nrow(ED) == nrow(AE))
  fe_terms <- terms(as.formula(sprintf("~ %s", fe)), data = pp$data)
  X <- model.matrix(fe_terms, ED)
  b <- if (pp$mixed) lme4::fixef(m) else coef(m)
  b <- b[colnames(X)]; b[is.na(b)] <- 0          # rank-deficient columns contribute nothing
  list(X = X, b = b, bUse = pp$bUse, feB = pp$feB, gm = eiv_gm(s, base))
}

## which design-matrix columns belong to a Block B measure (the linear column,
## or every column of its spline basis) -- the same match R/04-spec-curve.R
## uses to pull single-measure contrasts out of the contrast vector
cols_for <- function(X, vars) {
  idx <- integer(0)
  for (v in vars) idx <- c(idx, grep(sprintf("^(ns\\(%s,|%s$)", v, v), colnames(X)))
  sort(unique(idx))
}

## MR of one specification for one group of variables, on the common-frame loss
mr_spec <- function(s, vars) {
  J <- if (s$missing == "mi") seq_len(e$MI_M) else 1L
  n <- nrow(AE); Cm <- Vm <- matrix(NA_real_, n, length(J)); Bm <- matrix(NA_real_, n, length(J))
  n_cols <- 0L
  for (jj in seq_along(J)) {
    P  <- spec_pieces(s, if (s$missing == "mi") mi_base(a, J[jj]) else a)
    cl <- cols_for(P$X, vars)
    ## a spec that carries none of these columns (a Block-A spec asked about
    ## Block B) does not rely on them at all: MR is exactly 1 by definition
    if (!length(cl)) return(list(mr = 1, e_orig = NA_real_, e_switch = NA_real_, n_cols = 0L))
    n_cols <- length(cl)
    eta_v <- as.numeric(P$X[, cl, drop = FALSE] %*% P$b[cl])      # the permuted block
    eta_a <- as.numeric(P$X %*% P$b) - eta_v                      # everything else
    ## p_{i<-j} = B_i + C_i * V_j, per the back-transform (header, and
    ## pre-registration Sec 2 for the transforms themselves)
    if (s$scale == "log") {
      if (s$reliability == "eiv") { B <- P$gm * (1 - LAM); C <- LAM * exp(eta_a) }
      else                        { B <- rep(0, n);        C <- exp(eta_a) }
      Vv <- exp(eta_v)
    } else {
      if (s$reliability == "eiv") { B <- P$gm + LAM * (eta_a - P$gm); C <- LAM }
      else                        { B <- eta_a;                       C <- rep(1, n) }
      Vv <- eta_v
    }
    Bm[, jj] <- B; Cm[, jj] <- C; Vm[, jj] <- Vv
  }
  z <- model_reliance(Y, rowMeans(Bm), Cm, Vm)
  z$n_cols <- n_cols; z
}

## MCR over a set of specifications, per variable group
mcr_over_set <- function(spec_ids, groups, label = "") {
  out <- list(); per_model <- list()
  for (gname in names(groups)) {
    mrs <- rep(NA_real_, length(spec_ids))
    for (k in seq_along(spec_ids)) {
      s <- as.list(reg[reg$spec_id == spec_ids[k], ])
      mrs[k] <- mr_spec(s, groups[[gname]])$mr
    }
    ok <- is.finite(mrs)
    per_model[[gname]] <- data.frame(group = gname, spec_id = spec_ids, mr = mrs,
                                     stringsAsFactors = FALSE)
    out[[gname]] <- data.frame(
      set = label, group = gname, n_models = sum(ok),
      mcr_minus = min(mrs[ok]), mcr_plus = max(mrs[ok]),
      spec_at_minus = spec_ids[ok][which.min(mrs[ok])],
      spec_at_plus  = spec_ids[ok][which.max(mrs[ok])],
      mr_median = median(mrs[ok]),
      share_above_one = mean(mrs[ok] > 1), stringsAsFactors = FALSE)
  }
  list(table = do.call(rbind, out), per_model = do.call(rbind, per_model))
}

# ==========================================================================
# 4.  A SMOKE RUN  --  end to end on a few members of the real set
#     (Task 3.12 runs the whole set; this only shows the machinery works)
# ==========================================================================
sub_("smoke run: MR on a spanning handful of the primary set")
ids <- SET$primary$spec_ids
d   <- SET$sets[["composite.hospital"]]$d
pick <- unique(c(d$spec_id[d$in_set][which.min(d$loss[d$in_set])],
                 head(d$spec_id[d$in_set & d$form == "linear"], 2),
                 head(d$spec_id[d$in_set & d$grain == "catch_tract"], 2),
                 head(d$spec_id[d$in_set & d$grain == "catch_county"], 2),
                 head(d$spec_id[d$in_set & d$scale == "log"], 1),
                 head(d$spec_id[d$in_set & d$missing == "mi"], 1)))
GROUPS <- list(disadvantage_block = names(e$DIS_SIGN), adi = "adi", svi3 = "svi3", ice150 = "ice150")
rows <- list()
for (sid in pick) {
  s <- as.list(reg[reg$spec_id == sid, ])
  r <- mr_spec(s, GROUPS$disadvantage_block)
  a_ <- mr_spec(s, "adi")
  rows[[length(rows) + 1]] <- data.frame(
    spec_id = sid, form = s$form, reliability = s$reliability, grain = s$grain,
    missing = s$missing, scale = s$scale,
    stored_loss = LOS$loss[LOS$spec_id == sid], e_orig = r$e_orig,
    mr_block = r$mr, mr_adi = a_$mr, stringsAsFactors = FALSE)
  cat(sprintf("  spec %-5d %-6s %-10s %-12s %-8s %-8s  e_orig %.6f  MR(block) %.4f  MR(adi) %.4f\n",
              sid, s$form, s$reliability, s$grain, s$missing, s$scale,
              r$e_orig, r$mr, a_$mr))
}
SM <- do.call(rbind, rows)
SM$loss_matches_stored <- abs(SM$e_orig - SM$stored_loss) < 1e-10
write.csv(SM, file.path("output", "tables", "mcr-smoke.csv"), row.names = FALSE)
cat(sprintf("\n  e_orig equals the stored common-frame loss for %d of %d specs\n",
            sum(SM$loss_matches_stored), nrow(SM)))

sub_("mcr_over_set() on the same handful")
M <- mcr_over_set(pick, GROUPS["disadvantage_block"], label = "smoke (not the full set)")
print(M$table, row.names = FALSE)
cat("\n  Task 3.12 runs this over all 194 members and the Block A covariates.\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. the implementation reproduces a hand-computable answer BEFORE it reads\n"))
cat(sprintf("     the project's data: MR = 19/3 on the worked example, the arithmetic\n"))
cat(sprintf("     printed above, and %d checks pass in total -- PASS\n", nrow(VAL)))
cat(sprintf("  2. the closed form agrees with brute force over all n(n-1) ordered pairs\n"))
cat(sprintf("     in the additive, row-scaled, multiplicative and m = 5 cases, to %.0e -- PASS\n", TOLNUM))
cat(sprintf("  3. a variable the model does not use returns MR exactly 1 -- PASS\n"))
cat(sprintf("  4. a population case with a known answer is recovered: y = x + e with\n"))
cat(sprintf("     unit variances gives MR -> 3 -- PASS\n"))
cat(sprintf("  5. the loss underlying MR is the loss that defined the set: e_orig equals\n"))
cat(sprintf("     data/rashomon-loss.rds for %d of %d smoke specs -- %s\n",
            sum(SM$loss_matches_stored), nrow(SM), if (all(SM$loss_matches_stored)) "PASS" else "CHECK"))
stopifnot(all(VAL$pass), all(SM$loss_matches_stored), nrow(AE) == 2569)
hdr("done")
