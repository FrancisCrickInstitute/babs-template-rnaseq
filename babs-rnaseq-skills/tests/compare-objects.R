# Compare R objects (and xlsx workbooks) from a skill run with the Phase 0
# reference. Read-only: nothing is written except to stdout.
#
# Usage: Rscript compare-objects.R REF_VERSION REF_GIT_REF RUN_VERSION RUN_GIT_REF \
#                                  REF_FILE RUN_FILE [REF_FILE RUN_FILE ...]
#   The four stamps are e.g. v9.9.9 _v9.9.9-35d73cb1 unreleased _unreleased-1a2b3c4d.
#   Files may be .rds, .rda (every object in it) or .xlsx (every sheet).
#
# Each object is broken into leaves (assays, colData, rowData, design,
# results tables, comparison matrices, settings, params ...) and every leaf
# is compared. The version stamps are replaced by placeholders first, because
# the objects carry params$VERSION, params$GIT_REF and params$res_dir.
# Environments (formula environments, the IHW filterFun closure) are not
# compared; functions and calls are compared by their deparsed text.
#
# Output: one line per leaf that is not identical, then a summary line.
#   EQUAL     all.equal() TRUE but not identical() (numerical noise)
#   DIFFERS   real difference (first line of all.equal() shown)
#   MISSING   leaf in the reference but not in the run
#   EXTRA     leaf in the run but not in the reference
#   SESSION   the "R Packages" / "R Details" sheets of a write_results() xlsx
#             differ. They hold sessioninfo::session_info() (render date,
#             installed package versions), which plan section 6 allows to
#             differ; the differing packages/settings are listed for review.
#             The SUMMARY then ends "-> PASS (session info differs)".
# Exit status 1 if anything is DIFFERS, MISSING or EXTRA.

suppressPackageStartupMessages({
  library(SummarizedExperiment)
  library(DESeq2)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 6 || length(args) %% 2 != 0) {
  stop("usage: Rscript compare-objects.R REF_VERSION REF_GIT_REF RUN_VERSION RUN_GIT_REF REF_FILE RUN_FILE [...]")
}
ref_tok <- c(GIT_REF = args[2], VERSION = args[1])
run_tok <- c(GIT_REF = args[4], VERSION = args[3])
args <- args[-(1:4)]

# Replace the version stamps in a character vector (GIT_REF first: it contains VERSION).
normalise_chr <- function(x, tok) {
  for (n in names(tok)) if (nzchar(tok[[n]])) x <- gsub(tok[[n]], paste0("<", n, ">"), x, fixed = TRUE)
  x
}
normalise_df <- function(d, tok) {
  for (j in seq_along(d)) if (is.character(d[[j]])) d[[j]] <- normalise_chr(d[[j]], tok)
  if (!is.null(rownames(d))) rownames(d) <- normalise_chr(rownames(d), tok)
  d
}
dep <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = "\n")

# rowData can hold nested DataFrame columns; keep what converts cleanly.
safe_df <- function(d) {
  out <- tryCatch(as.data.frame(d), error = function(e) NULL)
  if (!is.null(out)) return(out)
  keep <- vapply(seq_len(ncol(d)), function(j) is.atomic(d[[j]]), logical(1))
  as.data.frame(d[, keep, drop = FALSE])
}

flatten <- function(x, path, tok, out) {
  add <- function(p, v) { out[[p]] <<- v; invisible() }
  if (is.null(x)) { add(path, "<NULL>"); return(out) }
  if (is(x, "DESeqResults") || is(x, "DataFrame")) { add(path, normalise_df(safe_df(x), tok)); return(out) }
  if (is(x, "SummarizedExperiment")) {
    for (a in assayNames(x)) add(paste0(path, "/assay:", a), as.matrix(assay(x, a, withDimnames = TRUE)))
    add(paste0(path, "/colData"), normalise_df(safe_df(colData(x)), tok))
    add(paste0(path, "/rowData"), normalise_df(safe_df(rowData(x)), tok))
    add(paste0(path, "/dimnames"), dimnames(x))
    if (is(x, "DESeqDataSet")) {
      add(paste0(path, "/design"), tryCatch(dep(design(x)), error = function(e) "<no design>"))
      add(paste0(path, "/sizeFactors"), tryCatch(sizeFactors(x), error = function(e) NULL) %||% "<NULL>")
    }
    return(out)
  }
  if (inherits(x, "lm")) {
    for (k in c("coefficients", "residuals", "fitted.values", "rank", "df.residual")) add(paste0(path, "/", k), x[[k]])
    return(out)
  }
  if (inherits(x, "formula") || is.language(x) || is.function(x)) { add(path, normalise_chr(dep(x), tok)); return(out) }
  if (is.environment(x)) { add(path, "<environment>"); return(out) }
  if (is.data.frame(x)) { add(path, normalise_df(x, tok)); return(out) }
  if (is.list(x)) {
    nms <- names(x); if (is.null(nms)) nms <- rep("", length(x))
    nms <- ifelse(nzchar(nms), nms, paste0("[[", seq_along(x), "]]"))
    if (!length(x)) { add(path, "<empty list>"); return(out) }
    for (i in seq_along(x)) out <- flatten(x[[i]], paste0(path, "/", nms[i]), tok, out)
    return(out)
  }
  if (isS4(x)) { add(path, paste0("<S4 ", class(x)[1], ">")); return(out) }
  if (is.character(x)) {
    a <- attributes(x); x <- normalise_chr(x, tok); attributes(x) <- a
    if (!is.null(names(x))) names(x) <- normalise_chr(names(x), tok)
  }
  add(path, x)
  out
}
`%||%` <- function(a, b) if (is.null(a)) b else a

