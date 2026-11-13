# R/17-inclusion-missingness.R  --  Task S3.1, the inclusion flow and the
# missing-data assumption. make.R stage 43. POST-REVIEW.
#
# Two parts.
#
# 1. THE INCLUSION FLOW. One table from the 2,801-hospital outcome frame to
#    every analytic frame the report uses: the component outcomes, the
#    2,569-hospital composite model frame (and the larger fit frames of the
#    multiple-imputation and omit arms), the 2,581-hospital star-rating frame,
#    the clustering frame, and the HACRP calibration frame. Each frame is
#    rebuilt here from the frozen file by the rule its own stage uses, and
#    asserted equal to that stage's count, so the table cannot drift from the
#    analyses. Stage 39 then reconciles every row that carries a registry key
#    against the number it registers, and stops on any difference.
#
#    The 158 imputed contract-labor values are split into the 139 that were
#    missing after deterministic recovery (Task 1.6) and the 19 observed but
#    outside [0, 0.50], set to missing by gate C2.d. The Task 2.6 missingness
#    audit modelled only the 139.
#
# 2. THE SHIFT SENSITIVITY (second-pass-preregistration.md sec 7). Multiple
#    imputation here assumes contract labor is missing at random given the
#    observed covariates. A regression of missingness on observed covariates
#    shows only that missingness depends on them; it cannot show that it does
#    not also depend on the unseen values. So: every imputed value (and only
#    those) is shifted by delta x SD(observed share), delta = -1, -0.5, 0,
#    +0.5, +1, in all 20 completions, and the two preregistered MI anchors are
#    refitted.
#      M-best   lowest excess loss among unweighted, missing = mi set members
#      M-median upper median of the same members
#    Reported at each delta: the community block's share of variation (LMG,
#    as stage 22 defines it, in the anchor's own model and fit frame, averaged
#    over completions) and the reliance on the ten-measure disadvantage group
#    (MR, as stage 30 computes it, on the common 2,569-hospital frame).
#    Supplementary, fixed before the shift was first run: the contract-labor
#    coefficient, and the same shifts with each shifted value clamped to the
#    C2.d range [0, 0.50] (an unclamped shift of -1 SD takes some imputed
#    shares below zero).
#
# CHECKS. At delta = 0 each anchor's MR equals its value in mcr-per-model.csv
# (1e-9) and its common-frame loss equals data/rashomon-loss.rds (1e-10); the
# LMG function reproduces stage 22's published-score community share on the
# matching linear complete-case spec (1e-10); a shifted completion differs
# from the unshifted one only on the imputed rows.
#
# Output: output/tables/inclusion-flow.csv, output/tables/mnar-sensitivity.csv,
# the log. Deterministic (no random step); about 30 s.

suppressMessages({ library(splines); library(lme4) })
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")

hdr("TASK S3.1  inclusion flow and the missing-data assumption -- stage 43 (post-review)")

## the Phase 3 machinery: 06-mcr.R rebuilds 3.9's evaluation frame, carries the
## spec harness (its own validation re-runs, silently, as in stage 35)
q <- new.env()
local({ tf <- tempfile(); sink(tf); sys.source(file.path("R", "06-mcr.R"), envir = q); sink(); unlink(tf) })
n_ <- q$n_; sub_ <- q$sub_; e <- q$e; a <- q$a
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
N <- nrow(a)
stopifnot(N == 2801)

# ==========================================================================
# 1.  THE INCLUSION FLOW
# ==========================================================================
hdr("1. inclusion flow")
FLOW <- list()
row_ <- function(frame, step, n_before, n_after, reason, key = "", note = "") {
  FLOW[[length(FLOW) + 1]] <<- data.frame(frame = frame, step = step, n_before = n_before,
    n_removed = n_before - n_after, n_after = n_after, reason = reason,
    registry_key = key, note = note, stringsAsFactors = FALSE)
  cat(sprintf("  %-26s %-44s %5s -> %5d  (%s)\n", frame, step,
              if (is.na(n_before)) "" else format(n_before), n_after, reason))
}
fin <- function(x) is.finite(n_(x))

