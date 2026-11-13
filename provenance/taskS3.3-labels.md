# Task S3.3 — Fix the labels and the timing of hospital characteristics

**Date:** 2026-10-05 · **Budget:** 1.5 h · **Status: done. Stage 45,
post-review.** Three things.
1. **Names.** Each block name now refers to one set only. The community block is
   all eleven Block B measures; the disadvantage group is the ten without
   market concentration. ADI is labelled a catchment average of block-group
   ranks.
2. **Ownership and system membership.** Adding them to Block A barely moves the
   disadvantage results. It does improve the fit, by 1.26% of loss at both
   anchors, almost all through system membership (−0.047 PSI-90, about five
   standard errors). The structure block left out a predictor that matters,
   though not one that changes what the report says about disadvantage.
3. **Timing.** Of the hospital characteristics, case mix, volume, the cost-report
   finances, contract labor and case-mix drift fall inside the July 2022 to
   June 2024 outcome window. The payment-policy fields are later values, and
   system membership is a 2026 snapshot.

---

## 1. Names: one set each

The glossary entries are in `report/glossary.md`. S5 folds them into the
supplement's glossary. The file is not a numbered section, so the report
build skips it, while stage 39's claim guard still reads it.

| Name | Set | Used for |
|---|---|---|
| **Community block** (Block B) | all eleven: SVI 1–4, ADI, ICE, uninsured, limited English, rurality, primary-care density, market concentration | variance-decomposition community share; "with/without Block B"; S3.2's community contribution |
| **Disadvantage group** | the ten without market concentration | MCR on disadvantage; the p10 → p90 contrast; per-measure reliance and TIS; model-implied disadvantage (`v_B` in stage 35 uses `DIS`, checked) |

**Changed in generated figures and text** (no numbers moved; the six stage 22,
28 and 30 tables are byte-identical before and after):

| Where | Was | Now |
|---|---|---|
| Fig 2 row label | "Community disadvantage (Block B)" | "Community (Block B)"; the caption names the block's contents |
| Fig 3 title | "Community disadvantage and PSI outcomes …" | "The ten-measure disadvantage contrast …" |
| Fig 4 panel A | "Community disadvantage (primary)", "Disadvantage block, all 10" | "Disadvantage group (primary)", "Disadvantage group, all 10" |
| Fig 4 HHI row | "HHI (outside the block)", which was wrong: HHI is in the block | "HHI (outside the group)" |
| Figs 4 / 5 / 7 / 8, ADI | "ADI", "ADI quintile", "catchment ADI" | "ADI, mean block-group rank", "ADI rank", "Catchment ADI quintile", "catchment ADI (mean BG rank)"; captions for figs 4, 5, 7 and 8 state the definition |
| `report/figures.csv`, figs 2, 3, 4 | "community disadvantage", "disadvantage and structure blocks" | community block / disadvantage group |
| Stage 22 statement | "Community disadvantage (Block B) is associated with …" | "The community block (Block B: the ten disadvantage and access measures and market concentration) …" |
| Stage 30 log | "BLOCK B -- community disadvantage"; "relies on community disadvantage" | "the ten-measure disadvantage group" |
| Stage 28 log | "no community disadvantage at all" | "no community block at all" |

The longer labels were checked in the rendered PNGs. Three overflowed (fig 2's
row label, fig 4's panel header, fig 7's panel title) and were shortened, with
the definition moved to the caption.

**Left as is:**
- Stage 32's log title ("TIS: shared attribution across community
  disadvantage"). Editing `07-tis-run.R` invalidates the TIS cache and its
  bootstrap (both key on the script) for one word in a supplement-only log.
  S4's release rerun is the time to change it if S5 wants the log quoted.
- Table keys `blockB_disadvantage` (MCR) and `B disadvantage` (coefficient
  ranges) already mean the ten-measure group.

## 2. The ownership sensitivity (stage 45)

Fixed in `second-pass-preregistration.md` amendment 2 (commit bbe5601) before
any model with either field was fitted.
- **Anchors:** P-best (382) and P-median (610).
- **Added terms:** government and proprietary indicators, with voluntary
  nonprofit as the reference, and a system-membership indicator, all added to
  Block A.
- **Unchanged:** everything else.
- **Check first:** both anchors as fitted reproduce their stored loss (1e-10),
  contrast (1e-8) and disadvantage-group MR (1e-9).

`R/19-ownership.R`, about 20 s, deterministic. Output
`output/tables/ownership-sensitivity.csv`.

| | P-best as fitted | + ownership, system | P-median as fitted | + ownership, system |
|---|---|---|---|---|
| loss (2,569 frame) | 0.032559 | 0.032149 (−1.26%) | 0.032953 | 0.032536 (−1.27%) |
| joint contrast, SD (se) | −0.215 (0.202) | −0.240 (0.202) | +0.138 (0.174) | +0.096 (0.173) |
| community-block share (LMG) | 5.70% | 5.26% | 4.59% | 4.14% |
| structure share | 4.37% | 5.98% | 4.71% | 6.40% |
| disadvantage-group MR | 1.1268 | 1.1119 | 1.1347 | 1.1140 |
| government (vs nonprofit) | | −0.002 (0.013) | | −0.003 (0.012) |
| proprietary | | −0.012 (0.010) | | −0.015 (0.010) |
| system member | | **−0.047 (0.009)** | | **−0.048 (0.009)** |

