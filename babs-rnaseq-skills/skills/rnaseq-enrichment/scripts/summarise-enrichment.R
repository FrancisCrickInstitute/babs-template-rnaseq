# Read-only summary of the csv tables written by 03_enrichment (via table_tracker).
# Usage (via shared/scripts/run-r-helper.sh): summarise-enrichment.R DATA_SOURCE SPEC [N_TOP] [VERSION]
args <- commandArgs(trailingOnly = TRUE)
ds <- args[1]; spec <- args[2]
n_top <- if (length(args) >= 3 && nzchar(args[3])) as.integer(args[3]) else 5
version <- if (length(args) >= 4 && nzchar(args[4])) args[4] else NULL
if (is.na(ds) || is.na(spec)) stop("usage: summarise-enrichment.R DATA_SOURCE SPEC [N_TOP] [VERSION]")
page <- paste("03_enrichment", spec, ds, sep = "_")
vdirs <- if (!is.null(version)) file.path("results", version) else list.dirs("results", recursive = FALSE)
vdirs <- vdirs[dir.exists(file.path(vdirs, page))]
if (!length(vdirs)) stop("no results/<VERSION>/", page, " folder: has the page been rendered?")
vdir <- vdirs[order(file.mtime(vdirs), decreasing = TRUE)][1]
files <- sort(list.files(file.path(vdir, page), pattern = "^tbl-.*\\.csv$", full.names = TRUE))
cat("Enrichment summary for", page, "in", vdir, "\n")
if (!length(files)) { cat("No enrichment tables were written (missing annotation, or no significant input).\n"); quit(status = 0) }
for (f in files) {
  df <- tryCatch(read.csv(f, check.names = FALSE), error = function(e) NULL)
  cat("\n==", sub("^tbl-[0-9]+-", "", sub("_[^_]*-[0-9a-f]{8}\\.csv$|\\.csv$", "", basename(f))), "\n   file:", f, "\n")
  if (is.null(df) || !nrow(df)) { cat("   (empty)\n"); next }
  df <- df[!is.na(df$Description), , drop = FALSE]
  cat("   ", nrow(df), "term x comparison rows;", length(unique(df$ID)), "distinct terms\n")
  cols <- intersect(c("comparison", "ID", "Description", "effect", "NES", "p.adjust", "qvalue", "setSize", "Count", "GeneRatio"), names(df))
  for (cmp in unique(df$comparison)) {
    sub <- df[df$comparison == cmp, cols, drop = FALSE]
    o <- if ("p.adjust" %in% names(sub)) order(sub$p.adjust, -abs(sub$effect)) else order(-abs(sub$effect))
    sub <- head(sub[o, , drop = FALSE], n_top)
    num <- vapply(sub, is.numeric, TRUE); sub[num] <- lapply(sub[num], signif, 3)
    cat("   -- ", cmp, "\n", sep = "")
    print(sub, row.names = FALSE)
  }
}
