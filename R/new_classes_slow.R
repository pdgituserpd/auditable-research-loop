# Slow, plain version of the same measure: follows spec/new_classes.md line by line,
# with simple loops and no clever tricks, so a person can read it against the definition.
# It is deliberately written without data.table.

build_new_classes_slow <- function(patent_class, firm_year,
                                   base_years = 5, forward_years = 3,
                                   first_listed_only = TRUE) {
  pc <- as.data.frame(patent_class, stringsAsFactors = FALSE)
  fy <- unique(as.data.frame(firm_year, stringsAsFactors = FALSE)[, c("firm_id", "year")])

  # Rule 2: which codes count
  if (first_listed_only) pc <- pc[pc$cpc_seq == 0, ]
  # Rule 3: a missing class contributes no class
  pc <- pc[!is.na(pc$cpc_subclass) & pc$cpc_subclass != "", ]

  result <- vector("list", nrow(fy))
  for (r in seq_len(nrow(fy))) {
    firm <- fy$firm_id[r]
    t <- fy$year[r]
    mine <- pc[pc$firm_id == firm, ]                       # Rule 10: only this firm's patents

    # Rule 4: base window t-5 .. t-1 (Rule 1: by filing year)
    in_base <- mine$filing_year >= t - base_years & mine$filing_year <= t - 1
    base_set <- unique(mine$cpc_subclass[in_base])

    # Rule 5: forward window t+1 .. t+3
    in_fwd <- mine$filing_year >= t + 1 & mine$filing_year <= t + forward_years
    fwd_set <- unique(mine$cpc_subclass[in_fwd])

    # Rule 7: classes in the forward set that are not in the base set
    new_set <- setdiff(fwd_set, base_set)

    if (length(base_set) == 0) {
      value <- NA_integer_                                # Rule 8: empty base -> missing
    } else {
      value <- length(new_set)                            # Rule 9 included: empty forward -> 0
    }
    result[[r]] <- data.frame(firm_id = firm, year = as.integer(t),
                              n_base_classes = length(base_set),
                              n_forward_classes = length(fwd_set),
                              new_classes = value, stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, result)
  out <- out[order(out$firm_id, out$year), ]
  rownames(out) <- NULL
  out
}
