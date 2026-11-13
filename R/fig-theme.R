# R/fig-theme.R  --  Task 5.1, the one visual grammar for the report figures.
#
# Sourced by R/12-figures.R. Base graphics only (the rest of the project draws
# with base R; no new package). Every final figure is drawn through these
# helpers, so the grammar is enforced by construction rather than by care:
#
#   * one surface, one ink set, hairline solid gridlines, no plot box;
#   * ONE primary hue (blue) for the headline series; a muted grey for the
#     comparison series (uncorrected, sensitivity, fixed-reliability, memo);
#     orange as the second categorical hue only where two series are both
#     primary (direct vs shared reliance); blue <-> red with a grey midpoint
#     for signed magnitudes (heatmaps). Nothing else;
#   * estimates are a dot on a 95% interval line, everywhere;
#   * text is never in a data colour -- identity comes from the key beside it;
#   * every figure carries a left-aligned title, a subtitle that says what is
#     plotted, and a source line naming the stage and file it was drawn from.
#
# Palette: the dataviz skill's validated reference instance (light surface).
# Blue / orange / aqua clear the all-pairs colour-vision-deficiency floor.

FIG <- list(
  surf    = "#ffffff",
  ink     = "#0b0b0b",
  ink2    = "#52514e",
  muted   = "#898781",
  grid    = "#e1e0d9",
  axis    = "#c3c2b7",
  band    = "#f0efec",             # memo ranges, reference bands
  blue    = "#2a78d6",             # primary series
  blue_dk = "#1c5cab",
  blue_lt = "#86b6ef",
  blue_xl = "#cde2fb",
  orange  = "#eb6834",             # second primary series, only where needed
  grey    = "#898781",             # comparison series
  red     = "#e34948",
  dpi     = 300,
  pt      = 8.5,
  width   = 7.5                    # inches: a full report text width
)

## Diverging ramp: blue (low) -- grey midpoint -- red (high), equal arms.
fig_diverging <- function(n = 101) {
  lo <- grDevices::colorRampPalette(c("#184f95", "#6da7ec", FIG$band))(ceiling(n / 2))
  hi <- grDevices::colorRampPalette(c(FIG$band, "#ec8a89", "#b3302f"))(ceiling(n / 2))
  c(lo, hi[-1])[seq_len(n)]
}
fig_div_col <- function(x, lim) {           # x in [-lim, lim] -> ramp colour
  pal <- fig_diverging(101)
  pal[pmax(1, pmin(101, round(50 * x / lim) + 51))]
}

## One file, one device. The figure function draws; this owns the device, so
## size, resolution, surface and type are identical across the suite.
FIG_DIR <- file.path("output", "figures", "final")
## Device: quartz on macOS (where this project runs; the cairo module needs
## XQuartz, absent here), cairo elsewhere. Both render Unicode and both are
## deterministic run to run on one machine; the manifest records which one.
FIG_DEVICE <- if (isTRUE(capabilities("aqua"))) "quartz" else "cairo"
fig_render <- function(name, height, draw, width = FIG$width) {
  if (!dir.exists(FIG_DIR)) dir.create(FIG_DIR, recursive = TRUE)
  f <- file.path(FIG_DIR, paste0(name, ".png"))
  grDevices::png(f, width = width, height = height, units = "in", res = FIG$dpi,
                 type = FIG_DEVICE, bg = FIG$surf, pointsize = FIG$pt, family = "sans")
  op <- par(no.readonly = TRUE)
  tryCatch(draw(), finally = { par(op); grDevices::dev.off() })
  cat(sprintf("  -> %s  (%.1f x %.1f in, %d dpi)\n", f, width, height, FIG$dpi))
  invisible(f)
}

## Outer frame: title and subtitle top-left, source line bottom-left.
## Call once per figure, before the first panel. `top`/`bottom` in lines.
fig_frame <- function(title, subtitle = NULL, source = NULL, top = 3.4, bottom = 1.6) {
  par(oma = c(bottom, 0.4, top, 0.4), bg = FIG$surf, family = "sans",
      col.axis = FIG$ink2, col.lab = FIG$ink2, fg = FIG$axis)
  FIG_PENDING <<- list(title = title, subtitle = subtitle, source = source, top = top)
}
FIG_PENDING <- NULL
## Titles are written after the first panel exists (mtext(outer=TRUE) needs a
## plot on the device); fig_panel does it on first use.
fig_flush_frame <- function() {
  P <- FIG_PENDING; if (is.null(P)) return(invisible())
  mtext(P$title, side = 3, outer = TRUE, line = P$top - 1.3, adj = 0, font = 2,
        cex = 1.25, col = FIG$ink)
  if (!is.null(P$subtitle))
    mtext(P$subtitle, side = 3, outer = TRUE, line = P$top - 2.5, adj = 0,
          cex = 0.88, col = FIG$ink2)
  if (!is.null(P$source))
    mtext(P$source, side = 1, outer = TRUE, line = 0.55, adj = 0, cex = 0.72, col = FIG$muted)
  FIG_PENDING <<- NULL
}

