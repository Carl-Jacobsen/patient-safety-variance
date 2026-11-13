# Task 4.4 — Derive the regressivity measure

**Date:** 2026-09-27 · **Budget:** 3 h · **Status: complete. Phase 4 complete.**

One stage (`make.R` 37, `R/11-regressivity.R`, seconds). It reads
`data/payment-sim.rds` and makes no draws.

The framing and the rule were fixed in **amendment 9 (`3fcacdc`), committed
before any per-revenue-dollar index was computed**:

- **the headline is the marginal incentive per dollar of net patient revenue**
  (Carl's decision, after 4.3 showed that size drives the per-hospital gap);
- per hospital is reported beside it;
- the formula is called **"structurally regressive" along an axis only if
  that index is below zero with its 95% interval excluding zero**.

4.2's stage gained the per-NPR indices and headroom strata as new outputs only:
- B stays 8,000, with all 131 headline outputs passing;
- every existing 4.2 and 4.3 number is unchanged. The fixed-shape tables are
  byte-identical. `payment-scenarios.csv` and `payment-strata.csv` keep all
  121 and 176 existing rows identical and gain 121 and 148 new ones. The
  convergence log lists 131 outputs, up from 56.

The plain-language statement is `output/tables/regressivity-statement.txt`.
**It is generated from the numbers, not typed**, so it regenerates with them
(standing rule 1).

---

## 1. The verdicts, under the rule as written

Marginal incentive per unit of PSI-90 improvement, base scenario, B = 8,000:

| Framing | Ranked by | Index | Verdict |
|---|---|---|---|
| **per NPR dollar** | headroom | −0.005 [−0.013, +0.004] | **neutral** |
| **per NPR dollar** | **model-implied disadvantage (primary)** | **−0.014 [−0.037, +0.007]** | **neutral** |
| **per NPR dollar** | catchment ADI (secondary) | −0.033, zero-width | **regressive, by the rule; see §2** |
| per NPR dollar | safety-net / not, ratio | 0.77 | **23% less at safety-net hospitals** |
| per hospital | headroom | +0.020 [+0.002, +0.039] | tilted toward more headroom |
| per hospital | model-implied disadvantage | −0.159 [−0.228, −0.085] | regressive |
| per hospital | catchment ADI | −0.203 | regressive |
| per hospital | safety-net / not, ratio | 1.25 | 25% more at safety-net hospitals |
| per eligible dollar | any | constant 0.585% | neutral by construction |

**So the honest headline is narrower than the one I sketched last turn.**

- **Per revenue dollar the formula is neutral against headroom and neutral
  along the models' own disadvantage ranking.**
- **It is regressive by catchment deprivation (ADI) and by safety-net status,
  and both come entirely from commercial share.** Per commercial dollar,
  every hospital earns the same rate. Commercial share is 0.212 at safety-net
  hospitals against 0.274, and 0.238 in the most-deprived ADI fifth against
  0.272.

The 13% and 23% figures I estimated before the run hold: 13.92 against
15.92 basis points by ADI, and a 0.77 safety-net ratio.

## 2. Two things a reviewer will probe

1. **The ADI interval has zero width.** Neither ADI nor a hospital's incentive
   per revenue dollar varies across draws, so nothing in the simulation
   perturbs this index. It meets the rule, but "excludes zero" there reflects
   no modelled uncertainty, not certainty. Sampling error in HCRIS payer days
   is not modelled. The same holds for the safety-net ratio. The statement
   says this in the sentence that uses the word.
2. **Why the primary ranking is neutral when ADI and safety-net status are
   not.** The models' "disadvantage" ranking orders catchments by how much
   the drawn model associates them with worse PSI-90. It is not a deprivation
   index. Limited-English share runs against it in every near-optimal model
   (3.12), which places many urban safety-net catchments low on it. Under
   CASH2's flat 0.40 safety-net factor the per-NPR index along it turns
   slightly *progressive* (+0.027). The pre-registered primary ranking asks a
   different question from "are poorer places paid less": it asks whether
   hospitals whose catchments carry more PSI-90 risk get less incentive per
   dollar. They do not.

## 3. The scenario that changes the verdict

**The bottom-quartile threshold (S3)** is the variant CASH2's own Table 3
implies: 75% of pay-for-performance hospitals earn a bonus.

- **Headroom:** −0.076 [−0.090, −0.062]. **Structurally regressive, as
  arithmetic.**
- **The models' disadvantage ranking:** −0.046 [−0.078, −0.016]. **Also
  structurally regressive, as arithmetic.**
- The hospitals that earn nothing at the margin are the ones with the most
  room to improve.

**This is the single most consequential design choice in the model, and it is
not something CASH2 or Elevance publishes.**

**Two other scenarios change a headline verdict, and the statement names both:**

- **CASH2's own flat commercial share with its 0.40 safety-net factor:**
  slightly regressive along headroom, −0.009 [−0.015, −0.004]. Safety-net
  hospitals get 40% of the share and carry more headroom. Along the models'
  ranking it is slightly *progressive*, +0.027 [+0.002, +0.046] (§2.2).
- **PSI-90 fixed at its published value:** −0.004 along headroom, with a
  zero-width interval. Nothing varies across draws, so its "regressive" is
  the rule reading a point, the same caveat as ADI.

The attribution weight (S1), scoring shape (S2), PSI-90-only scorecard (S6)
and the metro model set leave the headroom and model-implied verdicts
unchanged, to three decimals. CASH2's flat 37% makes every per-NPR index
exactly zero: with a flat share, the incentive per revenue dollar is the same
for every hospital.

## 4. Incentive against headroom, by stratum (`regressivity-by-stratum.csv`)

| Headroom quintile | Marginal incentive per NPR, bp | Per hospital, $K | Bonus rate, % |
|---|---|---|---|
| 1 (least) | 15.36 [14.87, 15.85] | 630 | 2.46 |
| 3 | 15.16 | 722 | 2.07 |
| 5 (most) | 14.95 [14.49, 15.42] | 691 | 1.59 |

**The incentive to improve is flat across headroom; the bonus paid is not.**
The most-headroom fifth earns 1.59% of eligible revenue against 2.46% for the
least-headroom fifth. That is the pay-for-performance design working as
intended. The marginal incentive per unit of improvement is the same.

## 5. Observed FY 2026 HACRP penalties (`observed-hacrp-regressivity.csv`)

Calibration frame: 2,551 hospitals, 629 penalised (24.7%), Maryland excluded
as waived. Associational throughout.

| | Penalised share | Rate ratio |
|---|---|---|
| ADI quintile 1 (least deprived) | 22.8% [19.4, 26.6] | |
| ADI quintile 5 (most deprived) | 31.8% [27.9, 35.9] | **1.39 [1.14, 1.71]** |
| Model-implied quintile 1 | 22.0% | |
| Model-implied quintile 5 | 35.8% [31.8, 40.1] | **1.63 [1.33, 1.99]** |
| Safety-net / not | 27.2% / 23.8% | 1.14 [0.98, 1.33], includes parity |
| 1–2 star, thin margin | 50.4% | |
| 4–5 star, comfortable margin | 11.1% | |

Concentration index of the penalty:

- ranked by ADI quintile: +0.091 [+0.051, +0.129];
- ranked by mean v_B: +0.117 [+0.078, +0.158].

Positive means penalties are concentrated toward the disadvantaged end. Both
intervals come from a hospital bootstrap, which is not pre-specified in
amendment 9 and is labelled in the table.

**Hospitals in deprived catchments are over-represented among those Medicare
penalises today.** That holds on both catchment rankings. It is not clear for
safety-net status. **Here the models' ranking gives the stronger contrast
(1.63), while for the Q-HIP incentive it gave the weaker one.** The two
programmes put their weight on different things:

- HACRP ranks on the safety score itself, where catchment-associated PSI-90
  risk lands;
- the Q-HIP incentive per dollar is set by commercial share.

## 6. What the report can say, and cannot

**Can:**

- Under CASH2's mechanics, a Q-HIP-style incentive pays **the same per
  commercial dollar** to every hospital.
- Per revenue dollar, it pays **about a quarter less to safety-net
  hospitals** and **about an eighth less in the most-deprived catchments**,
  and that is entirely payer mix.
- If a quarter of hospitals earn nothing, **it becomes structurally
  regressive against headroom, as arithmetic of the formula**.
- Medicare's HACRP already penalises hospitals in deprived catchments at
  **1.4–1.6 times** the rate of the least deprived.

**Cannot:**

- that the base formula is regressive against headroom (it is neutral);
- that the incentive is regressive along the models' disadvantage ranking in
  the base case (neutral);
- anything about intent or realised Q-HIP payments;
- anything causal about HACRP.

## 7. Outputs

- `output/tables/regressivity.csv` (every framing × quantity × ranking ×
  scenario, with the verdict);
- `regressivity-by-stratum.csv`;
- `observed-hacrp-regressivity.csv`;
- `regressivity-statement.txt`;
- `output/figures/regressivity.png`;
- `task4.4-regressivity.txt`.

## 8. Verify

- "Structurally regressive" appears on 4 lines of the statement, each with
  the arithmetic-of-the-formula qualifier. The script asserts it.
- The observed-penalty sentences carry no causal verb. Asserted.
