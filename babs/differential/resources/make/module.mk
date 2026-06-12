################################################################
## Settings specific for this phase of the analysis
################################################################
## Most things will already have been set in shared.mk -
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

# The following can be set to singularity|docker|shell
# and determines the environment in which quarto/R processes
# will be run in.
EXECUTOR = singularity

SQLITE_MODULE=SQLite/3.42.0-GCCcore-12.3.0
SQLITE = $(call ml,$(SQLITE_MODULE)); sqlite3

datasets_dep=$(patsubst $(docs_dir)/%.config,%,$(wildcard $(docs_dir)/*.config))
datasets=$(datasets_dep) $(filter-out $(datasets_dep),$(patsubst extdata/%.config,%,$(wildcard extdata/*.config)))

specfiles_dep=$(patsubst $(docs_dir)/%.spec,extdata/%.spec,$(wildcard $(docs_dir)/*.spec))
specfiles=$(specfiles_dep) $(filter-out $(specfiles_dep),$(wildcard extdata/*.spec))
specs=$(patsubst extdata/%.spec,%,$(specfiles))

covariate_files_dep = $(patsubst %,$(my_metadata)_%.csv,$(datasets_dep))
covariate_files = $(patsubst %,$(my_metadata)_%.csv,$(datasets))

configs = $(patsubst %,extdata/%.config,$(datasets))
genes_results = $(patsubst %,$(my_counts_dir)/%,$(datasets_dep))

excluded-targets += check-isolated
