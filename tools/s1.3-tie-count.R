# tools/s1.3-tie-count.R  --  Task S1.3, run once before the payment rerun.
#
# Counts the hospitals and dollars the September 30 pos_cf() misassigned in the
# stored draws (data/payment-sim.rds). It evaluates R/09-payment-sim.R up to its
# Sec 5 (inputs, fits from cache, the draw machinery and the identity test),
# then replays every stored draw from its seed with the OLD convention -- and
# requires each replayed row to equal the stored row exactly, which proves these
# are the draws the September 30 results came from -- while computing, for every
# scenario call, the counterfactual payment under BOTH conventions.
#
#   Rscript tools/s1.3-tie-count.R > output/tables/taskS1.3-ties.txt
#
# Writes output/tables/payment-ties-count.csv (per pool x scenario) and
# output/tables/payment-ties-strata.csv (base run, mean shift per stratum).

src <- readLines(file.path("R", "09-payment-sim.R"))
cut <- grep("^# 5\\.  THE PRIMARY RUN", src)
stopifnot(length(cut) == 1)
eval(parse(text = src[seq_len(cut - 1)]), envir = globalenv())

STORED <- readRDS(file.path("data", "payment-sim.rds"))
pos_cf_new <- pos_cf
pos_cf <- pos_cf_sep30                          # so qhip() reproduces the stored draws
qhip_orig <- qhip
LABS <- c(names(SCEN), "fixed")                 # the order one_draw() calls them in
TIE <- new.env(); TIE$k <- 0L; TIE$base_shift <- numeric(nQ); TIE$pool <- ""
TCOLS <- c("n_tied", "n_moved", "abs_usd", "net_usd", "max_usd")

qhip <- function(sc, pub, pubcf, head_rk, vb_rk, adi_rk, strata = FALSE, vbq = NULL, hdq = NULL) {
  o <- qhip_orig(sc, pub, pubcf, head_rk, vb_rk, adi_rk, strata, vbq, hdq)
  TIE$k <- TIE$k + 1L; lab <- LABS[(TIE$k - 1L) %% length(LABS) + 1L]
  R <- R_VAR[[sc$R]]; so <- score_of(pub, sc$w, sc$psi); zcf <- so$zfun(pubcf)
  Scf <- if (sc$psi) zcf else ifelse(nHAI > 0, sc$w * zcf + (1 - sc$w) * HAIM, zcf)
  ## Dis_new - Dis_old = R * (rate at the old cf position - rate at the new one)
  d <- R * (rate_of(pos_cf_sep30(so$S, Scf), sc$thr) - rate_of(pos_cf_new(so$S, Scf), sc$thr))
  srt <- sort(so$S)
  tied <- (findInterval(Scf, srt) - findInterval(Scf, srt, left.open = TRUE) - (so$S == Scf)) > 0
  TIE$M[TIE$k, ] <- c(sum(tied), sum(d != 0), sum(abs(d)), sum(d), max(abs(d)))   # preallocated
  if (lab == "base" && TIE$pool == "primary") TIE$base_shift <- TIE$base_shift + d
  o
}

replay <- function(pool, seed, stored, label) {
  nb <- as.integer(Sys.getenv("TIE_B", nrow(stored)))              # smoke runs only; the count uses all
  stored <- stored[seq_len(nb), , drop = FALSE]
  TIE$k <- 0L; TIE$pool <- label
  TIE$M <- matrix(NA_real_, nrow(stored) * length(LABS), length(TCOLS), dimnames = list(NULL, TCOLS))
  t0 <- Sys.time()
  r <- run_draws(1L, nrow(stored), pool, seed, new_acc())
  same <- identical(unname(r$rows), unname(stored))
  cat(sprintf("  %-8s %d draws replayed in %.1f min; identical to the stored draws: %s\n", label,
              nrow(stored), as.numeric(difftime(Sys.time(), t0, units = "mins")), same))
  stopifnot(same)
  stopifnot(TIE$k == nrow(TIE$M), !anyNA(TIE$M))
  M <- data.frame(pool = label, scenario = rep(LABS, nrow(stored)), TIE$M)
  do.call(rbind, lapply(LABS, function(s) { x <- M[M$scenario == s, ]
    data.frame(pool = label, scenario = s, draws = nrow(x),
               mean_tied = mean(x$n_tied), mean_moved = mean(x$n_moved), max_moved = max(x$n_moved),
               share_draws_any = mean(x$n_moved > 0),
               mean_abs_usd = mean(x$abs_usd), mean_net_usd = mean(x$net_usd),
               max_hosp_usd = max(x$max_usd), share_of_dis_total = NA_real_) }))
}

