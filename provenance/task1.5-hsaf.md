# Task 1.5 — Acquire the Hospital Service Area File

**Date:** 2026-08-27 · **Budget:** 0.5 h · **Status: complete. Both gates pass.**
Suppression reproduces at 87.46%; the Dartmouth crosswalk covers 99.99% of observed
frame Medicare cases.

Most of this task was done in Phase 0. The work here is: move the HSAF into the
permanent layout, add the one genuinely new source (the Dartmouth crosswalk), and
re-run the suppression measurement as a stage of `make.R` rather than a one-off script.

---

## 1. What was acquired

| `source_id` | Route | Role |
|---|---|---|
| `hsaf_2023` | data.cms.gov DCAT catalogue | **the catchment engine input** — hospital × patient-ZIP Medicare discharge counts, CY centred on the PSI midpoint |
| `hsaf_2024` | data.cms.gov DCAT catalogue | **diagnostic only** — stage 1b's cross-vintage suppression-recovery test reads it; not an analytic input |
| `dartmouth_ziphsahrr19` | static publisher URL | **suppression-free robustness column at Task 2.5** — ZIP→HSA/HRR by plurality of Medicare admissions |

Both HSAF files were downloaded and hashed in Phase 0 (`data-raw/spike-phase0/`). Task
1.5 moves them to `data-raw/hsaf/` and records the move in `provenance/relocations.csv`,
so the ported Phase 0 drivers (stages 1 and 1b) keep reading them through a
compatibility symlink and their numbers keep regenerating. The sha256s are unchanged —
`0482a469…` for 2023, matching what `spike-context.md` §2 recorded.

### The HSAF retrieval route

`spike-context.md` recorded a direct file URL. That URL carries a dated release-path
segment (`…/2024-07/88791b91-…/`) that rotates on each CMS refresh, so it is a snapshot,
not a recipe. The durable route is the same DCAT catalogue Block A uses:
`https://data.cms.gov/data.json` → dataset title **"Hospital Service Area"** → the
distribution whose `downloadURL` filename ends in the wanted calendar year. One
distribution per year, CY 2015 through CY 2025. `retrieval_method` = `catalog API`.

### The Dartmouth crosswalk

`https://data.dartmouthatlas.org/downloads/geography/ZipHsaHrr19.csv.zip`, linked from
the Atlas's [supplemental data page](https://data.dartmouthatlas.org/supplemental/)
under "ZIP Code Crosswalks". **2019 is the most recent edition** — the Atlas has not
published a newer one. Free, no registration. The `.zip` holds `ZipHsaHrr19.csv` plus a
`__MACOSX/._ZipHsaHrr19.csv` resource fork to ignore. A fresh `download.file()` of this
URL reproduces the recorded sha256 exactly.

Why it earns its 2 hours (`plan-amendments.md` §2.3): it is a **genuinely independent
construction** of the catchment. The weighted engine renormalises over the 13% of cells
that survive suppression; the Dartmouth file never had suppression to begin with,
because it publishes no cell counts — just one HSA per ZIP, assigned by plurality. If
the weighted result and the Dartmouth-assigned result agree, the suppression handling is
not driving the finding. That comparison is built at Task 2.5.

---

## 2. Gate 1.5a — suppression reproduces at 87.46%

`R/acquire-hsaf.R` re-measures on the relocated file and reproduces Phase 0 exactly:

| Quantity | Value |
|---|---|
| Rows, raw file / after `read_hsaf()` | 1,139,666 / 1,139,665 |
| Suppressed `TOTAL_CASES` cells | **996,700 of 1,139,665 = 87.46%** via `read_hsaf()`; the raw file counts 996,701 / 1,139,666 |
| Minimum non-suppressed `TOTAL_CASES` | **11** — threshold confirmed |
| Frame hospitals present | 2,799 / 2,801 (99.93%) |

The 1-row / 1-cell gap is the **Ctrl-Z EOF row**, now removed by the shared reader (§4).
Phase 0's `spike-context.md` reported 996,701 because it read the raw file; both round
to 87.46% and the gate passes on either.

