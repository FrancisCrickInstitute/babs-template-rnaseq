include ../global.mk
include local.mk
-include $(confs_dir)/*.config
-include *.config

.PHONY: build run clean

run: analyses  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`.  Requires 'make build' be done first.


alignments = $(patsubst ${my_counts_dir}/%,%,$(wildcard ${my_counts_dir}/*))
specfiles = $(patsubst %.spec,%,$(wildcard *.spec))
result_objs = $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),data/$(spec)_x_$(alignment).dda))

.PHONY: analyses
analyses: $(result_objs)

.PHONY: submit
tmp_script:=$(shell mktemp -u)
submit:  ## Do 'run' but submit to slurm rather than run locally
	echo "$${slurm}" > $(tmp_script)
	make -n -s analyses >> $(tmp_script)
	sbatch $(tmp_script)
	rm -f $(tmp_script)

define RESULT_RULE
data/$(spec)_x_$(alignment).dda : resdir = $(results)/$(VERSION)/$(alignment)/$(spec)
data/$(spec)_x_$(alignment).dda : 01_analyse.r $(spec).spec data/counts_$(alignment).rda R.bib
	mkdir -p "$$(resdir)" 
	$(R) -e "rmarkdown::render('01_analyse.rmd',\
	 output_file='$(spec)_x_$(alignment)_$(TAG).html',\
	 output_options = list(self_contained=$(contained)),\
	 params=list(res_dir='$$(resdir)',spec_file='$(spec).spec', count_source='$(alignment)'))"  >logs/01_analyse.log 2>&1
	mv -f "$(spec)_x_$(alignment)_$(TAG).html"  "$$(resdir)"
	rm -rf "$$(resdir)/$(spec)_x_$(alignment)_$(TAG)_files"
	mv "$(spec)_x_$(alignment)_$(TAG)_files" "$$(resdir)"
	ln -sfn "$(VERSION)" $(results)/latest
endef

$(foreach spec,$(specfiles), \
   $(foreach alignment,$(alignments), \
     $(eval $(RESULT_RULE)) \
   ) \
)


count_objs = $(patsubst %,data/counts_%.rda,$(alignments))
$(count_objs) : data/counts_%.rda : 00_init.r $(wildcard $(my_counts_dir)/%/*.genes.results)
	mkdir -p data
	$(R) -e "source('00_init.r')" --args count_source="$*" metadata="$(strip $(my_metadata))_$*.csv" file_col="$(metadata_id_column)" counts="$(my_counts_dir)/$*/" org_package="$($*.org.db)" >logs/00_init.log 2>&1 


