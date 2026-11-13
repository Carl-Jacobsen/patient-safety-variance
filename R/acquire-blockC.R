# R/acquire-blockC.R  --  Task 1.6, Block C candidates
#
# Block C is three covariates from three very different places, and most of the
# data is already on disk from earlier tasks:
#
#   coding / surveillance intensity   TACMIV42 from the FY2025 AND FY2026 IPPS
#                                     Impact Files (already acquired at Task 1.3
#                                     as ipps_impact_fy2025 / ipps_impact_fy2026).
#                                     Differencing the SAME field across the two
#                                     MedPAR years holds the DRG grouper constant
#                                     -- that is the drift measure; it is not
#                                     TACMIV42 vs TACMIV43.
#   staffing instability              Contract Labor: Direct Patient Care over
#                                     Total Salaries (adjusted). The curated PUF
#                                     (hcris_puf_fy2023) covers 90.7% of the
#                                     frame. This task RAISES that by recovering
#                                     real values, never by imputing:
#                                       1. raw HCRIS Worksheet S-3 Part II, which
#                                          carries lines the PUF drops  <- NEW
#                                          download, HOSP10FY2023.zip, 137 MB
#                                       2. the FY2022 PUF (hcris_puf_fy2022) for
#                                          cross-year fill
#                                     Every value is tagged in contract_labor_source
#                                     so Task 2.7 knows what it is looking at.
#   state tort environment            Database of State Tort Law Reforms 7.1
#                                     (Avraham). Acquired in Phase 0; this task
#                                     moves it into data-raw/blockC/.
#
# Standing rule 7: recover before imputing. README rule 7 names raw HCRIS and the
# adjacent fiscal year explicitly. This stage is where that recovery happens.
#
# VERIFY here is acquisition only -- no admission judgment. The Block C gates
# (C1, C2, C3 in admission-gates.md) run at Task 2.7.

suppressPackageStartupMessages({ library(data.table); library(readxl) })
source(file.path("R", "provenance.R"))

BC <- file.path("data-raw", "blockC")
BA <- file.path("data-raw", "blockA")
CC <- file.path("data-raw", "careCompare_2022Q3-2024Q2")

HCRIS_URL <- "https://downloads.cms.gov/files/hcris/HOSP10FY2023.zip"
DSTLR_URL <- "https://law.utexas.edu/faculty/ravraham/dstlr-7.1-regular-102621.xlsx"

BLOCKC_SOURCES <- data.frame(
  source_id = c("hcris_raw_hosp10_fy2023", "dstlr_7_1"),
  file = c(file.path(BC, "HOSP10FY2023.zip"), file.path(BC, "dstlr-7.1.xlsx")),
  url  = c(HCRIS_URL, DSTLR_URL),
  stringsAsFactors = FALSE)

rd  <- function(p, ...) read.csv(p, colClasses = "character", check.names = FALSE,
                                 na.strings = character(0), ...)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

