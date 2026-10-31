# Deliberate bugs (M1-M10): ten realistic mistakes, each made by changing one line of the fast
# version. The checks must catch each one. Run from the repository folder:
#   Rscript R/mutants/make_mutants.R
# Each bug goes in its own file, so the file can also be handed to an AI reviewer as it is.

src <- readLines("R/new_classes_fast.R")
txt <- paste(src, collapse = "\n")

mutants <- list(
  M1 = list(name = "Duplicate firm-years in the output (no de-duplication of the firm-year list)",
            based_on = "WRDS duplicate firm-years (E01)",
            from = "out <- unique(as.data.table(firm_year)[, .(firm_id, year = as.integer(year))])",
            to   = "out <- as.data.table(firm_year)[, .(firm_id, year = as.integer(year))]"),
  M2 = list(name = "Base window includes year t (t-5 to t)",
            based_on = "Common timing mistake",
            from = "base <- unique(pc[, .(year = fy + seq_len(base_years)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])",
            to   = "base <- unique(pc[, .(year = fy + 0:base_years), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])"),
  M3 = list(name = "Grant year used instead of filing year",
            based_on = "Common in patent studies",
            from = ".(firm_id, fy = as.integer(filing_year), cls = cpc_subclass)",
            to   = ".(firm_id, fy = as.integer(grant_year), cls = cpc_subclass)"),
  M4 = list(name = "Every code on the patent counted, not only the first-listed",
            based_on = "Common in patent studies",
            from = "if (first_listed_only) pc <- pc[cpc_seq == 0L]",
            to   = "pc <- pc"),
  M5 = list(name = "Empty base coded as 0 instead of missing",
            based_on = "Common missing-value mistake",
            from = "out[n_base_classes == 0L, new_classes := NA_integer_]",
            to   = "# (empty base left at 0)"),
  M6 = list(name = "Forward window shifted to t to t+2",
            based_on = "Common timing mistake",
            from = "fwd  <- unique(pc[, .(year = fy - seq_len(forward_years)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])",
            to   = "fwd  <- unique(pc[, .(year = fy - 0:(forward_years - 1L)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])"),
  M7 = list(name = "Firms mixed: base classes pooled across firms (firm left out of the join key)",
            based_on = "Common linking mistake",
            from = "n_new  <- fwd[!base, on = .(firm_id, year, cls)][, .(new_classes = .N), by = .(firm_id, year)]",
            to   = "n_new  <- fwd[!unique(base[, .(year, cls)]), on = .(year, cls)][, .(new_classes = .N), by = .(firm_id, year)]"),
  M8 = list(name = "Missing class counted as a class",
            based_on = "Common missing-value mistake",
            from = "pc <- unique(pc[!is.na(cpc_subclass) & cpc_subclass != \"\",",
            to   = "pc[is.na(cpc_subclass), cpc_subclass := \"NA\"]\n  pc <- unique(pc[TRUE,"),
  M10 = list(name = "Base window shifted one year (t-4 to t)",
            based_on = "Common timing mistake",
            from = "base <- unique(pc[, .(year = fy + seq_len(base_years)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])",
            to   = "base <- unique(pc[, .(year = fy + 0:(base_years - 1L)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])"),
  M9 = list(name = "Class cut to three characters (A01B and A01C treated as one class)",
            based_on = "Common string mistake",
            from = "cls = cpc_subclass)])",
            to   = "cls = substr(cpc_subclass, 1, 3))])")
)

dir.create("R/mutants", showWarnings = FALSE)
index <- data.frame(id = character(), name = character(), based_on = character(), file = character())
for (id in names(mutants)) {
  m <- mutants[[id]]
  stopifnot(grepl(m$from, txt, fixed = TRUE))
  mt <- sub(m$from, m$to, txt, fixed = TRUE)
  mt <- sub("build_new_classes_fast <- function", "build_new_classes_mutant <- function", mt, fixed = TRUE)
  f <- sprintf("R/mutants/%s.R", id)
  writeLines(c(sprintf("# PLANTED BUG %s: %s", id, m$name), mt), f)
  index[nrow(index) + 1, ] <- c(id, m$name, m$based_on, f)
}
write.csv(index, "R/mutants/index.csv", row.names = FALSE)
cat("Wrote", nrow(index), "planted bugs\n")