R.bib: renv.lock
	 $(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")' >logs/bib.log 2>&1


.PHONY: geo
geo: geo/md5.txt  ## Gather everything into the 'geo' folder. Specify `geo_version=`, `geo_alignment=` and `geo_spec=` to customise. Remember to `make clean-geo` when the files have been upload.


geo_version=latest
geo_alignment=$(firstword $(aligments))
geo_spec=$(firstword $(specfiles))
geo/md5.txt:
	mkdir -p $(geo_dir)
	ln -s $(geo_dir) geo
	ln -f $(my_counts_dir)/$(geo_alignment)/*.genes.results geo/
	ln -f $(results)/$(geo_version)/$(geo_alignment)/$(geo_spec)/*.xlsx geo/
	$(SQLITE) samples.db 'select fastq_1 from fastqs  where _babs_config_file="$(geo_alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	$(SQLITE) samples.db 'select fastq_2 from fastqs  where _babs_config_file="$(geo_alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	pushd geo; md5sum *.* > geo.md5.txt; popd


################################################################
#### Bootrap all relevant data from outside
################################################################
nfcore_alignments = $(patsubst $(strip $(nfcore_dir))/%,%,$(wildcard $(strip $(nfcore_dir))/*))
specfiles0 = $(patsubst $(docs_dir)/%,%,$(wildcard $(docs_dir)/*.spec))
samplesheets = $(patsubst %,$(strip $(my_metadata))_%.csv,$(nfcore_alignments))
samples_db = $(patsubst ../nfcore/samples.db,%,$(wildcard ../nfcore/samples.db))
genes_results = $(patsubst %,$(my_counts_dir)/%,$(nfcore_alignments))

build: $(specfiles0) $(samplesheets) $(genes_results) scripts ## Create experimental tables that reflect the samples actually run. Generate R scripts and environment that will analyse the data. Copy the required nfcore count files into the `inst/extdata` area.

$(specfiles0): %: $(docs_dir)/%
	cp $< $@


$(samplesheets) : $(strip $(my_metadata))_%.csv : $(samples_db)
	mkdir -p $(dir $(strip $(my_metadata)))
	$(SQLITE) -header -csv  samples.db 'SELECT metadata.* FROM metadata INNER JOIN (SELECT * FROM fastqs GROUP BY $(samplesheet_id_column)) AS asf on metadata.$(metadata_id_column)=asf.$(samplesheet_id_column) WHERE asf._babs_config_file="$*";' > $@


$(samples_db) : % : ../nfcore/% $(docs_dir)/$(experiment_table).csv
	cp $< $@
	$(SQLITE) $@ -csv "DROP TABLE IF EXISTS metadata;"
	$(SQLITE) $@ -csv ".import $(word 2, $^) metadata"


$(genes_results): $(my_counts_dir)/%: $(strip $(nfcore_dir))/% %.config
	dir=$(if $($*.group-as),$($*.group-as),$*);\
	mkdir -p $(my_counts_dir)/$${dir} ;\
	ln -f $(strip $(nfcore_dir))/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/ ;\


.PHONY: scripts
scripts: $(scripts) ## Generate (or reinstate) the default analysis scripts

align1 = $(firstword $(nfcore_alignments))
spec1 = $(firstword $(specfiles0) $(specfiles))

$(scripts) &: $(align1).config | renv.lock
	git stash -m "DESdemonA stashed your scripts. Use 'git stash pop' to retrieve them" 2>/dev/null -- $(scripts) || true
	$(R) -e "DESdemonA::get_started(files=commandArgs(trailing=TRUE),\
	  nfcore='$(strip $(nfcore_dir))/$(align1)',\
	  metadata='$(strip $(my_metadata))_$(align1).csv',\
	  file_col='$(metadata_id_column)',\
	  name_col=c($(name_column)),\
	  counts='$(my_counts_dir)/$(align1)/',\
	  org_package='$($(align1).org.db)',\
	  count_source='$(align1)',\
	  specfile='$(spec1)',\
	  project='$(babsproject)',\
	  overwrite=TRUE)" --args $(scripts) >logs/get_started.log 2>&1
	git add $(scripts)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1
	git stash list

renv.lock:orgs=$(subst $(space),$(comma),$(foreach align,$(nfcore_alignments),$($(align).org.db))),
renv.lock: .renv.lock | logs
	git stash push -m "DESdemonA stashed your lock file. Use 'git stash pop' to retrieve it" 2>/dev/null -- $@ || true
	cp $< $@
	sed -i 's/^Imports:/Imports:\n    $(orgs)/' DESCRIPTION
	module purge ;\
	export RENV_PATHS_LIBRARY=renv/library ;\
	$(R) -e 'library(renv); renv::restore(); renv::install(strsplit("$(orgs)", ",")[[1]])' >logs/renv.log 2>&1
	git add renv.lock
	git commit -m "Pipeline creates renv environment"  >/dev/null 2>&1 || echo "renv.lock already in git"


logs:
	mkdir $@

configs=$(patsubst $(confs_dir)/%.config,%.config,$(wildcard $(confs_dir)/*.config))
$(configs):%.config: $(ingress_dir)/%.config
	cp $< $@

.PHONY: R-local
R-local: R-$(Rversion) ## Create a local shell script that will run R (optional, but helpful for interactive analyses)
R-$(Rversion):
	echo "#!/bin/bash" > $@
	echo "function R { $(R)" \$$@  " ; }" >> $@
	echo "function Rscript { $(R)script" \$$@  " ; }" >> $@
	echo "[[ "'$$BASH_SOURCE'" == "'$$0'" ]] && R " \$$@ >> $@
	setfacl -m u::rwx $@




clean:
clean-geo:  ## Remove the GEO files from scratch
	rm -rf $(geo_dir)
	rm geo


MAKEFLAGS += --no-builtin-rules
