#!/usr/bin/env Rscript
# make.R -- the single driver.
#
#   Rscript make.R              run every stage whose inputs are present
#   Rscript make.R --stage 1    run one stage
#   Rscript make.R --list       list the stages and their input status
#   Rscript make.R --release    every stage, no skips, then build the report
#   Rscript make.R --release --cold   the same with every cache recomputed
#   Rscript make.R --release --defer-prose   stage 39's checks of the report PROSE
#                                     are reported, not enforced, and the report is
#                                     not built (Task S4.1; removed for S5.5)
#
# Standing rule 1: every number in the report regenerates from this file.
# Nothing is transcribed by hand. If a number appears in prose, make.R made it.
#
# Standing rule 2: renv from the first commit, relative paths only. Run this
# from the project root. It refuses to run from anywhere else rather than
# quietly writing outputs into the wrong tree.
#
# The driver runs end to end even when it has nothing to do: a stage whose raw
# inputs are absent is SKIPPED with its missing files named, not an error. That
# is what makes a fresh clone -- which carries no data-raw/, by design -- a
# clean run rather than a stack trace.
#
# --release (Task S0.3, second pass) removes that allowance. It runs every
# stage, stops at the first stage that is skipped or fails -- because every
# later stage would otherwise read stale inputs and still exit cleanly -- and
# then builds the report with tools/build_report.py. A release run that exits
# 0 has regenerated every output and the document from raw. --cold adds a
# recompute of every cache (hours; the bootstraps and the clustering dominate).

options(stringsAsFactors = FALSE, warn = 1)

## ---------------------------------------------------------------- setup ----

if (!file.exists("make.R") || !dir.exists("provenance")) {
  stop("run make.R from the project root (the directory holding make.R)")
}

ARGS     <- commandArgs(trailingOnly = TRUE)
WANT     <- if ("--stage" %in% ARGS) ARGS[match("--stage", ARGS) + 1L] else NULL
LIST_ONLY<- "--list" %in% ARGS
RELEASE  <- "--release" %in% ARGS
COLD     <- "--cold" %in% ARGS
## Task S4.1: the release rerun precedes the rewrite, so the Sep 30 prose still
## carries retired numbers and claims. --defer-prose lets stage 39 report those
## prose checks without stopping; every other check in it (registry, inclusion
## reconciliation, claim-guard self-test, generated stage text) stays strict.
## With it, no report is built: a document from the stale prose is not a release.
DEFER    <- "--defer-prose" %in% ARGS
if (DEFER && !RELEASE) stop("--defer-prose applies only to --release")
if (DEFER) Sys.setenv(VP_DEFER_PROSE = "1")
if (RELEASE && !is.null(WANT)) stop("--release runs every stage; it cannot be combined with --stage")
if (COLD && !RELEASE) stop("--cold applies only to --release")
## the scripts read VP_RELEASE (04-spec-curve.R will not fall back to its 10-spec
## TEST subset under it); --cold sets every cache's force variable (R/cache-key.R)
if (RELEASE) Sys.setenv(VP_RELEASE = "1")
CACHE_FORCE_VARS <- c("SPEC_CURVE_FULL", "VD_REFIT", "RASHOMON_REFIT", "MCR_REFIT", "TIS_REFIT",
                      "CLUSTER_REFIT", "PAYMENT_REFIT")
if (COLD) do.call(Sys.setenv, as.list(setNames(rep("1", length(CACHE_FORCE_VARS)), CACHE_FORCE_VARS)))
STARTED  <- Sys.time()

DIRS <- c("R", "data", "data-raw", "provenance", "output/figures", "output/tables", "report")
for (d in DIRS) if (!dir.exists(d)) dir.create(d, recursive = TRUE)

rule <- function(ch = "=") cat(strrep(ch, 78), "\n", sep = "")
say  <- function(...) cat(..., "\n", sep = "")

## renv, if it has been initialised. Sourced rather than required so that the
## very first run -- the one that has not restored a library yet -- still works.
if (file.exists(file.path("renv", "activate.R"))) {
  source(file.path("renv", "activate.R"))
}

source(file.path("R", "provenance.R"))
source(file.path("R", "relocate.R"))

## ---------------------------------------------------------------- stages ---
##
## A stage is: a name, the raw files it needs, and the script that runs it.
## `needs` is checked before the script is sourced. Stage 1 is Phase 0's two
## drivers, ported at Task 1.1 -- they were already a working driver skeleton
## reading raw files by relative path with no packages, so they are the
## foundation rather than something rewritten.

