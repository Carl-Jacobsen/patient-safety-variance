# R/blockA-coverage.R  --  Task 1.3 verification
#
# The gate: every Block A covariate named in plan section 4 -- beds, ownership,
# teaching intensity, case mix index, DSH percentage, wage index, system
# membership, occupancy, operating margin, uncompensated care burden -- resolves
# at >= 99% coverage against the frame of n = 2,801.
#
# Vintage split, per spike-structure.md section 2 and phase1-readiness.md 6.1:
#   FY 2025 Impact File (Correction Notice)  case mix and volume. Built on FY 2023
#                                            MedPAR, which sits inside the PSI window.
#   FY 2026 Impact File (Final Rule)         payment-policy and structural fields.
#                                            Built on FY 2024 MedPAR, which overlaps
#                                            only the window's last quarter.
# This is carried as a specification axis in Phase 3, not a silent default, so
# both vintages are measured here.
#
# Parse traps exercised rather than described: the Impact File .txt is latin-1
# with its header on line 2; the Cost Report PUF has CCNs with more than one
# report; the POS and Hospital All Owners files are latin-1 too.
#
# Base R plus nothing. Reads the permanent Task 1.3 layout.

BA <- file.path("data-raw", "blockA")
CC <- file.path("data-raw", "careCompare_2022Q3-2024Q2")

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

