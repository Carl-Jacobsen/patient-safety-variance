# R/07-tis.R  --  Task 3.13, the TIS decomposition: implementation and tests.
# Task 3.14 runs it on the Rashomon set; this file establishes it is correct.
#
# WHAT TIS IS. Total Influence Score, from the project's own prior work rather
# than from the published literature: `Rashomon/Spring 26/docs/
# decomposition_algorithm.docx` (derivation), `mcr_formula_reference.docx` (the
# quantities), and `Rashomon/Spring 26/correlated_signals/
# mcr_correlated_signals.Rmd` Sec 9 (the metric). Plan Sec 6 asks for it because
# Task 3.1 measured the Block B collinearity, so a marginal importance number
# credits a measure for variation it merely shares with its neighbors.
#
# The decomposition splits a variable's model reliance into a DIRECT part and a
# SHARED part:
#
#     MR_marginal_j  =  MR_direct_j  +  Delta_j
#
# MR_marginal permutes X_j outright, which destroys both the variation unique to
# X_j and the variation X_j shares with its neighbors. MR_direct permutes only
# e_j, the residual of X_j regressed on the other measures -- the part of X_j
# that cannot be reconstructed from them -- holding the reconstructable part
# fixed. Delta_j is what the difference measures: the inflation X_j's reliance
# gets from its correlations. Delta_j = 0 when X_j is orthogonal to everything
# else in the model.
#
# Delta_j then splits across the neighbors by the OLS projection identity
# Var(Xhat_j) = sum_k alpha_k Cov(X_k, X_j):
#
#     Delta_j^(k)  =  Delta_j * alpha_k Cov(X_k, X_j) / Var(Xhat_j),
#     and  sum_{k != j} Delta_j^(k)  =  Delta_j  exactly.
#
# Collected over all pairs this is the FLOW MATRIX F[j, k] = Delta_j^(k): how
# much of measure j's apparent importance is on loan from measure k. Finally
#
#     TIS(k)  =  MCR+_direct(k)  +  sum_{j != k} max(F[j, k], 0)
#
# -- what k earns on its own account, plus the credit it earns as a SENDER, for
# the inflation it lends to everyone else. A pure-noise variable scores about 1.
# A noise variable correlated with a real signal gets a small sender term and no
# direct term, so it ranks below any true signal: that is exactly the
# distinction Task 3.14's verify condition asks for, between covariates no
# near-optimal model can ignore and covariates merely correlated with something
# consequential.
#
# TWO DEPARTURES FROM THE PRIOR CODE, both deliberate and both tested in Sec 2.
# (1) The prior implementation's conditional expectation uses
# e_j^2 (n-2)/(n-1) + ||e_j||^2/(n-1); the exact all-pairs value is
# e_j^2 n/(n-1) + ||e_j||^2/(n-1). Check 5 compares both against brute force
# over every ordered pair. The difference is O(1/n) and immaterial at n = 2569,
# but this file uses the exact form, which is the one Task 3.11's estimator was
# brute-force validated against.
# (2) The prior code assumes a scalar beta_j x_ij term. Half this project's
# specifications spline the disadvantage measures, so everything here works in
# CONTRIBUTION space -- v_j = X[, cols(j)] %*% beta[cols(j)], the measure's
# total contribution to the linear predictor -- which handles a spline basis
# whole and reduces exactly to the prior formulas when a measure has one
# column. Check 9 verifies that reduction numerically.
#
# TASK S1.1 (2026-10-02). The September 30 decompose_model() gave every measure
# the same fixed part -- everything except the ten measures -- so each measure
# was permuted inside a model missing the other nine, and its reliance was not
# the model's (review of 2026-10-01, P0). fixed_part() now builds the full model
# minus that one measure. The checks that would have caught it are 3 (by-hand
# full-minus-one), 8 (a real proxy, replacing an independent signal mislabelled
# as one) and 8b (two independent predictors, MR near 3); 8b is also run on the
# September 30 code, kept as decompose_model_sep30(), and must fail there.
#
# ORDER OF THIS FILE. Section 2 validates, including a synthetic case whose
# shared structure is known in closed form, and halts on failure. Section 3
# touches the project's data. That order is Task 3.13's verify condition.
#
# Outputs: R/07-tis.R, output/tables/tis-validation.csv, output/tables/tis-smoke.csv.

suppressMessages({ library(lme4); library(splines) })

