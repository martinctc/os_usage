#!/usr/bin/env Rscript
# Validate that data/*.rds snapshots have the expected schema and plausible
# values. Designed to run in CI as a cheap guardrail against silent corruption
# from a future qmd refactor or upstream API change.
#
# Usage: Rscript scripts/validate_snapshots.R [data_dir]

suppressPackageStartupMessages({
  library(readr)
})

args <- commandArgs(trailingOnly = TRUE)
data_dir <- if (length(args) >= 1) args[[1]] else "data"

files <- list.files(data_dir, pattern = "\\.rds$", full.names = TRUE)
if (length(files) == 0) {
  stop(sprintf("No .rds snapshots found in '%s'", data_dir), call. = FALSE)
}

required_cols <- c("date", "CRAN", "PyPI")
errors <- character(0)

for (path in files) {
  snap <- tryCatch(read_rds(path), error = function(e) {
    errors <<- c(errors, sprintf("[%s] unreadable: %s", path, conditionMessage(e)))
    return(NULL)
  })
  if (is.null(snap)) next

  missing_cols <- setdiff(required_cols, names(snap))
  if (length(missing_cols) > 0) {
    errors <- c(errors, sprintf("[%s] missing columns: %s",
                                path, paste(missing_cols, collapse = ", ")))
    next
  }

  if (!inherits(snap$date, "Date")) {
    errors <- c(errors, sprintf("[%s] 'date' is not class Date (got %s)",
                                path, paste(class(snap$date), collapse = "/")))
  }

  for (num_col in c("CRAN", "PyPI")) {
    vals <- snap[[num_col]]
    if (!is.numeric(vals)) {
      errors <- c(errors, sprintf("[%s] '%s' is not numeric (got %s)",
                                  path, num_col, paste(class(vals), collapse = "/")))
      next
    }
    if (any(vals < 0, na.rm = TRUE)) {
      errors <- c(errors, sprintf("[%s] '%s' contains negative values", path, num_col))
    }
  }

  if (nrow(snap) == 0) {
    errors <- c(errors, sprintf("[%s] snapshot has zero rows", path))
  }
}

if (length(errors) > 0) {
  message("Snapshot validation FAILED:")
  for (e in errors) message("  - ", e)
  quit(status = 1L)
}

message(sprintf("Validated %d snapshot(s) in '%s' - all OK.", length(files), data_dir))
