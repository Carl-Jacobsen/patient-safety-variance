# R/20-archetype-bands.R  --  Task S3.4, the archetype account corrected.
# make.R stage 46. POST-REVIEW.
#
# Three things, none of which changes stage 33's or 34's results.
#
# 1. THE CLUSTER CRITERIA TOGETHER. Stage 33 fixed ICL as the criterion and
#    reported the gap statistic beside it. The draft quoted ICL's verdict as
#    "no separated groups". Read together: ICL selects 2 groups on the
#    published score and 4 on the lambda-corrected one, the gap statistic
#    selects 1 on both, and ICL's own choice recurs in 44% and 59% of
#    subsamples. The statement generated here keeps ICL and the gap statistic
#    in one sentence: the analysis does not establish stable three-Track
#    groups. It is printed apart from the Track cross-tabulation, which tests a
#    different thing (whether hospitals concentrate in the three Track cells).
#
# 2. THE FULL NINE-CELL TABLE, with every off-diagonal count, for the primary
#    star arm, the arm without the 23 margin < -1 hospitals and the PSI-90 arm
#    -> output/tables/archetype-cells-full.csv.
#
# 3. THE ALTERNATIVE BANDS fixed in second-pass-preregistration.md sec 7:
#    (i) margin quartiles (Q1 low, Q2-Q3 middle, Q4 high) with the original
#    star bands; (ii) the original margin terciles with star bands 1 / 2-4 / 5;
#    (iii) both. Each with its nine-cell table, the diagonal share against the
#    50% operational criterion, the share expected under independence, and
#    gamma, with stage 34's bootstrap (B = 2000, seed 20260923) and verdict
#    rule -> output/tables/archetype-bands-sensitivity.csv. Bands that put half
#    the hospitals in the middle margin band raise the diagonal share expected
#    by chance, so the expected share is reported beside every observed one.
#
# CHECK FIRST: stage 34's helpers, taken from R/08-archetypes.R without
# running it, reproduce the stored primary-arm cell counts and its stored
# Track-cell share and interval.
#
# Output: the two tables and the log. About 1 min.

n_  <- function(x) suppressWarnings(as.numeric(x))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK S3.4  the archetype account -- stage 46 (post-review)")

## stage 34's constants and helpers, without running the stage
env <- new.env()
KEEP_FN <- c("SEED", "BOOT", "BAR", "tercile", "band", "gk_gamma", "stats_of", "boot_ci", "cell_table")
for (ex in parse(file.path("R", "08-archetypes.R"))) {
  if (is.call(ex) && identical(ex[[1]], as.name("<-")) && is.name(ex[[2]]) && as.character(ex[[2]]) %in% KEEP_FN)
    eval(ex, env)
  ## `SEED <- ...; BOOT <- ...; BAR <- ...` sits on one line: parse gives three calls
}
stopifnot(all(KEEP_FN %in% ls(env)))
for (k in KEEP_FN) assign(k, get(k, env))

# ==========================================================================
# 1.  THE CLUSTER CRITERIA, TOGETHER
# ==========================================================================
hdr("1. clustering on margin and PSI-90: every criterion in one place (stage 33)")
CS <- read.csv(file.path("output", "tables", "cluster-summary.csv"), stringsAsFactors = FALSE)
p <- CS[CS$screen == "primary", ]; pp <- p[p$version == "published", ]; pc_ <- p[p$version == "corrected", ]
print(CS, row.names = FALSE)
## the subsample design, from stage 33's log
L33 <- grep("stability -- ICL's G over", readLines(file.path("output", "tables", "task3.15-clusters.txt")), value = TRUE)
SUB <- c(B = as.numeric(sub(".*over (\\d+) subsamples.*", "\\1", L33)), F = as.numeric(sub(".*subsamples of (\\d+)%.*", "\\1", L33)))
stopifnot(length(L33) == 1, all(is.finite(SUB)))
STMT <- sprintf(paste0(
  "On operating margin and PSI-90 (%s hospitals), the preregistered criterion, ICL, selects %d groups on the ",
  "published score and %d on the lambda-corrected score, while the gap statistic selects %d on both; ICL's own ",
  "choice recurs in %s and %s of %d random %s subsamples. The analysis therefore does not establish stable three-Track groups. ",
  "That is a statement about clustering, separate from the Track cross-tabulation below."),
  format(pp$n, big.mark = ","), pp$icl_G, pc_$icl_G, pp$gap_k, pct(pp$stability_agree, 0),
  pct(pc_$stability_agree, 0), SUB[["B"]], paste0(SUB[["F"]], "%"))
stopifnot(pp$gap_k == pc_$gap_k)
cat("\n  ", strwrap(STMT, 100, exdent = 2), sep = "\n  ")

# ==========================================================================
# 2.  THE FRAME (stage 34's) AND THE CHECK
# ==========================================================================
a <- readRDS(file.path("data", "analytic-v2.rds"))
h <- read.csv(file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv"),
              colClasses = "character", check.names = FALSE)
