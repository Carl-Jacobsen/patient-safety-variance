# R/acquire-adi.R  --  Task 1.4, the ADI component
#
# ADI is the one Phase 1 input that cannot be fetched by script. The
# Neighborhood Atlas requires a free account and email validation, and the
# account is registered under Carl's name and affiliation, so acquisition is a
# manual step and `retrieval_method` records it as `account login`. Everything
# after the download is automated, including this verification.
#
# Two vintages, both at census BLOCK GROUP level, national percentile:
#   2024  ACS 2020-2024, data midpoint 2022-07-01, a 1.0-year gap to the PSI
#         window midpoint. The primary file, and the ONLY Block B disadvantage
#         measure that describes communities during the outcome period --
#         SVI 2022's gap is 3.0 years and no newer SVI release exists.
#   2020  ACS 2016-2020. Carried as a free vintage axis in the specification
#         space, not as a fallback.
#
# What this stage does NOT do: the ZIP+4 crosswalk is deliberately not taken --
# it cannot join to the 5-digit ZIPs the Hospital Service Area File publishes.
# The route is block group -> tract by population weighting (an exact
# hierarchical roll-up, since block groups nest within tracts), then the same
# ZCTA->tract machinery SVI already needs. See spike-context.md section 3.3.

source(file.path("R", "provenance.R"))

ADI <- file.path("data-raw", "blockB_adi")
ADI_FILES <- data.frame(
  source_id = c("adi_2024_bg", "adi_2020_bg"),
  file = file.path(ADI, c("US_2024_block_group_adi_v_4_0_1.csv",
                          "US_2020_ADI_Census_Block_Group_v4_0_1.csv")),
  role = c("primary, 1.0-year gap", "vintage axis, 5.0-year gap"),
  stringsAsFactors = FALSE)

rd  <- function(p) read.csv(p, colClasses = "character", check.names = FALSE,
                            na.strings = character(0))
pct <- function(x, d = 2) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 1.4  ADI -- ingest and verification")

sub_("files")
prov <- tryCatch(prov_read(), error = function(e) NULL)
present <- file.exists(ADI_FILES$file)
for (i in seq_len(nrow(ADI_FILES))) {
  sid <- ADI_FILES$source_id[i]; f <- ADI_FILES$file[i]
  if (!present[i]) {
    cat(sprintf("  %-14s ABSENT -- account-gated, cannot be fetched by script.\n", sid))
    cat("                 https://www.neighborhoodatlas.medicine.wisc.edu/ -> Create an Account\n")
    cat("                 then /download: 12-digit FIPS, All states, the version in the file name.\n")
    next
  }
  h <- sha256_file(f)
  rec <- if (!is.null(prov) && sid %in% prov$source_id) prov$sha256[prov$source_id == sid] else NA_character_
  status <- if (is.na(rec)) "no provenance row yet" else
            if (identical(h, rec)) "sha256 MATCHES provenance" else "*** sha256 MISMATCH ***"
  cat(sprintf("  %-14s %6.1f MB  %s  %-26s %s\n", sid, file.size(f) / 1e6,
              substr(h, 1, 16), status, ADI_FILES$role[i]))
}
if (!all(present)) { cat("\n  Verification below needs both files.\n"); } else {

sub_("the parse trap: the value column is CHARACTER, carrying suppression inline")
for (i in seq_len(nrow(ADI_FILES))) {
  d <- rd(ADI_FILES$file[i])
  v <- trimws(d$ADI_NATRANK)
  num <- suppressWarnings(as.numeric(v))
  cat(sprintf("\n  %s\n", basename(ADI_FILES$file[i])))
  cat(sprintf("    block groups              %7d   columns: %s\n", nrow(d), paste(names(d), collapse = ", ")))
  cat(sprintf("    numeric national rank     %7d   %s   range %d-%d\n",
              sum(!is.na(num)), pct(mean(!is.na(num))), min(num, na.rm = TRUE), max(num, na.rm = TRUE)))
  codes <- table(v[is.na(num)])
  for (k in names(codes)) {
    meaning <- c(GQ = "group quarters > 33.3% of housing units -- NON-RANDOM, enumerate",
                 PH = "population < 100 and/or < 30 housing units",
                 `GQ-PH` = "both conditions",
                 QDI = "questionable data integrity, missing ACS input")[k]
    cat(sprintf("    %-6s %6d  %s  %s\n", k, codes[[k]], pct(codes[[k]] / nrow(d)), meaning))
  }
  cat(sprintf("    FIPS width %s, all distinct: %s\n",
              paste(sort(unique(nchar(trimws(d$FIPS)))), collapse = "/"),
              if (length(unique(d$FIPS)) == nrow(d)) "yes" else "NO -- duplicates present"))
  cat(sprintf("    implied tracts (FIPS 1:11) %6d   state FIPS present %d\n",
              length(unique(substr(trimws(d$FIPS), 1, 11))),
              length(unique(substr(trimws(d$FIPS), 1, 2)))))
}

sub_("the roll-up to tract is exact, which is the point")
d24 <- rd(ADI_FILES$file[1]); d20 <- rd(ADI_FILES$file[2])
t24 <- unique(substr(trimws(d24$FIPS), 1, 11)); t20 <- unique(substr(trimws(d20$FIPS), 1, 11))
cat("  Block groups nest exactly inside tracts -- the tract code IS the first 11\n")
cat("  digits of the block-group code, so aggregating adds no allocation error.\n")
cat(sprintf("  tracts covered, 2024 %d   2020 %d   in both %d\n",
            length(t24), length(t20), length(intersect(t24, t20))))
cat("  The only allocation step remains ZCTA->tract, which SVI already requires,\n")
cat("  so ADI introduces no new source of error beyond what the design carries.\n")
cat("  NOTE for report section 3: averaging a PERCENTILE RANK across block groups is a\n")
cat("  rank-of-ranks. Standard and acceptable, but it is not a block-group ADI and\n")
cat("  must not be described as one.\n")

sub_("vintage comparison, on block groups present in both")
k <- intersect(d24$FIPS, d20$FIPS)
a <- suppressWarnings(as.numeric(setNames(trimws(d24$ADI_NATRANK), d24$FIPS)[k]))
b <- suppressWarnings(as.numeric(setNames(trimws(d20$ADI_NATRANK), d20$FIPS)[k]))
g <- !is.na(a) & !is.na(b)
cat(sprintf("  block groups in both files %d, both ranks numeric %d  %s\n",
            length(k), sum(g), pct(mean(g))))
cat(sprintf("  correlation 2024 vs 2020   %.4f\n", cor(a[g], b[g])))
cat(sprintf("  median absolute change     %.1f percentile points; p95 %.1f\n",
            median(abs(a[g] - b[g])), quantile(abs(a[g] - b[g]), .95, names = FALSE)))
cat("  The two vintages are close but not interchangeable, which is what makes 2020\n")
cat("  worth carrying as an axis rather than discarding.\n")
}

hdr("done")
