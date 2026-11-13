# R/blockA.R  --  Task 2.3, Block A (hospital structure)
#
# The ten plan-§4 structural covariates, one row per frame CCN:
#
#   beds, ownership, teaching intensity, case mix index, DSH percentage,
#   wage index, system membership, occupancy, operating margin,
#   uncompensated care burden
#
# Sources and the vintage split, decided and measured at Task 1.3
# (task1.3-blockA.md §2, spike-structure.md §2):
#
#   FY2026 IPPS Impact File   structural / payment-policy fields -- beds, ADC,
#                             resident-to-bed ratio, DSHPCT, wage index,
#                             ownership, provider type. Built on FY2024 MedPAR.
#   FY2025 IPPS Impact File    case mix (TACMIV42, transfer-adjusted, grouper
#     (Correction Notice)      V42) and Medicare volume (Bills). Built on FY2023
#                              MedPAR -- inside the PSI window near its midpoint.
#   HCRIS Cost Report PUF      operating margin, uncompensated care, occupancy
#     FY2023 Final             cross-check, DSH cross-check, discharges.
#                              62 CCNs file >1 report -- deduplicated by LONGEST
#                              fiscal period (never the first row).
#   HCRIS PUF FY2022 Final     deterministic cross-year recovery for the
#                              financial fields (standing rule 7: an adjacent
#                              fiscal year is observed data, not imputation).
#   Hospital Enrollments +     system membership. The plan's source (POS) is
#     Hospital All Owners      empty for every row (task1.3-blockA.md §4);
#                              this pair, joined on ENROLLMENT ID, is the
#                              substitute at 98.7%.
#
# Verify (Task 2.3): each variable's range is plausible; outliers are ENUMERATED
# for inspection in output/tables/blockA-outliers.csv, never winsorized on
# sight, and never silently dropped (standing rule 4).
#
# Base R. Reads the permanent Task 1.3 layout and the Task 2.1 crosswalk spine.

CC <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
BA <- file.path("data-raw", "blockA")

rd  <- function(p, enc = "") read.csv(p, colClasses = "character", check.names = FALSE,
                                      na.strings = character(0), fileEncoding = enc)
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")
pdt <- function(x) as.Date(trimws(x), tryFormats = c("%m/%d/%Y", "%Y-%m-%d"))

## Impact file: latin-1, header on line 2, tab-delimited, ragged tail. Same
## reader as R/blockA-coverage.R, R/crosswalk.R, R/outcomes.R.
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

## HCRIS PUF, deduplicated to one report per CCN by LONGEST fiscal period
## (task1.3-blockA.md §1: never the first row), tie broken by the later end date.
hcris_dedup <- function(file) {
  cr <- rd(file.path(BA, file))
  cr$ccn <- formatC(trimws(cr$`Provider CCN`), width = 6, flag = "0")
  cr$fb  <- pdt(cr$`Fiscal Year Begin Date`)
  cr$fe  <- pdt(cr$`Fiscal Year End Date`)
  cr$len <- as.numeric(cr$fe - cr$fb)
  cr <- cr[order(cr$ccn, -cr$len, -as.numeric(cr$fe)), ]
  cr[!duplicated(cr$ccn), ]
}

OWN <- c(V = "voluntary nonprofit", P = "proprietary (for-profit)",
         G = "government", X = "unknown")
PTYPE <- c("0" = "IPPS (no special status)", "7" = "Rural Referral Center",
           "8" = "Indian Health Service", "16" = "Sole Community Hospital",
           "17" = "SCH and RRC", "21" = "Essential Access Community Hospital",
           "22" = "EACH and RRC")

# ==========================================================================
hdr("TASK 2.3  Block A -- hospital structure")

cd <- rd(file.path(CC, "Complications_and_Deaths-Hospital.csv"))
hg <- rd(file.path(CC, "Hospital_General_Information.csv"))
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame)
cat(sprintf("  frame n = %d\n", N))

cw <- readRDS(file.path("data", "crosswalk.rds"))
stopifnot(setequal(frame, cw$ccn))
cwf <- cw[match(frame, cw$ccn), ]

i26 <- impact("fy2026-ipps-fr-impact-file.zip",  "FY 2026 IPPS Final Rule Impact File.txt")
i25 <- impact("fy-2025-ipps-fr-impact-file.zip", "FY 2025 IPPS Impact File - Correction Notice.txt")
h23 <- hcris_dedup("CostReport_2023_Final.csv")
h22 <- hcris_dedup("CostReport_2022_Final.csv")

