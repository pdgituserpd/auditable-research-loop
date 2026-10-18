# Data checks. Each returns a list(check, passed, detail) and records it in the run log.
# They never stop silently: a failed check is always visible in the log and the report.

suppressPackageStartupMessages({ library(data.table) })

.result <- function(check, passed, detail) {
  r <- list(check = check, passed = isTRUE(passed), detail = detail)
  # checks run on planted bugs are scored in the catch matrix, not logged as failures of the real build
  if (!isTRUE(getOption("checks.silent"))) log_check(r) else r
}

check_unique_keys <- function(dt, keys, label = "") {
  dt <- as.data.table(dt)
  n <- nrow(dt); u <- nrow(unique(dt[, ..keys]))
  .result(paste0("unique keys ", paste(keys, collapse = "+"), label),
          n == u, sprintf("%d rows, %d unique keys, %d duplicated", n, u, n - u))
}

check_row_count <- function(dt, expected, label = "") {
  .result(paste0("row count", label), nrow(dt) == expected,
          sprintf("%d rows, expected %d", nrow(dt), expected))
}

check_range <- function(x, lower = -Inf, upper = Inf, label = "") {
  bad <- sum(!is.na(x) & (x < lower | x > upper))
  .result(paste0("range ", label), bad == 0,
          sprintf("%d values outside [%s, %s]", bad, lower, upper))
}

check_no_infinite <- function(x, label = "") {
  bad <- sum(is.infinite(x))
  .result(paste0("no infinite values ", label), bad == 0, sprintf("%d infinite values", bad))
}

check_missing_share <- function(x, max_share, label = "") {
  s <- mean(is.na(x))
  .result(paste0("missing share ", label), s <= max_share,
          sprintf("%.1f%% missing, limit %.1f%%", 100 * s, 100 * max_share))
}

check_na_iff <- function(x, condition, label = "") {
  # x must be NA exactly when condition is TRUE
  bad <- sum(is.na(x) != condition)
  .result(paste0("missing exactly when expected ", label), bad == 0,
          sprintf("%d rows where missingness does not match the rule", bad))
}

check_le <- function(x, y, label = "") {
  bad <- sum(!is.na(x) & !is.na(y) & x > y)
  .result(paste0("not larger than its bound ", label), bad == 0, sprintf("%d rows violate", bad))
}

# Standard checks for the new-classes output
check_new_classes_output <- function(out, firm_year) {
  list(
    check_unique_keys(out, c("firm_id", "year"), " (output)"),
    check_row_count(out, nrow(unique(as.data.table(firm_year)[, .(firm_id, year)])), " (one row per firm-year)"),
    check_range(out$new_classes, 0, Inf, "new_classes >= 0"),
    check_no_infinite(out$new_classes, "new_classes"),
    check_na_iff(out$new_classes, out$n_base_classes == 0, "(new_classes NA iff empty base)"),
    check_le(out$new_classes, out$n_forward_classes, "(new_classes <= forward classes)")
  )
}