q <- new.env()
local({ tf <- tempfile(); sink(tf); sys.source(file.path("R", "06-mcr.R"), envir = q); sink(); unlink(tf) })
for (f in c("n_", "hdr", "sub_", "switch_loss", "model_reliance", "switch_loss_bruteforce",
            "spec_pieces", "cols_for", "mi_base", "eiv_gm"))
  assign(f, get(f, envir = q))
e <- q$e; a <- q$a; AE <- q$AE; Y <- q$Y; LAM <- q$LAM
TOLNUM <- 1e-9

hdr("TASK 3.13  the TIS decomposition -- implementation and tests")
cat(sprintf("  the MCR implementation's %d checks re-ran on load: %s\n",
            nrow(q$VAL), if (all(q$VAL$pass)) "all pass" else "FAILURES"))
stopifnot(all(q$VAL$pass))

# ==========================================================================
# 1.  THE ESTIMATOR
# ==========================================================================
## regress one measure's contribution on the others' -> the reconstructable
## part, the unique part, and the neighbor coefficients
residualize <- function(Vmat, j) {
  target <- Vmat[, j]; others <- Vmat[, -j, drop = FALSE]
  design <- cbind(1, others)
  cf <- tryCatch(as.vector(solve(crossprod(design), crossprod(design, target))),
                 error = function(err) as.vector(MASS::ginv(design) %*% target))
  fit <- as.vector(design %*% cf); res <- target - fit
  sst <- sum((target - mean(target))^2)
  list(fitted = fit, residuals = res, alpha = cf[-1],
       r_squared = if (sst > 0) 1 - sum(res^2) / sst else 0)
}

## MR when only the unique part is permuted. The conditionally permuted
## prediction is B_i + C_i*(vhat_i + etilde_j), which is the same
## B + C * V shape Task 3.11 solves exactly, with vhat folded into B.
mr_direct <- function(Y, B, Cm, Vhat, Etil)
  model_reliance(Y, B + Cm[, 1] * Vhat, Cm, matrix(Etil, ncol = 1))

## the full decomposition for one measure of one model
decompose_one <- function(Y, B, Cvec, Vmat, j) {
  Cm <- matrix(Cvec, ncol = 1)
  marg <- model_reliance(Y, B, Cm, matrix(Vmat[, j], ncol = 1))
  info <- residualize(Vmat, j)
  dir  <- mr_direct(Y, B, Cm, info$fitted, info$residuals)
  delta <- marg$mr - dir$mr
  ## split Delta across neighbors by the OLS projection identity
  other <- setdiff(seq_len(ncol(Vmat)), j)
  vj <- Vmat[, j]
  cov_terms <- vapply(seq_along(other), function(ix)
    info$alpha[ix] * mean((Vmat[, other[ix]] - mean(Vmat[, other[ix]])) * (vj - mean(vj))),
    numeric(1))
  tot <- sum(cov_terms)
  contrib <- setNames(rep(0, ncol(Vmat)), colnames(Vmat))
  if (abs(tot) > .Machine$double.eps && abs(delta) > .Machine$double.eps)
    contrib[other] <- delta * cov_terms / tot
  list(mr_marginal = marg$mr, mr_direct = dir$mr, delta = delta,
       contributions = contrib, r_squared = info$r_squared, e_orig = marg$e_orig)
}

## Task S1.1: the fixed part for measure j is the FULL model minus that one
## measure. B0 and C0 carry everything except the p measures; the other p - 1
## contributions join the sum on the identity scale (B0 + C0 * sum_{k != j} v_k)
## and the multiplicative factor on the log scale (C0 * prod_{k != j} V_k, where
## V = exp(v)). The September 30 code used B0 and C0 alone for every j, so each
## measure was permuted inside a model that had lost the other nine.
fixed_part <- function(B0, C0, Vmat, j, mult = FALSE) {
  n <- nrow(Vmat); B0 <- rep_len(B0, n); C0 <- rep_len(C0, n)
  rest <- Vmat[, -j, drop = FALSE]
  if (mult) list(B = B0, C = C0 * apply(rest, 1, prod))
  else      list(B = B0 + C0 * rowSums(rest), C = C0)
}

