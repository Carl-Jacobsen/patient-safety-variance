# Task 1.6 — Acquire Block C candidates

**Date:** 2026-08-27 · **Budget:** 5 h · **Status: complete.** One new download, one
relocation, and the deterministic recovery that Task 1.6 exists for: contract-labour
population **90.7% → 95.1%** with observed values, no imputation.

Acquisition only — no admission judgment here. Gates C1, C2, C3 run at Task 2.7.

---

## 1. What Block C is, and where it already was

| Covariate | Source | Status coming into 1.6 |
|---|---|---|
| Coding / surveillance intensity | `TACMIV42` from the **FY2025 and FY2026 IPPS Impact Files** | already on disk (`ipps_impact_fy2025`, `ipps_impact_fy2026`, Task 1.3) |
| Staffing instability | `Contract Labor: Direct Patient Care` ÷ `Total Salaries (adjusted)` | curated PUF on disk (`hcris_puf_fy2023`), 90.7% — **raised here** |
| — cross-year fill | FY2022 PUF | already on disk (`hcris_puf_fy2022`, Task 1.3) |
| — raw recovery | **raw HCRIS Worksheet S-3 Part II** | **new download, `HOSP10FY2023.zip`, 137 MB** |
| State tort environment | Database of State Tort Law Reforms 7.1 (Avraham) | on disk in `spike-phase0/` — **relocated** to `data-raw/blockC/` |

So the only genuinely new acquisition is the raw HCRIS archive. Everything else is a
relocation or a cross-reference to a file an earlier task already fetched and hashed.

## 2. Coding intensity — confirmed, both vintages present

`TACMIV42` is in both Impact Files, which is the whole point: differencing the **same
field** across the FY2023 and FY2024 MedPAR years holds the DRG grouper version
constant. Stage 10 preview (gate C1 runs at 2.7):

| | value | spike baseline |
|---|---|---|
| level coverage (FY2025 file) | 99.9% | 100.0% |
| relative-drift coverage | 99.8% | 99.8% |
| drift median / SD | −0.0050 / 0.0527 | −0.0050 / 0.0527 |

Reproduces `spike-structure.md` §6 to the digit.

## 3. Tort environment — relocated, structure confirmed

`dstlr-7.1.xlsx` moved `spike-phase0/ → blockC/`, recorded in `relocations.csv`; stage 1
reads it through a compatibility symlink. sha256 unchanged (`907cdd75…`).

Sheets `READ ME | DATA | Sheet1 | Sheet3`; DATA is 2,142 × 49, one row per state-year,
51 states, 51 rows in the terminal year **2021**.

**Parse trap:** a nominally numeric column carries the text value `'1890s'` deep in the
sheet, so `read_excel` widens it and column-type inference is unreliable. Task 2.7 must
read the DATA sheet as character and coerce per column.

## 4. Staffing instability — the recovery

**Standing rule 7 / README rule 7: recover before imputing.** The 90.7% figure is the
coverage of CMS's *curated* PUF, not of HCRIS. Three sources, applied in order of
evidential quality:

| `contract_labor_source` | n | % of frame | what it is |
|---|---|---|---|
| `puf_fy2023` | 2,541 | 90.7% | the curated FY2023 PUF value |
| `raw_s3_fy2023` | 47 | 1.7% | raw HCRIS Worksheet S-3 Part II, line 11 col 4 — a **FY2023 observed** value the PUF dropped |
| `puf_fy2022` | 75 | 2.7% | prior-year observed value; contract-labour share is persistent year to year |
| `missing` | 138 | 4.9% | absent in both years and both sources — genuinely missing |

**Population rate: 90.7% → 95.1%** (+122 hospitals). Contract-labour *share* computable
(value present **and** `Total Salaries (adjusted) ≥ $1M`): **95.0%** — the one-hospital
gap is CCN 170194, the broken record `spike-structure.md` §4 already identified
(`Total Salaries (adjusted)` = $1).

### Why raw S-3 is trustworthy here

Where the PUF and raw HCRIS both carry a value (2,530 hospitals), they agree to
**median |relative difference| 0.00000** — the PUF field *is* S-3 Part II line 11,
column 4. Raw S-3 simply has the line for more hospitals: **2,577** of the frame versus
the PUF's 2,541. The 47 recovered values are the same measurement, not a proxy.

The raw archive earns its 137 MB (`phase1-readiness.md` §6.3 timebox: keep it only if it
beats the PUF). It does — by 47 hospitals directly, and it is what makes the remaining
138 *genuinely* missing rather than an artifact of PUF curation.

### The 138 that remain

They go to **multiple imputation at Task 2.7** under the MAR justification in
`admission-gates.md` amendment A1 — never to a zero floor, because `spike-structure.md`
§4 established there are no true zeros in this field and a blank cannot be told apart
from "used no contract labour."

## 5. Files, provenance, output

```
data-raw/blockC/HOSP10FY2023.zip     136.6 MB   NEW   (hcris_raw_hosp10_fy2023)
data-raw/blockC/dstlr-7.1.xlsx          0.4 MB   moved from spike-phase0/   (dstlr_7_1)
data/blockC_contract_labor.csv         2,801 rows, rebuilt by stage 10 each run
```

`data/blockC_contract_labor.csv` columns: `ccn`, `contract_labor`, `total_salaries`,
`contract_labor_share`, `contract_labor_source`. It is a build product, not frozen —
Task 2.7 consumes it, Task 2.8 freezes the analytic file that incorporates it.

`sources.csv`: +2 rows → **31**. `relocations.csv`: +1. `make.R`: **stage 10**, logging
to `output/tables/task1.6-blockC.txt`.

### Raw HCRIS parse notes (for Task 2.7)

- Three headerless members. `HOSP10_2023_rpt.csv` (6,109 rows): `V1` = `RPT_REC_NUM`,
  `V3` = 6-digit CCN (character), `V6`/`V7` = fiscal period begin/end (`m/d/Y`).
- `HOSP10_2023_nmrc.csv` (~24M rows, 677 MB): `RPT_REC_NUM, WKSHT_CD, LINE_NUM,
  CLMN_NUM, ITM_VAL_NUM`. `LINE_NUM`/`CLMN_NUM` are zero-padded 5-char (`01100`,
  `00400`). **Prefilter on `WKSHT_CD` — never read it whole.**
- Worksheet S-3 Part II = `S300002`. Line `01100` col `00400` = Contract Labor: Direct
  Patient Care; line `00100` col `00400` = Total Salaries (adjusted); col `00200` is a
  near-duplicate fallback.
- **62 CCNs file more than one report** — this stage takes a field's value from the
  CCN's best report: a non-blank value first, then longest fiscal period, then latest
  period end (10 of the 62 have contract labour blank in some FY2023 reports but not
  others). Revisit the report-selection rule at Task 2.3.

## 6. Next

**Task 1.7** — close the provenance table: complete every row and run the re-download
test (hand `sources.csv` to a fresh session, retrieve one file per source from the
recorded information alone). That closes Phase 1.
