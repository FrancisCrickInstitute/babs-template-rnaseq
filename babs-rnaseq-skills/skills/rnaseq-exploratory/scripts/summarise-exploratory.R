# Read-only summary of the 01_exploratory outputs for one data source x spec.
# Usage (via shared/scripts/run-r-helper.sh): summarise-exploratory.R DATA_SOURCE SPEC [VERSION]
args <- commandArgs(trailingOnly = TRUE)
source(".babs-skills/helpers-common.R")
ds <- arg_or(args, 1); spec <- arg_or(args, 2); version <- arg_or(args, 3)
if (is.null(ds) || is.null(spec)) stop("usage: summarise-exploratory.R DATA_SOURCE SPEC [VERSION]")
page <- paste("01_exploratory", spec, ds, sep = "_")
f <- file.path("data", paste0("ddsList_", ds, "_", spec, ".rda"))
if (!file.exists(f)) stop(f, " not found: has ", page, " been rendered?")
env <- new.env(); load(f, envir = env); ddsList <- env$ddsList

cat("Exploratory summary for", page, "\n")
s <- ddsList$settings
if (!is.null(s)) {
  keep <- intersect(c("alpha", "lfcThreshold", "baseMeanMin", "top_n_variable", "seed", "showCategory"), names(s))
  cat("Spec settings:", paste(sprintf("%s=%s", keep, vapply(s[keep], function(x) paste(format(x), collapse = ","), "")), collapse = "; "), "\n")
}
for (sn in nm(ddsList$sample_sets)) {
  ss <- el(ddsList$sample_sets, sn)
  obj <- ss$object
  cat(sprintf("\nSample set %s%s\n", sn, if (!is.null(ss$name) && ss$name != sn) paste0(" (", ss$name, ")") else ""))
  if (!is.null(obj)) {
    cat(sprintf("  %d features x %d samples; assays: %s\n", nrow(obj), ncol(obj), paste(assayNames(obj), collapse = ", ")))
    cat("  samples:", paste(colnames(obj), collapse = ", "), "\n")
  }
  if (!is.null(ss$feature_filters)) cat("  feature filters:", paste(names(ss$feature_filters), collapse = ", "), "\n")
  if (!is.null(ss$baseMeanMin)) cat("  baseMeanMin:", ss$baseMeanMin, "\n")
  for (mn in nm(ss$models)) {
    m <- el(ss$models, mn)
    cat(sprintf("  Model %s%s: design %s; %d comparison(s); %d profile plot(s)\n", mn,
                if (!is.null(m$name) && m$name != mn) paste0(" (", m$name, ")") else "",
                fmt_formula(m$design), length(m$comparisons), length(m$profile_plots)))
  }
}
pf <- file.path("data", "exploratory_plots.rds")
if (file.exists(pf) && file.mtime(pf) >= file.mtime(f) - 5) {
  pl <- readRDS(pf)
  if (is.data.frame(pl) && nrow(pl)) {
    cat("\nFigures produced (", nrow(pl), "):\n", sep = "")
    lab <- if ("label" %in% names(pl)) pl$label else rep("", nrow(pl))
    print(head(data.frame(label = lab, png = pl$png), 40), row.names = FALSE)
  }
} else cat("\n(data/exploratory_plots.rds is absent or belongs to a different page; figures not listed)\n")
cat("\n")
list_outputs(find_version_dir(page, version), page)
