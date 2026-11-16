# Experiment table and config rules

## experiment_table.csv

These are the rules the `docs` stage enforces, plus what the analysis assumes.
`validate-inputs.sh` checks the first three.

- It must be CSV. Windows line endings are stripped during staging.
- **The first column must be named `ID`.** Its values must match the nf-core
  sample names (the `sample` column of the nf-core samplesheet, which is also the
  basename of `star_rsem/<sample>.genes.results`). Rows whose ID is not in the
  nf-core run are dropped by the inner join, and so are nf-core samples absent
  from the table. `stage-inputs.sh` lists both.
- The second column should be `sample_label`, with unique, human-readable names.
  If there isn't one, the first column after `ID` with unduplicated values
  becomes the label, otherwise `ID` itself.
- This table is the sole source of truth for covariates. Every variable in a
  spec's designs, comparisons and subsets must be a column here, or be created by the
  spec's `transform=mutate(...)`.
- Columns that contain only numbers are treated as numeric. Used in a design,
  that means a strict linear trend. A numeric `Replicate` column is especially
  risky. Flag numeric design covariates to the user.
- A completely blank `ID` column makes `00_init` simulate counts (the
  isolated-template behaviour). With real nf-core data that is a mistake.

## <genome>.config

Make-style `key=value` lines. `#` starts a comment. Only these keys
matter downstream:

| key | use |
|---|---|
| `org.db` | Bioconductor annotation package (`org.Hs.eg.db`, `org.Mm.eg.db`, …). Without it there is no symbol/entrez annotation and no enrichment. |
| `aligner` | `star_rsem` (default, tested) or `star_salmon` (understood by 00_init, untested). |
| `spec` / `nospec` | Restrict which specs run with this data source (space- or comma-separated spec basenames). |
| `name`, `categories` | Display name and listing category in the report. |
| `keytype` | Key type of the count row names for annotation (default `ENSEMBL`). |

`genome_fasta`, `gtf` and `nfcore` are only used by the alignment stage. The
config file name (e.g. `GRCh38.config` → `GRCh38`) becomes the data-source
label in every output name.
