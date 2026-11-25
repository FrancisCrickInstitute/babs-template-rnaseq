---
tags: [babs-rnaseq, phase8]
max_turns: 500
timeout_seconds: 18000
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

This is the airway data: the nf-core run is in ./nfcore (BABS nfcore layout, star_rsem, data source GRCh38). I have two spec files, analyse.spec and treatment.spec, both in this folder along with experiment_table.csv and GRCh38.config. Please run the BABS downstream analysis for both specs into ./analysis and give me a summary of the differential results for each spec.

Input files: experiment_table.csv, analyse.spec, treatment.spec, GRCh38.config
