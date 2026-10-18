# Random hand-check, step 2: compare the person's counts with the code's, and record the result.
# Usage (repo root): Rscript handcheck/compare_handcheck.R <answers_filled.csv> <patent_class.csv> <firm_year.csv> [--tool-test]
# With zero mismatches in n random cases, the error rate is below about 3/n with 95% confidence
# ("rule of three", Hanley & Lippman-Hand 1983). Tricky cases are reported separately.
# Only rows with all three counts filled in are scored, so the check can be done in sittings.

suppressPackageStartupMessages({ library(data.table) })
source("R/runlog.R"); source("R/io.R"); source("R/new_classes_fast.R")

args <- commandArgs(trailingOnly = TRUE)
ans_path <- args[1]
pc_path <- if (length(args) >= 2) args[2] else "data/synthetic/patent_class.csv"
fy_path <- if (length(args) >= 3) args[3] else "data/synthetic/firm_year.csv"

# A 4th argument "--tool-test" marks a test of this script with a machine-filled sheet, so the
# run record can never be mistaken for a real hand-check.
tool_test <- length(args) >= 4 && args[4] == "--tool-test"
purpose <- if (tool_test) "TOOL TEST of the hand-check scripts (sheet filled by a script, NOT a hand-check)" else
  "random hand-check: person's counts vs the code"
start_run(purpose, settings = list(tool_test = tool_test), inputs = c(ans_path, pc_path, fy_path))
# Keep a typed "NA" as text (it is an answer: empty base); only truly blank cells are blank
ans <- fread(ans_path, colClasses = "character", na.strings = "")
for (j in names(ans)) set(ans, which(is.na(ans[[j]])), j, "")
pc <- read_patent_class(pc_path); fy <- read_firm_year(fy_path)

code <- build_new_classes_fast(pc, fy)
ans[, year := as.integer(focal_year)]
m <- code[ans, on = .(firm_id, year)]
num <- function(x) suppressWarnings(as.integer(ifelse(toupper(trimws(x)) %in% c("NA", ""), NA, x)))
filled <- function(x) trimws(x) != ""
m <- m[filled(your_base_classes) & filled(your_forward_classes) & filled(your_new_classes)]
m[, `:=`(hb = num(your_base_classes), hf = num(your_forward_classes), hn = num(your_new_classes))]
m[, match := (hb == n_base_classes) & (hf == n_forward_classes) &
              ((is.na(hn) & is.na(new_classes)) | (!is.na(hn) & !is.na(new_classes) & hn == new_classes))]
m[is.na(match), match := FALSE]

out <- m[, .(case_id, firm_id, year, why, code_base = n_base_classes, your_base = hb,
             code_forward = n_forward_classes, your_forward = hf, code_new = new_classes, your_new = hn, match,
             source_filing_year_ok, source_owner_ok, source_subclass_present, minutes)]
print(out[match == FALSE])

r <- out[why == "random"]; n <- nrow(r); k <- sum(!r$match)
log_check(list(check = "hand-check: random cases match the code", passed = k == 0,
               detail = sprintf("%d of %d match", n - k, n)))
cat(sprintf("\nRandom cases scored: %d. Matches: %d. Mismatches: %d.", n, n - k, k))
if (k == 0 && n > 0) cat(sprintf(" With no mismatches, the error rate is below about %.1f%% (95%% confidence, rule of three).", 100 * 3 / n))
tr <- out[why != "random"]
log_check(list(check = "hand-check: tricky cases match the code", passed = all(tr$match),
               detail = sprintf("%d of %d match", sum(tr$match), nrow(tr))))
cat(sprintf("\nTricky cases: %d of %d match.\n", sum(tr$match), nrow(tr)))

yn <- function(x) sprintf("%d Y, %d N, %d blank", sum(toupper(x) == "Y"), sum(toupper(x) == "N"), sum(trimws(x) == ""))
cat("Source check, filing year:", yn(out$source_filing_year_ok), "\n")
cat("Source check, owner:      ", yn(out$source_owner_ok), "\n")
cat("Source check, subclass:   ", yn(out$source_subclass_present), "\n")
for (v in c("source_filing_year_ok", "source_owner_ok", "source_subclass_present"))
  log_check(list(check = paste("hand-check", v), passed = !any(toupper(out[[v]]) == "N"), detail = yn(out[[v]])))
mins <- suppressWarnings(as.numeric(out$minutes))
if (any(!is.na(mins))) cat(sprintf("Time: %.0f minutes over %d cases with a time recorded\n", sum(mins, na.rm = TRUE), sum(!is.na(mins))))

dir.create("handcheck/results", showWarnings = FALSE)
res_path <- sub("_answers_TO_FILL\\.csv$|\\.csv$", "_comparison.csv", file.path("handcheck/results", basename(ans_path)))
if (tool_test) res_path <- sub("\\.csv$", "_TOOLTEST.csv", res_path)
fwrite(out, res_path, na = "NA")
log_output("handcheck_comparison", out)
rec <- end_run()
cat("Comparison:", res_path, "| run record:", rec$path, "\n")
