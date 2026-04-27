# Testing `spec` and other metadata files

If you have a `*.spec`, `experiment_table.csv` and `*.config` in the
parent (docs) directory, then:

```
make
```

at the command line will generate a `differential` subdirectory in
this directory, with simulated gene counts conforming to the number of
samples in your experiment_table. Moving to that directory and doing
another `make run` in there will set off the differential analysis
part of the pipeline to run using those prerequisites.

# Details

By default, the counts will be generated from the `SRR1039508` GEO
sample, which is part of the 'airways' standard dataset. You can use
another dataset by adding a parameter to the make that was carried out
in the `simulate` directory: `make exemplar=/path/to/sample.genes.results`.

It will take a random 1000 counts from that file, and re-annotate them
with gene IDs that are taken from the gtf file identified in your
`*.config` file. It recycles those values to produce as many
`.genes.results` files as are required, and modifies the instance of
the `00_init.qmd` file in order to add noise to the counts.

Currently it will not add any differential behaviour.
