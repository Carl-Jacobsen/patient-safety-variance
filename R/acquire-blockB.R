# R/acquire-blockB.R  --  Task 1.4, Block B (social and geographic context)
#
# Everything in Block B except ADI, which is account-gated and handled in
# R/acquire-adi.R, and except market concentration, which is DERIVED from the
# Hospital Service Area File at Task 2.5 and is not a download at all. It is
# recorded here as a deliberate non-acquisition so it is not discovered missing
# in Phase 2.
#
# Two Phase 0 simplifications are carried through and matter:
#   * EP_UNINSUR and EP_LIMENG are COLUMNS OF THE SVI FILE, so the uninsured and
#     limited-English ACS pulls are dropped. Vintage consistency comes free.
#   * The HUD USPS ZIP crosswalk now needs an API token and is dropped. The
#     Census 2020 ZCTA relationship files are free, need no token, and do the
#     same job: ZCTA->tract for the base case, ZCTA->county for the fallback.
#
# All static URLs. No catalogue indirection is needed -- these publishers do not
# rotate a release token into the path.

source(file.path("R", "provenance.R"))
BB <- file.path("data-raw", "blockB")

BLOCKB_SOURCES <- data.frame(
  source_id = c("svi_2022_tract", "svi_2022_county", "zcta_tract_2020",
                "zcta_county_2020", "ahrf_2023_2024", "chr_2025", "rucc_2023"),
  url = c("https://svi.cdc.gov/Documents/Data/2022/csv/states/SVI_2022_US.csv",
          "https://svi.cdc.gov/Documents/Data/2022/csv/states_counties/SVI_2022_US_county.csv",
          "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_tract20_natl.txt",
          "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt",
          "https://data.hrsa.gov/DataDownload/AHRF/AHRF%202023-2024%20SAS.zip",
          "https://www.countyhealthrankings.org/sites/default/files/media/document/analytic_data2025_v3.csv",
          "https://www.ers.usda.gov/sites/default/files/_laserfiche/DataFiles/53251/Ruralurbancontinuumcodes2023.csv"),
  file = file.path(BB, c("SVI_2022_US.csv", "SVI_2022_US_county.csv",
                         "tab20_zcta520_tract20_natl.txt", "tab20_zcta520_county20_natl.txt",
                         "AHRF_2023-2024_SAS.zip", "analytic_data2025_v3.csv",
                         "Ruralurbancontinuumcodes2023.csv")),
  stringsAsFactors = FALSE)

rd  <- function(p, ...) read.csv(p, colClasses = "character", check.names = FALSE,
                                 na.strings = character(0), ...)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 1.4  Block B -- acquisition and verification")

sub_("files")
prov <- tryCatch(prov_read(), error = function(e) NULL)
for (i in seq_len(nrow(BLOCKB_SOURCES))) {
  f <- BLOCKB_SOURCES$file[i]; sid <- BLOCKB_SOURCES$source_id[i]
  if (!file.exists(f)) {
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("  %-18s downloading ...\n", sid))
    ok <- tryCatch({ utils::download.file(BLOCKB_SOURCES$url[i], f, quiet = TRUE, mode = "wb"); TRUE },
                   error = function(e) { message("    FAILED: ", conditionMessage(e)); FALSE })
    if (!ok) next
  }
  h <- sha256_file(f)
  rec <- if (!is.null(prov) && sid %in% prov$source_id) prov$sha256[prov$source_id == sid] else NA_character_
  status <- if (is.na(rec)) "no provenance row yet" else
            if (identical(h, rec)) "sha256 MATCHES provenance" else "*** sha256 MISMATCH ***"
  cat(sprintf("  %-18s %8.1f MB  %s  %s\n", sid, file.size(f) / 1e6, substr(h, 1, 16), status))
}

## ---- SVI: four themes, and the composite that must never be modelled --------
sub_("VERIFY: SVI arrives as four separate themes")
sv <- rd(file.path(BB, "SVI_2022_US.csv"))
cols <- names(sv)
for (v in c("RPL_THEME1", "RPL_THEME2", "RPL_THEME3", "RPL_THEME4",
            "RPL_THEMES", "EP_UNINSUR", "EP_LIMENG", "FIPS")) {
  cat(sprintf("  %-12s %s\n", v, if (v %in% cols) "present" else "*** ABSENT ***"))
}
cat("\n  RPL_THEMES is acquired and MUST NEVER ENTER A MODEL. It is the composite\n")
cat("  the design exists to decompose: collapsing four themes into one number is\n")
cat("  precisely the information loss Phase 3 is measuring.\n")
th <- sapply(1:4, function(i) n_(sv[[paste0("RPL_THEME", i)]]))
cat(sprintf("\n  tracts in file %d   with all four themes valid (>= 0) %d  %s\n",
            nrow(sv), sum(apply(th, 1, function(r) all(!is.na(r) & r >= 0))),
            pct(mean(apply(th, 1, function(r) all(!is.na(r) & r >= 0))))))
