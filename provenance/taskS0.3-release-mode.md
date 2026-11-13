# Task S0.3 — Release mode, and caches keyed to their dependencies

**Date:** 2026-10-01 · **Budget:** 2 h · **Status: done; both verify conditions
pass.** The release mode also found a stage that had failed on every full run
since 2026-09-22 (sec 3).

---

## 1. Release mode

`Rscript make.R --release` runs every stage and **stops at the first stage that
is skipped or fails**, exit status 1, naming the stage. Stopping matters as much
as refusing: in the ordinary mode a failed or skipped stage is reported and the
run continues, so every later stage reads whatever an earlier run left behind
and can still finish cleanly. After the last stage and the provenance check,
release mode builds the report (`tools/build_report.py`) and fails if the build
fails. `--cold` (release only) sets every cache's force variable. `--release`
with `--stage`, and `--cold` without `--release`, are refused. Under release,
`04-spec-curve.R` cannot fall back to its 10-specification TEST subset
(`VP_RELEASE=1`).

## 2. Caches keyed to their dependencies

`R/cache-key.R`: a cache is reused only when the key recorded beside it
(`<cache>.key`) equals the key of what it depends on now. The key hashes the
files the computation reads or runs, the text of the functions in the calling
script that it calls, and its settings. Eight cache files, all moved off
modification times or partial keys:

| Cache (stage) | Keyed on | Before |
|---|---|---|
| `spec-results.rds` (24) | the harness, registry, analytic file, imputations | mtime of registry and harness |
| `rashomon-loss.rds`, `rashomon-boot.rds` (27) | the harness, registry, data, and the loss and resampling functions | mtime of registry and harness; ignored the data and the loss code |
| `variance-decomp-boot.rds` (22) | analytic file, settings, and the five functions the draws run | settings and analytic hash; ignored the code |
| `mcr-reliance.rds` (30) | the runner, `06-mcr.R`, the harness, set, registry, data | mtime of set and `06-mcr.R`; ignored its own runner |
| `tis-decomposition.rds` (32) | the runner, `07-tis.R`, `06-mcr.R`, the harness, set, registry, data | mtime of set and `07-tis.R`; **ignored the runner holding the defect** |
| `cluster-stability.rds` (33) | the frame's contents, settings, and the four functions the subsamples run | frame and settings; ignored the code |
| `payment-fits.rds` (35) | the harness, `06-mcr.R`, set, loss, registry, data, and the four fitting functions | mtime of four files; ignored the data |

The long computations are keyed on **function text** rather than their whole
script, so editing a printed line does not re-draw 85 minutes of bootstrap or
refit the payment models while S1.3–S1.5 edit the payment rules.

**`.rds` inputs are hashed on content, not bytes.** The first version hashed
bytes, and the comparison in sec 4 showed why that fails: `blockC_mice.rds`,
`rashomon-set.rds` and `rashomon-tolerance.rds` each store when they were built
(a `date`, `built` or `run_time` field) and, for the imputations, formulas
carrying environment pointers. Byte hashes would have invalidated every
downstream cache on every run, and on every new day the multi-hour
specification refit. The content hash drops those four field names, renders
formulas and functions as text and environments as a token.

**Adoption.** The existing caches had no keys. Before any script was edited,
the old modification-time test was recorded for each: all passed except TIS
against its runner (cache 2026-09-22, runner edited 2026-09-29). The git diff
shows that edit only added the Model 2 tag table (Task 5.4) and left
`decompose_spec()` untouched. A Rashomon edit after its loss cache (2026-09-18)
changed only how hospitals without a cluster value are grouped, which matters
for the metro bootstrap drawn after it. Every cache was therefore built by the
code that would rebuild it, and keys were recorded for the existing caches
through a temporary `CACHE_ADOPT` switch. The switch was then removed; it is
not in the committed code.

## 3. Stage 28 had failed since September 22

The first release run stopped at stage 28 (Task 3.10, the Rashomon set). Its
verify block asserted `!file.exists("R/06-mcr.R")`, which was true when the
set was built and false from Task 3.11 (065dc39) on. **Every full run since
2026-09-22 has failed stage 28** and carried on. The set itself was written
before the assertion, so nothing downstream was stale; the order the assertion
checked is recorded by the commits (b3f04cc before 065dc39). The assertion is
retired with a comment saying so.

## 4. Verify

**The outputs did not move.** After the adoption run, 75 of 76 archived CSVs
are byte-identical to the regenerated ones, and so are all eight figures. The
76th, `admission-gate-results.csv`, differs only in its run-date column. The
three `.rds` files that differ in bytes differ only in build time (and, for the
imputations, formula environments); their content hashes equal the archive's.

**The keys hold.** A second pass over stages 20–39 reported "key matches,
reused" for all eight caches, and every stage exited 0.

**Whitespace test.** A blank line appended to `R/08-clusters.R`: stage 32
reports "key matches, reused". The same line appended to `R/07-tis-run.R`:
"a dependency changed, recomputed" (242 s). Both files and the original TIS
cache were then restored, and stage 32 again reports a match.

**Skip test.** With `data-raw/careCompare_2022Q3-2024Q2/Footnote_Crosswalk.csv`
moved away, `make.R --release` exited 1 at stage 1 ("RELEASE STOPPED at stage 1
(skipped)"), naming the file. The file was restored and its hash checked. A
first attempt moved the stage's symlink instead, which the relocation step
recreated; that run was stopped and proved nothing.

## 5. The report builder

`report-draft/build_docx.py` moved to `tools/build_report.py`; the original is
in the archive (added to its manifest). Sections are now every `report/NN-*.md`
then `appendix.md`, captions come from `report/figures.csv`, output goes to
`output/report/` (gitignored), and the footer date is that of the last commit
touching `report/`. LibreOffice is found through `SOFFICE`, the `PATH`, then the
usual install locations. It rebuilds the September 30 draft at 45 pages, as
before. `report-draft/build_tasks_docx.py` now imports from it.
