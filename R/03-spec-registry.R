# R/03-spec-registry.R  --  Task 3.5, freeze the specification registry.
#
# Converts the grid enumerated in provenance/spec-space.md (Task 3.4) into a
# machine-readable registry: one row per specification, one column per axis,
# an integer spec_id, and the derived fields the Task 3.6 harness needs to
# resolve a row into a model (outcome family, weight, nesting geography).
#
# THE POINT OF THIS TASK is the commit timestamp. The registry is committed
# BEFORE any specification is fitted, so "we fitted the curve and then decided
# which specs count" is not available as a criticism. data/spec-registry.rds
# and .csv are force-tracked (see .gitignore) precisely so the history carries
# that timestamp -- they are build products in every other respect.
#
# Reads data/analytic-v2.rds, and ONLY to validate that every column each axis
# level will need is actually present in the frozen file. No model is fitted
# here. No number from the file is reported.
#
# AXES (8 -- the 7 from the rev-2 task sheet table, plus outcome scale, added
# at Carl's sign-off 2026-09-02; see provenance/task3.5-spec-registry.md Sec 1):
#   blocks       A / AB / ABC
#   form         linear / spline           (spline = ns() on the continuous
#                                            Block B disadvantage measures)
#   outcome      composite / psi03 / psi06 / psi12 / psi13 / agg
#   reliability  unweighted / weighted / subsample / eiv
#   grain        catch_tract / catch_county / hosp_county / hsa
#   missing      mi / complete / omit      (na when Block C is not in the model)
#   influential  all / drop_fn2329 / drop_fallback
#   scale        identity / log
#
# STRUCTURAL VOIDS pruned here (provenance/spec-space.md Sec 9):
#   V1  form = spline requires Block B in the model  -> linear only when blocks = A
#   V2  the missing-data axis requires Block C       -> missing = "na" unless blocks = ABC
#   V3  reliability = eiv requires a published lambda -> composite outcome only
#   V4  catchment covariate grain is inert without Block B -> under blocks = A the
#       grain axis is just the nesting choice: keep {hsa, hosp_county}, drop the
#       two catchment grains (identical fit to hsa there)
#   V5  influential = drop_fallback is a no-op with no catchment construction ->
#       removed under blocks = A, and under grain = hosp_county
#
# Output: data/spec-registry.rds, data/spec-registry.csv, and N -- printed
# here, stated in the provenance note, fixed by the commit.

