# Plan: converting the BABS bulk RNA-seq downstream analysis into Claude skills

## 1. Goal and constraints

Produce a Claude skills plugin that lets an agent be pointed at an nf-core/rnaseq
output directory, an `experiment_table.csv` and one or more `*.spec` files, and
carry out the BABS downstream analysis (initialisation, exploratory QC,
differential expression, enrichment) exactly as the existing `make`-driven
pipeline does.

Hard constraints:

- The statisticians' R code is the analysis. It is **not** rewritten, refactored
  or "simplified". The skills ship byte-identical copies of `babs/differential/R/*.r`
  and `babs/differential/resources/*.qmd`, and the agent runs that code.
- Nothing in the existing code base is edited. All new material lives in a new,
  self-contained plugin directory (or a separate repo; see open question 1).
- The user supplies `experiment_table.csv` and the `.spec` file(s). The skills
  validate them and run; they do not invent experimental designs.
- Anything the current `makefile` does that affects the analysis (parameter
  values, file layout, order of steps, container/package versions) is replicated
  faithfully by the skill scripts rather than re-imagined.

The thing being replaced is **only the orchestration layer** (make, the
docs/ingress/nfcore gathering, the Quarto staging). The thing being preserved is
**everything that executes inside R**.

## 2. How the current pipeline works (what the skills must reproduce)

### 2.1 Stage orchestration (`babs/makefile`)

```
docs  ->  ingress  ->  nfcore  ->  differential     (biologic is optional, out of scope)
```

`make all` in `babs/` equals `make differential`; each stage pulls its
prerequisites from the stage upstream of it via make dependencies.

| Stage | What it does | Relevant to the skills? |
|---|---|---|
| `docs` | Checks `*.spec`, `*.config`, `experiment_table.csv`, `samplesheet.csv` exist and are well formed (`ID` first column, `sample_label` second column recommended). | Yes, the validation rules carry over. |
| `ingress` | Copies docs files, strips CR, fills config defaults (`universal=yes`, `strandedness=auto`, `aligner=star_rsem`), md5s fasta/gtf. | Only the CR stripping and the `aligner` default matter downstream. |
| `nfcore` | Builds per-config samplesheet (sqlite join), runs `nf-core/rnaseq` (`-r 3.26.0` in `module.mk`, 3.10.1 in docs), symlinks `results/<config>/merged.gene_counts.tsv` and `results/<config>/multi-qc`. | No. The agent starts from an existing nf-core output. The skills must *discover* the same files `differential` would have pulled. |
| `differential` | The downstream R/Quarto analysis. | Yes, entirely. |

### 2.2 What `differential/make run` gathers (the input contract)

For each `data_source` (the basename of a `*.config`, e.g. `GRCh38`) and each
`spec` (basename of a `*.spec`), `make run` assembles this layout inside the
`differential` folder, which is also the working directory for every R chunk
(`quarto render --execute-dir $(CURDIR)`):

```
differential/
├── R/                                   # function library (sourced by every qmd)
├── resources/                           # qmd templates, _quarto.yml, css, html, _extensions, typescript, params.yml
├── extdata/
│   ├── <spec>.spec                      # copied from docs
│   ├── <ds>.config                      # at minimum "<ds>.org.db=org.Hs.eg.db" (prefixed with the data_source name)
│   ├── metadata.csv                     # experiment_table.csv, CR-stripped
│   ├── metadata_<ds>.csv                # metadata INNER JOIN nfcore samplesheet on metadata.ID = samplesheet.sample
│   ├── genes.results/<ds>/*.genes.results            # star_rsem: hard-linked from nfcore/results/<ds>/star_rsem/
│   ├── genes.results/<ds>/star_salmon/<sample>/quant.sf + salmon_tx2gene.tsv   # if aligner=star_salmon
│   └── R.bib                            # knitr::write_bib of every package in renv.lock
├── results/multiqc-<ds>/                # copied from nfcore/results/<ds>/multi-qc
├── data/                                # R objects written by the qmds
├── staging/                             # generated qmds + _quarto.yml + R.bib + css/html/_extensions
├── results/<VERSION>/                   # rendered html, tsv, xlsx, pdf/png figures, manifest
└── logs/
```

### 2.3 Report sections and per-page parameters