The cost of that 87% is not 87% of the analysis. `plan-amendments.md` §2.3 established
that suppressed cells hold ~1–3 cases each, so they account for roughly **17% of
Medicare cases**, and stage 1b's decisive test showed the catchment-weighted SVI
covariate moves by `r ≥ 0.986` whether suppressed cells are imputed or dropped. The
suppression is real but it is not a severe bias. This is Task 2.4's problem to handle,
not Task 1.5's to solve.

---

## 3. Gate 1.5b — Dartmouth covers the frame

| Quantity | Value |
|---|---|
| Crosswalk rows | 40,866 — one per ZIP, no duplicates (plurality assignment) |
| ZIP format | 5-digit character, leading zeros significant |
| Distinct HSAs / HRRs | 3,436 / 306 |
| Distinct frame patient-ZIPs found in the crosswalk | 98.93% |
| **Observed-case-weighted coverage** | **99.99%** |
| Frame hospitals with ≥ 1 resolvable ZIP | 2,799 / 2,799 |
| Observed Medicare cases in unmatched frame ZIPs | 1,099 of 11,880,416 (0.009%) |

The unmatched ZIPs are blank, `00000`, or Puerto Rico / territory ZIPs the Atlas does
not cover. At 0.009% of observed cases this is a rounding error.

---

## 4. Parse traps

Confirmed against the delivered file, and one is new:

- **Suppression is a literal `*`**, space-padded to the field width (10 chars in
  `TOTAL_DAYS_OF_CARE` and `TOTAL_CHARGES`) — not blank, not `NA`. Parse the numeric
  columns as character, then convert.
- **The file's final line is a lone Ctrl-Z (`0x1A`) DOS EOF marker**, which `read.csv`
  turns into a junk final data row: `MEDICARE_PROV_NUM = "\032"`, every other field
  empty. `spike-context.md` §2 called this a "trailing empty line" — it is not; it is a
  control character, and it is the one row that `is.na(TOTAL_CASES)` counts beyond a
  literal `*` match. **Fixed:** `R/hsaf.R::read_hsaf()` is now the canonical HSAF reader
  — it drops the Ctrl-Z row (and any fully-empty row) and every reader from Task 2.4 on
  goes through it. The ported Phase 0 drivers (stages 1 and 1b) keep their raw
  `read.csv` on purpose: their job is to reproduce Phase 0's numbers, EOF row included.
- **Non-IPPS provider numbers are present** — 1,685 of the 7,607 distinct provider
  numbers are alphanumeric (e.g. `01S007`). Filter to the frame; do not assume every
  row is a hospital.
- **949 rows carry a blank `ZIP_CD_OF_RESIDENCE`** file-wide, 797 of them for frame
  hospitals. These are unallocated Medicare residence records; they cannot be catchment-
  weighted and drop out of the ZIP join.

The two frame hospitals absent from HSAF 2023 — `050855` Kaiser San Marcos and `060133`
St Francis Interquest — are the same two absent from the FY 2025 Impact File and the
FY 2023 HCRIS PUF. Both opened in 2023 with no Medicare claims history yet. Recorded,
not silently dropped (standing rule 4); they will need a catchment fallback at Task 2.4.

---

## 5. Files and provenance

```
data-raw/hsaf/Hospital_Service_Area_2023.csv     44.5 MB   (moved from spike-phase0/)
data-raw/hsaf/Hospital_Service_Area_2024.csv     27.0 MB   (moved from spike-phase0/)
data-raw/dartmouth/ZipHsaHrr19.csv.zip            0.2 MB   (new)
```

`provenance/sources.csv` gains three rows (`hsaf_2023`, `hsaf_2024`,
`dartmouth_ziphsahrr19`), bringing it to 29. `provenance/relocations.csv` gains two.
`make.R` gains **stage 9**, logging to `output/tables/task1.5-hsaf.txt`. New helper
`R/hsaf.R` (`read_hsaf()`) — the canonical HSAF reader, used by stage 9 and every
Phase 2 reader.

Full `make.R` run: all ten stages `ok`, provenance `consistent`.

---

## 6. Next

**Task 1.6** (Block C candidates — raw HCRIS S-3, cross-year cost reports, tort reform
DB) is the last Phase 1 acquisition. **Task 1.7** then closes the provenance table with
the re-download test.
