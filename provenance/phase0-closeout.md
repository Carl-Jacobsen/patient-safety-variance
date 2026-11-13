# Phase 0 closeout

**Date:** 2026-08-26
**Budget:** 8 hours, 6 tasks
**Result:** **6 of 6 tasks complete.** Phase 0 is closed. One follow-on item (ADI
registration) remains and blocks only Tasks 1.4 and 2.5.

> **UPDATED 2026-08-26, later the same day.** Carl supplied the Task 0.1 answers, and
> three questions he raised prompted further measurement. All of it is propagated in
> **`plan-amendments.md`**, and the task sheet is reissued as
> **`Variance Project - Tasks (rev 3).md`**. Read those with this one — §3 below is
> superseded where they disagree.
>
> Headlines: the composite's reliability shrinkage is now quantified (median λ = 0.462,
> r = +0.93 with volume, rural 0.304 vs urban 0.520); HSAF suppression was tested
> directly and does **not** materially bias the catchment covariates (r ≥ 0.986), but
> county-grain weighting is near-redundant so the base grain moves to ZIP→tract; the
> Gate C2 imputation hierarchy is reversed to MI-primary (amendment A1); MCR is scoped
> away from Block C; and plan §12's third cut line — the component PSI analyses — is
> **withdrawn permanently**, because with no O/E split they are the only lightly-smoothed
> outcome.
>
> On scope: rev 2 cut Phase 4 and the archetype tasks against a 201-hour ceiling.
> **That ceiling was wrong** — the contract runs to **2026-10-15**, and the plan's hour
> estimates assume unassisted solo work. **Rev 3 reinstates every time-driven cut.**
> Phase 1 readiness is audited separately in `phase1-readiness.md`: **ready to start.**

---

## 1. Task status

| Task | Output | Status |
|---|---|---|
| 0.1 Settle engagement terms | engagement record (not published) | **Complete.** Answers recorded 2026-08-26 |
| 0.2 Outcome-layer access spike | `spike-outcome.md` | **Complete** |
| 0.3 Block A and Block C source spike | `spike-structure.md` | **Complete** |
| 0.4 Block B and catchment source spike | `spike-context.md` | **Complete except ADI registration** |
| 0.5 Open the enrichment track | `enrichment-track.md` | **Specified; two actions require Carl** |
| 0.6 Write the admission gates | `admission-gates.md` | **Complete** |

All numbers regenerate from `provenance/phase0-numbers.R` (base R, relative paths, no
packages, runs before `renv` exists). Task 1.1 folds it into `make.R`.

Raw files archived unedited with sha256 at `data-raw/spike-phase0/` (144 MB, 13 files).

## 2. Phase 0's closing condition, checked

> *"Phase 0 closes when: compensation is resolved, every Block A and Block B source is
> confirmed or substituted, and the gates are numeric and dated."*

| Condition | Met? |
|---|---|
| Compensation resolved | **Yes** — same structure as the first project, through 2026-10-12 |
| Every Block A source confirmed or substituted | **Yes.** 10 of 10 covariates at ≥99% coverage; RAND substituted out |
| Every Block B source confirmed or substituted | **8 of 9.** ADI blocked on registration |
| Gates numeric and dated | **Yes.** 22 gates across 5 groups, every predicate script-evaluable, dated 2026-08-26, committed before any model was fitted |

## 3. What Phase 0 changed about the plan

Four findings alter downstream work. None of them changes the project's viability.

**a. There is no observed-vs-expected split, and none can be reconstructed.**
`spike-outcome.md` §5. CMS publishes the PSI-90 composite as a weighted average of
reliability-adjusted component ratios and publishes neither the observed numerator nor
the expected rate. Shrinkage is volume-dependent, volume correlates with the Block A
and Block B covariates the study is about, and the result is covariate-correlated
attenuation in the composite. **Consequence:** the component models are promoted from
robustness check to structural — they are how the study measures what smoothing
conceals. Outcome definition becomes a live axis in the Phase 3 specification space,
and two cheap mitigations (denominator weighting on components, CI width as a
reliability proxy on the composite) are specified.