I26 <- i26[match(frame, i26$ccn), ]
I25 <- i25[match(frame, i25$ccn), ]
H23 <- h23[match(frame, h23$ccn), ]
H22 <- h22[match(frame, h22$ccn), ]

b <- data.frame(ccn = frame, stringsAsFactors = FALSE)
b$in_impact_fy2026 <- frame %in% i26$ccn
b$in_impact_fy2025 <- frame %in% i25$ccn
b$in_hcris_fy2023  <- frame %in% h23$ccn

# ==========================================================================
# 1. structural fields -- FY2026 Impact File
# ==========================================================================
sub_("structural fields -- FY2026 Impact File")
b$beds              <- n_(I26$Beds)
b$adc               <- n_(I26$`Average Daily Census`)
b$occupancy         <- b$adc / b$beds                       # gate primary
b$resident_to_bed   <- n_(I26$`Resident to Bed Ratio`)      # teaching intensity
b$teaching          <- b$resident_to_bed > 0                # explicit 0 = non-teaching
b$dsh_pct           <- n_(I26$DSHPCT)
b$wage_index        <- n_(I26$`FY 2026 Wage Index`)
b$ownership_code    <- ifelse(b$in_impact_fy2026, trimws(I26$`Ownership Control Type`), NA_character_)
b$ownership         <- unname(OWN[b$ownership_code])
b$provider_type_code<- ifelse(b$in_impact_fy2026, trimws(I26$`Provider Type`), NA_character_)
b$provider_type     <- unname(PTYPE[b$provider_type_code])
b$urban_rural       <- ifelse(b$in_impact_fy2026, trimws(I26$URGEO), NA_character_)

for (v in c("beds", "adc", "occupancy", "resident_to_bed", "dsh_pct", "wage_index"))
  cat(sprintf("  %-16s present %s\n", v, pct(mean(!is.na(b[[v]])))))
cat("  ownership : "); print(table(b$ownership, useNA = "ifany"))
cat("  teaching  : ", sum(b$teaching, na.rm = TRUE), " teaching, ",
    sum(!b$teaching, na.rm = TRUE), " non-teaching (explicit 0), ",
    sum(is.na(b$teaching)), " unknown\n", sep = "")
cat("  provider_type : "); print(table(b$provider_type, useNA = "ifany"))

# ==========================================================================
# 2. case mix and Medicare volume -- FY2025 Impact File (the vintage decision)
# ==========================================================================
sub_("case mix + volume -- FY2025 Impact File (MedPAR inside the PSI window)")
b$cmi          <- n_(I25$TACMIV42)          # transfer-adjusted, grouper V42
b$volume_bills <- n_(I25$Bills)             # Medicare cases, FY2023 MedPAR
cat(sprintf("  cmi (TACMIV42)     present %s   median %.3f\n",
            pct(mean(!is.na(b$cmi))), median(b$cmi, na.rm = TRUE)))
cat(sprintf("  volume_bills       present %s   median %.0f\n",
            pct(mean(!is.na(b$volume_bills))), median(b$volume_bills, na.rm = TRUE)))
## cross-vintage: the reason this is a Phase 3 axis, not a default
cmi26 <- setNames(n_(i26$TACMIV42), i26$ccn)[frame]
g <- !is.na(b$cmi) & !is.na(cmi26)
cat(sprintf("  TACMIV42 FY2025 vs FY2026: r %.4f  (median %.3f vs %.3f) -- carried as a spec axis\n",
            cor(b$cmi[g], cmi26[g]), median(b$cmi[g]), median(cmi26[g])))

# ==========================================================================
# 3. financial fields -- HCRIS FY2023, with FY2022 deterministic recovery
# ==========================================================================
sub_("financial fields -- HCRIS FY2023 Final, FY2022 cross-year recovery")

## one helper: take FY2023, fall back to FY2022, record which
fill <- function(v23, v22) {
  out <- v23; src <- ifelse(!is.na(v23), "fy2023", NA_character_)
  take <- is.na(v23) & !is.na(v22)
  out[take] <- v22[take]; src[take] <- "fy2022"
  src[is.na(out)] <- "missing"
  list(value = out, source = src)
}

