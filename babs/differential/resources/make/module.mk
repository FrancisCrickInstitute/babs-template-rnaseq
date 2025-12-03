################################################################
## Settings specific for this phase of the analysis
################################################################
## Most things will already have been set in shared/secret.mk -
## if you want to over-ride them, it is best to do so here
################################################################


################################################################
## Directories
################################################################

## Location of qmds and multi-yaml files
source_dir=resources
## Place where qmds will be generated
staging_dir=staging
## place within the staging directory where renders will be placed
RESULTS_DIR = results
staged_results=$(staging_dir)/$(RESULTS_DIR)/$(VERSION)
## Where to store key information transferred from nfcore run
my_counts_dir=extdata/genes.results
my_metadata=extdata/metadata


samplesheets = $(patsubst %,$(my_metadata)_%.csv,$(alignments))
configs = $(patsubst %,extdata/%.config,$(alignments))
genes_results = $(patsubst %,$(my_counts_dir)/%,$(alignments))
file.spec = $(patsubst %,extdata/%.spec,$(specfiles))

################################################################
## GEO settings
################################################################
## For submission to GEO, we need to know the version, spec and
## aligment settings that are to be submitted.
################################################################
geo: version=latest
geo: alignment=$(firstword $(alignments))
geo: spec=$(firstword $(specfiles))
