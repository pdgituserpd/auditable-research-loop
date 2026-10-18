# Random hand-check, step 2: compare the person's counts with the code's.
# Usage (repo root): Rscript handcheck/compare_handcheck.R <answers_filled.csv> <patent_class.csv> <firm_year.csv>
# With zero mismatches in n random cases, the error rate is below about 3/n with 95% confidence
# ("rule of three", Hanley & Lippman-Hand 1983). Tricky cases are reported separately.

suppressPackageStartupMessages({ library(data.table) })
source("R/io.R"); source("R/new_classes_fast.R")

args <- commandArgs(trailingOnly = TRUE)
ans <- fread(args[1], colClasses = "character")
pc <- read_patent_class(if (length(args) >= 2) args[2] else "data/synthetic/patent_class.csv")
fy <- read_firm_year(if (length(args) >= 3) args[3] else "data/synthetic/firm_year.csv")

code <- build_new_classes_fast(pc, fy)
ans[, year := as.integer(focal_year)]
m <- code[ans, on = .(firm_id, year)]
num <- function(x) suppressWarnings(as.integer(ifelse(toupper(x) %in% c("NA", ""), NA, x)))
m[, `:=`(hb = num(your_base_classes), hf = num(your_forward_classes), hn = num(your_new_classes))]
m[, match := (hb == n_base_classes) & (hf == n_forward_classes) &
              ((is.na(hn) & is.na(new_classes)) | (!is.na(hn) & !is.na(new_classes) & hn == new_classes))]
m[is.na(match), match := FALSE]

print(m[, .(case_id, firm_id, year, why, code_new = new_classes, your_new = hn, match)])
r <- m[why == "random"]
n <- nrow(r); k <- sum(!r$match)
cat(sprintf("\nRandom cases: %d of %d match.", n - k, n))
if (k == 0 && n > 0) cat(sprintf(" With no mismatches, the error rate is below about %.0f%% (95%% confidence, rule of three).", 100 * 3 / n))
cat(sprintf("\nTricky cases: %d of %d match.\n", sum(m[why != "random"]$match), nrow(m[why != "random"])))
