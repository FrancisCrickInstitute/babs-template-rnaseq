---
tags: [babs-rnaseq, phase8]
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

Could you run the BABS downstream analysis on my airway nf-core output in ./nfcore (BABS nfcore layout, star_rsem, data source GRCh38)? The experiment_table.csv, analyse.spec and GRCh38.config are in this folder. Set the analysis up in ./analysis.

Input files: experiment_table.csv, analyse.spec, GRCh38.config
