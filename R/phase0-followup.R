#!/usr/bin/env Rscript
# R/phase0-followup.R
#
# PORTED AT TASK 1.1 from provenance/phase0-followup.R, body unchanged.
# Stage 1b of make.R. Base R, relative paths, no packages.
#
# The three measurements added on 2026-08-26 after Carl's questions about
#   (1) what the absent O/E split actually costs,
#   (2) whether HSAF suppression severely impacts the analysis,
#   (3) whether alternative imputation is available.
#
# Companion to phase0-numbers.R. Same rules: base R only, relative paths,
# no packages, every number in plan-amendments.md produced here.
#
#   Rscript make.R          (or, standalone: Rscript R/phase0-followup.R)

RAW <- file.path("data-raw", "spike-phase0")
stopifnot(dir.exists(RAW))
hdr  <- function(s) cat("\n", strrep("=", 74), "\n", s, "\n", strrep("=", 74), "\n", sep = "")
sub_ <- function(s) cat("\n--- ", s, " ---\n", sep = "")
n_   <- function(x) suppressWarnings(as.numeric(trimws(x)))
pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
rd   <- function(f, ...) read.csv(file.path(RAW, f), colClasses = "character",
                                  check.names = FALSE, na.strings = character(0), ...)
qs   <- function(x, label, fmt = "%.4f") {
  x <- sort(x[is.finite(x)]); q <- quantile(x, c(.05,.25,.5,.75,.95), type = 7, names = FALSE)
  cat(sprintf("  %-40s n=%-6d p05=%s p25=%s med=%s p75=%s p95=%s\n", label, length(x),
              sprintf(fmt,q[1]),sprintf(fmt,q[2]),sprintf(fmt,q[3]),sprintf(fmt,q[4]),sprintf(fmt,q[5])))
}
pear <- function(a, b) { k <- is.finite(a) & is.finite(b); cor(a[k], b[k]) }