`resources/make/project.mk` defines `sections = 00_init 01_exploratory 02_differential 03_enrichment`.
(`04_gene_plots.qmd` exists but is **not** in `sections`, has hard-coded
aesthetics, and is treated as work in progress; excluded, see open question 5.)

Pages are instantiated per combination:

| Section | Instantiated per | Parent (must run first) | Reads | Writes |
|---|---|---|---|---|
| `00_init` | data_source | none | `extdata/<ds>.config`, `extdata/metadata_<ds>.csv`, `extdata/genes.results/<ds>/` | `data/counts_<ds>.rda` + `.rds` (annotated `DESeqDataSet`, design `~1`) |
| `01_exploratory` | spec x data_source | `00_init_<ds>` | `data/counts_<ds>`, `extdata/<spec>.spec` | `data/ddsList_<ds>_<spec>.rda`, `data/exploratory_plots.rds`, assay/PC/cluster/expected tsv, manifest |
| `02_differential` | spec x data_source | `01_exploratory_<spec>_<ds>` | `data/ddsList_<ds>_<spec>` | `data/<spec>_x_<ds>.rds` + `.rda` (fitted ddsList with results), `differential_<dataset>.xlsx`, cluster tsv, manifest |
| `03_enrichment` | spec x data_source | `02_differential_<spec>_<ds>` | `data/counts_<ds>`, `data/<spec>_x_<ds>` | enrichment dotplots and csv tables |

Each staged qmd gets a YAML header merged (by `resources/typescript/merge_yml.ts`)
from four sources: the template qmd, `resources/params.yml` (authors), the
make-generated `staging/<VERSION>.params.yml`, and a per-page `staging/<page>.yml`.
The resulting `params` the R code depends on are:

```
res_dir      = results/<VERSION>
VERSION      = git tag | "unreleased" | "modified" (from shared.mk)
GIT_REF      = _<VERSION>-<short hash>     (embedded in every output filename via p2filename / rename_with_tag)
staging_dir  = staging
file_col     = ID                           (metadata_id_column)
name_col     = sample_name
metadata     = extdata/metadata_<ds>.csv
counts       = extdata/genes.results/<ds>/
data_source, spec, specname, data_sourcename, script, section
```

The skill drivers must produce these same params; the R code reads them via the
knitr `params` object (and via `load_params(choose_staging(...))` only when run
interactively outside knitr).

### 2.4 The R data flow (the code that must run unchanged)

- **`00_init.qmd`**: `get_data_source_params()` reads the config; loads/installs
  the `org.db`; chooses rsem vs salmon input by the presence of
  `star_salmon/salmon_tx2gene.tsv`; `tximport` -> `DESeqDataSetFromTximport(~1)`;
  drops all-zero rows; `add_org_annotation()` adds `symbol`/`entrez`/`ensembl`
  via `mapIds`; `trim_names()` shortens sample labels; saves `counts_<ds>`.
  Alternative entry points already in the code: `<ds>.rda`, `<ds>.rds`, `<ds>.csv`
  (limma mode), or simulation when `ID` is blank.
- **`01_exploratory.qmd`**: `load_specs()` evaluates the spec file in a
  controlled environment (the `specification/sample_set/model/mult_comp/...`
  grammar documented in `pkgdown/vignettes/spec.rmd`); `build_dds_list()` expands
  sample_sets x models x comparisons with cascading defaults, applies `subset`,
  `transform`, feature filters, palettes; `sample_norm()` (size factors, `vst`);
  `removeLow()` (`baseMeanMin`); `add_extra_assays()`; then per dataset x model x
  `profile_plot`: top-variable heatmap (`bluster` clustering, `hmap_fn`), sorted
  heatmap, cluster-centroid profiles, 2-D PCA, covariate x PC association
  (`mat_x_terms`), 1-D PC plots; writes assays, PC projections, clusters,
  expected values, manifest.
- **`02_differential.qmd`**: `fit_models()` -> `fit_model()` -> `check_model()`
  (lm rank check, `drop_unsupported_combinations`, constraints) ->
  `fit_comparison()` choosing Wald / LRT / emmeans-expanded `multiWald`
  (`emcontrasts`) / limma / voom; `get_result()` (DESeq2 `results` with `IHW`
  `filterFun`, `alpha`, `lfcThreshold`, `ashr` shrinkage, `class` labels
  `Up*`/`Down*`/`Low Count`/`Outlier`/`Zero Count`, LRT max-fold-change
  heuristic); saves `<spec>_x_<ds>`; `write_results()` (xlsx per dataset);
  summary tables, p-value diagnostics, per-comparison MA plot, significant-gene
  heatmaps, cluster profiles, PCA; manifest.
