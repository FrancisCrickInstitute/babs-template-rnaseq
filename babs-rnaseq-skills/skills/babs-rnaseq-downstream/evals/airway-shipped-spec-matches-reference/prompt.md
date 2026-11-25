---
tags: [babs-rnaseq, phase8]
max_turns: 400
timeout_seconds: 14400
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

I've got an nf-core/rnaseq run in ./nfcore. It's the BABS nfcore folder layout, aligned with star_rsem against GRCh38, and the data source is GRCh38. Can you run the BABS downstream analysis on it with the experiment_table.csv, analyse.spec and GRCh38.config in this folder? Please put the analysis in ./analysis. When it's finished, tell me what the main differential results are and where the report is.

Input files: experiment_table.csv, analyse.spec, GRCh38.config
