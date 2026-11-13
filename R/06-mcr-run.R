# R/06-mcr-run.R  --  Task 3.12, running model class reliance. SCOPED.
#
# Sources R/06-mcr.R for the estimator, which re-runs that file's 15 validation
# checks on the way in (Task 3.11's verify condition, re-established every time
# the implementation is used rather than once). Reads data/rashomon-set.rds for
# membership and data/spec-results.rds for the per-measure contrasts.
#
# THE SCOPE IS THE TASK SHEET'S, and the exclusions are principled rather than
# time cuts:
#   Block B disadvantage -- full MCR-/MCR+, as a GROUP (the bound that matters)
#                           and per measure. Primary.
#   Block A structure    -- MCR as a SECONDARY output, reported after Block B
#                           and never as the headline, with coefficient ranges.
#   Block C policy       -- Rashomon coefficient ranges ONLY. NO MCR. Their job
#                           is to be in the model so a rival explanation is
#                           addressed, not to be ranked. provenance/
#                           admission-gates.md Sec 4 already forbids a tort MCR
#                           claim and rev 2 extended that to coding intensity
#                           and contract labor.
#
# HOW A BOUND IS STATED. Every number here is a claim about a model class, not
# about the world: "every fitted member of the set relies on X" and never
# "X causes Y" or "X matters by this much". Task S2.3: and never "every
# credible model" -- the set is 194 fitted representatives of 736
# specifications inside a bootstrap-calibrated empirical tolerance on in-sample
# loss, not a confidence set and not every model that fits nearly as well. The class is the 736 composite
# specifications of the pre-registered registry, and the bounds are minima and
# maxima over the ones inside the Rashomon set, so they range over an
# ENUMERATED class -- a minimum over a subset can only overstate the true
# minimum, which makes MCR- an upper bound for any richer class (Task 3.11
# Sec 4). Task 3.10's set width is printed beside every bound.
#
# MR is computed once per specification for every variable group at once (one
# fit, many groups), and the three composite sets nest -- hospital inside metro
# inside state, since their tolerances increase -- so MR is computed for all 736
# composite specifications and the bounds at each tolerance are minima over
# subsets. That also gives MCR- as a function of the tolerance for free.
#
# Outputs: output/tables/mcr-bounds-blockB.csv, output/tables/mcr-bounds-blockA.csv,
# output/tables/rashomon-coef-ranges.csv, output/tables/mcr-per-model.csv,
# output/tables/rashomon-published-subset.csv (Task S2.1: the members fitted
# to the published score without weights, beside the full set),
# output/figures/mcr-bounds.png.

suppressMessages({ library(lme4); library(splines) })

q <- new.env()
local({ tf <- tempfile(); sink(tf); sys.source(file.path("R", "06-mcr.R"), envir = q); sink(); unlink(tf) })
for (f in c("n_", "hdr", "sub_", "model_reliance", "spec_pieces", "cols_for", "mi_base", "eiv_gm"))
  assign(f, get(f, envir = q))
e <- q$e; a <- q$a; AE <- q$AE; Y <- q$Y; LAM <- q$LAM
reg <- readRDS(file.path("data", "spec-registry.rds"))
SET <- readRDS(file.path("data", "rashomon-set.rds"))
S37 <- readRDS(file.path("data", "spec-results.rds"))$results
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

hdr("TASK 3.12  model class reliance, run -- Block B primary")
cat(sprintf("  the implementation's %d validation checks re-ran on load: %s\n",
            nrow(q$VAL), if (all(q$VAL$pass)) "all pass" else "FAILURES -- STOP"))
stopifnot(all(q$VAL$pass))

# ==========================================================================
# 1.  THE VARIABLE GROUPS
# ==========================================================================
DIS  <- names(e$DIS_SIGN)                       # the 10 disadvantage measures
BA   <- names(e$bA)                             # 11 structural covariates
BC   <- names(e$bC_all)                         # 4 policy covariates -- NO MCR
GROUPS <- c(list(blockB_disadvantage = DIS, blockA_structure = BA),
            setNames(as.list(DIS), DIS), list(hhi = "hhi"),
            setNames(as.list(BA), BA))