hdr("TASK S1.3  what the September 30 pos_cf() misassigned in the stored draws")
cat(sprintf("  stored: B = %d per pool, %d Q-HIP hospitals\n", STORED$B, nQ))
## each pool is cached on its own (about 25 min apiece), so the two can run in
## separate sessions; a cached pool is reused only for the full B
pool_run <- function(pool, seed, stored, label) {
  f <- file.path("data", sprintf("tie-count-%s.rds", label))
  if (file.exists(f) && Sys.getenv("TIE_B") == "") {
    z <- readRDS(f); cat(sprintf("  %-8s reused from %s (replayed identical: TRUE when saved)\n", label, f)); return(z) }
  z <- list(cnt = replay(pool, seed, stored, label), base_shift = TIE$base_shift)
  if (Sys.getenv("TIE_B") == "") saveRDS(z, f)
  z
}
if (Sys.getenv("TIE_POOL") == "metro") {
  pool_run(POOL_METRO, SEED + 1000000L, STORED$draws_metro, "metro"); quit(save = "no") }
RP <- pool_run(POOL_PRIMARY, SEED, STORED$draws, "primary")
TIE$base_shift <- RP$base_shift
if (Sys.getenv("TIE_POOL") == "primary") quit(save = "no")
RM <- pool_run(POOL_METRO, SEED + 1000000L, STORED$draws_metro, "metro")
CNT <- rbind(RP$cnt, RM$cnt)
## each scenario's misassignment against the size of its disadvantage-associated total
for (i in seq_len(nrow(CNT))) {
  col <- paste0(CNT$scenario[i], ".dis_total")
  D <- if (CNT$pool[i] == "primary") STORED$draws else STORED$draws_metro
  D <- D[seq_len(CNT$draws[i]), , drop = FALSE]
  if (col %in% colnames(D)) CNT$share_of_dis_total[i] <- CNT$mean_abs_usd[i] / abs(mean(D[, col]))
}
write.csv(CNT, file.path("output", "tables", "payment-ties-count.csv"), row.names = FALSE)
op <- options(width = 200); print(CNT, row.names = FALSE, digits = 4); options(op)

## the Task 4.3 strata: mean per-hospital shift in the disadvantage-associated
## amount, base run, primary pool
NB1 <- CNT$draws[CNT$pool == "primary"][1]
sh <- TIE$base_shift / NB1
ST <- data.frame(stratum = STRATA[grepl("^(adi_q|sn)", STRATA)])
ST$stored_dis_mean <- vapply(ST$stratum, function(k) mean(STORED$draws[seq_len(NB1), paste0("base.dis.", k)]), numeric(1))
stopifnot(identical(ST$stratum, c("sn0", "sn1", paste0("adi_q", 1:5))))
ST$tie_shift_mean <- unname(c(tapply(sh, factor(as.integer(SNQ), 0:1), mean), tapply(sh, factor(ADIQ, 1:5), mean)))
ST$corrected_dis_mean <- ST$stored_dis_mean + ST$tie_shift_mean
write.csv(ST, file.path("output", "tables", "payment-ties-strata.csv"), row.names = FALSE)
cat("\n  base run, primary pool: mean disadvantage-associated amount per hospital\n")
print(ST, row.names = FALSE, digits = 6)
cat("\n  output/tables/payment-ties-count.csv, output/tables/payment-ties-strata.csv\n")
