# R/19-ownership.R  --  Task S3.3, ownership and system membership added to
# Block A. make.R stage 45. POST-REVIEW.
#
# spec-space.md listed ownership, system membership and urban-rural status in
# Block A; every model used eleven other structure measures instead, and the
# draft discloses the gap (sec 3.3). This stage runs the limited sensitivity
# fixed in second-pass-preregistration.md amendment 2: on P-best (spec 382) and
# P-median (spec 610), add ownership (government and proprietary indicators,
# voluntary nonprofit the reference) and a system-membership indicator to
# Block A, change nothing else, and compare.
#
# Reported per anchor, as fitted and augmented: common-frame loss, the joint
# p10 -> p90 disadvantage contrast (SD of PSI-90) with its standard error, the
# community block's LMG share (stage 22's definition, the added terms counted
# as structure), the ten-measure disadvantage group's MR on the 2,569 frame,
# and the added coefficients.
#
# CHECK FIRST: the as-fitted anchor reproduces its stored loss (1e-10),
# contrast (1e-8) and disadvantage-group MR (1e-9).
#
# Output: output/tables/ownership-sensitivity.csv, the log. About 20 s.

suppressMessages({ library(splines); library(lme4) })
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")

hdr("TASK S3.3  ownership and system membership in Block A -- stage 45 (post-review)")
q <- new.env()
local({ tf <- tempfile(); sink(tf); sys.source(file.path("R", "06-mcr.R"), envir = q); sink(); unlink(tf) })
n_ <- q$n_; sub_ <- q$sub_; e <- q$e; a <- q$a; AE <- q$AE; Y <- q$Y
REGI <- q$reg; DIS <- names(e$DIS_SIGN)
SR  <- readRDS(file.path("data", "spec-results.rds"))$results
LOS <- readRDS(file.path("data", "rashomon-loss.rds"))
MPM <- read.csv(file.path("output", "tables", "mcr-per-model.csv"), stringsAsFactors = FALSE)
RS  <- read.csv(file.path("output", "tables", "rashomon-set.csv"), stringsAsFactors = FALSE)
sd_psi90 <- sd(n_(a$psi90), na.rm = TRUE)

## anchors by the sec 1 rule, re-derived
U <- RS[RS$outcome == "composite" & RS$unit == "hospital" & RS$in_set & RS$reliability == "unweighted", ]
U <- U[order(U$excess), ]
ANCH <- c(P_best = U$spec_id[1], P_median = U$spec_id[ceiling((nrow(U) + 1) / 2)])
stopifnot(nrow(U) == 65, ANCH[["P_best"]] == 382, ANCH[["P_median"]] == 610)

## the added columns, unstandardized
add_cols <- function(d) {
  i <- match(d$ccn, a$ccn); oc <- a$ownership_code[i]
  d$own_government <- as.numeric(oc == "G"); d$own_proprietary <- as.numeric(oc == "P")
  d$system_member <- as.numeric(a$system_member[i]); d }
EXTRA <- c("own_government", "own_proprietary", "system_member")
stopifnot(all(!is.na(AE$ownership_code)), all(!is.na(AE$system_member)))
sub_("the added fields on the 2,569-hospital frame")
print(table(ownership = AE$ownership_code, system_member = AE$system_member))
cat(sprintf("  no owner record (coded non-member, as frozen): %d\n", sum(!AE$has_owner_record)))

lmg3 <- function(dat, blocks) {
  r2 <- function(v) if (!length(v)) 0 else
    summary(lm(as.formula(paste(".y ~", paste(v, collapse = " + "))), data = dat))$r.squared
  q3 <- new.env(); val <- function(s) { k <- if (!length(s)) "0" else paste(sort(s), collapse = "+")
    if (is.null(q3[[k]])) q3[[k]] <- r2(unlist(blocks[s], use.names = FALSE)); q3[[k]] }
  nm <- names(blocks); sh <- setNames(numeric(3), nm)
  for (p in list(c(1, 2, 3), c(1, 3, 2), c(2, 1, 3), c(2, 3, 1), c(3, 1, 2), c(3, 2, 1))) {
    prev <- character(0); for (b in nm[p]) { sh[b] <- sh[b] + val(c(prev, b)) - val(prev); prev <- c(prev, b) } }
  sh / 6
}

