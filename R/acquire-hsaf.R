# R/acquire-hsaf.R  --  Task 1.5, the Hospital Service Area File
#
# Two sources, and they are a matched pair by design:
#
#   HSAF CY 2023   CMS Hospital Service Area File, the calendar year centred on
#                  the PSI window midpoint. Hospital x patient-ZIP Medicare
#                  discharge counts -- the raw material of the catchment engine
#                  at Task 2.4. Acquired and hashed in Phase 0; this task moves
#                  it into the permanent layout and writes its provenance row.
#                  CY 2024 rides along because stage 1b's cross-vintage
#                  suppression-recovery test reads it.
#   Dartmouth      Dartmouth Atlas ZIP->HSA/HRR crosswalk (ZipHsaHrr19). Free,
#                  no registration, and -- the point -- SUPPRESSION-FREE: it
#                  assigns each ZIP to exactly one hospital service area by
#                  plurality of Medicare admissions. Coarser than a weighted
#                  catchment (whole-ZIP assignment, no weights) but a genuinely
#                  independent construction. It becomes the robustness column
#                  at Task 2.5, the thing a reviewer checks the weighted result
#                  against.
#
# HSAF comes through the data.cms.gov DCAT catalogue: every file URL there
# carries a dated release path that rotates, so the durable recipe is
# https://data.cms.gov/data.json -> dataset "Hospital Service Area" ->
# the distribution whose filename ends in the wanted year. The Dartmouth file
# is a static URL on a publisher that does not rotate paths.
#
# Same contract as every other acquisition stage: idempotent, downloads only
# what is missing, verifies what is present against the sha256 in sources.csv.

suppressPackageStartupMessages(library(jsonlite))
source(file.path("R", "provenance.R"))
source(file.path("R", "hsaf.R"))

CMS_CATALOG <- "https://data.cms.gov/data.json"
HSAF <- file.path("data-raw", "hsaf")
DART <- file.path("data-raw", "dartmouth")
CC   <- file.path("data-raw", "careCompare_2022Q3-2024Q2")

DART_URL <- "https://data.dartmouthatlas.org/downloads/geography/ZipHsaHrr19.csv.zip"
DART_MEMBER <- "ZipHsaHrr19.csv"

HSAF_SOURCES <- data.frame(
  source_id = c("hsaf_2023", "hsaf_2024", "dartmouth_ziphsahrr19"),
  file = c(file.path(HSAF, "Hospital_Service_Area_2023.csv"),
           file.path(HSAF, "Hospital_Service_Area_2024.csv"),
           file.path(DART, "ZipHsaHrr19.csv.zip")),
  # match against the distribution filename; NA => the Dartmouth static URL
  cms_year = c("Hospital_Service_Area_2023.csv", "Hospital_Service_Area_2024.csv", NA),
  stringsAsFactors = FALSE)

rd  <- function(p, ...) read.csv(p, colClasses = "character", check.names = FALSE,
                                 na.strings = character(0), ...)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 2) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

## data.cms.gov DCAT: dataset title -> named vector of downloadURLs by basename
cms_hsaf_urls <- function(url = CMS_CATALOG) {
  j <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                error = function(e) { message("  catalogue unreachable: ", conditionMessage(e)); NULL })
  if (is.null(j)) return(NULL)
  hit <- Filter(function(x) identical(x$title, "Hospital Service Area"), j$dataset)
  if (!length(hit)) return(NULL)
  d <- hit[[1]]$distribution
  u <- vapply(d, function(z) if (is.null(z$downloadURL)) "" else z$downloadURL, character(1))
  u <- u[nzchar(u)]
  list(urls = setNames(u, basename(u)),
       modified = if (is.null(hit[[1]]$modified)) "" else hit[[1]]$modified,
       license  = if (is.null(hit[[1]]$license))  "" else hit[[1]]$license)
}

hdr("TASK 1.5  Hospital Service Area File -- acquisition and verification")

cat("  CMS catalogue : ", CMS_CATALOG, "\n", sep = "")
cat("  Dartmouth     : ", DART_URL, "\n", sep = "")
cms <- cms_hsaf_urls()
if (!is.null(cms)) {
  sub_("CMS catalogue resolution")
  cat("  dataset 'Hospital Service Area'  modified ", cms$modified,
      "   licence ", cms$license, "\n", sep = "")
  for (nm in HSAF_SOURCES$cms_year[!is.na(HSAF_SOURCES$cms_year)]) {
    cat(sprintf("  %-32s %s\n", nm, if (nm %in% names(cms$urls)) cms$urls[[nm]] else "*** NOT IN CATALOGUE ***"))
  }
}