## every measure of one model: the flow matrix and the per-measure summary
decompose_model <- function(Y, B0, C0, Vmat, mult = FALSE) {
  p <- ncol(Vmat); nm <- colnames(Vmat)
  F <- matrix(0, p, p, dimnames = list(nm, nm))
  S <- data.frame(measure = nm, mr_marginal = NA_real_, mr_direct = NA_real_,
                  delta = NA_real_, r_squared = NA_real_, stringsAsFactors = FALSE)
  for (j in seq_len(p)) {
    fp <- fixed_part(B0, C0, Vmat, j, mult)
    z <- decompose_one(Y, fp$B, fp$C, Vmat, j)
    F[j, ] <- z$contributions
    S[j, c("mr_marginal", "mr_direct", "delta", "r_squared")] <-
      c(z$mr_marginal, z$mr_direct, z$delta, z$r_squared)
  }
  list(flow = F, summary = S)
}

## THE SEPTEMBER 30 CODE, kept only so the checks below can show they fail on
## it (second-pass standing rule 3). It hands every measure the same B and C.
decompose_model_sep30 <- function(Y, B, Cvec, Vmat) {
  p <- ncol(Vmat); nm <- colnames(Vmat)
  F <- matrix(0, p, p, dimnames = list(nm, nm))
  S <- data.frame(measure = nm, mr_marginal = NA_real_, mr_direct = NA_real_,
                  delta = NA_real_, r_squared = NA_real_, stringsAsFactors = FALSE)
  for (j in seq_len(p)) {
    z <- decompose_one(Y, B, Cvec, Vmat, j)
    F[j, ] <- z$contributions
    S[j, c("mr_marginal", "mr_direct", "delta", "r_squared")] <-
      c(z$mr_marginal, z$mr_direct, z$delta, z$r_squared)
  }
  list(flow = F, summary = S)
}

## TIS from a direct-reliance vector and a flow matrix (mcr_correlated_signals
## Sec 9): what a measure earns directly, plus what it lends to its neighbors
tis_score <- function(mr_direct_vec, F, net = FALSE) {
  sender <- if (net) colSums(F) else colSums(pmax(F, 0))
  1 + (mr_direct_vec - 1) + sender
}

## a Shapley/LMG decomposition of R^2 over the same measures, for Task 3.14 to
## judge against the flow matrix (exact over all 2^p subsets)
shapley_r2 <- function(y, Vmat) {
  p <- ncol(Vmat); nm <- colnames(Vmat); idx <- seq_len(p)
  r2 <- function(cols) if (!length(cols)) 0 else
    summary(lm(y ~ ., data = as.data.frame(Vmat[, cols, drop = FALSE])))$r.squared
  cache <- new.env(parent = emptyenv())
  ## the empty subset's key must not be "" -- exists("") is an error, the same
  ## family of trap as the inherits = FALSE one Task 3.3 recorded
  R2 <- function(cols) { k <- if (!length(cols)) "<empty>" else paste(sort(cols), collapse = ",")
    if (!exists(k, envir = cache, inherits = FALSE)) assign(k, r2(cols), envir = cache)
    get(k, envir = cache, inherits = FALSE) }
  phi <- setNames(rep(0, p), nm)
  for (j in idx) {
    rest <- setdiff(idx, j)
    for (k in 0:(p - 1)) for (S in combn(rest, k, simplify = FALSE))
      phi[j] <- phi[j] + factorial(k) * factorial(p - k - 1) / factorial(p) *
                         (R2(c(S, j)) - R2(S))
  }
  uniq <- setNames(vapply(idx, function(j) R2(idx) - R2(setdiff(idx, j)), numeric(1)), nm)
  list(shapley = phi, unique = uniq, shared = phi - uniq, r2_full = R2(idx))
}

# ==========================================================================
# 2.  VALIDATION  --  before the implementation touches the project's data
# ==========================================================================
hdr("VALIDATION  (Task 3.13 verify: the components sum, and a synthetic case")
cat("            with known shared structure is recovered)\n")
V <- list(); chk <- function(name, got, want, tol = TOLNUM, note = "") {
  ok <- is.finite(got) && is.finite(want) && abs(got - want) <= tol
  V[[length(V) + 1]] <<- data.frame(check = name, got = got, want = want,
                                    abs_diff = abs(got - want), tol = tol, pass = ok,
                                    note = note, stringsAsFactors = FALSE)
  cat(sprintf("  %-52s got %13.8f  want %13.8f  %s\n", name, got, want, if (ok) "PASS" else "FAIL"))
  ok
}
sim <- function(n, p, rho = 0, seed = 1) {
  set.seed(seed); X <- matrix(rnorm(n * p), n, p); colnames(X) <- paste0("X", seq_len(p))
  if (rho != 0) X[, 1] <- rho * X[, 2] + sqrt(1 - rho^2) * X[, 1]
  X
}
vmat_of <- function(X, b) { V <- sweep(X, 2, b, `*`); colnames(V) <- colnames(X); V }

