# Task 3.5 — Freeze the specification registry

**Date:** 2026-09-02 · **Budget:** 4 h · **Status: complete. N is fixed.**
One stage (`make.R` 23, `R/03-spec-registry.R`) reading `data/analytic-v1.rds`
— and reading it only to confirm every axis level's input columns are present.
No model is fitted. No number from the file is reported.

**The registry:** `data/spec-registry.rds` (+ `.csv` mirror), 3,496 rows × 15
columns, one row per specification. Both files are **force-tracked** (`.gitignore`
exception added) — they are build products in every respect except one: Task
3.5's verify condition is that the commit predates the first fit, so the
registry has to be *in the history*, not merely regenerable. The commit of this
task is that timestamp.

---

## 1. Axes — 8, up from the rev-2 table's 7

The rev-2 task sheet fixes a 7-axis table. Carl signed off on 2026-09-02 on
adding the **outcome-scale axis (identity / log)** that Task 3.1 §1 had flagged
as a candidate (PSI-90 skew +2.75, → +1.05 logged; 20 of 37 measures |skew| > 1).
It is defensible, decided before any fit, and a health-services reviewer will
ask for it (Plan §12). No outcome has a zero or negative value (min PSI-90
0.402, min component rate 0.050), so `log()` is clean with no offset.

| Axis | Levels | k |
|---|---|---|
| `blocks` | A / AB / ABC(admitted) | 3 |
| `form` | linear / spline — `ns(df=3)` on the continuous Block B disadvantage measures only | 2 |
| `outcome` | composite / psi03 / psi06 / psi12 / psi13 / agg (denominator-weighted component aggregate) | 6 |
| `reliability` | unweighted / weighted / subsample / eiv | 4 |
| `grain` | catch_tract / catch_county / hosp_county / hsa | 4 |
| `missing` | mi (PMM m=20) / complete / omit | 3 |
| `influential` | all / drop_fn2329 / drop_fallback | 3 |
| `scale` | identity / log | 2 |

Naive factorial 3·2·6·4·4·3·3·2 = **10,368**.

Every level's justification is in `provenance/spec-space.md` §2–§8 (Task 3.4);
not restated here.

---

## 2. Structural voids pruned (spec-space.md §9)

The registry builder applies five rules, in order, and prints the row count
after each:

| Rule | What it removes | 10,368 → |
|---|---|---|
| V2 | `missing` is a real axis only when Block C is in the model (`contract_labor_share` ∈ Block C). For `blocks ∈ {A, AB}` the three levels collapse to one sentinel `"na"`. | 5,760 |
| V1 | `form = spline` is identical to `linear` with no Block B in the model. Removed for `blocks = A`. | 5,184 |
| V3 | `reliability = eiv` needs a published per-hospital λ — the composite has one, the components do not. Removed for every non-composite outcome. | 4,104 |
| V4 | The catchment *covariate* grains are inert with no Block B covariates; under `blocks = A` the grain axis is just the nesting choice, so `catch_tract` and `catch_county` (both HSA-nested, no B columns used) are dropped as exact duplicates of `hsa`. `{hsa, hosp_county}` remain = HSA-nested vs county-nested. | 3,876 |
| V5 | `influential = drop_fallback` changes nothing measurable where no catchment weighting is used — removed under `blocks = A` and under `grain = hosp_county`. | **3,496** |

3 of the 130 catchment-fallback hospitals also carry an fn-23/29 flag; the two
drop rules are applied independently, never unioned.

---

## 3. N = 3,496

| block set | specs | why this many |
|---|---|---|
| A | 152 | form 1 · outcome×reliability 19 · grain 2 · influential 2 · scale 2 |
| AB | 836 | form 2 · outcome×reliability 19 · (grain×influential 11) · scale 2 |
| ABC | 2,508 | form 2 · outcome×reliability 19 · (grain×influential 11) · missing 3 · scale 2 |
| **total** | **3,496** | |

"outcome×reliability = 19" is the composite's 4 reliability levels plus each of
the 5 component-based outcomes' 3 (no `eiv`). "grain×influential = 11" is the 4
grains × 3 influential levels minus the one `hosp_county` × `drop_fallback` cell
that V5 voids.

Cross-tabs (from the stage log, `output/tables/task3.5-spec-registry.txt`):

```
        agg  composite  psi03  psi06  psi12  psi13   Sum
  A      24         32     24     24     24     24    152
  AB    132        176    132    132    132    132    836
  ABC   396        528    396    396    396    396   2508

              all  drop_fallback  drop_fn2329   Sum
  A            76              0           76    152
  AB          304            228          304    836
  ABC         912            684          912   2508
```

**Registry sha256 (serialised object, v3): `506cfc2a…`** — pinned here so a
later regeneration that changes N is caught the same way `freeze.R` catches
drift in the analytic file.

---

## 4. Registry columns

The 8 axis columns plus `spec_id` (int, 1–3,496), and 6 derived fields the Task
3.6 harness resolves a row through:

| column | meaning |
|---|---|
| `outcome_family` | composite / component / aggregate |
| `weight` | `none` · `lambda_i` (composite, `reliability=weighted`) · `denominator` (component/agg, `reliability=weighted`) · `none_high_reliability_subsample` · `lambda_eiv` |
| `subsample` | logical — restrict to the top reliability tier (λ ≥ 0.6 ≈ upper two volume quartiles) |
| `nest` | `hsa` or `county` — the random-effect grouping implied by `grain` |
| `blockB_suffix` | column suffix for the Block B covariates (`catch_tract` / `catch_county` / `county` / `hsa`); `NA` when `blocks = A` |
| `key` | `blocks.form.outcome.reliability.grain.missing.influential.scale` — stable, unique, human-readable |

The harness owns the level→formula mapping; the registry only says *which*
levels. `cl_share_mi_01..20` (the frozen m=20 PMM draws) and the z-scoring of
component outcomes are fixed preprocessing, not levels.

---

## 5. Files

```
R/03-spec-registry.R                     new -- make.R stage 23
make.R                                   stage 23 added
.gitignore                               force-track data/spec-registry.{rds,csv}
data/spec-registry.rds                   3,496 x 15 -- THE FROZEN REGISTRY
data/spec-registry.csv                   human-readable mirror
output/tables/task3.5-spec-registry.txt  stage log (gitignored)
```

`make.R --stage 23`: `ok`, provenance `consistent`, 2.8 s. Frozen analytic hash
(`7d409b5d…`) unaffected — stage 23 reads the file, writes nothing upstream.
Provenance table unchanged at 33 rows (no new source).

---

## 6. Next

**Task 3.6 — build the fitting harness** (`R/04-spec-curve.R`). Fits every one
of the 3,496 registered specs, stores coefficients / loss / diagnostics in one
uniform structure, and **records failures as rows with a reason rather than
skipping them**. Test on a 10-spec subset; estimate full-grid runtime before
launching (the composite arms are ~ms `lm` fits, the component arms ~2.5 s
`lmer` fits — order of a few hours for the full 3,496). **The first fit happens
in Task 3.6, and this commit predates it — that is the evidence the grid was
frozen first.**