## ---- the outcome frame (stage 3, gate O1.b) ----
sub_("the outcome frame")
L12 <- readLines(file.path("output", "tables", "task1.2-frame.txt"))
gl <- function(p) as.numeric(sub(".*?(\\d+)\\s*(\\[.*)?$", "\\1", grep(p, L12, value = TRUE)[1]))
n_fac <- gl("facilities in provider file"); n_num <- gl("with a numeric PSI_90")
n_va  <- gl("Acute Care - VA"); stopifnot(n_num - n_va == N)
row_("outcome frame", "Care Compare provider file", NA, n_fac, "all facilities")
row_("outcome frame", "numeric PSI-90 published", n_fac, n_num, "PSI-90 not published")
row_("outcome frame", "acute care hospitals (VA excluded)", n_num, N, "VA hospital", "03-data|n_frame",
     "the frame every later frame starts from")

## ---- component outcomes: suppression and structural zeros are not imputed ----
sub_("component outcomes (analyzed at their own coverage, never imputed)")
O <- readRDS(file.path("data", "outcomes.rds"))
stopifnot(identical(O$ccn, a$ccn))
fnote <- function(v) { x <- O[[paste0(v, "_footnote")]]; x[is.na(x)] <- "" ; x }
for (v in c("psi03", "psi06", "psi12", "psi13")) {
  ok <- fin(O[[v]]); ft <- fnote(v)[!ok]
  n7 <- sum(grepl("(^|, )7($|,)", ft)); n1 <- sum(!ok) - n7
  why <- if (!any(!ok)) "none missing" else
    sprintf("%d suppressed, too few cases (footnote 1); %d no eligible cases (footnote 7, structurally inapplicable)", n1, n7)
  row_("component outcomes", v, N, sum(ok), why, paste0("03-data|n_", v))
}
joint <- Reduce(`&`, lapply(c("psi03", "psi06", "psi12", "psi13"), function(v) fin(O[[v]])))
row_("component outcomes", "all four components", N, sum(joint), "any component missing", "03-data|n_joint")
hb <- fin(O$psi90) & fin(O$psi90_hacrp)
row_("HACRP comparison", "PSI-90 in both Care Compare and HACRP", N, sum(hb), "no HACRP PSI-90 value",
     "03-data|n_hacrp_both")

## ---- the composite model frame (stage 27's common frame, rebuilt in 06-mcr.R) ----
sub_("the composite model frame, in a fixed order of exclusion")
okY <- fin(a$psi90) & fin(a$lambda_i) & n_(a$lambda_i) > 0
okN <- !is.na(a$county_fips) & nzchar(as.character(a$county_fips)) & !is.na(a$hsa) & nzchar(as.character(a$hsa))
Avars <- setdiff(names(e$bA), "teaching")
okA_v <- sapply(Avars, function(k) fin(a[[e$bA[[k]]]]))
okA <- apply(okA_v, 1, all) & fin(a$teaching)
bcols <- unique(unlist(lapply(names(e$SUFFIX), function(g) vapply(e$bB_base, e$bcol, character(1), grain = g))))
okB <- Reduce(`&`, lapply(bcols, function(k) fin(a[[k]])))
Cother <- setdiff(names(e$bC_all), "contract_labor_share")
okCo <- Reduce(`&`, lapply(Cother, function(k) fin(a[[e$bC_all[[k]]]])))
okCL <- fin(a$contract_labor_share)
stopifnot(identical(okY & okN & okA & okB & okCo & okCL, q$KEEP))

