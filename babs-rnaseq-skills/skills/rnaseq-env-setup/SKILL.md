---
name: rnaseq-env-setup
description: Prepare and check the runtime for the BABS RNA-seq downstream analysis - the pinned BABS Bioconductor singularity image (R 4.6.0 / Bioconductor 3.23), the renv library from renv.lock, Quarto, and the R.bib bibliography. Use before rendering any BABS rnaseq report page, when a render fails with missing packages or a missing image, or when asked to check, pull or set up the analysis container or renv.
---

# Runtime for the BABS RNA-seq analysis

The results are only reproducible with the pinned container image (`.env`:
`ghcr.io/franciscrickinstitute/babs-environments/bioconductor_docker:3.23-R-4.6.0-v1.14.0`)
and the package versions in `renv.lock`. Do not substitute a different R,
Bioconductor or package version to "get it working". If the image cannot be
obtained, stop and tell the user.

`PLUGIN` = two directories above this file. Every script takes `--dir ANALYSIS_DIR`.

## Supported executor

**Singularity on NEMO** is the tested path (plan decision 2). Set
`EXECUTOR=docker` or `EXECUTOR=shell` only if the user asks. Both are
transcribed from `shared.mk` but untested, and `shell` is not reproducible.

The analysis directory's `.env` chain is read as make reads it: `.env`,
`.env.local`, `.env.$USER`, `.env.local.$USER`, from the outermost
directory inwards. On NEMO, `.env.local` normally needs:

```
export SINGULARITY_MODULE=Singularity/3.11.3
export SINGULARITY_IMAGEDIR=/path/to/shared/sif/store
export SINGULARITYENV_RENV_PATHS_ROOT=/path/on/fast/disk/renv-cache
```

Without `SINGULARITYENV_RENV_PATHS_ROOT`, `--containall` gives a throw-away
home directory and packages are reinstalled on every call.

## Steps

1. `PLUGIN/skills/rnaseq-env-setup/scripts/check-env.sh --dir ANALYSIS_DIR`
   reports the executor, the singularity version, where the `.sif` is, and the renv cache.
   - Image missing: re-run with `--pull`. Pulling from ghcr.io may need
     `DOCKER_USERNAME`/`DOCKER_PASSWORD` (falls back to `GITHUB_PAT`). Ask the
     user to set these; never type a token yourself.
2. After `rnaseq-ingest/stage-inputs.sh` has written `extdata/<ds>.config`, run
   `PLUGIN/skills/rnaseq-env-setup/scripts/restore-renv.sh --dir ANALYSIS_DIR`.
   This replicates the makefile `renv` target:
   - adds `library(<org.db>)` to `resources/_dependencies.R`
   - runs `renv::restore()`, then installs the org.db packages
   - commits ("Renv initialised by pipeline")
   - writes `extdata/R.bib`

   The first run downloads a lot. Run it in the background or in a SLURM job.
3. Confirm with `check-env.sh --dir ANALYSIS_DIR --deep`. It runs R and
   quarto inside the container and prints versions of DESeq2, IHW, emmeans,
   ashr, clusterProfiler and ReactomePA. Anything `MISSING` means the restore failed: read
   `logs/renv.log`.

## Running anything else in the container

`PLUGIN/shared/scripts/run-in-container.sh --dir ANALYSIS_DIR -- <command>`
uses the same bind, env and `--containall --cleanenv` options as `shared.mk`.
Read-only R helpers go through `PLUGIN/shared/scripts/run-r-helper.sh`.
