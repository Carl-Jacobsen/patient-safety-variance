# Task 2.6 — The missingness audit

**Date:** 2026-08-31 · **Budget:** 5 h (+1 by `plan-amendments.md` §3.4) ·
**Status: complete. This task does not get cut.**
30 analytic variables audited. **Every one of the 8 variables with substantive
missingness is both (a) differential with community disadvantage and (b)
predicted by fully observed covariates** — the textbook MAR case. Multiple
imputation is licensed for all 8; complete-case for none.

Outputs: `output/tables/missingness-audit.csv`, `output/figures/missingness-audit.png`,
and this interpretation.

---

## 1. The two questions, kept separate

| | question | goes to | how tested |
|---|---|---|---|
| **Q1** | Does missingness correlate with **disadvantage**? | report §9 **Limitations** | standardized difference of ADI / SVI-SES / ICE / uninsured (base-case `_catch_tract` grain) between hospitals with and without a value; \|SMD\| > 0.10 = differential |
| **Q2** | Is missingness predicted by **fully observed** covariates? | **licenses MI** at Task 2.7 | logistic `is.na(var) ~ log(beds) + rural + ownership + teaching + wage index + log(volume) + CMI + DSH% + occupancy`; likelihood-ratio test + McFadden pseudo-R² |

The fully-observed predictor set is the IPPS Impact File structural fields, all
≥ 99.8% observed for the frame (complete for 2,796 / 2,801). Q2 is the one that
matters for the imputation strategy: **missingness predicted by fully observed
covariates is MAR, where MI is unbiased and the missingness-indicator method is
biased even under MCAR** (`plan-amendments.md` §3.1, `admission-gates.md` C2.e as
amended). Where Q2 fails for a variable, MI is not licensed and it goes to
complete-case with the reason recorded.

---

## 2. The variables with substantive missingness (≥ 0.5% of the frame)

| variable | missing | SMD log(beds) | SMD rural | SMD ADI | Q1 differential? | MAR LR p | pseudo-R² | Q2 → disposition |
|---|---|---|---|---|---|---|---|---|
| `psi13` (postop sepsis) | 488 (17.4%) | +1.19 | −0.75 | −0.52 | **YES** | <1e-4 | 0.45 | **MI** |
| `contract_labor_share` | 139 (5.0%) | +0.68 | −0.20 | −0.00 | **YES** (SVI-SES −0.29) | <1e-4 | 0.14 | **MI** |
| `psi12` (periop PE/DVT) | 74 (2.6%) | +1.51 | −0.71 | −0.92 | **YES** | <1e-4 | 0.59 | **MI** |
| `hhi_zip` (market conc.) | 54 (1.9%) | +2.05 | +0.55 | +0.07 | **YES** (uninsured −0.42) | <1e-4 | 0.72 | **MI** |
| `uncompensated_care` | 48 (1.7%) | +0.32 | +0.05 | +0.30 | **YES** | 0.0015 | 0.06 | **MI** |
| `system_member` | 36 (1.3%) | +0.68 | −0.37 | −0.51 | **YES** | <1e-4 | 0.11 | **MI** |
| `psi03` (pressure ulcer) | 23 (0.8%) | +2.72 | +0.51 | +0.08 | **YES** (uninsured −0.40) | <1e-4 | 0.68 | **MI** |
| `operating_margin` | 19 (0.7%) | +0.46 | −0.13 | −0.17 | **YES** | <1e-4 | 0.34 | **MI** |

SMD sign: **positive = the value is higher among hospitals that HAVE it**. So
`+1.19` on `log(beds)` for `psi13` means the missing hospitals are much smaller;
`−0.75` on the rural indicator means they are more rural; `−0.52` on ADI means
they serve **more** disadvantaged communities (higher ADI). The SMDs on `psi03`
and `hhi_zip` are large in magnitude because only ~20–50 hospitals are missing
and they sit at the small-volume extreme.

**8 negligible-missingness variables** (`beds`, `occupancy`, `resident_to_bed`,
`dsh_pct`, `wage_index`, `cmi`, `volume_bills`, `ownership` — 2–3 hospitals each,
the two Impact-File-absent hospitals from Task 2.1) → complete-case, no material
effect at n = 2,801.