## the 158: 139 missing after recovery, 19 screened out by C2.d (blockC.R)
CLR <- read.csv(file.path("data", "blockC_contract_labor.csv"), colClasses = "character")
raw <- n_(CLR$contract_labor_share[match(a$ccn, CLR$ccn)])
orig_miss <- is.na(raw); screened <- !orig_miss & (raw < 0 | raw > 0.50)
stopifnot(identical(orig_miss | screened, !okCL), sum(orig_miss) == 139, sum(screened) == 19)

blk_names <- function(m) paste(names(which(colSums(!m) > 0)), collapse = ", ")
cur <- rep(TRUE, N); steps <- list(
  list("PSI-90 and reliability present", okY, "outcome or lambda missing"),
  list("county and HSA assigned", okN, "no county or HSA"),
  list("Block A complete", okA, NULL),
  list("Block B complete at every grain", okB, "a disadvantage, access or market measure missing at some grain"),
  list("Block C complete except contract labor", okCo, "CMI drift or tort measure missing"),
  list("contract labor observed and in range", okCL, NULL))
for (st in steps) {
  nb <- sum(cur); gone <- cur & !st[[2]]
  why <- st[[3]]
  if (is.null(why) && st[[1]] == "Block A complete")
    why <- paste("missing:", paste(sprintf("%s %d", Avars, colSums(!okA_v[gone, , drop = FALSE]))[colSums(!okA_v[gone, , drop = FALSE]) > 0], collapse = ", "))
  if (is.null(why)) why <- sprintf("%d missing after recovery, %d outside [0, 0.50] (gate C2.d)",
                                   sum(gone & orig_miss), sum(gone & screened))
  cur <- cur & st[[2]]
  last <- identical(st, steps[[length(steps)]])
  row_("composite model frame", st[[1]], nb, sum(cur), why, if (last) "03-data|n_cc_abc" else "",
       if (last) "the common evaluation frame of every composite specification (stage 27)" else "")
}
stopifnot(sum(cur) == 2569)
row_("composite model frame", "left out of the model frame", N, N - sum(cur), "sum of the steps above",
     "03-data|n_cc_left", "n_after here is the count left out, not a frame")
FLOW[[length(FLOW)]]$n_removed <- NA

## hospitals excluded for one reason only (the order above does not matter for these)
only <- function(k) { ok <- list(okY, okN, okA, okB, okCo, okCL); bad <- sapply(ok, function(x) !x)
  sum(bad[, k] & rowSums(bad) == 1) }
cat(sprintf("  excluded for ONE reason only: outcome %d, nest %d, Block A %d, Block B %d, Block C other %d, contract labor %d\n",
            only(1), only(2), only(3), only(4), only(5), only(6)))
sole_cl <- only(6)

## ---- fit frames of the three missing-data arms, at the anchors' grains ----
sub_("fit frames of the missing-data arms (the evaluation frame is 2,569 for all)")
REGI <- q$reg
spec_of <- function(id) as.list(REGI[REGI$spec_id == id, ])
fit_n <- function(id, base) nrow(e$prep_spec(spec_of(id), base)$data)
## M anchors by the preregistered rule (sec 1), re-derived and checked
RS <- read.csv(file.path("output", "tables", "rashomon-set.csv"), stringsAsFactors = FALSE)
U <- RS[RS$outcome == "composite" & RS$unit == "hospital" & RS$in_set &
        RS$reliability == "unweighted" & RS$missing == "mi", ]
U <- U[order(U$excess), ]
ANCH <- c(M_best = U$spec_id[1], M_median = U$spec_id[ceiling((nrow(U) + 1) / 2)])
stopifnot(nrow(U) == 17, ANCH[["M_best"]] == 80, ANCH[["M_median"]] == 157)
cc_twin <- function(id, arm) { s <- spec_of(id)
  REGI$spec_id[REGI$blocks == s$blocks & REGI$form == s$form & REGI$outcome == s$outcome &
               REGI$reliability == s$reliability & REGI$grain == s$grain & REGI$missing == arm &
               REGI$influential == s$influential & REGI$scale == s$scale] }
