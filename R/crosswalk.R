# R/crosswalk.R  --  Task 2.1, the identifier crosswalk
#
# The spine of Phase 2. For every one of the 2,801 frame hospitals it connects
# five identifiers and reports the match rate of each join:
#
#   ccn              6-char CMS Certification Number -- the spine, from the frame
#   provider_number  Medicare provider number as it appears in the IPPS payment
#                    file. For a hospital it equals the CCN; the join's value is
#                    confirming that the payment layer covers the frame at all.
#   zip5             5-digit ZIP of the hospital's physical location
#   county_fips      5-digit state+county FIPS of the hospital's location
#   census_tract     11-digit 2020 census-tract GEOID of the hospital's location
#
# Standing rule 4: a hospital that fails a join is carried into
# output/tables/unmatched-hospitals.csv with whatever identifying information
# exists -- never dropped, never silently absorbed by a later failed merge.
#
# Every identifier has a primary source and at least one independent check:
#
#   join            primary                         cross-check
#   provider_number FY2026 IPPS Impact File          FY2025 Impact File, POS file
#   zip5            Care Compare Hospital General     POS ZIP_CD
#   county_fips     FY2026 Impact `FIPS County Code`  POS FIPS_STATE+CNTY, geocoder
#   census_tract    Census Bureau batch geocoder     -- (ZCTA fallback, flagged)
#
# The one external call is the Census Bureau batch geocoder. Its per-hospital
# result is cached to data-raw/geocode/ with a hash manifest and a sources.csv
# row, so re-runs are offline and the frozen analytic file at Task 2.8 is
# stable. Deleting the cache forces a fresh geocode; a scratch rebuild may then
# reassign a small number of tracts as the TIGER benchmark is revised -- the
# cache is the authority, exactly as the ADI vintage rows are.
#
# Base R. The geocoder POST goes through curl (system2), the same reasoning
# R/provenance.R shells out to shasum: the recipe must not lean on a package
# the recipe does not name.

source(file.path("R", "provenance.R"))

CC   <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
BA   <- file.path("data-raw", "blockA")
BB   <- file.path("data-raw", "blockB")
GEO  <- file.path("data-raw", "geocode")
GEO_CACHE <- file.path(GEO, "hospital-geocode.csv")

GEOCODER   <- "https://geocoding.geo.census.gov/geocoder/geographies/addressbatch"
GC_BENCH   <- "Public_AR_Current"
GC_VINTAGE <- "Census2020_Current"

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
z5  <- function(x) { d <- gsub("[^0-9]", "", x); ifelse(nchar(d) >= 5, substr(d, 1, 5), NA_character_) }

## Impact file: latin-1, header on line 2, tab-delimited, ragged tail.
## Same reader as R/blockA-coverage.R.
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

