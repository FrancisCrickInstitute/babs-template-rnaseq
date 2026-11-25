---
tags: [babs-rnaseq, phase8]
max_turns: 400
timeout_seconds: 14400
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

I've already run the BABS downstream analysis on the airway data. It's in ./analysis (data source GRCh38, spec analyse). In model M1 of the analyse spec, could you add comparisons of each cell line against N61311, keeping the existing comparisons, and then update the analysis and the report so they include them?