**14 fully observed variables** (`psi90`, `psi06`, `lambda_i`, and every Block B
`_catch_tract` covariate — svi1–4, uninsured, limeng, ice, adi, adi2020,
rurality, pcp_density) — the CT geography fix at Task 2.5 closed the last Block B
gap.

---

## 3. Q1 — the disadvantage differential is real, and it goes to Limitations

**Every substantive-missingness variable is differential with disadvantage.**
The pattern is one mechanism seen from several angles: the missing values are
concentrated in **small, rural, lower-volume hospitals**, and those hospitals
serve **more disadvantaged communities**. The clearest cases:

- **`psi12` / `psi13`**: the components are suppressed when the at-risk
  denominator is too small (spike-outcome.md §7). Missing hospitals sit at
  ICE-deprived SMD −0.99 / −0.69 — the deprived end.
- **`system_member`**: the 36 hospitals absent from Hospital Enrollments are
  smaller, more rural (SMD −0.37), more deprived (ADI −0.51).
- **`contract_labor_share`**: SVI-SES SMD −0.29 — missing hospitals in
  lower-socioeconomic catchments.

Report §9 states this with the standardized differences, for every affected
variable, whatever the Phase 3 estimates turn out to be.

**This does not, by itself, threaten the finding** — because of Q2.

---

## 4. Q2 — the same missingness is predicted by observed structure, so MI is licensed

**Every substantive-missingness variable's missingness is predicted by the
fully-observed covariates** (LR test p ≤ 0.0015 for all 8). For the suppressed
components the relationship is near-deterministic (pseudo-R² 0.45–0.72:
missingness *is* volume suppression, and volume is 100% observed). For the HCRIS
financial fields it is weaker but clearly present (`uncompensated_care`
pseudo-R² 0.06, p = 0.0015).

That is exactly the condition under which **multiple imputation by chained
equations is unbiased**: missing-at-random given observed covariates. The
imputation model at Task 2.7 includes beds, rurality, ownership, CBSA, wage
index, volume, and the Block B disadvantage measures — all fully observed —
with predictive mean matching for the bounded/skewed variables (contract-labour
share, uncompensated care).

**MI is licensed for all 8. Complete-case for none.** No variable fails Q2, so
the "complete-case, MAR not established" disposition — required by the verify
condition if any variable had failed — is not triggered here.

### Contract labour: continuity with Phase 0

Phase 0 measured contract-labour missingness **before** deterministic recovery:
9.2% missing, beds SMD +0.462, rural −0.269 (`admission-gates.md` C2.e). Task
1.6's recovery (raw HCRIS S-3 + FY2022 cross-year fill) removed the recoverable
part; the audit here is the **post-recovery** state MI actually operates on:
**5.0% missing, beds SMD +0.68, rural −0.20**. Recovery shrank the count and
left the residual still MAR.

---

## 5. The figure — `output/figures/missingness-audit.png`

Two panels. Left: missingness rate per variable, every bar coloured for
"differential with disadvantage" (all 8 are). Right: the standardized-difference
forest — `log(beds)` (●), rural indicator (▲), ADI (■), present minus absent,
with the ±0.10 balance band shaded. Every ● is well right of the band (missing =
smaller); the ▲ and ■ sit left of it for most variables (missing = more rural,
more deprived).

---

## 6. Files

```
R/missingness.R                             new — stage 17
make.R                                      stage 17 added
output/tables/missingness-audit.csv         30 rows (one per audited variable)
output/figures/missingness-audit.png        the first figure in the project
output/tables/task2.6-missingness.txt       stage log (carries both Q1 and Q2 per variable)
```

No `data/` output — the audit is a diagnostic, not an analytic file. No
`provenance/sources.csv` change. Full `make.R`: 17 stages `ok`, provenance
`consistent`.

---

## 7. Next

**Task 2.7 — run the admission tests.** Evaluate every gate in
`admission-gates.md` (C1, C2, C3, B0, O1) into
`output/tables/admission-gate-results.csv`. Order of operations for contract
labour (amendment A1): deterministic recovery first (done at 1.6), then gate C2
on the recovered coverage, then **MI by PMM, m = 20** — licensed for it, and for
the seven other MAR variables, by this audit. Blanks are never imputed to zero
(C2.b = exactly 0). Depends on 2.6, 0.6, 1.6. **Does not get cut.**
