# Task 5.3 — Draft §4, methods in plain language

**Date:** 2026-09-28 · **Budget:** 5 h · **Status: drafted. The verify
condition (a test on an actual person) is pending and is Carl's to run; see
§3.**

The draft is `report/04-methods.md`, about 2,850 words and one table, in
Carl's voice with American spelling. Formal definitions are left to the
appendix (5.8). **Stage 39 now covers §4:** 36 numeric tokens, 0 unregistered.
The registry holds 170 values across the two sections.

---

## 1. How the section is built for this audience

Plan §3 describes the readers: the Foundation lead and the Business Case Work Group. They
bring the four-model framework and have no background in model multiplicity.
The section therefore opens from the framework's own Model 2 text ("which
inputs are necessary across credible models and which are substitutable").
It then explains each method in terms of that question:

- the Rashomon set is "credible models";
- MCR⁻ > 1 is "necessary";
- direct against shared reliance is "essential" against "substitutable".

Table 4.1 maps each question to its method and to the section that reports it.
There are no figures, so the figures stay numbered in order of appearance from
§3.

The three verify targets are covered as follows.

- **What a Rashomon set is** (§4.4): models within a tolerance of the best fit.
  The tolerance comes from refitting the best model on 1,000 resamples and
  taking the 95th percentile of its error spread, fixed in advance. The section
  says that the resampling unit (hospital, metro or state; 4.1%, 5.1% or 9.3%)
  matters more than the percentile, and it gives the set's width.
- **Why MCR⁻ > 1 is stronger than a p-value** (§4.5, one paragraph):
  - a p-value lives inside one model and assumes that model is right;
  - MCR⁻ > 1 holds for every credible model;
  - MCR⁻ concerns predictive need, not one coefficient, so it can hold while
    the models disagree on the size of the contrast. That is this project's
    actual situation.
- **The three limits of MCR⁻**, stated where they apply: it is a claim about
  models, not the world; it is an upper bound because the model set was
  enumerated; and it depends on the tolerance, reaching 1.000 at the state
  tolerance.

One worked contrast from the project's own results carries the TIS idea:
SVI 3 has a marginal reliance of 0.998 but a direct reliance above 1 in every
member. Stage 39 asserts the direct-reliance claim (`stopifnot(dir_lo > 1)`),
so the sentence cannot go stale.

## 2. Claims checked against the provenance, and corrected while drafting

- The Q-HIP band is 0.1%–4% **of the commercial fee schedule**. The simulation
  assigns the rate by rank; it is not Q-HIP's actual rule. Stage 39 reads the
  band from `rate_of()` in `R/09-payment-sim.R` and stops if it cannot find it.
- The regressivity rule is stated as the 4.4 amendment-9 quantity: the
  marginal incentive per NPR dollar, along a named ranking, below zero with a
  95% interval excluding zero. It is not stated as "bonus per dollar".
- C1 is stated as reproducing 3,054 of 3,055 HACRP decisions, read from the
  stage 35 log.
- The draft said all tolerance-dependent results are reported at all three
  tolerances. That was **narrowed:** the reliance bounds are, but the payment
  simulation runs at the primary and metro tolerances only.
- The Track verdict rule is described as fixed "before the test was run", not
  "before the data were examined", because 3.15 had already clustered the
  data.

## 3. The person test (Task 5.3 verify). Carl to run

**Reader.** Someone who has not heard of Rashomon sets or MCR, ideally with a
profile like the Work Group's: comfortable with regression output, no
background in model multiplicity. It should be someone who has not seen this
project's results.

**Procedure.** The reader reads `report/04-methods.md` once, with Table 4.1,
and does not read the appendix. With the text put away, they answer in their
own words:

1. What is a Rashomon set, and how did the report decide which models belong
   in it?
2. The report says MCR⁻ for community disadvantage is above 1. Why is that a
   stronger statement than "community disadvantage is statistically significant
   (p < 0.05)"?
3. (Stretch) What would it mean for a disadvantage measure to be "substitutable"?

**Pass.**

- Q1 needs both parts: (a) the set is the models that fit about as well as the
  best one, and (b) the cut-off came from a procedure fixed in advance, not
  from judgment.
- Q2 needs (a) the claim covers every credible model, not one, and (b) no
  credible model can do without the covariate, or "they all lose accuracy
  without it".
- Q3 is informative only; it is not a pass condition.

**Record.** Write the answers verbatim below, with the date, the reader's
role (not their name), and pass or fail. If Q1 or Q2 fails, revise the
paragraph the answer shows was misread, and re-test with a different reader.

| Date | Reader (role) | Q1 | Q2 | Q3 | Revision made |
|---|---|---|---|---|---|
| | | | | | |

## 4. Note for 5.4 onward

§4 promises some content to later sections:

- §6 assigns Model 2's tags (essential, useful, substitutable, optional) from
  the direct and shared split;
- §5 carries the reliance bounds at all three tolerances;
- every importance claim carries the Rashomon width.

5.4 has to deliver those, and each section adds its registry block to
`R/13-report-numbers.R`.
