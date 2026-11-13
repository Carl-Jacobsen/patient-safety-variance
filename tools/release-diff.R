# tools/release-diff.R  --  Task S4.1, the change table.
#
# Compares every number stage 39 registers in the release run with the
# September 30 registry archived at Task S0.1, and names the second-pass task
# responsible for each difference. Not a make.R stage: the archive is a local,
# gitignored copy (its manifest is tracked).
#
#   Rscript tools/release-diff.R <old registry> <new registry> <out csv>
#
# A registry row is (section, key, value). Some keys carry a vector and so
# appear more than once; rows are matched on (section, key, occurrence).
#
# Status: unchanged (|diff| <= 1e-9 relative) / changed / new / retired.
# Attribution is by rule, first match wins, each rule citing the provenance
# note that records the change. A difference no rule claims is "UNATTRIBUTED"
# and the script stops: every changed number must trace to a task.

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3)
o <- read.csv(args[1], stringsAsFactors = FALSE); n <- read.csv(args[2], stringsAsFactors = FALSE)
occ <- function(d) ave(seq_len(nrow(d)), d$section, d$key, FUN = seq_along)
o$i <- occ(o); n$i <- occ(n)
ko <- paste(o$section, o$key, o$i, sep = "\r"); kn <- paste(n$section, n$key, n$i, sep = "\r")
all_k <- union(kn, ko)
D <- data.frame(section = sub("\r.*", "", all_k), key = sub("^[^\r]*\r(.*)\r[0-9]+$", "\\1", all_k),
                occurrence = as.integer(sub(".*\r", "", all_k)),
                old = o$value[match(all_k, ko)], new = n$value[match(all_k, kn)],
                source = ifelse(all_k %in% kn, n$source[match(all_k, kn)], o$source[match(all_k, ko)]),
                stringsAsFactors = FALSE)
in_o <- all_k %in% ko; in_n <- all_k %in% kn
same <- (is.na(D$old) & is.na(D$new)) | (!is.na(D$old) & !is.na(D$new) & abs(D$old - D$new) <= 1e-9 * pmax(1, abs(D$old)))
D$status <- ifelse(!in_o, "new", ifelse(!in_n, "retired", ifelse(same, "unchanged", "changed")))

## ---- attribution rules: (status set, field, pattern, task, reason) ----
R <- list(
  ## new analyses, by registry prefix
  list("new", "key", "^ss ", "S3.2", "suppression sensitivity, stage 44 (taskS3.2-suppression.md)"),
  list("new", "key", "^(if |mnar |cl (orig missing|screened|imputed|sd observed)$)", "S3.1", "inclusion flow and contract-labor shift, stage 43 (taskS3.1)"),
  list("new", "key", "^own ", "S3.3", "ownership sensitivity, stage 45 (taskS3.3-labels.md)"),
  list("new", "key", "^(cl |cells |bands )", "S3.4", "cluster criteria, nine-cell tables, alternative bands, stage 46 (taskS3.4)"),
  list("new", "key", "^gc ", "S2.6", "geography as construction, stage 42 (taskS2.6)"),
  list("new", "key", "^cs ", "S2.5", "contrast support, stage 41 (taskS2.5)"),
  list("new", "key", "^gv ", "S2.4", "geographic validation, stage 40 (taskS2.4)"),
  ## renames and relabels
  list(c("new", "retired"), "key", "^(pub |vd |vd_explained|comm_of_expl|struct_of_expl|ci_width_volume_slope$|residual( weighted)?$)", "S2.1",
       "published score primary: keys relabeled published/weighted, published-subset set added (taskS2.1)"),
  list(c("new", "retired"), "key", "(headroom|distance from the best measured score)", "S1.6",
       "\"improvement headroom\" renamed \"distance from the best measured score\"; regressivity of the finite return (taskS1.6)"),
  list(c("new", "retired"), "key", "^(marg_pct|expo_pct)$", "S1.4",
       "marginal incentive retired; w x 0.039 kept as the revenue exposure coefficient (taskS1.4, S1.6)"),
  ## changed values, by the table that produced them
  list("changed", "source", "tis-|driver-tags|stage 32 log", "S1.1, S1.2",
       "TIS wrapper repaired and rerun (taskS1.1, taskS1.2)"),
  list("changed", "source", "payment-sim\\.rds", "S1.4", "payment draws B = 8,000 -> 16,000 (taskS1.4)"),
  list("changed", "source", "regressivity\\.csv|regressivity-by-stratum|payment-by-stratum|payment-gap|payment-by-hospital|task4\\.2",
       "S1.3-S1.6 (on S0.4)", "payment stage rerun: tie rule, finite return, scenario curves, rerun on analytic-v2 (taskS1.3-S1.6)"),
  list("changed", "source", "hacrp-calibration|observed-hacrp", "S0.4, S1.6",
       "calibration and model-implied strata recomputed on analytic-v2 and rerun (taskS0.4 v2 rerun; taskS1.6)"),
  list("changed", "source", "sources\\.csv", "S2.2", "five methodology sources added (taskS2.2)"),
  list("changed", "source", paste0("catchment-vs-county|missingness-audit|adi-aggregation|variance-decomposition|weighted minus|",
                                   "spec-curve|spec-diagnostics|rashomon-|mcr-bounds|mcr-per-model|archetype|task3\\.|analytic-v2|cluster"),
       "S0.4", "Connecticut and mixed-unit allocation repaired; every model refit on analytic-v2 (taskS0.4, amendments.md amendment 1)")
)
D$task <- NA_character_; D$reason <- NA_character_
for (r in R) {
  hit <- is.na(D$task) & D$status %in% r[[1]] & grepl(r[[3]], D[[r[[2]]]], perl = TRUE)
  D$task[hit] <- r[[4]]; D$reason[hit] <- r[[5]]
}
D$task[D$status == "unchanged"] <- ""; D$reason[D$status == "unchanged"] <- ""
## copies in 01/10 (via another section) inherit their source rule; anything left is unattributed
left <- D$status != "unchanged" & is.na(D$task)
if (any(left)) {
  print(D[left, c("section", "key", "old", "new", "source")], row.names = FALSE)
  stop(sum(left), " difference(s) no rule attributes to a task")
}
D <- D[order(match(D$status, c("changed", "new", "retired", "unchanged")), D$section, D$key, D$occurrence), ]
write.csv(D, args[3], row.names = FALSE)
cat(sprintf("%d registry rows: %s\n", nrow(D), paste(sprintf("%s %d", names(table(D$status)), table(D$status)), collapse = ", ")))
print(table(task = D$task[D$status != "unchanged"], status = D$status[D$status != "unchanged"]))
