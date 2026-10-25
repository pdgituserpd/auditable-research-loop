# One worked case, walked through the code (decision D09).
#
# Picks one real firm-year and prints, step by step, what the slow plain build
# (R/new_classes_slow.R) does with it: the raw patents, the rows each rule keeps, the base set,
# the forward set and the result. The researcher reads this next to the slow build and the
# definition (spec/new_classes.md) and confirms each step by hand. The fast build's and the
# blind rebuild's answers are printed last, so the hand reading comes first.
#
# Usage (repo root):
#   Rscript handcheck/walkthrough.R <patent_class.csv> <firm_year.csv> [blind_output.csv] [seed]

suppressPackageStartupMessages({ library(data.table) })
source("R/io.R"); source("R/new_classes_slow.R"); source("R/new_classes_fast.R")

args <- commandArgs(trailingOnly = TRUE)
pc_path <- if (length(args) >= 1) args[1] else "data/synthetic/patent_class.csv"
fy_path <- if (length(args) >= 2) args[2] else "data/synthetic/firm_year.csv"
blind_path <- if (length(args) >= 3) args[3] else NA_character_
seed <- if (length(args) >= 4) as.integer(args[4]) else 20261025L

pc <- read_patent_class(pc_path)
fy <- unique(read_firm_year(fy_path)[, .(firm_id, year)])
first <- unique(pc[cpc_seq == 0L, .(firm_id, patent_id, filing_year, cpc_subclass)], by = c("firm_id", "patent_id"))

# A case worth walking: 12-30 patents listed from t-6 to t+4, at least one patent filed in year t
# (tests Rule 6), and at least one subclass found in both windows and one only in the forward window.
cnt <- function(f, lo, hi) first[firm_id == f & filing_year >= lo & filing_year <= hi]
set.seed(seed)
cand_firms <- first[, .N, by = firm_id][N >= 12 & N <= 400, firm_id]
pick <- NULL
for (f in sample(cand_firms)) {
  yrs <- intersect(fy[firm_id == f, year], first[firm_id == f, unique(filing_year)])
  for (t in sample(yrs)) {
    x <- cnt(f, t - 6, t + 4)
    if (nrow(x) < 12 || nrow(x) > 30) next
    b <- unique(x[filing_year >= t - 5 & filing_year <= t - 1 & !is.na(cpc_subclass), cpc_subclass])
    w <- unique(x[filing_year >= t + 1 & filing_year <= t + 3 & !is.na(cpc_subclass), cpc_subclass])
    if (x[filing_year == t, .N] > 0 && length(intersect(b, w)) > 0 && length(setdiff(w, b)) > 0) { pick <- list(f = f, t = t); break }
  }
  if (!is.null(pick)) break
}
if (is.null(pick)) stop("no suitable case found")
f <- pick$f; t <- pick$t

mine_all <- pc[firm_id == f]
x <- mine_all[filing_year >= t - 6 & filing_year <= t + 4][order(filing_year, patent_id, cpc_seq)]
out <- character()
p <- function(...) out <<- c(out, paste0(...))
tbl <- function(d) {
  d <- as.data.frame(d)
  p("| ", paste(names(d), collapse = " | "), " |"); p("|", paste(rep(" --- |", ncol(d)), collapse = ""))
  for (i in seq_len(nrow(d))) p("| ", paste(ifelse(is.na(unlist(d[i, ])), "(missing)", unlist(d[i, ])), collapse = " | "), " |")
  p("")
}

p("# Worked case: firm ", f, ", focal year ", t); p("")
p("Read this next to `R/new_classes_slow.R` and `spec/new_classes.md`. Tick each step when your own count agrees."); p("")
p("Patents are linked to the firm by rule A (decision D11). Each patent number links to its Google Patents page, if you want to check one against the source."); p("")
p("## Step 0. Every code on every patent this firm filed from ", t - 6, " to ", t + 4); p("")
tbl(x[, .(patent = sprintf("[%s](https://patents.google.com/patent/US%s)", patent_id, patent_id), filing_year, grant_year, cpc_seq, cpc_subclass)])

p("## Step 1. Rule 2: keep only the first-listed code (cpc_seq = 0)"); p("")
s1 <- x[cpc_seq == 0L]
p("- [ ] ", nrow(x), " rows become ", nrow(s1), " rows, one per patent."); p("")
p("## Step 2. Rule 3: drop rows with a missing subclass"); p("")
s2 <- s1[!is.na(cpc_subclass) & cpc_subclass != ""]
p("- [ ] ", nrow(s1) - nrow(s2), " row(s) dropped; ", nrow(s2), " remain."); p("")

p("## Step 3. Rule 4: base window, patents filed ", t - 5, " to ", t - 1); p("")
bw <- s2[filing_year >= t - 5 & filing_year <= t - 1]
tbl(bw[, .(patent_id, filing_year, cpc_subclass)])
B <- sort(unique(bw$cpc_subclass))
p("- [ ] Base set B = {", paste(B, collapse = ", "), "}: ", length(B), " subclasses."); p("")

p("## Step 4. Rule 5: forward window, patents filed ", t + 1, " to ", t + 3); p("")
fw <- s2[filing_year >= t + 1 & filing_year <= t + 3]
tbl(fw[, .(patent_id, filing_year, cpc_subclass)])
Fs <- sort(unique(fw$cpc_subclass))
p("- [ ] Forward set F = {", paste(Fs, collapse = ", "), "}: ", length(Fs), " subclasses."); p("")

p("## Step 5. Rule 6: patents filed in ", t, " itself, and in ", t - 6, " and ", t + 4, ", are in neither window"); p("")
tbl(s2[filing_year %in% c(t - 6, t, t + 4), .(patent_id, filing_year, cpc_subclass)])
p("- [ ] None of these rows appear in Step 3 or Step 4."); p("")

p("## Step 6. Rule 7: subclasses in F that are not in B"); p("")
N <- setdiff(Fs, B)
p("- [ ] New = {", paste(N, collapse = ", "), "}: **new_classes = ", if (length(B) == 0) "NA" else length(N), "**."); p("")

slow <- as.data.table(build_new_classes_slow(mine_all, data.table(firm_id = f, year = t)))
fast <- build_new_classes_fast(mine_all, data.table(firm_id = f, year = t))
p("## Step 7. What the three builds report (read after your own count)"); p("")
res <- data.table(build = c("slow plain build (R)", "fast build (R)"),
                  n_base_classes = c(slow$n_base_classes, fast$n_base_classes),
                  n_forward_classes = c(slow$n_forward_classes, fast$n_forward_classes),
                  new_classes = c(slow$new_classes, fast$new_classes))
if (!is.na(blind_path) && file.exists(blind_path)) {
  bl <- fread(blind_path, colClasses = c(firm_id = "character"), na.strings = c("NA", ""))[firm_id == f & year == t]
  res <- rbind(res, data.table(build = "blind rebuild (Python)", n_base_classes = bl$n_base_classes,
                               n_forward_classes = bl$n_forward_classes, new_classes = bl$new_classes))
}
tbl(res)
p("- [ ] Your count in Step 6 matches all three."); p("")

dir.create("handcheck/results", showWarnings = FALSE)
path <- sprintf("handcheck/results/walkthrough_%s_%d.md", f, t)
writeLines(out, path)
cat("Wrote", path, "\n")