## Impact file: latin-1, header on line 2, tab-delimited, ragged tail.
impact <- function(zipfile, member) {
  td <- tempfile(); dir.create(td)
  unzip(file.path(BA, zipfile), files = member, exdir = td)
  L <- readLines(file.path(td, member), encoding = "latin1", warn = FALSE)
  h <- strsplit(L[2], "\t")[[1]]
  b <- L[-(1:2)]; b <- b[nzchar(trimws(b))]
  m <- do.call(rbind, lapply(strsplit(b, "\t", fixed = TRUE),
                             function(v) { length(v) <- length(h); v }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- h
  d$ccn <- formatC(trimws(d$`Provider Number`), width = 6, flag = "0")
  d
}

hdr("TASK 1.3  Block A coverage against the frame")

## ---- the frame, rebuilt from the outcome layer -----------------------------
cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
p90 <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame)
cat("  frame n =", N, "\n")

i26 <- impact("fy2026-ipps-fr-impact-file.zip", "FY 2026 IPPS Final Rule Impact File.txt")
i25 <- impact("fy-2025-ipps-fr-impact-file.zip", "FY 2025 IPPS Impact File - Correction Notice.txt")
cr  <- rd(file.path(BA, "CostReport_2023_Final.csv"))
cr$ccn <- formatC(trimws(cr$`Provider CCN`), width = 6, flag = "0")

sub_("source match rates -- standing rule 4 wants the misses named, not counted")
for (nm in c("FY2026 impact", "FY2025 impact", "HCRIS PUF FY2023")) {
  v <- switch(nm, "FY2026 impact" = i26$ccn, "FY2025 impact" = i25$ccn, cr$ccn)
  miss <- setdiff(frame, v)
  cat(sprintf("  %-18s %4d / %d  %s   unmatched: %s\n", nm, sum(frame %in% v), N,
              pct(mean(frame %in% v)),
              if (length(miss)) paste(miss, collapse = " ") else "none"))
}
cat(sprintf("  HCRIS rows %d, unique CCN %d, providers filing more than one report %d",
            nrow(cr), length(unique(cr$ccn)), sum(table(cr$ccn) > 1)))
cat("   <- deduplicate deliberately at Task 2.3\n")

## ---- system membership ------------------------------------------------------
## POS was the plan's route and it is a dead end: MLT_FAC_ORG_NAME and
## MLT_OWND_FAC_ORG_SW are empty for every one of the file's rows. Measured, not
## assumed -- see below. The substitute is the enrollment/ownership pair.
pos <- rd(file.path(BA, "Hospital_and_other.DATA.Q2_2026.csv"), enc = "latin1")
pos$ccn <- formatC(trimws(pos$PRVDR_NUM), width = 6, flag = "0")
en  <- rd(file.path(BA, "Hospital_Enrollments_2026.07.31.csv"))
ow  <- rd(file.path(BA, "Hospital_All_Owners_2026.07.31.csv"), enc = "latin1")
ecc <- trimws(en$CCN)
en$ccn <- substr(ifelse(nchar(ecc) == 5, paste0("0", ecc), ecc), 1, 6)
ow$ccn <- setNames(en$ccn, en$`ENROLLMENT ID`)[ow$`ENROLLMENT ID`]

sub_("system membership: why it is not the Provider of Services file")
for (v in c("MLT_FAC_ORG_NAME", "MLT_OWND_FAC_ORG_SW", "CHOW_SW", "GNRL_CNTL_TYPE_CD")) {
  x <- trimws(pos[[v]])
  cat(sprintf("  POS %-22s non-blank %6d of %d  %s\n", v, sum(nzchar(x)), nrow(pos), pct(mean(nzchar(x)))))
}
cat("  The two multi-facility columns are empty for EVERY row of the Q2 2026 release.\n")
cat("  POS matches the frame at ", pct(mean(frame %in% pos$ccn)),
    " on CCN, so it stays as the identifier fallback -- but it cannot carry system membership.\n", sep = "")

owf <- ow[!is.na(ow$ccn) & ow$ccn %in% frame, ]
org <- owf[nzchar(trimws(owf$`ORGANIZATION NAME - OWNER`)), ]
key <- toupper(trimws(org$`ASSOCIATE ID - OWNER`))
sizes <- tapply(org$ccn, key, function(v) length(unique(v)))
multi <- names(sizes)[sizes > 1]
in_multi <- unique(org$ccn[key %in% multi])

sub_("system membership from Hospital Enrollments + Hospital All Owners")
cat(sprintf("  frame matched to Hospital Enrollments on CCN     %4d  %s\n",
            sum(frame %in% en$ccn), pct(mean(frame %in% en$ccn))))
cat(sprintf("  frame hospitals with at least one owner record   %4d  %s   <- the coverage that counts\n",
            length(unique(owf$ccn)), pct(length(unique(owf$ccn)) / N)))
cat(sprintf("  ... of which have an ORGANIZATION owner          %4d  %s\n",
            length(unique(org$ccn)), pct(length(unique(org$ccn)) / N)))
cat(sprintf("  ... in an org owning more than one frame hospital%4d  %s\n",
            length(in_multi), pct(length(in_multi) / N)))
cat(sprintf("  distinct owner organisations %d, of which %d span more than one frame hospital\n",
            length(sizes), sum(sizes > 1)))
cat("  largest, by frame hospitals owned:\n")
top <- head(sort(sizes, decreasing = TRUE), 5)
nmap <- setNames(trimws(org$`ORGANIZATION NAME - OWNER`), key)
for (k in names(top)) cat(sprintf("    %-42s %4d\n", substr(nmap[[k]], 1, 42), top[[k]]))
cat("  NOTE: a hospital with only individual owners is not missing data -- it is a\n")
cat("  hospital that is genuinely not owned by an organisation. The missingness is the\n")
cat("  3.7%% with no owner record at all.\n")

## ---- the gate ---------------------------------------------------------------
I26 <- i26[match(frame, i26$ccn), ]
I25 <- i25[match(frame, i25$ccn), ]
R_  <- cr[match(frame, cr$ccn), ]

cov_impact <- function(d, field) mean(!is.na(n_(d[[field]])))
cov_chr    <- function(d, field) mean(!is.na(d[[field]]) & nzchar(trimws(d[[field]])))

npr <- n_(R_$`Net Patient Revenue`); toe <- n_(R_$`Less Total Operating Expense`)
margin_ok <- !is.na(npr) & !is.na(toe) & npr != 0
occ_imp   <- !is.na(n_(I26$`Average Daily Census`)) & !is.na(n_(I26$Beds)) & n_(I26$Beds) > 0
uncomp_ok <- !is.na(n_(R_$`Cost of Uncompensated Care`))

gate <- data.frame(
  covariate = c("Beds", "Ownership", "Teaching intensity", "Case mix index",
                "DSH percentage", "Wage index", "System membership", "Occupancy",
                "Operating margin", "Uncompensated care burden"),
  source = c("Impact FY2026 `Beds`", "Impact FY2026 `Ownership Control Type`",
             "Impact FY2026 `Resident to Bed Ratio`", "Impact FY2025 `TACMIV42`",
             "Impact FY2026 `DSHPCT`", "Impact FY2026 `FY 2026 Wage Index`",
             "Enrollments + All Owners", "Impact FY2026 ADC / Beds",
             "HCRIS `Net Patient Revenue`, `Less Total Operating Expense`",
             "HCRIS `Cost of Uncompensated Care`"),
  coverage = c(cov_impact(I26, "Beds"), cov_chr(I26, "Ownership Control Type"),
               cov_impact(I26, "Resident to Bed Ratio"), cov_impact(I25, "TACMIV42"),
               cov_impact(I26, "DSHPCT"), cov_impact(I26, "FY 2026 Wage Index"),
               length(unique(owf$ccn)) / N, mean(occ_imp),
               mean(margin_ok), mean(uncomp_ok)),
  stringsAsFactors = FALSE)
gate$verdict <- ifelse(gate$coverage >= 0.99, "PASS", "BELOW GATE")

hdr("THE GATE: every plan section 4 Block A covariate at >= 99% of the frame")
cat(sprintf("  %-27s %-58s %8s  %s\n", "covariate", "source", "coverage", "verdict"))
for (i in seq_len(nrow(gate))) {
  cat(sprintf("  %-27s %-58s %8s  %s\n", gate$covariate[i], gate$source[i],
              pct(gate$coverage[i], 2), gate$verdict[i]))
}
cat(sprintf("\n  %d of %d at or above 99%%.\n", sum(gate$verdict == "PASS"), nrow(gate)))

## ---- can the two short covariates be lifted to 99%? -------------------------
## Standing rule 7 says recover before imputing: a value in an adjacent fiscal
## year is observed data, not imputation. So the question is not "impute or
## not", it is "what is the ceiling once recovery is exhausted". Measured, using
## the FY 2022 Cost Report PUF -- the same dataset, one release earlier.
c22 <- rd(file.path(BA, "CostReport_2022_Final.csv"))
c22$ccn <- formatC(trimws(c22$`Provider CCN`), width = 6, flag = "0")
P22 <- c22[match(frame, c22$ccn), ]

sub_("recovery ceiling for uncompensated care and operating margin")
u23 <- n_(R_$`Cost of Uncompensated Care`);              u22 <- n_(P22$`Cost of Uncompensated Care`)
t23 <- n_(R_$`Total Unreimbursed and Uncompensated Care`); t22 <- n_(P22$`Total Unreimbursed and Uncompensated Care`)
cat(sprintf("  FY2022 PUF: %d rows, %d unique CCN, frame match %s\n",
            nrow(c22), length(unique(c22$ccn)), pct(mean(frame %in% c22$ccn), 2)))
cat(sprintf("  uncompensated care, FY2023 only                    %s\n", pct(mean(!is.na(u23)), 2)))
cat(sprintf("  ... plus FY2022 cross-year fill                    %s   (+%d hospitals)\n",
            pct(mean(!is.na(u23) | !is.na(u22)), 2), sum(is.na(u23) & !is.na(u22))))
cat(sprintf("  ... plus the broader column, either year           %s   <- THE CEILING\n",
            pct(mean(!is.na(u23) | !is.na(u22) | !is.na(t23) | !is.na(t22)), 2)))
n22 <- n_(P22$`Net Patient Revenue`); o22 <- n_(P22$`Less Total Operating Expense`)
m22 <- !is.na(n22) & !is.na(o22) & n22 != 0
cat(sprintf("  operating margin, FY2023 only %s   plus FY2022 fill %s\n",
            pct(mean(margin_ok), 2), pct(mean(margin_ok | m22), 2)))
cat("  READ: uncompensated care cannot reach 99% from the public HCRIS PUF, in any\n")
cat("  combination of column and vintage. The shortfall is structural, not a\n")
cat("  retrieval failure, and it is a decision for Task 2.6, not a reason to wait.\n")

## ---- is the missingness differential? ---------------------------------------
## The question that decides whether the two sub-99% covariates can be dropped
## or imputed casually. Two per cent lost AT RANDOM costs almost nothing at
## n = 2,801. Two per cent lost SYSTEMATICALLY, from the small and rural end,
## costs a limb of the equity gradient the study exists to measure.
##
## Tested on COVARIATES ONLY, never on the outcome -- the same rule gate C2.e
## follows. Screening missingness against PSI-90 would be peeking at the
## dependent variable to choose a handling rule, which is exactly the
## researcher degree of freedom the specification-curve design is built to
## remove.
smd <- function(v, g) {
  x <- v[g & !is.na(v)]; y <- v[!g & !is.na(v)]
  if (length(x) < 2 || length(y) < 2) return(NA_real_)
  (mean(x) - mean(y)) / sqrt((var(x) + var(y)) / 2)
}
beds  <- n_(I26$Beds)
rural <- as.numeric(I26$URGEO == "RURAL")
vol   <- n_(I25$Bills)

sub_("differential missingness of the two sub-99% covariates")
tests <- list(
  "uncompensated care present" = uncomp_ok,
  "system membership present"  = frame %in% unique(owf$ccn))
cat(sprintf("  %-30s %8s %10s %10s %10s\n", "", "n absent", "SMD beds", "SMD rural", "SMD volume"))
for (nm in names(tests)) {
  g <- tests[[nm]]
  cat(sprintf("  %-30s %8d %10.3f %10.3f %10.3f\n", nm, sum(!g),
              smd(beds, g), smd(rural, g), smd(vol, g)))
}
cat(sprintf("\n  For scale, gate C2.e judged S-3 contract labour DIFFERENTIAL at SMD beds\n"))
cat(sprintf("  +0.462 and rural -0.269, and admitted it only with a missingness indicator.\n"))
cat("  A |SMD| under about 0.10 is the conventional balance threshold.\n")

sub_("also present, not in the plan's list, and wanted downstream")
for (f in c("Bills", "Medicare Percentage", "Medicaid Percentage", "URGEO",
            "FIPS County Code", "Provider Type")) {
  d <- if (f == "Bills") I25 else I26
  v <- if (f %in% c("Bills", "Medicare Percentage", "Medicaid Percentage")) cov_impact(d, f) else cov_chr(d, f)
  cat(sprintf("  %-22s %-16s %s\n", f, if (identical(d, I25)) "Impact FY2025" else "Impact FY2026", pct(v, 2)))
}

sub_("vintage: the two Impact Files disagree, which is why the choice is an axis")
a <- setNames(n_(i25$TACMIV42), i25$ccn)[frame]; b <- setNames(n_(i26$TACMIV42), i26$ccn)[frame]
g <- !is.na(a) & !is.na(b) & a > 0
cat(sprintf("  TACMIV42 computable in both vintages          %4d  %s\n", sum(g), pct(sum(g) / N)))
cat(sprintf("  median FY2025 %.3f   median FY2026 %.3f   correlation %.4f\n",
            median(a[g]), median(b[g]), cor(a[g], b[g])))
va <- n_(I25$Bills); vb <- n_(I26$Bills); gv <- !is.na(va) & !is.na(vb) & va > 0
cat(sprintf("  Bills (Medicare volume) median FY2025 %.0f   FY2026 %.0f   correlation %.4f\n",
            median(va[gv]), median(vb[gv]), cor(va[gv], vb[gv])))
cat("  Case mix and volume take FY2025: its MedPAR year sits inside the PSI window.\n")
cat("  Payment-policy fields take FY2026. Phase 3 enumerates the choice.\n")

hdr("done")