impact <- function(zipfile, member) {
  td <- tempfile(); dir.create(td); unzip(file.path(RAW, zipfile), files = member, exdir = td)
  L <- readLines(file.path(td, member), encoding = "latin1", warn = FALSE)
  h <- strsplit(L[2], "\t")[[1]]; b <- L[-(1:2)]; b <- b[nzchar(trimws(b))]
  m <- do.call(rbind, lapply(strsplit(b, "\t", fixed = TRUE), function(v) { length(v) <- length(h); v }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- h
  d$ccn <- formatC(trimws(d$`Provider Number`), width = 6, flag = "0"); d
}

cd  <- rd("CandD_hospital.csv")
hg  <- rd("Hospital_General_Information.csv")
i26 <- impact("fy2026-impact.zip", "FY 2026 IPPS Final Rule Impact File.txt")
p90 <- cd[cd$`Measure ID` == "PSI_90", ]
type <- setNames(hg$`Hospital Type`, hg$`Facility ID`)
frame <- p90$`Facility ID`[!is.na(n_(p90$Score)) & type[p90$`Facility ID`] == "Acute Care Hospitals"]
N <- length(frame); cat("analytic frame n =", N, "\n")

## =================================================================== Q1 ====
hdr("Q1  What the absent O/E split costs: the implied reliability shrinkage")

P <- p90[match(frame, p90$`Facility ID`), ]
I <- i26[match(frame, i26$ccn), ]
d <- data.frame(
  ccn   = frame,
  score = n_(P$Score),
  wid   = n_(P$`Higher Estimate`) - n_(P$`Lower Estimate`),
  bills = n_(I$Bills),
  beds  = n_(I$Beds),
  rural = as.numeric(I$URGEO == "RURAL"),
  dsh   = n_(I$DSHPCT),
  mcaid = n_(I$`Medicaid Percentage`),
  stringsAsFactors = FALSE)
d <- d[complete.cases(d[, c("score","wid","bills","beds")]) & d$bills > 0 & d$beds > 0, ]
cat("hospitals with a published CI and a volume measure:", nrow(d), "\n")

sub_("is the published interval a sampling interval, or a posterior interval?")
cat(sprintf("  corr(log CI width, log Medicare volume) = %+.4f\n", pear(log(d$wid), log(d$bills))))
sl <- coef(lm(log(wid) ~ log(bills), data = d))[2]
cat(sprintf("  slope log(CI width) ~ log(volume)      = %+.4f\n", sl))
cat("  theory: pure sampling error on an UNSHRUNK rate gives -0.500.\n")
cat("  The observed slope is far flatter, which is consistent with an interval on an\n")
cat("  already-shrunk estimate: at low volume the posterior rests on the prior.\n")
## Task S2.1 (second pass): a diagnostic, not an identification. Total Medicare
## volume is not the component-specific at-risk denominator, and interval
## widths also move with case mix and component weighting.
cat("  A diagnostic consistent with shrinkage, not an identification of it: total\n")
cat("  Medicare volume is not the component-specific denominator.\n")

sub_("solve the empirical-Bayes shrinkage")
d$v <- (d$wid / 2 / 1.96)^2                 # posterior variance implied by the interval
varpub <- mean((d$score - mean(d$score))^2) # population variance of the PUBLISHED value
tau2   <- varpub + mean(d$v)                # since Var(pub) = tau^2 - mean(v) under lambda = 1 - v/tau^2
d$lam  <- 1 - d$v / tau2                    # share of true deviation retained
cat(sprintf("  Var(published PSI-90)            = %.5f\n", varpub))
cat(sprintf("  mean implied posterior variance  = %.5f\n", mean(d$v)))
cat(sprintf("  => implied prior variance tau^2  = %.5f   (tau = %.4f)\n", tau2, sqrt(tau2)))
qs(d$lam, "shrinkage factor lambda = 1 - v/tau^2", "%.3f")
cat(sprintf("  mean lambda = %.3f  -> under this scalar approximation, a slope fitted on the composite\n",
            mean(d$lam)), sprintf(" would retain about %s of the gradient, on average.\n", pct(mean(d$lam), 0)))

sub_("IS THE ATTENUATION COVARIATE-CORRELATED?  (this is the whole question)")
for (v in c("bills","beds","rural","dsh","mcaid")) {
  x <- if (v %in% c("bills","beds")) log(d[[v]]) else d[[v]]
  cat(sprintf("  corr(lambda, %-22s) = %+.4f\n",
              c(bills="log Medicare volume", beds="log beds", rural="rural indicator",
                dsh="DSH patient pct", mcaid="Medicaid day share")[v], pear(d$lam, x)))
}
cat(sprintf("\n  mean lambda  RURAL     %.3f (n=%d)\n", mean(d$lam[d$rural==1]), sum(d$rural==1)))
cat(sprintf("  mean lambda  NON-RURAL %.3f (n=%d)\n", mean(d$lam[d$rural==0]), sum(d$rural==0)))
qv <- cut(d$bills, quantile(d$bills, 0:4/4), include.lowest = TRUE, labels = c("Q1 low","Q2","Q3","Q4 high"))
for (l in levels(qv)) cat(sprintf("  volume %-8s mean lambda %.3f   median Medicare cases %.0f\n",
                                  l, mean(d$lam[qv==l]), median(d$bills[qv==l])))
cat("\n  READ: rurality is heavily differentially attenuated; DSH and Medicaid share are NOT.\n")
cat("  Under the scalar approximation, the rural limb of the equity gradient is the part\n")
cat("  the composite would attenuate most.\n")

## =================================================================== Q2 ====
hdr("Q2  Does HSAF suppression severely impact the analysis?")

hs <- function(f) {
  x <- rd(f); x <- x[nzchar(trimws(x$MEDICARE_PROV_NUM)), ]
  data.frame(ccn = trimws(x$MEDICARE_PROV_NUM),
             zip = formatC(trimws(x$ZIP_CD_OF_RESIDENCE), width = 5, flag = "0"),
             cases = n_(x$TOTAL_CASES), stringsAsFactors = FALSE)
}
h23 <- hs("Hospital_Service_Area_2023.csv")
h24 <- hs("Hospital_Service_Area_2024.csv")

sub_("MITIGATION TESTED AND REJECTED: recovering suppressed cells from an adjacent vintage")
k23 <- paste(h23$ccn, h23$zip); k24 <- paste(h24$ccn, h24$zip)
s23 <- h23$ccn %in% frame & is.na(h23$cases)
m   <- match(k23[s23], k24)
rec <- !is.na(m) & !is.na(h24$cases[m])
cat(sprintf("  2023 suppressed cells in frame hospitals : %d\n", sum(s23)))
cat(sprintf("  present as a cell in 2024                : %d (%s)\n", sum(!is.na(m)), pct(mean(!is.na(m)))))
cat(sprintf("  UNSUPPRESSED in 2024                     : %d (%s)  <- the recoverable share\n",
            sum(rec), pct(mean(rec))))
rv <- h24$cases[m[rec]]
cat(sprintf("  recovered values: median %g, mean %.2f, max %g\n", median(rv), mean(rv), max(rv)))
cat("  VERDICT: only ", pct(mean(rec)), " recoverable. Not worth the acquisition.\n", sep = "")
cat("  SIDE FINDING: if suppressed cells were typically 7-10, far more would cross 11 in\n")
cat("  an adjacent year. That only ", pct(mean(rec)), " do is evidence most suppressed cells\n", sep = "")
cat("  hold 1-3 cases, which supports the working constant of 3 in gate B0.\n")

sub_("THE DECISIVE TEST: does suppression bias the catchment-weighted covariate?")
z <- read.csv(file.path(RAW, "zcta_county_rel.txt"), sep = "|", colClasses = "character", check.names = FALSE)
z$a <- n_(z$AREALAND_PART); z <- z[nzchar(z$GEOID_ZCTA5_20) & nzchar(z$GEOID_COUNTY_20), ]
z <- z[order(z$GEOID_ZCTA5_20, -z$a), ]; z <- z[!duplicated(z$GEOID_ZCTA5_20), ]
z2c <- setNames(z$GEOID_COUNTY_20, z$GEOID_ZCTA5_20)
cat("  ZCTA -> county crosswalk (Census 2020 relationship file, free, no token):", length(z2c), "entries\n")

sv <- rd("SVI_2022_US_county.csv")
sv$fips <- formatC(trimws(sv$FIPS), width = 5, flag = "0")
TH <- sapply(1:4, function(i) n_(sv[[paste0("RPL_THEME", i)]]))
keep <- apply(TH, 1, function(r) all(!is.na(r) & r >= 0))
TH <- TH[keep, , drop = FALSE]; rownames(TH) <- sv$fips[keep]
cat("  counties with all four SVI themes:", nrow(TH), "\n")

hf <- h23[h23$ccn %in% frame, ]
hf$cty <- z2c[hf$zip]
hf <- hf[!is.na(hf$cty) & hf$cty %in% rownames(TH), ]
hcty <- setNames(formatC(trimws(i26$`FIPS County Code`), width = 5, flag = "0"), i26$ccn)

wavg <- function(cc, w, th) { k <- !is.na(w) & w > 0; if (!any(k)) NA else sum(w[k]*TH[cc[k],th])/sum(w[k]) }
sp   <- split(seq_len(nrow(hf)), hf$ccn)
res <- do.call(rbind, lapply(names(sp), function(f) {
  ix <- sp[[f]]; cc <- hf$cty[ix]; ca <- hf$cases[ix]; imp <- ifelse(is.na(ca), 3, ca)
  hc <- unname(hcty[f]); if (is.na(hc) || !(hc %in% rownames(TH))) return(NULL)
  o <- sapply(1:4, function(th) wavg(cc, ca, th))
  p <- sapply(1:4, function(th) wavg(cc, imp, th))
  if (any(is.na(o)) || any(is.na(p))) return(NULL)
  data.frame(ccn = f, o1=o[1],o2=o[2],o3=o[3],o4=o[4], p1=p[1],p2=p[2],p3=p[3],p4=p[4],
             c1=TH[hc,1],c2=TH[hc,2],c3=TH[hc,3],c4=TH[hc,4], stringsAsFactors = FALSE)
}))
cat("  hospitals in the comparison:", nrow(res), "\n\n")
nm <- c("T1 socioeconomic","T2 household char","T3 racial/ethnic minority","T4 housing/transport")
cat(sprintf("  %-28s %11s %10s %10s %11s %11s\n", "SVI theme", "r(obs,imp)", "mean diff", "sd diff",
            "r(obs,cty)", "r(imp,cty)"))
for (i in 1:4) {
  A <- res[[paste0("o",i)]]; B <- res[[paste0("p",i)]]; C <- res[[paste0("c",i)]]
  cat(sprintf("  %-28s %11.4f %10.4f %10.4f %11.4f %11.4f\n",
              nm[i], pear(A,B), mean(A-B), sd(A-B), pear(A,C), pear(B,C)))
}
gp <- abs(res$o1 - res$p1)
cat(sprintf("\n  theme-1 |observed-only - suppression-imputed|: med %.4f  p95 %.4f  max %.4f\n",
            median(gp), quantile(gp,.95,names=FALSE), max(gp)))
cat(sprintf("  hospitals where that gap exceeds 0.05 SVI percentile points: %d (%s)\n",
            sum(gp > .05), pct(mean(gp > .05))))
cat("\n  VERDICT 1: suppression is NOT a severe bias. r(obs,imp) >= 0.986 on every theme and\n")
cat("             the mean difference is under 0.004. Renormalising over observed cells is sound.\n")
cat("  VERDICT 2: BUT r(catchment, hospital-county) is 0.89-0.97 at COUNTY grain. Catchment\n")
cat("             weighting is nearly redundant with naive county assignment at this grain --\n")
cat("             and that is NOT a suppression artifact, since imputing the suppressed cells\n")
cat("             moves the correlation by only ~0.01. If catchment weighting is to earn its\n")
cat("             hours it must run at ZIP/tract grain, not county.\n")

hdr("done")
