# R/relocate.R
#
# Phase 0 archived everything under data-raw/spike-phase0/. Phase 1 moves each
# file into a permanent, per-source directory as its acquisition task reaches
# it. Those two facts collide: the ported Phase 0 drivers read the spike paths,
# and standing rule 1 says their numbers must keep regenerating.
#
# Rather than edit the ported bodies -- which would end the guarantee that they
# are the Phase 0 scripts and not a retelling of them -- every move is recorded
# in provenance/relocations.csv and replayed here as a relative symlink at the
# old path. read.csv, readLines, and unzip follow symlinks without noticing.
#
# This is also what makes a re-download reproducible: a stranger who rebuilds
# data-raw/ from sources.csv gets the permanent paths only, and make.R restores
# the spike-era paths from the same table.

RELOC_FILE <- file.path("provenance", "relocations.csv")

reloc_read <- function(file = RELOC_FILE) {
  if (!file.exists(file)) return(data.frame(from = character(), to = character(), note = character()))
  utils::read.csv(file, colClasses = "character", check.names = FALSE, na.strings = character(0))
}

## Recreate any missing compatibility link whose target is present. Returns the
## number of links made. Never overwrites a real file -- if something exists at
## `from` that is not a symlink, that is a genuine duplicate and it is reported.
reloc_apply <- function(file = RELOC_FILE, quiet = FALSE) {
  r <- reloc_read(file)
  if (!nrow(r)) return(invisible(0L))
  made <- 0L
  for (i in seq_len(nrow(r))) {
    from <- r$from[i]; to <- r$to[i]
    if (!file.exists(to)) next                       # target not downloaded yet
    if (!is.na(Sys.readlink(from)) && nzchar(Sys.readlink(from))) next   # link already there
    if (file.exists(from)) {
      if (!quiet) cat("  DUPLICATE  a real file sits at ", from,
                      "\n             it should have moved to ", to, "\n", sep = "")
      next
    }
    dir.create(dirname(from), recursive = TRUE, showWarnings = FALSE)
    ## `to` is written relative to the project root, so the link has to climb
    ## out of `from`'s directory first -- one ".." per component of it.
    up  <- length(strsplit(dirname(from), "/", fixed = TRUE)[[1]])
    rel <- file.path(paste(rep("..", up), collapse = "/"), to)
    if (file.symlink(rel, from)) {
      made <- made + 1L
      if (!quiet) cat("  linked     ", from, " -> ", to, "\n", sep = "")
    } else if (!quiet) {
      cat("  FAILED     could not link ", from, "\n", sep = "")
    }
  }
  if (!made && !quiet) {
    have <- sum(file.exists(r$to))
    cat(if (have) "  compatibility links already in place\n"
        else "  nothing to link yet -- no relocated file has been downloaded\n")
  }
  invisible(made)
}