## ---- Census Bureau batch geocoder ----------------------------------------
## df: id, street, city, state, zip (all character). Returns one row per id:
## status, match_type, matched_address, lon, lat, state_fips, county_fips,
## tract_ce, block, tract_geoid. Chunked at 1,000; each chunk retried on an
## empty or short response. The service returns rows in arbitrary order, so the
## join is on the caller's id.
census_geocode <- function(df, chunk = 1000L, tries = 3L) {
  if (!nzchar(Sys.which("curl"))) stop("curl not on PATH; cannot reach the geocoder")
  df$street <- toupper(gsub("\\s+", " ", trimws(df$street)))
  parts <- split(df, ceiling(seq_len(nrow(df)) / chunk))
  out <- list()
  for (k in seq_along(parts)) {
    p <- parts[[k]]
    got <- NULL
    for (attempt in seq_len(tries)) {
      infile  <- tempfile(fileext = ".csv")
      outfile <- tempfile(fileext = ".csv")
      utils::write.table(p[, c("id", "street", "city", "state", "zip")], infile,
                         sep = ",", row.names = FALSE, col.names = FALSE,
                         qmethod = "double", na = "")
      st <- tryCatch(system2("curl", c("-s", "--max-time", "600",
                                       "--form", paste0("addressFile=@", infile),
                                       "--form", paste0("benchmark=", GC_BENCH),
                                       "--form", paste0("vintage=",   GC_VINTAGE),
                                       shQuote(GEOCODER)),
                             stdout = outfile, stderr = FALSE),
                     error = function(e) 1L)
      if (identical(st, 0L) && file.exists(outfile) && file.size(outfile) > 0) {
        r <- tryCatch(utils::read.csv(outfile, header = FALSE, colClasses = "character",
                                      col.names = paste0("V", 1:12), fill = TRUE,
                                      na.strings = character(0)),
                      error = function(e) NULL)
        if (!is.null(r) && nrow(r) >= 0.9 * nrow(p)) { got <- r; break }
      }
      Sys.sleep(2 * attempt)
    }
    if (is.null(got)) {
      cat(sprintf("    chunk %d/%d: no usable response after %d tries -- rows deferred\n",
                  k, length(parts), tries))
      got <- data.frame(V1 = p$id, V2 = "", V3 = "No_Response",
                        V4 = "", V5 = "", V6 = "", V7 = "", V8 = "",
                        V9 = "", V10 = "", V11 = "", V12 = "", stringsAsFactors = FALSE)
    }
    cat(sprintf("    chunk %d/%d: %d in, %d rows back, %d matched\n",
                k, length(parts), nrow(p), nrow(got), sum(got$V3 == "Match")))
    out[[k]] <- got
  }
  g <- do.call(rbind, out)

  matched <- g$V3 == "Match" & nzchar(g$V6)
  lonlat  <- strsplit(ifelse(matched, g$V6, ","), ",")
  res <- data.frame(
    id             = g$V1,
    status         = g$V3,
    match_type     = ifelse(matched, g$V4, NA_character_),
    matched_address= ifelse(matched, g$V5, NA_character_),
    lon            = vapply(lonlat, function(v) suppressWarnings(as.numeric(v[1])), numeric(1)),
    lat            = vapply(lonlat, function(v) suppressWarnings(as.numeric(v[2])), numeric(1)),
    state_fips     = ifelse(matched, formatC(n_(g$V9),  width = 2, flag = "0", format = "d"), NA_character_),
    county_fips    = ifelse(matched, formatC(n_(g$V10), width = 3, flag = "0", format = "d"), NA_character_),
    tract_ce       = ifelse(matched, formatC(n_(g$V11), width = 6, flag = "0", format = "d"), NA_character_),
    block          = ifelse(matched, trimws(g$V12), NA_character_),
    stringsAsFactors = FALSE)
  res$county_fips5 <- ifelse(is.na(res$state_fips), NA_character_,
                             paste0(res$state_fips, res$county_fips))
  res$tract_geoid  <- ifelse(is.na(res$state_fips), NA_character_,
                             paste0(res$state_fips, res$county_fips, res$tract_ce))
  ## one row per requested id, in the caller's order
  res[match(df$id, res$id), ]
}

