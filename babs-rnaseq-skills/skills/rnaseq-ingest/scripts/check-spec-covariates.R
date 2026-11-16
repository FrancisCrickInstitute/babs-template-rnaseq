#!/usr/bin/env Rscript
# Read-only check: do the variables a spec refers to exist in the experiment table?
# Base R only (runs with --vanilla, no renv needed). Does NOT evaluate the spec.
#
# Usage: Rscript --vanilla check-spec-covariates.R METADATA.csv SPEC [SPEC...]
# Exit status 1 if a spec fails to parse or a design/comparison formula uses
# a variable that is neither a column nor created by a transform=mutate(...).
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: check-spec-covariates.R METADATA.csv SPEC [SPEC...]")
meta <- utils::read.csv(args[1], check.names = FALSE, nrows = 5, colClasses = "character")
cols <- names(meta)
status <- 0

collect <- function(e, acc) {
  if (is.call(e)) {
    fn <- if (is.symbol(e[[1]])) as.character(e[[1]]) else ""
    nms <- names(e)
    if (fn == "~") {
      rhs <- e[[length(e)]]
      acc$formula <- c(acc$formula, all.vars(rhs))
    } else if (fn == "aes") {
      acc$aes <- c(acc$aes, unlist(lapply(as.list(e)[-1], all.vars)))
    } else if (fn %in% c("mutate", "transform")) {
      acc$derived <- c(acc$derived, setdiff(nms, ""))
    } else if (fn %in% c("extra_assays", "list") && !is.null(nms)) {
      # named extra_assay(...) entries create assay names usable in aes(y=...)
      ea <- vapply(as.list(e)[-1], function(x) is.call(x) && identical(x[[1]], as.name("extra_assay")), logical(1))
      acc$assays <- c(acc$assays, nms[-1][ea])
    }
    if (!is.null(nms)) {
      for (k in intersect(nms, c("subset", "influential_samples", "visualise")))
        acc$predicate <- c(acc$predicate, all.vars(e[[k]]))
    }
    for (i in seq_along(e)[-1]) acc <- collect(e[[i]], acc)
  }
  acc
}

for (f in args[-1]) {
  cat("Spec:", f, "\n")
  ex <- tryCatch(parse(file = f), error = function(e) e)
  if (inherits(ex, "error")) { cat("  PARSE ERROR:", conditionMessage(ex), "\n"); status <- 1; next }
  acc <- list(formula = character(), aes = character(), predicate = character(),
              derived = character(), assays = character())
  for (e in ex) acc <- collect(e, acc)
  known <- c(cols, acc$derived, ".", ".include")
  bad_formula <- setdiff(unique(acc$formula), known)
  bad_pred <- setdiff(unique(acc$predicate), c(known, "TRUE", "FALSE"))
  bad_aes <- setdiff(unique(acc$aes), c(known, acc$assays))
  cat("  experiment-table columns:", paste(cols, collapse = ", "), "\n")
  if (length(acc$derived)) cat("  created by transform/mutate:", paste(unique(acc$derived), collapse = ", "), "\n")
  cat("  variables used in formulas:", paste(setdiff(unique(acc$formula), "."), collapse = ", "), "\n")
  if (length(bad_formula)) { cat("  ERROR formula variable(s) not in the experiment table:", paste(bad_formula, collapse = ", "), "\n"); status <- 1 }
  if (length(bad_pred)) cat("  WARNING subset/influential_samples refer to unknown name(s):", paste(bad_pred, collapse = ", "),
                            "(fine only if they are R objects, e.g. a vector defined in the spec)\n")
  if (length(bad_aes)) cat("  WARNING profile_plots aes() refer to unknown name(s):", paste(bad_aes, collapse = ", "),
                           "(fine if they are assay names)\n")
  if (!length(bad_formula) && !length(bad_pred) && !length(bad_aes)) cat("  OK: every variable is accounted for\n")
}
quit(status = status)