- **`03_enrichment.qmd`**: four default approaches (GO MF and Reactome, each as
  GSEA and over-representation) via `functional_api()` (clusterProfiler /
  ReactomePA on `entrez` keyed `shrunkLFC`), `default_post_process()`,
  dotplots and `gt` tables.

Shared machinery the qmds rely on: `plot_tracker()`/`table_tracker()` (emit knitr
child chunks and record figure paths), `dmc_heading()`/`src2bullets()` (headings
from the spec), `nested_modify()`/`leaf_modify()` (tree traversal of the
ddsList), `p2filename()` (output naming with `GIT_REF`).

### 2.5 Runtime environment

- R 4.6.0 / Bioconductor 3.23 inside
  `ghcr.io/franciscrickinstitute/babs-environments/bioconductor_docker:3.23-R-4.6.0-v1.14.0`
  (`.env`), run via singularity, docker or bare shell (`EXECUTOR` in `shared.mk`).
- Package versions pinned in `babs/differential/renv.lock`; `resources/_dependencies.R`
  gets `library(<org.db>)` appended before `renv::restore()`.
- Quarto (with Deno for the two `.ts` helpers), `tooltips` and `notes` lua
  extensions, `R.bib` bibliography.
- The `renv`, `R.bib` and `_quarto.yml` generation are make recipes and have to
  be replicated by the skills.

## 3. Design decisions for the conversion

1. **Vendor, don't port.** The plugin contains verbatim copies of `R/`,
   `resources/*.qmd`, `resources/_quarto*.yml`, `resources/params.yml`,
   `resources/css`, `resources/html`, `resources/_extensions`,
   `resources/typescript`, `resources/_dependencies.R`, `renv.lock`, `.env`,
   `resources/docker/`. A `sync-check` script diffs the vendored copies against
   `babs/differential` so drift is impossible to miss.
2. **Replace make with thin driver scripts, one per section.** Each driver does
   exactly what the corresponding make recipe does (write `staging/<page>.yml`,
   run `merge_yml.ts`, build `_quarto.yml` with `sidebar.ts`, `quarto render`
   with `--execute-dir`), nothing more. The R chunks therefore run in the same
   working-directory layout, with the same params, as under `make run`.
3. **The agent's working directory mirrors `differential/`.** The first skill
   creates an analysis folder with the layout in section 2.2 so every relative
   path in the R code resolves unchanged.
4. **Render pages individually and in dependency order** (the makefile's `pages`
   path, which it notes is equivalent to `run` but safer sequentially). This
   gives the agent a natural checkpoint after each section to read logs, surface
   warnings (for example the "Can't estimate some coefficients" rank warning)
   and report back before continuing.
5. **The agent interprets, the R code computes.** New code is limited to
   drivers, validators and read-only summarisers of the output objects. No new
   statistics.
6. **Structure follows the Claude skills anatomy** (`SKILL.md` with name and
   description frontmatter, `scripts/`, `references/`, `assets/`), with one
   orchestrating skill and one skill per stage, so each SKILL.md stays short and
   the heavy material is in references loaded on demand.

## 4. Proposed plugin layout

```
babs-rnaseq-skills/                          # new directory (or repo), nothing else in the repo changes
├── .claude-plugin/plugin.json               # plugin manifest (verify field names against current Claude Code plugin docs)
├── README.md                                # how to install, prerequisites, quick start
├── shared/                                  # single vendored copy used by every skill
│   ├── R/                                   # byte-identical to babs/differential/R
│   ├── resources/                           # byte-identical subset of babs/differential/resources (see 3.1)
│   ├── renv.lock  .env  _dependencies.R
│   └── sync-check.sh                        # diff -r against babs/differential; fails on any difference
└── skills/
    ├── babs-rnaseq-downstream/              # orchestrator: the whole workflow, order, decision points
    ├── rnaseq-env-setup/                    # container + renv + quarto readiness
    ├── rnaseq-ingest/                       # nf-core discovery, inputs validation, 00_init
    ├── rnaseq-exploratory/                  # 01_exploratory
    ├── rnaseq-differential/                 # 02_differential
    ├── rnaseq-enrichment/                   # 03_enrichment
    └── rnaseq-report/                       # site assembly, manifest, results reading
```