## Build (or read) the geocode cache: passes A and B, one row per frame CCN.
geocode_cache <- function(base, pos) {
  if (file.exists(GEO_CACHE)) {
    cat("  reading cached geocode result: ", GEO_CACHE, "\n", sep = "")
    return(rd(GEO_CACHE))
  }
  cat("  no cache -- calling the Census batch geocoder\n")
  cat("    endpoint : ", GEOCODER, "\n", sep = "")
  cat("    benchmark: ", GC_BENCH, "   vintage: ", GC_VINTAGE, "\n", sep = "")

  sub_("geocode pass A -- Care Compare address")
  a <- census_geocode(data.frame(id = base$ccn, street = base$address, city = base$city,
                                 state = base$state, zip = base$zip5, stringsAsFactors = FALSE))
  hitA <- a$status == "Match" & !is.na(a$tract_geoid)
  cat(sprintf("  pass A matched %d / %d  (%s)\n", sum(hitA), nrow(a), pct(mean(hitA))))

  sub_("geocode pass B -- Provider of Services address, for pass-A misses")
  need <- !hitA
  pb <- pos[match(base$ccn[need], pos$ccn), ]
  b <- census_geocode(data.frame(id = base$ccn[need], street = pb$ST_ADR, city = pb$CITY_NAME,
                                 state = pb$STATE_CD, zip = z5(pb$ZIP_CD), stringsAsFactors = FALSE))
  hitB <- b$status == "Match" & !is.na(b$tract_geoid)
  cat(sprintf("  pass B matched %d / %d pass-A misses  (%s)\n",
              sum(hitB, na.rm = TRUE), nrow(b), pct(mean(hitB, na.rm = TRUE))))

  cache <- data.frame(
    ccn         = base$ccn,
    geo_pass    = ifelse(hitA, "hgi", NA_character_),
    status      = a$status,
    match_type  = a$match_type,
    matched_address = a$matched_address,
    lon = a$lon, lat = a$lat,
    county_fips5 = a$county_fips5,
    tract_geoid  = a$tract_geoid,
    block        = a$block,
    stringsAsFactors = FALSE)
  ib <- match(b$id, cache$ccn)
  take <- which(!is.na(hitB) & hitB)
  cache$geo_pass[ib[take]]        <- "pos"
  cache$status[ib[take]]          <- b$status[take]
  cache$match_type[ib[take]]      <- b$match_type[take]
  cache$matched_address[ib[take]] <- b$matched_address[take]
  cache$lon[ib[take]]             <- b$lon[take]
  cache$lat[ib[take]]             <- b$lat[take]
  cache$county_fips5[ib[take]]    <- b$county_fips5[take]
  cache$tract_geoid[ib[take]]     <- b$tract_geoid[take]
  cache$block[ib[take]]           <- b$block[take]

  dir.create(GEO, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(cache, GEO_CACHE, row.names = FALSE, na = "")
  manifest(GEO)
  cat("  wrote ", GEO_CACHE, " and its manifest\n", sep = "")
  rd(GEO_CACHE)
}

manifest <- function(dir) {
  fs <- setdiff(list.files(dir, full.names = TRUE), file.path(dir, "MANIFEST.sha256"))
  lines <- vapply(fs, function(f) paste0(sha256_file(f), "  ", basename(f)), character(1))
  writeLines(sort(lines), file.path(dir, "MANIFEST.sha256"))
}

## ZCTA -> largest-land-area tract, the flagged fallback for hospitals the
## geocoder cannot place. Census 2020 ZCTA relationship file, pipe-delimited,
## BOM on the header.
zcta_largest_tract <- function() {
  f <- file.path(BB, "tab20_zcta520_tract20_natl.txt")
  d <- read.table(f, sep = "|", header = TRUE, quote = "", comment.char = "",
                  colClasses = "character", check.names = FALSE, fileEncoding = "UTF-8-BOM")
  d <- d[nzchar(trimws(d$GEOID_ZCTA5_20)) & nzchar(trimws(d$GEOID_TRACT_20)), ]
  d$area <- n_(d$AREALAND_PART); d$area[is.na(d$area)] <- 0
  d <- d[order(d$GEOID_ZCTA5_20, -d$area), ]
  d <- d[!duplicated(d$GEOID_ZCTA5_20), ]
  setNames(formatC(d$GEOID_TRACT_20, width = 11, flag = "0"),
           formatC(trimws(d$GEOID_ZCTA5_20), width = 5, flag = "0"))
}

## The Census county universe -- the set of real 5-digit county GEOIDs. The
## Impact File's `FIPS County Code` is not always one: for FY2024 on, CMS
## adopted Connecticut's nine COG planning regions (09110..09190) in place of
## its eight legacy counties, and every county-grain Block B source (SVI, ADI,
## AHRF, CHR) is still keyed to the legacy counties. Validating against this
## set catches that and any other non-county code.
county_universe <- function() {
  f <- file.path(BB, "tab20_zcta520_county20_natl.txt")
  d <- read.table(f, sep = "|", header = TRUE, quote = "", comment.char = "",
                  colClasses = "character", check.names = FALSE, fileEncoding = "UTF-8-BOM")
  unique(formatC(trimws(d$GEOID_COUNTY_20[nzchar(trimws(d$GEOID_COUNTY_20))]),
                 width = 5, flag = "0"))
}

# ==========================================================================
hdr("TASK 2.1  the identifier crosswalk")

## ---- the spine: the frame, rebuilt from the outcome layer -----------------
cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame)
cat(sprintf("  frame n = %d   (VA and non-acute already excluded by Hospital Type)\n", N))

hgf <- hg[match(frame, hg$`Facility ID`), ]
base <- data.frame(
  ccn     = frame,
  name    = trimws(hgf$`Facility Name`),
  address = trimws(hgf$Address),
  city    = trimws(hgf$`City/Town`),
  state   = trimws(hgf$State),
  zip5    = z5(hgf$`ZIP Code`),
  county_name = trimws(hgf$`County/Parish`),
  stringsAsFactors = FALSE)