star <- n_(h[["Hospital overall rating"]][match(a$ccn, h[["Facility ID"]])])
D0 <- data.frame(ccn = a$ccn, star = star, margin = n_(a$operating_margin), dsh = n_(a$dsh_pct),
                 beds = n_(a$beds), psi90 = n_(a$psi90), lambda_i = n_(a$lambda_i))
D0$screened23 <- !is.na(D0$margin) & D0$margin < -1
F1 <- D0[!is.na(D0$star) & !is.na(D0$margin), ]
stopifnot(nrow(F1) == 2581)

sub_("check: the helpers reproduce stage 34's primary arm")
AC <- read.csv(file.path("output", "tables", "archetype-cells.csv"), stringsAsFactors = FALSE)
AV <- read.csv(file.path("output", "tables", "archetype-validation.csv"), stringsAsFactors = FALSE)
ct0 <- cell_table(F1, band(F1$star)); st0 <- stats_of(band(F1$star), F1$margin); ci0 <- boot_ci(band(F1$star), F1$margin)
ref <- AC[AC$arm == "star", ]
stopifnot(identical(as.numeric(ct0$n), as.numeric(ref$n)))
av <- AV[AV$claim == "C2 Track-cell share" & grepl("^star, full frame", AV$track), ]
cat(sprintf("  cells identical; Track-cell share %.6f [%.6f, %.6f] vs stored %.6f [%.6f, %.6f]\n",
            st0[["track_share"]], ci0[1, "track_share"], ci0[2, "track_share"], av$estimate, av$ci_lo, av$ci_hi))
stopifnot(abs(st0[["track_share"]] - av$estimate) < 1e-12, abs(ci0[1, "track_share"] - av$ci_lo) < 1e-12,
          abs(ci0[2, "track_share"] - av$ci_hi) < 1e-12)

# ==========================================================================
# 3.  THE FULL NINE-CELL TABLES
# ==========================================================================
hdr("2. the full nine-cell tables, every off-diagonal count")
SLAB <- list(star = c("1-2 stars", "3 stars", "4-5 stars"), psi90 = c("PSI-90 worst third", "PSI-90 middle third", "PSI-90 best third"))
MLAB3 <- c("margin bottom third", "margin middle third", "margin top third")
full_rows <- function(arm, ct, slab, mlab, n) {
  data.frame(arm = arm, safety = ct$safety, margin = ct$margin, safety_label = slab[ct$safety],
             margin_label = mlab[ct$margin], cell = ifelse(ct$safety == ct$margin, paste0("Track ", ct$safety, " cell"), "off-diagonal"),
             n = ct$n, share = ct$n / n, expected = ct$expected, obs_exp = ct$n / ct$expected,
             beds_median = ct$beds_median, safety_net_share = ct$safety_net_share, stringsAsFactors = FALSE)
}
FULL <- rbind(
  full_rows("star (primary)", ct0, SLAB$star, MLAB3, nrow(F1)),
  { F2 <- F1[!F1$screened23, ]; full_rows("star, without the 23", cell_table(F2, band(F2$star)), SLAB$star, MLAB3, nrow(F2)) },
  full_rows("PSI-90 terciles", cell_table(F1, 4L - tercile(F1$psi90)), SLAB$psi90, MLAB3, nrow(F1)))
for (arm in unique(FULL$arm)) {
  x <- FULL[FULL$arm == arm, ]; M <- matrix(x$n, 3, 3, dimnames = list(unique(x$safety_label), unique(x$margin_label)))
  sub_(arm); print(M)
  cat(sprintf("  diagonal (Track cells) %d = %s; off-diagonal %d = %s; corners off the Track pattern (worst safety x top margin, best safety x bottom margin) %d\n",
              sum(diag(M)), pct(sum(diag(M)) / sum(M)), sum(M) - sum(diag(M)), pct(1 - sum(diag(M)) / sum(M)), M[1, 3] + M[3, 1]))
}
write.csv(FULL, file.path("output", "tables", "archetype-cells-full.csv"), row.names = FALSE)

# ==========================================================================
# 4.  THE ALTERNATIVE BANDS (prereg sec 7)
# ==========================================================================
hdr("3. alternative bands (second-pass preregistration sec 7) -- the 50% criterion is operational")
quartile_band <- function(m) { q <- as.integer(ceiling(4 * rank(m, ties.method = "first") / length(m)))
  ifelse(q == 1, 1L, ifelse(q == 4, 3L, 2L)) }
