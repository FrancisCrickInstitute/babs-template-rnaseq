# Files

This is the list of files that should be added to the `babs/docs` directory of the project repository during the experimental design and data arrival phases of the project workflow. Please use **the same files names** as shown here - you can see examples in the [example_docs](example_docs) directory.
* **`proposal.docx`** - The [project proposal](https://bioinformatics.thecrick.org/babs/working-with-us/completing-a-proposal-document/) document.
* **`experiment_table.csv`** - The [experiment table](https://bioinformatics.thecrick.org/babs/working-with-us/experiment-table-preparation/) CVS file containing sample level experimental details
  * :loudspeaker: The first column of this file must be called **ID** and contains the ASF sample LIMS ids.
  * :loudspeaker: This file must be in CSV format

* **`*.spec`** - Comparison [definition file](https://bioinformatics.thecrick.org/babs/working-in-babs/analysis/desdemona/#comparisons) for [DESDemonA](https://bioinformatics.thecrick.org/babs/working-in-babs/analysis/desdemona/)
* **`*.config`** Config file containing analysis data dependency
definitions. `strandedness` will be set to `auto` if omitted, e.g.
```
genome_fasta=/path/to/fasta.fa
gtf=/path/to/genome.gtf
org.db=org.Hs.eg.db
nfcore= -profile crick -resume -r 3.10.1
```
* **`samplesheet.csv`** - List of fastq file locations. Will be provided by the LIMS system.
