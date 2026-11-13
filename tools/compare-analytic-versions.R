## tools/compare-analytic-versions.R -- Task S0.4: every frame hospital, every numeric
## column, archived v1 (archive/draft-2026-09-30) against the current v2. Writes
## output/tables/ct-allocation-check.csv. Run from the project root:
##   Rscript tools/compare-analytic-versions.R
old <- readRDS("archive/draft-2026-09-30/data/analytic-v1.rds"); new <- readRDS("data/analytic-v2.rds")
stopifnot(identical(old$ccn, new$ccn), identical(names(old), names(new)))
num <- names(old)[vapply(old, is.numeric, logical(1))]
ch <- sapply(num, function(v) { d <- abs(old[[v]] - new[[v]]); d[is.na(d)] <- ifelse(is.na(old[[v]]) == is.na(new[[v]]), 0, Inf)[is.na(d)]; d })
nonnum <- setdiff(names(old), num); cat("non-numeric cols changed:", sum(!sapply(nonnum, function(v) identical(old[[v]], new[[v]]))), "\n")
moved <- ch > 1e-8
hosp <- rowSums(moved) > 0
cat("hospitals with any column moved:", sum(hosp), "of", nrow(old), " CT:", sum(hosp & old$state == "CT"), " non-CT:", sum(hosp & old$state != "CT"), "\n")
cat("columns moved:", paste(names(which(colSums(moved) > 0)), collapse = ", "), "\n")
sdv <- sapply(num, function(v) sd(old[[v]], na.rm = TRUE))
rel <- sweep(ch, 2, sdv, "/")
cols <- names(which(colSums(moved) > 0))
out <- do.call(rbind, lapply(cols, function(v) data.frame(column = v,
  n_ct = sum(moved[, v] & old$state == "CT"), n_other = sum(moved[, v] & old$state != "CT"),
  max_sd_ct = max(c(0, rel[old$state == "CT", v]), na.rm = TRUE), max_sd_other = max(c(0, rel[old$state != "CT", v]), na.rm = TRUE))))
print(out, row.names = FALSE, digits = 3)
write.csv(out, "output/tables/ct-allocation-check.csv", row.names = FALSE)
cat("non-CT hospitals moved by state:\n"); print(table(old$state[hosp & old$state != "CT"]))