sub_("1. the conditional permutation, against brute force over all ordered pairs")
set.seed(713); n <- 40
Xs <- sim(n, 3, seed = 2); bs <- c(1.4, -0.8, 0.5)
ys <- as.vector(Xs %*% bs) + rnorm(n)
Vs <- vmat_of(Xs, bs); Bs <- as.vector(Vs[, -1, drop = FALSE] %*% rep(1, 2)); Cs <- rep(1, n)
inf1 <- residualize(Vs, 1)
bf <- switch_loss_bruteforce(ys, Bs + inf1$fitted, matrix(Cs, ncol = 1),
                             matrix(inf1$residuals, ncol = 1))
cf <- switch_loss(ys, Bs + inf1$fitted, matrix(Cs, ncol = 1), matrix(inf1$residuals, ncol = 1))
chk("conditional e_switch: closed form = brute force", cf$e_switch, bf$e_switch)

sub_("2. a measure orthogonal to every other has no shared part")
bo <- c(1, 1, 1)
## orthogonal to one another AND to the intercept, so that the centred
## covariances the decomposition uses are exactly zero
set.seed(5)
Xo <- qr.Q(qr(cbind(1, matrix(rnorm(4000 * 3), 4000, 3))))[, -1] * sqrt(4000)
colnames(Xo) <- paste0("X", 1:3)
yo <- as.vector(Xo %*% bo) + rnorm(4000)
Vo <- vmat_of(Xo, bo); Bo <- as.vector(Vo[, -1] %*% rep(1, 2))
d1 <- decompose_one(yo, Bo, rep(1, 4000), Vo, 1)
chk("orthogonal design: Delta = 0", d1$delta, 0, tol = 1e-8)
chk("orthogonal design: MR_direct = MR_marginal", d1$mr_direct, d1$mr_marginal, tol = 1e-8)

sub_("3. the components sum as the method requires")
Xc <- sim(3000, 4, rho = 0.8, seed = 9); bc <- c(1.2, 0.9, -0.5, 0.3)
yc <- as.vector(Xc %*% bc) + rnorm(3000, sd = 1.5)
Vc <- vmat_of(Xc, bc); Bc0 <- rep(0, 3000)
Bfull <- as.vector(Vc %*% rep(1, 4))
dm <- decompose_model(yc, 0, 1, Vc)                    # fixed part = full model minus j
for (j in 1:4) {
  z <- decompose_one(yc, Bfull - Vc[, j], rep(1, 3000), Vc, j)
  chk(sprintf("X%d: MR_marginal = MR_direct + Delta", j), z$mr_direct + z$delta, z$mr_marginal)
  chk(sprintf("X%d: the per-neighbor flow sums to Delta", j), sum(z$contributions), z$delta)
}
## Task S1.1: decompose_model() must hand each measure the full model minus
## that measure, which is what the per-measure calls above do by hand
chk("decompose_model = full-minus-one by hand (all measures)",
    max(abs(dm$summary$mr_marginal - vapply(1:4, function(j)
      decompose_one(yc, Bfull - Vc[, j], rep(1, 3000), Vc, j)$mr_marginal, numeric(1)))), 0)
## the log-scale fixed part: the other measures' exponentiated contributions
## fold into the multiplicative factor, so B + C * V_j rebuilds exp(eta)
Vx <- exp(0.1 * Vc); fpx <- fixed_part(0, 1, Vx, 2, mult = TRUE)
chk("log scale: B + C * V_j rebuilds exp(sum of contributions)",
    max(abs(fpx$B + fpx$C * Vx[, 2] - exp(0.1 * Bfull))), 0, tol = 1e-12)

sub_("4. the ERM closed form from decomposition_algorithm.docx Sec 5")
## Delta_j = 2 n beta_j^2 Var(Xhat_j) / ((n-1) e0) at the empirical risk minimizer
Xe <- sim(6000, 3, rho = 0.7, seed = 21); be <- c(1, -0.6, 0.4)
ye <- as.vector(Xe %*% be) + rnorm(6000)
fit <- lm(ye ~ Xe); bh <- coef(fit)[-1]
Ve <- vmat_of(Xe, bh); ne <- 6000
e0 <- mean(residuals(fit)^2)
ie <- residualize(Ve, 1)
want <- 2 * ne * var(ie$fitted) * (ne - 1) / ne / ((ne - 1) * e0)
zz <- decompose_one(ye, coef(fit)[1] + as.vector(Ve[, -1] %*% rep(1, 2)), rep(1, ne), Ve, 1)
chk("Delta = 2 n Var(vhat) / ((n-1) e0) at the ERM", zz$delta, want, tol = 1e-6)