for (nm in names(ANCH)) {
  id <- ANCH[[nm]]; g <- spec_of(id)$grain
  n_mi <- fit_n(id, q$mi_base(a, 1)); n_cc <- fit_n(cc_twin(id, "complete"), a); n_om <- fit_n(cc_twin(id, "omit"), a)
  row_("missing-data arms", sprintf("%s (spec %d, %s): complete-case arm", nm, id, g), N, n_cc,
       "any model term missing at this grain")
  row_("missing-data arms", sprintf("%s (spec %d, %s): multiple-imputation arm", nm, id, g), N, n_mi,
       "any term other than contract labor missing at this grain",
       note = sprintf("%d imputed contract-labor values enter this fit", n_mi - n_cc))
  row_("missing-data arms", sprintf("%s (spec %d, %s): omit arm", nm, id, g), N, n_om,
       "any term missing; contract labor not in the model")
}

## ---- the star-rating frame (stage 34) and the clustering frame (stage 33) ----
sub_("the star-rating frame and the clustering frame")
hg <- read.csv(file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv"),
               colClasses = "character", check.names = FALSE)
star <- n_(hg[["Hospital overall rating"]][match(a$ccn, hg[["Facility ID"]])])
mg <- n_(a$operating_margin)
mwhy <- function(k) { s <- a$operating_margin_source[k & is.na(mg)]
  sprintf("%d net patient revenue < $1M (margin structurally undefined), %d not in HCRIS",
          sum(s == "denominator < $1M"), sum(s != "denominator < $1M")) }
row_("star-rating frame", "overall star rating published", N, sum(!is.na(star)), "no star rating",
     note = "208 unrated (supp-archetypes|n_unrated)")
row_("star-rating frame", "operating margin present", sum(!is.na(star)), sum(!is.na(star) & !is.na(mg)),
     mwhy(!is.na(star)), "supp-archetypes|n_frame", "the archetype cross-tabulation frame (stage 34)")
FLOW[[length(FLOW) + 1]] <- data.frame(frame = "star-rating frame", step = "unrated hospitals", n_before = N,
  n_removed = NA, n_after = sum(is.na(star)), reason = "count of hospitals with no star rating",
  registry_key = "supp-archetypes|n_unrated", note = "n_after here is a count, not a frame", stringsAsFactors = FALSE)
row_("clustering frame", "operating margin present", N, sum(!is.na(mg)), mwhy(rep(TRUE, N)))
row_("clustering frame", "margin at least -1", sum(!is.na(mg)), sum(!is.na(mg) & mg >= -1),
     "operating expense more than twice net patient revenue", note = "the ICL frame (stage 33)")
L33 <- readLines(file.path("output", "tables", "task3.15-clusters.txt"))
stopifnot(sum(!is.na(mg) & mg >= -1) == as.numeric(sub(".*primary frame (\\d+),.*", "\\1", grep("primary frame", L33, value = TRUE)[1])))

## ---- the payment frame and the HACRP calibration frame (stage 35) ----
sub_("the payment frame and the HACRP calibration frame")
AE <- q$AE
NPR <- n_(AE$net_patient_revenue)
okQ <- is.finite(NPR) & NPR > 0 & !AE$flag_npr_tiny
row_("payment frame", "model frame with positive net patient revenue", nrow(AE), sum(okQ),
     "net patient revenue missing, non-positive or flagged tiny", note = "the Q-HIP simulation frame")
starQ <- star[match(AE$ccn[okQ], a$ccn)]
FLOW[[length(FLOW) + 1]] <- data.frame(frame = "payment frame", step = "payment-frame hospitals with no star rating",
  n_before = sum(okQ), n_removed = NA, n_after = sum(is.na(starQ)), reason = "count, not an exclusion",
  registry_key = "07-payment|n_unrated_pay",
  note = "a different 139 from the 139 missing contract labor: none of these is in that group" , stringsAsFactors = FALSE)