npr23 <- n_(H23$`Net Patient Revenue`); npr22 <- n_(H22$`Net Patient Revenue`)
toe23 <- n_(H23$`Less Total Operating Expense`); toe22 <- n_(H22$`Less Total Operating Expense`)
unc23 <- n_(H23$`Cost of Uncompensated Care`);   unc22 <- n_(H22$`Cost of Uncompensated Care`)

fn <- fill(npr23, npr22);  b$net_patient_revenue <- fn$value
ft <- fill(toe23, toe22);  b$total_operating_expense <- ft$value
fu <- fill(unc23, unc22);  b$uncompensated_care <- fu$value; b$uncompensated_care_source <- fu$source

## operating margin: guard the denominator at $1M (task 0.3 used the same floor
## for the contract-labour share; below it the ratio is not meaningful).
den_ok <- !is.na(b$net_patient_revenue) & b$net_patient_revenue >= 1e6 & !is.na(b$total_operating_expense)
b$operating_margin <- ifelse(den_ok,
                             (b$net_patient_revenue - b$total_operating_expense) / b$net_patient_revenue,
                             NA_real_)
## source: fy2023 if both inputs are FY2023, fy2022_fill if either was filled,
## and the reason otherwise
b$operating_margin_source <- ifelse(
  !den_ok,
  ifelse(!is.na(b$net_patient_revenue) & b$net_patient_revenue < 1e6, "denominator < $1M", "missing"),
  ifelse(fn$source == "fy2023" & ft$source == "fy2023", "fy2023", "fy2022_fill"))

## uncompensated care burden: raw cost is the covariate (spike-structure.md §3);
## also carry it normalised by net patient revenue.
b$uncompensated_care_pct_npr <- ifelse(!is.na(b$net_patient_revenue) & b$net_patient_revenue >= 1e6,
                                       b$uncompensated_care / b$net_patient_revenue, NA_real_)

## HCRIS cross-checks
b$occupancy_hcris <- n_(H23$`Total Days (V + XVIII + XIX + Unknown)`) / n_(H23$`Total Bed Days Available`)
b$dsh_pct_hcris   <- n_(H23$`Allowable DSH Percentage`)
b$beds_hcris      <- n_(H23$`Number of Beds`)
b$discharges      <- n_(H23$`Total Discharges (V + XVIII + XIX + Unknown)`)
b$hcris_fy_begin  <- as.character(H23$fb)
b$hcris_fy_end    <- as.character(H23$fe)
W0 <- as.Date("2022-07-01"); W1 <- as.Date("2024-06-30")
b$hcris_window_overlap_days <- pmax(0, as.numeric(pmin(H23$fe, W1) - pmax(H23$fb, W0)) + 1)

cat(sprintf("  operating margin   present %s  (FY2023 %s + FY2022 fill %s)\n",
            pct(mean(!is.na(b$operating_margin))),
            pct(mean(!is.na(n_(H23$`Net Patient Revenue`)) & n_(H23$`Net Patient Revenue`) >= 1e6)),
            pct(mean(!is.na(b$operating_margin)) - mean(!is.na(n_(H23$`Net Patient Revenue`)) & n_(H23$`Net Patient Revenue`) >= 1e6))))
cat("  operating_margin_source : "); print(table(b$operating_margin_source, useNA = "ifany"))
cat(sprintf("  uncompensated care present %s\n", pct(mean(!is.na(b$uncompensated_care)))))
cat("  uncompensated_care_source : "); print(table(b$uncompensated_care_source, useNA = "ifany"))
cat(sprintf("  HCRIS FY overlaps PSI window: median %.0f days, %s wholly inside, %s zero overlap\n",
            median(b$hcris_window_overlap_days, na.rm = TRUE),
            pct(mean(b$hcris_window_overlap_days >= 364, na.rm = TRUE)),
            pct(mean(b$hcris_window_overlap_days == 0, na.rm = TRUE))))

# ==========================================================================
# 4. system membership -- Hospital Enrollments + Hospital All Owners
# ==========================================================================
sub_("system membership -- Enrollments + All Owners (POS is empty; task1.3 §4)")
en <- rd(file.path(BA, "Hospital_Enrollments_2026.07.31.csv"))
ow <- rd(file.path(BA, "Hospital_All_Owners_2026.07.31.csv"), enc = "latin1")
ecc <- trimws(en$CCN)
en$ccn <- substr(ifelse(nchar(ecc) == 5, paste0("0", ecc), ecc), 1, 6)   # ragged: widths 5..9
ow$ccn <- setNames(en$ccn, en$`ENROLLMENT ID`)[ow$`ENROLLMENT ID`]