band_alt <- function(s) ifelse(s == 1, 1L, ifelse(s == 5, 3L, 2L))
DESIGNS <- list(
  original = list(s = band, m = tercile, sl = c("1-2 stars", "3 stars", "4-5 stars"), ml = MLAB3),
  `(i) margin quartiles` = list(s = band, m = quartile_band, sl = c("1-2 stars", "3 stars", "4-5 stars"),
                                ml = c("margin Q1", "margin Q2-Q3", "margin Q4")),
  `(ii) star bands 1 / 2-4 / 5` = list(s = band_alt, m = tercile, sl = c("1 star", "2-4 stars", "5 stars"), ml = MLAB3),
  `(iii) both` = list(s = band_alt, m = quartile_band, sl = c("1 star", "2-4 stars", "5 stars"),
                      ml = c("margin Q1", "margin Q2-Q3", "margin Q4")))
## stats with a given margin banding (stage 34's stats_of uses terciles)
stats_b <- function(s, mb) {
  tb <- table(factor(s, 1:3), factor(mb, 1:3)); ex <- outer(rowSums(tb), colSums(tb)) / sum(tb)
  c(gamma = gk_gamma(tb), diag = sum(diag(tb)) / sum(tb), expected = sum(diag(ex)) / sum(tb),
    ratio = sum(diag(tb)) / sum(diag(ex))) }
OUT <- list()
for (nm in names(DESIGNS)) {
  D <- DESIGNS[[nm]]; s <- D$s(F1$star)
  st <- stats_b(s, D$m(F1$margin))
  set.seed(SEED)                                   # stage 34's bootstrap: bands re-formed within each resample
  B <- t(replicate(BOOT, { i <- sample.int(nrow(F1), replace = TRUE); stats_b(s[i], D$m(F1$margin[i])) }))
  ci <- apply(B, 2, quantile, c(0.025, 0.975))
  tb <- table(factor(s, 1:3), factor(D$m(F1$margin), 1:3)); dimnames(tb) <- list(D$sl, D$ml)
  verdict <- if (ci[1, "gamma"] <= 0) "not supported" else if (st[["diag"]] >= BAR) "supported as strata" else "gradient, not strata"
  sub_(nm); print(tb)
  cat(sprintf("  diagonal %s [%s, %s]; expected under independence %s; ratio %.2f [%.2f, %.2f]; gamma %+.3f [%+.3f, %+.3f] -> %s\n",
              pct(st[["diag"]]), pct(ci[1, "diag"]), pct(ci[2, "diag"]), pct(st[["expected"]]), st[["ratio"]],
              ci[1, "ratio"], ci[2, "ratio"], st[["gamma"]], ci[1, "gamma"], ci[2, "gamma"], verdict))
  if (nm == "original") stopifnot(abs(st[["diag"]] - st0[["track_share"]]) < 1e-12, abs(ci[1, "diag"] - ci0[1, "track_share"]) < 1e-12)
  for (i in 1:3) for (j in 1:3)
    OUT[[length(OUT) + 1]] <- data.frame(design = nm, row = "cell", safety = D$sl[i], margin = D$ml[j],
      diagonal = i == j, n = tb[i, j], estimate = tb[i, j] / sum(tb), ci_lo = NA, ci_hi = NA, verdict = NA, stringsAsFactors = FALSE)
  for (q in c("diag", "expected", "ratio", "gamma"))
    OUT[[length(OUT) + 1]] <- data.frame(design = nm, row = c(diag = "diagonal share", expected = "expected under independence",
      ratio = "observed / expected", gamma = "gamma")[[q]], safety = NA, margin = NA, diagonal = NA, n = nrow(F1),
      estimate = st[[q]], ci_lo = if (q == "expected") NA else ci[1, q], ci_hi = if (q == "expected") NA else ci[2, q],
      verdict = if (q == "diag") verdict else NA, stringsAsFactors = FALSE)
}
OUT <- do.call(rbind, OUT)
write.csv(OUT, file.path("output", "tables", "archetype-bands-sensitivity.csv"), row.names = FALSE)

# ==========================================================================
# 5.  BEDS AND UNITS
# ==========================================================================
hdr("4. beds: the Track 3 cell against the memo's scenario hospital")
t3 <- FULL[FULL$arm == "star (primary)" & FULL$safety == 3 & FULL$margin == 3, ]
cat(sprintf("  Track 3 cell (4-5 stars, top margin third): n %d, median beds %.0f, against the memo's 500-bed scenario\n",
            t3$n, t3$beds_median))
cat(sprintf("  share of the Track 3 cell with 500 or more beds: %s\n",
            pct(mean(F1$beds[band(F1$star) == 3 & tercile(F1$margin) == 3] >= 500, na.rm = TRUE))))
cat("  CASH2 v6 calls its archetypes constructed illustrations; bed counts are scenario inputs, not fitted\n")
cat("  percentiles. The memo's unit is a health system; this analysis's unit is a CCN (one hospital).\n")

hdr("verify")
cat("  helpers reproduce stage 34's cells and Track-cell share and interval; the original design reproduces\n")
cat("  them again through the band machinery; ICL and gap stand in one generated sentence -- PASS\n")
hdr("done")