stopifnot(!any(AE$ccn[okQ][is.na(starQ)] %in% a$ccn[orig_miss]))
h <- read.csv(file.path("data-raw", "hacrp_fy2026", "FY_2026_HAC_Reduction_Program_Hospital.csv"),
              colClasses = "character", check.names = FALSE)
hm <- match(AE$ccn[okQ], h[["Facility ID"]])
inH <- !is.na(hm); hv <- inH & is.finite(n_(h[["PSI 90 Composite Value"]][pmax(hm, 1)]))
notMD <- hv & h$State[pmax(hm, 1)] != "MD"
FLOW[[length(FLOW) + 1]] <- data.frame(frame = "HACRP calibration frame", step = "rows in the FY 2026 HACRP file",
  n_before = NA, n_removed = NA, n_after = nrow(h), reason = "context: the gate C1 file, not a subset of the frame",
  registry_key = "07-payment|c1_n", note = "", stringsAsFactors = FALSE)
row_("HACRP calibration frame", "payment frame present in HACRP", sum(okQ), sum(inH), "not in the HACRP file")
row_("HACRP calibration frame", "HACRP PSI-90 value present", sum(inH), sum(hv), "no HACRP PSI-90 value")
row_("HACRP calibration frame", "outside Maryland", sum(hv), sum(notMD), "Maryland (waived from HACRP)",
     "07-payment|c2_n", "the C2 calibration frame (stage 35)")

FLOW <- do.call(rbind, FLOW)
FLOW$order <- seq_len(nrow(FLOW))
FLOW <- FLOW[, c("order", "frame", "step", "n_before", "n_removed", "n_after", "reason", "registry_key", "note")]
write.csv(FLOW, file.path("output", "tables", "inclusion-flow.csv"), row.names = FALSE)
cat(sprintf("\n  %d rows -> output/tables/inclusion-flow.csv (%d carry a registry key)\n",
            nrow(FLOW), sum(nzchar(FLOW$registry_key))))

sub_("contract labor: who was imputed")
cat(sprintf("  missing after recovery %d; observed but outside [0, 0.50] %d (gate C2.d); imputed %d x 20 completions\n",
            sum(orig_miss), sum(screened), sum(!okCL)))
cat(sprintf("  of the 158, %d are otherwise complete for every composite term; %d are excluded from the\n", sole_cl, sum(!okCL) - sole_cl))
cat("  model frame for another reason too. None is in the 2,569-hospital evaluation frame.\n")
cat(sprintf("  screened values: %s\n", paste(sprintf("%.3f", sort(raw[screened])), collapse = " ")))

# ==========================================================================
# 2.  THE SHIFT SENSITIVITY  (prereg sec 7)
# ==========================================================================
hdr("2. contract labor imputed values shifted by delta x SD(observed), M-best and M-median")
DELTAS <- c(-1, -0.5, 0, 0.5, 1)
SD_OBS <- sd(n_(a$contract_labor_share), na.rm = TRUE)
IMP_ROWS <- which(!okCL)
IMPC0 <- q$IMPC
cat(sprintf("  SD of the %d observed shares %.5f; %d imputed rows; anchors M-best %d, M-median %d\n",
            sum(okCL), SD_OBS, length(IMP_ROWS), ANCH[["M_best"]], ANCH[["M_median"]]))
imp_vals <- unlist(lapply(IMPC0, function(z) z$contract_labor_share[IMP_ROWS]))
cat(sprintf("  imputed values (158 x 20): mean %.4f, median %.4f; observed mean %.4f\n",
            mean(imp_vals), median(imp_vals), mean(n_(a$contract_labor_share), na.rm = TRUE)))

shifted <- function(delta, clamp) lapply(IMPC0, function(z) {
  v <- z$contract_labor_share; v[IMP_ROWS] <- v[IMP_ROWS] + delta * SD_OBS
  if (clamp) v[IMP_ROWS] <- pmin(pmax(v[IMP_ROWS], 0), 0.50)
  z$contract_labor_share <- v; z })