sub_("files")
prov <- tryCatch(prov_read(), error = function(e) NULL)
for (i in seq_len(nrow(HSAF_SOURCES))) {
  f <- HSAF_SOURCES$file[i]; sid <- HSAF_SOURCES$source_id[i]
  if (!file.exists(f)) {
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    src <- if (is.na(HSAF_SOURCES$cms_year[i])) DART_URL
           else if (!is.null(cms) && HSAF_SOURCES$cms_year[i] %in% names(cms$urls)) cms$urls[[HSAF_SOURCES$cms_year[i]]]
           else NA_character_
    if (is.na(src)) { cat(sprintf("  %-22s ABSENT and unresolved (no network?)\n", sid)); next }
    cat(sprintf("  %-22s downloading ...\n", sid))
    ok <- tryCatch({ utils::download.file(src, f, quiet = TRUE, mode = "wb"); TRUE },
                   error = function(e) { message("    FAILED: ", conditionMessage(e)); FALSE })
    if (!ok) next
  }
  h <- sha256_file(f)
  rec <- if (!is.null(prov) && sid %in% prov$source_id) prov$sha256[prov$source_id == sid] else NA_character_
  status <- if (is.na(rec)) "no provenance row yet" else
            if (identical(h, rec)) "sha256 MATCHES provenance" else "*** sha256 MISMATCH ***"
  cat(sprintf("  %-22s %8.1f MB  %s  %s\n", sid, file.size(f) / 1e6, substr(h, 1, 16), status))
}