Coefficients are in PSI-90 units; the published PSI-90 SD is 0.19, so system
membership is about 0.25 SD.

**Reading.**
- **The disadvantage findings hold.**
  - The contrast moves by 0.03–0.04 SD, about a fifth of its standard error,
    and keeps its sign at each anchor.
  - The community share falls by under half a point.
  - Reliance on the disadvantage group stays well above 1 (1.11 at both
    anchors).
- **The structure block was missing a real predictor.** System members have
  lower (better) PSI-90 by about 0.05 at both anchors. That improves the fit
  by 1.3%, roughly a third of the primary Rashomon tolerance (4.1% of the best
  model's loss).
  - A specification set with system membership in Block A would likely put
    these augmented models near the front of the set.
  - Its width and ERM were not recomputed, so that is not claimed.
  - Ownership itself adds little (both indicators are within 1.5 SE of zero).
- **Two limits on reading the system coefficient:**
  - System membership comes from a July 2026 snapshot (sec 3), so a hospital's
    affiliation during the outcome window may differ.
  - The 26 hospitals with no owner record are coded non-members in the frozen
    file.

  The association is not read as an effect of affiliation.

## 3. Timing of hospital characteristics

Outcome window: July 2022 to June 2024 (PSI-90, Care Compare). Periods are as
stated by each source; the Impact Files' own variable descriptions were read
for this table.

| Characteristic | Source | Period | Relative to window |
|---|---|---|---|
| Case mix index | FY 2025 IPPS Impact File (Correction Notice), TACMIV42 | FY 2023 MedPAR (Oct 2022–Sep 2023) | **inside** |
| Medicare volume | FY 2025 Impact File, BILLS | FY 2023 MedPAR | **inside** |
| Case-mix drift | TACMIV42, FY 2025 → FY 2026 files | FY 2023 → FY 2024 MedPAR (to Sep 2024) | **inside**, last quarter just after |
| Operating margin, uncompensated care | HCRIS cost reports, FY 2023 (FY 2022 for 9 hospitals) | hospital fiscal years in 2022–2023 | **inside** (the 9 fills partly before) |
| Contract-labor share | HCRIS FY 2023 (75 filled from FY 2022) | as above | **inside** (fills partly before) |
| Beds, average daily census, occupancy | FY 2026 Impact File | "most recent available cost report data (FYs 2022–2023)" | **partly before, mostly inside** |
| Ownership | FY 2026 Impact File, from cost report data | cost reports FY 2022–2023 | **partly before, mostly inside** |
| Residents per bed, teaching | FY 2026 Impact File, IME ratio | payment-year value for FY 2026; source year not stated per field | **after** (current) |
| DSH percentage | FY 2026 Impact File | March 2025 Provider Specific File Medicaid ratio and most recent SSI data | **after** |
| Wage index | FY 2026 Impact File | FY 2026 payment value | **after** |
| System membership | Hospital Enrollments and All Owners, 2026-07-31 | snapshot | **after** (current) |
| Tort reforms | DSTLR 7.1 | terminal year 2021 | **before** (2.5 years to the window's midpoint, gate C3.c) |
| Star rating (archetypes) | Hospital General Information in the Care Compare release used for PSI-90 | that release | concurrent release |

Most current values are payment-policy quantities (wage index, DSH, IME) that
move slowly. System membership and ownership can change through mergers and
acquisitions, and that is where a current value most plausibly differs from
the value during the window.

## 4. Verify

- **Tables and figures.** No table or figure uses "community block" for the
  disadvantage group or the reverse:
  - every figure label and caption that names a set was checked against
    sec 1's definitions;
  - every output table's text was scanned for "community" and "disadvantage
    block". `community_share` in `mnar-sensitivity.csv`,
    `ownership-sensitivity.csv` and `variance-decomposition.csv` is the
    community block's LMG share. The remaining hits are hospital names and
    Sep 30 report prose quoted in `claim-guard-hits.csv`.
- **Report prose (S5's job).** The draft's prose still says "community
  disadvantage" for both sets (for example sec 5's "Every credible model
  relies on community disadvantage", which is the disadvantage group). S5
  applies the glossary.

## 5. Stage 39

Stage 45's numbers are registered in section 09
(`own <anchor> <version> <quantity>`). Registry: 2,271. Unregistered counts
are unchanged from S3.2 (2 / 3 / 6 / 19 / 0 / 8 / 2 / 4 / 2).

## 6. Not done

- **Refit with the new Block A.** The specification set and Rashomon set were
  not refitted with ownership and system membership in Block A. If S5 wants
  to say whether the augmented models would lead the set, that is a full
  refit of the composite specifications and everything downstream of them.
- **Fig 8 subtitle.** It runs past the right edge. That predates this task
  (S1.6's text), so it is left for S5's figure pass.
