# Input tests T1-T11 (listed in spec/new_classes.md). Each test changes the input on purpose in a
# way whose effect is known in advance, then checks that the output responds the way the
# definition's rules say it should. They were called R1-R10 until 30 Oct 2026 (change C11), when
# they were renamed so they can't be confused with the definition's Rules 1-11.

suppressPackageStartupMessages({ library(data.table) })

same_output <- function(a, b) {
  a <- as.data.table(a)[order(firm_id, year)]; b <- as.data.table(b)[order(firm_id, year)]
  nrow(a) == nrow(b) && identical(a$firm_id, b$firm_id) && identical(as.integer(a$year), as.integer(b$year)) &&
    identical(as.integer(a$new_classes), as.integer(b$new_classes))
}

value_at <- function(out, firm, t) {
  # The whole row: base classes, forward classes, new classes
  out <- as.data.table(out); v <- out[firm_id == firm & year == t]
  if (nrow(v) == 0) return(c(NA_integer_, NA_integer_, NA_integer_))
  as.integer(c(v$n_base_classes[1], v$n_forward_classes[1], v$new_classes[1]))
}

add_patent <- function(pc, firm, filing_year, cls) {
  rbind(pc, data.table(patent_id = paste0("RULE", filing_year, cls), firm_id = firm,
                       filing_year = as.integer(filing_year), grant_year = as.integer(filing_year + 2),
                       cpc_seq = 0L, cpc_subclass = cls))
}

run_input_tests <- function(builder, pc, fy, n_cases = 25, seed = 1, ref = NULL) {
  pc <- as.data.table(pc); fy <- as.data.table(fy)
  base_out <- builder(pc, fy)
  res <- list()
  res$T1_duplicate_rows <- same_output(base_out, builder(rbind(pc, pc), fy))
  set.seed(seed)
  res$T2_shuffled_rows <- same_output(base_out, builder(pc[sample(.N)], fy))

  # Test cases: firm-years whose base is not empty, according to the slow version. The slow
  # version's output is the same for every build being tested, so the caller can pass it in once.
  ref <- if (is.null(ref)) as.data.table(build_new_classes_slow_by_firm(pc, fy)) else as.data.table(ref)
  set.seed(seed)
  cases <- ref[n_base_classes > 0][sample(.N, min(.N, n_cases))]
  r3 <- r4 <- r5 <- r11 <- logical(nrow(cases))
  for (i in seq_len(nrow(cases))) {
    f <- cases$firm_id[i]; t <- cases$year[i]
    mine <- pc[firm_id == f]; one <- data.table(firm_id = f, year = t)
    before <- value_at(builder(mine, one), f, t)
    base_cls <- unique(mine[cpc_seq == 0 & filing_year >= t - 5 & filing_year <= t - 1 & !is.na(cpc_subclass), cpc_subclass])
    if (length(base_cls) == 0) { r3[i] <- r4[i] <- r5[i] <- r11[i] <- NA; next }
    # T3: a forward-window patent in a class already in the base -> base and new classes unchanged
    a3 <- value_at(builder(add_patent(mine, f, t + 1, base_cls[1]), one), f, t)
    r3[i] <- identical(a3[c(1, 3)], before[c(1, 3)])
    # T4: a forward-window patent in a class in neither set -> one more forward class and one more new class
    r4[i] <- identical(value_at(builder(add_patent(mine, f, t + 2, "Z99Z"), one), f, t), before + c(0L, 1L, 1L))
    # T5: a patent filed in year t, in a class in neither set -> one more forward class and one more new class
    r5[i] <- identical(value_at(builder(add_patent(mine, f, t, "Y99Y"), one), f, t), before + c(0L, 1L, 1L))
    # T11: a patent filed in year t+3, just after the forward window -> nothing changes
    r11[i] <- identical(value_at(builder(add_patent(mine, f, t + 3, "X99X"), one), f, t), before)
  }
  res$T3_known_class_in_forward <- all(r3, na.rm = TRUE)
  res$T4_new_class_adds_one     <- all(r4, na.rm = TRUE)
  res$T5_year_t_in_forward      <- all(r5, na.rm = TRUE)
  res$T11_year_after_forward_ignored <- all(r11, na.rm = TRUE)

  # T6: removing other firms' patents changes nothing for this firm
  firms <- unique(cases$firm_id)
  r6 <- vapply(firms, function(f) {
    full <- as.data.table(base_out)[firm_id == f][order(year)]
    alone <- as.data.table(builder(pc[firm_id == f], fy[firm_id == f]))[order(year)]
    identical(as.integer(full$new_classes), as.integer(alone$new_classes))
  }, logical(1))
  res$T6_firms_separate <- all(r6)

  # T10: repeating some firm-year rows on purpose changes nothing (Rule 11). Added 25 Oct 2026
  # (change C09). The real firm-year list has no repeats, so without this test a build that keeps
  # repeats passes every check on clean input.
  set.seed(seed)
  fy_rep <- rbind(fy, fy[sample(.N, min(.N, 50L))])
  res$T10_repeated_firm_years <- same_output(base_out, builder(pc, fy_rep))

  # T7-T9: properties of the output itself
  o <- as.data.table(base_out)
  res$T7_missing_iff_empty_base <- all(is.na(o$new_classes) == (o$n_base_classes == 0))
  res$T8_bounds <- all(is.na(o$new_classes) | (o$new_classes >= 0 & o$new_classes <= o$n_forward_classes))
  res$T9_one_row_per_firm_year <- nrow(o) == nrow(unique(fy[, .(firm_id, year)])) &&
    nrow(unique(o[, .(firm_id, year)])) == nrow(o)
  unlist(res)
}