## ---- payment layer -------------------------------------------------------
i26 <- impact("fy2026-ipps-fr-impact-file.zip",   "FY 2026 IPPS Final Rule Impact File.txt")
i25 <- impact("fy-2025-ipps-fr-impact-file.zip",  "FY 2025 IPPS Impact File - Correction Notice.txt")
pos <- rd(file.path(BA, "Hospital_and_other.DATA.Q2_2026.csv"), enc = "latin1")
pos$ccn <- formatC(trimws(pos$PRVDR_NUM), width = 6, flag = "0")
pos <- pos[!duplicated(pos$ccn), ]

i26f <- i26[match(frame, i26$ccn), ]
i25f <- i25[match(frame, i25$ccn), ]
posf <- pos[match(frame, pos$ccn), ]

## ---- JOIN 1: ccn -> provider_number ------------------------------------
sub_("JOIN 1  ccn -> provider_number")
in26 <- frame %in% i26$ccn
in25 <- frame %in% i25$ccn
inpos<- frame %in% pos$ccn
base$provider_number        <- ifelse(in26, i26f$`Provider Number`, NA_character_)
base$provider_number_fy2025 <- ifelse(in25, i25f$`Provider Number`, NA_character_)
base$in_impact_fy2026 <- in26
base$in_impact_fy2025 <- in25
base$in_pos <- inpos
## a hospital CCN and its Medicare provider number are the same string; check it
pn_eq <- sum(in26 & formatC(trimws(i26f$`Provider Number`), width = 6, flag = "0") == frame, na.rm = TRUE)
cat(sprintf("  FY2026 Impact File   %d / %d  (%s)\n", sum(in26), N, pct(mean(in26))))
cat(sprintf("  FY2025 Impact File   %d / %d  (%s)\n", sum(in25), N, pct(mean(in25))))
cat(sprintf("  Provider of Services %d / %d  (%s)\n", sum(inpos), N, pct(mean(inpos))))
cat(sprintf("  provider_number == ccn wherever present: %d / %d\n", pn_eq, sum(in26)))
cat(sprintf("  absent from FY2026 Impact File: %s\n", paste(frame[!in26], collapse = ", ")))

## ---- JOIN 2: ccn -> zip5 ---------------------------------------------------
sub_("JOIN 2  ccn -> zip5")
base$zip5_pos <- z5(posf$ZIP_CD)
zip_ok   <- !is.na(base$zip5)
zip_both <- zip_ok & !is.na(base$zip5_pos)
zip_agree<- zip_both & base$zip5 == base$zip5_pos
base$zip5_source   <- ifelse(zip_ok, "care_compare", NA_character_)
base$zip5_agree_pos<- ifelse(zip_both, base$zip5 == base$zip5_pos, NA)
cat(sprintf("  Care Compare Hospital General Information  %d / %d  (%s)\n",
            sum(zip_ok), N, pct(mean(zip_ok))))
cat(sprintf("  POS ZIP_CD present                         %d / %d  (%s)\n",
            sum(!is.na(base$zip5_pos)), N, pct(mean(!is.na(base$zip5_pos)))))
cat(sprintf("  agree where both present                   %d / %d  (%s)\n",
            sum(zip_agree), sum(zip_both), pct(mean(zip_agree[zip_both]))))
cat(sprintf("  same 3-digit prefix among the disagreements: %d / %d\n",
            sum(substr(base$zip5, 1, 3) == substr(base$zip5_pos, 1, 3) & !zip_agree & zip_both, na.rm = TRUE),
            sum(!zip_agree & zip_both)))

## ---- JOIN 3: ccn -> county_fips ------------------------------------------
sub_("JOIN 3  ccn -> county_fips")
cf_impact <- ifelse(in26 & nchar(trimws(i26f$`FIPS County Code`)) == 5,
                    trimws(i26f$`FIPS County Code`), NA_character_)
cf_pos <- ifelse(nchar(trimws(posf$FIPS_STATE_CD)) > 0 & nchar(trimws(posf$FIPS_CNTY_CD)) > 0,
                 paste0(formatC(n_(posf$FIPS_STATE_CD), width = 2, flag = "0", format = "d"),
                        formatC(n_(posf$FIPS_CNTY_CD),  width = 3, flag = "0", format = "d")),
                 NA_character_)
base$county_fips_impact <- cf_impact
base$county_fips_pos    <- cf_pos
cf_both  <- !is.na(cf_impact) & !is.na(cf_pos)
cf_agree <- cf_both & cf_impact == cf_pos

