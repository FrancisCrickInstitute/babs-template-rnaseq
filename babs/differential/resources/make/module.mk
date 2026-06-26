################################################################
## Settings specific for this phase of the analysis
################################################################
## Most things will already have been set in shared.mk -
## if you want to over-ride them, it is best to do so here
################################################################


################################################################
## Directories
################################################################


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

datasets_dep=$(patsubst $(docs_dir)/%.config,%,$(or $(wildcard $(docs_dir)/$(ANALYSIS_)*.config),$(wildcard $(docs_dir)/*.config)))
datasets=$(datasets_dep) $(filter-out $(datasets_dep),$(patsubst extdata/%.config,%,$(or $(wildcard extdata/$(ANALYSIS_)*.config),$(wildcard extdata/*.config))))

specfiles_dep=$(patsubst $(docs_dir)/%.spec,extdata/%.spec,$(or $(wildcard $(docs_dir)/$(ANALYSIS_)*.spec),$(wildcard $(docs_dir)/*.spec)))
specfiles=$(specfiles_dep) $(filter-out $(specfiles_dep),$(or $(wildcard extdata/$(ANALYSIS_)*.spec), $(wildcard extdata/*.spec)))
specs=$(patsubst extdata/%.spec,%,$(specfiles))

covariate_files_dep = $(patsubst %,$(my_metadata)_%.csv,$(datasets_dep))
covariate_files = $(patsubst %,$(my_metadata)_%.csv,$(datasets))

configs = $(patsubst %,extdata/%.config,$(datasets))
genes_results = $(patsubst %,$(my_counts_dir)/%,$(datasets_dep))

excluded-targets += check-isolated

## These are additional dependencies/rules that make it easier to keep things in sync with the more generic way of generating parametrised qmd pages.
$(staging_dir)/index.qmd : $(log_dir)/check_spec.log

$(log_dir)/check_spec.log : $(specfiles)
	$(R) --vanilla -e "files <- strsplit('$(specfiles)', ' +')[[1]]; \
	  ok <- TRUE; \
	  for (f in files) { \
	    message('Checking ', f); \
	    tryCatch(parse(file = f), error = function(e) { \
	      message('ERROR in ', f, ': ', e$$message); \
	      ok <<- FALSE \
	    }) \
	  }; \
	  if (!ok) quit(status = 1)"  2>$@

renv: orgs=$(strip $(foreach data_source,$(datasets),$($(data_source).org.db)))

check-isolated: confs=$(or $(LABEL),$(patsubst extdata/%.config,%,$(configs)),example)
check-isolated:
	@echo "Checking general setup"
	@. resources/shell/isolated.sh
	@for conf in $(confs); do echo "Checking setup for config '$${conf}'"; . resources/shell/isolated.sh $${conf}; done

clean-geo:  ## Remove the GEO files from scratch
	rm -f shortcuts/geo
	rm -rf $(SCRATCH_DIR)geo


# .PHONY: geo
# geo: geo/md5.txt  ## Gather everything into the 'geo' folder. Specify `VERSION=`, `data_source=` and `spec=` to customise. Remember to `make clean-geo` when the files have been upload.
# geo/md5.txt:
# 	mkdir -p $(SCRATCH_DIR)geo
# 	mkdir -p shortcuts
# 	ln -s $(SCRATCH_DIR)geo shortcuts/geo
# 	ln -fn $(my_counts_dir)/$(data_source)/*.genes.results shortcuts/geo/
# 	ln -fn $(RESULTS_DIR)/$(VERSION)/$(data_source)/$(spec)/*.xlsx shortcuts/geo/
# 	$(SQLITE) extdata/$(samples_db) 'select fastq_1 from fastqs  where config_file="$(data_source)";' | \
# 	while read -r fq ; do cp $${fq} shortcuts/geo/ ; done
# 	$(SQLITE) extdata/$(samples_db) 'select fastq_2 from fastqs  where config_file="$(data_source)";' | \
# 	while read -r fq ; do cp $${fq} shortcuts/geo/ ; done
# 	pushd shortcuts/geo; md5sum *.* > geo.md5.txt; popd