### 4.1 Skill by skill

**`babs-rnaseq-downstream` (orchestrator)**
- Triggers on: "analyse this nf-core run", "run the BABS downstream", "DESeq2
  on these counts with this spec", any mention of experiment table + spec.
- Body: the stage order and the parent dependencies from section 2.3; what to
  ask the user up front (nf-core results dir, experiment table, spec(s), org.db
  / species, aligner); the checkpoint protocol (after each stage: show the log
  tail, the warnings, the key numbers, ask before continuing only when something
  looks wrong); where outputs land.
- `references/pipeline-overview.md`: condensed version of section 2 of this
  plan. `references/spec-grammar.md`: the `spec.rmd` vignette, verbatim.
  `references/experiment-table.md`: the docs/readme rules.

**`rnaseq-env-setup`**
- `scripts/check-env.sh`: detect docker / singularity / bare R + quarto; report
  versions; locate or pull the image named in `.env`; locate renv cache.
- `scripts/restore-renv.sh`: replicate the makefile `renv` target (append
  `library(<org.db>)` to `_dependencies.R`, `renv::restore()`, install org.db,
  `knitr::write_bib` -> `extdata/R.bib`).
- `scripts/run-in-container.sh <cmd>`: the `CONTAINER_OPTIONS` / bind logic from
  `shared.mk`, so every later driver runs through one wrapper regardless of
  executor.
