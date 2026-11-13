# 7. The Track archetypes

The CASH2 memo organized its return-on-investment models around three hospital Tracks: Track 1 hospitals with thin margins and poor safety, Track 2 with middling finances and uneven safety, and Track 3 with comfortable margins and strong safety. The memo said that the Tracks were constructed rather than observed. They are tested against the national data with a verdict rule written down before the test was run. The verdict is that margin and safety form a gradient, not three strata. Better-resourced hospitals do tend to have better safety ratings, and the safety-net mix falls across the Tracks much as the memo described, but hospitals do not sort into three types: most sit outside the Track the memo would assign them, and the middle Track does not exist as a distinct group.

## 7.1 The verdict

Hospitals were cross-classified by CMS overall star rating (1–2 stars, 3 stars, 4–5 stars, standing in for Leapfrog grades D–F, C and A–B) and by operating margin tercile. Figure 6 shows the resulting table, with each cell's count compared with the count expected if star rating and margin were unrelated. The association between the two is positive and clearly above zero (a rank association of +0.21, with a 95% interval of +0.16 to +0.25), so the first condition for the Tracks holds: margin and safety move together in the direction the memo assumed. The second condition does not hold: the three Track cells hold 38.4% of the 2,581 rated hospitals (95% interval 36.5% to 40.2%), against 33.3% if the two axes were unrelated and the 50% that the pre-registered rule required for the Tracks to count as strata. Even the top of the interval falls short of the bar by about ten percentage points. The same verdict follows when the 23 hospitals with extreme negative margins are removed (+0.20, with 38.5% in the Track cells) and when PSI-90 terciles replace star rating as the safety axis (+0.19, with 37.0%).

The association is concentrated in two corners of the table: the Track 1 cell (1–2 stars, thin margin) holds 1.24 times its expected count and the Track 3 cell (4–5 stars, comfortable margin) 1.21 times, while the opposite corners are under-represented by about as much. The middle of the table shows no concentration: the Track 2 cell (3 stars, middle margin) holds 0.99 times its expected count, which is what independence predicts, and hospitals with 3 stars are spread almost evenly across the three margin terciles. The memo expected Track 2 to be the plurality of hospitals. It is the smallest of the three Track cells (272 hospitals), and the largest cell in the whole table is Track 3 (421).

An independent test reached the same answer by a different route. A clustering analysis of hospitals on margin and PSI-90, with the selection criterion fixed in advance, found no separated groups at all, and when forced to find three, its groups bore no relation to the Track cells (an adjusted Rand index of −0.003, where 0 means no agreement beyond chance).

## 7.2 The memo's per-Track parameters

The memo's ROI models attach specific parameters to each Track. These do not affect the verdict, but they determine whether the models describe the hospitals that actually fall in each Track cell, and Table 7.1 checks each against the memo's own figures.

Table 7.1. The memo's per-Track parameters against the hospitals in each Track cell.

| Parameter | Memo | Observed | Result |
|---|---|---|---|
| Safety-net share, Track 1 | 50–70% | 47.8% (42.2% to 53.5%) | Partial |
| Safety-net share, Track 2 | 15–30% | 24.3% (19.6% to 29.7%) | Pass |
| Safety-net share, Track 3 | 5–10% | 11.9% (9.1% to 15.3%) | Partial |
| Beds, Tracks 1 / 2 / 3 | 175 / 300 / 500 | median 151 / 190 / 144 | Fail |
| Track 1 safety in the bottom quartile | a majority | 42.1% (36.6% to 47.8%) in the worst PSI-90 quartile | Fail |
| Track 2 is the largest group | the plurality | the smallest Track cell | Fail |

The safety-net gradient is the best-supported of the memo's parameters. Safety-net share (hospitals in the top quarter of disproportionate share percentage) falls from 47.8% in the Track 1 cell to 24.3% in Track 2 and 11.9% in Track 3, each within or a few points outside the memo's range, and the same gradient runs across the whole table rather than only the Track cells. The memo inferred those ranges without a published cross-tabulation, and they turned out close. Hospital size is the parameter that fails by the widest margin. Median bed counts are flat or inverted across the Tracks (the Track 3 cell's median is smaller than Track 1's), and the 500-bed Track 3 health system does not appear in these data. Because the memo's models scale quality-improvement cost, procedure volume and commercial revenue from bed count, the payment analysis replaces the per-Track inputs with each hospital's own revenue and payer mix. The Track 1 safety claim fails narrowly and in the expected direction: 42.1% of Track 1 hospitals are in the worst PSI-90 quartile, against 25% by chance, which is a clear enrichment but not a majority.

## 7.3 Two groups the table does not describe well

The 23 hospitals with operating margins below −100% are largely county and public safety-net hospitals, the clearest examples of Track 1's financial description. Of the 17 that have a star rating, all fall in the bottom margin tercile, but only 4 have the 1–2 star rating that would place them in Track 1; most have 3 stars. The hospitals that most resemble Track 1 on finances mostly do not resemble it on safety ratings.

The verdict also describes only hospitals that have a star rating. The 208 hospitals without a star rating (7.4% of the sample) are not a random subset: their median bed count is 28, against 168 for rated hospitals, and their mean reliability is 0.17, against 0.50. Many of the small safety-net hospitals that match Track 1's financial description are too small to receive a star rating, so they fall outside the test.

## 7.4 What the verdict means

Three qualifications apply to the verdict and the parameter checks. The star rating covers more than safety (it includes mortality, readmission, patient experience and timeliness), and reading its bands as Leapfrog grades is an inference, not a published crosswalk; the PSI-90 version of the test is the check on this, and it gives the same verdict. Rank terciles impose equal thirds on margin, which the memo's "thin, median, comfortable" language does not specify, but a different cut would move counts between cells without creating the concentration the continuous association lacks. And safety-net status is proxied by disproportionate share percentage, since the memo never defines it.

With those qualifications, the Tracks are a reasonable shorthand for a continuous gradient and a poor description of distinct groups of hospitals. A model built on three archetypes will describe the corners of the distribution adequately and the middle not at all. Analyses meant to guide investment across the whole hospital population, including the payment simulation, work better with each hospital's own characteristics than with the Track it is assigned to.
