---
name: rnaseq-exploratory
description: Render and interpret the BABS RNA-seq 01_exploratory page for a spec x data source - sample sets, feature filters, VST normalisation, top-variable heatmaps, cluster profiles, PCA and PC-covariate association. Use after 00_init has been rendered, or when asked about sample clustering, PCA, outliers, batch effects or QC plots in a BABS rnaseq analysis.
---

# Exploratory analysis (01_exploratory)

`PLUGIN` = two directories above this file. Requires `00_init_<ds>` to have
been rendered with the same VERSION.

## Run

```
PLUGIN/shared/scripts/render-section.sh --dir ANALYSIS_DIR 01_exploratory DS SPEC
PLUGIN/shared/scripts/run-r-helper.sh --dir ANALYSIS_DIR PLUGIN/skills/rnaseq-exploratory/scripts/summarise-exploratory.R DS SPEC
```

`SPEC` is the spec basename (e.g. `analyse` for `extdata/analyse.spec`).

## What it produces

- `data/ddsList_<ds>_<spec>.rda`: the sample sets × models tree built by
  `build_dds_list()` from the spec, with the `vst` and extra assays.
- `results/<VERSION>/01_exploratory_<spec>_<ds>/`: assay, PC, cluster and expected-value
  tsv files, plus pdf/png figures named `fig-NNN-<label>-N<GIT_REF>.*`.
- `data/exploratory_plots.rds`: the list of figures (overwritten by every 01 page).

## Interpret, then report

Read `references/reading-exploratory.md` before describing any figure. It is
the report's own explanation. To look at a figure, open the png it lists
with the Read tool. Report:
- the sample sets and models found, and the samples in each
- whether the top-variable heatmap and PCA separate samples by the design
  factors, and any sample that sits away from its group
- covariates strongly associated with early PCs that are **not** in the
  design (possible batch effects). Report these as observations, not as fixes.
- warnings in `logs/html-01_exploratory_<spec>_<ds>.log`

Do not remove samples or change the design yourself. Report possible outliers
or batch effects. The user decides, through `subset`, `influential_samples` or
the design in the spec.
