# Enrichment track (Task 0.5)

**Date:** 2026-08-26
**Status:** Located and specified. **Both items require Carl to act** — one is a
training registration, the other is an email. Neither blocks anything.

---

## Design check first — the thing Task 0.5 actually asks to verify

Task 0.5's verification criterion is not "did the training start." It is:
**neither item appears on any other task's dependency list.** Confirmed by inspection
of the task sheet:

| Task | Depends on | HCUP or AHA appears? |
|---|---|---|
| 1.1–1.7 | 0.1, 0.3, 0.4, 1.1, 1.2–1.6 | no |
| 2.1–2.8 | 1.7, 2.1, 2.4 | no |
| 3.x, 4.x, 5.x, 6.x | upstream phases | no |

Neither HCUP nor the AHA Annual Survey appears in any `Depends on` line anywhere in
the task sheet. Plan §4 states the same thing in prose: HCUP and AHA "stay out of the
base case and sit on a parallel enrichment track, so that the report can be finished
without them."

**The design has not drifted.** The parallel track is genuinely parallel.

The Phase 0 spikes reinforce this. `spike-structure.md` §5 removed the one remaining
paid dependency (RAND Hospital Data) from the critical path, and `spike-outcome.md`
§5 confirmed that the only thing HCUP would add to the outcome layer — discharge-level
observed counts, secondary diagnoses per discharge, POA completeness — is precisely
the material plan §4 Table 1 already assigns to the HCUP path and excludes from the
base case.

---

## Item 1: HCUP Data Use Agreement training

**Action required from Carl.** The DUA training requires completing a course and
signing an agreement under his own name; I cannot complete a training or sign an
agreement on his behalf.

- Training: `https://hcup-us.ahrq.gov/tech_assist/dua.jsp`
- Accessible version: `https://hcup-us.ahrq.gov/DUA/dua_508/DUA508version.jsp`
- Both verified reachable 2026-08-26.

**Steps:** complete the online DUA training, then sign the DUA. The training is short
(under an hour). The signed DUA is a prerequisite for any HCUP purchase, including
the State Inpatient Databases that would carry the PA discharge-level data relevant
to the PRHI-region section.

**Record here when done:**

- Training started: _______
- Training completed: _______
- DUA signed: _______
- DUA expiration: _______

## Item 2: AHA Annual Survey licence

**Action required from Carl.** This is an email to JHF; sending mail on his behalf is
his call, not mine.

**Question to send:** does JHF already hold an American Hospital Association Annual
Survey Database licence, and if so for which survey years and under what terms of use
for a JHF-authored analysis?

**Why it matters, briefly, so the ask is legible to whoever answers:** the AHA Annual
Survey would add nurse staffing ratios, service-line detail, and system-affiliation
structure. None of it is in the base case. If JHF already has a licence, several
Block A and Block C measures get sharper at zero acquisition cost; if not, the report
is unaffected.

**Record here when done:**

- Question sent to: _______ on _______
- Answer received: _______
- Licence held? _______ Years covered: _______

---

## Standing rule for this track

If either item later shows up as a blocker for a base-case task, that is a design
drift signal, not a scheduling problem — stop and re-check the dependency, per the
verification criterion above.
