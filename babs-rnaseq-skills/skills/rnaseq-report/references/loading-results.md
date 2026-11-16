# Loading the analysis objects in R

Start R with the analysis directory as the working directory, ideally through
`PLUGIN/shared/scripts/run-in-container.sh --dir ANALYSIS_DIR -- R` so the
same container and renv library are used. `data()` looks in `./data`, which
is how the report pages themselves load these objects.

```r
library(DESeq2)

## 1. The annotated count object from 00_init (design ~1, before any filtering)
data(counts_GRCh38)            # loads `dds`  (also data/counts_GRCh38.rds)
dds
mcols(dds)[, c("symbol", "entrez", "ensembl")]

## 2. The fitted analysis from 02_differential
data(analyse_x_GRCh38)          # loads `ddsList` (also data/analyse_x_GRCh38.rds)
names(ddsList$sample_sets)                                   # sample sets
names(ddsList$sample_sets$D1$models)                         # models in a set
names(ddsList$sample_sets$D1$models$M1$comparisons)          # comparisons in a model
res <- ddsList$sample_sets$D1$models$M1$comparisons[[1]]$results   # DataFrame
ddsList$sample_sets$D1$models$M1$object                      # the fitted DESeqDataSet
ddsList$settings                                             # spec settings in force

## All results as one long data frame
library(purrr); library(dplyr)
all_res <- imap_dfr(ddsList$sample_sets, function(ss, set)
  imap_dfr(ss$models, function(m, model)
    imap_dfr(m$comparisons, function(cmp, comparison)
      as.data.frame(cmp$results) |>
        tibble::rownames_to_column("feature") |>
        mutate(set = set, model = model, comparison = comparison))))
```

The column meanings are in
`rnaseq-differential/references/results-columns.md`. The pre-fit tree from
`01_exploratory` (`data/ddsList_<ds>_<spec>.rda`) has the same shape, without
the fits and `results`.

`pkgdown/vignettes/BABS-RNASeq.rmd` describes an older layout
(`dds_model_comp`, results in `mcols`). The layout above is the one the current code writes.