cat(sprintf("\n  Block B disadvantage group: %s\n", paste(DIS, collapse = ", ")))
cat(sprintf("  Block A structure group:    %s\n", paste(BA, collapse = ", ")))
cat(sprintf("  Block C (%s): coefficient ranges only, no MCR -- a principled\n", paste(BC, collapse = ", ")))
cat(  "  exclusion carried from admission-gates.md Sec 4, not a time cut.\n")

# ==========================================================================
# 2.  ONE FIT PER SPECIFICATION, EVERY GROUP
# ==========================================================================
## returns MR for each group plus the scalar Block A / Block C coefficients
mr_all_groups <- function(s, groups) {
  J <- if (s$missing == "mi") seq_len(e$MI_M) else 1L
  n <- nrow(AE); M <- length(J); G <- names(groups)
  Bg <- Cg <- Vg <- setNames(lapply(G, function(...) matrix(NA_real_, n, M)), G)
  ncol_g <- setNames(rep(0L, length(G)), G)
  coefs <- NULL
  for (jj in seq_along(J)) {
    P   <- spec_pieces(s, if (s$missing == "mi") mi_base(a, J[jj]) else a)
    eta <- as.numeric(P$X %*% P$b)
    nmb <- names(P$b)
    coefs <- rbind(coefs, setNames(vapply(c(BA, BC), function(v)
      if (v %in% nmb) unname(P$b[[v]]) else NA_real_, numeric(1)), c(BA, BC)))
    for (g in G) {
      cl <- cols_for(P$X, groups[[g]])
      ncol_g[g] <- length(cl)
      ev <- if (length(cl)) as.numeric(P$X[, cl, drop = FALSE] %*% P$b[cl]) else rep(0, n)
      ea <- eta - ev                                  # the model without that block
      ## p(i<-j) = B_i + C_i * V_j, per the back-transform (R/06-mcr.R header)
      if (s$scale == "log") {
        if (s$reliability == "eiv") { B <- P$gm * (1 - LAM); C <- LAM * exp(ea) }
        else                        { B <- rep(0, n);        C <- exp(ea) }
        Vv <- exp(ev)
      } else {
        if (s$reliability == "eiv") { B <- P$gm + LAM * (ea - P$gm); C <- LAM }
        else                        { B <- ea;                       C <- rep(1, n) }
        Vv <- ev
      }
      Bg[[g]][, jj] <- B; Cg[[g]][, jj] <- C; Vg[[g]][, jj] <- Vv
    }
  }
  mr <- setNames(rep(NA_real_, length(G)), G); eo <- NA_real_
  for (g in G) {
    if (ncol_g[g] == 0) { mr[g] <- 1; next }   # no such column in this model: MR is 1
    z <- model_reliance(Y, rowMeans(Bg[[g]]), Cg[[g]], Vg[[g]])
    mr[g] <- z$mr; eo <- z$e_orig
  }
  list(mr = mr, e_orig = eo, coefs = colMeans(coefs, na.rm = TRUE), n_cols = ncol_g)
}

sub_("computing model reliance for every composite specification")
D <- SET$sets[["composite.hospital"]]$d
ids <- D$spec_id
## cached against the set and the implementation, so re-running the report is
## seconds rather than four minutes; MCR_REFIT=1 forces a recompute
MRF <- file.path("data", "mcr-reliance.rds")
## (Task S0.3: keyed on every script and data file the computation reads)
if (!exists("cache_key")) source(file.path("R", "cache-key.R"))
MR_KEY <- cache_key(c(file.path("R", c("06-mcr-run.R", "06-mcr.R", "04-spec-curve.R")),
                      file.path("data", c("rashomon-set.rds", "spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds"))))