## LMG (stage 22's Shapley average over the three blocks) for one fitted frame
lmg_one <- function(pp) {
  blocks <- list(structure = pp$feA, community = pp$feB, policy = pp$feC)
  r2 <- function(vars) if (!length(vars)) 0 else
    summary(lm(as.formula(paste(".y ~", paste(vars, collapse = " + "))), data = pp$data, weights = pp$data$.w))$r.squared
  q3 <- new.env(); val <- function(s) { k <- if (!length(s)) "0" else paste(sort(s), collapse = "+")
    if (is.null(q3[[k]])) q3[[k]] <- r2(unlist(blocks[s], use.names = FALSE)); q3[[k]] }
  P <- list(c(1, 2, 3), c(1, 3, 2), c(2, 1, 3), c(2, 3, 1), c(3, 1, 2), c(3, 2, 1)); nm <- names(blocks)
  sh <- setNames(numeric(3), nm)
  for (p in P) { prev <- character(0); for (b in nm[p]) { sh[b] <- sh[b] + val(c(prev, b)) - val(prev); prev <- c(prev, b) } }
  c(sh / 6, r2 = val(nm))
}

## check: on the linear complete-case catch_tract spec this IS stage 22's model
VD <- read.csv(file.path("output", "tables", "variance-decomposition.csv"), stringsAsFactors = FALSE)
vd_pub <- VD[grepl("^composite", VD$source) & grepl("^published", VD$version) & VD$block == "community", "share"]
id22 <- REGI$spec_id[REGI$blocks == "ABC" & REGI$form == "linear" & REGI$outcome == "composite" &
                     REGI$reliability == "unweighted" & REGI$grain == "catch_tract" & REGI$missing == "complete" &
                     REGI$influential == "all" & REGI$scale == "identity"]
l22 <- lmg_one(e$prep_spec(spec_of(id22), a))
cat(sprintf("  LMG check: spec %d community share %.6f vs stage 22 published %.6f\n", id22, l22[["community"]], vd_pub))
stopifnot(length(vd_pub) == 1, abs(l22[["community"]] - vd_pub) < 1e-10)

