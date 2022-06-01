include ../config/global.mk
include local.mk
-include ../ingress/*.config
-include *.config

.PHONY: build run copy publish clean

run: analyses  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`


alignments := $(patsubst ${my_counts_dir}/%,%,$(wildcard ${my_counts_dir}/*))
specfiles := $(patsubst %.spec,%,$(wildcard *.spec))
result_objs := $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),data/$(spec)_x_$(alignment).dda))
align1 := $(firstword $(alignments))
spec1 := $(firstword $(specfiles))

.PHONY: analyses
analyses: $(result_objs)

define RESULT_RULE
data/$(spec)_x_$(alignment).dda : resdir = results/$(VERSION)/$(alignment)
data/$(spec)_x_$(alignment).dda : 01_analyse.r $(spec).spec data/counts_$(alignment).rda R.bib
	mkdir -p "$$(resdir)" 
	$(R) -e "rmarkdown::render('01_analyse.r',\
	 output_file='$(spec)_x_$(alignment)_$(TAG).html',\
	 output_options = list(self_contained=$(contained)),\
	 params=list(res_dir='$$(resdir)',spec_file='$(spec).spec', count_source='$(alignment)'))"
	mv -f "$(spec)_x_$(alignment)_$(TAG).html"  "$$(resdir)"
	rm -rf "$$(resdir)/$(spec)_x_$(alignment)_$(TAG)_files"
	mv "$(spec)_x_$(alignment)_$(TAG)_files" "$$(resdir)"
	ln -sfn "$(VERSION)" results/latest
endef

$(foreach spec,$(specfiles), \
   $(foreach alignment,$(alignments), \
     $(eval $(RESULT_RULE)) \
   ) \
)


count_objs := $(patsubst %,data/counts_%.rda,$(alignments)) %.config
$(count_objs) : data/counts_%.rda : 00_init.r $(wildcard $(my_counts_dir)/%/*.genes.results)
	mkdir -p data
	$(R) -e "source('00_init.r')" --args count_source="$*" metadata="$(my_metadata)_$*.csv" file_col="$(metadata_id_column)" counts="$(my_counts_dir)/$*/" org_package="$($*.org.db)"


R.bib: renv.lock
	 $(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'



################################################################
#### Bootrap all relevant data from outside
################################################################

build: specfiles samplesheets genes_results scripts ## Create experimental tables that reflect the samples actually run. Generate R scripts and environment that will analyse the data. Copy the required nfcore count files into the `inst/extdata` area.
	make -n -s run > run.sh

specfiles := $(patsubst ../docs/%,%,$(wildcard ../docs/*.spec))
specfiles: $(specfiles)
$(specfiles): %: ../docs/%
	cp $< $@


nf_alignments := $(patsubst $(nfcore_dir)/%,%,$(wildcard $(nfcore_dir)/*))
samplesheets:= $(patsubst %,$(my_metadata)_%.csv,$(nf_alignments))
samplesheets: $(samplesheets)
$(samplesheets) : $(my_metadata)_%.csv : samples.db
	mkdir -p $(dir $(my_metadata))
	$(SQLITE) -header -csv  samples.db 'SELECT metadata.* FROM metadata INNER JOIN (SELECT * FROM fastqs GROUP BY $(samplesheet_id_column)) AS asf on metadata.$(metadata_id_column)=asf.$(samplesheet_id_column) WHERE asf._babs_config_file="$*";' > $@

samples.db: ../nfcore/samples.db ../docs/$(BABS_TABLE).csv
	cp $< $@
	$(SQLITE) $@ -csv "DROP TABLE IF EXISTS metadata;"
	$(SQLITE) $@ -csv ".import $(word 2, $^) metadata"



genes_results := $(patsubst %,$(my_counts_dir)/%,$(nf_alignments))
genes_results : $(genes_results)
$(genes_results): $(my_counts_dir)/%: $(nfcore_dir)/% %.config
	dir=$(if $($*.group-as),$($*.group-as),$*);\
	mkdir -p $(my_counts_dir)/$${dir} ;\
	ln -f $(nfcore_dir)/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/ 


.PHONY: scripts
scripts = 00_init.r 01_analyse.r
scripts: $(scripts) ## Generate (or reinstate) the default analysis scripts

$(scripts) &: $(align1).config | renv.lock
	for file in $(scripts) ; do \
	  [ -f $${file} ] && git add "$${file}" || true;\
	done ;\
	if [ ! -z "$$(git diff --staged)" ] ; then \
	  git status ;\
	  echo "Please commit changes before re-running 'prepare_scripts'" ; exit 1 ;\
	fi ;\
	$(R) -e 'DESdemonA::get_started(files=commandArgs(trailing=TRUE),nfcore="", metadata="$(my_metadata)_$(align1).csv", file_col="$(metadata_id_column)",name_col=c($(NAME_COLUMN)), counts="$(my_counts_dir)/$(align1)/", org_package="$($(align1).org.db)", count_source="$(align1)", specfile="$(spec1)",  project="$(babsproject)", overwrite=TRUE)' --args $(scripts)
	git add $(scripts)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1

renv.lock:orgs=$(subst $(space),$(comma),$(foreach align,$(nf_alignments),$($(align).org.db))),
renv.lock:
	sed -i 's/^Imports:/Imports:\n    $(orgs)/' DESCRIPTION
	module purge ;\
	export RENV_PATHS_LIBRARY=renv/library ;\
	$(R) -e 'library(renv); renv::install("BiocManager"); options(repos=BiocManager::repositories()); renv::init(bioconductor=TRUE, bare=TRUE); renv::install(); renv::snapshot(type="all")'
	git add renv.lock
	git commit -m "Pipeline creates renv environment"


configs=$(patsubst ../ingress/%.config,%.config,$(wildcard ../ingress/*.config))

$(configs):%.config: ../ingress/%.config
	cp $< $@

R-local:
	echo "#!/bin/bash" > $@
	echo "function R {" >> $@
	echo $(R) " $$@">> $@
	echo "}" >> $@
	echo "function Rscript {" >> $@
	echo "$(R)script  $$@" >> $@
	echo "}" >> $@
	echo "[[ "'$$BASH_SOURCE'" == "$$0" ]] && R "$$@"" >> $@




copy:

clean:

publish:
