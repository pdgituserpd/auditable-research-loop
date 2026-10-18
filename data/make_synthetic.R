# Made-up patent data with the same layout as the real PatentsView extract.
# Used only to test the code end to end before running on real data.
# Like real merged data, it includes duplicate rows, missing classes and co-owned patents.
# Run from the repo root: Rscript data/make_synthetic.R

set.seed(20261018)
n_firms <- 200
classes <- c(sprintf("A%02dB", 1:15), sprintf("G%02dF", 1:15), sprintf("H%02dL", 1:10))
rows <- list(); k <- 0
for (f in seq_len(n_firms)) {
  firm <- sprintf("S%03d", f)
  first <- sample(1982:2010, 1); last <- min(2018, first + sample(5:30, 1))
  core <- sample(classes, sample(2:6, 1))
  rate <- runif(1, 0.3, 6)
  for (yr in first:last) {
    n_pat <- rpois(1, rate)
    for (p in seq_len(n_pat)) {
      k <- k + 1
      pid <- sprintf("X%07d", k)
      main <- if (runif(1) < 0.8) sample(core, 1) else sample(classes, 1)
      n_codes <- sample(1:3, 1, prob = c(0.5, 0.3, 0.2))
      codes <- c(main, sample(classes, n_codes - 1))
      if (runif(1) < 0.01) codes[1] <- NA            # missing class
      grant <- yr + sample(1:4, 1)
      rows[[length(rows) + 1]] <- data.frame(patent_id = pid, firm_id = firm, filing_year = yr,
        grant_year = grant, cpc_seq = seq_along(codes) - 1L, cpc_subclass = codes, stringsAsFactors = FALSE)
      if (runif(1) < 0.02) {                          # co-owned with another firm
        other <- sprintf("S%03d", sample(setdiff(seq_len(n_firms), f), 1))
        rows[[length(rows) + 1]] <- data.frame(patent_id = pid, firm_id = other, filing_year = yr,
          grant_year = grant, cpc_seq = seq_along(codes) - 1L, cpc_subclass = codes, stringsAsFactors = FALSE)
      }
    }
  }
}
pc <- do.call(rbind, rows)
dups <- pc[sample(nrow(pc), round(0.03 * nrow(pc))), ]    # duplicate rows, as after a messy merge
pc <- rbind(pc, dups)
pc <- pc[sample(nrow(pc)), ]

# Firm-year universe: firms with at least one patent filed 1982-2018, focal years 1987-2015
firms <- sort(unique(pc$firm_id))
fy <- expand.grid(firm_id = firms, year = 1987:2015, stringsAsFactors = FALSE)
fy_dups <- fy[sample(nrow(fy), 40), ]                       # a few duplicated firm-years, as in real panels
fy <- rbind(fy, fy_dups)

dir.create("data/synthetic", showWarnings = FALSE, recursive = TRUE)
write.csv(pc, "data/synthetic/patent_class.csv", row.names = FALSE, na = "")
write.csv(fy, "data/synthetic/firm_year.csv", row.names = FALSE)
cat("Wrote", nrow(pc), "patent-class rows for", length(firms), "firms;", nrow(fy), "firm-year rows (with duplicates)\n")
