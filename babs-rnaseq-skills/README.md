# babs-rnaseq-skills

A Claude Code plugin that runs the BABS bulk RNA-seq downstream analysis
(`00_init → 01_exploratory → 02_differential → 03_enrichment`, plus the Quarto
site) on an existing nf-core/rnaseq output. It uses the BABS R and Quarto
code **unchanged**. Only the `make` orchestration is replaced. See
[`../plan.md`](../plan.md) for the design and the agreed decisions.

## Layout

```
.claude-plugin/plugin.json
shared/                     vendored, byte-identical copies of babs/differential
  R/  resources/  renv.lock  .env  .gitignore
  sync-check.sh             diff against babs/differential (--update to re-copy)
  scripts/
    common.sh               make variables/recipes as shell functions (VERSION, GIT_REF, .env chain, container exec)
    render-section.sh       the per-page driver (staging, _quarto.yml, quarto render)
    run-in-container.sh     run any command in the pinned container
    run-r-helper.sh         run a read-only R summariser in the container
skills/
  babs-rnaseq-downstream/   orchestrator: order, checkpoints, references (spec grammar, experiment table)
    evals/                  Phase 8 agent test cases (prompt, expected outcome, graders, inputs)
  rnaseq-env-setup/         check-env.sh, restore-renv.sh
  rnaseq-ingest/            init-workdir.sh, discover-nfcore.sh, stage-inputs.sh, validate-inputs.sh, summarise-counts.R
  rnaseq-exploratory/       summarise-exploratory.R, reading-exploratory.md
  rnaseq-differential/      summarise-differential.R, results-columns.md
  rnaseq-enrichment/        summarise-enrichment.R, reading-enrichment.md
  rnaseq-report/            build-site.sh, list-outputs.sh, loading-results.md
tests/                      not used by the agent
  compare-to-reference.sh   compare an analysis directory with the Phase 0 reference run
  compare-objects.R         leaf-by-leaf comparison of the rds/rda/xlsx outputs
  prepare-trial.sh          Phase 8: set up one eval case for a session in the VS Code extension
  finish-trial.sh           Phase 8: collect that session's transcript and check the result
  check-trial.sh            objective checks on what a trial left behind
  check-results.R           match two runs' comparisons by their results, not their labels
  RUNBOOK.md                NEMO steps for testing each stage against the reference, and the Phase 8 trials
```

## Prerequisites

- **Tested:** NEMO with Singularity (`SINGULARITY_MODULE`), git, and network
  access to ghcr.io (image) and CRAN/Bioconductor (first `renv::restore`).
  sqlite3 on the host is optional; the container's copy is used otherwise.
- Put site settings in `.env.local` next to the analysis directory (or in any
  parent directory): `SINGULARITY_MODULE`, `SINGULARITY_IMAGEDIR`,
  `SINGULARITYENV_RENV_PATHS_ROOT`.
- Docker and bare-shell executors (`EXECUTOR=docker|shell`) are transcribed
  but **untested**.

## Install

For a session:

```
claude --plugin-dir /path/to/babs-template-rnaseq/babs-rnaseq-skills
```

To make it permanent, add it to a plugin marketplace and use `claude plugin install`.
`claude plugin validate babs-rnaseq-skills` checks the manifest. Then ask Claude to
"run the BABS downstream analysis on <nf-core outdir> with <experiment table>
and <spec>".

## Quick start without the agent

```
P=/path/to/babs-rnaseq-skills
$P/skills/rnaseq-ingest/scripts/init-workdir.sh ~/an
$P/skills/rnaseq-ingest/scripts/stage-inputs.sh --dir ~/an --nfcore NF_OUTDIR \
   --experiment-table experiment_table.csv --spec analyse.spec --config GRCh38.config
$P/skills/rnaseq-ingest/scripts/validate-inputs.sh --dir ~/an
$P/skills/rnaseq-env-setup/scripts/check-env.sh --dir ~/an --pull
$P/skills/rnaseq-env-setup/scripts/restore-renv.sh --dir ~/an
for s in 00_init; do $P/shared/scripts/render-section.sh --dir ~/an $s GRCh38; done
for s in 01_exploratory 02_differential 03_enrichment; do $P/shared/scripts/render-section.sh --dir ~/an $s GRCh38 analyse; done
$P/skills/rnaseq-report/scripts/build-site.sh --dir ~/an
```

## Keeping in sync

After changing anything in `babs/differential`, run `shared/sync-check.sh --update`
and commit. `init-workdir.sh` refuses to start while the copies differ.

## Status

Scripts have been syntax-checked and the ingest/staging/site-assembly flow
exercised locally with a stub `quarto`. Plan phases 0 (golden reference
run) and 3–8 (comparison against `make run` on NEMO, agent trials,
statistician review) are still to do.
