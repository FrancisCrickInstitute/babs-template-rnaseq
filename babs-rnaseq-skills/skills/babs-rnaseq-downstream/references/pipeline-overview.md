# What `make` did, and what replaces it

The BABS template runs `docs → ingress → nfcore → differential`. These skills
start from an existing nf-core/rnaseq output, so only the `differential`
stage and the parts of `docs`/`ingress` it depends on are replicated.

| make recipe (babs/differential) | replaced by |
|---|---|
| `check-isolated` / `isolated.sh` (git init + `bootstrap-isolated-analysis` tag) | `rnaseq-ingest/scripts/init-workdir.sh` |
| `$(my_metadata).csv` (copy of CR-stripped experiment table) | `stage-inputs.sh` |
| `extdata/<ds>.config` (ingress: CR strip, `universal`/`strandedness`/`aligner` defaults) | `stage-inputs.sh` (md5 lines omitted, unused downstream) |
| `$(covariate_files)`: sqlite `metadata INNER JOIN samplesheet ON ID = sample` | `stage-inputs.sh` (same SQL) |
| `$(genes_results)`: hard-link `star_rsem/*.genes.results` (or salmon quant.sf) and multiqc | `stage-inputs.sh` |
| docs-stage file checks, `$(log_dir)/check_spec.log` | `validate-inputs.sh` (+ covariate check) |
| `renv`, `extdata/R.bib` | `rnaseq-env-setup/scripts/restore-renv.sh` |
| `$(qmds:qmd=yml)`, `$(VERSION).params.yml`, `merge_yml.ts`, `choose_staging` sed | `shared/scripts/render-section.sh` |
| `staging/_quarto.yml` (`sidebar.ts`), css/html/_extensions, `index.qmd`, `notes.md` | `render-section.sh` |
| `html-<page>` (`quarto render --execute-dir`) | `render-section.sh SECTION DS [SPEC]` |
| `pages` / `notes` / manifest, `latest`, `downloads.php` from `run` | `rnaseq-report/scripts/build-site.sh` |
| `$(containerPrefix)` (singularity exec … --containall --cleanenv) | `shared/scripts/common.sh: babs_exec` |

Sections (`project.mk`): `00_init` (one per data source), then `01_exploratory`,
`02_differential` and `03_enrichment` (one per spec × data source), with parents
00 → 01 → 02 → 03. `04_gene_plots` and `biologic` are not run.

Parameters every page receives (from `project.mk` `param_names` plus the
per-page yml): `res_dir=results/<VERSION>`, `VERSION`, `GIT_REF`,
`staging_dir=staging`, `file_col=ID`, `name_col=sample_name`,
`metadata=extdata/metadata_<ds>.csv`, `counts=extdata/genes.results/<ds>/`,
`data_source`, `spec`, `specname`, `data_sourcename`, `script`, `section`.

Known differences from make, all in orchestration only:
- `metadata`/`counts` in `staging/<VERSION>.params.yml` are written per page.
  make writes them once, for whichever data source it builds first, which
  matters only with more than one config.
- `resources/_dependencies.R` gets one `library()` line per org.db. make
  writes a single invalid line when there are several.
- A failed `quarto render` is reported as a failure. make piped it through
  `tee` and carried on.
- The `.latest` checkpoint file, `retag` and `publish` are not replicated.
