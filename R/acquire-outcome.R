# R/acquire-outcome.R  --  Task 1.2, the outcome layer
#
# Six files from the CMS Provider Data Catalog: the five Care Compare files that
# define the outcome and the sample frame, plus the FY 2026 HAC Reduction
# Program file that carries observed penalty status.
#
# Retrieval goes through the METASTORE API, never the versioned file URL. A PDC
# download URL embeds a release token (`..._1785189947`) that changes on every
# refresh, so a recorded URL is a snapshot, not a recipe. The API is the recipe:
#
#   https://data.cms.gov/provider-data/api/1/metastore/schemas/dataset/items
#   -> select by `identifier` -> distribution[[1]]$data$downloadURL
#
# The script is idempotent. A file already on disk is verified against the
# sha256 in provenance/sources.csv and left alone; only a missing file is
# downloaded. That is what lets a stranger rebuild data-raw/ from the
# provenance table and nothing else.

suppressPackageStartupMessages(library(jsonlite))

source(file.path("R", "provenance.R"))

PDC_METASTORE <- paste0("https://data.cms.gov/provider-data/api/1/metastore/",
                        "schemas/dataset/items?show-reference-ids=false")

CC_DIR  <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
HAC_DIR <- file.path("data-raw", "hacrp_fy2026")

## source_id, PDC dataset identifier, and where the bytes live.
OUTCOME_SOURCES <- data.frame(
  source_id  = c("cc_candd", "cc_psi6dec", "cc_footnotes", "cc_measuredates",
                 "cc_hospinfo", "hacrp_fy2026"),
  identifier = c("ynj2-r877", "muwa-iene", "y9us-9xdf", "4j6d-yzce",
                 "xubh-q36u", "yq43-i98g"),
  file = c(file.path(CC_DIR,  "Complications_and_Deaths-Hospital.csv"),
           file.path(CC_DIR,  "CMS_PSI_6_decimal_file.csv"),
           file.path(CC_DIR,  "Footnote_Crosswalk.csv"),
           file.path(CC_DIR,  "Measure_Dates.csv"),
           file.path(CC_DIR,  "Hospital_General_Information.csv"),
           file.path(HAC_DIR, "FY_2026_HAC_Reduction_Program_Hospital.csv")),
  stringsAsFactors = FALSE)

hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

## Resolve every dataset in one API call. Returns NULL if the catalogue is
## unreachable -- offline is a reason to skip re-resolution, not to fail a run
## whose files are all present and correctly hashed.
pdc_resolve <- function(ids, url = PDC_METASTORE) {
  j <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                error = function(e) { message("  metastore unreachable: ", conditionMessage(e)); NULL })
  if (is.null(j)) return(NULL)
  got <- do.call(rbind, lapply(j, function(x) {
    if (is.null(x$identifier) || !x$identifier %in% ids) return(NULL)
    data.frame(identifier = x$identifier,
               title      = if (is.null(x$title)) "" else x$title,
               modified   = if (is.null(x$modified)) "" else x$modified,
               released   = if (is.null(x$released)) "" else x$released,
               accessLevel= if (is.null(x$accessLevel)) "" else x$accessLevel,
               downloadURL= x$distribution[[1]]$data$downloadURL,
               stringsAsFactors = FALSE)
  }))
  got[match(ids, got$identifier), , drop = FALSE]
}

hdr("TASK 1.2  outcome layer -- acquisition and verification")

cat("  catalogue: ", PDC_METASTORE, "\n", sep = "")
res <- pdc_resolve(OUTCOME_SOURCES$identifier)

sub_("metastore resolution")
if (is.null(res)) {
  cat("  SKIPPED -- no network. Local files are still verified below.\n")
} else {
  for (i in seq_len(nrow(res))) {
    cat(sprintf("  %-14s %-12s modified %s  released %s  access %s\n",
                OUTCOME_SOURCES$source_id[i], res$identifier[i], res$modified[i],
                res$released[i], res$accessLevel[i]))
  }
}

sub_("files")
prov <- tryCatch(prov_read(), error = function(e) NULL)
for (i in seq_len(nrow(OUTCOME_SOURCES))) {
  f <- OUTCOME_SOURCES$file[i]; sid <- OUTCOME_SOURCES$source_id[i]
  if (!file.exists(f)) {
    if (is.null(res)) { cat(sprintf("  %-14s ABSENT and no network to fetch it\n", sid)); next }
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("  %-14s downloading ...\n", sid))
    utils::download.file(res$downloadURL[i], f, quiet = TRUE, mode = "wb")
  }
  h <- sha256_file(f)
  rec <- if (!is.null(prov) && sid %in% prov$source_id) prov$sha256[prov$source_id == sid] else NA_character_
  status <- if (is.na(rec)) "no provenance row yet" else if (identical(h, rec)) "sha256 MATCHES provenance" else "*** sha256 MISMATCH ***"
  cat(sprintf("  %-14s %9.1f MB  %s  %s\n", sid, file.size(f) / 1e6, substr(h, 1, 16), status))
}

## The release token moves; the bytes may not. Recording both answers the
## question a reviewer will actually ask: is the archive still the live file?
if (!is.null(res)) {
  sub_("release token drift")
  cat("  Resolved download URLs (token in the path segment before the filename):\n")
  for (i in seq_len(nrow(res))) cat("    ", res$downloadURL[i], "\n", sep = "")
}