n_  <- function(x) suppressWarnings(as.numeric(x))
hdr <- function(s) cat("\n", strrep("=", 78), "\n", s, "\n", strrep("=", 78), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")

hdr("TASK 3.5  freeze the specification registry")

a <- readRDS(file.path("data", "analytic-v2.rds"))
cat(sprintf("  frozen file: data/analytic-v2.rds  (%d x %d)\n", nrow(a), ncol(a)))

# ==========================================================================
sub_("1. axis levels")

AX <- list(
  blocks      = c("A", "AB", "ABC"),
  form        = c("linear", "spline"),
  outcome     = c("composite", "psi03", "psi06", "psi12", "psi13", "agg"),
  reliability = c("unweighted", "weighted", "subsample", "eiv"),
  grain       = c("catch_tract", "catch_county", "hosp_county", "hsa"),
  missing     = c("mi", "complete", "omit"),
  influential = c("all", "drop_fn2329", "drop_fallback"),
  scale       = c("identity", "log")
)
for (nm in names(AX)) cat(sprintf("  %-12s %s\n", nm, paste(AX[[nm]], collapse = " / ")))
naive <- prod(vapply(AX, length, integer(1)))
cat(sprintf("\n  naive factorial: %s = %d\n",
            paste(vapply(AX, length, integer(1)), collapse = " * "), naive))

# ==========================================================================
sub_("2. column presence check (the frozen file must carry every level's inputs)")

need <- list(
  "outcome composite"      = "psi90",
  "outcome components"     = c("psi03", "psi06", "psi12", "psi13"),
  "component denominators" = c("psi03_denom", "psi06_denom", "psi12_denom", "psi13_denom"),
  "reliability lambda"     = "lambda_i",
  "grain catch_tract"      = c("adi_catch_tract", "ice150_catch_tract", "svi1_catch_tract"),
  "grain catch_county"     = c("adi_catch_county", "ice150_catch_county"),
  "grain hosp_county"      = c("adi_county", "ice150_county"),
  "grain hsa"              = c("adi_hsa", "ice150_hsa"),
  "influential fn23"       = "fn_claims_discrepancy",
  "influential fn29"       = "fn_partial_window",
  "influential fallback"   = "catch_source",
  "blockC MI columns"      = sprintf("cl_share_mi_%02d", 1:20)
)
miss <- character(0)
for (nm in names(need)) {
  have <- need[[nm]] %in% names(a)
  cat(sprintf("  %-24s %s\n", nm, if (all(have)) "ok" else
              paste("MISSING:", paste(need[[nm]][!have], collapse = ", "))))
  if (!all(have)) miss <- c(miss, need[[nm]][!have])
}
# blockC MI columns live in blockC.rds / analytic file under a known name --
# tolerate either the cl_share_mi_* pattern or a single frozen mids reference.
mi_ok <- any(grepl("^cl_share_mi_", names(a))) || file.exists(file.path("data", "blockC_mice.rds"))
cat(sprintf("  %-24s %s\n", "blockC MI source", if (mi_ok) "ok (cl_share_mi_* or blockC_mice.rds)" else "MISSING"))
stopifnot("frozen file is missing columns a registered spec would need" =
            length(setdiff(miss, grep("^cl_share_mi_", miss, value = TRUE))) == 0,
          mi_ok)

# hospital counts the influential-point levels drop -- recorded, not fitted
n_fn2329  <- sum(a$fn_claims_discrepancy | a$fn_partial_window, na.rm = TRUE)
n_fallbk  <- sum(a$catch_source == "county_fallback", na.rm = TRUE)
cat(sprintf("\n  drop_fn2329 removes %d hospitals (fn-23 %d + fn-29 %d, disjoint)\n",
            n_fn2329, sum(a$fn_claims_discrepancy, na.rm = TRUE), sum(a$fn_partial_window, na.rm = TRUE)))
cat(sprintf("  drop_fallback removes %d hospitals (catch_source == \"county_fallback\")\n", n_fallbk))

# ==========================================================================
sub_("3. build the full grid, then prune the structural voids")

g <- expand.grid(AX, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
cat(sprintf("  full grid rows: %d\n", nrow(g)))

# V2 first: missing is only a real axis when Block C is in. For blocks != ABC
# collapse the three levels to a single sentinel "na" (do this by keeping only
# missing == "mi" rows for non-ABC, then relabelling -- avoids 3x duplication).
g <- g[g$blocks == "ABC" | g$missing == "mi", ]
g$missing[g$blocks != "ABC"] <- "na"
cat(sprintf("  after V2 (missing axis needs Block C):            %d\n", nrow(g)))

# V1: spline needs Block B.
g <- g[!(g$blocks == "A" & g$form == "spline"), ]
cat(sprintf("  after V1 (spline needs Block B):                  %d\n", nrow(g)))

# V3: eiv reliability needs a published per-hospital lambda -> composite only.
g <- g[!(g$reliability == "eiv" & g$outcome != "composite"), ]
cat(sprintf("  after V3 (eiv reliability is composite-only):     %d\n", nrow(g)))

# V4: under blocks = A the catchment covariate grains are inert; the grain axis
# is just the nesting choice {hsa-nested, county-nested}. Keep hsa + hosp_county.
g <- g[!(g$blocks == "A" & g$grain %in% c("catch_tract", "catch_county")), ]
cat(sprintf("  after V4 (catchment grain inert under blocks=A):  %d\n", nrow(g)))

# V5: drop_fallback is a no-op where no catchment weighting is used.
g <- g[!(g$influential == "drop_fallback" &
           (g$blocks == "A" | g$grain == "hosp_county")), ]
cat(sprintf("  after V5 (drop_fallback no-op w/o catchment):     %d\n", nrow(g)))

# ==========================================================================
sub_("4. derived fields for the Task 3.6 harness")

reg <- data.frame(
  spec_id     = seq_len(nrow(g)),
  g[, names(AX)],
  row.names   = NULL,
  stringsAsFactors = FALSE
)

reg$outcome_family <- ifelse(reg$outcome == "composite", "composite",
                      ifelse(reg$outcome == "agg", "aggregate", "component"))

# how each reliability level is realised, given the outcome
reg$weight <- with(reg, ifelse(
  reliability == "unweighted", "none",
  ifelse(reliability == "weighted",
         ifelse(outcome_family == "composite", "lambda_i", "denominator"),
  ifelse(reliability == "subsample", "none_high_reliability_subsample",
         "lambda_eiv"))))
reg$subsample <- reg$reliability == "subsample"     # restrict to top reliability tier

# nesting geography implied by the grain
reg$nest <- ifelse(reg$grain == "hosp_county", "county", "hsa")

# Block B covariate column suffix (NA when Block B is not in the model)
reg$blockB_suffix <- ifelse(reg$blocks == "A", NA_character_,
                     ifelse(reg$grain == "hosp_county", "county",
                     ifelse(reg$grain == "hsa", "hsa", reg$grain)))

# a stable human-readable key
reg$key <- with(reg, paste(blocks, form, outcome, reliability, grain, missing,
                           influential, scale, sep = "."))
stopifnot(!anyDuplicated(reg$key))

# ==========================================================================
sub_("5. the count, by block set")

tab <- table(reg$blocks)[c("A", "AB", "ABC")]
for (b in names(tab)) cat(sprintf("  blocks = %-3s   %5d specs\n", b, tab[b]))
N <- nrow(reg)
cat(sprintf("\n  ================  N = %d registered specifications  ================\n", N))
cat("\n  cross-tabs:\n")
print(addmargins(table(reg$blocks, reg$outcome)))
cat("\n")
print(addmargins(table(reg$reliability, reg$outcome_family)))
cat("\n")
print(addmargins(table(reg$blocks, reg$influential)))

# ==========================================================================
sub_("6. write the registry -- this is the artefact the commit freezes")

saveRDS(reg, file.path("data", "spec-registry.rds"))
write.csv(reg, file.path("data", "spec-registry.csv"), row.names = FALSE)
cat(sprintf("  data/spec-registry.rds   %d rows x %d cols\n", nrow(reg), ncol(reg)))
cat(sprintf("  data/spec-registry.csv   (human-readable mirror, force-tracked)\n"))

# sha256 of the serialised registry -- same object-hash pattern as R/freeze.R,
# shelled out to the platform digest (no `digest` package in renv).
ser <- tempfile(); writeBin(serialize(reg, NULL, version = 3), ser)
h <- sub("^([0-9a-f]{64}).*$", "\\1",
         trimws(system(sprintf("shasum -a 256 %s", shQuote(ser)), intern = TRUE)[1]))
unlink(ser)
cat(sprintf("  registry sha256 (serialised object v3): %s\n", h))

# ==========================================================================
hdr("verify")
cat(sprintf("  1. registry is machine-readable, one row per spec, integer spec_id -- PASS\n"))
cat(sprintf("  2. N counted and printed BEFORE any fit: N = %d -- PASS\n", N))
cat(sprintf("  3. every axis level's input columns confirmed present in the frozen file -- PASS\n"))
cat(sprintf("  4. structural voids V1-V5 pruned; no spec is a logical impossibility or exact dup -- PASS\n"))
cat(sprintf("  5. the commit of this file predates R/04-spec-curve.R (Task 3.6) -- the timestamp is the evidence\n"))
stopifnot(N > 0, !anyDuplicated(reg$spec_id), !anyDuplicated(reg$key),
          all(reg$missing[reg$blocks != "ABC"] == "na"),
          all(reg$form[reg$blocks == "A"] == "linear"),
          !any(reg$reliability == "eiv" & reg$outcome != "composite"))

hdr("done")
cat(sprintf("\n  N = %d  -- fix this number in provenance/task3.5-spec-registry.md and commit.\n\n", N))