## Is the Impact File code an actual census county?
VALID_CTY <- county_universe()
cf_impact_real <- !is.na(cf_impact) & cf_impact %in% VALID_CTY
notcty <- !is.na(cf_impact) & !cf_impact_real
cat(sprintf("  FY2026 Impact File `FIPS County Code`  %d / %d  (%s)\n",
            sum(!is.na(cf_impact)), N, pct(mean(!is.na(cf_impact)))))
cat(sprintf("  ... that are a real census county      %d / %d  (%s)\n",
            sum(cf_impact_real), N, pct(mean(cf_impact_real))))
if (any(notcty)) {
  cat(sprintf("  ... NOT a census county               %d   states: %s\n",
              sum(notcty), paste(sort(unique(base$state[notcty])), collapse = " ")))
  cat("      (Connecticut COG planning regions -- CMS adopted them for FY2024+; every\n")
  cat("       county-grain Block B source is still on the 8 legacy counties. Replaced\n")
  cat("       from POS below, which carries the legacy county for all of them.)\n")
}
cat(sprintf("  POS FIPS_STATE_CD + FIPS_CNTY_CD       %d / %d  (%s)\n",
            sum(!is.na(cf_pos)), N, pct(mean(!is.na(cf_pos)))))
cat(sprintf("  agree where both present               %d / %d  (%s)\n",
            sum(cf_agree), sum(cf_both), pct(mean(cf_agree[cf_both]))))

## ---- JOIN 4: ccn -> census_tract ---------------------------------------
sub_("JOIN 4  ccn -> census_tract")
gc <- geocode_cache(base, pos)
gcf <- gc[match(frame, gc$ccn), ]
tract_geo   <- ifelse(nzchar(trimws(gcf$tract_geoid)) & !is.na(gcf$tract_geoid),
                      formatC(trimws(gcf$tract_geoid), width = 11, flag = "0"), NA_character_)
geo_pass    <- trimws(gcf$geo_pass)
hitA <- !is.na(tract_geo) & geo_pass == "hgi"
hitB <- !is.na(tract_geo) & geo_pass == "pos"

## pass C: ZCTA largest-tract fallback for whatever the geocoder could not place
z2t <- zcta_largest_tract()
need_c <- is.na(tract_geo)
tract_c <- ifelse(need_c & base$zip5 %in% names(z2t), z2t[base$zip5], NA_character_)

base$census_tract <- ifelse(!is.na(tract_geo), tract_geo, tract_c)
base$tract_source <- ifelse(hitA, "geocode_hgi",
                     ifelse(hitB, "geocode_pos",
                     ifelse(!is.na(tract_c), "zcta_fallback", "unmatched")))
base$tract_match_type <- ifelse(!is.na(tract_geo), trimws(gcf$match_type), NA_character_)
base$lat <- suppressWarnings(as.numeric(gcf$lat))
base$lon <- suppressWarnings(as.numeric(gcf$lon))
base$lat[is.na(tract_geo)] <- NA; base$lon[is.na(tract_geo)] <- NA

cumA <- mean(hitA)
cumB <- mean(hitA | hitB)
cumC <- mean(base$tract_source != "unmatched")
cat(sprintf("  pass A  geocoder on Care Compare address   %4d  (%s cumulative)\n", sum(hitA), pct(cumA)))
cat(sprintf("  pass B  + geocoder on POS address          %4d  (%s cumulative)\n", sum(hitB), pct(cumB)))
cat(sprintf("  pass C  + ZCTA largest-tract fallback      %4d  (%s cumulative)\n",
            sum(base$tract_source == "zcta_fallback"), pct(cumC)))
cat(sprintf("  still unmatched                            %4d\n",
            sum(base$tract_source == "unmatched")))
cat(sprintf("  of the geocoder matches, Exact: %s\n",
            pct(mean(base$tract_match_type[!is.na(base$tract_match_type)] == "Exact"))))

## geocoder county vs Impact File county -- an address-level check on the spine
gc_cf <- ifelse(nzchar(trimws(gcf$county_fips5)) & !is.na(gcf$county_fips5),
                formatC(trimws(gcf$county_fips5), width = 5, flag = "0"), NA_character_)