- SKILL.md explains why the pinned image and lockfile matter (reproducibility
  of the statisticians' results) and what to do when the image cannot be pulled.

**`rnaseq-ingest`**
- `scripts/init-workdir.sh <analysis_dir>`: create the section 2.2 layout and
  copy `shared/R`, `shared/resources` into it.
- `scripts/discover-nfcore.sh <nfcore_results_dir>`: find
  `star_rsem/*.genes.results` or `star_salmon/*/quant.sf` + `salmon_tx2gene.tsv`,
  the multiqc folder, the samplesheet; print what was found and which aligner it
  implies. Handles both the 3.10.x and 3.26.x result layouts.
- `scripts/stage-inputs.sh`: the gathering recipes from the differential
  makefile: CR-strip the experiment table to `extdata/metadata.csv`; inner-join
  with the samplesheet on `ID` = `sample` to make `extdata/metadata_<ds>.csv`
  (same semantics as the sqlite recipe; report dropped samples); hard-link or
  copy counts into `extdata/genes.results/<ds>/`; copy multiqc to
  `results/multiqc-<ds>/`; write `extdata/<ds>.config` with the `<ds>.` prefix
  and at least `org.db`; copy spec(s) to `extdata/`.
- `scripts/validate-inputs.sh`: the `docs` stage checks (first column `ID`,
  `sample_label` advice, non-empty files), plus the `check_spec` recipe
  (`parse()` every spec in R) and a covariate check (every variable named in
  spec designs/transforms exists in the experiment table).
- `scripts/render-section.sh <section> <ds> [<spec>]`: the generic driver used
  by this and the three analysis skills (per-page yml, `merge_yml.ts`,
  `sidebar.ts` -> `_quarto.yml`, `<VERSION>.params.yml`, `quarto render
  --execute-dir`, log to `logs/`). Lives in `shared/`, referenced from each skill.
- SKILL.md: run `00_init` and then read `data/counts_<ds>.rds` with a read-only
  helper (`scripts/summarise-counts.R`: dims, samples kept/dropped, annotation
  coverage, organism) so the agent can report the ingest outcome.

**`rnaseq-exploratory`**
- Runs `render-section.sh 01_exploratory <ds> <spec>`.
- `scripts/summarise-exploratory.R` (read-only): feature-filter table, datasets
  and models found in the spec, which profile plots were produced, the
  covariate x PC association table, paths of the figures and tsv downloads.
- `references/reading-exploratory.md`: the explanatory prose already in the qmd
  (heatmaps, cluster centroids, PC association, PC scatter) so the agent
  interprets plots the way the report text does.

**`rnaseq-differential`**
- Runs `render-section.sh 02_differential <ds> <spec>`.
- `scripts/summarise-differential.R` (read-only): loads `data/<spec>_x_<ds>.rds`,
  prints per dataset/model/comparison the counts of `Up*`/`Down*`/other
  classes, the approach used (Wald/LRT/multiWald/limma), the `alpha`,
  `lfcThreshold`, `filterFun` in force, and the xlsx path.
- `references/results-columns.md`: meaning of `baseMean`, `log2FoldChange`,
  `shrunkLFC`, `padj`, `sig`, `class`, `maxLog2FoldChange`, the `A-B|M` naming
  convention, and the caveats paragraph from the spec vignette (multiplicity,
  Table Two fallacy).
- SKILL.md tells the agent what warnings mean (rank deficiency, dropped models
  with no replication, dropped comparisons) and that fixes belong in the spec,
  not in the code.

**`rnaseq-enrichment`**
- Runs `render-section.sh 03_enrichment <ds> <spec>`.
- `scripts/summarise-enrichment.R` (read-only): top terms per approach and
  comparison from the csv tables the page writes.
- `references/reading-enrichment.md`: the "Introduction to Functional Analysis"
  text from the qmd (OR vs GSEA, relative effect, NES).

**`rnaseq-report`**
- `scripts/build-site.sh`: the `index.qmd` listing, `notes.md`, the combined
  `manifest<GIT_REF>.txt`, `results/latest` symlink, `downloads.php`
  substitution; optionally the `publish` copy.
- `scripts/list-outputs.sh`: tabulate everything under `results/<VERSION>/`.
- SKILL.md: how to hand results back (the html site, the xlsx, the rds objects
  and how a bioinformatician loads them, as in `BABS-RNASeq.rmd`).

## 5. Step-by-step conversion process

### Phase 0: freeze a reference run (before writing any skill)
1. Run the existing pipeline end to end on the airway test data
   (`make test`, `make test-differential` in the repo root; the cached
   `airway/nfcore.tar.gz` route avoids re-aligning). Keep the whole
   `test/babs/differential` folder as the golden reference: `data/*.rds`,
   `results/<VERSION>/**`, `staging/*.qmd`, `logs/*`.
2. Record the exact image tag, `renv.lock` hash, quarto version and the git
   `VERSION`/`GIT_REF` used, so the skills can be checked against them.
3. Save the generated `staging/*.yml`, `staging/<VERSION>.params.yml` and
   `staging/_quarto.yml`; these are the specification for what the driver
   scripts must emit.

### Phase 1: plugin skeleton and vendored assets
4. Create `babs-rnaseq-skills/` with the layout in section 4; copy the files
   listed in design decision 1 verbatim; write `sync-check.sh` and run it.
5. Write `.claude-plugin/plugin.json` and a README with prerequisites
   (container runtime or R 4.6 + quarto, renv cache location, org.db packages).

### Phase 2: environment skill
6. Write `check-env.sh`, `run-in-container.sh`, `restore-renv.sh` by lifting
   the corresponding logic from `shared.mk` (EXECUTOR branches, bind paths,
   env vars like `OMP_NUM_THREADS`, `BIOCPARALLEL_WORKER_NUMBER`) and the
   makefile `renv` target.
7. Test: inside a fresh directory, the scripts reach a state where
   `Rscript -e 'library(DESeq2); library(IHW); library(emmeans)'` and
   `quarto --version` succeed inside the chosen executor.

### Phase 3: ingest skill
8. Write `init-workdir.sh`, `discover-nfcore.sh`, `stage-inputs.sh`,
   `validate-inputs.sh` and the shared `render-section.sh`.
9. Test `render-section.sh 00_init GRCh38` against the airway reference:
   the staged qmd header must match the reference `staging/00_init_GRCh38.qmd`
   header (modulo `VERSION`/`GIT_REF`/author) and `data/counts_GRCh38.rds` must
   be identical in dims, colData, rowData and counts.
10. Write `summarise-counts.R` and the SKILL.md.

### Phase 4: exploratory skill
11. Test `render-section.sh 01_exploratory GRCh38 analyse` against the
    reference: `ddsList_GRCh38_analyse.rda` equal (sample sets, models,
    assays, filters); every tsv under `results/<VERSION>/01_exploratory_*/`
    equal after stripping `GIT_REF` from names; same set of figures.
12. Write `summarise-exploratory.R`, references and the SKILL.md.

### Phase 5: differential skill
13. Test `02_differential` likewise: `analyse_x_GRCh38.rds` results tables equal
    (padj, shrunkLFC, class) per comparison; xlsx sheets equal.
14. Write `summarise-differential.R`, references and the SKILL.md.

### Phase 6: enrichment skill
15. Test `03_enrichment` likewise (csv tables equal given the same seed).
16. Write `summarise-enrichment.R`, references and the SKILL.md.

### Phase 7: report skill and orchestrator
17. Write `build-site.sh` and `list-outputs.sh`; confirm the rendered site
    opens with the index listing and the manifest downloads resolving.
18. Write the orchestrator SKILL.md and its references (section 4.1).

### Phase 8: end-to-end agent trials
19. Using the skill-creator workflow, write 3 to 4 test prompts (airway with the
    shipped spec; a two-factor spec from `example_docs/analyse.spec`; a salmon
    run; a deliberately broken spec with an unknown covariate) and run them
    through an agent with the plugin installed, saving outputs per iteration.
20. Compare against the Phase 0 reference with a script
    (`scripts/compare-to-reference.sh`): same objects, same tables, same figure
    set. Fix drivers until they match; the R code is never the thing fixed.
21. Have the statisticians review one full agent run and the SKILL.md texts
    (particularly what the agent is told to say about results).

### Phase 9: polish
22. Tune the skill descriptions for triggering (skill-creator's description
    optimiser), package, document installation, decide on export rules
    (`.gitattributes`) if the plugin lives in this repo.

## 6. Verification standard

A skill run is correct when, for the same inputs, image, lockfile and seed, it
produces the same `data/*.rds` contents and the same tsv/csv/xlsx tables as
`make run`, differing only in `VERSION`/`GIT_REF`, author metadata and
timestamps. This is checkable because all randomness is seeded from
`settings$seed` and the code is identical.

## 7. Open questions and working assumptions

1. **Where does the plugin live?** Assumed: a new top-level directory in this
   repo, marked `export-ignore` so it never reaches project tarballs. A
   separate repo is the alternative if the plugin should version independently
   of the template.
2. **Which executor will agents have?** Assumed: docker on workstations,
   singularity on NEMO. If agents will only ever have a bare R, the env skill
   needs a documented "shell" path with renv from the lockfile and a warning
   that results are not container-reproducible.
3. **Is the HTML report required, or are the objects and tables enough?**
   Assumed: the report is rendered because that is how the code is intended to
   run (`plot_tracker` and `table_tracker` only save figures and csvs inside
   knitr). Dropping Quarto would mean changing how the R code is invoked.
4. **nf-core version in the wild.** The repo references both 3.10.1 and 3.26.0.
   Assumed: both layouts must be discovered; the skill reports which it found.
5. **Scope of sections.** Assumed: `00_init` to `03_enrichment` only.
   `04_gene_plots.qmd` (not in `sections`, hard-coded aesthetics) and the
   `biologic` export are excluded unless requested.
6. **Spec authoring.** Assumed: the user provides the spec; the skill validates
   it and, if asked, helps edit it using the vignette grammar, but never
   silently rewrites a design.
7. **Git versioning of results.** `VERSION`/`GIT_REF` come from `git describe`.
   Assumed: the analysis directory is initialised as a git repo (as
   `isolated.sh` does) so output naming stays identical; otherwise the driver
   falls back to `unreleased`/`uncontrolled` exactly as `shared.mk` does.
8. **Multiple specs and configs.** Supported by looping the drivers over
   spec x data_source, honouring `<ds>.spec` / `<ds>.nospec` restrictions from
   the config, as the makefile does.
9. **Crick-specific text** (Terms of Use, affiliations in `params.yml`) is kept
   as is, since the qmds are vendored verbatim; confirm this is wanted for
   non-Crick users.

## 8. Explicitly out of scope

- Running nf-core/rnaseq, fetch_ngs, or any alignment.
- The Shiny `Explorer.R`, RStudio/Jupyter launchers, publishing to intranet.
- Any change to statistical methodology, defaults, thresholds or plots.