MPM <- read.csv(file.path("output", "tables", "mcr-per-model.csv"), stringsAsFactors = FALSE)
LOS <- readRDS(file.path("data", "rashomon-loss.rds"))
DIS <- names(e$DIS_SIGN)
ROWS <- list()
for (clamp in c(FALSE, TRUE)) for (d in DELTAS) {
  if (clamp && d == 0) next
  IMPd <- shifted(d, clamp)
  for (j in seq_along(IMPd)) {           # only the imputed rows move
    dv <- IMPd[[j]]$contract_labor_share != IMPC0[[j]]$contract_labor_share
    stopifnot(!any(dv[-IMP_ROWS]), identical(IMPd[[j]][, -1], IMPC0[[j]][, -1]))
  }
  assign("IMPC", IMPd, envir = q)
  n_out <- sum(sapply(IMPd, function(z) sum(z$contract_labor_share[IMP_ROWS] < 0 | z$contract_labor_share[IMP_ROWS] > 0.50)))
  for (nm in names(ANCH)) {
    s <- spec_of(ANCH[[nm]])
    mr <- q$mr_spec(s, DIS)
    per <- sapply(seq_along(IMPd), function(j) {
      pp <- e$prep_spec(s, q$mi_base(a, j))
      fit <- lm(as.formula(paste(".y ~", paste(c(pp$feA, pp$feB, pp$feC), collapse = " + "))),
                data = pp$data, weights = pp$data$.w)
      c(lmg_one(pp), coef_cl = unname(coef(fit)["contract_labor_share"]), n_fit = nrow(pp$data))
    })
    if (d == 0) {
      st <- MPM$blockB_disadvantage[MPM$spec_id == ANCH[[nm]]]
      cat(sprintf("  delta 0 check, %s: MR %.10f vs stored %.10f; loss %.3e vs stored\n", nm, mr$mr, st,
                  abs(mr$e_orig - LOS$loss[LOS$spec_id == ANCH[[nm]]])))
      stopifnot(abs(mr$mr - st) < 1e-9, abs(mr$e_orig - LOS$loss[LOS$spec_id == ANCH[[nm]]]) < 1e-10)
    }
    ROWS[[length(ROWS) + 1]] <- data.frame(
      anchor = nm, spec_id = ANCH[[nm]], grain = s$grain, delta = d,
      shift = d * SD_OBS, clamped = clamp, n_fit = per["n_fit", 1], n_eval = nrow(q$AE),
      n_imputed_outside_range = n_out,
      community_share = mean(per["community", ]), structure_share = mean(per["structure", ]),
      policy_share = mean(per["policy", ]), r2 = mean(per["r2", ]),
      mr_disadvantage = mr$mr, coef_contract_labor = mean(per["coef_cl", ]),
      stringsAsFactors = FALSE)
  }
}
assign("IMPC", IMPC0, envir = q)
MN <- do.call(rbind, ROWS)
base <- MN[MN$delta == 0, c("anchor", "community_share", "mr_disadvantage", "coef_contract_labor")]
names(base)[-1] <- paste0(names(base)[-1], "_d0")
MN <- merge(MN, base, by = "anchor", sort = FALSE)
MN$community_change <- MN$community_share - MN$community_share_d0
MN$mr_change <- MN$mr_disadvantage - MN$mr_disadvantage_d0
MN <- MN[order(MN$anchor != "M_best", MN$clamped, MN$delta), ]
MN$community_share_d0 <- MN$mr_disadvantage_d0 <- NULL
write.csv(MN, file.path("output", "tables", "mnar-sensitivity.csv"), row.names = FALSE)

sub_("results (community share = LMG share of R2-scale variation; MR on the 2,569 frame)")
for (cl in c(FALSE, TRUE)) {
  cat(sprintf("\n  %s\n", if (cl) "SUPPLEMENTARY: shifted values clamped to [0, 0.50]" else "PREREGISTERED: unclamped"))
  cat(sprintf("  %-9s %6s %8s %10s %10s %10s %10s %9s %6s\n", "anchor", "delta", "shift", "community",
              "change", "MR(dis)", "change", "coef CL", "out"))
  x <- MN[MN$clamped == cl | (MN$delta == 0), ]
  for (i in seq_len(nrow(x))) with(x[i, ], cat(sprintf("  %-9s %+6.1f %+8.4f %9.3f%% %+9.3f%% %10.4f %+10.4f %+9.4f %6d\n",
    anchor, delta, shift, 100 * community_share, 100 * community_change, mr_disadvantage, mr_change,
    coef_contract_labor, n_imputed_outside_range)))
}
mx_c <- max(abs(MN$community_change)); mx_m <- max(abs(MN$mr_change))
cat(sprintf("\n  largest change over all shifts and both anchors: community share %.3f points; MR %.4f\n",
            100 * mx_c, mx_m))

# ==========================================================================
hdr("verify")
cat(sprintf("  1. every frame is rebuilt by its stage's own rule and equals that stage's count\n"))
cat(sprintf("     (2,801 / 2,569 / 2,581 / %d / %d); stage 39 reconciles %d keyed rows to its registry\n",
            sum(!is.na(mg) & mg >= -1), sum(notMD), sum(nzchar(FLOW$registry_key))))
cat(sprintf("  2. the 158 imputed = %d missing after recovery + %d screened by C2.d\n", sum(orig_miss), sum(screened)))
cat(sprintf("  3. delta = 0 reproduces stored MR (1e-9) and loss (1e-10) at both anchors; LMG reproduces\n"))
cat(sprintf("     stage 22's community share on spec %d; shifts move only the imputed rows -- PASS\n", id22))
hdr("done")