## layout() shrinks text for 3+ rows/columns (cex 0.66) and 2x2 (0.83); the
## suite holds one type size, so every layout goes through here.
fig_layout <- function(...) { layout(...); par(cex = 1); invisible() }

## Ink for text set inside a coloured fill: white on dark fills, ink on light.
fig_on <- function(fill) {
  m <- grDevices::col2rgb(fill) / 255
  lum <- 0.2126 * m[1, ] + 0.7152 * m[2, ] + 0.0722 * m[3, ]
  ifelse(lum < 0.45, FIG$surf, FIG$ink)
}

## Axis labels as individual mtext calls, so none is silently dropped for overlap.
fig_xlabels <- function(at, labels, line = 0.1, cex = 0.86, col = FIG$ink2, font = 1) {
  for (i in seq_along(at)) mtext(labels[i], side = 1, at = at[i], line = line, cex = cex, col = col,
                                 font = font, padj = 1)
}

## An empty panel with hairline gridlines. grid = "x", "y", "xy" or "".
## Axis tick labels only (no tick marks, no box); caller adds axis titles.
fig_panel <- function(xlim, ylim, grid = "x", xat = pretty(xlim, 5), yat = pretty(ylim, 5),
                      xlab = NULL, ylab = NULL, xfmt = format, yfmt = format,
                      xaxis = TRUE, yaxis = TRUE, log = "", ylab_line = 2.4) {
  plot.new(); plot.window(xlim, ylim, log = log, xaxs = "r", yaxs = "r")
  fig_flush_frame()
  xat <- xat[xat >= min(xlim) & xat <= max(xlim)]
  yat <- yat[yat >= min(ylim) & yat <= max(ylim)]
  if (grepl("x", grid)) abline(v = xat, col = FIG$grid, lwd = 0.6)
  if (grepl("y", grid)) abline(h = yat, col = FIG$grid, lwd = 0.6)
  if (xaxis && length(xat)) axis(1, at = xat, labels = xfmt(xat), lwd = 0, line = -0.6,
                                 cex.axis = 0.92, col.axis = FIG$ink2)
  if (yaxis && length(yat)) axis(2, at = yat, labels = yfmt(yat), lwd = 0, line = -0.6,
                                 las = 1, cex.axis = 0.92, col.axis = FIG$ink2)
  if (!is.null(xlab)) mtext(xlab, side = 1, line = 1.7, cex = 0.85, col = FIG$ink2)
  if (!is.null(ylab)) mtext(ylab, side = 2, line = ylab_line, cex = 0.85, col = FIG$ink2)
  invisible(list(xat = xat, yat = yat))
}

## Panel label: bold letter + short title, left-aligned to the panel's figure
## region (so it sits over the row labels, not the plot area).
fig_ptitle <- function(tag, text, line = 1.75) {
  mtext(paste0(tag, "   ", text), side = 3, line = line, adj = 0, cex = 0.95,
        col = FIG$ink, font = 2, at = grconvertX(0.01, "nfc", "user"))
}

## Row labels down the left of a dot plot.
fig_rowlabels <- function(y, labels, font = 1, col = FIG$ink, cex = 0.92) {
  axis(2, at = y, labels = labels, lwd = 0, las = 1, line = -0.6, cex.axis = cex,
       col.axis = col, font = font)
}

## A reference line (zero, one, a frame mean) -- the one non-grid line.
fig_ref <- function(v = NULL, h = NULL) {
  if (!is.null(v)) abline(v = v, col = FIG$ink2, lwd = 0.9)
  if (!is.null(h)) abline(h = h, col = FIG$ink2, lwd = 0.9)
}

