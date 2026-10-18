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
oth[, `:=`(patent_id = as.character(patent_id), gvkey = as.character(gvkey))]
yrs <- range(pub$filing_year)
oth <- unique(oth[filing_year >= yrs[1] & filing_year <= yrs[2], .(patent_id, gvkey)])

# Firm set per patent in each build (a patent can belong to several firms)
key <- function(d) d[, .(firms = paste(sort(unique(gvkey)), collapse = "|")), by = patent_id]
pk <- key(pub); ok <- key(oth)
basis <- unique(pub[, .(patent_id, basis)])[, .(basis = paste(sort(unique(basis)), collapse = " + ")), by = patent_id]
m <- merge(pk, ok, by = "patent_id", all = TRUE, suffixes = c("_pub", "_oth"))
m <- merge(m, basis, by = "patent_id", all.x = TRUE)
m[, status := fifelse(is.na(firms_oth), "only in public build",
              fifelse(is.na(firms_pub), "only in other build",
              fifelse(firms_pub == firms_oth, "same firm(s)", "different firm(s)")))]

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
