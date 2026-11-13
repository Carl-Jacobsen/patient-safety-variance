# F. Sources

The data files, with their addresses, retrieval dates and hashes, are in the project's provenance table. The sources below are those the methods and assumptions in this supplement rest on.

## F.1 Measures and program rules

Agency for Healthcare Research and Quality (2024). *Quality Indicator Empirical Methods.* Sections `F.4` and `F.5`, including `F.5.1` on the composite's standard error. `https://qualityindicators.ahrq.gov/Downloads/Resources/Publications/2024/Empirical_Methods_2024.pdf`

Centers for Medicare & Medicaid Services. *Patient Safety Indicator resources* for the PSI software release behind the FY 2026 scores: the measure FAQ, the fact sheet, the scientific acceptability report (with its table of component correlations) and the replication instructions. QualityNet, `https://qualitynet.cms.gov/inpatient/measures/psi/resources`

Centers for Medicare & Medicaid Services (2025). *FY 2026 Hospital-Acquired Condition Reduction Program scoring methodology* and the FY 2026 hospital-level HACRP file. `https://www.cms.gov/files/document/fy-2026-hac-reduction-program-methodology-infographic-updated-08/04/2025.pdf`; hospital file `https://data.cms.gov/provider-data/dataset/yq43-i98g`

Centers for Medicare & Medicaid Services. Care Compare provider data, the Hospital Service Area File, the IPPS Impact Files and the Healthcare Cost Report Information System (worksheet `S-3` Part I). Care Compare complications and deaths `https://data.cms.gov/provider-data/dataset/ynj2-r877`; IPPS Impact File `https://www.cms.gov/files/zip/fy2026-ipps-fr-impact-file.zip`; HCRIS `https://www.cms.gov/data-research/statistics-trends-reports/cost-reports/hospital-2010-form`; the remaining file addresses are in the provenance table.

Elevance Health (2024). *How can a company like Elevance Health help improve patient safety in hospitals?* `https://www.elevancehealth.com/our-approach-to-health/whole-health/improving-patient-safety-in-hospitals`

## F.2 Community measures

Centers for Disease Control and Prevention and Agency for Toxic Substances and Disease Registry (2022). *CDC/ATSDR Social Vulnerability Index*, tract and county files. `https://svi.cdc.gov/Documents/Data/2022/csv/states/SVI_2022_US.csv`; `https://svi.cdc.gov/Documents/Data/2022/csv/states_counties/SVI_2022_US_county.csv`

Kind, A. J. H. and Buckingham, W. R. (2018). Making neighborhood-disadvantage metrics accessible: the Neighborhood Atlas. *New England Journal of Medicine.* `https://doi.org/10.1056/NEJMp1802313`. The Area Deprivation Index's block-group ranks.

U.S. Census Bureau. American Community Survey five-year estimates, for the income concentration index, the uninsured and limited-English shares and the block-group populations, from the Census Data API `https://api.census.gov/data/2024/acs/acs5`.

## F.3 Methods

Biernacki, C., Celeux, G. and Govaert, G. (2000). Assessing a mixture model for clustering with the integrated completed likelihood. *IEEE Transactions on Pattern Analysis and Machine Intelligence.* `https://doi.org/10.1109/34.865189`

Breiman, L. (2001). Statistical modeling: the two cultures. *Statistical Science.* `https://doi.org/10.1214/ss/1009213726`. The Rashomon effect.

Fisher, A., Rudin, C. and Dominici, F. (2019). All models are wrong, but many are useful: learning a variable's importance by studying an entire class of prediction models simultaneously. *Journal of Machine Learning Research.* `https://www.jmlr.org/papers/v20/18-760.html`. Model reliance and model class reliance; the reported bounds cover the enumerated registry, which is narrower than the function classes that paper treats.

Lindeman, R. H., Merenda, P. F. and Gold, R. Z. (1980). *Introduction to Bivariate and Multivariate Analysis.* Scott, Foresman. The averaging over orders of entry used in the variance decomposition.

O'Donnell, O., van Doorslaer, E., Wagstaff, A. and Lindelow, M. (2008). *Analyzing Health Equity Using Household Survey Data.* World Bank. `https://doi.org/10.1596/978-0-8213-6933-3`. The concentration index.

Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in Surveys.* Wiley. `https://doi.org/10.1002/9780470316696`. The pooling rules.

Simonsohn, U., Simmons, J. P. and Nelson, L. D. (2020). Specification curve analysis. *Nature Human Behaviour.* `https://doi.org/10.1038/s41562-020-0912-z`

Tibshirani, R., Walther, G. and Hastie, T. (2001). Estimating the number of clusters in a data set via the gap statistic. *Journal of the Royal Statistical Society, Series B.* `https://doi.org/10.1111/1467-9868.00293`

## F.4 CASH2

Jewish Healthcare Foundation, CASH. *CASH2 memo, final version (recalibrated scenario analysis)*, `v6` (file `CASH2 memo - Final v6 (recalibrated scenario analysis).docx`); its verification script `verify_models.py`; the response to Michael's review; the Business Case Framework; and the CASH2 revision ledger and next-exercise definition kept with this project. Internal documents, which supply the payment scenarios' bonus band, revenue share and safety-net factor and the Track parameters, and which this project does not validate.
