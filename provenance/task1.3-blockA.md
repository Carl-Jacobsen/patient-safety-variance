# Task 1.3 — Acquire Block A (hospital structure)

**Date:** 2026-08-27 · **Budget:** 3 h · **Status: complete, and the verify condition
does not fully pass.** 8 of the 10 plan §4 covariates clear 99%; two do not, for reasons
that are structural rather than retrieval failures. Details in §4 and §5 — that is the
substantive content of this task.

---

## 1. What was acquired

Seven files into `data-raw/blockA/`, by two retrieval routes.

| `source_id` | Route | Role |
|---|---|---|
| `ipps_impact_fy2026` | static cms.gov ZIP | payment-policy and structural fields |
| `ipps_impact_fy2025` | static cms.gov ZIP | **case mix and volume** — its MedPAR year sits inside the PSI window |
| `hcris_puf_fy2023` | data.cms.gov catalogue | margin, uncompensated care, occupancy, the S-3 contract-labour line |
| `hcris_puf_fy2022` | data.cms.gov catalogue | measures the cross-year recovery ceiling (§5); also a Task 1.6 input |
| `pos_q2_2026` | data.cms.gov catalogue | identifier fallback **only** — see §4 |
| `hosp_enrollments` | data.cms.gov catalogue | system membership, part 1 |
| `hosp_all_owners` | data.cms.gov catalogue | system membership, part 2 |

The two publishers need two routes. `www.cms.gov` serves the Impact Files at stable
static URLs. `data.cms.gov` puts a dated release path in every file URL, so the durable
recipe is its DCAT catalogue — `https://data.cms.gov/data.json`, match the dataset title,
take the distribution's `downloadURL`. `retrieval_method` gains **`catalog API`** to
distinguish it from the Provider Data Catalog's metastore used at Task 1.2. The DCAT
records also state a licence explicitly — `https://www.usa.gov/government-works` — which
the PDC metastore does not.

Match rates against the frame, with the misses named rather than counted (standing
rule 4):

| Source | Matched | Unmatched CCNs |
|---|---|---|
| FY 2026 Impact | 2,799 / 2,801 (99.9%) | `010062`, `050350` |
| FY 2025 Impact | 2,798 / 2,801 (99.9%) | `050855`, `060133`, `250036` |
| HCRIS PUF FY 2023 | 2,798 / 2,801 (99.9%) | `050855`, `060133`, `420101` |

62 CCNs file more than one FY 2023 cost report — deduplicate deliberately at Task 2.3,
never by taking the first row.

## 2. The vintage decision, made and measured

`phase1-readiness.md` §6.1 flagged this as a choice that would get attacked if made by
default. It is made explicitly:

- **FY 2025 Impact File (Correction Notice)** → case mix (`TACMIV42`) and volume
  (`Bills`). Built on FY 2023 MedPAR, which sits inside the PSI window near its midpoint.
- **FY 2026 Impact File (Final Rule)** → payment-policy and structural fields. Built on
  FY 2024 MedPAR, which overlaps only the window's last quarter.

The two vintages are close but not identical, which is exactly why the choice is carried
into Phase 3 as a specification axis rather than buried: `TACMIV42` correlates 0.9708
across vintages (median 1.717 vs 1.706), `Bills` correlates 0.9966 (median 1,573 vs
1,551).

The FY 2025 ZIP holds **three** vintages. The Correction Notice member is the right one;
the Final Rule and Interim Final Action members are superseded and are a live trap for
anyone re-running this.

## 3. The gate

Every plan §4 Block A covariate, measured against the frame of 2,801:

| Covariate | Source | Coverage | |
|---|---|---|---|
| Beds | Impact FY2026 `Beds` | 99.93% | PASS |
| Ownership | Impact FY2026 `Ownership Control Type` | 99.93% | PASS |
| Teaching intensity | Impact FY2026 `Resident to Bed Ratio` | 99.93% | PASS |
| Case mix index | Impact FY2025 `TACMIV42` | 99.89% | PASS |
| DSH percentage | Impact FY2026 `DSHPCT` | 99.93% | PASS |
| Wage index | Impact FY2026 `FY 2026 Wage Index` | 99.93% | PASS |
| **System membership** | Enrollments + All Owners | **98.71%** | **BELOW GATE** |
| Occupancy | Impact FY2026 ADC ÷ Beds | 99.93% | PASS |
| Operating margin | HCRIS revenue and expense | 99.21% | PASS |
| **Uncompensated care burden** | HCRIS `Cost of Uncompensated Care` | **97.97%** | **BELOW GATE** |

**8 of 10.** Phase 0 recorded "10 of 10 covariates at ≥99% coverage." That count was
taken over the Impact File's fields; it did not include system membership, which no
Phase 0 source had been tested for, and it rounded 98.1% up. The corrected count is
above.

## 4. System membership: the plan's source is empty, and the substitute is 98.71%

