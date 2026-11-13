# R/frame-o1b.R  --  Task 1.2 verification, admission gate O1.b
#
# The frame must reproduce at n = 2,801 acute-care hospitals with a numeric
# PSI-90, and the 107 VA hospitals must leave by an EXPLICIT `Hospital Type`
# filter with their count recorded -- not by silently failing to join to Block A
# later, which is what standing rule 4 exists to prevent.
#
# This is a verification report, not the outcome table. Assembling that table,
# with footnote semantics and component columns, is Task 2.2.
#
# Reads the permanent Task 1.2 layout. Base R.

CC  <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
HAC <- file.path("data-raw", "hacrp_fy2026")

rd  <- function(p) read.csv(p, colClasses = "character", check.names = FALSE,
                            na.strings = character(0))
n_  <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_<- function(s) cat("\n--- ", s, " ---\n", sep = "")

cd  <- rd(file.path(CC,  "Complications_and_Deaths-Hospital.csv"))
s6  <- rd(file.path(CC,  "CMS_PSI_6_decimal_file.csv"))
hg  <- rd(file.path(CC,  "Hospital_General_Information.csv"))
fnc <- rd(file.path(CC,  "Footnote_Crosswalk.csv"))
md  <- rd(file.path(CC,  "Measure_Dates.csv"))
hac <- rd(file.path(HAC, "FY_2026_HAC_Reduction_Program_Hospital.csv"))

hdr("TASK 1.2  gate O1.b -- the sample frame, from the permanent layout")

sub_("reporting window, confirmed from two files")
psi <- cd[grepl("^PSI", cd$`Measure ID`), ]
cat("  provider file PSI rows :", unique(psi$`Start Date`)[1], "..", unique(psi$`End Date`)[1], "\n")
mdp <- md[grepl("PSI", md[[1]]) | grepl("PSI", md[[2]]), , drop = FALSE]
cat("  Measure_Dates PSI rows :", nrow(mdp), "\n")

sub_("Facility ID is a 6-char CCN, leading zeros significant")
cat("  distinct Facility ID widths in provider file:",
    paste(sort(unique(nchar(trimws(cd$`Facility ID`)))), collapse = ", "), "\n")
cat("  IDs beginning with a zero:", sum(substr(trimws(unique(cd$`Facility ID`)), 1, 1) == "0"),
    "-- read as character everywhere\n")

sub_("GATE O1.b -- the explicit Hospital Type filter")
p90  <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
p90$num  <- !is.na(n_(p90$Score))
p90$type <- type[p90$`Facility ID`]

n_fac  <- length(unique(cd$`Facility ID`))
n_num  <- sum(p90$num)
n_acute<- sum(p90$num & p90$type == "Acute Care Hospitals")
n_va   <- sum(p90$num & p90$type == "Acute Care - Veterans Administration")
n_other<- n_num - n_acute - n_va

cat(sprintf("  facilities in provider file                     %6d\n", n_fac))
cat(sprintf("  ... with a numeric PSI_90                       %6d\n", n_num))
cat(sprintf("  ... Hospital Type == Acute Care Hospitals       %6d   [THE FRAME]\n", n_acute))
cat(sprintf("  ... Hospital Type == Acute Care - VA            %6d   [EXCLUDED, recorded]\n", n_va))
cat(sprintf("  ... any other Hospital Type                     %6d\n", n_other))
if (n_other > 0) {
  cat("      breakdown:\n")
  o <- table(p90$type[p90$num & !p90$type %in%
                        c("Acute Care Hospitals", "Acute Care - Veterans Administration")])
  for (k in names(o)) cat(sprintf("        %-46s %5d\n", k, o[[k]]))
}
cat(sprintf("  facilities with no Hospital Type row at all     %6d\n", sum(p90$num & is.na(p90$type))))

frame <- p90$`Facility ID`[p90$num & p90$type == "Acute Care Hospitals"]
N <- length(frame)
cat(sprintf("\n  GATE O1.b  n = %d, expected 2801  ->  %s\n", N, if (N == 2801L) "PASS" else "FAIL"))
cat(sprintf("  GATE O1.b  VA excluded explicitly = %d, expected 107  ->  %s\n",
            n_va, if (n_va == 107L) "PASS" else "FAIL"))

sub_("the six-decimal file covers the frame")
r6 <- setNames(n_(s6$Rate[s6$`Measure ID` == "PSI_90"]), s6$`Facility ID`[s6$`Measure ID` == "PSI_90"])
cat(sprintf("  frame hospitals with a six-decimal PSI_90       %6d   %s\n",
            sum(frame %in% names(r6)[!is.na(r6)]), pct(mean(frame %in% names(r6)[!is.na(r6)]))))
cat(sprintf("  six-decimal PSI_90: median %.6f  mean %.6f  min %.6f  max %.6f\n",
            median(r6, na.rm = TRUE), mean(r6, na.rm = TRUE),
            min(r6, na.rm = TRUE), max(r6, na.rm = TRUE)))

sub_("footnotes parse as comma-concatenated multi-codes, and 7 is not 1")
seen <- sort(unique(unlist(strsplit(psi$Footnote[psi$Footnote != ""], ",\\s*"))))
for (k in seen) cat(sprintf("  %-3s :: %s\n", k, fnc$`Footnote Text`[match(k, fnc$Footnote)]))
multi <- grepl(",", psi$Footnote)
cat(sprintf("  rows carrying more than one code               %6d\n", sum(multi)))
cat(sprintf("  code 1 (volume suppression) on PSI rows        %6d\n",
            sum(vapply(strsplit(psi$Footnote, ",\\s*"), function(v) "1" %in% v, logical(1)))))
cat(sprintf("  code 7 (structural zero) on PSI rows           %6d   <- never collapse with 1\n",
            sum(vapply(strsplit(psi$Footnote, ",\\s*"), function(v) "7" %in% v, logical(1)))))

sub_("the fifth source: FY 2026 HACRP, the observed penalty distribution")
cat(sprintf("  rows in the HACRP file                         %6d\n", nrow(hac)))
cat(sprintf("  frame hospitals present in HACRP               %6d   %s\n",
            sum(frame %in% hac$`Facility ID`), pct(mean(frame %in% hac$`Facility ID`))))
cat(sprintf("  VA hospitals present in HACRP                  %6d   <- expected 0\n",
            sum(p90$`Facility ID`[p90$num & p90$type == "Acute Care - Veterans Administration"]
                %in% hac$`Facility ID`)))
cat("  Payment Reduction:\n")
pr <- table(hac$`Payment Reduction`)
for (k in names(pr)) cat(sprintf("    %-12s %5d\n", k, pr[[k]]))
ths <- n_(hac$`Total HAC Score`)
cat(sprintf("  Total HAC Score: n numeric %d  median %.4f  p75 %.4f  max %.4f\n",
            sum(!is.na(ths)), median(ths, na.rm = TRUE),
            quantile(ths, .75, na.rm = TRUE, names = FALSE), max(ths, na.rm = TRUE)))

hdr("done")