sub_("5. the exact conditional expectation against the prior implementation's")
## exact: E[(e_i - e_pi(i))^2] = e_i^2 n/(n-1) + ||e||^2/(n-1)
## prior: e_i^2 (n-2)/(n-1) + ||e||^2/(n-1)
ej <- inf1$residuals; nn <- length(ej); bj <- 1
Eex <- ej^2 * nn / (nn - 1) + sum(ej^2) / (nn - 1)
Epr <- ej^2 * (nn - 2) / (nn - 1) + sum(ej^2) / (nn - 1)
r0 <- ys - (Bs + Vs[, 1])
chk("exact conditional e1 = brute force",
    mean(r0^2 + bj^2 * Eex) + 2 * bj * mean(r0 * (ej * nn / (nn - 1))), bf$e_switch, tol = 1e-8)
chk("prior formula differs from brute force by O(1/n)",
    abs(mean(r0^2 + 2 * bj * r0 * ej + bj^2 * Epr) - bf$e_switch) > 1e-6, TRUE, tol = 0,
    note = "difference is real but immaterial; the exact form is used")

sub_("6. a synthetic case whose shared structure is known in closed form")
## X1 = rho*X2 + sqrt(1-rho^2)*xi with X2 standard normal, so the share of X1
## reconstructable from X2 is exactly rho^2, and ALL of Delta_1 must attribute
## to X2. rho = 0.8 -> 64 percent of X1's variance is shared.
rho <- 0.8; nk <- 200000
set.seed(77); x2 <- rnorm(nk); xi <- rnorm(nk); x1 <- rho * x2 + sqrt(1 - rho^2) * xi
Xk <- cbind(X1 = x1, X2 = x2)
yk <- as.vector(Xk %*% c(1, 0.5)) + rnorm(nk)
## the closed form of Sec 4 holds AT THE ERM, where the cross-terms vanish by
## the OLS normal equations, so the check fits rather than assuming the truth
fk <- lm(yk ~ Xk); bk <- coef(fk)[-1]
Vk <- vmat_of(Xk, bk)
zk <- decompose_one(yk, coef(fk)[1] + as.vector(Vk[, 2]), rep(1, nk), Vk, 1)
chk("known rho = 0.8: R^2 of X1 on X2 recovered as rho^2", zk$r_squared, rho^2, tol = 5e-3,
    note = "rho^2 is the population value; the sample R^2 carries its own error")
chk("known rho = 0.8: all of Delta_1 flows to X2", unname(zk$contributions["X2"]), zk$delta, tol = TOLNUM)
chk("known rho = 0.8: nothing flows to X1 itself", unname(zk$contributions["X1"]), 0)
## the share of measure 1 that its neighbor reconstructs is rho^2 by construction
vh <- residualize(Vk, 1)
chk("known rho = 0.8: Var(vhat_1)/Var(v_1) = rho^2", var(vh$fitted) / var(Vk[, 1]), rho^2, tol = 5e-3)
## and Delta obeys the exact finite-sample identity of Sec 4 on these data too
chk("known rho = 0.8: Delta_1 matches its exact closed form", zk$delta,
    2 * nk * mean((vh$fitted - mean(vh$fitted))^2) / ((nk - 1) * zk$e_orig), tol = 1e-6)

sub_("7. a known three-way split of the shared part")
## X1 = c2*X2 + c3*X3 + noise with X2, X3 independent, so the flow from X1 must
## divide as c2^2 Var(X2) : c3^2 Var(X3) = 0.36 : 0.64 for c2 = 0.6, c3 = 0.8
set.seed(78); nt <- 200000; z2 <- rnorm(nt); z3 <- rnorm(nt)
x1t <- 0.6 * z2 + 0.8 * z3 + rnorm(nt, sd = 0.5)
Xt <- cbind(X1 = x1t, X2 = z2, X3 = z3); bt <- c(1, 0.4, -0.3)
yt <- as.vector(Xt %*% bt) + rnorm(nt)
Vt <- vmat_of(Xt, bt)
zt <- decompose_one(yt, as.vector(Vt[, -1] %*% rep(1, 2)), rep(1, nt), Vt, 1)
chk("known split: share of Delta_1 flowing to X2", unname(zt$contributions["X2"]) / zt$delta,
    0.36 / (0.36 + 0.64), tol = 5e-3)