Plan §4 assigns system membership to the Provider of Services file. **It cannot carry
it.** In the Q2 2026 release, `MLT_FAC_ORG_NAME` and `MLT_OWND_FAC_ORG_SW` are blank for
**every one of 44,707 rows**, as is `CHOW_SW`. This is measured in the stage output, not
inferred. POS is retained as the identifier fallback — it matches 100% of the frame on
`PRVDR_NUM` — but it is not a Block A data source.

The substitute is the **Hospital Enrollments** / **Hospital All Owners** pair, joined on
`ENROLLMENT ID`. It behaves correctly: 1,880 distinct owner organisations, 709 of them
spanning more than one frame hospital, HCA at the top with 141.

Two things about the coverage number:

- The binding constraint is the identifier join. 36 frame hospitals are **absent from
  Hospital Enrollments entirely** — not a CCN-format problem, since none of the 36
  appears in the file's raw CCN column in any form. Their CCNs are ragged in that file
  generally (934 five-character, 77 with an `A` or numeric suffix), and the parse fixes
  that; these 36 are simply not there.
- Of the 2,765 with an owner record, 2,407 (85.9%) have an *organisational* owner. **The
  remaining 358 are not missing data.** They are hospitals genuinely owned by
  individuals rather than an organisation, which is a substantive value of the variable.
  Conflating the two would be the same error as imputing blank contract labour to zero.

Group on `ASSOCIATE ID - OWNER`, never on owner name: HCA alone appears as `HCA INC`,
`HCA HEALTHCARE INC`, `HEALTHTRUST INC`, `HERCULES HOLDING II`, and `FRISCO HOLDING II`.

**Escalation, if 98.71% is judged insufficient:** the AHA Annual Survey is the canonical
system-membership source and is licence-gated — that is open item 4 on the enrichment
track, and this is the first task that gives it a concrete value. Worth asking JHF now
rather than at Phase 2.

## 5. Uncompensated care cannot reach 99%, and that is now measured rather than assumed

Standing rule 7 says recover before imputing, so the question is not whether to impute
but where recovery runs out. Measured against the FY 2022 PUF:

| | |
|---|---|
| `Cost of Uncompensated Care`, FY 2023 only | 97.97% |
| plus FY 2022 cross-year fill | 98.29% (**+9 hospitals**) |
| plus the broader `Total Unreimbursed and Uncompensated Care`, either year | **98.43% — the ceiling** |

Nine hospitals. The shortfall is not a retrieval failure and no further acquisition will
close it. Operating margin behaves better: 99.21% → 99.50% with cross-year fill, so it
clears the gate either way.

**This is a decision for Task 2.6, not a reason to wait**, and it should follow the
contract-labour template already written into `admission-gates.md` §3: admit with a
missingness indicator, alongside a multiple-imputation and an omitted-variable
specification, and let no importance claim rest on the covariate unless it holds across
all three.

## 6. Parse traps, exercised rather than described

Every one of these is in `sources.csv` under `parse_notes`, and each is executed by
stage 5 rather than asserted:

- Impact File `.txt` is **latin-1** with its **header on line 2** and a ragged tail
- FY 2025 ZIP holds three vintages; only the **Correction Notice** is correct
- Cost Report PUF: **62 CCNs with more than one report**; non-reporting is **blank, never
  zero**
- POS is **latin-1** — `FAC_NAME` aborts a UTF-8 read
- Hospital All Owners is **latin-1** too
- Hospital Enrollments CCNs are **ragged**: widths 5 to 9, needing a leading zero or a
  truncation
- CCNs are character everywhere, leading zeros significant

## 7. Verification actually performed

| Check | Result |
|---|---|
| `Rscript make.R`, working tree | 6 stages **ok**, 13 files hash-verified |
| Block A gate | **8 of 10** at ≥99%; two below, both quantified |
| Phase 0 stages after the Block A move | unchanged — frame 2,801, VA 107, S-3 population 90.7%, median λ 0.462 |
| Fresh `git clone`, empty `data-raw/` | stages 2 and 4 re-downloaded all 13 files; **every sha256 matches `sources.csv`** |
| Fresh clone, stage 5 | output **byte-identical** to the working-tree run |
| `shasum -c` on every `data-raw/*/MANIFEST.sha256` | 0 failures |

## 8. Open items this touched

- **Open item 4 (AHA Annual Survey licence)** now has a concrete stake: it is the
  escalation route for system membership at 98.71%. Worth asking JHF this week.
- Uncompensated care's 98.43% ceiling is new information for **Task 2.6** and for gate
  design; `admission-gates.md` has no gate for this covariate yet and should get one.
- `hcris_puf_fy2022` is recorded once, here, though Task 1.6 also lists it.

## 9. Next

**Task 1.5** (Hospital Service Area File) is unblocked and independent. **Task 1.4**
(Block B) is unblocked except for the ADI column, which still waits on Carl's
Neighborhood Atlas registration and the Census API key — neither of which blocks 1.5 or
1.6.