**b. The Hospital Service Area File suppresses 87.46% of its cells.**
`spike-context.md` §2. Plan §4 says the Service Area File closes the
geographic-attribution problem "at no cost." **That sentence should be revised.** It
closes it at a measured cost: for the median hospital the catchment weights are a
discharge-weighted average over roughly 83% of catchment cases, 130 hospitals (4.64%)
need a county fallback, and 52 have no observed ZIP cell at all. The weighting remains
defensible — the median hospital's weight is 81% determined by its ten largest,
well-observed ZIPs — but the report must describe it in those terms. Gate B0 commits
the thresholds in advance, which was the only way to keep them honest.

**c. The sample frame is n = 2,801, and 107 VA hospitals must be excluded explicitly.**
`spike-outcome.md` §7. They carry a published PSI-90 but are not subsection (d) IPPS
hospitals and would otherwise vanish silently at the Block A join, violating standing
rule 4. Separately, listwise deletion across the four named components costs 507
hospitals (18.1%), and they are systematically low-volume — correlated with rurality,
and therefore with Block B. Gate O1.d forces that to be a decision rather than a
default.

**d. Contract-labor missingness is differential.**
`spike-structure.md` §4 and `admission-gates.md` §3. The variable populates 90.7% of
the frame, but the missing 9.2% are smaller (standardized difference +0.462 on beds)
and more rural (−0.269). Blanks cannot be imputed to zero. The covariate is admitted
only with a missingness indicator, only alongside a multiple-imputation and an
omitted-variable specification, and no MCR importance claim may rest on it unless it
holds across all three.

Two smaller changes: **RAND Hospital Data is substituted out** (paywalled; the CMS
Hospital Provider Cost Report PUF covers 99.9% of the frame and already exposes the
S-3 contract labor line), which removes a paid dependency from the critical path; and
**`EP_UNINSUR` and `EP_LIMENG` come from inside the SVI file**, removing two ACS pulls
from Task 1.4 and one source of vintage mismatch.

One addition to the plan's source list: the **FY 2026 HAC Reduction Program file**
supplies each hospital's Total HAC Score and actual penalty status (719 of 3,055
penalised). Phase 4's payment-impact Monte Carlo can be calibrated against an observed
penalty distribution rather than a synthetic one.

## 4. Open items

| # | Item | Owner | Blocks |
|---|---|---|---|
| 1 | ~~Settle engagement terms~~ **CLOSED 2026-08-26.** | — | — |
| 1b | **Request calendar slots for the 6.4 and 6.5 review meetings — this week** | **Carl** | Phase 6; unrecoverable if it slips |
| 2 | Register at the Neighborhood Atlas and download ADI; record the turnaround | **Carl** | Tasks 1.4 and 2.5 only |
| 3 | Complete HCUP DUA training and sign the DUA | **Carl** | nothing — parallel track |
| 4 | Ask JHF whether it holds an AHA Annual Survey licence | **Carl** | nothing — parallel track |
| 5 | CMS PSI software version for FY 2026 | either | nothing; interpretation only |
| 6 | Confirm the snapshot-date explanation for the HACRP / Care Compare PSI-90 divergence | either | nothing |
| 7 | Verify County Health Rankings licence terms for JHF's intended distribution | either | Task 1.7 |

Items 2, 3, and 4 are registrations, trainings, and correspondence — actions taken
under Carl's own name, not mine. Items 5 and 6 both resolve through the QualityNet
Question & Answer Tool or a Hospital-Specific Report cover page.

## 5. Hours

Phase 0 was budgeted at 8 hours. The work above corresponds to that scope, with the
S-3 population rate, the CMI drift series, and the HSAF suppression measurement all
computed rather than estimated, plus a regeneration script that was not in the budget
and that Task 1.1 now inherits rather than writes.

## 6. Next

Phase 1 (22 h, 7 tasks) starts at Task 1.1, which depends on Task 0.1 — open item 1.
Tasks 1.3 and 1.6 depend on 0.3, and 1.4 and 1.5 on 0.4; those dependencies are now
cleared, with ADI the single exception inside 1.4.

The task sheet marks a fresh session here.
