# Task 5.7 — Draft §1 and §10, summary and recommended actions

**Date:** 2026-09-30 · **Budget:** 5 h · **Status: drafted, and the verify
condition passes as a mechanical check.**

- `report/01-summary.md`: about 1,000 words. A framing paragraph, then five
  findings in the CASH2 memo's summary form, then four decision points.
- `report/10-actions.md`: about 1,100 words. Five actions, each tied to a
  finding and its number, with its limits stated.

---

## 1. Required content

- **The 3.3 one-sentence-with-a-number** opens finding 1. It uses the
  corrected wording, "of the 9.1% that the three covariate blocks explain
  together" (5.4 §3), with the 91% unexplained beside it.
- **A direct answer on headroom** is finding 5 and §10.5. Per revenue dollar,
  the formula sends money neither toward nor away from headroom (−0.005
  [−0.013, +0.004]). It sends money away if the lowest-scoring quarter earns
  nothing (−0.076).
- **Model 2's ranked minimum-viable dataset** is finding 3 and §10.2, pointing
  to Table 6.1.

## 2. Verify: zero causal verbs

**Stage 39 now scans every `report/*.md`** for cause, causes, caused, causing,
drive, drives, driven, driving, driver(s), lead(s) to, led to, result(s) in,
resulted in, impact(s) and impacted. **It fails on any of them, negated or
not.** Only "driver script" and "Impact File(s)", which are names, are exempt.

Before drafting, a scan of §§3–9 found four slips, all fixed:

- §5: "No single hospital drives these results";
- §6: "the main result on drivers";
- §8: "Driven instead by the Rashomon models' predictions";
- §4: "does not claim that a community's characteristics cause". This one was
  negated, but it was reworded so the rule holds without exception.

The summary was drafted to the same standard. **The scan now reports none
across all nine sections.**

Stage 39 status: all nine sections pass. §1 has 38 numeric tokens and §10 has
16, all registered. Every number in §1 and §10 is copied in the registry from
the section that computes it (`copy_reg`), not recomputed. "Structurally
regressive" appears once in each, qualified.

## 3. Choices in the recommendations, for Carl's review

The actions stay within what the evidence supports. Where an action would
change a payment design, it is offered as an option to test, because section 8
varied only the named scenarios. Three are worth a look before the Foundation lead sees
them:

1. **§10.1, "a design whose conclusions change between [published and
   reliability-corrected] should not be adopted on the strength of either."**
   This is the strongest recommendation in the section.
2. **§10.5 names a total-revenue base or a fixed per-hospital component** as
   ways to reach deprived catchments. Neither was simulated, and the text says
   so.
3. **§10.4 suggests buying Leapfrog grades** only if the archetype question
   still matters to CASH.

The summary says CASH "should decide whether its models rank hospitals on the
published composite at all". That follows from the 91% unexplained share and
the smoothing pattern. It is phrased as a decision for CASH, not a finding.
