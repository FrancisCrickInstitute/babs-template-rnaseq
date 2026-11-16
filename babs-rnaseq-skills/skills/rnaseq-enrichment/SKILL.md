---
name: rnaseq-enrichment
description: Render and interpret the BABS RNA-seq 03_enrichment page - GO molecular function and Reactome analyses, each as GSEA and over-representation, on the shrunk fold changes from 02_differential. Use after 02_differential, or when asked about pathways, GO terms, Reactome, GSEA, NES or over-representation in a BABS rnaseq analysis.
---

# Enrichment analysis (03_enrichment)

`PLUGIN` = two directories above this file. Requires
`02_differential_<spec>_<ds>` to have been rendered with the same VERSION.

## Run

```
PLUGIN/shared/scripts/render-section.sh --dir ANALYSIS_DIR 03_enrichment DS SPEC
PLUGIN/shared/scripts/run-r-helper.sh --dir ANALYSIS_DIR PLUGIN/skills/rnaseq-enrichment/scripts/summarise-enrichment.R DS SPEC [N_TOP]
```

Unless the spec sets `functional_approaches`, four approaches run per sample
set and model:
- GO Enrichment (GSEA, MF)
- GO Over-representation (MF)
- Reactome Enrichment
- Reactome Over-representation

Each writes a dotplot and a csv:
`results/<VERSION>/03_enrichment_<spec>_<ds>/tbl-NNN-<set>-<approach>-<model>-1<GIT_REF>.csv`.
The summariser prints the top terms per comparison from those csv files.

The page skips enrichment entirely, with a callout, when `00_init` could
not annotate genes (no usable org.db). If so, report it and point back to the
org.db in the config.

## Interpreting

Read `references/reading-enrichment.md`, the report's own introduction. Key points:
- `effect` is NES for GSEA and the relative effect for over-representation.
  Sign follows the comparison direction (`A-B`: positive means higher in A).
- Over-representation and GSEA answer different questions. Disagreement
  between them is informative, not an error.
- The report itself says these are a starting point. Don't present pathway
  hits as findings without that caveat.
