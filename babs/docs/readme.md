
# Pipeline files

This is the list of files that need to be present in this `docs`
directory for the rnaseq pipeline to run. 

## Design stage files

These files should be added at the experimental design stage and need
to be present for the project to pass the BABS approval stage.

### proposal.docx

 The [project
 proposal](https://bioinformatics.thecrick.org/babs/working-with-us/completing-a-proposal-document/)
 document. This is generally uploaded when the ticket is created.
 
### experiment_table.csv

The [experiment
table](https://bioinformatics.thecrick.org/babs/working-with-us/experiment-table-preparation/)
CSV file containing sample level experimental meta data.

> * :loudspeaker: This file must be in CSV format
> * :loudspeaker: Please leave the first column (named ID) blank so
      the ASF sample ids can be added when they are created. 
> * :loudspeaker: The second column (named sample_label) must
      contain unique human readable sample names that are recognisable
      by the scientist.
	  
It is best practice to create a draft of this file using the
information provided in proposal document, prior to the design
meeting. The table can
then be used to frame the experimental design discussion with the
scientist, where required comparisons and potential confounding
covariates can be checked.

This table will be cross referenced against the samples passing QC
when submitted to the ASF to ensure the experimental aims can be
achieved with the samples being sequenced.

### analyse.spec

The model and comparison [definition
file](https://bioinformatics.thecrick.org/babs/working-in-babs/analysis/desdemona/#comparisons)
for the [RNA-seq
pipeline](https://bioinformatics.thecrick.org/babs/working-in-babs/analysis/desdemona/)
which encodes the statistical models and sample comparisons.

There is an example analyse.spec file in the [example_docs](example_docs) directory of
this directory. This file contains example code for common statistical
analyses. Please edit this file as appropriate, changing the covariate
names, models and comparisons as needed and deleting the unwanted
examples. The easiest way to do this si to edit it in GitHub, removing
the 'example_docs' directory from the path at the top of the page and
committing the changes. This will save your changes and move the file
up one level to the `docs` directory.

### genome.config

A config file containing analysis data-dependencies. These
include the following.

```
genome_fasta=/path/to/fasta.fa
gtf=/path/to/genome.gtf
org.db=org.Hs.eg.db
nfcore=-profile crick -resume -r 3.10.1
```

There are human and mouse examples in the [example_docs](example_docs)
directory above. The appropriate file can simply be moved from
`example_docs` to this directory by editing the required file,
changing the path at the top of the page and committing the change.

## Analysis stage files

### samplesheet.csv

This file contains the fastq files and is generated at the point the
pipeline is run.