fit_one <- function(s, extra) {
  pp <- e$prep_spec(s, a); d <- add_cols(pp$data)
  feA <- c(pp$feA, extra)
  fe <- paste(c(feA, pp$feB, pp$feC), collapse = " + ")
  m <- lm(as.formula(sprintf(".y ~ %s", fe)), data = d, weights = d$.w)
  fe_terms <- terms(as.formula(sprintf("~ %s", fe)), data = d)
  nd <- e$contrast_rows(pp); for (k in extra) nd[[k]] <- 0
  ce <- e$contrast_estimate(m, fe_terms, nd, FALSE)
  ## common-frame design and MR, as R/06-mcr.R mr_spec() does it (unweighted, identity)
  s2 <- s; s2$influential <- "all"; s2$reliability <- "unweighted"; s2$scale <- "identity"
  ED <- add_cols(e$prep_spec(s2, AE)$data); stopifnot(nrow(ED) == nrow(AE))
  X <- model.matrix(fe_terms, ED); b <- coef(m)[colnames(X)]; b[is.na(b)] <- 0
  cl <- q$cols_for(X, DIS)
  eta_v <- as.numeric(X[, cl, drop = FALSE] %*% b[cl]); eta_a <- as.numeric(X %*% b) - eta_v
  mr <- q$model_reliance(Y, eta_a, matrix(1, length(Y), 1), matrix(eta_v, ncol = 1))
  sh <- lmg3(d, list(structure = feA, community = pp$feB, policy = pp$feC))
  V <- vcov(m)
  co <- sapply(extra, function(k) c(est = unname(coef(m)[k]), se = sqrt(V[k, k])))
  list(n_fit = nrow(d), loss = mr$e_orig, joint = ce$est / sd_psi90, joint_se = ce$se / sd_psi90,
       community = sh[["community"]], structure = sh[["structure"]], mr = mr$mr, coef = co)
}

ROWS <- list()
for (nm in names(ANCH)) {
  id <- ANCH[[nm]]; s <- as.list(REGI[REGI$spec_id == id, ])
  stopifnot(s$reliability == "unweighted", s$scale == "identity", s$missing != "mi")
  f0 <- fit_one(s, character(0)); f1 <- fit_one(s, EXTRA)
  st <- SR[SR$spec_id == id, ]
  sub_(sprintf("%s (spec %d: %s, %s, %s)", nm, id, s$form, s$grain, s$missing))
  cat(sprintf("  check: loss %.10f vs stored %.10f; joint %+.8f vs %+.8f; MR %.10f vs %.10f\n",
              f0$loss, LOS$loss[LOS$spec_id == id], f0$joint, st$dis_effect / sd_psi90,
              f0$mr, MPM$blockB_disadvantage[MPM$spec_id == id]))
  stopifnot(abs(f0$loss - LOS$loss[LOS$spec_id == id]) < 1e-10,
            abs(f0$joint - st$dis_effect / sd_psi90) < 1e-8,
            abs(f0$mr - MPM$blockB_disadvantage[MPM$spec_id == id]) < 1e-9)
  for (v in c("as fitted", "with ownership and system")) {
    f <- if (v == "as fitted") f0 else f1
    ROWS[[length(ROWS) + 1]] <- data.frame(anchor = nm, spec_id = id, grain = s$grain, missing = s$missing,
      version = v, n_fit = f$n_fit, n_eval = nrow(AE), loss = f$loss, joint = f$joint, joint_se = f$joint_se,
      community_share = f$community, structure_share = f$structure, mr_disadvantage = f$mr,
      b_government = if (v == "as fitted") NA else f$coef["est", "own_government"],
      se_government = if (v == "as fitted") NA else f$coef["se", "own_government"],
      b_proprietary = if (v == "as fitted") NA else f$coef["est", "own_proprietary"],
      se_proprietary = if (v == "as fitted") NA else f$coef["se", "own_proprietary"],
      b_system = if (v == "as fitted") NA else f$coef["est", "system_member"],
      se_system = if (v == "as fitted") NA else f$coef["se", "system_member"], stringsAsFactors = FALSE)
  }
  cat(sprintf("  %-26s %8s %16s %10s %10s %9s\n", "", "loss", "joint (se)", "community", "structure", "MR(dis)"))
  for (v in list(c("as fitted", "f0"), c("+ ownership, system", "f1"))) { f <- get(v[2])
    cat(sprintf("  %-26s %.6f %+.3f (%.3f) %9.2f%% %9.2f%% %9.4f\n", v[1], f$loss, f$joint, f$joint_se,
                100 * f$community, 100 * f$structure, f$mr)) }
  cat(sprintf("  change: loss %+.3f%%, joint %+.4f SD, community %+.3f points, MR %+.4f\n",
              100 * (f1$loss / f0$loss - 1), f1$joint - f0$joint, 100 * (f1$community - f0$community), f1$mr - f0$mr))
  for (k in EXTRA) cat(sprintf("  %-16s %+.4f (se %.4f) PSI-90 units\n", k, f1$coef["est", k], f1$coef["se", k]))
}
OUT <- do.call(rbind, ROWS)
write.csv(OUT, file.path("output", "tables", "ownership-sensitivity.csv"), row.names = FALSE)

hdr("verify")
cat("  the as-fitted anchors reproduce stored loss, contrast and MR; the augmented fits differ\n")
cat(sprintf("  only by the three added columns -> output/tables/ownership-sensitivity.csv (%d rows)\n", nrow(OUT)))
hdr("done")