read_any <- function(f) {
  ext <- tolower(tools::file_ext(f))
  if (ext == "rds") return(list(object = readRDS(f)))
  if (ext == "rda" || ext == "rdata") { e <- new.env(); n <- load(f, envir = e); return(mget(n, envir = e)) }
  if (ext == "xlsx") {
    if (requireNamespace("readxl", quietly = TRUE)) {
      sh <- readxl::excel_sheets(f)
      return(setNames(lapply(sh, function(s) as.data.frame(readxl::read_excel(f, sheet = s))), sh))
    }
    sh <- openxlsx::getSheetNames(f)
    return(setNames(lapply(sh, function(s) openxlsx::read.xlsx(f, sheet = s)), sh))
  }
  stop("don't know how to read ", f)
}

# Session-info sheets written by write_results() (shared/R/output.r).
session_sheets <- c("/R Packages", "/R Details")
# Describe how two session-info sheets differ: package versions or settings.
session_diff <- function(a, b) {
  if (!is.data.frame(a) || !is.data.frame(b)) return("not both tables")
  key <- intersect(c("package", "setting"), intersect(names(a), names(b)))[1]
  if (is.na(key)) return("sheet layout differs")
  cols <- setdiff(intersect(names(a), names(b)), key)
  m <- merge(a[c(key, cols)], b[c(key, cols)], by = key, all = TRUE, suffixes = c(".ref", ".run"))
  out <- character()
  for (r in seq_len(nrow(m))) {
    d <- vapply(cols, function(cl) !identical(as.character(m[r, paste0(cl, ".ref")]), as.character(m[r, paste0(cl, ".run")])), logical(1))
    if (!any(d)) next
    cl <- cols[d][1]
    out <- c(out, sprintf("%s %s: %s -> %s", m[r, key], cl, m[r, paste0(cl, ".ref")], m[r, paste0(cl, ".run")]))
  }
  if (!length(out)) return("formatting only")
  paste(c(head(out, 6), if (length(out) > 6) sprintf("... and %d more", length(out) - 6)), collapse = "; ")
}

total_bad <- 0L
for (i in seq(1, length(args), by = 2)) {
  rf <- args[i]; uf <- args[i + 1]
  label <- basename(uf)
  if (!file.exists(rf)) { cat(sprintf("%-40s MISSING reference file %s\n", label, rf)); total_bad <- total_bad + 1L; next }
  if (!file.exists(uf)) { cat(sprintf("%-40s MISSING run file %s\n", label, uf)); total_bad <- total_bad + 1L; next }
  ref <- suppressWarnings(flatten(read_any(rf), "", ref_tok, list()))
  run <- suppressWarnings(flatten(read_any(uf), "", run_tok, list()))
  # sheet names in xlsx carry no stamp, but leaf paths might: normalise them too
  names(ref) <- normalise_chr(names(ref), ref_tok); names(run) <- normalise_chr(names(run), run_tok)
  paths <- union(names(ref), names(run))
  is_xlsx <- tolower(tools::file_ext(uf)) == "xlsx"
  n <- c(IDENTICAL = 0L, EQUAL = 0L, SESSION = 0L, DIFFERS = 0L, MISSING = 0L, EXTRA = 0L)
  for (p in paths) {
    if (!p %in% names(run)) { st <- "MISSING"; msg <- "" }
    else if (!p %in% names(ref)) { st <- "EXTRA"; msg <- "" }
    else if (identical(ref[[p]], run[[p]])) { st <- "IDENTICAL"; msg <- "" }
    else {
      ae <- tryCatch(all.equal(ref[[p]], run[[p]], check.attributes = TRUE), error = function(e) conditionMessage(e))
      if (isTRUE(ae)) { st <- "EQUAL"; msg <- "" }
      else if (is_xlsx && p %in% session_sheets) { st <- "SESSION"; msg <- session_diff(ref[[p]], run[[p]]) }
      else { st <- "DIFFERS"; msg <- paste(head(ae, 1), collapse = "") }
    }
    n[[st]] <- n[[st]] + 1L
    if (st != "IDENTICAL") cat(sprintf("%-40s %-9s %s %s\n", label, st, p, msg))
  }
  bad <- n[["DIFFERS"]] + n[["MISSING"]] + n[["EXTRA"]]
  total_bad <- total_bad + bad
  verdict <- if (bad > 0) "FAIL"
             else if (n[["SESSION"]] > 0) "PASS (session info differs)"
             else if (n[["EQUAL"]] > 0) "PASS (numerically equal)"
             else "PASS"
  cat(sprintf("%-40s SUMMARY   %d leaves: %d identical, %d equal, %d session, %d differ, %d missing, %d extra -> %s\n",
              label, length(paths), n[["IDENTICAL"]], n[["EQUAL"]], n[["SESSION"]], n[["DIFFERS"]], n[["MISSING"]], n[["EXTRA"]],
              verdict))
}
quit(status = if (total_bad > 0) 1L else 0L)
