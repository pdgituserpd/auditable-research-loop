# Linkage cross-check: compares the public patent-to-firm links built by data/prepare_real.R
# with links from an independent build (here, the researcher's own DISCERN 2.0 pipeline, which
# uses licensed Compustat data and therefore is not in this repository).
# Only counts are written; no licensed data leaves the researcher's machine.
#
# Usage (repo root):
#   Rscript data/compare_links.R <public links.csv> <other links (.rds or .csv)> <label>
# The other file needs columns patent (or patent_id), gvkey, year (filing year).

suppressPackageStartupMessages({ library(data.table) })

args <- commandArgs(trailingOnly = TRUE)
pub_path <- args[1]; oth_path <- args[2]; label <- if (length(args) >= 3) args[3] else "public"

pub <- fread(pub_path, colClasses = list(character = c("patent_id", "gvkey")))
oth <- if (grepl("\\.rds$", oth_path)) as.data.table(readRDS(oth_path)) else fread(oth_path)
if ("patent" %in% names(oth)) setnames(oth, "patent", "patent_id")
if ("year" %in% names(oth)) setnames(oth, "year", "filing_year")
# GVKEY is a six-digit code with leading zeros ("001010"); a build that reads it as a number
# stores 1010. Both sides are written the same way before comparing. (The first run of this
# script skipped this and reported 90% of patents as linked to different firms.)
norm_gvkey <- function(x) formatC(as.integer(x), width = 6, flag = "0")
pub[, gvkey := norm_gvkey(gvkey)]
oth[, `:=`(patent_id = as.character(patent_id), gvkey = norm_gvkey(gvkey))]
yrs <- range(pub$filing_year)
oth <- unique(oth[filing_year >= yrs[1] & filing_year <= yrs[2], .(patent_id, gvkey)])

# Firm set per patent in each build (a patent can belong to several firms): the sets are the
# same when both builds have the same number of firms and all of them are shared.
pp <- unique(pub[, .(patent_id, gvkey)])
n_pub  <- pp[, .(n_pub = .N), by = patent_id]
n_oth  <- oth[, .(n_oth = .N), by = patent_id]
n_both <- pp[oth, on = .(patent_id, gvkey), nomatch = 0L][, .(n_both = .N), by = patent_id]
m <- Reduce(function(a, b) merge(a, b, by = "patent_id", all = TRUE), list(n_pub, n_oth, n_both))
m[is.na(n_both), n_both := 0L]
basis <- unique(pub[, .(patent_id, basis)])[, .(basis = paste(sort(unique(basis)), collapse = " + ")), by = patent_id]
m <- merge(m, basis, by = "patent_id", all.x = TRUE)
m[, status := fifelse(is.na(n_oth), "only in public build",
              fifelse(is.na(n_pub), "only in other build",
              fifelse(n_pub == n_oth & n_both == n_pub, "same firm(s)",
              fifelse(n_both > 0, "overlapping firm(s)", "different firm(s)"))))]

out <- rbind(
  m[, .(patents = .N), by = status][, basis := "all"],
  m[!is.na(basis), .(patents = .N), by = .(basis, status)]
)
out[, share_of_basis := round(patents / sum(patents), 4), by = basis]
out[, `:=`(public_build = label, filing_years = paste(yrs, collapse = "-"))]
setcolorder(out, c("public_build", "filing_years", "basis", "status", "patents", "share_of_basis"))
setorder(out, basis, status)
dir.create("report", showWarnings = FALSE)
fwrite(out, sprintf("report/link_agreement_%s.csv", label))
print(out)