## --------------------------------------------------------------------------
## HSAF CY 2023 -- the suppression measurement Phase 0 made, reproduced
## --------------------------------------------------------------------------
f23 <- file.path(HSAF, "Hospital_Service_Area_2023.csv")
if (file.exists(f23)) {
  sub_("VERIFY: HSAF CY 2023 -- the parse trap, fixed, and the suppression measurement")

  ## the raw read shows the trap; read_hsaf() is the fix every downstream
  ## reader uses. R/hsaf.R drops the Ctrl-Z (0x1A) DOS EOF marker that read.csv
  ## turns into a junk final row (MEDICARE_PROV_NUM = "\032", all else empty).
  raw <- rd(f23)
  junk <- which(grepl("[\001-\037]", raw$MEDICARE_PROV_NUM))
  cat(sprintf("  rows in the raw file                 %s\n", format(nrow(raw), big.mark = ",")))
  cat(sprintf("  Ctrl-Z (0x1A) EOF junk row           %s\n",
              if (length(junk)) sprintf("row %s -- read_hsaf() drops it", format(junk[1], big.mark = ","))
              else "none found"))

  h <- read_hsaf(f23)
  dropped <- attr(h, "hsaf_dropped_rows"); if (is.null(dropped)) dropped <- 0L
  cat(sprintf("  rows after read_hsaf()               %s   (%d dropped)\n",
              format(nrow(h), big.mark = ","), dropped))
  cat(sprintf("  columns                              %s\n", paste(names(h), collapse = ", ")))

  star <- trimws(h$TOTAL_CASES) == "*"
  na_cases <- is.na(n_(h$TOTAL_CASES))
  pad <- range(nchar(c(h$TOTAL_DAYS_OF_CARE[star], h$TOTAL_CHARGES[star])))
  cat(sprintf("\n  suppressed TOTAL_CASES cells         %s of %s = %s\n",
              format(sum(na_cases), big.mark = ","), format(nrow(h), big.mark = ","), pct(mean(na_cases))))
  cat("  (Phase 0 / stage 1b read the raw file and count one more -- 996,701 -- because the\n")
  cat("   EOF row's blank TOTAL_CASES is is.na too; read_hsaf() removes that artifact)\n")
  cat(sprintf("  suppression is a literal '*', space-padded to the field width (%d-%d chars in the\n",
              pad[1], pad[2]))
  cat("  wider numeric columns) -- not blank and not NA; parse as character, then convert\n")
  cat(sprintf("  minimum non-suppressed TOTAL_CASES   %s   <- threshold confirmed at 11\n",
              min(n_(h$TOTAL_CASES), na.rm = TRUE)))

  supp_pct <- pct(mean(na_cases))
  cat(sprintf("\n  GATE 1.5a  suppression share reproduces at 87.46%%  ->  %s  (%s)\n",
              if (supp_pct == "87.46%") "PASS" else "FAIL", supp_pct))

  sub_("VERIFY: provider numbers, and the frame match")
  pn <- trimws(h$MEDICARE_PROV_NUM)
  alpha <- unique(pn[grepl("[A-Za-z]", pn)])
  cat(sprintf("  distinct MEDICARE_PROV_NUM           %s\n", format(length(unique(pn)), big.mark = ",")))
  cat(sprintf("  non-IPPS provider numbers (alpha)    %s   e.g. %s -- filter to the frame\n",
              format(length(alpha), big.mark = ","), paste(head(sort(alpha), 4), collapse = ", ")))
  cat(sprintf("  blank ZIP_CD_OF_RESIDENCE cells      %s file-wide\n",
              format(sum(!nzchar(trimws(h$ZIP_CD_OF_RESIDENCE))), big.mark = ",")))

  ccf <- file.path(CC, "Complications_and_Deaths-Hospital.csv")
  hgf <- file.path(CC, "Hospital_General_Information.csv")
  if (file.exists(ccf) && file.exists(hgf)) {
    cd <- rd(ccf); hg <- rd(hgf)
    p90 <- cd[cd$`Measure ID` == "PSI_90", ]
    type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
    frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
    miss <- setdiff(frame, unique(pn))
    nm <- setNames(hg$`Facility Name`, hg$`Facility ID`)
    cat(sprintf("  frame hospitals present in HSAF 2023 %d / %d  (%s)\n",
                sum(frame %in% pn), length(frame), pct(mean(frame %in% pn))))
    for (m in miss) cat(sprintf("    absent: %s  %s\n", m, nm[m]))
    cat("    (both are hospitals that opened in 2023 with no Medicare claims history yet;\n")
    cat("     the same two are absent from the FY2025 Impact File and the FY2023 HCRIS PUF)\n")
    cat(sprintf("  blank ZIP_CD_OF_RESIDENCE cells in frame hospitals  %s\n",
                format(sum(pn %in% frame & !nzchar(trimws(h$ZIP_CD_OF_RESIDENCE))), big.mark = ",")))

    ## ---- Dartmouth coverage of the frame ---------------------------------
    df <- file.path(DART, "ZipHsaHrr19.csv.zip")
    if (file.exists(df)) {
      sub_("VERIFY: Dartmouth crosswalk covers the frame")
      td <- tempfile(); dir.create(td)
      utils::unzip(df, files = DART_MEMBER, exdir = td)
      d <- rd(file.path(td, DART_MEMBER))
      dz <- trimws(d$zipcode19)
      cat(sprintf("  crosswalk rows                       %s\n", format(nrow(d), big.mark = ",")))
      cat(sprintf("  columns                              %s\n", paste(names(d), collapse = ", ")))
      cat(sprintf("  ZIP widths                           %s   (all 5-digit)\n",
                  paste(sort(unique(nchar(dz))), collapse = ", ")))
      cat(sprintf("  one HSA per ZIP (no duplicate ZIPs)  %s   <- plurality assignment, suppression-free\n",
                  !any(duplicated(dz))))
      cat(sprintf("  distinct HSAs / HRRs                  %s / %s\n",
                  format(length(unique(d$hsanum)), big.mark = ","),
                  format(length(unique(d$hrrnum)), big.mark = ",")))

      hz <- trimws(h$ZIP_CD_OF_RESIDENCE)
      inf <- pn %in% frame
      fz  <- unique(hz[inf & nzchar(hz)])
      cso <- n_(h$TOTAL_CASES)
      obs <- inf & !is.na(cso)
      cov_zip  <- mean(fz %in% dz)
      cov_case <- sum(cso[obs & hz %in% dz]) / sum(cso[obs])
      byh <- tapply(hz[inf] %in% dz, pn[inf], any)
      unmatched_obs <- sum(cso[obs & !(hz %in% dz)])
      cat(sprintf("\n  distinct frame patient-ZIPs          %s\n", format(length(fz), big.mark = ",")))
      cat(sprintf("  ... found in the Dartmouth crosswalk %s\n", pct(cov_zip)))
      cat(sprintf("  observed-case-weighted coverage      %s\n", pct(cov_case)))
      cat(sprintf("  frame hospitals with a resolvable ZIP %d / %d\n", sum(byh), length(byh)))
      cat(sprintf("  observed Medicare cases in unmatched frame ZIPs  %s of %s  (%s)\n",
                  format(unmatched_obs, big.mark = ","), format(sum(cso[obs]), big.mark = ","),
                  pct(unmatched_obs / sum(cso[obs]), 3)))
      cat("  the unmatched ZIPs are blank, 00000, or Puerto Rico / territory ZIPs the\n")
      cat("  Dartmouth Atlas does not cover -- a rounding error against the frame.\n")

      cat(sprintf("\n  GATE 1.5b  Dartmouth covers the frame (>= 99%% of observed cases)  ->  %s  (%s)\n",
                  if (cov_case >= 0.99) "PASS" else "FAIL", pct(cov_case)))
    }
  } else {
    cat("\n  (frame match skipped -- run stage 2 first to fetch the Care Compare files)\n")
  }
}

hdr("done")
