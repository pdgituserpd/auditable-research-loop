# Random hand-check, step 1: draw firm-years and write a worksheet for a person to work by hand.
#
# What the person gets for each case: every patent the firm filed from t-6 to t+4 (one year past
# each window on purpose), with its filing year and the subclass of its first-listed CPC code.
# The windows are NOT marked: the person applies the rules (base t-5..t-1, forward t+1..t+3, year t
# in neither) from the definition, so an off-by-one in the code cannot be copied into the sheet.
# One patent per case is also picked for a source check against the patent itself (Google Patents).
#
# Draws use raw patent counts only, never the measure, so the code's answer cannot steer the check.
# Usage (repo root):
#   Rscript handcheck/make_worksheet.R <patent_class.csv> <firm_year.csv> [n_random=100] [n_tricky=10] [seed]
# Decision D09: at least 100 random firm-years plus about 10 tricky ones.

suppressPackageStartupMessages({ library(data.table) })
source("R/io.R")

args <- commandArgs(trailingOnly = TRUE)
pc_path  <- if (length(args) >= 1) args[1] else "data/synthetic/patent_class.csv"
fy_path  <- if (length(args) >= 2) args[2] else "data/synthetic/firm_year.csv"
n_random <- if (length(args) >= 3) as.integer(args[3]) else 100L
n_tricky <- if (length(args) >= 4) as.integer(args[4]) else 10L
seed     <- if (length(args) >= 5) as.integer(args[5]) else 20261018L

pc <- read_patent_class(pc_path)
fy <- unique(read_firm_year(fy_path)[, .(firm_id, year)])

# One row per firm x patent with its first-listed subclass (may be missing)
first <- unique(pc[cpc_seq == 0L, .(firm_id, patent_id, filing_year, cpc_subclass)], by = c("firm_id", "patent_id"))

# Raw counts per firm and filing year, then summed over year ranges with a range join (fast on real data)
per_year <- first[, .(n = .N, n_missing = sum(is.na(cpc_subclass) | cpc_subclass == "")), by = .(firm_id, filing_year)]
count_range <- function(lo_off, hi_off, col = "n") {
  q <- fy[, .(firm_id, year, lo = year + lo_off, hi = year + hi_off)]
  r <- per_year[q, on = .(firm_id, filing_year >= lo, filing_year <= hi),
                .(v = sum(get(col), na.rm = TRUE)), by = .EACHI]
  r$v[is.na(r$v)] <- 0L
  r$v
}
fy[, `:=`(n_base_pat = count_range(-5, -1), n_fwd_pat = count_range(1, 3),
          n_year_t   = count_range(0, 0),
          n_outside  = count_range(-6, -6) + count_range(4, 4),
          n_missing  = count_range(-5, 3, "n_missing"),
          n_listed   = count_range(-6, 4))]

set.seed(seed)
# Random cases: firm-years whose base window has at least one patent (where the measure can exist).
# No cap on firm size: big firms are part of the population and are checked with a spreadsheet.
pool <- fy[n_base_pat > 0]
pick <- pool[sample(.N, min(.N, n_random))][, why := "random"]

# Tricky cases, chosen on purpose and reported separately (they do not count toward the error bound)
take <- function(d, k, label) {
  d <- d[!pick, on = .(firm_id, year)]
  if (nrow(d) == 0 || k <= 0) return(NULL)
  d[sample(.N, min(.N, k))][, why := label]
}
k <- n_tricky
tricky <- rbindlist(list(
  take(fy[n_base_pat == 0 & n_fwd_pat > 0],        ceiling(0.3 * k), "tricky: empty base"),
  take(fy[n_base_pat > 0 & n_year_t > 0],           ceiling(0.3 * k), "tricky: patents filed in year t"),
  take(fy[n_base_pat > 0 & n_outside > 0],          ceiling(0.2 * k), "tricky: patents just outside the windows"),
  take(fy[n_base_pat > 0 & n_missing > 0],          ceiling(0.2 * k), "tricky: patent with missing class")
), fill = TRUE)
tricky <- unique(tricky, by = c("firm_id", "year"))
if (nrow(tricky) > k) tricky <- tricky[seq_len(k)]
pick <- rbind(pick, tricky, fill = TRUE)
pick[, case_id := sprintf("H%03d", seq_len(.N))]

# Patent listing per case: t-6 to t+4, windows not marked
listing <- rbindlist(lapply(seq_len(nrow(pick)), function(i) {
  f <- pick$firm_id[i]; t <- pick$year[i]
  x <- first[firm_id == f & filing_year >= t - 6 & filing_year <= t + 4]
  if (nrow(x) == 0) x <- data.table(firm_id = f, patent_id = "(none)", filing_year = NA_integer_, cpc_subclass = NA_character_)
  x[, `:=`(case_id = pick$case_id[i], focal_year = t)]
  x[order(filing_year, patent_id)]
}))
listing[, google_patents := ifelse(patent_id == "(none)", "", paste0("https://patents.google.com/patent/US", patent_id))]
setnames(listing, "cpc_subclass", "first_listed_subclass")
setcolorder(listing, c("case_id", "firm_id", "focal_year", "patent_id", "filing_year", "first_listed_subclass", "google_patents"))

# One patent per case for the source check (from the case's own listing, chosen at random)
src <- listing[patent_id != "(none)", .SD[sample(.N, 1)], by = case_id][, .(case_id, source_patent = patent_id)]

answers <- merge(pick[, .(case_id, firm_id, focal_year = year, why, patents_listed = n_listed)], src, by = "case_id", all.x = TRUE)
answers[, `:=`(your_base_classes = "", your_forward_classes = "", your_new_classes = "",
               source_filing_year_ok = "", source_owner_ok = "", source_subclass_present = "", minutes = "", notes = "")]
setorder(answers, case_id)

# file names carry the data source (folder name, e.g. "synthetic" or "real") and the date
src_dir <- dirname(normalizePath(pc_path))
src_label <- basename(src_dir)
if (basename(dirname(src_dir)) == "real") src_label <- paste0("real_", src_label)   # e.g. data/real/A -> real_A
stamp <- paste0(src_label, "_", format(Sys.Date(), "%Y-%m-%d"))
dir.create("handcheck/sheets", showWarnings = FALSE)
fwrite(listing, sprintf("handcheck/sheets/%s_patents.csv", stamp), na = "")
fwrite(answers, sprintf("handcheck/sheets/%s_answers_TO_FILL.csv", stamp), na = "")

size <- cut(answers[why == "random", patents_listed], c(-Inf, 20, 60, Inf), labels = c("up to 20", "21-60", "over 60"))
cat(sprintf("Wrote %d cases (%d random, %d tricky) to handcheck/sheets/\n", nrow(answers),
            sum(answers$why == "random"), sum(answers$why != "random")))
cat("Random cases by number of patents listed:\n"); print(table(size))
cat(sprintf("Rough time: %.0f to %.0f hours (3-5 min for up to 20 patents, 6-10 for 21-60, 10-15 over 60, plus 1-2 min source check)\n",
            sum(c(4, 7, 11)[as.integer(size)]) / 60, sum(c(7, 12, 17)[as.integer(size)]) / 60))
cat("Instructions: handcheck/HOW_TO.md\n")
