# Task S4.1 — Rerun everything in release mode

**Date:** 2026-10-06 · **Budget:** 2 h attended (7 h 20 min unattended) ·
**Status: done.** A clean checkout of commit 5c036f7, with every cache cold,
ran all 47 stages (stages 1–46 and 1b), skipped none and exited 0. Provenance
is consistent, and `analytic-v2.rds` rebuilt from raw matches its frozen hash.
Every number stage 39 registers is byte-identical to the warm state the
second-pass tasks left, so the corrected pipeline reproduces from raw.

Against the September 30 archive, the registry has 2,438 rows. 328 are
unchanged, 333 changed, 1,699 are new and 78 are retired. Every changed, new
and retired row is attributed to a second-pass task; the script stops if any
is not. Stage 39's checks of the September 30 prose were deferred, as the task
sheet expects, and they come back on for S5.5.

---

## 1. What ran

- **Checkout.** `git clone` of the repository at 5c036f7 into
  `Patient Safety Variance Project/release-s4.1/`, outside the repository.
  Only `data-raw/` was copied in (461 MB; its bytes are checked against
  `provenance/sources.csv` by the end-of-run provenance check, which reported
  "consistent"). `data/` started holding only the committed specification
  registry.
- **Library.** `renv::restore()` from the lockfile. Every package was linked
  from the local renv cache and none was downloaded; `renv::status()` reported
  a consistent state.
- **Command.** `Rscript make.R --release --cold --defer-prose`, run detached
  (nohup, with `caffeinate -w` on its process). It started 11:53 and took
  26,395 s.
- **Exit status.** The run exited 0. make.R prints its closing rule only after
  the status-1 check, and the log ends with that rule. The log has no
  "SKIPPED" and no "FAILED" line.
- **Log.** `output/tables/taskS4.1-release.log`, 5,286 lines, sha256
  `03a600b8…bf88e`.

**Slowest stages (cold):**

| Stage | What | Time |
|---|---|---|
| 33 | clustering, 100 subsamples × ICL | 76 min |
| 35 | payment simulation, B = 16,000, metro set, uncertainty trace | 58 min |
| 27 | Rashomon tolerance bootstrap | 49 min |
| 22 | variance decomposition, HSA-cluster bootstrap | 48 min |
| 32 | TIS run and anchor bootstrap | 28 min |
| 30 | MCR run | 27 min |
| 24 | specification curve, all 3,496 specs | 25 min |
| 26, 29, 31, 43, 45 | diagnostics; and four stages that load the stage 29 machinery | 22–23 min each |

Stages 43 and 45 each take about 80 s warm. Cold, each re-runs `06-mcr.R`'s
own validation when it loads that file, which costs about 21 minutes apiece
(follow-up, sec 6).

## 2. The prose checks, deferred

The task sheet expects stage 39's scan of the September 30 prose to fail here,
and also asks for exit status 0. As built at S0.3, release mode would stop at
stage 39. Commit 5c036f7 added `--defer-prose`. With that flag:
- **Reported, not enforced:** stage 39's checks of the report prose, which are
  the per-section number scans, `structurally_regressive`, `no_causal_verbs`,
  `limitations_numbers`, `weighted_with_published`, `claim_guard` and
  `qualitative_claims`.
- **Still strict:**
  - the registry itself;
  - the inclusion-flow reconciliation;
  - the claim-guard self-test on the frozen September 30 prose;
  - the check of generated stage text.
- **No report built:** a document from the stale prose is not a release.

This run deferred 11 prose checks (sections 01, 03, 04, 05, 06, 08, 09 and 10,
`weighted_with_published`, `claim_guard`, `qualitative_claims`).

**S5.5 must run `make.R --release` without the flag.**

## 3. Reproduction

The release outputs were compared with a snapshot of the working tree taken
before the run started, when every stage there had last run warm:

