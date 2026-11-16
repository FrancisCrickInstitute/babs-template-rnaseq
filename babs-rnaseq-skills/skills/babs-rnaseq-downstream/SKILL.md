---
name: babs-rnaseq-downstream
description: Run the BABS bulk RNA-seq downstream analysis (DESeq2 initialisation, exploratory QC, differential expression, GO/Reactome enrichment, Quarto HTML report) on an existing nf-core/rnaseq output, using an experiment_table.csv and one or more .spec files. Use whenever someone asks to analyse an nf-core rnaseq run, run the BABS/Crick downstream or "differential" stage, run DESeq2 with a spec file, or mentions an experiment table together with a spec. This is the entry point; it sequences the rnaseq-env-setup, rnaseq-ingest, rnaseq-exploratory, rnaseq-differential, rnaseq-enrichment and rnaseq-report skills.
---

# BABS RNA-seq downstream analysis (orchestrator)

This runs the statisticians' existing R/Quarto analysis unchanged. Your job is
orchestration and interpretation. **Never edit, rewrite or "fix" anything in
`R/` or `resources/*.qmd`**, in the plugin or in the analysis directory.
When something fails, the fix belongs in the inputs (spec, experiment table,
config) or the environment, never in the code.

`PLUGIN` below means the plugin root: the directory two levels above this file.

## 1. Ask for these up front (do not guess)

1. **nf-core output directory**: the run's `--outdir`, or a BABS `babs/nfcore`
   folder plus the data-source name. The tested target is nf-core/rnaseq
   3.26.0 with `star_rsem`.
2. **experiment_table.csv**: the first column must be `ID`, with values matching the
   nf-core sample names. See `references/experiment-table.md`.
3. **spec file(s)** (`*.spec`): supplied by the user. **Never draft a spec
   unprompted.** Edit one only when the user asks, using
   `references/spec-grammar.md`.
4. **Annotation**: a BABS `<genome>.config` (preferred), or just the org.db
   package (e.g. `org.Hs.eg.db`, `org.Mm.eg.db`).
5. **Where to create the analysis directory**: a new, empty path.

## 2. Stage order

Each step is a skill. Follow its SKILL.md.

| Step | Skill | What happens |
|---|---|---|
| a | `rnaseq-env-setup` | `check-env.sh`: container image and renv cache ready |
| b | `rnaseq-ingest` | `init-workdir.sh` → `stage-inputs.sh` → `validate-inputs.sh` |
| c | `rnaseq-env-setup` | `restore-renv.sh` (needs the staged config for the org.db) |
| d | `rnaseq-ingest` | render `00_init` for each data source, then `summarise-counts.R` |
| e | `rnaseq-exploratory` | render `01_exploratory` for each spec × data source |
| f | `rnaseq-differential` | render `02_differential` for each spec × data source |
| g | `rnaseq-enrichment` | render `03_enrichment` for each spec × data source |
| h | `rnaseq-report` | `build-site.sh`, `list-outputs.sh`, hand-over |

Each page's parent must be rendered first: 00 → 01 → 02 → 03, for the same
data source and spec. With several specs or data sources, loop over every
combination that `<ds>.spec` / `<ds>.nospec` in the config allows. The full
list of pages comes from
`bash -c 'source PLUGIN/shared/scripts/common.sh; cd ANALYSIS_DIR; babs_all_pages'`.

Rendering a page can take minutes (02 and 03 especially). Run it in the
background or as a SLURM job if the session might time out, then read
the log.

## 3. Checkpoint after every page

After each render:
1. Run that stage's summariser and read its output.
2. Scan `logs/html-<page>.log` for `Warning`, `Error`, `dropped`,
   `Can't estimate`, `rank`, `no replication`
   (`grep -nEi 'warn|error|dropp|rank|replicat' logs/html-<page>.log`).
   Because the qmds use `error: true`, an R error does NOT stop the render.
   The page still appears, with the error printed in it. Always check.
3. Report the key numbers (samples, features, significant genes per
   comparison) and any warnings to the user in a few lines.
4. Carry on without asking unless something looks wrong: an R error, a
   dropped model or comparison, zero significant genes everywhere, samples lost
   in the join, or a VERSION that changed between pages. Then stop and explain.

## 4. VERSION and file names

Output names carry `GIT_REF = _<VERSION>-<hash>` computed from the analysis
directory's git state, exactly as make does. `restore-renv.sh` commits once.
After that, tracked files must not change between pages, or VERSION flips to
`modified` and later pages will not find their parent. If you must change a
spec mid-run, re-stage it and re-render from `00_init`.

## 5. References

- `references/pipeline-overview.md`: what make did and what each driver replaces.
- `references/spec-grammar.md`: the spec vignette, verbatim.
- `references/experiment-table.md`: experiment table and config rules.