base$county_fips_geocode <- gc_cf
qc_both  <- !is.na(gc_cf) & !is.na(cf_impact)
qc_agree <- qc_both & gc_cf == cf_impact
cat(sprintf("\n  QC  geocoder county == Impact File county  %d / %d  (%s)\n",
            sum(qc_agree), sum(qc_both), pct(mean(qc_agree[qc_both]))))

## final county_fips: the Impact File where it names a real county, then POS,
## then the geocoder -- each candidate must itself be a valid census county.
pos_real <- !is.na(cf_pos) & cf_pos %in% VALID_CTY
gc_real  <- !is.na(gc_cf)  & gc_cf  %in% VALID_CTY
base$county_fips <- ifelse(cf_impact_real, cf_impact,
                    ifelse(pos_real, cf_pos,
                    ifelse(gc_real, gc_cf, NA_character_)))
base$county_fips_source <- ifelse(cf_impact_real, "impact_fy2026",
                           ifelse(pos_real, "pos",
                           ifelse(gc_real, "geocode", NA_character_)))
base$county_fips_source[notcty & base$county_fips_source == "pos"] <- "pos (impact code was a COG region)"
cat(sprintf("\n  final county_fips resolved             %d / %d  (%s)\n",
            sum(!is.na(base$county_fips)), N, pct(mean(!is.na(base$county_fips)))))
cat("  source: ")
cat(paste(sprintf("%s=%d", names(table(base$county_fips_source)), table(base$county_fips_source)),
          collapse = "  "), "\n")

## enumerate the county disagreements -- two independent sources against the
## Impact File spine. The Impact File FIPS is the payment-processing county and
## is occasionally not the physical-location county; the table lets the report
## say which hospitals and how far off (same state? adjacent county?).
dis <- which((cf_both & !cf_agree) | (qc_both & !qc_agree))
cdis <- data.frame(
  ccn = base$ccn[dis], name = base$name[dis], state = base$state[dis],
  city = base$city[dis], zip5 = base$zip5[dis],
  county_fips_impact = cf_impact[dis], county_fips_pos = cf_pos[dis],
  county_fips_geocode = gc_cf[dis],
  pos_vs_impact  = ifelse(cf_both[dis], ifelse(cf_agree[dis], "agree", "DIFFER"), "pos NA"),
  geo_vs_impact  = ifelse(qc_both[dis], ifelse(qc_agree[dis], "agree", "DIFFER"), "geo NA"),
  same_state = ifelse(!is.na(cf_pos[dis]),
                      substr(cf_impact[dis], 1, 2) == substr(cf_pos[dis], 1, 2), NA),
  reason = ifelse(notcty[dis], "impact code is a CT COG planning region, not a county",
                  "boundary/reclassification difference between sources"),
  resolved_to = base$county_fips[dis],
  resolved_from = base$county_fips_source[dis],
  stringsAsFactors = FALSE)
cdis <- cdis[order(cdis$state, cdis$ccn), ]
write.csv(cdis, file.path("output", "tables", "crosswalk-county-disagreements.csv"), row.names = FALSE)
cat(sprintf("\n  county disagreements enumerated: %d rows -> output/tables/crosswalk-county-disagreements.csv\n",
            nrow(cdis)))
cat(sprintf("    POS differs from Impact File   %d   (of these, %d in the same state)\n",
            sum(cdis$pos_vs_impact == "DIFFER"),
            sum(cdis$pos_vs_impact == "DIFFER" & cdis$same_state, na.rm = TRUE)))
cat(sprintf("    geocoder differs from Impact File %d\n", sum(cdis$geo_vs_impact == "DIFFER")))

## ---- context columns for the unmatched characterization -----------------
base$beds  <- n_(i26f$Beds)
base$urgeo <- ifelse(in26, trimws(i26f$URGEO), NA_character_)
base$cbsa  <- ifelse(in26, trimws(i26f$`Geographic Labor Market Area`), NA_character_)
base$zcta5 <- ifelse(base$zip5 %in% names(z2t), base$zip5, NA_character_)

