# Builds the measure's two inputs (patent_class, firm_year) from public data only:
# PatentsView bulk tables and DISCERN 2.0.1 (Arora et al. 2024, https://zenodo.org/records/13619821).
#
# The steps follow the researcher's existing DISCERN 2.0 / PatentsView pipeline (its
# 01_prepare_patents.R), which is the precedent for every choice here. Where this script departs
# from it, the comment says so and why.
#
# Usage (repo root):
#   Rscript data/prepare_real.R <raw_dir> [link_rule] [out_dir]
#     raw_dir   folder holding g_patent.tsv.zip, g_application.tsv.zip, g_cpc_current.tsv.zip
#               and a discern/ subfolder with DISCERN's csv_files
#     link_rule A (default): DISCERN official application owner at filing; otherwise the
#                 grant-name match mapped to its owner in the calendar filing year
#               B: DISCERN's own grant-file owner (owner at the grant fiscal year)
#     out_dir   default data/real/<link_rule>
#
# Writes: patent_class.csv, firm_year.csv, links.csv, prep_log.csv in out_dir, and a copy of
# prep_log.csv in report/ (counts only, no data).

suppressPackageStartupMessages({ library(data.table) })
source("R/runlog.R")
setDTthreads(0L)

args <- commandArgs(trailingOnly = TRUE)
raw_dir   <- if (length(args) >= 1) args[1] else stop("give the folder with the raw files")
link_rule <- if (length(args) >= 2) toupper(args[2]) else "A"
out_dir   <- if (length(args) >= 3) args[3] else file.path("data/real", link_rule)
stopifnot(link_rule %in% c("A", "B"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

FILING_MIN <- 1982L; FILING_MAX <- 2018L      # decision D06: base from 1982, forward window ends 2018
FOCAL      <- 1987:2015                       # decision D06
GRANT_MAX  <- as.IDate("2024-12-31")          # same observation cutoff as the precedent pipeline

disc <- file.path(raw_dir, "discern")
inputs <- c(file.path(raw_dir, c("g_patent.tsv.zip", "g_application.tsv.zip", "g_cpc_current.tsv.zip")),
            file.path(disc, c("permno_gvkey.csv", "discern_uo_names.csv", "discern_sub_names.csv",
                              "discern_pat_grant_1980_2021.csv", "discern_pat_app_1980_2021.csv")))
miss <- inputs[!file.exists(inputs)]
if (length(miss)) stop("missing input files:\n", paste(miss, collapse = "\n"))

start_run(sprintf("prepare real data (link rule %s)", link_rule),
          settings = list(link_rule = link_rule, filing_years = c(FILING_MIN, FILING_MAX),
                          focal_years = range(FOCAL), grant_cutoff = as.character(GRANT_MAX)),
          inputs = inputs)

steps <- list()
note <- function(step, rows = NA, patents = NA, firms = NA, detail = "") {
  steps[[length(steps) + 1L]] <<- data.table(step = step, rows = rows, patents = patents,
                                             firms = firms, detail = detail)
  message(sprintf("%-55s rows=%s patents=%s firms=%s %s", step, rows, patents, firms, detail))
}
read_zip <- function(file, cols) {
  fread(cmd = sprintf("unzip -p '%s'", file.path(raw_dir, file)), select = cols,
        colClasses = list(character = "patent_id"), showProgress = FALSE)
}

# ---- 1. Granted utility patents and their filing dates (as in the precedent) -------------------
p <- read_zip("g_patent.tsv.zip", c("patent_id", "patent_type", "patent_date", "withdrawn"))
note("g_patent: all records", nrow(p), uniqueN(p$patent_id))
p <- p[patent_type == "utility" & withdrawn == 0L]
p[, grant_date := as.IDate(patent_date)]
p <- p[!is.na(grant_date) & grant_date <= GRANT_MAX, .(patent_id, grant_date)]
note("utility, not withdrawn, granted by 2024-12-31", nrow(p), uniqueN(p$patent_id))

app <- unique(read_zip("g_application.tsv.zip", c("patent_id", "filing_date")))
app[, filing_date := as.IDate(filing_date)]
app <- unique(app)
amb <- unique(app$patent_id[duplicated(app$patent_id)])
note("patents with more than one filing date (dropped, as in precedent)", length(amb), length(amb))
app <- app[!patent_id %in% amb]
p <- merge(p, app, by = "patent_id")
p[, `:=`(filing_year = as.integer(year(filing_date)), grant_year = as.integer(year(grant_date)))]
note("filing date found", nrow(p), uniqueN(p$patent_id))
note("filing date after grant date (kept, flagged as in precedent)", p[filing_date > grant_date, .N],
     p[filing_date > grant_date, .N])
rm(app); invisible(gc())

# ---- 2. DISCERN firm identifiers -------------------------------------------------------------
# PERMNO_ADJ (DISCERN's firm ID) to GVKEY, one row per fiscal year (as in precedent)
cross <- fread(file.path(disc, "permno_gvkey.csv"), colClasses = list(character = "gvkey"))
cross <- cross[!is.na(fyear1_adjust) & !is.na(fyearn_adjust) & fyear1_adjust <= fyearn_adjust]
cross <- unique(cross[, .(fyear = seq.int(fyear1_adjust, fyearn_adjust)), by = .(gvkey, permno_adj, fyear1_adjust, fyearn_adjust)][
  , .(gvkey, permno_adj, fyear)])

# Patent-to-firm links
if (link_rule == "A") {
  # A1. Official application owner. DISCERN's application file already carries the firm and the
  #     fiscal year at filing, so no licensed data is needed (as in precedent).
  a <- fread(file.path(disc, "discern_pat_app_1980_2021.csv"),
             select = c("patent_id", "permno_adj", "fyear"), colClasses = list(character = "patent_id"))
  a <- a[!is.na(patent_id) & nzchar(patent_id)]
  a <- merge(a, cross, by = c("permno_adj", "fyear"), allow.cartesian = TRUE)
  a <- unique(a[patent_id %chin% p$patent_id, .(patent_id, gvkey, basis = "A1 official application owner")])
  note("A1 links: official application owner", nrow(a), uniqueN(a$patent_id), uniqueN(a$gvkey))

  # A2. Grant-name match mapped to the name's owner at filing.
  #     DEPARTURE from precedent: the precedent picks the filing FISCAL year with each firm's
  #     fiscal-year-end month from Compustat, which is licensed and cannot be shared. Here the
  #     calendar filing year is used. This is exact for firms whose fiscal year ends in December.
  #     data/compare_links.R measures how often the two choices differ.
  nm <- rbindlist(lapply(c("discern_uo_names.csv", "discern_sub_names.csv"),
                         function(f) fread(file.path(disc, f))), fill = TRUE)
  iv <- unique(rbindlist(lapply(0:5, function(k) nm[, .(id_name, sample,
           permno_adj = get(paste0("permno_adj", k)), start = get(paste0("fyear", k)), end = get(paste0("nyear", k)))])))
  iv <- iv[!is.na(permno_adj) & permno_adj != 99999 & !is.na(start) & !is.na(end) & start <= end]
  own <- unique(iv[, .(fyear = seq.int(start, end)), by = .(id_name, sample, permno_adj, start, end)][
    , .(id_name, sample, permno_adj, fyear)])
  own <- merge(own, cross, by = c("permno_adj", "fyear"), allow.cartesian = TRUE)

  g <- fread(file.path(disc, "discern_pat_grant_1980_2021.csv"),
             select = c("patent_id", "id_name", "sample"), colClasses = list(character = "patent_id"))
  g <- unique(g)[!patent_id %chin% a$patent_id]
  g <- merge(g, p[, .(patent_id, fyear = filing_year)], by = "patent_id")
  g <- merge(g, own, by = c("id_name", "sample", "fyear"), allow.cartesian = TRUE)
  g <- unique(g[, .(patent_id, gvkey, basis = "A2 grant-name owner at calendar filing year")])
  note("A2 links: grant-name owner at filing (patents not in A1)", nrow(g), uniqueN(g$patent_id), uniqueN(g$gvkey))
  links <- rbind(a, g)
  rm(a, g, nm, iv, own)
} else {
  # B. DISCERN's own convention: the owner its grant file assigns at the grant fiscal year.
  g <- fread(file.path(disc, "discern_pat_grant_1980_2021.csv"),
             select = c("patent_id", "permno_adj", "fyear"), colClasses = list(character = "patent_id"))
  g <- g[!is.na(permno_adj) & permno_adj != 99999]
  g <- merge(g, cross, by = c("permno_adj", "fyear"), allow.cartesian = TRUE)
  links <- unique(g[patent_id %chin% p$patent_id, .(patent_id, gvkey, basis = "B DISCERN grant-file owner")])
  rm(g)
}
invisible(gc())

links <- merge(links, p[, .(patent_id, filing_year, grant_year)], by = "patent_id")
links <- links[filing_year >= FILING_MIN & filing_year <= FILING_MAX]
note(sprintf("links with filing year %d-%d", FILING_MIN, FILING_MAX), nrow(links), uniqueN(links$patent_id), uniqueN(links$gvkey))
multi <- links[, uniqueN(gvkey), by = patent_id][V1 > 1, .N]
note("patents linked to more than one firm (each firm counts it)", multi, multi)

# ---- 3. CPC subclasses (current, retrospective classification, as in precedent) --------------
cpc <- read_zip("g_cpc_current.tsv.zip", c("patent_id", "cpc_sequence", "cpc_subclass"))
note("g_cpc_current: all codes", nrow(cpc), uniqueN(cpc$patent_id))
cpc <- cpc[patent_id %chin% links$patent_id]
invisible(gc())
cpc[cpc_subclass == "", cpc_subclass := NA_character_]
# one row per patent x subclass, keeping the subclass's first position on the patent; the
# first-listed code (sequence 0) therefore keeps sequence 0
cpc <- cpc[!is.na(cpc_subclass), .(cpc_seq = as.integer(min(cpc_sequence))), by = .(patent_id, cpc_subclass)]
note("linked patents with CPC codes (distinct subclasses)", nrow(cpc), uniqueN(cpc$patent_id))
no_cpc <- setdiff(unique(links$patent_id), cpc$patent_id)
no_first <- setdiff(unique(cpc$patent_id), cpc[cpc_seq == 0L, patent_id])
note("linked patents with no CPC code (kept with a missing class)", length(no_cpc), length(no_cpc))
note("patents with codes but no first-listed code (no class under the default)", length(no_first), length(no_first))
cpc <- rbind(cpc, data.table(patent_id = no_cpc, cpc_subclass = NA_character_, cpc_seq = 0L))

pc <- merge(links[, .(patent_id, firm_id = gvkey, filing_year, grant_year)], cpc,
            by = "patent_id", allow.cartesian = TRUE)
setcolorder(pc, c("patent_id", "firm_id", "filing_year", "grant_year", "cpc_seq", "cpc_subclass"))
setorder(pc, firm_id, filing_year, patent_id, cpc_seq)
note("patent_class rows (patent x firm x subclass)", nrow(pc), uniqueN(pc$patent_id), uniqueN(pc$firm_id))
note("distinct first-listed subclasses", pc[cpc_seq == 0L & !is.na(cpc_subclass), uniqueN(cpc_subclass)])

# ---- 4. Firm-years: firms with at least one patent filed 1982-2018 (D08), focal years 1987-2015
fy <- CJ(firm_id = sort(unique(pc$firm_id)), year = FOCAL)
note("firm_year rows", nrow(fy), NA, uniqueN(fy$firm_id))

fwrite(pc, file.path(out_dir, "patent_class.csv"), na = "NA")
fwrite(fy, file.path(out_dir, "firm_year.csv"))
fwrite(links[, .(patent_id, gvkey, basis, filing_year)], file.path(out_dir, "links.csv"))
log <- rbindlist(steps); log[, link_rule := link_rule]
fwrite(log, file.path(out_dir, "prep_log.csv"))
dir.create("report", showWarnings = FALSE)
fwrite(log, sprintf("report/real_prep_log_%s.csv", link_rule))
log_output("patent_class", pc[, .(n = .N), by = .(firm_id, filing_year)])
log_output("firm_year", fy)
rec <- end_run(sprintf("real-data inputs written to %s", out_dir))
cat("Done. Run record:", rec$path, "\n")
