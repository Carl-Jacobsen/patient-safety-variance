# R/provenance.R
#
# The provenance table and its helpers.
#
# Phase 1's test is that a stranger holding only provenance/sources.csv can
# re-download every file this project reads. Everything here exists to keep
# that true: a fixed schema, a hash function, an append that validates, and a
# reader that fails loudly rather than silently returning a short table.
#
# Base R only. Sourced by make.R; safe to source on its own.

PROV_FILE <- file.path("provenance", "sources.csv")

## The schema. Seven columns come from Task 1.1 as written in the plan; three
## more come from what Phase 0 actually ran into, and one is a stable key.
##
##   source_id        stable short key, cited from task notes and the report
##   source           the publisher and programme, not the filename
##   file             path under data-raw/, relative to the project root
##   retrieval_date   ISO-8601, the day the bytes were fetched
##   url              the address a stranger would use, not a session URL
##   retrieval_method direct URL | metastore API | account login | manual
##                    -- PDC download URLs carry a release token that changes
##                       on each refresh, so "the URL" alone is not a recipe
##   vintage          the data period, not the publication date
##   license          terms as stated by the publisher
##   sha256           of the archived file, unedited
##   parse_notes      the trap that would otherwise be rediscovered
##                    (latin-1, header on line 2, leading zeros, ...)
##   exclusion_reason non-empty ONLY for attempted-and-excluded sources.
##                    Standing rule 4: nothing gets dropped quietly, and
##                    before this column there was nowhere to put a source
##                    that was tried and rejected (RAND, paywalled).
PROV_COLS <- c(
  "source_id", "source", "file", "retrieval_date", "url", "retrieval_method",
  "vintage", "license", "sha256", "parse_notes", "exclusion_reason"
)

## `catalog API` is the data.cms.gov DCAT route (data.json -> dataset title ->
## distribution downloadURL); `metastore API` is the Provider Data Catalog's.
## Both exist because both publishers rotate their file URLs.
PROV_METHODS <- c("direct URL", "metastore API", "catalog API", "web API",
                  "account login", "manual", "not retrieved")

## sha256 of a file. tools::md5sum is base, sha256sum is not, so shell out to
## the platform digest and check we got 64 hex characters back.
sha256_file <- function(path) {
  stopifnot(file.exists(path))
  cmd <- if (nzchar(Sys.which("shasum"))) {
    sprintf("shasum -a 256 %s", shQuote(path))
  } else if (nzchar(Sys.which("sha256sum"))) {
    sprintf("sha256sum %s", shQuote(path))
  } else {
    stop("no shasum or sha256sum on PATH; cannot hash ", path)
  }
  out <- system(cmd, intern = TRUE)
  h <- sub("^([0-9a-f]{64}).*$", "\\1", trimws(out[1]))
  if (!grepl("^[0-9a-f]{64}$", h)) stop("unexpected hash output for ", path, ": ", out[1])
  h
}

prov_read <- function(file = PROV_FILE) {
  stopifnot(file.exists(file))
  d <- utils::read.csv(file, colClasses = "character", check.names = FALSE,
                       na.strings = character(0))
  if (!identical(names(d), PROV_COLS)) {
    stop("provenance schema drift in ", file, "\n  expected: ",
         paste(PROV_COLS, collapse = ", "), "\n  found:    ", paste(names(d), collapse = ", "))
  }
  d
}

## Append one row. Hashes the file itself rather than trusting a hash typed in
## by hand, and refuses a duplicate source_id.
prov_add <- function(source_id, source, file, url, retrieval_method,
                     vintage, license, parse_notes = "", exclusion_reason = "",
                     retrieval_date = format(Sys.Date()), sha256 = NULL,
                     prov_file = PROV_FILE) {
  d <- prov_read(prov_file)
  if (source_id %in% d$source_id) stop("source_id already present: ", source_id)
  if (!retrieval_method %in% PROV_METHODS) {
    stop("retrieval_method must be one of: ", paste(PROV_METHODS, collapse = ", "))
  }
  if (is.null(sha256)) {
    sha256 <- if (file.exists(file)) sha256_file(file) else ""
  }
  if (!nzchar(sha256) && !nzchar(exclusion_reason)) {
    stop("a retrieved source needs a sha256; an unretrieved one needs an exclusion_reason")
  }
  row <- data.frame(source_id = source_id, source = source, file = file,
                    retrieval_date = retrieval_date, url = url,
                    retrieval_method = retrieval_method, vintage = vintage,
                    license = license, sha256 = sha256, parse_notes = parse_notes,
                    exclusion_reason = exclusion_reason, stringsAsFactors = FALSE)
  utils::write.csv(rbind(d, row)[, PROV_COLS], prov_file, row.names = FALSE, na = "")
  invisible(row)
}

## Verify every archived file still hashes to what the table says. Task 1.7
## closes the provenance table with this; make.R runs it whenever the table is
## non-empty, so a silently re-downloaded or edited raw file is caught early.
prov_verify <- function(prov_file = PROV_FILE, quiet = FALSE) {
  d <- prov_read(prov_file)
  d <- d[!nzchar(d$exclusion_reason), , drop = FALSE]
  if (!nrow(d)) {
    if (!quiet) cat("  provenance table has no retrieved sources yet\n")
    return(invisible(TRUE))
  }
  ok <- vapply(seq_len(nrow(d)), function(i) {
    if (!file.exists(d$file[i])) {
      if (!quiet) cat(sprintf("  MISSING  %-20s %s\n", d$source_id[i], d$file[i]))
      return(FALSE)
    }
    h <- sha256_file(d$file[i])
    if (!identical(h, d$sha256[i])) {
      if (!quiet) cat(sprintf("  MISMATCH %-20s %s\n", d$source_id[i], d$file[i]))
      return(FALSE)
    }
    if (!quiet) cat(sprintf("  ok       %-20s %s\n", d$source_id[i], d$file[i]))
    TRUE
  }, logical(1))
  invisible(all(ok))
}
