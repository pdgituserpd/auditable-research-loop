# Run log: every run writes one JSON record to logs/runs/, automatically.
# A run that is skipped leaves a gap in the sequence, so runs can't be quietly dropped.

suppressPackageStartupMessages({ library(jsonlite) })

.run <- new.env()

file_hash <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::md5sum(path))
}

data_hash <- function(dt) {
  # Order-independent fingerprint of a table's content
  d <- as.data.frame(dt)
  d <- d[do.call(order, unname(as.list(d))), , drop = FALSE]
  tf <- tempfile(fileext = ".csv")
  utils::write.csv(d, tf, row.names = FALSE, na = "NA")
  h <- unname(tools::md5sum(tf)); unlink(tf); h
}

git_commit <- function() {
  out <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE, ignore.stderr = TRUE),
                  error = function(e) NA_character_, warning = function(w) NA_character_)
  if (length(out) == 0) NA_character_ else out
}

start_run <- function(purpose, settings = list(), inputs = character(), log_dir = "logs/runs") {
  dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
  .run$record <- list(
    run_id = format(Sys.time(), "%Y%m%d-%H%M%OS3"),
    started = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    purpose = purpose,
    git_commit = git_commit(),
    r_version = R.version.string,
    settings = settings,
    inputs = as.list(vapply(inputs, file_hash, character(1))),
    checks = list(),
    outputs = list()
  )
  .run$dir <- log_dir
  invisible(.run$record$run_id)
}

log_check <- function(result) {
  if (is.null(.run$record)) return(invisible(result))
  .run$record$checks[[length(.run$record$checks) + 1]] <- result
  invisible(result)
}

log_output <- function(name, dt) {
  if (is.null(.run$record)) return(invisible(NULL))
  .run$record$outputs[[name]] <- list(rows = nrow(dt), fingerprint = data_hash(dt))
  invisible(NULL)
}

end_run <- function(notes = "") {
  if (is.null(.run$record)) return(invisible(NULL))
  .run$record$finished <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  .run$record$notes <- notes
  n_fail <- sum(vapply(.run$record$checks, function(x) isFALSE(x$passed), logical(1)))
  .run$record$checks_failed <- n_fail
  path <- file.path(.run$dir, paste0(.run$record$run_id, ".json"))
  writeLines(toJSON(.run$record, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"), path)
  rec <- .run$record
  .run$record <- NULL
  invisible(list(path = path, failed = n_fail, record = rec))
}
