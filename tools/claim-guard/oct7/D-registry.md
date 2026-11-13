# D. The number registry

Every number in the main report and in this supplement is produced by the project's build script (`make.R`) and checked against a registry before either document is built. One of its stages computes each number a section cites from the data products and stage outputs that earlier stages wrote, and records it with its section, a key, its value, every rendering the prose may use (a share may be written as a percentage or as a decimal) and its source table, log or definition. It then reads each section, extracts every numeric token, and stops the build if any token is not a registered rendering of a number in that section's block. Tokens that are not quantities are exempt by pattern: measure names such as PSI-90 or SVI 3, years, dates, cross-references to tables, figures and sections, and anything in a code span. A number that appears in two sections is computed once and copied, with its source marked as a copy, never recomputed.

The same stage enforces the review's wording rules. It fails on any causal verb in the report text, on a reliability-weighted share cited without its published-score pair, on a composite community share cited without the components model's share beside it, and on the claim-guard patterns that catch meanings the review retired, among them a fitted model set read as the whole space of models, a reliance bound cited without the state-tolerance bound, a claim of equal treatment without an equivalence range, a working assumption about missing data stated as established, a novelty claim, and a clustering result read beyond what its criteria agree on. Each guard pattern must still fire on the frozen September prose, or the stage stops, so a guard cannot go blind without notice.

The registry is shipped with this supplement as a separate file, `Variance Project - Number Registry.csv`, with one row for each registered number in each section. To trace a number in either document, find its section and rendering in that file; the source column names the table, log or definition it came from, and the key names the quantity.

Table S7. Registry rows by section.

| Section | Rows |
|---|---|
| Section 1 (summary) | 216 |
| Section 2 (the question and CASH2) | 18 |
| Section 3 (data) | 318 |
| Section 4 (methods) | 28 |
| Section 5 (decomposition) | 407 |
| Section 6 (community associations) | 905 |
| Section 7 (payment consequences) | 338 |
| Section 8 (what remains open) | 229 |

A registered number shows that the build script produced it, not that it sits beside the right claim. That second check is a reading of every sentence against the claim-to-evidence table, done separately before the documents are built.
