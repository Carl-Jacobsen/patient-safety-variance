# Task S3.5 — Reconnect the work to CASH2 and open the revision ledger

**Date:** 2026-10-05 · **Budget:** 2 h · **Status: done. No stage; no number
in the variance pipeline changed.** The report now has a scope statement that
says what the project calibrated and what it did not. The CASH2 verification
script was rerun and reproduces the memo's returns exactly. The Foundation lead's four
unresolved issues are in a revision ledger, all open and none addressed here.
The next ROI exercise is defined on one page, with a source for every input.
**This closes Phase S3.**

---

## 1. The CASH2 verification, rerun

`CASH memo/Models/verify_models.py` (sha256 `e05e3946…cf63f05`), run
2026-10-05 from `Models/`. It is an independent Python check of
`vbp_model.R` (sha256 `c932b861…434b773`) from the same parameters.

| | Track 1 | Track 2 | Track 3 |
|---|---|---|---|
| VBP net ROI, base case | 4.31× | 10.38× | 9.42× |
| VBP net ROI, Q-HIP bonus removed | 2.68× | 5.44× | 2.92× |

Both rows match the task sheet and memo v6 exactly. They show that the
arithmetic is right under the memo's assumptions; they test none of the
assumptions.

## 2. The scope statement, for S5 (report sec 2)

> This project calibrated some of the hospital characteristics CASH2 assumed
> against national data, and described how a Q-HIP-style payment would
> distribute across hospitals under stated scenarios. It did not recalibrate
> the SSI intervention, the avoided-cost model, the malpractice pathway, or
> how safety responds to investment, which together produce CASH2's returns.
> CASH2's verification script reproduces the memo's base-case net returns on
> the value-based purchasing pathway (4.31, 10.38 and 9.42 for Tracks 1 to 3)
> and its returns with the bonus removed (2.68, 5.44 and 2.92). That confirms
> the arithmetic under the memo's assumptions, which this project neither
> establishes nor overturns. The community measures recommended here are a
> candidate community-data module for this safety-score analysis. They are not
> a minimum dataset for a CASH2 business case, whose returns depend far more on
> eligible revenue, intervention cost, achievable reduction and payment timing
> than on any covariate that helps predict PSI-90. The issues in the memo that
> The Foundation lead's review raised, and that this project does not answer, are kept in
> a separate revision ledger.

**The rename.** Wherever the draft calls the SVI set a "minimum dataset" or
"recommended core" (secs 1, 6 and 10; the claim-guard worklist already flags
sec 10's "The recommended core is the CDC Social Vulnerability Index file"),
S5 uses "candidate community-data module for this safety-score analysis".
The S2.4 validation is its basis, not the TIS tags.

**Stage 39.** The six CASH2 values come from the memo's script, outside
make.R. When S5 writes sec 2, its registry block must register them as quoted
external values, with the script's path and hash as the source, as the memo's
bed counts already are in sec 07. Sec 02 has no registry block yet.

## 3. The revision ledger

`CASH memo/Review/CASH2 revision ledger.md` (sha256 `3a44b694…c6bb6b`, 742
words; the CASH memo folder is not under git, so the hash is the record).

| # | Issue | Status in v6 | Ledger status | Variance project |
|---|---|---|---|---|
| 1 | Allocation of infection-prevention spending to SSI ($200/bed from a 0.20 allocation of a full program; unsourced; no sensitivity) | unchanged; v6 still says VBP "clears its cost in every scenario we run" | open | not addressed |
| 2 | Track 3's 50% maturity discount | disclosed as "not independently sourced" | open | not addressed |
| 3 | Payer mix and eligible revenue (net patient revenue derived from commercial share, backwards; the program payer's contracts vs the whole commercial book) | unchanged (Table A3, malpractice parameters: net patient revenue "derived from commercial share") | open | not addressed; related evidence only (the payment simulation's HCRIS day shares and price-ratio scenarios) |
| 4 | Captive rebate against new consolidated value | disclosed ("does not establish … new consolidated-system value"), but 0.43× still reported as a return | open | not addressed |

Each row cites where the issue sits in v6, why it matters (with the call-prep
numbers, for example the $100–$1,000 per bed sweep that moves Track 2 from
18.71× to 1.60×), and an empty "Closed by" column. Two distinctions from the
October 1 review follow the table, also open:
- avoidable resource cost versus cash released to the hospital;
- payer transfers versus additional societal benefit.

## 4. The next ROI exercise, on one page

`CASH memo/Review/Next ROI exercise - definition.md` (sha256
`c2d35c6c…57f29`, 729 words with its table).

- **The hospitals.** Six to eight hospitals, at least one from each Track
  cell and at least two off the diagonal, varied in size and safety-net
  status. Candidates come from the 2,581-hospital frame; participation depends
  on partners sharing internal data.
- **The unit, left open.** Facility or consolidated system is a decision for
  the Foundation lead, already listed in the task sheet's open decisions. The page says
  which inputs it changes.
- **The inputs and where each comes from.** Ten inputs:
  - eligible contracted revenue and program terms (finance office, contracts);
  - procedure volume and baseline SSI risk (NHSN surveillance; Care Compare and
    HACRP publicly);
  - intervention cost and achievable reduction (the hospital's IP budget and
    bundle costs; published effect sizes);
  - avoided cost and who keeps it (cost accounting, payment method);
  - penalty exposure (HCRIS, HACRP);
  - malpractice arrangement (risk management);
  - timing and ownership of benefits (contracts, system transfer rules).
- **Success.** A usable decision for each hospital with its uncertainty
  stated, reported with and without the bonus, the inputs that drive it, and
  the two distinctions kept apart.
- **Link to the ledger.** Each ledger issue is answered by an input on the
  page, so the exercise would close the ledger with data.

The page makes one public-data claim that I checked against the files: the
HACRP file carries a single combined SSI ratio (`SSI SIR`); Care Compare's HAI
file, not acquired by this project, reports colon and hysterectomy SSI
separately.

## 5. Verify

- **Ledger.** Each of the Foundation lead's four issues has a row marked open and "not
  addressed" by the variance project (sec 3).
- **Exercise page.** It names all ten inputs, each with where it would come
  from (sec 4).
- **Scope.** The scope statement contains the four exclusions and both rows
  of reproduced returns (sec 2).

## 6. Phase S3, closed

| Task | Commit | Stage | One line |
|---|---|---|---|
| S3.1 | 1972595 | 43 | Every frame traced from 2,801 and reconciled in stage 39; the contract-labor shift moves nothing that matters; the complete-case restriction is the real missing-data choice |
| S3.2 | 6050e8e | 44 | Suppression fills leave fit and contrast intact; hospital ranks on the community contribution are not stable, worst among low-discharge hospitals |
| S3.3 | bbe5601, 45bb710 | 45 | One name per set; system membership is a real omitted predictor that leaves the disadvantage findings intact; timing recorded |
| S3.4 | db14922 | 46 | The criteria disagree; no stable three-Track groups; 61.6% off the diagonal; 50% is an operational bar |
| S3.5 | this commit | — | Scope stated; CASH2 arithmetic reproduced; ledger open; next exercise defined |

Next is Phase S4: one release rerun (`make.R --release`). Stages 43–46 are new
and the release mode has not yet run them in sequence. Stage 32's log title
(S3.3 sec 1) can be changed before that run if S5 wants the TIS log quoted.