owf <- ow[!is.na(ow$ccn) & ow$ccn %in% frame, ]
owf$is_org <- nzchar(trimws(owf$`ORGANIZATION NAME - OWNER`))
org <- owf[owf$is_org, ]
org$owner_id  <- trimws(org$`ASSOCIATE ID - OWNER`)
org$owner_nm  <- trimws(org$`ORGANIZATION NAME - OWNER`)
org$own_pct   <- n_(org$`PERCENTAGE OWNERSHIP`)

## how many frame hospitals each organisational owner holds
owner_size <- tapply(org$ccn, org$owner_id, function(v) length(unique(v)))
org$owner_size <- owner_size[org$owner_id]

## a hospital's "system" = its organisational owner that holds the most frame
## hospitals (ties -> higher ownership %). HCA appears under 5 ASSOCIATE IDs
## (HCA INC, HEALTHTRUST INC, HERCULES/FRISCO HOLDING II, ...); picking the
## largest consolidates the holding chain to one system per hospital.
org <- org[order(org$ccn, -org$owner_size, -ifelse(is.na(org$own_pct), -1, org$own_pct)), ]
prim <- org[!duplicated(org$ccn), ]
mp <- match(frame, prim$ccn)

has_any_owner <- frame %in% owf$ccn
has_org_owner <- frame %in% org$ccn
b$has_owner_record <- has_any_owner
b$owner_type    <- ifelse(!has_any_owner, "none",
                   ifelse(has_org_owner, "organization", "individual"))
b$system_id     <- prim$owner_id[mp]
b$system_name   <- prim$owner_nm[mp]
b$system_size   <- as.numeric(prim$owner_size[mp])
b$system_member <- !is.na(b$system_size) & b$system_size >= 2

cat(sprintf("  frame with an owner record        %d / %d  (%s)\n",
            sum(has_any_owner), N, pct(mean(has_any_owner))))
cat(sprintf("  ... organisational owner          %d   ... individual owners only  %d\n",
            sum(has_org_owner), sum(has_any_owner & !has_org_owner)))
cat(sprintf("  ... absent from Enrollments (true missing)  %d\n", sum(!has_any_owner)))
cat(sprintf("  frame hospitals in a multi-hospital system  %d  (%s)\n",
            sum(b$system_member), pct(mean(b$system_member))))
cat(sprintf("  distinct systems (>=2 frame hospitals): %d\n", sum(owner_size >= 2, na.rm = TRUE)))
topn <- head(sort(tapply(b$ccn[b$system_member], b$system_name[b$system_member],
                         length), decreasing = TRUE), 5)
for (k in names(topn)) cat(sprintf("    %-42s %d\n", substr(k, 1, 42), topn[k]))

# ==========================================================================
# 5. plausibility -- ranges and enumerated outliers (the verify condition)
# ==========================================================================
hdr("PLAUSIBILITY -- ranges checked, outliers enumerated (not winsorized)")

## flags: booleans on the frozen table; raw values are left untouched
b$flag_beds_missing     <- is.na(b$beds)
b$flag_occupancy_gt1    <- !is.na(b$occupancy) & b$occupancy > 1
b$flag_occupancy_zero   <- !is.na(b$adc) & b$adc == 0
b$flag_dsh_gt1          <- !is.na(b$dsh_pct) & b$dsh_pct > 1
b$flag_margin_extreme   <- !is.na(b$operating_margin) & abs(b$operating_margin) > 1
b$flag_npr_tiny         <- !is.na(b$net_patient_revenue) & b$net_patient_revenue < 1e6
b$flag_uncomp_missing   <- is.na(b$uncompensated_care)