chk("known split: share flowing to X3", unname(zt$contributions["X3"]) / zt$delta,
    0.64 / (0.36 + 0.64), tol = 5e-3)
chk("known split: the two shares sum to Delta_1",
    sum(zt$contributions[c("X2", "X3")]), zt$delta)

sub_("8. the extremes: a perfectly reconstructable measure, and pure noise")
set.seed(79); np <- 5000; w <- rnorm(np)
Xp <- cbind(X1 = w, X2 = w + 0, X3 = rnorm(np))       # X1 and X2 identical
yp <- w + rnorm(np); Vp <- vmat_of(Xp, c(0.5, 0.5, 0.2))
zp <- decompose_one(yp, as.vector(Vp[, -1] %*% rep(1, 2)), rep(1, np), Vp, 1)
chk("a measure its neighbors reconstruct exactly has MR_direct = 1", zp$mr_direct, 1, tol = 1e-6)
## pure noise, uncorrelated and with a zero coefficient: TIS = 1
Xn <- sim(4000, 3, seed = 31); bn <- c(1, 0.6, 0)
yn <- as.vector(Xn %*% bn) + rnorm(4000)
Vn <- vmat_of(Xn, bn)
dn <- decompose_model(yn, mean(yn), 1, Vn)
tn <- tis_score(dn$summary$mr_direct, dn$flow)
chk("a pure-noise measure scores TIS = 1", unname(tn[3]), 1, tol = 1e-6)
## Task S1.1: the September 30 check here called X2 a "noise proxy", but X2 was
## an independent signal with coefficient 0.6. A real proxy follows
## (second-pass pre-registration sec 2): X2 = 0.8 X1 + 0.6 xi, and the model's
## coefficient on X2 is exactly 0.
set.seed(80); nq <- 200000; q1 <- rnorm(nq); q2 <- 0.8 * q1 + 0.6 * rnorm(nq)
yq <- q1 + rnorm(nq)
Vq <- cbind(X1 = q1, X2 = 0 * q2)
dq <- decompose_model(yq, 0, 1, Vq); tq <- tis_score(dq$summary$mr_direct, dq$flow)
chk("real proxy (model coef 0): direct reliance = 1", dq$summary$mr_direct[2], 1, tol = 1e-3)
chk("real proxy (model coef 0): TIS below the signal's", as.numeric(tq[2] < tq[1]), 1, tol = 0,
    note = sprintf("TIS = %.4f (signal), %.4f (proxy)", tq[1], tq[2]))
## the same proxy with its coefficient FITTED (true value 0, estimate small but
## not 0). Direct reliance still comes back as 1. TIS does not keep the order:
## the flow split is invariant to the size of the neighbor's coefficient, so
## any nonzero estimate hands the proxy the whole of the signal's Delta as
## sender credit. Carl, 2026-10-02: run it every time and report it as a known
## property of the sender term (task S1.1 note sec 4); the gate is the
## pre-registered exact-zero case above. It is logged, not a pass/fail check.
fq <- lm(yq ~ q1 + q2); bq <- coef(fq)
Vf <- cbind(X1 = bq[2] * q1, X2 = bq[3] * q2)
dfq <- decompose_model(yq, bq[1], 1, Vf); tf_ <- tis_score(dfq$summary$mr_direct, dfq$flow)
chk("fitted proxy: direct reliance = 1", dfq$summary$mr_direct[2], 1, tol = 1e-3,
    note = sprintf("fitted coefficient on X2 %.4f", bq[3]))
PROXY_FITTED <- data.frame(coef_x2 = unname(bq[3]), tis_signal = unname(tf_[1]),
                           tis_proxy = unname(tf_[2]), sender_proxy = dfq$flow[1, 2],
                           delta_signal = dfq$summary$delta[1])
cat(sprintf("  KNOWN PROPERTY (logged, not a check): fitted proxy TIS %.4f vs signal %.4f;\n",
            tf_[2], tf_[1]))
cat(sprintf("    the proxy's sender credit %.4f is the signal's whole Delta %.4f\n",
            dfq$flow[1, 2], dfq$summary$delta[1]))