CACHED <- cache_fresh(MRF, MR_KEY, "MCR_REFIT")
if (CACHED) {
  z <- readRDS(MRF); MR <- z$MR; CF <- z$CF
  cat(sprintf("  %s reused -- %d specs, no re-fit.\n", MRF, nrow(MR)))
} else {
t0 <- Sys.time(); MRL <- list(); COEF <- list()
for (k in seq_along(ids)) {
  s <- as.list(reg[reg$spec_id == ids[k], ])
  z <- mr_all_groups(s, GROUPS)
  MRL[[k]]  <- c(spec_id = ids[k], z$mr, e_orig = z$e_orig)
  COEF[[k]] <- c(spec_id = ids[k], z$coefs)
  if (k %% 100 == 0 || k == length(ids))
    cat(sprintf("  [%3d/%3d] %5.1f min\n", k, length(ids), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
MR <- as.data.frame(do.call(rbind, MRL)); CF <- as.data.frame(do.call(rbind, COEF))
MR <- merge(D[, c("spec_id", "loss", "excess", "in_set", "blocks", "form", "reliability",
                  "grain", "missing", "scale", "dis_std")], MR, by = "spec_id")
cache_save(list(MR = MR, CF = CF, built = Sys.time()), MRF, MR_KEY)
}
stopifnot(max(abs(MR$e_orig - MR$loss)) < 1e-10)
cat(sprintf("  e_orig equals the stored common-frame loss for all %d specs (max |diff| %.1e)\n",
            nrow(MR), max(abs(MR$e_orig - MR$loss))))

# ==========================================================================
# 3.  THE BOUNDS  --  minima and maxima over each nested set
# ==========================================================================
TOL <- readRDS(file.path("data", "rashomon-tolerance.rds"))$tolerance
TOLC <- TOL[TOL$family == "composite", ]
W <- SET$width
bounds_for <- function(gname, unit) {
  eps <- TOLC$epsilon[TOLC$unit == unit]
  m <- MR[MR$excess <= eps, ]
  ww <- W[W$family == "composite" & W$unit == unit, ]
  v <- m[[gname]]
  data.frame(group = gname, unit = unit, role = TOLC$role[TOLC$unit == unit],
             epsilon_pct = 100 * eps / TOLC$loss_erm[1], n_models = nrow(m),
             mcr_minus = min(v), mcr_plus = max(v), mr_median = median(v),
             mr_at_erm = m[[gname]][which.min(m$loss)],
             share_above_one = mean(v > 1),
             set_width_sd = ww$width, set_est_min = ww$est_min, set_est_max = ww$est_max,
             stringsAsFactors = FALSE)
}
BND <- do.call(rbind, lapply(c("blockB_disadvantage", DIS, "hhi", "blockA_structure", BA),
                             function(g) do.call(rbind, lapply(c("hospital", "cbsa", "state"),
                                                               function(u) bounds_for(g, u)))))

## ---------------------------------------------------------------- Block B --
hdr("BLOCK B -- the ten-measure disadvantage group (PRIMARY)")
P <- BND[BND$group == "blockB_disadvantage" & BND$unit == "hospital", ]
cat(sprintf("\n  THE GROUP BOUND, at the pre-registered tolerance (%d near-optimal models):\n", P$n_models))
cat(sprintf("    MCR- = %.4f    MCR+ = %.4f    median %.4f    at the ERM %.4f\n",
            P$mcr_minus, P$mcr_plus, P$mr_median, P$mr_at_erm))
cat(sprintf("    %s of the set has MR above 1.\n", pct(P$share_above_one)))
## Task S2.3: the claim names what was searched, and the state-tolerance
## bound travels in the same sentence as the primary one
PS_ <- BND[BND$group == "blockB_disadvantage" & BND$unit == "state", ]
cat(sprintf("\n    THE CLAIM, stated for the fitted models examined:\n"))
cat(sprintf("    Each of the %d fitted specifications (of %d composite specifications)\n", P$n_models, nrow(MR)))
cat(sprintf("    whose in-sample excess loss lies within the bootstrap-calibrated empirical\n"))
cat(sprintf("    tolerance relies on the ten-measure disadvantage group: scrambling it raises the least\n"))
cat(sprintf("    reliant member's squared error by %s and the most reliant's by %s\n",
            pct(P$mcr_minus - 1), pct(P$mcr_plus - 1)))
cat(sprintf("    (MCR- %.3f), while at the state tolerance the lower bound is %.3f.\n",
            P$mcr_minus, PS_$mcr_minus))
cat(sprintf("    It describes these fitted models, not every model that fits nearly as\n"))
cat(sprintf("    well, and says nothing about what disadvantage does to patients.\n"))
cat(sprintf("\n    ALONGSIDE IT, the set's width (Task 3.10): the same %d models put the\n", P$n_models))
cat(sprintf("    p10->p90 disadvantage contrast anywhere from %+.3f to %+.3f SD of PSI-90,\n",
            P$set_est_min, P$set_est_max))
cat(sprintf("    a width of %.3f SD that straddles zero. Reliance is bounded away from\n", P$set_width_sd))
cat(sprintf("    one while the contrast is not bounded away from zero, and both are true.\n"))
## Task S2.1: the Sep 30 text called MCR- a lower bound on reliance for the
## un-smoothed outcome. That reading rests on the scalar reliability
## approximation (lambda_i, Task 2.2), which the review found unvalidated for
## the released composite, so the bound is stated for the published score as
## fitted and the attenuation reading is labelled as conditional on it.
cat(sprintf("\n    ON THE PUBLISHED SCORE AS FITTED. Under the project's scalar reliability\n"))
cat(sprintf("    approximation, smoothing would attenuate gradients toward zero (the\n"))
cat(sprintf("    errors-in-variables arm raises the contrast in most paired cells, Task\n"))
cat(sprintf("    3.7), and MCR- = %.4f would then understate reliance on an unsmoothed\n", P$mcr_minus))
cat(sprintf("    outcome. That reading is conditional on an approximation not yet\n"))
cat(sprintf("    validated for this release; it is a sensitivity reading, not a finding.\n"))
cat(sprintf("    The members fitted to the published score without weights are\n"))
cat(sprintf("    reported beside the full set below.\n"))

## ------------------------------------------- the published-score members --
## Task S2.1 / review P1 (scalar reliability): the set and its MCR bounds for
## the members whose reliability axis is `unweighted`, beside the full set, at
## each tolerance. A subset of the reliance already computed above -- no refit.
## The full-set rows must reproduce BND and the stage-28 width exactly.
sub_("the published-score members (reliability = unweighted) beside the full set")
PUBGROUPS <- c("blockB_disadvantage", DIS, "hhi")
## October 7 audit A2: "unweighted" restricts the primary set, whose ERM and
## tolerance came through the mixed reliability registry. "published" is the
## published-score set calibrated on its own (stage 27 sec 6b): the unweighted
## composite specifications within their own ERM's bootstrap tolerance.
TOLPUB <- readRDS(file.path("data", "rashomon-tolerance.rds"))$published$tolerance
pub_rows <- function(unit, members) {
  eps <- TOLC$epsilon[TOLC$unit == unit]
  m <- MR[MR$excess <= eps, ]
  if (members == "unweighted") m <- m[m$reliability == "unweighted", ]
  if (members == "published") {
    tp <- TOLPUB[TOLPUB$unit == unit, ]
    m <- MR[MR$reliability == "unweighted" & MR$loss <= tp$loss_erm + tp$epsilon, ]
    stopifnot(nrow(m) == tp$n_members, m$spec_id[which.min(m$loss)] == tp$erm_spec)
  }
  best <- m[which.min(m$loss), ]
  do.call(rbind, lapply(PUBGROUPS, function(g) {
    v <- m[[g]]
    data.frame(unit = unit, role = TOLC$role[TOLC$unit == unit], members = members, group = g,
               n_models = nrow(m), mcr_minus = min(v), mcr_plus = max(v), mr_median = median(v),
               share_above_one = mean(v > 1), best_spec = best$spec_id, mr_at_best = best[[g]],
               n_with_estimate = sum(is.finite(m$dis_std)),   # Block-A-only members carry no contrast
               est_min = min(m$dis_std, na.rm = TRUE), est_max = max(m$dis_std, na.rm = TRUE),
               est_median = median(m$dis_std, na.rm = TRUE),
               share_positive = mean(m$dis_std > 0, na.rm = TRUE), stringsAsFactors = FALSE)
  }))
}
PUB <- do.call(rbind, lapply(c("hospital", "cbsa", "state"), function(u)
  rbind(pub_rows(u, "all"), pub_rows(u, "unweighted"), pub_rows(u, "published"))))
chk_all <- merge(PUB[PUB$members == "all", ], BND, by = c("group", "unit"), suffixes = c("", ".b"))
stopifnot(nrow(chk_all) == length(PUBGROUPS) * 3,
          max(abs(chk_all$mcr_minus - chk_all$mcr_minus.b)) == 0,
          max(abs(chk_all$mcr_plus - chk_all$mcr_plus.b)) == 0,
          all(chk_all$n_models == chk_all$n_models.b),
          max(abs(chk_all$est_min - chk_all$set_est_min)) < 1e-12,
          max(abs(chk_all$est_max - chk_all$set_est_max)) < 1e-12)
cat("  full-set rows reproduce the bounds above and the stage-28 width exactly\n\n")
cat(sprintf("  %-9s %-11s %4s %9s %9s   %-17s %8s   %s\n", "tolerance", "members", "n",
            "MCR-", "MCR+", "contrast range SD", "median", "best member"))
for (u in c("hospital", "cbsa", "state")) for (mb in c("all", "unweighted", "published")) {
  z <- PUB[PUB$unit == u & PUB$members == mb & PUB$group == "blockB_disadvantage", ]
  cat(sprintf("  %-9s %-11s %4d %9.4f %9.4f   %+.3f to %+.3f %+8.3f   spec %d\n", u, mb, z$n_models,
              z$mcr_minus, z$mcr_plus, z$est_min, z$est_max, z$est_median, z$best_spec))
}
pu <- PUB[PUB$unit == "hospital" & PUB$members == "unweighted" & PUB$group %in% c(DIS, "hhi"), ]
pa_ <- PUB[PUB$unit == "hospital" & PUB$members == "all" & PUB$group %in% c(DIS, "hhi"), ]
cat(sprintf("\n  per measure, primary tolerance: MCR- over all %d members vs the %d unweighted ones\n",
            pa_$n_models[1], pu$n_models[1]))
for (g in c(DIS, "hhi"))
  cat(sprintf("    %-12s %9.4f  %9.4f\n", g, pa_$mcr_minus[pa_$group == g], pu$mcr_minus[pu$group == g]))
write.csv(PUB, file.path("output", "tables", "rashomon-published-subset.csv"), row.names = FALSE)
cat("  -> output/tables/rashomon-published-subset.csv\n")

sub_("the group bound at the other two tolerances")
for (u in c("cbsa", "state")) {
  z <- BND[BND$group == "blockB_disadvantage" & BND$unit == u, ]
  cat(sprintf("  %-9s eps %.2f%%  %3d models  MCR- %.4f  MCR+ %.4f  share > 1 %s\n",
              u, z$epsilon_pct, z$n_models, z$mcr_minus, z$mcr_plus, pct(z$share_above_one)))
}

sub_("per measure (the group bound is the one that matters -- Plan Sec 6)")
pm <- BND[BND$group %in% c(DIS, "hhi") & BND$unit == "hospital", ]
pm <- pm[order(-pm$mcr_minus), ]
cat(sprintf("  %-14s %9s %9s %9s %9s\n", "measure", "MCR-", "MCR+", "median", "share>1"))
for (i in seq_len(nrow(pm)))
  cat(sprintf("  %-14s %9.4f %9.4f %9.4f %8s%s\n", pm$group[i], pm$mcr_minus[i], pm$mcr_plus[i],
              pm$mr_median[i], pct(pm$share_above_one[i]),
              if (pm$group[i] == "hhi") "   (market control, not a deprivation axis)" else ""))
cat(sprintf("\n  No single measure reaches the group's MCR- of %.4f. That is the point:\n", P$mcr_minus))
cat(  "  Task 3.1 measured the collinearity (adi~ice150 r = -0.83, VIF up to 9.8),\n")
cat(  "  so a near-optimal model can drop any one measure and lean on its neighbours.\n")
cat(  "  The group cannot be dropped. Per-measure attribution is TIS's job (3.13/3.14).\n")

## ---------------------------------------------------------------- Block A --
hdr("BLOCK A -- structure (SECONDARY, reported after Block B, never the headline)")
A <- BND[BND$group == "blockA_structure" & BND$unit == "hospital", ]
cat(sprintf("  group bound: MCR- = %.4f  MCR+ = %.4f  median %.4f  share > 1 %s\n",
            A$mcr_minus, A$mcr_plus, A$mr_median, pct(A$share_above_one)))
pa <- BND[BND$group %in% BA & BND$unit == "hospital", ]; pa <- pa[order(-pa$mcr_minus), ]
cat(sprintf("\n  %-18s %9s %9s %9s\n", "covariate", "MCR-", "MCR+", "median"))
for (i in seq_len(nrow(pa)))
  cat(sprintf("  %-18s %9.4f %9.4f %9.4f\n", pa$group[i], pa$mcr_minus[i], pa$mcr_plus[i], pa$mr_median[i]))

## ---------------------------------------------------------------- Block C --
hdr("BLOCK C -- policy: coefficient ranges only, no MCR")
cat("  No MCR is computed for cmi_drift, contract_labor_share, tort_n_reforms or\n")
cat("  tort_cap_total. admission-gates.md Sec 4 forbids a tort MCR claim, and rev 2\n")
cat("  of the task sheet extended that to coding intensity and contract labor: these\n")
cat("  covariates are in the model so that a rival explanation is addressed, not so\n")
cat("  that they can be ranked. This is a principled exclusion and it stands.\n")

# ==========================================================================
# 4.  RASHOMON COEFFICIENT RANGES
# ==========================================================================
sub_("Rashomon coefficient ranges, across the primary set")
inset <- MR$spec_id[MR$in_set]
sd90 <- SET$sd_psi90
rng <- function(v, lab, blk) { v <- v[is.finite(v)]
  data.frame(block = blk, covariate = lab, n = length(v), lo = min(v), hi = max(v),
             median = median(v), width = diff(range(v)), straddles_zero = min(v) < 0 & max(v) > 0,
             stringsAsFactors = FALSE) }
CR <- list()
## Block B: the per-measure p10->p90 contrast from Task 3.7, which handles the
## spline arm correctly (a splined measure has no single coefficient)
for (v in DIS) CR[[length(CR) + 1]] <-
  rng(S37[[paste0("b_", v)]][match(inset, S37$spec_id)] / sd90, v, "B disadvantage")
## Block A and C: scalar coefficients, per 1 SD of the covariate, in SD of PSI-90
CFin <- CF[match(inset, CF$spec_id), ]
for (v in BA) CR[[length(CR) + 1]] <- rng(CFin[[v]] / sd90, v, "A structure")
for (v in BC) CR[[length(CR) + 1]] <- rng(CFin[[v]] / sd90, v, "C policy")
CR <- do.call(rbind, CR)
for (blk in c("B disadvantage", "A structure", "C policy")) {
  cat(sprintf("\n  %s\n", blk)); z <- CR[CR$block == blk, ]
  for (i in seq_len(nrow(z)))
    cat(sprintf("    %-22s %+7.3f .. %+7.3f SD   median %+7.3f   %s\n", z$covariate[i], z$lo[i], z$hi[i],
                z$median[i], if (z$straddles_zero[i]) "straddles zero" else "one sign throughout"))
}

# ==========================================================================
# 5.  WRITE
# ==========================================================================
sub_("write")
bB <- BND[BND$group %in% c("blockB_disadvantage", DIS, "hhi"), ]
bA <- BND[BND$group %in% c("blockA_structure", BA), ]
write.csv(bB, file.path("output", "tables", "mcr-bounds-blockB.csv"), row.names = FALSE)
write.csv(bA, file.path("output", "tables", "mcr-bounds-blockA.csv"), row.names = FALSE)
write.csv(CR, file.path("output", "tables", "rashomon-coef-ranges.csv"), row.names = FALSE)
write.csv(MR, file.path("output", "tables", "mcr-per-model.csv"), row.names = FALSE)
cat("  output/tables/mcr-bounds-blockB.csv\n  output/tables/mcr-bounds-blockA.csv\n")
cat("  output/tables/rashomon-coef-ranges.csv\n  output/tables/mcr-per-model.csv\n")

# ==========================================================================
# 6.  FIGURE
# ==========================================================================
png(file.path("output", "figures", "mcr-bounds.png"), width = 1500, height = 1150, res = 130)
op <- par(mfrow = c(2, 2), mar = c(4.4, 9, 3.2, 1.2), cex.main = 0.95, cex.axis = 0.85)

## (1) Block B bounds
z <- BND[BND$group %in% c("blockB_disadvantage", DIS, "hhi") & BND$unit == "hospital", ]
z <- z[order(z$mcr_minus), ]
plot(NA, xlim = range(c(1, z$mcr_minus, z$mcr_plus)), ylim = c(0.5, nrow(z) + .5), yaxt = "n",
     ylab = "", xlab = "model class reliance", main = "Block B: MCR- to MCR+ (primary tolerance)")
abline(v = 1, col = "grey40", lty = 3)
cols <- ifelse(z$group == "blockB_disadvantage", "firebrick", ifelse(z$group == "hhi", "grey60", "grey25"))
segments(z$mcr_minus, seq_len(nrow(z)), z$mcr_plus, seq_len(nrow(z)), lwd = 4, col = cols)
points(z$mr_at_erm, seq_len(nrow(z)), pch = 4, col = "black", lwd = 1.5, cex = .8)
axis(2, at = seq_len(nrow(z)), labels = sub("blockB_disadvantage", "THE BLOCK", z$group), las = 2, cex.axis = .7)
legend("bottomright", bty = "n", cex = .7, pch = 4, legend = "the ERM's own reliance")

## (2) Block A bounds, secondary
z <- BND[BND$group %in% c("blockA_structure", BA) & BND$unit == "hospital", ]; z <- z[order(z$mcr_minus), ]
plot(NA, xlim = range(c(1, z$mcr_minus, z$mcr_plus)), ylim = c(0.5, nrow(z) + .5), yaxt = "n",
     ylab = "", xlab = "model class reliance", main = "Block A: structure (secondary)")
abline(v = 1, col = "grey40", lty = 3)
segments(z$mcr_minus, seq_len(nrow(z)), z$mcr_plus, seq_len(nrow(z)), lwd = 4,
         col = ifelse(z$group == "blockA_structure", "steelblue4", "grey35"))
axis(2, at = seq_len(nrow(z)), labels = sub("blockA_structure", "THE BLOCK", z$group), las = 2, cex.axis = .7)

## (3) MCR- of the block as the tolerance widens
par(mar = c(4.4, 4.4, 3.2, 1.2))
grid_eps <- seq(0, max(MR$excess), length.out = 300)
mm <- t(sapply(grid_eps, function(x) { v <- MR$blockB_disadvantage[MR$excess <= x]
  c(lo = min(v), hi = max(v), n = length(v)) }))
plot(grid_eps, mm[, "lo"], type = "l", lwd = 2, col = "firebrick",
     ylim = range(c(1, mm[, "lo"], mm[, "hi"])), xlab = "tolerance epsilon",
     ylab = "model class reliance", main = "Block B: MCR- and MCR+ as the tolerance widens")
lines(grid_eps, mm[, "hi"], lwd = 2, col = "firebrick")
polygon(c(grid_eps, rev(grid_eps)), c(mm[, "lo"], rev(mm[, "hi"])), col = adjustcolor("firebrick", .15), border = NA)
abline(h = 1, col = "grey40", lty = 3)
abline(v = TOLC$epsilon, col = c(hospital = "firebrick", state = "darkorange3", cbsa = "steelblue4")[TOLC$unit], lty = 2)
ocol <- c(hospital = "firebrick", state = "darkorange3", cbsa = "steelblue4")[TOLC$unit]
oo <- order(TOLC$epsilon)
legend("topright", bty = "n", cex = .7, lty = 2, col = ocol[oo],
       legend = sprintf("%s (%.1f%%)", c(hospital = "hospital", cbsa = "metro area",
                                         state = "state")[TOLC$unit][oo],
                        100 * TOLC$epsilon[oo] / TOLC$loss_erm[oo]))

## (4) coefficient ranges
par(mar = c(4.4, 9, 3.2, 1.2))
z <- CR[CR$block != "A structure", ]; z <- z[order(z$median), ]
plot(NA, xlim = range(c(z$lo, z$hi)), ylim = c(0.5, nrow(z) + .5), yaxt = "n", ylab = "",
     xlab = "coefficient across the set, SD of PSI-90",
     main = "Rashomon coefficient ranges (Block B contrasts, Block C)")
abline(v = 0, col = "grey40", lty = 3)
segments(z$lo, seq_len(nrow(z)), z$hi, seq_len(nrow(z)), lwd = 4,
         col = ifelse(z$block == "C policy", "darkorange3", "grey25"))
points(z$median, seq_len(nrow(z)), pch = 18, col = "black", cex = .9)
axis(2, at = seq_len(nrow(z)), labels = z$covariate, las = 2, cex.axis = .65)
legend("bottomright", bty = "n", cex = .7, lwd = 4, col = c("grey25", "darkorange3"),
       legend = c("Block B (p10->p90 contrast)", "Block C (no MCR, by design)"))
par(op); invisible(dev.off())
cat("  output/figures/mcr-bounds.png\n")

# ==========================================================================
hdr("verify")
cat(sprintf("  1. every bound is stated as a claim about the model class, not the world:\n"))
cat(sprintf("     the claim sentence above names the %d fitted members and the tolerance,\n", P$n_models))
cat(sprintf("     carries the state-tolerance bound beside the primary one, and disclaims\n"))
cat(sprintf("     any statement about what disadvantage does to patients -- PASS\n"))
cat(sprintf("  2. the set's width appears alongside the bound: %.3f SD, %+.3f to %+.3f,\n",
            P$set_width_sd, P$set_est_min, P$set_est_max))
cat(sprintf("     printed in the same block as MCR- -- PASS\n"))
cat(sprintf("  3. MCR- is stated for the published score as fitted; the attenuation\n"))
cat(sprintf("     reading is labelled conditional on the scalar approximation, and the\n"))
cat(sprintf("     %d unweighted members' bounds stand beside the full set's (Task S2.1) -- PASS\n",
            PUB$n_models[PUB$unit == "hospital" & PUB$members == "unweighted"][1]))
cat(sprintf("  4. no MCR was computed for Block C: %d of the %d groups are Block C -- PASS\n",
            sum(BND$group %in% BC), length(unique(BND$group))))
cat(sprintf("  5. Block A is reported after Block B and is not the headline -- PASS\n"))
stopifnot(!any(BND$group %in% BC), max(abs(MR$e_orig - MR$loss)) < 1e-10)
hdr("done")
