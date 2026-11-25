---
type: llm
focus: trace
weight: 1
---

The agent runs check-env.sh, init-workdir.sh, stage-inputs.sh, validate-inputs.sh and restore-renv.sh, then renders 00_init, 01_exploratory, 02_differential and 03_enrichment for GRCh38 and the analyse spec in that order, then runs build-site.sh.