## Impact file: latin-1, header on line 2, tab-delimited, ragged tail.
## (same shape as R/blockA-coverage.R's helper -- Block C only needs one column)
impact <- function(zipfile, member) {
  td <- tempfile(); dir.create(td)
  utils::unzip(file.path(BA, zipfile), files = member, exdir = td)
  L <- readLines(file.path(td, member), encoding = "latin1", warn = FALSE)
  h <- strsplit(L[2], "\t")[[1]]
  b <- L[-(1:2)]; b <- b[nzchar(trimws(b))]
  m <- do.call(rbind, lapply(strsplit(b, "\t", fixed = TRUE),
                             function(v) { length(v) <- length(h); v }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- h
  d$ccn <- formatC(trimws(d$`Provider Number`), width = 6, flag = "0")
  d
}

## 62 CCNs file more than one report. For a given numeric field, take the value
## from the CCN's best report, where "best" is: a non-blank value first, then the
## longest fiscal period (the annual filing), then the latest period end. Ten of
## the 62 have the field blank in some FY2023 reports but not others, so the
## non-blank preference matters and a plain longest-period dedup would lose them.
## Returns a named vector: value per CCN in `want`.
best_by_ccn <- function(ccn, value, period_len, period_end, want) {
  o <- order(ccn, is.na(value), -period_len, -as.numeric(period_end))
  keep <- o[!duplicated(ccn[o])]
  setNames(value[keep], ccn[keep])[want]
}

hdr("TASK 1.6  Block C candidates -- acquisition and deterministic recovery")

## ---------------------------------------------------------------- files ----
sub_("files")
prov <- tryCatch(prov_read(), error = function(e) NULL)
for (i in seq_len(nrow(BLOCKC_SOURCES))) {
  f <- BLOCKC_SOURCES$file[i]; sid <- BLOCKC_SOURCES$source_id[i]
  if (!file.exists(f)) {
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("  %-24s downloading ...\n", sid))
    ok <- tryCatch({ utils::download.file(BLOCKC_SOURCES$url[i], f, quiet = TRUE, mode = "wb"); TRUE },
                   error = function(e) { message("    FAILED: ", conditionMessage(e)); FALSE })
    if (!ok) next
  }
  h <- sha256_file(f)
  rec <- if (!is.null(prov) && sid %in% prov$source_id) prov$sha256[prov$source_id == sid] else NA_character_
  status <- if (is.na(rec)) "no provenance row yet" else
            if (identical(h, rec)) "sha256 MATCHES provenance" else "*** sha256 MISMATCH ***"
  cat(sprintf("  %-24s %8.1f MB  %s  %s\n", sid, file.size(f) / 1e6, substr(h, 1, 16), status))
}

zip <- file.path(BC, "HOSP10FY2023.zip")
dstlr <- file.path(BC, "dstlr-7.1.xlsx")
have_hcris <- file.exists(zip)
have_dstlr <- file.exists(dstlr)

## ------------------------------------------------------------- the frame ---
cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
p90 <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
cat(sprintf("\n  frame n = %d\n", length(frame)))

## ============================================ coding / surveillance intensity
sub_("VERIFY: coding intensity -- TACMIV42 in BOTH Impact Files (already acquired)")
i25 <- impact("fy-2025-ipps-fr-impact-file.zip", "FY 2025 IPPS Impact File - Correction Notice.txt")
i26 <- impact("fy2026-ipps-fr-impact-file.zip", "FY 2026 IPPS Final Rule Impact File.txt")
has25 <- "TACMIV42" %in% names(i25); has26 <- "TACMIV42" %in% names(i26)
cat(sprintf("  TACMIV42 present  FY2025 file %s   FY2026 file %s\n", has25, has26))
if (has25 && has26) {
  l25 <- setNames(n_(i25$TACMIV42), i25$ccn)[frame]
  l26 <- setNames(n_(i26$TACMIV42), i26$ccn)[frame]
  drift <- (l26 - l25) / l25
  cat(sprintf("  level  (FY2025 file): coverage %s   median %.3f\n",
              pct(mean(!is.na(l25)), 1), median(l25, na.rm = TRUE)))
  cat(sprintf("  drift  = (FY2026 - FY2025)/FY2025: coverage %s   median %.4f   SD %.4f\n",
              pct(mean(is.finite(drift)), 1), median(drift[is.finite(drift)]), sd(drift[is.finite(drift)])))
  cat("  (C1 preview only; gate C1 runs at Task 2.7. Spike baselines: coverage 100.0% /\n")
  cat("   99.8%, drift SD 0.0527 -- see spike-structure.md section 6)\n")
}

## ===================================================== state tort environment
if (have_dstlr) {
  sub_("VERIFY: Database of State Tort Law Reforms 7.1")
  sh <- excel_sheets(dstlr)
  cat(sprintf("  sheets: %s\n", paste(sh, collapse = " | ")))
  dd <- suppressWarnings(read_excel(dstlr, sheet = "DATA"))
  cat(sprintf("  DATA: %d rows x %d cols; year range %d-%d; %d states; %d rows in 2021\n",
              nrow(dd), ncol(dd), min(dd$year, na.rm = TRUE), max(dd$year, na.rm = TRUE),
              length(unique(dd$state)), sum(dd$year == 2021, na.rm = TRUE)))
  cat("  PARSE TRAP: at least one numeric column carries a text value ('1890s') deep in\n")
  cat("  the sheet -- read_excel must widen it to character, so read the whole sheet as\n")
  cat("  text at Task 2.7 rather than trusting column type inference.\n")
  cat("  (gate C3 -- terminal year 2021, >= 20 distinct reform vectors, <= 4.0-year gap --\n")
  cat("   runs at Task 2.7. Spike measured 44 vectors, 2.5-year gap.)\n")
}

## ===================================================== staffing instability ==
## The one piece of real work in this task: raise the contract-labor population
## rate above the PUF's 90.7% with OBSERVED values, then stop.
if (have_hcris) {
  sub_("RECOVER: contract labor -- PUF, then raw HCRIS S-3 Part II, then cross-year")

  puf_field <- function(path, field) {
    d <- rd(path)
    ccn <- formatC(trimws(d$`Provider CCN`), width = 6, flag = "0")
    b <- as.Date(d$`Fiscal Year Begin Date`, "%Y-%m-%d")
    e <- as.Date(d$`Fiscal Year End Date`, "%Y-%m-%d")
    best_by_ccn(ccn, n_(d[[field]]), as.numeric(e - b), e, frame)
  }
  cl_puf23  <- puf_field(file.path(BA, "CostReport_2023_Final.csv"), "Contract Labor: Direct Patient Care")
  sal_puf23 <- puf_field(file.path(BA, "CostReport_2023_Final.csv"), "Total Salaries (adjusted)")
  cl_puf22  <- puf_field(file.path(BA, "CostReport_2022_Final.csv"), "Contract Labor: Direct Patient Care")
  sal_puf22 <- puf_field(file.path(BA, "CostReport_2022_Final.csv"), "Total Salaries (adjusted)")

  ## raw HCRIS: rpt gives RPT_REC_NUM -> CCN and the fiscal period; S-3 Part II
  ## (worksheet S300002) line 11 is Contract Labor: Direct Patient Care, line 1
  ## is Total Salaries (adjusted). Column 4 is the reported figure, column 2 its
  ## near-duplicate -- fall back to it only when 4 is absent. A CCN's value is
  ## taken from its best report by the same non-blank-then-longest-period rule.
  rpt <- fread(cmd = sprintf("unzip -p %s HOSP10_2023_rpt.csv", shQuote(zip)),
               header = FALSE, colClasses = "character", showProgress = FALSE)
  rpt_ccn <- formatC(trimws(rpt$V3), width = 6, flag = "0")
  rb <- as.Date(rpt$V6, "%m/%d/%Y"); re <- as.Date(rpt$V7, "%m/%d/%Y")
  rpt_len <- as.numeric(re - rb)
  ccn_of  <- setNames(rpt_ccn, rpt$V1)
  len_of  <- setNames(rpt_len, rpt$V1)
  end_of  <- setNames(as.numeric(re), rpt$V1)

  s3 <- fread(cmd = sprintf("unzip -p %s HOSP10_2023_nmrc.csv | grep -E '^[0-9]+,S300002,'", shQuote(zip)),
              header = FALSE, colClasses = "character", showProgress = FALSE)
  setnames(s3, c("rrn", "wksht", "line", "clmn", "val"))
  by_rrn <- function(ln, cl) { x <- s3[line == ln & clmn == cl]; setNames(n_(x$val), x$rrn) }
  cl_c4 <- by_rrn("01100", "00400"); cl_c2 <- by_rrn("01100", "00200")
  sal_c4 <- by_rrn("00100", "00400")

  ## value per report number, then collapse to one value per frame CCN
  rrn <- rpt$V1
  raw_cl_rrn  <- ifelse(is.na(cl_c4[rrn]), cl_c2[rrn], cl_c4[rrn])
  raw_sal_rrn <- unname(sal_c4[rrn])
  raw_cl  <- best_by_ccn(ccn_of[rrn], raw_cl_rrn,  len_of[rrn], end_of[rrn], frame)
  raw_sal <- best_by_ccn(ccn_of[rrn], raw_sal_rrn, len_of[rrn], end_of[rrn], frame)

  ## agreement check: where the PUF and raw both have a value, do they match?
  both <- !is.na(cl_puf23) & !is.na(raw_cl) & cl_puf23 > 0
  cat(sprintf("  raw S-3 L11 present for frame        %d   (PUF has %d)\n",
              sum(!is.na(raw_cl)), sum(!is.na(cl_puf23))))
  cat(sprintf("  PUF vs raw where both present        %d hospitals, median |rel diff| %.5f\n",
              sum(both), median(abs((raw_cl[both] - cl_puf23[both]) / cl_puf23[both]))))

  ## the recovery hierarchy: FY2023 observed beats FY2022 observed beats missing
  src <- ifelse(!is.na(cl_puf23), "puf_fy2023",
         ifelse(!is.na(raw_cl),   "raw_s3_fy2023",
         ifelse(!is.na(cl_puf22), "puf_fy2022", "missing")))
  contract_labor <- ifelse(src == "puf_fy2023", cl_puf23,
                    ifelse(src == "raw_s3_fy2023", raw_cl,
                    ifelse(src == "puf_fy2022", cl_puf22, NA_real_)))
  total_salaries <- ifelse(!is.na(sal_puf23), sal_puf23,
                    ifelse(!is.na(raw_sal), raw_sal, sal_puf22))

  tb <- table(factor(src, c("puf_fy2023", "raw_s3_fy2023", "puf_fy2022", "missing")))
  cat("\n  contract_labor_source:\n")
  for (nm in names(tb)) cat(sprintf("    %-16s %5d   %s\n", nm, tb[[nm]], pct(tb[[nm]] / length(frame), 1)))

  base_rate <- mean(!is.na(cl_puf23))
  new_rate  <- mean(src != "missing")
  share_ok  <- mean(src != "missing" & !is.na(total_salaries) & total_salaries >= 1e6)
  cat(sprintf("\n  population rate   PUF baseline %s  ->  after recovery %s   (+%d hospitals)\n",
              pct(base_rate, 1), pct(new_rate, 1), sum(src != "missing") - sum(!is.na(cl_puf23))))
  cat(sprintf("  contract-labor SHARE computable (value + denominator >= $1M)  %s\n", pct(share_ok, 1)))
  cat("  the remaining missing are genuinely missing -- neither year, neither source. They\n")
  cat("  go to multiple imputation at Task 2.7 (admission-gates.md A1), not a zero floor.\n")

  out <- data.frame(ccn = frame,
                    contract_labor = contract_labor,
                    total_salaries = total_salaries,
                    contract_labor_share = ifelse(!is.na(total_salaries) & total_salaries >= 1e6,
                                                  contract_labor / total_salaries, NA_real_),
                    contract_labor_source = src,
                    stringsAsFactors = FALSE)
  if (!dir.exists("data")) dir.create("data")
  utils::write.csv(out, file.path("data", "blockC_contract_labor.csv"), row.names = FALSE)
  cat(sprintf("\n  wrote data/blockC_contract_labor.csv  (%d rows, one per frame CCN)\n", nrow(out)))
}

hdr("done")
