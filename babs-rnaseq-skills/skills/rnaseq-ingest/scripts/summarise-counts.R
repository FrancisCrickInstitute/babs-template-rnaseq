# Read-only summary of data/counts_<ds>.rds written by 00_init.
# Usage (via shared/scripts/run-r-helper.sh): summarise-counts.R DATA_SOURCE
args <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages({ library(SummarizedExperiment); library(DESeq2) })
ds <- args[1]
if (is.na(ds)) stop("usage: summarise-counts.R DATA_SOURCE")
f <- file.path("data", paste0("counts_", ds, ".rds"))
if (!file.exists(f)) stop(f, " not found: has 00_init_", ds, " been rendered?")
dds <- readRDS(f)
cat("Object:", f, " class:", class(dds)[1], "\n")
cat("Features x samples:", nrow(dds), "x", ncol(dds), "\n")
cat("Assays:", paste(assayNames(dds), collapse = ", "), "\n")
cat("Design:", paste(deparse(design(dds)), collapse = " "), "\n")
md <- metadata(dds)
if (length(md)) cat("metadata():", paste(sprintf("%s=%s", names(md), vapply(md, function(x) paste(format(x), collapse = ","), "")), collapse = "; "), "\n")
cat("\nSamples (colData columns:", paste(colnames(colData(dds)), collapse = ", "), ")\n")
print(head(as.data.frame(colData(dds)), 50))
lib <- colSums(assay(dds))
cat("\nLibrary sizes (counts): min", format(min(lib), big.mark = ","), " median", format(median(lib), big.mark = ","),
    " max", format(max(lib), big.mark = ","), "\n")
rd <- as.data.frame(mcols(dds))
ann <- intersect(c("symbol", "entrez", "ensembl"), names(rd))
if (length(ann)) {
  cat("\nAnnotation coverage:\n")
  for (a in ann) cat(sprintf("  %-8s %5.1f%% of features annotated\n", a, 100 * mean(!is.na(rd[[a]]) & rd[[a]] != "")))
} else cat("\nNo symbol/entrez/ensembl annotation columns (no usable org.db?)\n")
meta_f <- file.path("extdata", "metadata.csv")
if (file.exists(meta_f)) {
  m <- read.csv(meta_f, check.names = FALSE, colClasses = "character")
  ids <- if ("ID" %in% names(colData(dds))) as.character(dds$ID) else colnames(dds)
  dropped <- setdiff(m[[1]], ids)
  if (length(dropped)) cat("\nIn the experiment table but not in the counts object:", paste(dropped, collapse = ", "), "\n")
}
