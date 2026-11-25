# Match the comparisons of two fitted ddsList objects (data/<spec>_x_<ds>.rds)
# by their results rather than by their labels, which shift when a comparison
# is added to a spec. Read-only. Used by check-trial.sh for the Phase 8 trials.
#
# Usage (via shared/scripts/run-r-helper.sh, from the analysis directory):
#   check-results.R OLD.rds NEW.rds
#
# Two comparisons match when their padj vectors are equal (same features, same
# NA positions, relative difference < 1e-6). For each match the log2FoldChange
# relation is reported: "same direction", "reversed" (new = -old) or
# "LFC differs". Output, one line per comparison:
#   NEW <set>/<model>/<label>  <-  OLD <set>/<model>/<label>  (<relation>)  Up=.. Down=..
#   NEW <set>/<model>/<label>  new (no match in OLD)  Up=.. Down=..
#   OLD <set>/<model>/<label>  MISSING from NEW   (no NEW one equals it in the same direction)
# then a SUMMARY line; extra = number of NEW comparisons minus OLD ones.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("usage: check-results.R OLD.rds NEW.rds")
source(".babs-skills/helpers-common.R")
suppressPackageStartupMessages(library(DESeq2))

collect <- function(f) {
  x <- readRDS(f)
  out <- list()
  for (sn in nm(x$sample_sets)) {
    ss <- el(x$sample_sets, sn)
    for (mn in nm(ss$models)) {
      m <- el(ss$models, mn)
      for (cn in nm(m$comparisons)) {
        r <- el(m$comparisons, cn)$results
        if (is.null(r)) next
        cls <- as.character(r$class)
        starred <- grepl("\\*$", cls)
        out[[paste(sn, mn, cn, sep = "/")]] <- list(
          padj = setNames(r$padj, rownames(r)), lfc = setNames(r$log2FoldChange, rownames(r)),
          up = sum(starred & grepl("^Up", cls)), down = sum(starred & grepl("^Down", cls)))
      }
    }
  }
  out
}

same_vec <- function(a, b) {
  if (!identical(names(a), names(b))) return(FALSE)
  if (!identical(is.na(a), is.na(b))) return(FALSE)
  ok <- !is.na(a)
  isTRUE(all.equal(unname(a[ok]), unname(b[ok]), tolerance = 1e-6))
}
relation <- function(a, b) {
  if (same_vec(a, b)) "same direction" else if (same_vec(a, -b)) "reversed" else "LFC differs"
}
counts <- function(x) sprintf("Up=%d Down=%d", x$up, x$down)

old <- collect(args[1]); new <- collect(args[2])
# Several NEW comparisons may match the same OLD one: a kept pairwise contrast
# and an added treatment-vs-control contrast over the same pair of levels have
# the same padj. Each NEW takes its same-direction match if there is one.
hits <- character()
n_match <- 0L; n_new <- 0L; n_rev <- 0L
for (k in names(new)) {
  cand <- Filter(function(j) same_vec(new[[k]]$padj, old[[j]]$padj), names(old))
  if (!length(cand)) {
    n_new <- n_new + 1L
    cat(sprintf("NEW %-28s new (no match in OLD)  %s\n", k, counts(new[[k]])))
    next
  }
  rel <- vapply(cand, function(j) relation(new[[k]]$lfc, old[[j]]$lfc), "")
  pick <- if (any(rel == "same direction")) which(rel == "same direction")[1] else 1L
  hit <- cand[pick]; n_match <- n_match + 1L
  # an OLD comparison only counts as kept when a NEW one equals it outright
  if (rel[pick] == "same direction") hits <- c(hits, hit)
  if (rel[pick] == "reversed") n_rev <- n_rev + 1L
  cat(sprintf("NEW %-28s <-  OLD %-28s (%s)  %s  [old %s]\n", k, hit, rel[pick],
              counts(new[[k]]), counts(old[[hit]])))
}
missing <- setdiff(names(old), hits)
for (j in missing) cat(sprintf("OLD %-28s MISSING from NEW  %s\n", j, counts(old[[j]])))
cat(sprintf("SUMMARY old=%d new=%d matched=%d reversed=%d new_only=%d old_missing=%d extra=%d\n",
            length(old), length(new), n_match, n_rev, n_new, length(missing), length(new) - length(old)))
