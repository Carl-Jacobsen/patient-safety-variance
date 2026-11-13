# Task 3.4 — Enumerate the specification space

**Date:** 2026-09-02 · **Budget:** 7 h · **Status: complete.**
Enumeration only — no code, no `make.R` stage, no `data/` output, no
`sources.csv` change. The deliverable is `provenance/spec-space.md`; this note
records the work and the decisions that need Carl.

**Fresh-session rule honoured.** The task sheet requires the space be defined
"without the decomposition results in working memory." The seven axes and their
levels are justified in `spec-space.md` from the plan, the frozen amendments,
and the **pre-decomposition** exploratory pass (Task 3.1) only. No level was
added, dropped, or re-scoped on the basis of a Task 3.3 number; `spec-space.md`
§11 lists every candidate that was considered and left out, with its reason.

---

## 1. The seven axes (rev-2 list, unchanged)

| Axis | Levels | k |
|---|---|---|
| Covariate blocks | A / A+B / A+B+C admitted | 3 |
| Functional form | linear / natural spline on continuous disadvantage measures | 2 |
| Outcome definition | composite / PSI-03 / -06 / -12 / -13 / denominator-weighted aggregate | 6 |
| Reliability treatment | unweighted / reliability-weighted / high-reliability subsample / λ-corrected EIV | 4 composite, 3 components |
| Geographic grain | catchment-tract / catchment-county / hospital-county / HSA | 4 |
| Missing-data treatment | MI (PMM m=20) / complete-case / covariate omitted | 3, only with Block C |
| Influential-point handling | all / drop fn-23 & -29 (77 hosp) / drop catchment fallbacks (130 hosp) | 3 |

Every level has a stated reason in `spec-space.md` §2–§8 (the verify condition).
The reliability axis is the rev-2 addition — justified by the composite's
volume-correlated attenuation (median λᵢ 0.46, quartile λ 0.21→0.76;
`plan-amendments.md` §1.2). The missing-data axis omits the missingness-indicator
arm per amendment A1 (biased in regression even under MCAR).

---

## 2. Grid size — stated before 3.5 freezes it

| | N |
|---|---|
| Naive factorial 3·2·6·4·4·3·3 | **5,184** |
| After hard structural voids (spline needs Block B; missing-data arm needs Block C; λ-EIV needs the composite) | **2,592** |
| After the component-outcome reliability mapping (3 not 4 levels) + the Block-A grain dedup | **≈ 1,950–2,100** |
| Exact integer | Task 3.5 |

Worked reduction in `spec-space.md` §10. At ~2,000 fits of a few seconds each the
full curve is single-digit hours — inside Task 3.6's budget.

---

## 3. Two open items for Task 3.5 / Carl

1. **Outcome scale (identity vs log) — add as an 8th axis?** Task 3.1 §1 flagged
   it (PSI-90 skew +2.75 → +1.05 logged) and it is defensible and
   pre-decomposition, but it is not in the rev-2 axis table. `spec-space.md` §11
   recommends adding it (2 levels, cheap, a health-services reviewer will ask —
   Plan §12). Adopting it roughly doubles the grid to ≈ 3,900. **Left for Carl
   to rule in or out at 3.5.**
2. **The exact V4/V5 dedup rule** (inert catchment grain and no-op fallback drop
   under Block-A-only / hospital-county arms) — mechanical, 3.5's registry
   builder resolves it; noted so the frozen count is not read as the factorial.

---

## 4. Files

```
provenance/spec-space.md          new -- the full enumerated grid (deliverable)
provenance/task3.4-spec-space.md  this note
```

Nothing else touched. Frozen analytic hash unaffected (no build run).

---

## 5. Next

**Task 3.5 — freeze the specification registry.** Convert `spec-space.md` to
`data/spec-registry.rds`, settle the two §3 items, count N, and **commit before
the first fit** — that timestamp is the evidence. Fitting starts at Task 3.6.
