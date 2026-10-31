# Slow version of the same measure. It goes one firm-year at a time and follows the definition
# (spec/new_classes.md) line by line with simple loops, so a person can read it against the rules.
# It is written without data.table on purpose.

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

    # Rules 5 and 6: forward window t .. t+2, year t included
    in_fwd <- mine$filing_year >= t & mine$filing_year <= t + forward_years - 1
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

# Same function, run one firm at a time, for large data. Because of Rule 10 (firms are separate),
# this gives exactly the same result; it only avoids searching all patents for every firm-year.
# The function above is unchanged and is the one to read against the definition.
build_new_classes_slow_by_firm <- function(patent_class, firm_year, ...) {
  pc <- as.data.frame(patent_class, stringsAsFactors = FALSE)
  fy <- unique(as.data.frame(firm_year, stringsAsFactors = FALSE)[, c("firm_id", "year")])
  pc_by_firm <- split(pc, pc$firm_id)
  fy_by_firm <- split(fy, fy$firm_id)
  empty <- pc[0, , drop = FALSE]
  parts <- lapply(names(fy_by_firm), function(f) {
    mine <- if (is.null(pc_by_firm[[f]])) empty else pc_by_firm[[f]]
    build_new_classes_slow(mine, fy_by_firm[[f]], ...)
  })
  out <- do.call(rbind, parts)
  out <- out[order(out$firm_id, out$year), ]
  rownames(out) <- NULL
  out
}