| Compared | Result |
|---|---|
| `report-numbers.csv` (the registry, 2,360 rows) | byte-identical |
| 96 output tables | identical except for three kinds of difference: (a) run-date and runtime columns in `admission-gate-results.csv`, `rashomon-tolerance.csv` and `spec-results.csv`; (b) three tables written only by one-off `tools/` scripts (`ct-allocation-check.csv` at S0.4, `payment-ties-*.csv` at S1.3), which make.R does not produce; (c) nothing else |
| data products | identical in content. They differ only in build timestamps and runtimes (`mcr-reliance`, `rashomon-*`, `spec-results`, `variance-decomp-boot`). `cluster-stability.rds` has identical subsample results (G, 100 × 2) but an older cache layout in the working tree, with the key stored inside rather than in the S0.3 sidecar. `tie-count-*.rds` exists only in the working tree (a `tools/` cache) |
| `output/figures/final/MANIFEST.csv` (tracked) | identical (the clone's tree was clean after the run) |
| `analytic-v2.rds` | rebuilt from raw; "REPRODUCTION TEST: rebuilt file MATCHES the frozen hash" |

So the numbers do not depend on caches or on the order in which the second
pass touched stages.

## 4. The change table

`tools/release-diff.R` compares the archived September 30 registry
(`archive/draft-2026-09-30/tables/report-numbers.csv`) with the release
registry, matching rows on section, key and occurrence (some keys carry a
vector). The output is `output/tables/release-diff.csv`, 2,438 rows with old
value, new value, status, task and reason. Attribution is by rule, first match
wins, and each rule cites the provenance note that records the change. Any
difference no rule claims stops the script; none did.

| Task | Changed | New | Retired | What |
|---|---|---|---|---|
| S0.4 | 176 | | | Connecticut and mixed-unit allocation repaired; every model refit on `analytic-v2` (variance decomposition, specification curve, Rashomon set and its width, MCR bounds, coefficient ranges, catchment correlations, missingness SMDs) |
| S0.4, S1.6 | 4 | | | HACRP calibration and model-implied strata (C2 slope in λ quartile 1, 1.2849 → 1.2872) |
| S1.1, S1.2 | 64 | | | TIS repaired and rerun (for example the shared share of total 15.5% → 41.3%) |
| S1.3–S1.6 (on S0.4) | 87 | | | payment stage: tie rule, finite return, scenario curves, rerun |
| S1.4 | 1 | 1 | 1 | draws 8,000 → 16,000; marginal incentive retired, exposure coefficient kept |
| S1.6 | | 32 | 32 | "headroom" renamed "distance from the best measured score" |
| S2.1 | | 126 | 45 | published score primary: variance keys relabeled published/weighted; published-subset Rashomon set |
| S2.2 | 1 | | | sources 33 → 38 |
| S2.4 / S2.5 / S2.6 | | 159 / 189 / 312 | | geographic validation; contrast support; geography as construction |
| S3.1 / S3.2 / S3.3 / S3.4 | | 338 / 427 / 26 / 89 | | inclusion flow and contract-labor shift; suppression; ownership; archetype account |

**How to read the S0.4 row.** No registry was archived between the September
30 state and the `analytic-v2` rerun. The 176 are therefore attributed by the
table that produced them, not by replaying v1 and v2 separately. Two facts
support the attribution:
- the S1 and S2 tasks that touched those same tables changed only labels or
  wording (S2.1 and S2.3 record byte-identical outputs);
- the S0.4 note and amendment 1 record the v2 rerun moving exactly these
  quantities.

The two Rashomon-width rows are an example: −0.370 / +0.879 became −0.370 /
+0.858.

**Unchanged.** 328 registered numbers, including the MCR lower bound of the
disadvantage group (8.5%, or 1.0848 as a ratio). It is the same on v1 and v2.

## 5. Verify

- **Exit status.** The run exited 0 and no stage was skipped (sec 1).
- **Attribution.** Every changed number traces to a task in the task sheet
  (sec 4; the script enforces it).
- **Reproduction, beyond the task's requirement.** The cold run reproduces
  every registered number of the warm state byte for byte (sec 3).

## 6. Follow-ups

- **Stage-43 and stage-45 cold cost.** Both stages `sys.source()` `06-mcr.R`,
  which re-runs its full validation (about 21 minutes) on every cold load,
  and stage 35 does the same. A flag that skips the validation when the file
  is sourced for its functions would save about an hour per cold release
  without weakening stage 29, which still runs it.
- **The clone.** `release-s4.1/` (817 MB with its outputs) is outside the
  repository and untracked. It can be deleted once S5.5's release run has
  replaced it.
- **The S5.5 rerun.** It needs no `--cold`. Stage 39's prose checks are the
  only thing outstanding, and they run in seconds.