rng <- function(name, x, source, lo, hi, note = "") {
  x <- x[!is.na(x)]
  q <- quantile(x, c(.05, .25, .5, .75, .95), names = FALSE, type = 7)
  nflag <- sum(x < lo | x > hi)
  data.frame(covariate = name, source = source, n = length(x),
             min = min(x), p05 = q[1], median = q[3], p95 = q[5], max = max(x),
             plausible_range = sprintf("[%s, %s]", lo, hi),
             n_outside = nflag, note = note, stringsAsFactors = FALSE)
}
ranges <- rbind(
  rng("beds",              b$beds,             "impact_fy2026", 1, 3000),
  rng("occupancy",         b$occupancy,        "impact_fy2026 ADC/Beds", 0, 1,
      sprintf("%d hospitals ADC > Beds -- inspect, do not winsorize", sum(b$flag_occupancy_gt1))),
  rng("resident_to_bed",   b$resident_to_bed,  "impact_fy2026", 0, 2.5),
  rng("dsh_pct",           b$dsh_pct,          "impact_fy2026", 0, 1,
      sprintf("%d > 1.0 -- DPP is a sum of two ratios, can legitimately exceed 1", sum(b$flag_dsh_gt1))),
  rng("wage_index",        b$wage_index,       "impact_fy2026", 0.6, 2.2),
  rng("cmi",               b$cmi,              "impact_fy2025 TACMIV42", 0.8, 6),
  rng("volume_bills",      b$volume_bills,     "impact_fy2025 Bills", 1, 100000),
  rng("operating_margin",  b$operating_margin, "hcris (NPR - TOE)/NPR", -1, 1,
      sprintf("%d |margin| > 1 -- hospitals with large non-patient revenue; kept, flagged", sum(b$flag_margin_extreme))),
  rng("uncompensated_care", b$uncompensated_care, "hcris Cost of Uncompensated Care ($)", 0, 2e9),
  rng("system_size",       b$system_size,      "enrollments + all owners", 1, 250))
write.csv(ranges, file.path("output", "tables", "blockA-ranges.csv"), row.names = FALSE)
cat(sprintf("  %-20s %-28s %7s %10s %10s %10s %6s\n", "covariate", "source", "n", "min", "median", "max", "n_out"))
for (i in seq_len(nrow(ranges)))
  cat(sprintf("  %-20s %-28s %7d %10.4g %10.4g %10.4g %6d\n", ranges$covariate[i],
              substr(ranges$source[i], 1, 28), ranges$n[i], ranges$min[i],
              ranges$median[i], ranges$max[i], ranges$n_outside[i]))

## enumerate every flagged hospital -- standing rule 4
flagcols <- grep("^flag_", names(b), value = TRUE)
listed <- which(rowSums(b[, flagcols]) > 0)
ol <- data.frame(
  ccn = b$ccn[listed], name = cwf$name[listed], state = cwf$state[listed],
  beds = b$beds[listed], ownership = b$ownership[listed],
  urban_rural = b$urban_rural[listed],
  flags = apply(b[listed, flagcols], 1,
                function(r) paste(sub("^flag_", "", flagcols)[r], collapse = ";")),
  occupancy = round(b$occupancy[listed], 3),
  dsh_pct = round(b$dsh_pct[listed], 3),
  operating_margin = round(b$operating_margin[listed], 3),
  net_patient_revenue = b$net_patient_revenue[listed],
  uncompensated_care = b$uncompensated_care[listed],
  stringsAsFactors = FALSE)
ol <- ol[order(ol$flags, ol$state, ol$ccn), ]
write.csv(ol, file.path("output", "tables", "blockA-outliers.csv"), row.names = FALSE)

sub_("outliers enumerated -- output/tables/blockA-outliers.csv")
cat(sprintf("  %d hospitals carry at least one plausibility flag\n", nrow(ol)))
for (f in flagcols) {
  k <- sum(b[[f]])
  if (k) cat(sprintf("    %-22s %4d\n", sub("^flag_", "", f), k))
}
cat("\n  occupancy > 1 (ADC exceeds licensed beds) -- the ten:\n")
o1 <- b[b$flag_occupancy_gt1, ]
o1 <- o1[order(-o1$occupancy), ]
for (i in seq_len(nrow(o1)))
  cat(sprintf("    %s  %-36s occ %.3f  (ADC %.0f / %.0f beds)  %s\n", o1$ccn[i],
              substr(cwf$name[match(o1$ccn[i], cwf$ccn)], 1, 36), o1$occupancy[i],
              o1$adc[i], o1$beds[i], cwf$state[match(o1$ccn[i], cwf$ccn)]))
