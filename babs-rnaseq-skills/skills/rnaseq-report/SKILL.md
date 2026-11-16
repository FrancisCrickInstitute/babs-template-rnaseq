---
name: rnaseq-report
description: Assemble and hand over the BABS RNA-seq results - build the Quarto website index, release notes and combined manifest, set results/latest, list every output (HTML pages, xlsx, tsv, figures, R objects) and explain how to load the DESeq2 objects in R. Use after all report pages are rendered, or when asked where the results are, to package or hand over a BABS rnaseq analysis, or how to load its R objects.
---

# Report assembly and hand-over

`PLUGIN` = two directories above this file.

## Build the site

Once every staged page has been rendered for the current VERSION:

```
PLUGIN/skills/rnaseq-report/scripts/build-site.sh --dir ANALYSIS_DIR
PLUGIN/skills/rnaseq-report/scripts/list-outputs.sh --dir ANALYSIS_DIR
```

`build-site.sh` does what the makefile's `pages`, `notes` and `run` targets do
after rendering:
- renders `staging/index.qmd` and `staging/notes.md`
- copies `staging/results/<VERSION>/` to `results/<VERSION>/`
- merges the per-page manifests into `manifest<GIT_REF>.txt`
- points `results/latest` at the version
- writes `downloads.php`

It refuses if any page is missing.
Publishing to the intranet/internet (`make publish`) is out of scope.

## Hand over

Tell the user, with paths:
- **The website**: `results/<VERSION>/index.html` (open locally, or copy the whole
  `results/<VERSION>/` folder plus `results/multiqc-*` to share).
- **Spreadsheets**: `results/<VERSION>/02_differential_*/differential_*.xlsx`,
  one sheet per comparison.
- **R objects**: listed in `references/loading-results.md`.
- **What was run**: VERSION/GIT_REF, the image tag from `.env`, the spec(s)
  and data source(s), and anything you flagged at a checkpoint.

`references/loading-results.md` shows a bioinformatician how to load and
traverse the objects.
