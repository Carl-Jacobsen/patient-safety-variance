# R/hsaf.R -- the one correct way to read a Hospital Service Area File.
#
# The raw CMS file ends with a Ctrl-Z (0x1A, "\032") DOS end-of-file marker.
# read.csv turns it into a junk final data row: MEDICARE_PROV_NUM = "\032",
# every other field empty. It is a real parse trap -- it inflates
# is.na(TOTAL_CASES) by one cell (996,701 vs 996,700 in CY 2023) and would
# carry a bogus provider number into any join. spike-context.md called it a
# "trailing empty line"; it is not, it is a control character.
#
# Every reader of the HSAF from Task 2.4 onward goes through here, so the trap
# is handled exactly once. The ported Phase 0 drivers (make.R stages 1 and 1b)
# deliberately keep their raw read -- their job is to reproduce Phase 0's
# numbers, EOF row included -- so this helper is additive, not a patch to them.
#
# Suppression is a literal '*' (space-padded to the field width in the wider
# columns), not NA and not blank. This returns character columns untouched;
# converting TOTAL_CASES and its siblings to numeric -- which turns '*' into
# NA -- is the caller's step, and a deliberate one.

read_hsaf <- function(path) {
  stopifnot(file.exists(path))
  d <- utils::read.csv(path, colClasses = "character", check.names = FALSE,
                       na.strings = character(0))
  need <- c("MEDICARE_PROV_NUM", "ZIP_CD_OF_RESIDENCE", "TOTAL_CASES")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop("not an HSAF file -- missing columns: ", paste(miss, collapse = ", "))

  prov <- d$MEDICARE_PROV_NUM
  ctrlz <- grepl("[\001-\037]", prov)                 # any C0 control char in the id
  empty <- !nzchar(trimws(prov)) &
           !nzchar(trimws(d$ZIP_CD_OF_RESIDENCE)) &
           !nzchar(trimws(d$TOTAL_CASES))
  drop <- ctrlz | empty

  if (any(drop)) {
    d <- d[!drop, , drop = FALSE]
    rownames(d) <- NULL
  }
  attr(d, "hsaf_dropped_rows") <- sum(drop)
  d
}
