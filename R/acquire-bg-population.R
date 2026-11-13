# R/acquire-bg-population.R  --  Task 2.5 input: block-group population
#
# The block-group ADI (data-raw/blockB_adi/) carries no population column, and
# spike-context.md §3.3 commits the build to aggregating block-group ADI to
# census tract BY POPULATION WEIGHTING before catchment weighting. Block groups
# nest exactly inside tracts, so the roll-up is an exact hierarchical operation
# -- but it needs a population weight, and this is the one field the Neighborhood
# Atlas file omits.
#
# ACS table B01003 (total population), block-group level, one request per state.
# VINTAGE: ACS 2020-2024 5-year -- the same vintage as adi_2024_bg (which is
# built on ACS 2020-2024) and as acs_2024_ice, so the weight and the thing it
# weights share a vintage.
#
# Same key handling as R/acquire-acs-ice.R: CENSUS_API_KEY from the environment,
# never written to disk or to the provenance table.

suppressPackageStartupMessages(library(jsonlite))
source(file.path("R", "provenance.R"))

ACS_YEAR <- 2024L
ACS_BASE <- sprintf("https://api.census.gov/data/%d/acs/acs5", ACS_YEAR)
OUT_DIR  <- file.path("data-raw", "blockB_acs")
OUT_FILE <- file.path(OUT_DIR, sprintf("acs%d_5yr_B01003_blockgroup.csv", ACS_YEAR))

hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

hdr("TASK 2.5 input  ACS 2020-2024 5-year -- block-group population (B01003)")

KEY <- Sys.getenv("CENSUS_API_KEY")
if (!nzchar(KEY)) {
  cat("  NO CENSUS_API_KEY in the environment.\n")
  cat("  Free and instant from https://api.census.gov/data/key_signup.html\n")
  cat("  Put CENSUS_API_KEY=<key> in ~/.Renviron. Same key acquire-acs-ice.R uses.\n")
} else if (file.exists(OUT_FILE)) {
  cat("  archive already present -- fixed vintage, a re-pull is a no-op. Verifying.\n")
} else {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
  options(timeout = 300)
  st <- jsonlite::fromJSON(sprintf("%s?get=NAME&for=state:*&key=%s", ACS_BASE, KEY))
  fips <- st[-1, ncol(st)]
  cat("  states and state-equivalents to pull:", length(fips), "\n")
  pull_state <- function(fp, tries = 4L) {
    u <- sprintf("%s?get=B01003_001E&for=block%%20group:*&in=state:%s%%20county:*&key=%s",
                 ACS_BASE, fp, KEY)
    for (a in seq_len(tries)) {
      j <- tryCatch(jsonlite::fromJSON(u), error = function(e) NULL)
      if (!is.null(j) && nrow(j) > 1) {
        d <- as.data.frame(j[-1, , drop = FALSE], stringsAsFactors = FALSE); names(d) <- j[1, ]
        return(d)
      }
      Sys.sleep(3 * a)
    }
    NULL
  }
  acc <- vector("list", length(fips))
  for (i in seq_along(fips)) {
    acc[[i]] <- pull_state(fips[i])
    cat(sprintf("\r  pulled %2d/%d  state %s  block groups %6s", i, length(fips), fips[i],
                if (is.null(acc[[i]])) "FAIL" else nrow(acc[[i]])))
  }
  cat("\n")
  failed <- fips[vapply(acc, is.null, logical(1))]
  if (length(failed))
    stop("block-group pull incomplete -- states failed after retries: ",
         paste(failed, collapse = ", "), ". Not writing a partial archive; re-run.")
  A <- do.call(rbind, acc)
  A$GEOID <- paste0(A$state, A$county, A$tract, A$`block group`)
  utils::write.csv(A, OUT_FILE, row.names = FALSE)
  cat("  archived ", OUT_FILE, " (", length(fips), " states, ", nrow(A), " block groups)\n", sep = "")
  ## keep data-raw/blockB_acs/MANIFEST.sha256 current (same format as the rest)
  csvs <- sort(list.files(OUT_DIR, pattern = "\\.csv$", full.names = TRUE))
  writeLines(vapply(csvs, function(f) paste0(sha256_file(f), "  ", f), character(1)),
             file.path(OUT_DIR, "MANIFEST.sha256"))
}

if (file.exists(OUT_FILE)) {
  A <- read.csv(OUT_FILE, colClasses = "character", check.names = FALSE, na.strings = character(0))
  pop <- suppressWarnings(as.numeric(A$B01003_001E))
  sub_("the pull")
  cat(sprintf("  block groups         %s\n", format(nrow(A), big.mark = ",")))
  cat(sprintf("  GEOID width          %s  (12-digit block-group code), all distinct: %s\n",
              paste(sort(unique(nchar(A$GEOID))), collapse = "/"),
              if (length(unique(A$GEOID)) == nrow(A)) "yes" else "NO"))
  cat(sprintf("  population > 0       %s  %s\n", format(sum(pop > 0, na.rm = TRUE), big.mark = ","),
              pct(mean(pop > 0, na.rm = TRUE))))
  cat(sprintf("  total US population  %s\n", format(sum(pop, na.rm = TRUE), big.mark = ",")))
  cat(sprintf("  block groups per tract: median %.1f\n",
              median(table(substr(A$GEOID, 1, 11)))))

  prov <- tryCatch(prov_read(), error = function(e) NULL)
  if (!is.null(prov) && !("acs_2024_bg_pop" %in% prov$source_id)) {
    prov_add(
      source_id = "acs_2024_bg_pop",
      source = "U.S. Census Bureau, American Community Survey 2020-2024 5-year, table B01003, census block group",
      file = OUT_FILE,
      url = paste0(ACS_BASE, "?get=B01003_001E&for=block%20group:*&in=state:{FIPS}%20county:*",
                   "&key={CENSUS_API_KEY}  -- looped over all 52 state and state-equivalent FIPS codes"),
      retrieval_method = "web API",
      vintage = "ACS 2020-2024 5-year; same vintage as adi_2024_bg and acs_2024_ice",
      license = "Public domain, U.S. Government work.",
      parse_notes = paste0("Block-group total population, the weight for rolling block-group ADI up to ",
                           "census tract (spike-context.md §3.3). GEOID = state(2)+county(3)+tract(6)+",
                           "block group(1) = 12 digits, matching adi_2024_bg FIPS. One request per state, ",
                           "for=block group:* with in=state:{FIPS} county:*. Key read from CENSUS_API_KEY, ",
                           "not recorded. A block group with population 0 contributes 0 weight, not NA.")
    )
    cat("\n  provenance: added row `acs_2024_bg_pop`\n")
  } else {
    cat("\n  provenance: `acs_2024_bg_pop` already present\n")
  }
}

hdr("done")
