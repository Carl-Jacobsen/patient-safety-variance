# Task 5.6 — Draft §9, limitations

**Date:** 2026-09-29 · **Budget:** 4 h · **Status: drafted; the three verify
conditions pass, and one of them is now mechanical.**

The draft is `report/09-limitations.md`, about 2,300 words in nine subsections.
It covers the task sheet's list: ecological inference, the Medicare-only
catchment, suppression with its measured cost, the partial coding proxy, the
cross-sectional design and disadvantage-correlated missingness. It also covers
rev 2's three additions: reliability attenuation with the λ distribution and
its direction, the 3.0-year SVI gap, and the 2.5-year tort gap. Everything the
5.2–5.5 notes handed forward is here too.

---

## 1. Verify

| Condition | How it is met |
|---|---|
| The report does not claim the surveillance and coding bias problem is solved | §9.4 states that the proxy cannot separate documentation from sicker patients, that it measures coding across all conditions, and that the direct measures need discharge-level data. It gives case mix drift's SD (0.0527) and notes that its association straddles zero in every credible model. It ends by saying the community associations "could still partly reflect differences in how complications are documented". Stage 39 asserts that the drift range straddles zero |
| The partial proxy's limitation is stated, not absorbed | §9.4 is a subsection of its own, and §6.3 already says the proxy "cannot rule out the coding explanation" |
| No limitation is stated without its number where Phase 0 produced one | **Mechanical.** Stage 39 now holds `REQUIRED_09`, the rev-2 renderings: λ median 0.462, Q1 mean 0.205, corr(λ, log volume) +0.93, SVI gap 3.0 years, tort gap 2.5 years, 87.46% suppressed, r ≥ 0.986, 83% coverage and 130 fallback hospitals. It fails if §9 loses any of them. **9 of 9 are present.** §9: 49 numeric tokens, 0 unregistered |

The λ direction argument follows rev 2 as written. λ is nearly flat in DSH
share (+0.07) and Medicaid day share (+0.08), and it falls with rurality
(−0.40; rural 0.304 against 0.520). So the urban, payer-mix disadvantage
result is conservative, and the rural result is the one the composite hides.
The correlations are read from the stage 1b log (`phase0-followup.txt`) with
strict patterns.

## 2. Limitations the earlier sections had not stated

- **Commercial share is a share of inpatient days, not of dollars**
  (payment-model-inputs.md, amendment 1). Dollar levels therefore run low, but
  ranks and indices are unaffected by a common factor. The share also counts
  self-pay as commercial, which overstates commercial share most at safety-net
  hospitals. **That error runs against finding the formula structurally
  regressive, so the ADI result is conservative.** §8.1 now names the measure
  and points to §9.
- **Imputation uncertainty is understated slightly.** The completions were
  frozen with the analytic file and carried through the bootstrap rather than
  redrawn (3.9 preregistration §4).
- **Suppression was tested at county grain only.** The r ≥ 0.986 test ran on
  2,730 hospitals at county grain. At tract grain the evidence is indirect:
  agreement with the suppression-free HSA construction is ≥ 0.82.
- **The complete-case frame drops 232 hospitals** (2,569 of 2,801), and they
  lean small and deprived. This may understate associations concentrated
  among them.
- **The ADI interval leaves out sampling error in the HCRIS payer days**
  (4.4 §2).

## 3. Numbers read from logs

The λ quantiles, the four λ correlations, the rural and non-rural λ means and
the SVI gap are read from the stage 1 and 1b logs, the only place `make.R`
writes them. A pattern that stops matching fails the stage; nothing falls
back to a default.
