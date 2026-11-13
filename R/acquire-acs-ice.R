# R/acquire-acs-ice.R  --  Task 1.4, the ACS pull, for ICE only
#
# The Index of Concentration at the Extremes (Krieger et al.) measures how far a
# neighbourhood sits toward one pole of a distribution rather than the middle:
#
#     ICE = (A - P) / T
#
# with A the households in the privileged extreme, P those in the deprived
# extreme, and T all households with income reported. It runs from -1 (everyone
# poor) to +1 (everyone affluent), and 0 means either a balanced mix or a
# uniformly middle-income tract -- a genuine ambiguity worth stating rather than
# hiding, and the reason ICE complements rather than replaces SVI and ADI.
#
# This is the ONLY ACS pull the project makes. EP_UNINSUR and EP_LIMENG come
# from inside the SVI file, which removes two pulls and one vintage mismatch.
#
# VINTAGE: ACS 2020-2024 5-year, data midpoint 2022-07-01, a 1.0-year gap to the
# PSI window midpoint. ACS 2021-2025 does not exist -- it lands December 2026,
# after the contract ends. ICE deliberately does NOT inherit SVI's 2018-2022
# vintage and its 3.0-year gap; there is no reason for it to.
#
# KEY: the ACS API now returns "Missing Key" on unauthenticated requests, which
# Phase 0's note that no key was needed for light use no longer describes. The
# key is read from the environment and NEVER written to disk or to the
# provenance table -- sources.csv records that a key was used, not its value.
#
#   export CENSUS_API_KEY=...   or   CENSUS_API_KEY=... in ~/.Renviron

suppressPackageStartupMessages(library(jsonlite))
source(file.path("R", "provenance.R"))

ACS_YEAR <- 2024L                       # ACS 2020-2024 5-year
ACS_BASE <- sprintf("https://api.census.gov/data/%d/acs/acs5", ACS_YEAR)
OUT_DIR  <- file.path("data-raw", "blockB_acs")
OUT_FILE <- file.path(OUT_DIR, sprintf("acs%d_5yr_B19001_tract.csv", ACS_YEAR))

## B19001, household income in the past 12 months, 17 brackets.
##   002-005  under $25,000    the deprived extreme
##   014-017  $100,000 or more the privileged extreme
##   016-017  $150,000 or more a stricter alternative, carried as an axis
LOW  <- sprintf("B19001_%03dE", 2:5)
HIGH <- sprintf("B19001_%03dE", 14:17)
HI150<- sprintf("B19001_%03dE", 16:17)
VARS <- c("B19001_001E", LOW, HIGH)

hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

hdr("TASK 1.4  ACS 2020-2024 5-year -- the ICE pull")

KEY <- Sys.getenv("CENSUS_API_KEY")
if (!nzchar(KEY)) {
  cat("  NO CENSUS_API_KEY in the environment.\n")
  cat("  Free and instant from https://api.census.gov/data/key_signup.html\n")
  cat("  Then put CENSUS_API_KEY=<key> in ~/.Renviron. Nothing else in Phase 1\n")
  cat("  needs it, so this is the only stage that stops here.\n")
} else if (file.exists(OUT_FILE)) {
  cat("  archive already present -- the ACS is a fixed vintage, so a re-pull is\n")
  cat("  a no-op by construction. Verifying instead.\n")
} else {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
  ## Tract-level ACS requires one request per state.
  st <- jsonlite::fromJSON(sprintf("%s?get=NAME&for=state:*&key=%s", ACS_BASE, KEY))
  fips <- st[-1, ncol(st)]
  cat("  states and state-equivalents to pull:", length(fips), "\n")
  acc <- vector("list", length(fips))
  for (i in seq_along(fips)) {
    u <- sprintf("%s?get=%s&for=tract:*&in=state:%s&key=%s",
                 ACS_BASE, paste(VARS, collapse = ","), fips[i], KEY)
    j <- tryCatch(jsonlite::fromJSON(u), error = function(e) NULL)
    if (is.null(j)) { message("    state ", fips[i], " FAILED"); next }
    d <- as.data.frame(j[-1, , drop = FALSE], stringsAsFactors = FALSE)
    names(d) <- j[1, ]
    acc[[i]] <- d
    cat(sprintf("\r  pulled %2d/%d  state %s  tracts %5d", i, length(fips), fips[i], nrow(d)))
  }
  cat("\n")
  A <- do.call(rbind, acc)
  A$GEOID <- paste0(A$state, A$county, A$tract)
  utils::write.csv(A, OUT_FILE, row.names = FALSE)
  cat("  archived ", OUT_FILE, "\n", sep = "")
}

if (file.exists(OUT_FILE)) {
  A <- read.csv(OUT_FILE, colClasses = "character", check.names = FALSE, na.strings = character(0))
  num <- function(v) suppressWarnings(as.numeric(A[[v]]))
  tot <- num("B19001_001E")
  lo  <- rowSums(sapply(LOW,   num)); hi <- rowSums(sapply(HIGH, num))
  h15 <- rowSums(sapply(HI150, num))
  ok  <- !is.na(tot) & tot > 0
  ice <- ifelse(ok, (hi - lo) / tot, NA_real_)
  ice150 <- ifelse(ok, (h15 - lo) / tot, NA_real_)

  sub_("the pull")
  cat(sprintf("  tracts            %6d\n", nrow(A)))
  cat(sprintf("  GEOID width       %s, all distinct: %s\n",
              paste(sort(unique(nchar(A$GEOID))), collapse = "/"),
              if (length(unique(A$GEOID)) == nrow(A)) "yes" else "NO"))
  cat(sprintf("  households > 0    %6d  %s   <- ICE is undefined where the tract has\n",
              sum(ok), pct(mean(ok))))
  cat("                                    no households, not missing; keep the\n")
  cat("                                    distinction, do not impute a zero.\n")

  sub_("ICE, primary definition: bottom < $25,000 vs top >= $100,000")
  q <- quantile(ice, c(.05, .25, .5, .75, .95), na.rm = TRUE, names = FALSE)
  cat(sprintf("  p05 %+.3f  p25 %+.3f  median %+.3f  p75 %+.3f  p95 %+.3f   range %+.3f..%+.3f\n",
              q[1], q[2], q[3], q[4], q[5], min(ice, na.rm = TRUE), max(ice, na.rm = TRUE)))
  cat(sprintf("  tracts at the deprived pole (ICE < -0.5) %5d   privileged (> +0.5) %5d\n",
              sum(ice < -0.5, na.rm = TRUE), sum(ice > 0.5, na.rm = TRUE)))

  sub_("ICE, alternative cutoff: top >= $150,000 -- a specification axis")
  cat("  The conventional <$25k / >=$100k cutoffs date from an era when $100k was\n")
  cat("  near the 80th percentile. In 2020-2024 dollars it is not, so the stricter\n")
  cat("  cutoff is carried as an axis rather than one being asserted as correct.\n")
  q2 <- quantile(ice150, c(.05, .5, .95), na.rm = TRUE, names = FALSE)
  cat(sprintf("  p05 %+.3f  median %+.3f  p95 %+.3f   correlation with the primary %.4f\n",
              q2[1], q2[2], q2[3], cor(ice, ice150, use = "complete.obs")))

  sub_("join keys")
  cat("  GEOID is the 11-digit tract code, which is what the ZCTA->tract relationship\n")
  cat("  file keys on and what block-group ADI rolls up to. One grain, three sources.\n")
}

hdr("done")
