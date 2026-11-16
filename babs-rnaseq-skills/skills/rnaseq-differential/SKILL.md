---
name: rnaseq-differential
description: Render and interpret the BABS RNA-seq 02_differential page - DESeq2 Wald, LRT, emmeans multiple comparisons or limma fits defined by the spec, IHW/BH adjustment, ashr-shrunk fold changes, significant gene counts, Excel results. Use after 01_exploratory, or when asked how many genes are differential, which genes are up or down, what a comparison name or results column means, or why a model or comparison was dropped in a BABS rnaseq analysis.
---

# Differential analysis (02_differential)

`PLUGIN` = two directories above this file. Requires
`01_exploratory_<spec>_<ds>` to have been rendered with the same VERSION.

## Run

```
PLUGIN/shared/scripts/render-section.sh --dir ANALYSIS_DIR 02_differential DS SPEC
PLUGIN/shared/scripts/run-r-helper.sh --dir ANALYSIS_DIR PLUGIN/skills/rnaseq-differential/scripts/summarise-differential.R DS SPEC [N_TOP]
```

The summariser prints, for each sample set / model / comparison:
- the approach (Wald / LRT / multiWald / limma)
- `alpha`, `lfcThreshold` and `filterFun`
- counts of `Up*`, `Down*`, other significant, `Low Count`, `Outlier`, `Zero Count`
- the top genes

It also writes `.babs-skills/summary_<page>.csv` and lists the xlsx files.

## Outputs

- `data/<spec>_x_<ds>.rds` / `.rda`: the fitted tree. Each comparison holds a
  `results` DataFrame. See `references/results-columns.md`.
- `results/<VERSION>/02_differential_<spec>_<ds>/`: one `differential_<set>*.xlsx` per sample set,
  cluster tsv files, MA plots, heatmaps, p-value diagnostics.

## Warnings: what they mean (fixes go in the spec, never the code)

Search the log: `grep -nEi 'warn|error|dropp|rank|replicat|estimate' logs/html-02_differential_<spec>_<ds>.log`

- **"Model is being dropped as there is no replication"**: the design has as
  many coefficients as samples. The model and its comparisons are missing
  from the results.
- **"Dropping samples … as they have incomplete metadata"**: a design
  covariate is blank/NA for those samples. They are excluded from that model.
  Name them to the user.
- **Rank deficiency / "Can't estimate some coefficients"**:
  some factor combinations have no samples, or factors are confounded. The
  spec vignette's "Rank deficiency" section (in `references/results-columns.md`)
  explains `drop_unsupported_combinations=TRUE` and `transform=mutate(recode_within(...))`.
  Explain this to the user. Change the spec only if they ask, then
  re-render from 00_init so VERSION stays consistent.
- **"Couldn't work out relevant group ordering in LRT"**: an LRT `class` is blank
  and `shrunkLFC` comes from `lfcShrink` instead.
- An R error printed in the page: the qmds use `error: true`, so the page still
  renders. Always check the log.

## Reporting results

- Say "significant at padj < alpha", using the alpha in force, not "p < 0.05".
- `A-B|M` means A versus B (Up = higher in A), conditional on M.
- For LRT/omnibus tests, the effect is `maxLog2FoldChange` and `class` names the
  extreme groups.
- Quote the caveats paragraph (multiplicity, Table Two fallacy) from
  `references/results-columns.md` when the user is about to draw conclusions
  from many comparisons or from non-randomised groups.
- Zero significant genes is a legitimate result. Report it with the p-value
  diagnostic description, and don't loosen thresholds unless asked.