sub_("8b. two independent predictors (the review's case; Task S1.1)")
## y = X1 + X2 + e with X1, X2, e independent standard normals. Permuting X1
## inside the full model: e_orig = 1, e_switch = 1 + 2 Var(X1) = 3, so MR -> 3.
## The September 30 code drops X2 from the fixed part and returns about 2.
set.seed(81); nw <- 5000; Xw <- cbind(X1 = rnorm(nw), X2 = rnorm(nw))
yw <- Xw[, 1] + Xw[, 2] + rnorm(nw)
dw <- decompose_model(yw, 0, 1, Xw)
dw0 <- decompose_model_sep30(yw, rep(0, nw), rep(1, nw), Xw)
cat(sprintf("  marginal reliance, repaired: %.4f, %.4f   September 30 code: %.4f, %.4f\n",
            dw$summary$mr_marginal[1], dw$summary$mr_marginal[2],
            dw0$summary$mr_marginal[1], dw0$summary$mr_marginal[2]))
chk("two predictors: X1 marginal reliance above 2.8", as.numeric(dw$summary$mr_marginal[1] > 2.8), 1,
    tol = 0, note = sprintf("MR = %.4f", dw$summary$mr_marginal[1]))
chk("two predictors: X2 marginal reliance above 2.8", as.numeric(dw$summary$mr_marginal[2] > 2.8), 1,
    tol = 0, note = sprintf("MR = %.4f", dw$summary$mr_marginal[2]))
chk("the same test FAILS on the September 30 code", as.numeric(all(dw0$summary$mr_marginal <= 2.8)), 1,
    tol = 0, note = sprintf("Sep 30 MR = %.4f, %.4f", dw0$summary$mr_marginal[1], dw0$summary$mr_marginal[2]))

sub_("9. contribution space reduces to the prior code's feature space")
## with one column per measure, working in v_j = beta_j x_j must reproduce the
## X-space decomposition exactly
Xr <- sim(2000, 4, rho = 0.6, seed = 41); br <- c(0.9, -1.1, 0.4, 0.2)
yr <- as.vector(Xr %*% br) + rnorm(2000)
Vr <- vmat_of(Xr, br)
zr <- decompose_one(yr, as.vector(Vr[, -2] %*% rep(1, 3)), rep(1, 2000), Vr, 2)
## X-space: residualize X_2 on X_{-2}, scale by beta_2
ix <- residualize(Xr, 2)
chk("contribution space: R^2 matches the X-space residualization", zr$r_squared, ix$r_squared)
chk("contribution space: Var(vhat) = beta^2 Var(Xhat)",
    var(residualize(Vr, 2)$fitted), br[2]^2 * var(ix$fitted))

sub_("10. Shapley/LMG, for Task 3.14 to judge against the flow matrix")
sh <- shapley_r2(yo, Vo)
chk("Shapley values sum to the model R^2", sum(sh$shapley), sh$r2_full, tol = 1e-8)
chk("orthogonal design: Shapley = unique", max(abs(sh$shapley - sh$unique)), 0, tol = 1e-8)
shc <- shapley_r2(yc, Vc)
chk("correlated design: Shapley still sums to R^2", sum(shc$shapley), shc$r2_full, tol = 1e-8)

VAL <- do.call(rbind, V)
write.csv(VAL, file.path("output", "tables", "tis-validation.csv"), row.names = FALSE)
cat(sprintf("\n  %d checks, %d passed, %d failed -> output/tables/tis-validation.csv\n",
            nrow(VAL), sum(VAL$pass), sum(!VAL$pass)))
if (!all(VAL$pass)) stop("TIS validation failed; not trusted on real data")
cat("  the decomposition is validated. Only now does it read the project's data.\n")

# ==========================================================================
# 3.  ON A REAL SPECIFICATION
# ==========================================================================
hdr("a smoke run on the project's data")
reg <- readRDS(file.path("data", "spec-registry.rds"))
SET <- readRDS(file.path("data", "rashomon-set.rds"))
DIS <- names(e$DIS_SIGN)

## every disadvantage measure's contribution vector, for one specification
spec_contributions <- function(s, base = a) {
  P <- spec_pieces(s, base)
  eta <- as.numeric(P$X %*% P$b)
  Vm <- vapply(DIS, function(v) { cl <- cols_for(P$X, v)
    if (length(cl)) as.numeric(P$X[, cl, drop = FALSE] %*% P$b[cl]) else rep(0, nrow(P$X)) },
    numeric(nrow(P$X)))
  colnames(Vm) <- DIS
  rest <- eta - rowSums(Vm)
  ## B and C carry everything but the disadvantage measures; decompose_model()
  ## adds the other nine back for each measure (Task S1.1)
  if (s$scale == "log") {
    if (s$reliability == "eiv") list(B = P$gm * (1 - LAM), C = LAM * exp(rest), V = exp(Vm), mult = TRUE)
    else                        list(B = rep(0, nrow(Vm)), C = exp(rest), V = exp(Vm), mult = TRUE)
  } else {
    if (s$reliability == "eiv") list(B = P$gm + LAM * (rest - P$gm), C = LAM, V = Vm, mult = FALSE)
    else                        list(B = rest, C = rep(1, nrow(Vm)), V = Vm, mult = FALSE)
  }
}

