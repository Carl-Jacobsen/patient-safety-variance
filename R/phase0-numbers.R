#!/usr/bin/env Rscript
# R/phase0-numbers.R
#
# PORTED AT TASK 1.1 from provenance/phase0-numbers.R, body unchanged.
# It is stage 1 of make.R. Still base R, still relative paths, still no
# packages, so it runs before renv is restored.
#
# Regenerates every number quoted in the Phase 0 spike notes and admission gates,
# from the archived raw files in data-raw/spike-phase0/.
#
# Standing rule 1: nothing is transcribed by hand. If a number appears in
# spike-outcome.md, spike-structure.md, spike-context.md, or admission-gates.md,
# this script produced it.
#
# Base R only, relative paths only, no packages -- so it runs before renv exists.
# Task 1.1 folded this into make.R; this file is the ported copy.
#
# Usage, from the variance-project/ directory:
#   Rscript make.R          (or, standalone: Rscript R/phase0-numbers.R)

RAW <- file.path("data-raw", "spike-phase0")
stopifnot(dir.exists(RAW))

pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr  <- function(s) cat("\n", strrep("=", 72), "\n", s, "\n", strrep("=", 72), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
qtab <- function(x, label, fmt = "%.4f") {
  x <- sort(x[is.finite(x)])
  q <- quantile(x, c(.05, .25, .5, .75, .95), type = 7, names = FALSE)
  cat(sprintf("  %-38s n=%-6d min=%s p05=%s p25=%s med=%s p75=%s p95=%s max=%s\n",
              label, length(x), sprintf(fmt, x[1]), sprintf(fmt, q[1]), sprintf(fmt, q[2]),
              sprintf(fmt, q[3]), sprintf(fmt, q[4]), sprintf(fmt, q[5]), sprintf(fmt, x[length(x)])))
}
rd <- function(f, ...) read.csv(file.path(RAW, f), colClasses = "character",
                                check.names = FALSE, na.strings = character(0), ...)
n_ <- function(x) suppressWarnings(as.numeric(trimws(x)))

## ------------------------------------------------------------------ 0.2 ----
hdr("TASK 0.2  outcome layer")

cd  <- rd("CandD_hospital.csv")
s6  <- rd("CMS_PSI_6_decimal_file.csv")
hac <- rd("HAC_FY2026.csv")
hg  <- rd("Hospital_General_Information.csv")
fnc <- rd("Footnote_Crosswalk.csv")

sub_("reporting period")
psi <- cd[grepl("^PSI", cd$`Measure ID`), ]
cat("  PSI window:", unique(psi$`Start Date`)[1], "..", unique(psi$`End Date`)[1], "\n")
cat("  measures in Complications & Deaths:", length(unique(cd$`Measure ID`)), "\n")
cat("  measures in six-decimal file      :", length(unique(s6$`Measure ID`)), "\n")

sub_("file sizes")
cat("  C&D rows", nrow(cd), " facilities", length(unique(cd$`Facility ID`)), "\n")
cat("  6-dec rows", nrow(s6), " facilities", length(unique(s6$`Facility ID`)), "\n")
cat("  HACRP rows", nrow(hac), "\n")

sub_("footnote crosswalk (codes seen on PSI rows)")
seen <- sort(unique(unlist(strsplit(psi$Footnote[psi$Footnote != ""], ",\\s*"))))
for (k in seen) cat(sprintf("  %-3s :: %s\n", k, fnc$`Footnote Text`[match(k, fnc$Footnote)]))
cat("\n  footnote counts across PSI rows:\n")
print(sort(table(psi$Footnote), decreasing = TRUE))

sub_("sample frame")
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
p90$num  <- !is.na(n_(p90$Score))
p90$type <- type[p90$`Facility ID`]
cat("  facilities in provider file           :", length(unique(cd$`Facility ID`)), "\n")
cat("  numeric PSI_90                        :", sum(p90$num), "\n")
cat("  ... Acute Care Hospitals  [THE FRAME] :", sum(p90$num & p90$type == "Acute Care Hospitals"), "\n")
cat("  ... Acute Care - VA       [EXCLUDED]  :", sum(p90$num & p90$type == "Acute Care - Veterans Administration"), "\n")
frame <- p90$`Facility ID`[p90$num & p90$type == "Acute Care Hospitals"]
N <- length(frame)

sub_("component availability within the frame")
comps <- c("PSI_03", "PSI_06", "PSI_12", "PSI_13")
sc <- lapply(comps, function(m) {
  r <- cd[cd$`Measure ID` == m, ]
  setNames(n_(r$Score), r$`Facility ID`)[frame]
})
names(sc) <- comps
for (m in comps) cat(sprintf("  %-7s %5d  %s\n", m, sum(!is.na(sc[[m]])), pct(mean(!is.na(sc[[m]])))))
allfour <- Reduce(`&`, lapply(sc, function(v) !is.na(v)))
cat(sprintf("  all four %5d  %s\n", sum(allfour), pct(mean(allfour))))
cat("  hospitals lost to listwise deletion:", N - sum(allfour), "\n")

sub_("component denominators within the frame")
for (m in comps) {
  r <- cd[cd$`Measure ID` == m, ]
  d <- setNames(n_(r$Denominator), r$`Facility ID`)[frame]
  qtab(d, paste(m, "denominator"), "%.0f")
}

sub_("distributions, six-decimal file")
for (m in c("PSI_90", comps)) qtab(n_(s6$Rate[s6$`Measure ID` == m]), m)

sub_("PRHI region within the frame")
st <- setNames(hg$State, hg$`Facility ID`)[frame]
print(st[st %in% c("PA", "OH", "WV")] |> table())

sub_("HACRP vs Care Compare PSI-90, same window")
a <- setNames(n_(hac$`PSI 90 Composite Value`), hac$`Facility ID`)
b <- setNames(n_(s6$Rate[s6$`Measure ID` == "PSI_90"]), s6$`Facility ID`[s6$`Measure ID` == "PSI_90"])
k <- intersect(names(a)[!is.na(a)], names(b)[!is.na(b)])
d <- a[k] - b[k]
cat("  paired hospitals        :", length(k), "\n")
cat("  pearson r               :", sprintf("%.6f", cor(a[k], b[k])), "\n")
cat("  mean difference         :", sprintf("%+.6f", mean(d)), "\n")
cat("  sd of difference        :", sprintf("%.6f", sd(d)), "\n")
cat("  99th pct |difference|   :", sprintf("%.6f", quantile(abs(d), .99, names = FALSE)), "\n")
cat("  max |difference|        :", sprintf("%.6f", max(abs(d))), "\n")
cat("  agree to 5 dp           :", sum(abs(d) < 5e-5), "\n")
cat("  HACRP payment reduction :"); print(table(hac$`Payment Reduction`))

## ------------------------------------------------------------------ 0.3 ----
hdr("TASK 0.3  Block A and Block C structure")

impact <- function(zipfile, member) {
  td <- tempfile(); dir.create(td)
  unzip(file.path(RAW, zipfile), files = member, exdir = td)
  L <- readLines(file.path(td, member), encoding = "latin1", warn = FALSE)
  h <- strsplit(L[2], "\t")[[1]]
  b <- L[-(1:2)]; b <- b[nzchar(trimws(b))]
  m <- do.call(rbind, lapply(strsplit(b, "\t", fixed = TRUE),
                             function(v) { length(v) <- length(h); v }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- h
  d$ccn <- formatC(trimws(d$`Provider Number`), width = 6, flag = "0")
  d
}
i26 <- impact("fy2026-impact.zip", "FY 2026 IPPS Final Rule Impact File.txt")
i25 <- impact("fy2025-impact.zip", "FY 2025 IPPS Impact File - Correction Notice.txt")
cr  <- rd("CostReport_2023_Final.csv")
cr$ccn <- formatC(trimws(cr$`Provider CCN`), width = 6, flag = "0")

sub_("match rates against the frame (n = )"); cat("  frame n =", N, "\n")
cat("  FY2026 impact:", sum(frame %in% i26$ccn), pct(mean(frame %in% i26$ccn)), "\n")
cat("  FY2025 impact:", sum(frame %in% i25$ccn), pct(mean(frame %in% i25$ccn)), "\n")
cat("  HCRIS FY2023 :", sum(frame %in% cr$ccn),  pct(mean(frame %in% cr$ccn)), "\n")
cat("  impact rows", nrow(i26), "/", nrow(i25), "  HCRIS rows", nrow(cr),
    " unique CCN", length(unique(cr$ccn)),
    " providers with >1 report", sum(table(cr$ccn) > 1), "\n")

I <- i26[match(frame, i26$ccn), ]; I <- I[!is.na(I$ccn), ]
sub_(sprintf("Block A coverage, FY2026 impact file (n = %d)", nrow(I)))
for (f in c("FY 2026 Wage Index", "Resident to Bed Ratio", "Beds", "Average Daily Census",
            "DSHPCT", "CMIV43", "TACMIV43", "Bills", "Medicare Percentage",
            "Medicaid Percentage", "Operating CCR")) {
  v <- n_(I[[f]])
  cat(sprintf("  %-24s nonblank %6s  zero %6s  ", f, pct(mean(!is.na(v))), pct(mean(v == 0, na.rm = TRUE))))
  p <- v[!is.na(v) & v > 0]
  cat(sprintf("pos n=%d p05=%.4f med=%.4f p95=%.4f\n", length(p),
              quantile(p, .05, names = FALSE), median(p), quantile(p, .95, names = FALSE)))
}
cat("  Ownership Control Type:"); print(table(I$`Ownership Control Type`))
cat("  URGEO                 :"); print(table(I$URGEO))
cat("  Provider Type         :"); print(sort(table(I$`Provider Type`), decreasing = TRUE))
cat("  FIPS County Code nonblank:", pct(mean(nzchar(trimws(I$`FIPS County Code`)))), "\n")

R_ <- cr[match(frame, cr$ccn), ]; R_ <- R_[!is.na(R_$ccn), ]
sub_(sprintf("HCRIS fiscal-year alignment against the PSI window (n = %d)", nrow(R_)))
pdt <- function(x) as.Date(trimws(x), tryFormats = c("%m/%d/%Y", "%Y-%m-%d"))
b <- pdt(R_$`Fiscal Year Begin Date`); e <- pdt(R_$`Fiscal Year End Date`)
W0 <- as.Date("2022-07-01"); W1 <- as.Date("2024-06-30")
ov <- pmax(0, as.numeric(pmin(e, W1) - pmax(b, W0)) + 1)
cat("  FY-end month:"); print(table(format(e, "%m")))
cat("  median overlap days  :", median(ov, na.rm = TRUE), "\n")
cat("  wholly inside window :", pct(mean(ov >= 364, na.rm = TRUE)), "\n")
cat("  zero overlap         :", pct(mean(ov == 0, na.rm = TRUE)), "\n")

sub_("GATE C2 -- S-3 contract labor population rate")
clab <- n_(R_$`Contract Labor: Direct Patient Care`)
sal  <- n_(R_$`Total Salaries (adjusted)`)
cat("  non-blank contract labor :", sum(!is.na(clab)), pct(mean(!is.na(clab))), "\n")
cat("  blank                    :", sum(is.na(clab)),  pct(mean(is.na(clab))), "\n")
cat("  EXACT ZEROS              :", sum(clab == 0, na.rm = TRUE), "  <- the ambiguity is blank-vs-zero, not zero-vs-missing\n")
cat("  negative                 :", sum(clab < 0, na.rm = TRUE), "\n")
cat("  min positive             :", min(clab, na.rm = TRUE), "\n")
ok  <- !is.na(clab) & !is.na(sal) & sal >= 1e6
shr <- clab[ok] / sal[ok]
cat("  computable, denom >= $1M :", sum(ok), pct(sum(ok) / N), "of the frame\n")
qtab(shr, "contract labor share")
cat("  share > 0.50 :", sum(shr > .5), " share > 1.00 :", sum(shr > 1), "\n")
cat("  denominators < $1M :", sum(!is.na(sal) & sal < 1e6), "\n")

sub_("GATE C2.e -- differential missingness (NOT on the outcome)")
J    <- i26[match(R_$ccn, i26$ccn), ]
beds <- n_(J$Beds); rural <- as.numeric(J$URGEO == "RURAL")
smd  <- function(v, g) {
  x <- v[g & !is.na(v)]; y <- v[!g & !is.na(v)]
  (mean(x) - mean(y)) / sqrt((var(x) + var(y)) / 2)
}
cat(sprintf("  n present %d, n absent %d\n", sum(ok), sum(!ok)))
cat(sprintf("  Beds   present %.3f absent %.3f  standardized diff %+.3f\n",
            mean(beds[ok], na.rm = TRUE), mean(beds[!ok], na.rm = TRUE), smd(beds, ok)))
cat(sprintf("  Rural  present %.3f absent %.3f  standardized diff %+.3f\n",
            mean(rural[ok], na.rm = TRUE), mean(rural[!ok], na.rm = TRUE), smd(rural, ok)))

sub_("derived Block A distributions")
qtab(n_(R_$`Total Days (V + XVIII + XIX + Unknown)`) / n_(R_$`Total Bed Days Available`), "occupancy")
cat("  occupancy > 1.0 :",
    sum(n_(R_$`Total Days (V + XVIII + XIX + Unknown)`) / n_(R_$`Total Bed Days Available`) > 1, na.rm = TRUE), "\n")
npr <- n_(R_$`Net Patient Revenue`); toe <- n_(R_$`Less Total Operating Expense`)
qtab((npr - toe) / npr, "operating margin")
qtab(n_(R_$`Allowable DSH Percentage`), "DSH pct (HCRIS)")
ir <- n_(R_$`Number of Interns and Residents (FTE)`)
cat("  HCRIS interns/residents FTE: blank", sum(is.na(ir)), " zero", sum(ir == 0, na.rm = TRUE),
    " positive", sum(ir > 0, na.rm = TRUE), "   <- vs impact-file explicit zeros above\n")

sub_("GATE C1 -- CMI level and drift, grouper V42 held constant")
a <- setNames(n_(i25$TACMIV42), i25$ccn)[frame]
b <- setNames(n_(i26$TACMIV42), i26$ccn)[frame]
g <- !is.na(a) & !is.na(b) & a > 0
dr <- (b[g] - a[g]) / a[g]
cat("  computable :", sum(g), pct(sum(g) / N), "\n")
qtab(a[g], "CMI level (TACMIV42, FY2025 file)", "%.3f")
qtab(dr, "relative CMI drift")
cat(sprintf("  mean %+.4f  SD %.4f   |drift|>0.10: %d (%s)   |drift|>0.20: %d (%s)   |drift|>0.50: %d\n",
            mean(dr), sd(dr), sum(abs(dr) > .1), pct(mean(abs(dr) > .1)),
            sum(abs(dr) > .2), pct(mean(abs(dr) > .2)), sum(abs(dr) > .5)))

sub_("GATE C3 -- state tort environment (DSTLR 7.1)")
cat("  DSTLR 7.1 archived at", file.path(RAW, "dstlr-7.1.xlsx"),
    "\n  terminal year 2021; 51 states; 44 distinct reform vectors.\n",
    "  Requires an xlsx reader; ported to R at Task 1.6 with the readxl dependency\n",
    "  under renv. Values here are carried from the Phase 0 spike and re-verified there.\n")

## ------------------------------------------------------------------ 0.4 ----
hdr("TASK 0.4  catchment and Block B")

h <- read.csv(file.path(RAW, "Hospital_Service_Area_2023.csv"), colClasses = "character",
              check.names = FALSE, na.strings = character(0))
h <- h[nzchar(trimws(h$MEDICARE_PROV_NUM)), ]
h$cases <- n_(h$TOTAL_CASES)
cat("  rows", nrow(h), " distinct provider numbers", length(unique(h$MEDICARE_PROV_NUM)), "\n")
cat("  suppressed cells", sum(is.na(h$cases)), pct(mean(is.na(h$cases)), 2), "\n")
cat("  SUPPRESSION THRESHOLD, min non-suppressed TOTAL_CASES =", min(h$cases, na.rm = TRUE), "\n")
cat("  max non-suppressed TOTAL_CASES =", max(h$cases, na.rm = TRUE), "\n")
cat("  frame matched to HSAF:", sum(frame %in% h$MEDICARE_PROV_NUM),
    pct(mean(frame %in% h$MEDICARE_PROV_NUM)), "\n")

hf     <- h[h$MEDICARE_PROV_NUM %in% frame, ]
ncell  <- tapply(hf$cases, hf$MEDICARE_PROV_NUM, length)
nsupp  <- tapply(hf$cases, hf$MEDICARE_PROV_NUM, function(v) sum(is.na(v)))
nobs   <- ncell - nsupp
obs    <- tapply(hf$cases, hf$MEDICARE_PROV_NUM, function(v) sum(v, na.rm = TRUE))
sub_("per-hospital, within the frame")
qtab(ncell,          "ZIP cells per hospital",       "%.0f")
qtab(nsupp / ncell,  "share of CELLS suppressed",    "%.3f")
qtab(nobs,           "OBSERVED (unsuppressed) cells","%.0f")
qtab(obs,            "observed Medicare cases",      "%.0f")
cat("  hospitals with >50% of cells suppressed:", sum(nsupp / ncell > .5),
    pct(mean(nsupp / ncell > .5)), "\n")

sub_("share of catchment CASES unobserved, by assumption about suppressed cell size")
for (k in c(1, 3, 5, 10)) qtab(k * nsupp / (obs + k * nsupp), sprintf("assume %2d case(s)/cell", k), "%.3f")

sub_("concentration of observed cases")
top <- function(kk) tapply(hf$cases, hf$MEDICARE_PROV_NUM, function(v) {
  v <- sort(v[!is.na(v)], decreasing = TRUE)
  if (!length(v) || sum(v) == 0) NA else sum(head(v, kk)) / sum(v)
})
qtab(top(5),  "share of observed cases in top 5 ZIPs",  "%.3f")
qtab(top(10), "share of observed cases in top 10 ZIPs", "%.3f")

sub_("GATE B0 -- catchment coverage")
cov <- obs / (obs + 3 * nsupp)
qtab(cov, "catch_coverage = obs/(obs+3*nsupp)", "%.3f")
inhs <- frame %in% names(nobs)
failg <- sum(!inhs) + sum(nobs[frame[inhs]] < 3 | obs[frame[inhs]] < 100)
cat("  B0.a hospitals needing the county fallback:", failg, pct(failg / N, 2), "\n")
cat("  ... of which absent from HSAF entirely    :", sum(!inhs), "\n")
cat("  B0.b threshold 0.10 ->", if (failg / N <= .10) "PASS" else "FAIL", "\n")
cat("  B0.e median catch_coverage", sprintf("%.3f", median(cov, na.rm = TRUE)),
    "vs threshold 0.60 ->", if (median(cov, na.rm = TRUE) >= .60) "PASS" else "FAIL", "\n")
cat("  hospitals with 0 observed cells:", sum(nobs == 0), "  <5 cells:", sum(nobs < 5),
    "  <10 cells:", sum(nobs < 10), "  <100 observed cases:", sum(obs < 100), "\n")

sub_("SVI 2022 -- four themes present, and two Block B covariates come free")
svi <- readLines(file.path(RAW, "SVI_2022_US.csv"), n = 1)
cols <- strsplit(gsub('"', "", svi), ",")[[1]]
cat("  columns:", length(cols), "\n")
for (v in c("RPL_THEME1", "RPL_THEME2", "RPL_THEME3", "RPL_THEME4", "RPL_THEMES",
            "EP_UNINSUR", "EP_LIMENG", "FIPS")) {
  cat(sprintf("  %-12s %s\n", v, if (v %in% cols) "present" else "ABSENT"))
}
cat("\n  SVI 2022 is built on ACS 2018-2022 5-year estimates.\n")
gap <- as.numeric(as.Date("2023-07-01") - as.Date("2020-07-01")) / 365.25
cat(sprintf("  SVI data midpoint 2020-07-01; PSI window midpoint 2023-07-01; GAP = %.1f years\n", gap))

hdr("done")
