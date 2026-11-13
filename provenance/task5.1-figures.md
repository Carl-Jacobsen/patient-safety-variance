# Task 5.1 — Build the figure suite

**Date:** 2026-09-28 · **Budget:** 10 h · **Status: complete. Phase 5 open.**

This is one new stage: `make.R` 38, `R/12-figures.R`, which runs in 2 s. The
shared grammar lives in `R/fig-theme.R`. The stage fits nothing and makes no
draws. It reads only tables and data products that stages 12–37 write, so a
figure can change only through the chain from raw data to those stages and
then to stage 38.

The per-stage working figures in `output/figures/` stay where they are as
diagnostics. **The report cites only `output/figures/final/`.**

---

## 1. The set

| File | Task | What it shows |
|---|---|---|
| `fig2-variance-decomposition` | 3.3 | Structure / community / policy shares. Composite shown uncorrected and λ-corrected; the components model beside it |
| `fig1-reliability-by-volume` | 2.2 | λ against Medicare volume (Q1 0.21 → Q4 0.76), and λ by hospital location (rural median 0.27 against 0.51 and 0.54 urban) |
| `fig3-spec-curve` | 3.7 | 3,344 specifications with a choice grid. The 194 composite Rashomon members are marked; each level's median sits at the right |
| `fig4-mcr-bounds` | 3.12 | MCR⁻ to MCR⁺ for Block B and Block A, each at all three tolerances, plus coefficient ranges for Block B and Block C |
| `fig5-tis-decomposition` | 3.14 | Direct against shared reliance, the TIS ranking, the flow matrix, and Shapley against TIS |
| `fig6-archetype-validation` | 3.16 | Observed/expected heatmap with Track cells outlined, safety-net share against the memo's range, beds against the memo's figures |
| `fig7-payment-distribution` | 4.3 | Bonus rate and bonus $ per hospital by ADI, model-implied disadvantage, safety-net status, and star × margin cell |
| `fig8-regressivity` | 4.4 | Concentration index per NPR dollar and per hospital, with the verdict for each; observed HACRP penalty share |

All eight are 7.5 in wide (one report text width), 300 dpi PNG. Reliability by
volume had a table (`reliability-by-volume.csv`) but no figure until now.

## 2. The grammar

Every figure is drawn through `fig-theme.R`, so the grammar is fixed by the
code rather than applied by hand:

- **Frame.** A left-aligned title that states the finding and a subtitle that
  says what is plotted. A source line names stage 38 and the input files.
  Panels are lettered A–D.
- **One primary hue (blue)** for the headline series, and **muted grey** for
  the comparison series (uncorrected, other tolerances, PSI-90 fixed, memo
  values). Orange appears only where two series are both primary (direct
  against shared reliance in fig 5, and Rashomon membership in fig 3).
  Blue ↔ red with a grey midpoint is used only for signed magnitudes (the fig 5
  flow matrix and the fig 6 obs/exp heatmap).
- **Estimates are drawn one way throughout:** a dot on its 95% interval line.
  A range over the Rashomon set is a thick bar, and the median model is a dot
  on that bar.
- **Gridlines are solid hairlines,** with no plot box and no tick marks. The
  only heavier line is a reference line (0, 1, or the frame mean).
- **Text is never set in a data colour.** Identity comes from the key beside
  the label. Text inside a coloured cell switches between ink and white by the
  fill's luminance.
- **One type size.** `layout()` quietly shrinks text in 3-column and 2×2
  layouts, to cex 0.66 and 0.83. `fig_layout()` resets it, so every figure
  uses the same point size.

The palette is the dataviz skill's validated reference set on a light surface.
Its first three hues (blue, orange, aqua) pass the all-pairs colour-vision
check. The suite uses only blue and orange as categorical hues.

## 3. Verify: regenerates from raw, no image editor

- `output/figures/final/MANIFEST.csv` records each PNG's sha256, bytes, device,
  dpi and inputs. **The manifest is committed; the images are not**
  (`.gitignore` exception, the same device as the `data-raw/*/MANIFEST.sha256`
  files).
- **Two consecutive runs of `Rscript make.R --stage 38` gave all 8 of 8
  figures byte-identical.** The stage compares every run against the previous
  manifest and names any figure that changed.
- The stage stops if `output/figures/final/` contains a PNG it did not draw.

One qualification. The device is **quartz** on this Mac, because R's cairo
module needs XQuartz, which is absent here. It falls back to cairo elsewhere.
Both devices are deterministic run to run, but the same figure will not have
the same hash across platforms. The manifest records the device so that
difference is visible.

## 4. The one upstream change

`R/04-spec-curve-report.R` (stage 25) now also writes
`output/tables/spec-curve-points.csv`, the standardised estimate and interval
for each specification. The dis_std standardisation therefore stays in one
place and is not copied into stage 38. **Stage 25's existing outputs are
byte-identical,** checked by md5 before and after on both CSVs and both PNGs.

## 5. Two things a reader will ask about

1. **Fig 2B (formerly 1B): components-model interval.** As first drawn, the
   interval excluded its own point estimate for structure and community. The
   cause was a resampling-unit bug in 3.3's bootstrap. It is fixed by 3.3
   amendment 1: HSAs are resampled whole, B = 1,000. The panel's axis is now
   fitted to the data and its note is data-driven.
2. **Fig 4A lists HHI under the disadvantage measures but outside the block.**
   The Block B group in 3.12 is the 10 disadvantage measures, and HHI is
   reported beside them. The row is labelled "HHI (outside the block)".

## 6. For 5.2 onward

Every section draft should cite `output/figures/final/figN-*.png`. The
numbers on each figure are printed in `output/tables/task5.1-figures.txt`,
which is how to check a caption against its figure.