cat("\n  operating margin |.| > 1 -- the worst five each way:\n")
mo <- b[b$flag_margin_extreme, c("ccn", "operating_margin", "net_patient_revenue", "total_operating_expense")]
mo <- mo[order(mo$operating_margin), ]
for (i in unique(c(1:3, (nrow(mo) - 2):nrow(mo))))
  cat(sprintf("    %s  margin %+.2f   NPR %.3g   TOE %.3g\n", mo$ccn[i], mo$operating_margin[i],
              mo$net_patient_revenue[i], mo$total_operating_expense[i]))
cat("  none winsorized; all kept in data/blockA.rds with the flag set.\n")

# ==========================================================================
# 6. coverage against the frame -- reproduces the Task 1.3 gate (8 of 10)
# ==========================================================================
sub_("coverage vs frame -- task1.3-blockA.md §3, the 8-of-10 gate")
covrow <- function(label, present) sprintf("  %-24s %4d / %d  %7s  %s",
  label, sum(present), N, pct(mean(present), 2), if (mean(present) >= 0.99) "PASS" else "BELOW 99%")
cat(covrow("beds",               !is.na(b$beds)), "\n")
cat(covrow("ownership",           !is.na(b$ownership)), "\n")
cat(covrow("teaching intensity",  !is.na(b$resident_to_bed)), "\n")
cat(covrow("case mix index",      !is.na(b$cmi)), "\n")
cat(covrow("DSH percentage",      !is.na(b$dsh_pct)), "\n")
cat(covrow("wage index",          !is.na(b$wage_index)), "\n")
cat(covrow("system membership",   b$has_owner_record), "\n")
cat(covrow("occupancy",           !is.na(b$occupancy)), "\n")
cat(covrow("operating margin",    !is.na(b$operating_margin)), "\n")
cat(covrow("uncompensated care",  !is.na(b$uncompensated_care)), "\n")
cat("\n  system membership and uncompensated care sit below 99% -- structural, not\n")
cat("  retrieval failures (task1.3-blockA.md §4-5). Both go to Task 2.6 / 2.7 with a\n")
cat("  missingness indicator; no importance claim rests on them until it holds across\n")
cat("  the MI and omitted-variable specifications too.\n")

# ==========================================================================
# 7. freeze
# ==========================================================================
keep <- c("ccn", "in_impact_fy2026", "in_impact_fy2025", "in_hcris_fy2023",
          "beds", "adc", "occupancy", "occupancy_hcris",
          "ownership", "ownership_code", "provider_type", "provider_type_code",
          "urban_rural", "resident_to_bed", "teaching",
          "cmi", "volume_bills",
          "dsh_pct", "dsh_pct_hcris", "wage_index",
          "net_patient_revenue", "total_operating_expense", "operating_margin",
          "operating_margin_source",
          "uncompensated_care", "uncompensated_care_pct_npr", "uncompensated_care_source",
          "beds_hcris", "discharges",
          "hcris_fy_begin", "hcris_fy_end", "hcris_window_overlap_days",
          "has_owner_record", "owner_type", "system_member", "system_id",
          "system_name", "system_size",
          grep("^flag_", names(b), value = TRUE))
blockA <- b[, keep]
saveRDS(blockA, file.path("data", "blockA.rds"))

sub_("data/blockA.rds")
cat(sprintf("  %d rows, %d columns\n", nrow(blockA), ncol(blockA)))
cat("  columns: ", paste(names(blockA), collapse = ", "), "\n")

sub_("gate summary")
g_cov <- c(beds = mean(!is.na(b$beds)), ownership = mean(!is.na(b$ownership)),
           teaching = mean(!is.na(b$resident_to_bed)), cmi = mean(!is.na(b$cmi)),
           dsh = mean(!is.na(b$dsh_pct)), wage = mean(!is.na(b$wage_index)),
           system = mean(b$has_owner_record), occupancy = mean(!is.na(b$occupancy)),
           margin = mean(!is.na(b$operating_margin)), uncomp = mean(!is.na(b$uncompensated_care)))
cat(sprintf("  covariates at >= 99%% coverage: %d of 10  (system membership %s, uncompensated care %s)\n",
            sum(g_cov >= 0.99), pct(g_cov["system"], 1), pct(g_cov["uncomp"], 1)))
cat(sprintf("  every covariate range checked, %d outlier rows enumerated, 0 winsorized\n", nrow(ol)))
stopifnot(nrow(blockA) == N, !anyDuplicated(blockA$ccn))
if (sum(g_cov >= 0.99) < 8) stop("Block A coverage regressed below the Task 1.3 baseline of 8/10")

hdr("done")
