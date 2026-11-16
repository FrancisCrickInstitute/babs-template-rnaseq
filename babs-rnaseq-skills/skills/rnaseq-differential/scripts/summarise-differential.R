# Read-only summary of data/<spec>_x_<ds>.rds written by 02_differential.
# Usage (via shared/scripts/run-r-helper.sh): summarise-differential.R DATA_SOURCE SPEC [N_TOP] [VERSION]
args <- commandArgs(trailingOnly = TRUE)
source(".babs-skills/helpers-common.R")
ds <- arg_or(args, 1); spec <- arg_or(args, 2); n_top <- as.integer(arg_or(args, 3, "10")); version <- arg_or(args, 4)
if (is.null(ds) || is.null(spec)) stop("usage: summarise-differential.R DATA_SOURCE SPEC [N_TOP] [VERSION]")
page <- paste("02_differential", spec, ds, sep = "_")
f <- file.path("data", paste0(spec, "_x_", ds, ".rds"))
if (!file.exists(f)) stop(f, " not found: has ", page, " been rendered?")
ddsList <- readRDS(f)

# Same decision rule as fit_comparison() in R/rnaseq.r, used only for reporting.
approach_of <- function(model, comparison) {
  if (isTRUE(comparison[["LRT"]])) return("wald2LRT")
  if (!is.null(model$approach)) return(model$approach)
  if (inherits(comparison, "post_hoc") && inherits(model$object, "DESeqDataSet")) return("multiWald (emmeans)")
  if (inherits(comparison, "post_hoc")) return("limma")
  if (inherits(comparison[[1]], "formula")) return("LRT")
  "Wald"
}

cat("Differential summary for", page, "\n")
rows <- list()
for (sn in nm(ddsList$sample_sets)) {
  ss <- el(ddsList$sample_sets, sn)
  for (mn in nm(ss$models)) {
    m <- el(ss$models, mn)
    cat(sprintf("\n== Sample set %s / model %s: design %s, %d samples\n", sn, mn, fmt_formula(m$design),
                if (!is.null(m$object)) ncol(m$object) else NA))
    if (any(m$dropped)) cat("   NOTE: unsupported coefficient combinations were dropped from the design matrix\n")
    for (cn in nm(m$comparisons)) {
      cmp <- el(m$comparisons, cn)
      r <- cmp$results
      if (is.null(r)) { cat("   ", cn, ": no results\n"); next }
      alpha <- metadata(r)$alpha %||% cmp$alpha
      cls <- as.character(r$class)
      starred <- grepl("\\*$", cls)
      up <- sum(starred & grepl("^Up", cls)); down <- sum(starred & grepl("^Down", cls))
      other_sig <- sum(starred) - up - down
      tab <- c(Up = up, Down = down, `Other sig.` = other_sig,
               `Low Count` = sum(cls == "Low Count", na.rm = TRUE), Outlier = sum(cls == "Outlier", na.rm = TRUE),
               `Zero Count` = sum(cls == "Zero Count", na.rm = TRUE))
      ff <- cmp$filterFun
      ff <- if (is.null(ff)) "default (independent filtering)" else paste(deparse(ff), collapse = " ")
      cat(sprintf("   Comparison %s  [%s]  alpha=%s lfcThreshold=%s filterFun=%s\n", cn, approach_of(m, cmp),
                  paste(alpha, collapse = ","), paste(cmp$lfcThreshold %||% 0, collapse = ","), ff))
      cat("     ", paste(sprintf("%s=%d", names(tab), tab), collapse = "  "), "  (of", nrow(r), "features)\n")
      rows[[length(rows) + 1]] <- data.frame(sample_set = sn, model = mn, comparison = cn, approach = approach_of(m, cmp),
                                             t(tab), check.names = FALSE)
      if (n_top > 0 && sum(starred) > 0) {
        df <- as.data.frame(r)
        df$feature <- rownames(df)
        df <- df[starred, , drop = FALSE]
        df <- df[order(df$padj), , drop = FALSE]
        cols <- intersect(c("feature", "symbol", "baseMean", "log2FoldChange", "shrunkLFC", "maxLog2FoldChange", "padj", "class"), names(df))
        top <- head(df[, cols, drop = FALSE], n_top)
        num <- vapply(top, is.numeric, TRUE); top[num] <- lapply(top[num], signif, 3)
        print(top, row.names = FALSE)
      }
    }
  }
}
if (length(rows)) {
  out <- do.call(rbind, rows)
  dir.create(".babs-skills", showWarnings = FALSE)
  write.csv(out, file.path(".babs-skills", paste0("summary_", page, ".csv")), row.names = FALSE)
  cat("\nCompact table written to .babs-skills/summary_", page, ".csv\n", sep = "")
}
vdir <- find_version_dir(page, version)
x <- if (!is.na(vdir)) list.files(vdir, pattern = "\\.xlsx$", recursive = TRUE, full.names = TRUE) else character()
x <- x[grepl(paste0("^", page), basename(dirname(x))) | grepl(ds, x)]
if (length(x)) cat("\nExcel results:\n", paste0("  ", x, collapse = "\n"), "\n", sep = "")
list_outputs(vdir, page)
