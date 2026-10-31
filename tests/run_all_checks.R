# Runs every check on the correct fast version and on each of the ten deliberate bugs, and writes
# the results table ("catch matrix"): one row per version, one column per check, TRUE where the
# check flagged that version. Also writes a run record to logs/runs/.
# Usage (repo root): Rscript tests/run_all_checks.R [patent_class.csv] [firm_year.csv] [blind_output.csv] [snapshot.txt] [catch_matrix.csv]

suppressPackageStartupMessages({ library(data.table) })
for (f in c("R/runlog.R", "R/checks.R", "R/io.R", "R/new_classes_fast.R", "R/new_classes_slow.R", "tests/input_tests.R")) source(f)

args <- commandArgs(trailingOnly = TRUE)
pc_path <- if (length(args) >= 1) args[1] else "data/synthetic/patent_class.csv"
fy_path <- if (length(args) >= 2) args[2] else "data/synthetic/firm_year.csv"
blind_path <- if (length(args) >= 3) args[3] else "data/synthetic/out_blind.csv"
snap_path <- if (length(args) >= 4) args[4] else "logs/snapshots/new_classes_synthetic.txt"
matrix_path <- if (length(args) >= 5) args[5] else "report/catch_matrix.csv"

start_run("all check layers on the correct build and planted bugs",
          settings = list(base_years = 5, forward_years = 3, first_listed_only = TRUE),
          inputs = c(pc_path, fy_path, "tests/fixtures/fake_patent_class.csv", blind_path))

pc <- read_patent_class(pc_path); fy <- read_firm_year(fy_path)
fx_pc <- read_patent_class("tests/fixtures/fake_patent_class.csv")
fx_fy <- read_firm_year("tests/fixtures/fake_firm_year.csv")
fx_ex <- fread("tests/fixtures/fake_expected.csv")
slow <- as.data.table(build_new_classes_slow_by_firm(pc, fy))
blind <- if (file.exists(blind_path)) fread(blind_path, colClasses = c(firm_id = "character"), na.strings = c("NA", "")) else NULL
snapshot <- if (file.exists(snap_path)) readLines(snap_path)[1] else NA_character_

layers <- function(builder, label) {
  out <- tryCatch(as.data.table(builder(pc, fy)), error = function(e) NULL)
  if (is.null(out)) return(data.table(build = label, crashed = TRUE))
  # L1: data checks on the output (silent: results are kept, not printed)
  op <- options(checks.silent = label != "correct build"); chk <- check_new_classes_output(out, fy); options(op)
  l1 <- all(vapply(chk, function(x) isTRUE(x$passed), logical(1)))
  # L2: fake firms, whose answers were worked out from the definition before any version was run
  fo <- as.data.table(builder(fx_pc, fx_fy))
  m <- merge(fx_ex, fo, by = c("firm_id", "year"), suffixes = c("_exp", ""), all.x = TRUE)
  eq <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
  l2 <- nrow(fo) == nrow(fx_ex) && all(eq(m$new_classes_exp, m$new_classes)) &&
        all(eq(m$n_base_classes_exp, m$n_base_classes)) && all(eq(m$n_forward_classes_exp, m$n_forward_classes))
  # L3: input tests T1-T10
  rl <- run_input_tests(builder, pc, fy, ref = slow)
  l3 <- all(rl)
  # L4: agreement with the slow version
  c4 <- compare_outputs(out, slow, label, "slow")
  l4 <- nrow(out) == nrow(slow) && c4$n_agree == c4$n
  # L5: agreement with the blind rebuild (Python, written by a separate AI agent from the definition only)
  l5 <- if (is.null(blind)) NA else { c5 <- compare_outputs(out, blind, label, "blind"); nrow(out) == nrow(blind) && c5$n_agree == c5$n }
  # L6: the output's checksum must match the saved checksum of the approved output
  l6 <- if (is.na(snapshot)) NA else identical(data_hash(out[order(firm_id, year)]), snapshot)
  data.table(build = label, crashed = FALSE,
             data_checks = !l1, fake_firms = !l2, input_tests = !l3, slow_version = !l4,
             blind_rebuild = !l5, snapshot = !l6,
             input_tests_failed = paste(names(rl)[!rl], collapse = "; "),
             share_agree_slow = round(c4$share, 4))
}

idx <- fread("R/mutants/index.csv")
res <- list(layers(build_new_classes_fast, "correct build"))
for (i in seq_len(nrow(idx))) {
  e <- new.env(); sys.source(idx$file[i], envir = e)
  res[[length(res) + 1]] <- layers(e$build_new_classes_mutant, idx$id[i])
}
mat <- rbindlist(res, fill = TRUE)
mat <- merge(mat, idx[, .(build = id, name, based_on)], by = "build", all.x = TRUE, sort = FALSE)
lay <- c("data_checks", "fake_firms", "input_tests", "slow_version", "blind_rebuild", "snapshot")
mat[, caught_by_any := Reduce(`|`, lapply(.SD, function(x) isTRUE(x) | (!is.na(x) & x))), .SDcols = lay]
mat[, n_layers_caught := rowSums(as.matrix(.SD) == TRUE, na.rm = TRUE), .SDcols = lay]

dir.create("report", showWarnings = FALSE)
fwrite(mat, matrix_path)
log_check(list(check = "correct build passes every layer", passed = !mat[build == "correct build", any(unlist(.SD), na.rm = TRUE), .SDcols = lay]))
log_check(list(check = "every planted bug caught by at least one layer", passed = all(mat[build != "correct build", caught_by_any]),
               detail = sprintf("%d of %d caught", sum(mat[build != "correct build", caught_by_any]), nrow(idx))))
log_output("catch_matrix", mat)
log_output("new_classes_correct_build", as.data.table(build_new_classes_fast(pc, fy)))
rec <- end_run()

print(mat[, c("build", lay, "n_layers_caught", "input_tests_failed"), with = FALSE])
cat("\nRun record:", rec$path, "| failed checks:", rec$failed, "\n")