## ==========================================================================
## match-rate table -- one row per join
## ==========================================================================
mr <- function(join, source, n_matched, n_pool, extra = "") {
  data.frame(join = join, source = source, n = n_pool, n_matched = n_matched,
             match_rate = pct(n_matched / n_pool, 2), notes = extra,
             stringsAsFactors = FALSE)
}
rates <- rbind(
  mr("provider_number", "FY2026 IPPS Impact File `Provider Number`", sum(in26), N,
     sprintf("absent: %s", paste(frame[!in26], collapse = " "))),
  mr("provider_number (check)", "FY2025 IPPS Impact File", sum(in25), N, ""),
  mr("provider_number (check)", "Provider of Services File `PRVDR_NUM`", sum(inpos), N, ""),
  mr("zip5", "Care Compare Hospital General Information `ZIP Code`", sum(zip_ok), N, ""),
  mr("zip5 (check)", "Provider of Services File `ZIP_CD`", sum(!is.na(base$zip5_pos)), N,
     sprintf("agree with primary: %s", pct(mean(zip_agree[zip_both]), 1))),
  mr("county_fips", "FY2026 IPPS Impact File `FIPS County Code`, real census county",
     sum(cf_impact_real), N,
     sprintf("%d present; %d are CT COG regions, replaced from POS", sum(!is.na(cf_impact)), sum(notcty))),
  mr("county_fips (check)", "Provider of Services File FIPS_STATE+CNTY", sum(!is.na(cf_pos)), N,
     sprintf("agree with primary: %s", pct(mean(cf_agree[cf_both]), 1))),
  mr("county_fips (check)", "Census geocoder county", sum(qc_both), N,
     sprintf("agree with primary: %s", pct(mean(qc_agree[qc_both]), 1))),
  mr("county_fips final", "impact where a real county, else POS, else geocoder",
     sum(!is.na(base$county_fips)), N, ""),
  mr("census_tract pass A", "Census geocoder on Care Compare address", sum(hitA), N, ""),
  mr("census_tract pass B", "+ Census geocoder on POS address", sum(hitA | hitB), N,
     "cumulative"),
  mr("census_tract pass C", "+ ZCTA largest-land-area tract fallback",
     sum(base$tract_source != "unmatched"), N,
     sprintf("cumulative; %d via fallback, flagged tract_source=zcta_fallback",
             sum(base$tract_source == "zcta_fallback"))),
  mr("census_tract final", "any source", sum(base$tract_source != "unmatched"), N,
     sprintf("%d unmatched", sum(base$tract_source == "unmatched")))
)
write.csv(rates, file.path("output", "tables", "crosswalk-match-rates.csv"), row.names = FALSE)

sub_("match rates, per join")
for (i in seq_len(nrow(rates))) {
  cat(sprintf("  %-22s %-46s %8s  %s\n", rates$join[i], substr(rates$source[i], 1, 46),
              rates$match_rate[i], rates$notes[i]))
}

## ==========================================================================
## unmatched-hospitals table -- standing rule 4
## ==========================================================================
## A hospital is listed if, after every source and the flagged fallback, an
## identifier is missing (status "unresolved") OR was only obtainable from a
## coarse fallback (status "fallback_zcta", census_tract only).
flags <- data.frame(
  provider_number = ifelse(is.na(base$provider_number), "unresolved", ""),
  zip5            = ifelse(is.na(base$zip5), "unresolved", ""),
  county_fips     = ifelse(is.na(base$county_fips), "unresolved", ""),
  census_tract    = ifelse(base$tract_source == "unmatched", "unresolved",
                    ifelse(base$tract_source == "zcta_fallback", "fallback_zcta", "")),
  stringsAsFactors = FALSE)
listed <- which(rowSums(flags != "") > 0)
um <- data.frame(
  ccn = base$ccn[listed], name = base$name[listed], state = base$state[listed],
  city = base$city[listed], zip5 = base$zip5[listed],
  county_name = base$county_name[listed], beds = base$beds[listed],
  urgeo = base$urgeo[listed],
  unmatched_on = apply(flags[listed, , drop = FALSE], 1,
                       function(r) paste(names(flags)[r != ""], collapse = ";")),
  status = apply(flags[listed, , drop = FALSE], 1,
                 function(r) paste(unique(r[r != ""]), collapse = ";")),
  provider_number = base$provider_number[listed],
  county_fips = base$county_fips[listed],
  census_tract = base$census_tract[listed],
  stringsAsFactors = FALSE)
um <- um[order(um$status, um$state, um$ccn), ]
write.csv(um, file.path("output", "tables", "unmatched-hospitals.csv"), row.names = FALSE)

sub_("unmatched hospitals -- characterization")
cat(sprintf("  rows in the table: %d  (of frame %d)\n", nrow(um), N))
cat("  by status:\n")
for (s in names(sort(table(um$status), decreasing = TRUE)))
  cat(sprintf("    %-16s %4d\n", s, sum(um$status == s)))
