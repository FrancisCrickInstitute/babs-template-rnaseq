# Sourced by the read-only summarisers. Nothing here alters analysis objects.
suppressPackageStartupMessages({
  library(SummarizedExperiment)
  library(DESeq2)
})

arg_or <- function(args, i, default = NULL) if (length(args) >= i && nzchar(args[i])) args[i] else default

# Most recent results/<VERSION> containing the page's output folder.
find_version_dir <- function(page, version = NULL) {
  if (!is.null(version)) return(file.path("results", version))
  cands <- list.dirs("results", recursive = FALSE)
  cands <- cands[!grepl("multiqc-|latest|published_", basename(cands))]
  cands <- cands[dir.exists(file.path(cands, page)) | file.exists(file.path("staging", cands, paste0(page, ".html")))]
  if (!length(cands)) return(NA_character_)
  cands[order(file.mtime(cands), decreasing = TRUE)][1]
}

list_outputs <- function(vdir, page) {
  d <- file.path(vdir, page)
  if (is.na(vdir) || !dir.exists(d)) { cat("  (no output folder found for", page, ")\n"); return(invisible()) }
  f <- list.files(d, recursive = TRUE)
  ext <- tools::file_ext(f)
  cat("  output folder:", d, "\n")
  for (e in sort(unique(ext))) cat(sprintf("    %-5s %4d file(s)%s\n", e, sum(ext == e),
    if (e %in% c("tsv", "csv", "xlsx", "txt")) paste0(": ", paste(head(f[ext == e], 8), collapse = ", "), if (sum(ext == e) > 8) ", ..." else "") else ""))
}

fmt_formula <- function(x) if (inherits(x, "formula")) paste(deparse(x), collapse = " ") else if (is.matrix(x)) "<design matrix>" else paste(deparse(x), collapse = " ")

# names() that never drops unnamed elements
nm <- function(x) { n <- names(x); if (is.null(n)) n <- rep("", length(x)); ifelse(nzchar(n), n, as.character(seq_along(x))) }
el <- function(x, n) if (n %in% names(x)) x[[n]] else x[[as.integer(n)]]