## The estimate mark: a dot on its 95% interval. horiz = TRUE runs the
## interval along x at height y. open = TRUE for a comparison series.
fig_ci <- function(est, y, lo = NA, hi = NA, col = FIG$blue, open = FALSE, horiz = TRUE,
                   cex = 1.15, lwd = 1.8) {
  ok <- is.finite(lo) & is.finite(hi)
  if (any(ok)) {
    if (horiz) segments(lo[ok], y[ok], hi[ok], y[ok], col = col, lwd = lwd, lend = 1)
    else       segments(y[ok], lo[ok], y[ok], hi[ok], col = col, lwd = lwd, lend = 1)
  }
  xx <- if (horiz) est else y; yy <- if (horiz) y else est
  if (open) points(xx, yy, pch = 21, bg = FIG$surf, col = col, cex = cex, lwd = 1.6)
  else      points(xx, yy, pch = 21, bg = col, col = FIG$surf, cex = cex * 1.08, lwd = 1.1)
}

## A range bar (min..max over a set, no point estimate implied): thick, butt ends.
fig_range <- function(lo, hi, y, col = FIG$blue, lwd = 4.2) {
  segments(lo, y, hi, y, col = col, lwd = lwd, lend = 1)
}

## A horizontal key, drawn in the figure's top margin at the right.
## items: list of list(label, type = "dot"|"open"|"line"|"range"|"box"|"tick", col)
fig_key <- function(items, x = NULL, y = NULL, cex = 0.85) {
  op <- par(xpd = NA); on.exit(par(op))
  n <- length(items)
  lab <- vapply(items, `[[`, "", "label")
  sw <- strwidth(lab, cex = cex) + strwidth("MMM", cex = cex) * 1.1
  u <- par("usr")
  if (is.null(x)) x <- u[1]
  if (is.null(y)) y <- grconvertY(grconvertY(u[4], "user", "inches") + 0.08, "inches", "user")
  h <- strheight("M", cex = cex); k <- strwidth("M", cex = cex)
  for (i in seq_len(n)) {
    it <- items[[i]]; cx <- x + k * 0.6
    switch(it$type,
      dot   = points(cx, y, pch = 21, bg = it$col, col = FIG$surf, cex = 1.2),
      open  = points(cx, y, pch = 21, bg = FIG$surf, col = it$col, cex = 1.1, lwd = 1.6),
      line  = segments(cx - k * 0.7, y, cx + k * 0.7, y, col = it$col, lwd = 1.8),
      range = segments(cx - k * 0.7, y, cx + k * 0.7, y, col = it$col, lwd = 4.2, lend = 1),
      box   = rect(cx - k * 0.55, y - h * 0.5, cx + k * 0.55, y + h * 0.5, col = it$col, border = NA),
      tick  = segments(cx, y - h * 0.6, cx, y + h * 0.6, col = it$col, lwd = 1.2))
    text(x + k * (if (it$type %in% c("line", "range")) 1.9 else 1.6), y, lab[i], adj = c(0, 0.5), cex = cex, col = FIG$ink2)
    x <- x + sw[i]
  }
}

## Small annotation text in secondary ink.
fig_note <- function(x, y, label, adj = c(0, 0.5), cex = 0.8, col = FIG$ink2, ...) {
  op <- par(xpd = NA); on.exit(par(op))
  text(x, y, label, adj = adj, cex = cex, col = col, ...)
}

fmt_pct <- function(d = 0) function(x) sprintf(paste0("%.", d, "f%%"), 100 * x)
fmt_num <- function(d = 2) function(x) formatC(x, format = "f", digits = d)
fmt_sgn <- function(d = 2) function(x) ifelse(abs(x) < 1e-12, formatC(0, format = "f", digits = d),
                                             sprintf(paste0("%+.", d, "f"), x))

## Direct labels that would overprint are pushed apart vertically (a small
## iterative repel on the labels' text boxes); returns the label y positions.
fig_repel <- function(x, y, labels, cex = 0.8, iter = 200) {
  w <- strwidth(labels, cex = cex); h <- strheight("Mg", cex = cex) * 1.7
  ly <- y
  for (it in seq_len(iter)) {
    moved <- FALSE
    for (i in seq_along(x)) for (j in seq_along(x)) if (i < j) {
      ox <- min(x[i] + w[i], x[j] + w[j]) - max(x[i], x[j])
      oy <- h - abs(ly[i] - ly[j])
      if (ox > 0 && oy > 0) {
        d <- if (ly[i] >= ly[j]) 1 else -1
        ly[i] <- ly[i] + d * oy / 2 * 1.05; ly[j] <- ly[j] - d * oy / 2 * 1.05; moved <- TRUE
      }
    }
    if (!moved) break
  }
  ly
}