SPIKE <- file.path("data-raw", "spike-phase0")
CC    <- file.path("data-raw", "careCompare_2022Q3-2024Q2")
HACRP <- file.path("data-raw", "hacrp_fy2026")
BA    <- file.path("data-raw", "blockA")

STAGES <- list(
  list(id = "1",
       name = "Phase 0 numbers -- outcome layer, Block A/C, catchment",
       script = file.path("R", "phase0-numbers.R"),
       log    = file.path("output", "tables", "phase0-numbers.txt"),
       needs  = file.path(SPIKE, c("CandD_hospital.csv", "CMS_PSI_6_decimal_file.csv",
                                   "HAC_FY2026.csv", "Hospital_General_Information.csv",
                                   "Footnote_Crosswalk.csv", "CostReport_2023_Final.csv",
                                   "fy2026-impact.zip", "fy2025-impact.zip",
                                   "Hospital_Service_Area_2023.csv", "SVI_2022_US.csv",
                                   "dstlr-7.1.xlsx"))),
  list(id = "1b",
       name = "Phase 0 follow-up -- shrinkage, HSAF suppression, catchment grain",
       script = file.path("R", "phase0-followup.R"),
       log    = file.path("output", "tables", "phase0-followup.txt"),
       needs  = file.path(SPIKE, c("CandD_hospital.csv", "Hospital_General_Information.csv",
                                   "fy2026-impact.zip", "Hospital_Service_Area_2023.csv",
                                   "Hospital_Service_Area_2024.csv", "zcta_county_rel.txt",
                                   "SVI_2022_US_county.csv")))
  ,
  list(id = "2",
       name = "Task 1.2 acquire the outcome layer -- PDC metastore, hashes",
       script = file.path("R", "acquire-outcome.R"),
       log    = file.path("output", "tables", "task1.2-acquire.txt"),
       needs  = character(0)),   # it downloads what is missing; nothing is a precondition
  list(id = "3",
       name = "Task 1.2 verify -- gate O1.b, the sample frame",
       script = file.path("R", "frame-o1b.R"),
       log    = file.path("output", "tables", "task1.2-frame.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "CMS_PSI_6_decimal_file.csv", "Footnote_Crosswalk.csv",
                                  "Measure_Dates.csv", "Hospital_General_Information.csv")),
                  file.path(HACRP, "FY_2026_HAC_Reduction_Program_Hospital.csv")))
  ,
  list(id = "4",
       name = "Task 1.3 acquire Block A -- impact files, HCRIS, POS, ownership",
       script = file.path("R", "acquire-blockA.R"),
       log    = file.path("output", "tables", "task1.3-acquire.txt"),
       needs  = character(0)),
  list(id = "5",
       name = "Task 1.3 verify -- Block A coverage against the frame",
       script = file.path("R", "blockA-coverage.R"),
       log    = file.path("output", "tables", "task1.3-coverage.txt"),
       needs  = c(file.path(BA, c("fy2026-ipps-fr-impact-file.zip",
                                  "fy-2025-ipps-fr-impact-file.zip",
                                  "CostReport_2023_Final.csv", "CostReport_2022_Final.csv",
                                  "Hospital_and_other.DATA.Q2_2026.csv",
                                  "Hospital_Enrollments_2026.07.31.csv",
                                  "Hospital_All_Owners_2026.07.31.csv")),
                  file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "Hospital_General_Information.csv"))))
  ,
  list(id = "6",
       name = "Task 1.4 ADI -- ingest and verify (account-gated, manual download)",
       script = file.path("R", "acquire-adi.R"),
       log    = file.path("output", "tables", "task1.4-adi.txt"),
       needs  = character(0))   # reports its own absence rather than skipping silently
  ,
  list(id = "7",
       name = "Task 1.4 acquire Block B -- SVI, ZCTA crosswalks, AHRF, CHR, RUCC",
       script = file.path("R", "acquire-blockB.R"),
       log    = file.path("output", "tables", "task1.4-blockB.txt"),
       needs  = character(0)),
  list(id = "8",
       name = "Task 1.4 ACS 2020-2024 -- the ICE pull (needs CENSUS_API_KEY)",
       script = file.path("R", "acquire-acs-ice.R"),
       log    = file.path("output", "tables", "task1.4-acs-ice.txt"),
       needs  = character(0))
  ,
  list(id = "9",
       name = "Task 1.5 acquire the HSAF -- CY2023/2024, Dartmouth crosswalk, suppression",
       script = file.path("R", "acquire-hsaf.R"),
       log    = file.path("output", "tables", "task1.5-hsaf.txt"),
       needs  = character(0))
  ,
  list(id = "10",
       name = "Task 1.6 acquire Block C -- raw HCRIS S-3, DSTLR, contract-labour recovery",
       script = file.path("R", "acquire-blockC.R"),
       log    = file.path("output", "tables", "task1.6-blockC.txt"),
       needs  = character(0))
  ,
  list(id = "11",
       name = "Task 2.1 the identifier crosswalk -- CCN, provider no., ZIP, county, tract",
       script = file.path("R", "crosswalk.R"),
       log    = file.path("output", "tables", "task2.1-crosswalk.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "Hospital_General_Information.csv")),
                  file.path(BA, c("fy2026-ipps-fr-impact-file.zip",
                                  "fy-2025-ipps-fr-impact-file.zip",
                                  "Hospital_and_other.DATA.Q2_2026.csv")),
                  file.path("data-raw", "blockB", "tab20_zcta520_tract20_natl.txt")))
  ,
  list(id = "12",
       name = "Task 2.2 the outcome table -- PSI-90 + components, reliability shrinkage",
       script = file.path("R", "outcomes.R"),
       log    = file.path("output", "tables", "task2.2-outcomes.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "CMS_PSI_6_decimal_file.csv",
                                  "Hospital_General_Information.csv",
                                  "Footnote_Crosswalk.csv", "Measure_Dates.csv")),
                  file.path(HACRP, "FY_2026_HAC_Reduction_Program_Hospital.csv"),
                  file.path(BA, "fy2026-ipps-fr-impact-file.zip"),
                  file.path("data", "crosswalk.rds")))
  ,
  list(id = "13",
       name = "Task 2.3 Block A -- hospital structure (beds, ownership, CMI, margin, ...)",
       script = file.path("R", "blockA.R"),
       log    = file.path("output", "tables", "task2.3-blockA.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "Hospital_General_Information.csv")),
                  file.path(BA, c("fy2026-ipps-fr-impact-file.zip",
                                  "fy-2025-ipps-fr-impact-file.zip",
                                  "CostReport_2023_Final.csv", "CostReport_2022_Final.csv",
                                  "Hospital_Enrollments_2026.07.31.csv",
                                  "Hospital_All_Owners_2026.07.31.csv")),
                  file.path("data", "crosswalk.rds")))
  ,
  list(id = "14",
       name = "Task 2.4 catchment-weighting engine -- HSAF -> ZIP -> tract weights",
       script = file.path("R", "catchment.R"),
       log    = file.path("output", "tables", "task2.4-catchment.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "Hospital_General_Information.csv")),
                  file.path("data-raw", "hsaf", "Hospital_Service_Area_2023.csv"),
                  file.path("data-raw", "blockB", c("tab20_zcta520_tract20_natl.txt",
                                                    "SVI_2022_US.csv")),
                  file.path("data", "crosswalk.rds")))
  ,
  list(id = "15",
       name = "Task 2.5 input -- ACS block-group population (needs CENSUS_API_KEY)",
       script = file.path("R", "acquire-bg-population.R"),
       log    = file.path("output", "tables", "task2.5-bgpop.txt"),
       needs  = character(0))
  ,
  list(id = "16",
       name = "Task 2.5 Block B -- catchment-weighted, four grain variants per covariate",
       script = file.path("R", "blockB.R"),
       log    = file.path("output", "tables", "task2.5-blockB.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "Hospital_General_Information.csv")),
                  file.path("data-raw", "blockB", c("tab20_zcta520_tract20_natl.txt",
                                                    "tab20_zcta520_county20_natl.txt",
                                                    "SVI_2022_US.csv", "SVI_2022_US_county.csv",
                                                    "Ruralurbancontinuumcodes2023.csv",
                                                    "AHRF_2023-2024_SAS.zip")),
                  file.path("data-raw", "blockB_adi", c("US_2024_block_group_adi_v_4_0_1.csv",
                                                        "US_2020_ADI_Census_Block_Group_v4_0_1.csv")),
                  file.path("data-raw", "blockB_acs", c("acs2024_5yr_B19001_tract.csv",
                                                       "acs2024_5yr_B01003_blockgroup.csv")),
                  file.path("data-raw", "hsaf", "Hospital_Service_Area_2023.csv"),
                  file.path("data-raw", "dartmouth", "ZipHsaHrr19.csv.zip"),
                  file.path("data", c("crosswalk.rds", "catchment.rds", "catchment-weights.rds"))))
  ,
  list(id = "17",
       name = "Task 2.6 missingness audit -- differential missingness + MAR-plausibility",
       script = file.path("R", "missingness.R"),
       log    = file.path("output", "tables", "task2.6-missingness.txt"),
       needs  = file.path("data", c("outcomes.rds", "blockA.rds", "blockB.rds", "blockC_contract_labor.csv")))
  ,
  list(id = "18",
       name = "Task 2.7 admission tests -- C1/C2/C3/B0/O1, contract-labour MI, data/blockC.rds",
       script = file.path("R", "blockC.R"),
       log    = file.path("output", "tables", "task2.7-admission.txt"),
       needs  = c(file.path(CC, c("Complications_and_Deaths-Hospital.csv",
                                  "Hospital_General_Information.csv")),
                  file.path(BA, c("fy2026-ipps-fr-impact-file.zip", "fy-2025-ipps-fr-impact-file.zip")),
                  file.path("data-raw", "blockC", "dstlr-7.1.xlsx"),
                  file.path("data", c("outcomes.rds", "blockA.rds", "blockB.rds",
                                      "crosswalk.rds", "catchment.rds", "catchment-weights.rds",
                                      "blockC_contract_labor.csv"))))
  ,
  list(id = "19",
       name = "Task 2.8 freeze the analytic file -- merge, hash, pin",
       script = file.path("R", "freeze.R"),
       log    = file.path("output", "tables", "task2.8-freeze.txt"),
       needs  = file.path("data", c("outcomes.rds", "blockA.rds", "blockB.rds",
                                    "blockC.rds", "crosswalk.rds")))
  ,
  list(id = "20",
       name = "Task 3.1 exploratory pass -- distributions, correlations, Block B collinearity, geography",
       script = file.path("R", "03-eda.R"),
       log    = file.path("output", "tables", "task3.1-eda.txt"),
       needs  = file.path("data", "analytic-v2.rds"))
  ,
  list(id = "21",
       name = "Task 3.2 baseline hierarchical model -- components, hospitals nested in HSA, null->A->A+B->A+B+C",
       script = file.path("R", "03-baseline.R"),
       log    = file.path("output", "tables", "task3.2-baseline.txt"),
       needs  = file.path("data", c("analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "22",
       name = "Task 3.3 variance decomposition -- LMG community/structure/policy split, uncorrected vs lambda-corrected",
       script = file.path("R", "03-variance-decomposition.R"),
       log    = file.path("output", "tables", "task3.3-variance-decomposition.txt"),
       needs  = c(file.path("data", "analytic-v2.rds"),
                  file.path("output", "models", "task3.2-models.rds")))
  ,
  list(id = "23",
       name = "Task 3.5 freeze the specification registry -- 8 axes, structural voids pruned, N fixed before the first fit",
       script = file.path("R", "03-spec-registry.R"),
       log    = file.path("output", "tables", "task3.5-spec-registry.txt"),
       needs  = file.path("data", "analytic-v2.rds"))
  ,
  list(id = "24",
       name = "Task 3.6/3.7 specification-curve harness -- fits every registered spec (SPEC_CURVE_FULL=1); TEST subset + runtime estimate otherwise",
       script = file.path("R", "04-spec-curve.R"),
       log    = file.path("output", "tables", "task3.6-spec-curve.txt"),
       needs  = file.path("data", c("spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "25",
       name = "Task 3.7 specification curve -- sign-stability, the reliability axis on its own, and the figure",
       script = file.path("R", "04-spec-curve-report.R"),
       log    = file.path("output", "tables", "task3.7-spec-curve.txt"),
       needs  = file.path("data", "spec-results.rds"))
  ,
  list(id = "26",
       name = "Task 3.8 influence and diagnostics -- leave-one-hospital/state-out on anchors, axis variance decomposition",
       script = file.path("R", "04-spec-diagnostics.R"),
       log    = file.path("output", "tables", "task3.8-spec-diagnostics.txt"),
       needs  = file.path("data", c("spec-results.rds", "analytic-v2.rds")))
  ,
  list(id = "27",
       name = "Task 3.9 Rashomon tolerance -- common-frame loss, the ERM per outcome family, bootstrap excess loss, epsilon at a pre-registered alpha = 0.05",
       script = file.path("R", "05-rashomon.R"),
       log    = file.path("output", "tables", "task3.9-rashomon.txt"),
       needs  = file.path("data", c("spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "28",
       name = "Task 3.10 Rashomon set -- membership at the 3.9 tolerance, and the width reported before any MCR bound",
       script = file.path("R", "05-rashomon-set.R"),
       log    = file.path("output", "tables", "task3.10-rashomon-set.txt"),
       needs  = file.path("data", c("rashomon-loss.rds", "rashomon-tolerance.rds", "spec-results.rds", "analytic-v2.rds")))
  ,
  list(id = "29",
       name = "Task 3.11 model class reliance -- the MR/MCR implementation, validated against hand-computable answers before it reads the data",
       script = file.path("R", "06-mcr.R"),
       log    = file.path("output", "tables", "task3.11-mcr.txt"),
       needs  = file.path("data", c("rashomon-set.rds", "rashomon-loss.rds", "spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "30",
       name = "Task 3.12 run MCR -- Block B primary (group and per measure), Block A secondary, Block C coefficient ranges only",
       script = file.path("R", "06-mcr-run.R"),
       log    = file.path("output", "tables", "task3.12-mcr-run.txt"),
       needs  = file.path("data", c("rashomon-set.rds", "rashomon-tolerance.rds", "spec-results.rds", "spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "31",
       name = "Task 3.13 TIS decomposition -- direct vs shared model class reliance, the per-neighbour flow matrix, validated on a synthetic case with known shared structure",
       script = file.path("R", "07-tis.R"),
       log    = file.path("output", "tables", "task3.13-tis.txt"),
       needs  = file.path("data", c("rashomon-set.rds", "spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "32",
       name = "Task 3.14 run TIS -- shared attribution reported before any ranking, the flow matrix, and the driver ranking",
       script = file.path("R", "07-tis-run.R"),
       log    = file.path("output", "tables", "task3.14-tis-run.txt"),
       needs  = file.path("data", c("rashomon-set.rds", "rashomon-tolerance.rds", "spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")))
  ,
  list(id = "33",
       name = "Task 3.15 cluster on margin and safety maturity -- ICL criterion pre-registered, published and lambda-corrected PSI-90 both reported",
       script = file.path("R", "08-clusters.R"),
       log    = file.path("output", "tables", "task3.15-clusters.txt"),
       needs  = file.path("data", "analytic-v2.rds"))
  ,
  list(id = "34",
       name = "Task 3.16 validate the Track archetypes -- CMS star rating as the Leapfrog fallback, verdict rule pre-registered",
       script = file.path("R", "08-archetypes.R"),
       log    = file.path("output", "tables", "task3.16-archetypes.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "clusters.rds")),
                  file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv")))
  ,
  list(id = "35",
       name = "Task 4.2 payment-impact Monte Carlo -- HACRP C1 gate, Rashomon + reliability draws to convergence, C2 calibration, Q-HIP scenarios",
       script = file.path("R", "09-payment-sim.R"),
       log    = file.path("output", "tables", "task4.2-payment-sim.txt"),
       needs  = c(file.path("data", c("rashomon-set.rds", "rashomon-loss.rds", "spec-registry.rds", "analytic-v2.rds", "blockC_mice.rds")),
                  file.path("data-raw", "hacrp_fy2026", "FY_2026_HAC_Reduction_Program_Hospital.csv"),
                  file.path("data-raw", "blockC", "HOSP10FY2023.zip"),
                  file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv")))
  ,
  list(id = "36",
       name = "Task 4.3 simulated payments by stratum -- along 3.16's gradient, not by Track",
       script = file.path("R", "10-payment-strata.R"),
       log    = file.path("output", "tables", "task4.3-payment-strata.txt"),
       needs  = c(file.path("data", "payment-sim.rds"), file.path("output", "tables", "payment-by-hospital.csv")))
  ,
  list(id = "37",
       name = "Task 4.4 regressivity -- per NPR dollar (headline) and per hospital, rule fixed in amendment 9; observed HACRP cross-tab",
       script = file.path("R", "11-regressivity.R"),
       log    = file.path("output", "tables", "task4.4-regressivity.txt"),
       needs  = file.path("data", "payment-sim.rds"))
  ,
  list(id = "38",
       name = "Task 5.1 the final figure suite -- eight report figures in one visual grammar, hash manifest",
       script = file.path("R", "12-figures.R"),
       log    = file.path("output", "tables", "task5.1-figures.txt"),
       needs  = c(file.path("data", "analytic-v2.rds"),
                  file.path("output", "tables", c("variance-decomposition.csv", "reliability-by-volume.csv",
                                                  "spec-curve-points.csv", "rashomon-set.csv",
                                                  "mcr-bounds-blockA.csv", "mcr-bounds-blockB.csv",
                                                  "rashomon-coef-ranges.csv", "tis-decomposition.csv",
                                                  "tis-flow-matrix.csv", "archetype-cells.csv",
                                                  "archetype-validation.csv", "payment-by-stratum.csv",
                                                  "regressivity.csv", "observed-hacrp-regressivity.csv"))))
  ,
  ## Task S2.4: post-review; listed before 39 so the registry reads a fresh table
  list(id = "40",
       name = "Task S2.4 geographic validation (post-review) -- reduced Block B datasets on held-out states and hospitals",
       script = file.path("R", "14-geo-validation.R"),
       log    = file.path("output", "tables", "taskS2.4-geo-validation.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "spec-registry.rds", "rashomon-loss.rds")),
                  file.path("output", "tables", "driver-tags.csv")))
  ,
  ## Task S2.5: post-review; before 39 for the same reason as stage 40
  list(id = "41",
       name = "Task S2.5 contrast support (post-review) -- the joint p10->p90 profile against observed catchments; observed and group contrasts",
       script = file.path("R", "15-contrast-support.R"),
       log    = file.path("output", "tables", "taskS2.5-contrast-support.txt"),
       needs  = file.path("data", c("analytic-v2.rds", "spec-registry.rds", "spec-results.rds")))
  ,
  ## Task S2.6: post-review; before 39 for the same reason as stage 40
  list(id = "42",
       name = "Task S2.6 geography as construction (post-review) -- SVI themes rebuilt from estimate percentages, county vs tract catchment refit",
       script = file.path("R", "16-geo-construction.R"),
       log    = file.path("output", "tables", "taskS2.6-geo-construction.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "spec-registry.rds", "spec-results.rds", "catchment-weights.rds")),
                  file.path("data-raw", "blockB", c("SVI_2022_US.csv", "SVI_2022_US_county.csv"))))
  ,
  ## Task S3.1: post-review; before 39, which reconciles the flow to its registry
  list(id = "43",
       name = "Task S3.1 inclusion flow and missing-data assumption (post-review) -- every frame from 2,801; contract-labor shift sensitivity",
       script = file.path("R", "17-inclusion-missingness.R"),
       log    = file.path("output", "tables", "taskS3.1-inclusion-missingness.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "outcomes.rds", "blockC_mice.rds", "blockC_contract_labor.csv",
                                      "rashomon-set.rds", "rashomon-loss.rds", "spec-registry.rds")),
                  file.path("data-raw", "hacrp_fy2026", "FY_2026_HAC_Reduction_Program_Hospital.csv"),
                  file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv"),
                  file.path("output", "tables", c("task1.2-frame.txt", "task3.15-clusters.txt", "rashomon-set.csv",
                                                  "mcr-per-model.csv", "variance-decomposition.csv"))))
  ,
  ## Task S3.2: post-review; before 39 for the same reason as stage 40
  list(id = "44",
       name = "Task S3.2 suppression sensitivity (post-review) -- suppressed HSAF cells filled, both catchment grains, loss / contrast / ranks",
       script = file.path("R", "18-suppression.R"),
       log    = file.path("output", "tables", "taskS3.2-suppression.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "catchment.rds", "catchment-weights.rds",
                                      "spec-results.rds", "rashomon-loss.rds")),
                  file.path("data-raw", "hsaf", "Hospital_Service_Area_2023.csv"),
                  file.path("data-raw", "blockB", c("SVI_2022_US.csv", "SVI_2022_US_county.csv",
                                                    "tab20_zcta520_tract20_natl.txt",
                                                    "Ruralurbancontinuumcodes2023.csv", "AHRF_2023-2024_SAS.zip")),
                  file.path("data-raw", "blockB_acs", c("acs2024_5yr_B19001_tract.csv", "acs2024_5yr_B01003_blockgroup.csv")),
                  file.path("data-raw", "blockB_adi", "US_2024_block_group_adi_v_4_0_1.csv")))
  ,
  ## Task S3.3: post-review; before 39 for the same reason as stage 40
  list(id = "45",
       name = "Task S3.3 ownership sensitivity (post-review) -- ownership and system membership added to Block A at P-best and P-median",
       script = file.path("R", "19-ownership.R"),
       log    = file.path("output", "tables", "taskS3.3-ownership.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "blockC_mice.rds", "rashomon-set.rds", "rashomon-loss.rds",
                                      "spec-registry.rds", "spec-results.rds")),
                  file.path("output", "tables", c("mcr-per-model.csv", "rashomon-set.csv"))))
  ,
  ## Task S3.4: post-review; before 39 for the same reason as stage 40
  list(id = "46",
       name = "Task S3.4 archetype account (post-review) -- cluster criteria together, full nine-cell tables, alternative Track bands",
       script = file.path("R", "20-archetype-bands.R"),
       log    = file.path("output", "tables", "taskS3.4-archetypes.txt"),
       needs  = c(file.path("data", "analytic-v2.rds"),
                  file.path("data-raw", "careCompare_2022Q3-2024Q2", "Hospital_General_Information.csv"),
                  file.path("output", "tables", c("cluster-summary.csv", "task3.15-clusters.txt",
                                                  "archetype-cells.csv", "archetype-validation.csv"))))
  ,
  list(id = "39",
       name = "Report numbers -- registry of every number the report cites, and the check that the prose uses only those (standing rule 1)",
       script = file.path("R", "13-report-numbers.R"),
       log    = file.path("output", "tables", "report-numbers.txt"),
       needs  = c(file.path("data", c("analytic-v2.rds", "outcomes.rds", "catchment.rds", "crosswalk.rds",
                                      "blockC.rds", "blockC_mice.rds", "spec-registry.csv", "payment-sim.rds")),
                  file.path("output", "tables", c("unmatched-hospitals.csv", "admission-gate-results.csv",
                                                  "missingness-audit.csv", "catchment-vs-county-correlation.csv",
                                                  "reliability-by-volume.csv", "adi-aggregation-diagnostics.csv",
                                                  "task1.2-frame.txt", "task1.3-coverage.txt", "task1.5-hsaf.txt",
                                                  "phase0-numbers.txt", "phase0-followup.txt",
                                                  "rashomon-tolerance.csv", "rashomon-set-width.csv",
                                                  "mcr-bounds-blockB.csv", "tis-decomposition.csv",
                                                  "task3.3-variance-decomposition.txt", "task4.2-payment-sim.txt",
                                                  "variance-decomposition.csv", "spec-curve-points.csv",
                                                  "spec-curve-summary.csv", "spec-curve-reliability.csv",
                                                  "spec-diagnostics-influence.csv", "rashomon-set-axes.csv",
                                                  "rashomon-set.csv", "mcr-bounds-blockA.csv", "rashomon-coef-ranges.csv",
                                                  "driver-tags.csv", "tis-flow-matrix.csv", "task3.14-tis-run.txt",
                                                  "archetype-validation.csv", "archetype-cells.csv", "archetype-screened23.csv",
                                                  "task3.16-archetypes.txt", "payment-by-stratum.csv", "payment-gap-decomposition.csv",
                                                  "payment-by-hospital.csv", "hacrp-calibration.csv",
                                                  "observed-hacrp-regressivity.csv", "regressivity.csv",
                                                  "regressivity-by-stratum.csv", "task4.4-regressivity.txt",
                                                  "geo-validation.csv", "contrast-support.csv",
                                                  "geo-construction.csv", "inclusion-flow.csv",
                                                  "mnar-sensitivity.csv", "suppression-sensitivity.csv",
                                                  "ownership-sensitivity.csv", "cluster-summary.csv",
                                                  "archetype-cells-full.csv", "archetype-bands-sensitivity.csv"))))
  ## Phase 2 onward: one file per stage in R/, same shape.
)

missing_for <- function(s) s$needs[!file.exists(s$needs)]

## Run one stage, teeing its console output to output/tables/ so the numbers
## are a file on disk and not only a terminal that has scrolled away.
run_stage <- function(s) {
  miss <- missing_for(s)
  rule()
  say("STAGE ", s$id, "  ", s$name)
  rule()
  if (length(miss)) {
    say("  SKIPPED -- ", length(miss), " input file(s) absent:")
    for (m in miss) say("    ", m)
    say("  Re-download them from provenance/sources.csv. Not an error.")
    return(invisible("skipped"))
  }
  t0 <- Sys.time()
  con <- file(s$log, open = "wt")
  sink(con, split = TRUE)
  ok <- tryCatch({ source(s$script, local = new.env(), echo = FALSE); TRUE },
                 error = function(e) { message("STAGE ", s$id, " FAILED: ", conditionMessage(e)); FALSE })
  sink(); close(con)
  say(sprintf("  %s in %.1f s  ->  %s", if (ok) "done" else "FAILED",
              as.numeric(difftime(Sys.time(), t0, units = "secs")), s$log))
  invisible(if (ok) "ok" else "failed")
}

## ---------------------------------------------------------------- driver ---

rule()
say("Patient Safety Variance Project -- make.R")
say("  ", format(STARTED, "%Y-%m-%d %H:%M:%S"), "   ", R.version.string)
say("  root: ", getwd())
rule()

if (LIST_ONLY) {
  for (s in STAGES) {
    miss <- missing_for(s)
    say(sprintf("  %-4s %-62s %s", s$id, substr(s$name, 1, 62),
                if (length(miss)) sprintf("%d input(s) missing", length(miss)) else "ready"))
  }
  quit(save = "no", status = 0)
}

## Phase 0's drivers read the spike-era paths; Phase 1 moves files out from
## under them as each acquisition task lands. Replay the recorded moves as
## compatibility links before any stage runs, so the port stays unedited.
rule("-")
say("RELOCATIONS")
reloc_apply()
rule("-")

todo <- if (is.null(WANT)) STAGES else Filter(function(s) s$id == WANT, STAGES)
if (!length(todo)) stop("no such stage: ", WANT)

if (!RELEASE) {
  results <- vapply(todo, function(s) run_stage(s), character(1))
} else {
  results <- character(0)
  for (s in todo) {
    results <- c(results, run_stage(s))
    if (results[length(results)] != "ok") {
      rule()
      say("RELEASE STOPPED at stage ", s$id, " (", results[length(results)], "). Every later stage would")
      say("read inputs this run did not regenerate. Nothing after it ran.")
      rule()
      quit(save = "no", status = 1)
    }
  }
}

## A stage may have downloaded a file that some earlier stage wanted under its
## old path -- true on a fresh clone, where stage 2 fetches what stage 1 was
## missing. Replay the moves again so the next run finds them.
reloc_apply(quiet = TRUE)

## ------------------------------------------------------- provenance check --

rule()
say("PROVENANCE")
rule()
prov_ok <- prov_verify()

## ------------------------------------------------------------- summary -----

rule()
say("SUMMARY")
rule()
for (i in seq_along(todo)) say(sprintf("  stage %-4s %s", todo[[i]]$id, results[i]))
say(sprintf("  provenance: %s", if (isTRUE(prov_ok)) "consistent" else "SEE ABOVE"))

## ------------------------------------------------------ release: the document --
build_ok <- TRUE
if (RELEASE && DEFER) say("  report build: NOT RUN (--defer-prose: the prose is the Sep 30 draft; S5.5 builds it)")
if (RELEASE && !DEFER && isTRUE(prov_ok)) {
  py <- Sys.which("python3"); if (!nzchar(py)) py <- Sys.which("python")
  if (!nzchar(py)) { say("  report build: FAILED -- no python3 on the PATH"); build_ok <- FALSE }
  else {
    st <- system2(py, file.path("tools", "build_report.py"))
    build_ok <- identical(as.integer(st), 0L)
    say(sprintf("  report build: %s", if (build_ok) "output/report/ (docx and pdf)" else "FAILED (above)"))
    ## Task S5.4: the technical supplement, its own document, and the registry beside it
    st2 <- system2(py, c(file.path("tools", "build_report.py"), "--supplement"))
    build_ok <- build_ok && identical(as.integer(st2), 0L)
    say(sprintf("  supplement build: %s", if (identical(as.integer(st2), 0L)) "output/report/ (docx, pdf, registry csv)" else "FAILED (above)"))
  }
}
say(sprintf("  elapsed %.1f s", as.numeric(difftime(Sys.time(), STARTED, units = "secs"))))
if (any(results == "failed") || !isTRUE(prov_ok) || !build_ok) quit(save = "no", status = 1)
rule()
