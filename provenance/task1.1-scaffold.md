# Task 1.1 — Scaffold the project

**Date:** 2026-08-26 · **Budget:** 2 h · **Status: complete**, with one part of the
verify condition standing open (§5).

---

## 1. What exists now

`variance-project/` is a git repository at commit 1, with `renv` initialised *in* that
commit rather than bolted on later — the CASH2 failure mode, avoided at its only cheap
moment.

```
make.R                  the single driver
DESCRIPTION             declared dependency set
renv.lock               R 4.5.0, 78 packages, snapshot type "explicit"
R/provenance.R          schema, hashing, validated append, re-verification
R/phase0-numbers.R      stage 1   (ported)
R/phase0-followup.R     stage 1b  (ported)
provenance/sources.csv  headers only, as specified
data-raw/  data/  output/figures/  output/tables/  report/
```

## 2. The Phase 0 drivers were ported, not rewritten

`provenance/phase0-numbers.R` and `phase0-followup.R` are now `R/phase0-numbers.R` and
`R/phase0-followup.R`, stages 1 and 1b of `make.R`. **The bodies are byte-identical from
`RAW <- file.path(...)` onward**; only the header comments changed. Verified by `diff`,
not by eye.

They are still base R with relative paths and no packages, which is why stage 1 runs
*before* `renv::restore()` on a fresh clone. That property was worth preserving rather
than modernising away.

The originals are deleted rather than duplicated — two copies of a regeneration script is
how the numbers in one document quietly stop matching another. Older Phase 0 notes cite
the old paths, so `provenance/phase0-numbers.R.MOVED` explains where they went.

## 3. Three decisions taken inside this task

**a. `sources.csv` schema — extended, as `phase1-readiness.md` §6.2 recommended.** The
plan's seven columns are source, file, retrieval date, URL, vintage, license, sha256.
Four more:

| Column | Why |
|---|---|
| `retrieval_method` | PDC download URLs carry a release token that changes on each refresh. "The URL" alone is not a recipe, so the *method* — direct URL, metastore API, account login, manual — has to travel with it. Constrained to that vocabulary; a typo is rejected. |
| `parse_notes` | Latin-1 with the header on line 2; leading zeros on the CCN; comma-concatenated footnote codes. Phase 0 paid to find these once. |
| `exclusion_reason` | Standing rule 4 requires attempted-and-excluded sources to stay visible, and before this column there was nowhere to put RAND. |
| `source_id` | Not in the recommendation. A stable short key so task notes and the report can cite a row without quoting a filename that may be re-released. Cheap; reversible. |

`prov_add()` hashes the file itself rather than trusting a hash typed by hand, refuses a
duplicate `source_id`, and requires that a row carry either a sha256 or an
`exclusion_reason` — a row can be a retrieved file or a documented refusal, not neither.

**b. `make.R` skips rather than fails on absent inputs.** A fresh clone carries no
`data-raw/` — 144 MB of re-downloadable files do not belong in git, and the whole claim
of Phase 1 is that they *are* re-downloadable. So a stage whose inputs are missing prints
the missing filenames and returns "skipped", and the driver exits 0. This is what makes
"runs end to end even when it has nothing to do yet" true in the literal sense.

**c. Each stage tees to `output/tables/`.** Standing rule 1 says every number regenerates
from the driver. A number that regenerates only into a terminal that has since scrolled
away is not much use to the person checking it, so `phase0-numbers.txt` and
`phase0-followup.txt` are files.

## 4. Verification actually performed

| Check | Result |
|---|---|
| `Rscript make.R` in the working tree | both stages **ok**, 13.1 s, exit 0 |
| Fresh `git clone`, **no** `data-raw/` | both stages **skipped** with filenames named, exit 0 |
| Fresh clone **with** `data-raw/` restored | both stages **ok**, and both output files **byte-identical** to the working-tree run |
| Ported bodies vs Phase 0 originals | identical |
| `data-raw/spike-phase0/MANIFEST.sha256` | 16 files, all **OK** under `shasum -c` |
| `prov_add` / `prov_read` / `prov_verify` | round-trip, hash match, duplicate id rejected, bad method rejected |
| `renv::status()` | synchronized |

Phase 0's headline numbers reproduce under `make.R`: frame **n = 2,801**, **107** VA
hospitals excluded, HSAF suppression **87.46%**, median λ **0.462**, corr(λ, log volume)
**+0.9345**, mean λ rural **0.304** vs non-rural **0.520**.

## 5. The open part of the verify condition

The task says the driver must run clean **"on a machine that is not yours."** What was
tested is a fresh clone in an isolated directory *on this machine*. That catches
absolute paths, uncommitted files, and stale objects in the session — the usual
offenders — but it does not catch a dependency that happens to be installed here and
nowhere else.

Two things are therefore untested: `renv::restore()` against a clean library, and R on
another OS. Closing it costs minutes: clone to another machine, `renv::restore()`,
`Rscript make.R`. Worth doing before Phase 2 freezes the analytic file, not urgent today.

## 6. Not done here, deliberately

`sources.csv` is empty of rows. Writing the Phase 0 sources' provenance rows is **Task
1.2**, which moves those files out of `data-raw/spike-phase0/` into the permanent layout
and takes their metadata from `spike-outcome.md` §2. Doing it now would mean writing rows
against paths that Task 1.2 then changes.

## 7. Next

**Task 1.2**, acquire the outcome layer: relocate the four archived Care Compare files,
add the FY 2026 HAC Reduction Program file through the metastore API, and write the first
five provenance rows. It depends on nothing that is not now in place.

Still Carl's, still parallel, still not blocking 1.2: the **ADI** registration, the
**Census API key**, and — the one item that cannot be recovered by working faster — the
**calendar slots for the 6.4 and 6.5 meetings**.
