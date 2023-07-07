secrets global.mk: % : $(wildcard ../%)
	cp ../$* $@ 2>/dev/null || touch $@

include secrets
include global.mk
include local.mk
.PHONY: makefile local.mk 
.PHONY: build clean geo R-local


include project.mk  ## Provides analysis parametrisation
include $(patsubst %,$(staging_dir)/.make-%,$(sections))

alignments = $(patsubst ${my_counts_dir}/%,%,$(wildcard ${my_counts_dir}/*))
samplesheets = $(patsubst %,$(my_metadata)_%.csv,$(alignments))
specfiles = $(patsubst %.spec,%,$(wildcard *.spec))

## Create a makefile per section. It will set up target-specific
## variables to inform subsequent targets of the alignment, spec-file,
## and section for each alignment:spec combo. It will also set up the
## global variables 'section'_(pages|qmds|htmls) which
## enumerate the individual combos.  Because these makefiles are
## 'included' they will automatically get remade as necessary, and if
## changed will cause the whole 'make' process to be repeated.

mk0 = $(patsubst %,$(staging_dir)/.make-%,$(filter 00_%,$(sections)))
mk = $(patsubst %,$(staging_dir)/.make-%,$(filter-out 00_%,$(sections)))
qmd_path=$(staging_dir)/$*_$(ispec)_$(ialign)$$(TAG).qmd
qmd0_path=$(staging_dir)/$*_$(ialign)$$(TAG).qmd

$(mk): $(staging_dir)/.make-% : $(patsubst %,%.spec,$(specfiles)) $(samplesheets) | $(staging_dir)
	$(foreach ispec,$(specfiles),\
	   $(foreach ialign,$(alignments),\
	   echo '$(qmd_path): alignment=$(ialign)' >> $@;\
	   echo '$(qmd_path): spec=$(ispec)' >> $@;\
	   echo '$(qmd_path): script=$*_$(ispec)_$(ialign)$$(TAG)' >> $@;\
	   echo '$(qmd_path): section=$*' >> $@;\
	   echo '$(qmd_path): $(source_dir)/$*.qmd' >> $@;\
	   echo '$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$*_$(ispec)_$(ialign)$$(TAG).html: $(ispec).spec $(my_metadata)_$(ialign).csv $(qmd_path) $(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$($*_parent)$$(TAG).html' >> $@ ;\
	   echo '' >> $@ ;\
	))
	echo '$*_pages=$(foreach ispec,$(specfiles),$(foreach ialign,$(alignments),$*_$(ispec)_$(ialign)))' >> $@
	echo '$*_qmds = $$(patsubst %,$(staging_dir)/%$$(TAG).qmd,$$($*_pages))'>> $@
	echo '$*_htmls = $$(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/%$$(TAG).html,$$($*_pages))'>> $@
	echo '$*_htmls: $$($*_htmls)'>> $@

$(mk0): $(staging_dir)/.make-% : $(samplesheets) | $(staging_dir)
	$(foreach ialign,$(alignments),\
	 echo '$(qmd0_path): alignment=$(ialign)' >> $@;\
	 echo '$(qmd0_path): script=$*_$(ialign)$$(TAG)' >> $@;\
	 echo '$(qmd0_path): section=$*' >> $@;\
	 echo '$(qmd0_path): $(source_dir)/$*.qmd' >> $@;\
	 echo '$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$*_$(ialign)$$(TAG).html: $(my_metadata)_$(ialign).csv $(qmd0_path)' >> $@ ;\
	 echo '' >> $@ ;\
	)
	echo '$*_pages=$(foreach ialign,$(alignments),$*_$(ialign))' >> $@
	echo '$*_qmds = $$(patsubst %,$(staging_dir)/%$$(TAG).qmd,$$($*_pages))'>> $@
	echo '$*_htmls = $$(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/%$$(TAG).html,$$($*_pages))'>> $@
	echo '$*_htmls: $$($*_htmls)'>> $@

include $(patsubst %,%.config,$(alignments))
qmds=$(strip $(foreach section,$(sections),$($(section)_qmds)))

html_reports=$(strip $(foreach section,$(sections),$($(section)_htmls)))

ifeq ($(SUBMIT),false)
    ifeq ($(CONTAINERED),false)
##     Being executed directly - no submission or containerisation
.PHONY: run render pages scripts

run: render  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`.  Requires 'make build' be done first.

## Render the qmds to html in one quarto call
render: $(qmds)  $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(samplesheets)| $(log_dir) data $(RESULTS_DIR)/$(VERSION) R.bib## Render the whole directory of generated qmds
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)' --output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR) $(call log,render)
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest


## Alternative is to render pages individually
## Possibly parallelisable, but seems to have a race condition
pages: $(html_reports) ## Generate the renders individually
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)/index.qmd' --output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR)
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest

## Render an individual page
$(html_reports) : $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%$(TAG).html : $(staging_dir)/%$(TAG).qmd $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(samplesheets)| $(log_dir) $(RESULTS_DIR)/$(VERSION) $(staging_dir)/$(RESULTS_DIR)/$(VERSION) R.bib
	$(QUARTO) render '$<' \
	  --output-dir $(RESULTS_DIR)/$(VERSION)/ \
	  --execute-dir $(CURDIR) $(call log,html-$*)

html-%: $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%$(TAG).html ## Create a single html file to be placed in the staging directory, '%' is a simplified filename e.g. `make html-01_exploratory_per-plan_GRCh38`.
	echo "$(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%$(TAG).html"

scripts: $(qmds) ## Generate all the parametrised scripts, into the staging directory. But don't render

$(qmds) : $(staging_dir)/%$(TAG).qmd : $(staging_dir)/.params.yml $(source_dir)/params.yml
	$(QUARTO) run $(source_dir)/typescript/merge_yml.ts\
	 --script=$(source_dir)/$(section).qmd\
	 --alignment=$(alignment)\
	 --spec=$(spec)\
	 --fixed=$(source_dir)/params.yml\
	 --generated=$(staging_dir)/.params.yml > $@
	sed -i -e 's#load_params("$(source_dir)/$(section)", extra=TRUE)#load_params("$(staging_dir)/$*$(TAG)")#' $@

${staging_dir}/_quarto.yml: $(source_dir)/_quarto.yml $(qmds)
	$(QUARTO) run $(source_dir)/typescript/sidebar.ts\
	 --sections="$(subst $(space),$(comma),$(sections))"\
	 --alignments="$(subst $(space),$(comma),$(alignments))"\
	 --specfiles="$(subst $(space),$(comma),$(specfiles))"\
	 --template=$< \
	 --tag=$(TAG)\
	 --staging=$(staging_dir)\
	 --repo="$(repo)" > $@

$(source_dir)/params.yml:
	echo "" > $@

$(staging_dir)/.params.yml:  project.mk
	echo '{$(foreach p,$(param_names),$p: "${$p}"$(comma))}' > $@


${staging_dir}/index.qmd : $(source_dir)/index.qmd $(qmds)
	sed  's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $< > $@

R.bib: orgs=$(foreach align,$(alignments),$($(align).org.db))
R.bib: renv.lock $(patsubst %,%.config,$(alignments)) | $(log_dir)
	for o in $(orgs); do grep -F -q $$o resources/_dependencies.R || echo "library($$o)" >> resources/_dependencies.R; done
	$(R) -e 'library(renv); restore(); hydrate()' $(call log,bib)
	$(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")' $(call log,bib,-a)
	$(call git-ignore,/$@)

renv.lock: | rocker.Renviron  $(log_dir)
	[ ! -f $@ ] || $(GIT_OK) stash push -m "Pipeline stashed. Use 'git stash pop' to retrieve it" -- $@ $(call log,renv)
	$(R) -e 'library(renv); options(repos = BiocManager::repositories()); init(bioconductor=TRUE);' $(call log,renv,-a)
	$(GIT_OK) add renv.lock $(template_scripts) $(call log,renv,-a)
	$(GIT_OK) rev-parse "v0.0.1" >/dev/null 2>&1 || $(GIT) tag v0.0.1 $(call log,renv,-a)
	$(GIT_OK) commit -m 'Initialised by pipeline\n\n' $(call log,renv,-a)

    else
##   being executed by container without slurm, so put what 'make' would normally execute in a temporary
##   shell script, and get container to call that script (so it naturally inherits all the command line
##   arguments etc)
run render pages $(html_reports) scripts $(qmds) ${staging_dir}/_quarto.yml ${staging_dir}/index.qmd  R.bib renv.lock: $(CONTAINER_IMAGE)
	make -n -s $@ SUBMIT=false EXECUTOR=make > ${TMPSCRIPT}_bash 
	$(CONTAINER) $(CONTAINER_FLAGS) $(CONTAINER_IMAGE) bash "${TMPSCRIPT}_bash" && r=$$? || echo "Failed - tidying up temporary bash script"
	rm -f ${TMPSCRIPT}_bash
	exit $$r
    endif
else
## being submitted. So generate a slurm script with the usual slurm
## header, to call the script generated by make. Add a container
## prefix as required.
#make-args=$(shell echo "$(MAKEFLAGS)" | sed -rn 's/^.* -- (.*)/\1/p') TAG=$(TAG) VERSION=$(VERSION)

    ifeq ($(CONTAINERED),true)
slurm-container-prefix=$(CONTAINER) $(CONTAINER_FLAGS) $(CONTAINER_IMAGE) 
    else
slurm-container-prefix=
    endif
#JFLAG= -j $(SLURM--cpus-per-task)# Haven't got parallel make working with quarto. race condition?
run render pages $(html_reports) scripts $(qmds) ${staging_dir}/_quarto.yml ${staging_dir}/index.qmd R.bib renv.lock: $(CONTAINER_IMAGE)
	echo "$$slurm" > ${TMPSCRIPT}_slurm
	make -n -s $@ SUBMIT=false EXECUTOR=make > ${TMPSCRIPT}_slurm.sh
	echo "$(slurm-container-prefix) ${TMPSCRIPT}_slurm.sh" >> ${TMPSCRIPT}_slurm
	echo 'r=$$?' >>  ${TMPSCRIPT}_slurm
	echo '$(notification)' >> ${TMPSCRIPT}_slurm
	$(make_rwx) ${TMPSCRIPT}_slurm
	$(make_rwx) ${TMPSCRIPT}_slurm.sh
	sbatch ${TMPSCRIPT}_slurm 

endif


## Back outside the executor/submission 

geo: geo/md5.txt  ## Gather everything into the 'geo' folder. Specify `geo_version=`, `geo_alignment=` and `geo_spec=` to customise. Remember to `make clean-geo` when the files have been upload.
geo/md5.txt:
	mkdir -p $(SCRATCH_DIR)geo
	[ -z "$(SCRATCH_DIR)" ] || ln -s $(SCRATCH_DIR)geo geo
	ln -fn $(my_counts_dir)/$(alignment)/*.genes.results geo/
	ln -fn $(results)/$(version)/$(alignment)/$(spec)/*.xlsx geo/
	$(SQLITE) $(samples_db) 'select fastq_1 from fastqs  where config_file="$(alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	$(SQLITE) $(samples_db) 'select fastq_2 from fastqs  where config_file="$(alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	pushd geo; md5sum *.* > geo.md5.txt; popd

location=outputs
shortcut=$(empty)
ifdef redirect_$(location)
shortcut=shortcuts/
endif
pubdir = $(shortcut)$(publish_$(location))
ifeq ($(pubdir),)
pubdir = published
endif
publish:  ## Copy results to final location. Either 'outputs' folder (default), intranet (`make publish location=intranet`) or internet
ifdef redirect_$(location)
	mkdir -p $(redirect_$(location))
ifdef url_$(location)
	mkdir -p $(shortcut)
	echo "[InternetShortcut]" > $(shortcut)$(location).url
	echo "URL=$(url_$(location))/latest" >> $(shortcut)$(location).url
endif
	ln -sfn $(redirect_$(location)) $(pubdir)
endif
	mkdir -p $(pubdir)/$(VERSION)
	cp --no-preserve=mode -r $(RESULTS_DIR)/$(VERSION)/. $(pubdir)/$(VERSION)
	ln -sfn $(VERSION) $(pubdir)/latest
	[ ! -f .htaccess ] || [ "$(location)" == "outputs" ] || cp --no-preserve=mode -r .htaccess $(pubdir)/
	[ -f .htaccess ] || [ "$(location)" == "outputs" ] || echo "Warning: no .htaccess files, so unauthorised people may be able to view these results"
	ln -sfn $$(realpath $(pubdir)/$(VERSION)) $(RESULTS_DIR)/published_$(location)

## TODO - won't work when we do a group-as of alignments

################################################################
#### Bootrap all relevant data from outside
################################################################
alignments_ext = $(patsubst $(nfcore_dir)/%,%,$(wildcard $(nfcore_dir)/*))
specfiles_ext =  $(patsubst $(docs_dir)/%,%,$(wildcard $(docs_dir)/*.spec))

samplesheets_ext = $(patsubst %,$(my_metadata)_%.csv,$(alignments_ext))
genes_results = $(patsubst %,$(my_counts_dir)/%,$(alignments_ext))
multiqc_results = $(patsubst %,$(RESULTS_DIR)/multiqc-%,$(alignments_ext))
samples_db = samples.db

build: $(samplesheets_ext) $(specfiles_ext) $(genes_results)  $(multiqc_results) | $(source_dir) $(staging_dir) ##  Copy the required nfcore count files into the `extdata` area, and get the spec files.

ifneq (,$(filter build,$(MAKECMDGOALS)))
## Only do build-like things if build actually called.
## Otherwise, metadata samplesheets will trigger an
## attempt to rebuild the external samples.db etc.

$(samplesheets_ext) : $(my_metadata)_%.csv : $(samples_db) 
	$(SQLITE) -header -csv  $(samples_db) 'SELECT metadata.* FROM metadata INNER JOIN (SELECT * FROM "fastq_$*" GROUP BY $(samplesheet_id_column)) AS nfcore on metadata.$(metadata_id_column)=nfcore.$(samplesheet_id_column);' > $@

$(samples_db): $(my_metadata).csv $(nfcore_dir)/../$(samples_db)
	cp $(nfcore_dir)/../$(samples_db) $@ || echo "No samples database in nfcore directory"
	$(SQLITE) $@ -csv "DROP TABLE IF EXISTS metadata;"  ".import $< metadata"

$(my_metadata).csv: $(docs_dir)/$(experiment_table).csv | $(dir $(my_metadata))
	cp $< $@

$(specfiles_ext): % : $(docs_dir)/%
	cp $< $@

$(patsubst %,%.config,$(alignments_ext)): %.config: ../nfcore/%.config
	cp $< $@

-include $(patsubst %,%.config,$(filter-out $(alignments),$(alignments_ext)))

$(genes_results): $(my_counts_dir)/%: $(nfcore_dir)/% %.config
	dir=$(if $($*.group-as),$($*.group-as),$*);\
	mkdir -p $(my_counts_dir)/$${dir} ;\
	ln -fn $(nfcore_dir)/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/

$(multiqc_results) : $(RESULTS_DIR)/multiqc-% : $(nfcore_dir)/% | $(RESULTS_DIR)
	ln -sfn ../$(nfcore_dir)/$*/multiqc/star_rsem $@
endif

################################################################
#### Helper goals
################################################################


$(log_dir) $(source_dir) $(staging_dir) $(dir $(my_metadata)) data $(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR) $(staging_dir)/$(RESULTS_DIR)/$(VERSION):
	mkdir -p $@

rocker.Renviron: 
	echo "RENV_PATHS_PREFIX=$(RENV_PATHS_PREFIX)" > $@
	echo "RENV_PATHS_ROOT=$(RENV_PATHS_ROOT)" >> $@
	echo "RENV_PATHS_LIBRARY=renv/library" >> $@
#	echo "RENV_CONFIG_PAK_ENABLED=TRUE" >> $@

R-local: R-$(RVERSION) ## Create a local shell script that will run R (optional, but helpful for interactive analyses)
R-$(RVERSION): $(CONTAINER_IMAGE)
	echo "#!/bin/bash" > $@
	echo 'function R { $(CONTAINER) $(CONTAINER_FLAGS_INTERACTIVE) $(CONTAINER_IMAGE) R' \$$@  " ; }" >> $@
	echo 'function Rscript { $(CONTAINER) $(CONTAINER_FLAGS_INTERACTIVE) $(CONTAINER_IMAGE) Rscript' \$$@  " ; }" >> $@
	echo 'function conshell { $(CONTAINER_SHELL) ; }' >> $@
	echo "[[ "'$$BASH_SOURCE'" == "'$$0'" ]] && R " \$$@ >> $@
	setfacl -m u::rwx $@
	$(call git-ignore,$@)

.PHONY: rstudio
rstudio: ## Open this environment in RStudio
	. $(source_dir)/shell/rstudio-rocker.sh

clean:
clean-geo:  ## Remove the GEO files from scratch
	rm -rf $(geo_dir)
	rm geo




MAKEFLAGS += --no-builtin-rules
