# R/acquire-blockA.R  --  Task 1.3, Block A (hospital structure)
#
# Six files, two publishers, two retrieval routes.
#
#   www.cms.gov static ZIPs        the FY 2026 and FY 2025 IPPS Impact Files.
#                                  Stable URLs; no token, no catalogue.
#   data.cms.gov DCAT catalogue    the Cost Report PUF, the Provider of Services
#                                  file, Hospital Enrollments, Hospital All
#                                  Owners. Their file URLs carry a dated release
#                                  path that rotates, so the durable route is
#                                  https://data.cms.gov/data.json -> match the
#                                  dataset title -> distribution[[1]]$downloadURL
#                                  (distributions are newest-first).
#
# Same contract as the outcome layer: idempotent, hashes against sources.csv,
# downloads only what is missing.

suppressPackageStartupMessages(library(jsonlite))
source(file.path("R", "provenance.R"))

CMS_CATALOG <- "https://data.cms.gov/data.json"
BA <- file.path("data-raw", "blockA")

## title in the DCAT catalogue (exact), or NA for a static URL
BLOCKA_SOURCES <- data.frame(
  source_id = c("ipps_impact_fy2026", "ipps_impact_fy2025", "hcris_puf_fy2023",
                "hcris_puf_fy2022", "pos_q2_2026", "hosp_enrollments", "hosp_all_owners"),
  catalog_title = c(NA, NA,
                    "Hospital Provider Cost Report", "Hospital Provider Cost Report",
                    "Provider of Services File - Quality Improvement and Evaluation System",
                    "Hospital Enrollments", "Hospital All Owners"),
  static_url = c("https://www.cms.gov/files/zip/fy2026-ipps-fr-impact-file.zip",
                 "https://www.cms.gov/files/zip/fy-2025-ipps-fr-impact-file.zip",
                 NA, NA, NA, NA, NA),
  file = file.path(BA, c("fy2026-ipps-fr-impact-file.zip",
                         "fy-2025-ipps-fr-impact-file.zip",
                         "CostReport_2023_Final.csv", "CostReport_2022_Final.csv",
                         "Hospital_and_other.DATA.Q2_2026.csv",
                         "Hospital_Enrollments_2026.07.31.csv",
                         "Hospital_All_Owners_2026.07.31.csv")),
  stringsAsFactors = FALSE)

hdr  <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

cms_catalog <- function(url = CMS_CATALOG) {
  j <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                error = function(e) { message("  catalogue unreachable: ", conditionMessage(e)); NULL })
  if (is.null(j)) NULL else j$dataset
}

## The Cost Report PUF publishes one distribution per fiscal year, so the newest
## is not always the one wanted. `pick` matches on the distribution filename.
cat_resolve <- function(cat, title, pick = NULL) {
  if (is.null(cat)) return(NULL)
  hit <- Filter(function(x) identical(x$title, title), cat)
  if (!length(hit)) return(NULL)
  d <- hit[[1]]$distribution
  urls <- vapply(d, function(z) if (is.null(z$downloadURL)) "" else z$downloadURL, character(1))
  urls <- urls[nzchar(urls)]
  if (!is.null(pick)) urls <- urls[grepl(pick, basename(urls), fixed = TRUE)]
  if (!length(urls)) return(NULL)
  list(url = urls[1], modified = hit[[1]]$modified,
       license = if (is.null(hit[[1]]$license)) "" else hit[[1]]$license)
}

hdr("TASK 1.3  Block A -- acquisition and verification")

cat("  catalogue: ", CMS_CATALOG, "\n", sep = "")
cat <- cms_catalog()

sub_("catalogue resolution")
resolved <- rep(NA_character_, nrow(BLOCKA_SOURCES))
for (i in seq_len(nrow(BLOCKA_SOURCES))) {
  sid <- BLOCKA_SOURCES$source_id[i]
  if (is.na(BLOCKA_SOURCES$catalog_title[i])) {
    resolved[i] <- BLOCKA_SOURCES$static_url[i]
    cat(sprintf("  %-20s static URL   %s\n", sid, basename(resolved[i])))
  } else {
    r <- cat_resolve(cat, BLOCKA_SOURCES$catalog_title[i],
                     pick = if (grepl("^hcris_puf_fy", sid))
                              paste0("CostReport_", sub("hcris_puf_fy", "", sid), "_Final.csv") else NULL)
    if (is.null(r)) { cat(sprintf("  %-20s NOT RESOLVED\n", sid)); next }
    resolved[i] <- r$url
    cat(sprintf("  %-20s modified %-12s licence %s\n", sid, r$modified, r$license))
    cat(sprintf("  %-20s -> %s\n", "", basename(r$url)))
  }
}

sub_("files")
prov <- tryCatch(prov_read(), error = function(e) NULL)
for (i in seq_len(nrow(BLOCKA_SOURCES))) {
  f <- BLOCKA_SOURCES$file[i]; sid <- BLOCKA_SOURCES$source_id[i]
  if (!file.exists(f)) {
    if (is.na(resolved[i])) { cat(sprintf("  %-20s ABSENT and unresolved\n", sid)); next }
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("  %-20s downloading ...\n", sid))
    utils::download.file(resolved[i], f, quiet = TRUE, mode = "wb")
  }
  h <- sha256_file(f)
  rec <- if (!is.null(prov) && sid %in% prov$source_id) prov$sha256[prov$source_id == sid] else NA_character_
  status <- if (is.na(rec)) "no provenance row yet" else
            if (identical(h, rec)) "sha256 MATCHES provenance" else "*** sha256 MISMATCH ***"
  cat(sprintf("  %-20s %8.1f MB  %s  %s\n", sid, file.size(f) / 1e6, substr(h, 1, 16), status))
}

sub_("the ZIP members that matter")
for (i in 1:2) {
  z <- BLOCKA_SOURCES$file[i]
  if (!file.exists(z)) next
  m <- utils::unzip(z, list = TRUE)
  cat("  ", basename(z), "\n", sep = "")
  for (k in seq_len(nrow(m))) cat(sprintf("      %-62s %8.0f KB\n", m$Name[k], m$Length[k] / 1024))
}
cat("\n  FY 2025: take the CORRECTION NOTICE member. The ZIP also holds the Final\n")
cat("  Rule and Interim Final Action vintages; the Correction Notice supersedes both.\n")