cat("  SVI codes missing as -999, not blank -- a negative percentile is a suppression\n")
cat("  flag, and coercing it to numeric without filtering yields silent nonsense.\n")
for (i in 1:4) {
  v <- th[, i]
  cat(sprintf("  RPL_THEME%d  valid %6d   -999 %5d   median %.4f\n",
              i, sum(!is.na(v) & v >= 0), sum(!is.na(v) & v < 0), median(v[v >= 0], na.rm = TRUE)))
}
svc <- rd(file.path(BB, "SVI_2022_US_county.csv"))
cat(sprintf("\n  county file: %d counties, four themes valid for %d\n", nrow(svc),
            sum(apply(sapply(1:4, function(i) n_(svc[[paste0("RPL_THEME", i)]])), 1,
                      function(r) all(!is.na(r) & r >= 0)))))
cat("  SVI 2022 is built on ACS 2018-2022: data midpoint 2020-07-01, PSI midpoint\n")
cat("  2023-07-01, GAP = 3.0 YEARS. No newer SVI exists -- 2023 and 2024 both 404.\n")

## ---- the two ZCTA relationship files ---------------------------------------
sub_("Census 2020 ZCTA relationship files -- free, no token, replacing HUD")
zt <- read.csv(file.path(BB, "tab20_zcta520_tract20_natl.txt"), sep = "|",
               colClasses = "character", check.names = FALSE)
zc <- read.csv(file.path(BB, "tab20_zcta520_county20_natl.txt"), sep = "|",
               colClasses = "character", check.names = FALSE)
cat(sprintf("  ZCTA->tract  %7d rows   %6d distinct ZCTA   %6d distinct tract\n",
            nrow(zt), length(unique(zt$GEOID_ZCTA5_20)), length(unique(zt$GEOID_TRACT_20))))
cat(sprintf("  ZCTA->county %7d rows   %6d distinct ZCTA   %6d distinct county\n",
            nrow(zc), length(unique(zc$GEOID_ZCTA5_20)), length(unique(zc$GEOID_COUNTY_20))))
cat("  ZCTA->tract is the BASE CASE grain. Phase 0 measured county-grain catchment\n")
cat("  weighting as near-redundant with naive county assignment (r 0.89-0.97), so the\n")
cat("  hours only pay for themselves at the finer grain.\n")

## ---- AHRF, CHR, RUCC --------------------------------------------------------
sub_("AHRF 2023-2024")
am <- utils::unzip(file.path(BB, "AHRF_2023-2024_SAS.zip"), list = TRUE)
for (k in seq_len(nrow(am))) cat(sprintf("  %-58s %8.0f KB\n", am$Name[k], am$Length[k] / 1024))
cat("  Source of primary-care-physician density. The 2023-2024 release RENAMED\n")
cat("  VARIABLES and added CSV subsets -- read the User Tech documentation before\n")
cat("  writing the extraction, which is Task 2.5 work, not Task 1.4 work.\n")

sub_("County Health Rankings 2025 -- the only non-public-domain Block B source")
chr <- rd(file.path(BB, "analytic_data2025_v3.csv"))
cat(sprintf("  %d rows, %d columns\n", nrow(chr), ncol(chr)))
cat(sprintf("  first columns: %s\n", paste(head(names(chr), 6), collapse = ", ")))
cat("  LICENCE: Creative Commons BY-NC-ND. Attribution required, non-commercial,\n")
cat("  no derivatives. This is open item 7 and it is NOT resolved by acquiring the\n")
cat("  file -- see provenance/task1.4-blockB.md section 5.\n")

sub_("USDA Rural-Urban Continuum Codes 2023")
ru <- rd(file.path(BB, "Ruralurbancontinuumcodes2023.csv"))
cat(sprintf("  %d rows, columns: %s\n", nrow(ru), paste(names(ru), collapse = ", ")))
cat("  Nine codes, county and county-equivalent, 2020 census + 2023 OMB delineation.\n")

sub_("NOT acquired, deliberately")
cat("  market concentration  -- DERIVED at Task 2.5 as an HHI over hospital shares\n")
cat("                           within each ZIP, from the Service Area File itself.\n")
cat("  HUD USPS crosswalk    -- now requires an API token; the Census relationship\n")
cat("                           files above do the same job with no registration.\n")
cat("  ACS uninsured / LEP   -- EP_UNINSUR and EP_LIMENG come from inside SVI.\n")
cat("  ADI ZIP+4 crosswalk   -- cannot join to 5-digit HSAF ZIPs (see stage 6).\n")

hdr("done")
