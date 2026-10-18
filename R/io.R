# Reading inputs with fixed column types, so nothing is guessed.
suppressPackageStartupMessages({ library(data.table) })

read_patent_class <- function(path) {
  fread(path, colClasses = c(patent_id = "character", firm_id = "character",
                             filing_year = "integer", grant_year = "integer",
                             cpc_seq = "integer", cpc_subclass = "character"),
        na.strings = c("", "NA"))
}

read_firm_year <- function(path) {
  fread(path, colClasses = c(firm_id = "character", year = "integer"))
}

# Compare two outputs firm-year by firm-year. Returns the share and the rows that differ.
compare_outputs <- function(a, b, label_a = "a", label_b = "b") {
  a <- as.data.table(a)[, .(firm_id, year, x = new_classes)]
  b <- as.data.table(b)[, .(firm_id, year, y = new_classes)]
  m <- merge(a, b, by = c("firm_id", "year"), all = TRUE)
  same <- (is.na(m$x) & is.na(m$y)) | (!is.na(m$x) & !is.na(m$y) & m$x == m$y)
  list(n = nrow(m), n_agree = sum(same), share = mean(same),
       differences = m[!same][, .(firm_id, year, value_a = x, value_b = y)],
       label = paste(label_a, "vs", label_b))
}
