# Random hand-check, step 1: draw firm-years and write a worksheet for a person to work by hand.
# The worksheet lists the firm's patents (number, filing year, first-listed CPC subclass) in both
# windows, so the person can count without the code. Patent numbers let the person look up a few
# on Google Patents and check against the source itself.
# Usage (repo root): Rscript handcheck/make_worksheet.R <patent_class.csv> <firm_year.csv> <n_random> [seed]

suppressPackageStartupMessages({ library(data.table) })
source("R/io.R")

args <- commandArgs(trailingOnly = TRUE)
pc_path <- if (length(args) >= 1) args[1] else "data/synthetic/patent_class.csv"
fy_path <- if (length(args) >= 2) args[2] else "data/synthetic/firm_year.csv"
n_random <- if (length(args) >= 3) as.integer(args[3]) else 5L
seed <- if (length(args) >= 4) as.integer(args[4]) else 20261018L

pc <- read_patent_class(pc_path); fy <- unique(read_firm_year(fy_path))
first <- unique(pc[cpc_seq == 0L, .(patent_id, firm_id, filing_year, cpc_subclass)])

# Which firm-years are eligible: the draw uses only the raw patent counts, never the measure itself,
# so the person's count is not steered by the code's answer.
cnt <- function(f, lo, hi) first[firm_id == f & filing_year >= lo & filing_year <= hi, .N]
fy[, n_base_pat := mapply(function(f, t) cnt(f, t - 5, t - 1), firm_id, year)]
fy[, n_fwd_pat  := mapply(function(f, t) cnt(f, t + 1, t + 3), firm_id, year)]

set.seed(seed)
pick <- fy[n_base_pat > 0 & n_fwd_pat > 0 & n_base_pat + n_fwd_pat <= 30][sample(.N, min(.N, n_random))]
pick[, why := "random"]
# Tricky cases, oversampled on purpose (reported separately)
tricky <- rbind(
  fy[n_base_pat == 0 & n_fwd_pat > 0][sample(.N, min(.N, 1))][, why := "tricky: empty base"],
  fy[n_base_pat > 0 & n_fwd_pat == 0][sample(.N, min(.N, 1))][, why := "tricky: no forward patents"]
)
pick <- rbind(pick, tricky[!pick, on = .(firm_id, year)])
pick[, case_id := sprintf("H%02d", seq_len(.N))]

listing <- rbindlist(lapply(seq_len(nrow(pick)), function(i) {
  f <- pick$firm_id[i]; t <- pick$year[i]
  b <- first[firm_id == f & filing_year >= t - 5 & filing_year <= t - 1][, window := sprintf("base (%d-%d)", t - 5, t - 1)]
  w <- first[firm_id == f & filing_year >= t + 1 & filing_year <= t + 3][, window := sprintf("forward (%d-%d)", t + 1, t + 3)]
  x <- rbind(b, w)
  if (nrow(x) == 0) x <- data.table(patent_id = "(none)", firm_id = f, filing_year = NA_integer_, cpc_subclass = NA_character_, window = "-")
  x[, `:=`(case_id = pick$case_id[i], focal_year = t)]
  x[order(window, filing_year, patent_id)]
}))
setcolorder(listing, c("case_id", "firm_id", "focal_year", "window", "patent_id", "filing_year", "cpc_subclass"))

answers <- pick[, .(case_id, firm_id, focal_year = year, why,
                    your_base_classes = "", your_forward_classes = "", your_new_classes = "", notes = "")]

stamp <- format(Sys.Date(), "%Y-%m-%d")
dir.create("handcheck/sheets", showWarnings = FALSE)
fwrite(listing, sprintf("handcheck/sheets/%s_patents.csv", stamp), na = "")
fwrite(answers, sprintf("handcheck/sheets/%s_answers_TO_FILL.csv", stamp))
cat("Wrote", nrow(pick), "cases (", sum(pick$why == "random"), "random ) to handcheck/sheets/\n")
cat("How to fill in: for each case, count the distinct subclasses in the base window, in the forward window,\n",
    "and the forward subclasses that are not in the base. Leave new_classes as NA if the base has no patents.\n")