tis_spec <- function(spec_id) {
  s <- as.list(reg[reg$spec_id == spec_id, ])
  if (s$missing == "mi") s$missing <- "complete"   # smoke run: one completion
  z <- spec_contributions(s)
  dm <- decompose_model(Y, z$B, z$C, z$V, mult = z$mult)
  dm$tis <- tis_score(dm$summary$mr_direct, dm$flow)
  dm$spec <- s; dm
}
sid <- SET$sets[["composite.hospital"]]$d
sid <- sid$spec_id[sid$in_set & sid$scale == "identity"][1]
z <- tis_spec(sid)
cat(sprintf("\n  specification %d (%s / %s / %s):\n", sid, z$spec$form, z$spec$reliability, z$spec$grain))
cat(sprintf("  %-14s %10s %10s %10s %9s %9s\n", "measure", "MR_marg", "MR_direct", "Delta", "R2 on rest", "TIS"))
o <- order(-z$tis)
for (i in o) cat(sprintf("  %-14s %10.5f %10.5f %10.5f %9.3f %9.5f\n",
                         z$summary$measure[i], z$summary$mr_marginal[i], z$summary$mr_direct[i],
                         z$summary$delta[i], z$summary$r_squared[i], z$tis[i]))
cat(sprintf("\n  flow matrix rows sum to Delta: max |error| %.2e\n",
            max(abs(rowSums(z$flow) - z$summary$delta))))
nneg <- sum(z$summary$delta < 0)
cat(sprintf("\n  NOTE for Task 3.14: %d of the %d measures have Delta < 0 here.\n", nneg, nrow(z$summary)))
cat( "  mcr_formula_reference.docx states Delta >= 0, and that holds when the model\n")
cat( "  is the OLS solution ON THE DATA THE RELIANCE IS COMPUTED ON, because the\n")
cat( "  normal equations then kill the cross-terms. No specification here meets\n")
cat( "  that condition: each is fitted on its own frame -- weighted, subsampled, or\n")
cat( "  on an un-shrunk or logged outcome -- and then scored on the common\n")
cat( "  evaluation frame Task 3.9 fixed. The cross-terms survive, so Delta may take\n")
cat( "  either sign, and a negative Delta means the measure's correlations lower its\n")
cat( "  apparent reliance rather than inflating it. This is why TIS takes the\n")
cat( "  positive part of the flow; Task 3.14 reports TIS and TIS_net side by side.\n")
SM <- data.frame(spec_id = sid, z$summary, tis = as.numeric(z$tis),
                 sum_flow_minus_delta = rowSums(z$flow) - z$summary$delta)
write.csv(SM, file.path("output", "tables", "tis-smoke.csv"), row.names = FALSE)
cat("  output/tables/tis-smoke.csv\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. direct and shared sum as the method requires: MR_marginal = MR_direct +\n"))
cat(sprintf("     Delta for every measure, and the per-neighbor flow sums to Delta, both\n"))
cat(sprintf("     to %.0e in the synthetic checks and %.1e on the real specification -- PASS\n",
            TOLNUM, max(abs(rowSums(z$flow) - z$summary$delta))))
cat(sprintf("  2. a synthetic case with known shared structure is recovered: with\n"))
cat(sprintf("     X1 = 0.8*X2 + 0.6*xi, the reconstructable share comes back as rho^2 =\n"))
cat(sprintf("     0.64, all of Delta_1 flows to X2, and Delta_1 matches its closed form;\n"))
cat(sprintf("     a known 0.36/0.64 three-way split is recovered to 5e-3 -- PASS\n"))
cat(sprintf("  3. the validation ran before the implementation read any project data,\n"))
cat(sprintf("     %d checks, all passing -- PASS\n", nrow(VAL)))
stopifnot(all(VAL$pass), max(abs(rowSums(z$flow) - z$summary$delta)) < 1e-9)
hdr("done")
cat("\n  Task 3.14 runs this over the Rashomon set and reports shared attribution.\n")
