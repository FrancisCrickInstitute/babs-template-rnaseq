---
name: rnaseq-ingest
description: Set up a BABS RNA-seq analysis directory from an nf-core/rnaseq output - discover the star_rsem counts, MultiQC and samplesheet, stage experiment_table.csv, config and spec files, validate them (ID column, spec parses, spec covariates exist) and render the 00_init page that builds the annotated DESeqDataSet. Use when starting a BABS downstream analysis, when pointing at a new nf-core results folder, or when checking an experiment table or spec against the data.
---

# Ingest: from nf-core output to `data/counts_<ds>.rds`

`PLUGIN` = two directories above this file. `<ds>` is the data source label,
normally the genome/config name (e.g. `GRCh38`). It appears in every file
name, so use the user's config name.

## 1. Create the analysis directory

```
PLUGIN/skills/rnaseq-ingest/scripts/init-workdir.sh ANALYSIS_DIR
```

This copies the vendored `R/`, `resources/`, `renv.lock`, `.env` and `.gitignore`.
It refuses if `shared/sync-check.sh` reports drift from `babs/differential`.
It then `git init`s with the `bootstrap-isolated-analysis` tag, as `isolated.sh` does.

## 2. Look at the nf-core output

```
PLUGIN/skills/rnaseq-ingest/scripts/discover-nfcore.sh NFCORE_DIR [--data-source DS]
```

Report the NOTE lines to the user:
- A version other than 3.26.0, or `star_salmon`, is reported, not assumed
  to work. Say so, and continue only with the user's agreement.
- An `unrecognised` layout (exit status 1) means stop.
- `SAMPLESHEET_SOURCE=derived` means the sample list came from the
  `*.genes.results` names. That is fine, but mention it.

## 3. Stage the inputs

```
PLUGIN/skills/rnaseq-ingest/scripts/stage-inputs.sh --dir ANALYSIS_DIR \
  --nfcore NFCORE_DIR --experiment-table experiment_table.csv \
  --spec analyse.spec [--spec other.spec] \
  (--config GRCh38.config | --org-db org.Hs.eg.db --data-source GRCh38)
```

This does the makefile's gathering recipes: strips CR characters, joins the
experiment table to the samplesheet (`ID = sample`, same sqlite SQL), and
hard-links the counts and MultiQC. **Always relay the DROPPED / NOT ANALYSED lines.**
A sample silently missing from the join is the most common ingest mistake,
usually caused by IDs that don't match the fastq/sample names.
Repeat for each data source (config).

## 4. Validate

```
PLUGIN/skills/rnaseq-ingest/scripts/validate-inputs.sh --dir ANALYSIS_DIR
```

This runs the docs-stage checks and the makefile `check_spec` parse (output in
`logs/check_spec.log`). It also checks that every formula variable in the spec
is a column of the joined experiment table, or is created by
`transform=mutate(...)`.

On errors, explain them using `babs-rnaseq-downstream/references/spec-grammar.md`
and ask the user how to fix them. Edit the spec only if they ask.
Warnings about `aes()` names are fine when they are extra-assay names.

Then run `rnaseq-env-setup/scripts/restore-renv.sh` if it has not been run yet.

## 5. Render 00_init and summarise

```
PLUGIN/shared/scripts/render-section.sh --dir ANALYSIS_DIR 00_init DS
PLUGIN/shared/scripts/run-r-helper.sh --dir ANALYSIS_DIR PLUGIN/skills/rnaseq-ingest/scripts/summarise-counts.R DS
```

The renderer stages every page's qmd and `_quarto.yml` first, as make does,
then renders this one page with `--execute-dir` set to the analysis directory.

Report:
- features × samples
- library-size range
- annotation coverage: low symbol coverage means the wrong org.db
- any experiment-table samples absent from the object

`00_init` also accepts `extdata/<ds>.rda|.rds|.csv` instead of counts, and
simulates counts if `ID` is blank. Only use those routes if the user asks.
