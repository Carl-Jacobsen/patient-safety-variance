# Task 2.8 — Freeze the analytic file

**Date:** 2026-08-31 · **Budget:** 1 h · **Status: complete. Phase 2 closes.**
`data/analytic-v1.rds` — 2,801 × 200 — merged from the four built blocks, hashed,
and pinned. Re-running `make.R` from raw reproduces the identical hash.

---

## 1. The merge

One row per frame CCN. Column-name collisions were checked (none) and the blocks
column-bound in frame order behind eight identifier columns from the crosswalk:

| group | n cols | from |
|---|---|---|
| `ccn` + identifiers (`provider_number`, `name`, `state`, `city`, `zip5`, `census_tract`, `cbsa`) | 8 | Task 2.1 |
| outcome layer (`psi90`, components, `v_i`/`tau2`/`lambda_i`, HACRP anchor, footnote flags) | 51 | Task 2.2 |
| Block A (10 structural covariates + HCRIS cross-checks + `flag_*`) | 44 | Task 2.3 |
| Block B (12 covariates × 4 grain variants + `hhi_zip`/`hhi_hsa` + retained-weight cols) | 66 | Task 2.5 |
| Block C admitted (`cmi_level`, `cmi_drift`, contract labour + `cl_share_mi_01…20`, tort context) | 31 | Task 2.7 |

**Two all-NA columns were dropped** — `psi90_denominator` (the composite is
published "Not Applicable") and `psi_software_version` (open item
spike-outcome.md §9.1). Those gaps are documented in the provenance notes; the
analysis-ready file does not carry dead columns.

---

## 2. The imputation is frozen with the file

The contract-labour MI (`mice`, m = 20, PMM, `seed = 20260831`) was run at Task
2.7, and its 20 completed vectors `cl_share_mi_01…cl_share_mi_20` are columns of
Block C — so they are in `analytic-v1.rds` and hashed here. This is deliberate:

- **The frozen file is a single self-contained hashed artifact.** Phase 3's
  three imputation-handling arms all read from it without re-running `mice`:
  the **MI arm** uses `cl_share_mi_*`, the **complete-case arm** uses
  `contract_labor_share` (observed, `NA` where missing), the **omitted arm**
  drops the covariate, and the **MNAR diagnostic** uses `contract_labor_missing`.
- The seed makes the draws deterministic, so the freeze hash is reproducible.
- `data/blockC_mice.rds` (the full `mids` object) is kept alongside for
  Rubin's-rules pooling and for re-imputation if Phase 3 ever needs a
  specification-specific (congenial) imputation model — the seed and predictor
  matrix are recorded there.

The component **outcomes** (`psi03/12/13`, 17.4%–0.8% missing) are **not**
imputed — per gate O1.d they are analysed available-case per component with both
n's reported, and the differential dropout is a Limitations item that the
reliability weighting λ addresses.

---

## 3. Hash and the reproduction test

```
data/analytic-v1.rds        sha256  1827b418832f27f9db1b9edf1a4664d093bf859bdd760240180759c98eeda4e8
serialised object (v3)      sha256  7d409b5dcc434da57110af2f21afd4dd02ac3731f6671839807d3c057da57ee7
```

`provenance/analytic-v1.sha256` is a committed, checked pin. `R/freeze.R` runs
every `make.R` invocation: it rebuilds the file, re-hashes it, and **fails the
build if the hash drifts**. The `.rds` container hash is the primary check; the
serialised-object hash is a compression-independent fallback that isolates a
data change from a zlib/R-version container change.

**Verified:** a second `make.R --stage 19` and a full `make.R` from the
built-file state both reproduce `1827b418…`.

---

## 4. `provenance/amendments.md` — the amendment procedure

Created empty, with the rule stated. After the freeze, **any change to what the
analytic file records** — a corrected value, a re-drawn imputation, an
added/removed covariate, a changed frame — requires a dated, numbered amendment
stating what changed, why, and **whether any modelling result the change could
affect had already been computed** (if so, the change is invalid). The file
becomes `analytic-v2.rds` with its own pinned hash.

Adding a *derived* column on top of the frozen file (a transformation, an
interaction) in Phase 3 is a modelling choice, not an amendment. The admission
gates keep their own stricter threshold-amendment rule.

---

## 5. Phase 2 closes

The task sheet's two conditions:

| condition | status |
|---|---|
| the hash reproduces | **yes** — full `make.R` from raw → `1827b418…` |
| the exclusion log is complete | **yes** — 3 rows (`rand_hospital_data`, `adi_zip4_crosswalk`, `hud_usps_crosswalk`, all Phase 1); **0 admission-gate failures at Task 2.7**, so nothing new to log. C2.e's exceedance is a conditional-admission trigger (amendment A1), not an exclusion. |

```
R/freeze.R                          new — stage 19
make.R                              stage 19 added
README.md                           rule 8 (the freeze)
data/analytic-v1.rds                2,801 × 200   (build product, gitignored)
provenance/analytic-v1.sha256       the pin (committed, re-checked every run)
provenance/amendments.md            empty, rules stated (committed)
output/tables/task2.8-freeze.txt    stage log
```

Full `make.R`: 19 stages `ok`, provenance `consistent`, analytic hash reproduces.

---

## 6. Next

**`[START FRESH SESSION HERE]` — Phase 3.** Task 3.1: exploratory pass on the
frozen file (distributions, within- and cross-block correlations, geographic
patterning of the outcome, and the Block B collinearity that motivates the TIS
decomposition). Everything downstream reads `data/analytic-v1.rds` and nothing
else.