cat("  by identifier:\n")
for (f in names(flags)) {
  n <- sum(flags[[f]] != "")
  if (n) cat(sprintf("    %-16s %4d\n", f, n))
}
if (nrow(um)) {
  cat(sprintf("  rural (URGEO == RURAL): %s of the unmatched vs %s of the frame\n",
              pct(sum(um$urgeo == "RURAL", na.rm = TRUE) / nrow(um)),
              pct(mean(base$urgeo == "RURAL", na.rm = TRUE))))
  fb <- base$beds[base$ccn %in% um$ccn]
  cat(sprintf("  bed count: unmatched median %s vs frame median %.0f\n",
              ifelse(all(is.na(fb)), "NA", as.character(round(median(fb, na.rm = TRUE)))),
              median(base$beds, na.rm = TRUE)))
  top_st <- sort(table(um$state), decreasing = TRUE)
  cat("  top states: ",
      paste(sprintf("%s=%d", names(head(top_st, 6)), head(top_st, 6)), collapse = "  "), "\n")
}

## ==========================================================================
## freeze the crosswalk
## ==========================================================================
cw <- base[, c("ccn", "provider_number", "provider_number_fy2025",
               "in_impact_fy2026", "in_impact_fy2025", "in_pos",
               "name", "state", "city", "county_name",
               "zip5", "zip5_pos", "zip5_source", "zip5_agree_pos",
               "county_fips", "county_fips_source",
               "county_fips_impact", "county_fips_pos", "county_fips_geocode",
               "census_tract", "tract_source", "tract_match_type",
               "lat", "lon", "zcta5", "cbsa", "beds", "urgeo")]
saveRDS(cw, file.path("data", "crosswalk.rds"))

sub_("data/crosswalk.rds")
cat(sprintf("  %d rows, %d columns\n", nrow(cw), ncol(cw)))
cat("  columns: ", paste(names(cw), collapse = ", "), "\n")
cat(sprintf("  fully crosswalked (all four identifiers, no fallback): %d / %d  (%s)\n",
            sum(!is.na(cw$provider_number) & !is.na(cw$zip5) & !is.na(cw$county_fips) &
                cw$tract_source %in% c("geocode_hgi", "geocode_pos")),
            N, pct(mean(!is.na(cw$provider_number) & !is.na(cw$zip5) & !is.na(cw$county_fips) &
                cw$tract_source %in% c("geocode_hgi", "geocode_pos")))))

## ---- provenance row for the geocoder, once the cache exists --------------
prov <- tryCatch(prov_read(), error = function(e) NULL)
if (!is.null(prov) && !("census_geocoder" %in% prov$source_id) && file.exists(GEO_CACHE)) {
  prov_add(
    source_id = "census_geocoder",
    source = "U.S. Census Bureau Geocoding Services API, batch geographies endpoint",
    file = GEO_CACHE,
    url = paste0(GEOCODER, "  (multipart POST: addressFile=<id,street,city,state,zip>, ",
                 "benchmark=", GC_BENCH, ", vintage=", GC_VINTAGE,
                 "); pass A = Care Compare address, pass B = Provider of Services address for pass-A misses"),
    retrieval_method = "web API",
    vintage = paste0("geography vintage ", GC_VINTAGE, ", benchmark ", GC_BENCH,
                     " as of ", format(Sys.Date())),
    license = "Public domain, U.S. Government work. Census Bureau geocoder output carries no license or rights restriction.",
    parse_notes = paste0("Response is headerless CSV, rows in arbitrary order -- join on the supplied id. ",
                         "A match row has 12 fields; No_Match has 3. Quoted coords field is 'lon,lat'. ",
                         "tract GEOID = statefp(2)+countyfp(3)+tractce(6). Benchmark 'Public_AR_Current' ",
                         "is revised over time; the cached file is the authority and is hash-frozen here. ",
                         "Hospitals the geocoder cannot place fall back to the ZCTA largest-land-area tract ",
                         "(tract_source=zcta_fallback in data/crosswalk.rds), not this file.")
  )
  cat("\n  provenance: added row `census_geocoder` (", nrow(prov) + 1, " rows)\n", sep = "")
} else {
  cat("\n  provenance: `census_geocoder` row already present or cache absent\n")
}

hdr("done")
