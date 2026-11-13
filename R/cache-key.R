## R/cache-key.R -- Task S0.3 (second pass): caches keyed to their dependencies.
##
## A cache is reused only when the key recorded beside it (<cache>.key) equals
## the key of what it depends on now. The key is the sha256 of three things:
## every file the cached computation reads or whose code it runs; the deparsed
## text of every function, defined in the calling script, that the computation
## calls; and any settings (B, seed, scheme).
##
## Function text stands in for the whole calling script where that script also
## prints results, so that editing a printed sentence does not re-draw an
## 85-minute bootstrap while editing the bootstrap's own code does. deparse()
## without "useSource" drops comments and layout, so a comment edit inside one
## of those functions does not count as a change either. Whole files are hashed
## byte for byte.
##
## This replaces modification-time checks, which missed dependencies (the TIS
## cache ignored the runner that held the TIS defect, review of 2026-10-01) and
## which a copy or a checkout can make wrong in either direction.

if (!exists("sha256_file")) source(file.path("R", "provenance.R"))

## Build products that record when they were built (`built`, `run_time`,
## `fit_time`, `date`) change bytes on every rebuild without changing content,
## and a formula carries a pointer to the environment it was made in. Hashing
## such a file byte for byte would invalidate every cache downstream of it on
## every run (blockC_mice.rds daily, which means the multi-hour specification
## refit). So an .rds dependency is hashed on its CONTENT: those top-level
## fields dropped, formulas and functions as text, environments as a token.
## Every other file is hashed byte for byte.
CACHE_VOLATILE <- c("built", "run_time", "fit_time", "date")
cache_canon <- function(x) {
  if (is.environment(x)) return("<environment>")
  if (inherits(x, "formula") || is.function(x)) return(paste(deparse(x), collapse = "\n"))
  if (is.list(x)) {
    nm <- names(x)
    x <- lapply(unclass(x), cache_canon)   # unclass: a package_version's [[ returns itself
    names(x) <- nm
  }
  x
}
dep_hash <- function(f) {
  if (!grepl("\\.rds$", f, ignore.case = TRUE)) return(sha256_file(f))
  o <- readRDS(f)
  if (is.list(o) && !is.data.frame(o) && !is.null(names(o))) o <- o[setdiff(names(o), CACHE_VOLATILE)]
  tf <- tempfile(fileext = ".bin"); on.exit(unlink(tf))
  writeBin(serialize(cache_canon(o), NULL, version = 3), tf)
  sha256_file(tf)
}

cache_key <- function(files = character(0), funs = list(), settings = list()) {
  files <- sort(unique(files))
  miss <- files[!file.exists(files)]
  if (length(miss)) stop("cache_key: dependency absent: ", paste(miss, collapse = ", "))
  ftext <- vapply(funs, function(f) paste(deparse(f), collapse = "\n"), character(1))
  tf <- tempfile(); on.exit(unlink(tf))
  writeLines(c(paste(vapply(files, dep_hash, character(1)), files),
               if (length(funs)) paste0("## function ", names(funs), "\n", ftext),
               paste(deparse(settings), collapse = "\n")), tf)
  sha256_file(tf)
}

## a <VAR>=1 environment variable forces a recompute, as before
cache_forced <- function(var) !is.null(var) && Sys.getenv(var) %in% c("1", "true", "TRUE", "yes")

cache_fresh <- function(path, key, refit_var = NULL) {
  kf <- paste0(path, ".key")
  why <- if (cache_forced(refit_var)) paste0(refit_var, "=1 forces a recompute")
         else if (!file.exists(path)) "absent"
         else if (!file.exists(kf)) "no key on record"
         else if (!identical(readLines(kf, warn = FALSE)[1], key)) "a dependency changed"
         else NA_character_
  cat(sprintf("  cache %s: %s\n", basename(path),
              if (is.na(why)) "key matches, reused" else paste0(why, ", recomputed")))
  is.na(why)
}

## write the key AFTER the object, so an interrupted save leaves no valid key
cache_save <- function(obj, path, key) {
  saveRDS(obj, path)
  writeLines(key, paste0(path, ".key"))
  invisible(path)
}
