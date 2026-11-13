# C. Sensitivity analyses and supporting results

## C.1 Reliability by volume

Figure S1 shows the reliability approximation of section A.1 by Medicare volume quartile and by hospital location. Hospitals in the lowest quarter of volume retain a mean of 0.205 of their deviation from the national mean and those in the highest 0.755, so the published score is smoothed hardest at small hospitals, which are disproportionately rural.

## C.2 The specification curve

Figure S2 plots the disadvantage contrast of every one of the 3,344 specifications that include the community block, with the members of the Rashomon set marked. Of the 3,344 contrasts, 69.0% are positive and the median is +0.10 standard deviations, but only 7.3% have an interval wholly above zero and none has one wholly below; the near-optimal members span −0.37 to +0.86. The curve weights every specification equally, including those that fit poorly, which is why the main report reads direction from the Rashomon set instead.

## C.3 Suppressed discharge counts

The catchment weights use only the observed cells of the Hospital Service Area File. Table S3 refits the anchor specification (382, county-grain catchments) and its tract-grain sibling (344) after filling every one of the 996,700 suppressed cells at a constant count, and after 20 draws in which each suppressed cell is filled uniformly between 1 and 10; the weights and the ten community measures are rebuilt each time. Rank movement is the change in a hospital's position, among the 2,569, in the ranking of its community contribution to predicted PSI-90.

Table S3. Effect of filling suppressed cells, county-grain anchor (all hospitals, and the 251 with the fewest mapped discharges).

| Fill | Loss change | Contrast change | Rank correlation, all | Rank correlation, fewest discharges | Largest rank move |
|---|---|---|---|---|---|
| 1 discharge | −0.07% | −0.001 | 0.995 | 0.974 | 903 |
| 3 discharges | −0.09% | −0.013 | 0.979 | 0.921 | 1,543 |
| 5.5 discharges | −0.03% | +0.012 | 0.959 | 0.881 | 1,573 |
| 10 discharges | +0.12% | +0.044 | 0.924 | 0.840 | 1,696 |

At the tract grain the contrast grows with the fill (+0.009 at 1 discharge to +0.081 at 10) but keeps its sign. These are scenarios with no probability attached.

## C.4 The missing-data assumption

Contract labor is imputed for 158 hospitals under a missing-at-random working assumption. Table S4 shifts every imputed value by a multiple of the observed standard deviation (0.0748) and refits the best and median imputation models (specifications 80 and 157) on 2,700 hospitals, scored on the common 2,569.

Table S4. Community share and model reliance on the disadvantage group after shifting the imputed contract-labor values.

| Shift (SD) | Community share, spec 80 | Reliance, spec 80 | Community share, spec 157 | Reliance, spec 157 |
|---|---|---|---|---|
| −1 | 5.11% | 1.1153 | 4.25% | 1.0957 |
| 0 | 5.12% | 1.1149 | 4.27% | 1.0955 |
| +1 | 5.15% | 1.1150 | 4.30% | 1.0957 |

The shifts move the community share by at most 0.03 percentage points. The choice between complete-case, imputed and omitted contract labor moves the reliance far more, so the complete-case restriction is the missing-data assumption that matters.

## C.5 Ownership and system membership

Ownership (government, proprietary, nonprofit) and system membership come from 2026 enrollment snapshots, later than the outcome window, and were not in the registered structure block. Table S5 adds them to the best published-score model (382) and the median one (610).

Table S5. The two anchors with and without ownership and system membership.

| Model | Version | Joint contrast | Community share | Reliance on disadvantage group |
|---|---|---|---|---|
| Spec 382 | as fitted | −0.21 | 5.70% | 1.127 |
| Spec 382 | with ownership and system | −0.24 | 5.26% | 1.112 |
| Spec 610 | as fitted | +0.14 | 4.59% | 1.135 |
| Spec 610 | with ownership and system | +0.10 | 4.14% | 1.114 |

## C.6 Which draws move which payment output

Each payment output's interval reflects only the sources of uncertainty that output depends on, which the simulation traces by rerunning it with each source fixed. The concentration index of the finite return along catchment ADI, and the safety-net ratio, vary only with the published-score draw, since neither the ranking nor revenue depends on the model drawn; the index along model-implied disadvantage varies with the specification, the coefficients and the published-score draw; the all-improve payment change and the revenue exposure coefficient along ADI have no modeled variation at all. A zero-width interval in the main report therefore means that nothing the quantity depends on was drawn, not that it is known exactly.

## C.7 The Track cells

Table S6 is the full cross-tabulation behind the main report's Track finding, on the 2,581 hospitals with a star rating and an operating margin. The three cells the Tracks describe hold 990 hospitals; 1,591 (61.6%) are off the diagonal. Figure S4 sets the cells beside the memo's Track parameters. On PSI-90 and operating margin across 2,759 hospitals, ICL selects 2 groups on the published score and 4 on the reliability-corrected score while the gap statistic selects 1 on both, and ICL's choice recurs in 44% and 59% of 100 random 80% subsamples.

Table S6. Hospitals by star rating and operating-margin third.

| Star rating | Bottom third | Middle third | Top third |
|---|---|---|---|
| 1 to 2 stars | 297 (Track 1 cell) | 235 | 186 |
| 3 stars | 295 | 272 (Track 2 cell) | 254 |
| 4 to 5 stars | 268 | 353 | 421 (Track 3 cell) |

## C.8 Simulated payment by stratum

Figure S5 shows the simulated bonus rate and dollars per hospital under the Q-HIP-style rule as CASH2 specified it, by catchment ADI fifth, model-implied disadvantage, safety-net status and Track cell. These are national what-ifs, since Q-HIP participation cannot be identified by hospital.
