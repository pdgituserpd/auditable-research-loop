
suppressPackageStartupMessages({ library(data.table) })

build_new_classes <- function(patent_class, firm_year,
                                   base_years = 5L, forward_years = 3L,
                                   first_listed_only = TRUE) {
  pc <- as.data.table(patent_class)
  if (first_listed_only) pc <- pc[cpc_seq == 0L]
  pc <- unique(pc[!is.na(cpc_subclass) & cpc_subclass != "",
                  .(firm_id, fy = as.integer(filing_year), cls = cpc_subclass)])

  base <- unique(pc[, .(year = fy + seq_len(base_years)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])
  fwd  <- unique(pc[, .(year = fy - seq_len(forward_years)), by = .(firm_id, cls, fy)][, .(firm_id, year, cls)])

  n_base <- base[, .(n_base_classes = .N), by = .(firm_id, year)]
  n_fwd  <- fwd[,  .(n_forward_classes = .N), by = .(firm_id, year)]
  n_new  <- fwd[!base, on = .(firm_id, year, cls)][, .(new_classes = .N), by = .(firm_id, year)]

  out <- unique(as.data.table(firm_year)[, .(firm_id, year = as.integer(year))])
  out <- n_base[out, on = .(firm_id, year)]
  out <- n_fwd[out, on = .(firm_id, year)]
  out <- n_new[out, on = .(firm_id, year)]
  out[is.na(n_base_classes), n_base_classes := 0L]
  out[is.na(n_forward_classes), n_forward_classes := 0L]
  out[is.na(new_classes), new_classes := 0L]
  out[n_base_classes == 0L, new_classes := NA_integer_]
  setcolorder(out, c("firm_id", "year", "n_base_classes", "n_forward_classes", "new_classes"))
  setorder(out, firm_id, year)
  out[]
}
