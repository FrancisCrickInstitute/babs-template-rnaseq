.PHONY: makefile project.mk system.mk ../system.mk
.PHONY: build clean geo R-local

-include secrets
include ../system.mk
include system.mk

include project.mk  ## Provides analysis parametrisation
include $(patsubst %,$(staging_dir)/%.mk,$(sections))

alignments = $(patsubst ${my_counts_dir}/%,%,$(wildcard ${my_counts_dir}/*))
samplesheets = $(patsubst %,$(my_metadata)_%.csv,$(alignments))
specfiles = $(patsubst %.spec,%,$(wildcard *.spec))

## Create a makefile per section. It will set up target-specific
## variables to inform subsequent targets of the alignment, spec-file,
## and section for each alignment:spec combo. It will also set up the
## global variables 'section'_(pages|yamls|qmds|htmls|params) which
## enumerate the individual combos.  Because these makefiles are
## 'included' they will automatically get remade as necessary, and if
## changed will cause the whole 'make' process to be repeated.

mk0 = $(patsubst %,$(staging_dir)/%.mk,$(filter 00_%,$(sections)))
mk = $(patsubst %,$(staging_dir)/%.mk,$(filter-out 00_%,$(sections)))
qmd_path=$(staging_dir)/$*_$(ispec)_$(ialign)$$(TAG).qmd
qmd0_path=$(staging_dir)/$*_$(ialign)$$(TAG).qmd

$(mk): $(staging_dir)/%.mk : $(patsubst %,%.spec,$(specfiles)) $(samplesheets) | $(staging_dir)
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
	echo '$*_yamls = $$(patsubst %,$(staging_dir)/%.yml,$${$*_pages})'>> $@
	echo '$*_qmds = $$(patsubst %,$(staging_dir)/%$$(TAG).qmd,$$($*_pages))'>> $@
	echo '$*_params = $$(foreach p,$$($*_param_names),$$(patsubst %,-P %:$$($$(p)),$$(p)))'>> $@
	echo '$*_htmls = $$(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/%$$(TAG).html,$$($*_pages))'>> $@
	echo '$*_htmls: $$($*_htmls)'>> $@

$(mk0): $(staging_dir)/%.mk : $(samplesheets) | $(staging_dir)
	$(foreach ialign,$(alignments),\
	 echo '$(qmd0_path): alignment=$(ialign)' >> $@;\
	 echo '$(qmd0_path): script=$*_$(ialign)$$(TAG)' >> $@;\
	 echo '$(qmd0_path): section=$*' >> $@;\
	 echo '$(qmd0_path): $(source_dir)/$*.qmd' >> $@;\
	 echo '$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$*_$(ialign)$$(TAG).html: $(my_metadata)_$(ialign).csv $(qmd0_path)' >> $@ ;\
	 echo '' >> $@ ;\
	)
	echo '$*_pages=$(foreach ialign,$(alignments),$*_$(ialign))' >> $@
	echo '$*_yamls = $$(patsubst %,$(staging_dir)/%.yml,$${$*_pages})'>> $@
	echo '$*_qmds = $$(patsubst %,$(staging_dir)/%$$(TAG).qmd,$$($*_pages))'>> $@
	echo '$*_params = $$(foreach p,$$($*_param_names),$$(patsubst %,-P %:$$($$(p)),$$(p)))'>> $@
	echo '$*_htmls = $$(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/%$$(TAG).html,$$($*_pages))'>> $@
	echo '$*_htmls: $$($*_htmls)'>> $@

include $(patsubst %,%.config,$(alignments))

ifeq ($(SUBMIT),false)
    ifeq ($(CONTAINERED),false)
##     Being executed directly - no submission or containerisation
.PHONY: run render pages scripts

run: render  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`.  Requires 'make build' be done first.

qmds=$(strip $(foreach section,$(sections),$($(section)_qmds)))

## Render the qmds to html in one quarto call
render: $(qmds)  $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(samplesheets)| $(log_dir) data $(RESULTS_DIR)/$(VERSION) ## Render the whole directory of generated qmds
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)' --output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR) >$(log_dir)/render.log 2>&1
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest


## Alternative is to render pages individually
## Possibly parallelisable, but seems to have a race condition
html_reports=$(strip $(foreach section,$(sections),$($(section)_htmls)))
pages: $(html_reports) ## Generate the renders individually
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)/index.qmd' --output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR)
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest

## Render an individual page
$(html_reports) : $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%$(TAG).html : $(staging_dir)/%$(TAG).qmd $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(samplesheets)| $(log_dir) $(RESULTS_DIR)/$(VERSION) $(staging_dir)/$(RESULTS_DIR)/$(VERSION)
	$(QUARTO) render '$<' \
	  --output-dir $(RESULTS_DIR)/$(VERSION)/ \
	  --execute-dir $(CURDIR) >$(log_dir)/html-$*.log 2>&1


scripts: $(qmds) ## Generate all the parametrised scripts, into the staging directory. But don't render

$(qmds) : $(staging_dir)/%$(TAG).qmd : $(staging_dir)/%.yml
	$(QUARTO) run $(source_dir)/typescript/merge_yml.ts --script=$(filter %.qmd,$^) --yml=$(staging_dir)/$*.yml >> $@
	sed -i -e 's#$(yaml-filename-placeholder) <- .*$$#$(yaml-filename-placeholder) <- "$(staging_dir)/$*.yml"#' $@

${staging_dir}/_quarto.yml: $(source_dir)/_quarto.yml $(qmds)
	$(QUARTO) run $(source_dir)/typescript/sidebar.ts --template=$< --tag=$(TAG) --staging=$(staging_dir) --repo="$(repo)" > $@

${staging_dir}/index.qmd : $(source_dir)/index.qmd
	cp $< $@

all_params=$(foreach p,$(param_names),$(patsubst %,-P %:$($(p)),$(p))) -P qmd_name:$(script)

yaml0 = $(filter $(staging_dir)/00_%.yml,$(foreach s,$(sections),$($(s)_yamls)))
yaml = $(filter-out $(staging_dir)/00_%.yml,$(foreach s,$(sections),$($(s)_yamls)))
sed-p2yml = 's/^ *-P */    /; s/: */: /g; s/ *-P */\n    /g;'

$(yaml):
	echo "- title: $(alignment) $(spec)" >> $@ 
	echo "  description: of $(alignment)-aligned data according to '$(spec)'" >> $@
	echo "  categories: [$(alignment), $(spec)]" >> $@
	echo "  params:" >> $@
	echo "    alignment: $(alignment)" >> $@
	echo "    spec: $(spec)" >> $@
	echo "${all_params}" | sed $(sed-p2yml) >> $@
	echo "$($(section)_params)" | sed $(sed-p2yml) >> $@
	echo "" >> $@

$(yaml0):
	echo "- title: $(alignment)" >> $@ 
	echo "  description: of $(alignment)-aligned data" >> $@
	echo "  categories: [$(alignment)]" >> $@
	echo "  params:" >> $@
	echo "    alignment: $(alignment)" >> $@
	echo "    metadata: $(my_metadata)_${alignment}.csv" >> $@ ;\
	echo "    counts: $(my_counts_dir)/${alignment}/" >> $@ ;\
	echo "    org_package: ${${alignment}.org.db}" >> $@ ;\
	echo "${all_params}" | sed $(sed-p2yml) >> $@
	echo "$($(section)_params)" | sed $(sed-p2yml) >> $@
	echo "" >> $@

R.bib: renv.lock | $(log_dir)
	$(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")' >$(log_dir)/bib.log 2>&1
	$(call git-ignore,/$@)

renv.lock:orgs=$(subst $(space),$(comma),$(foreach align,$(alignments),$($(align).org.db))),
renv.lock: | rocker.Renviron  $(log_dir)
	( $(GIT) stash push -m "DESdemonA stashed. Use 'git stash pop' to retrieve it" -- $@ || echo "Couldn't stash changes" ) >$(log_dir)/renv.log 2>&1
	for o in $(orgs); do grep -F -q $$o DESCRIPTION || sed -i "s/^Imports:/Imports:\n    $$o/" DESCRIPTION; done 
	$(R) -e 'library(renv); init(bioconductor=TRUE); options(repos=BiocManager::repositories()); install(); snapshot(type="all")' >>$(log_dir)/renv.log 2>&1
	$(R) -e "DESdemonA::get_started(c(\
	  $(subst $(space),$(comma),$(patsubst %,'%',$(notdir $(template_scripts)))) ),\
	  dest='$(source_dir)' )" >$(log_dir)/renv.log 2>&1
	( $(GIT) add renv.lock $(template_scripts) || echo "Coudn't add renv.lock/scripts to version control") >>$(log_dir)/renv.log 2>&1
	( $(GIT) rev-parse "v0.0.1" >/dev/null 2>&1 || $(GIT) tag v0.0.1 || echo "Couldn't tag" ) >>$(log_dir)/renv.log 2>&1
	( $(GIT) commit -m 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock`   || echo "Couldn't commit" ) >>$(log_dir)/renv.log 2>&1

    else
##   being executed by container without slurm, so put what 'make' would normally execute in a temporary
##   shell script, and get container to call that script (so it naturally inherits all the command line
##   arguments etc)
%: $(CONTAINER_IMAGE)
	bash_script=$$(mktemp -u $(staging_dir)/bash_script_XXXXX) ;\
	make -n -s $* SUBMIT=false EXECUTOR=make > $${bash_script} ;\
	$(CONTAINER) $(CONTAINER_FLAGS) $(CONTAINER_IMAGE) bash "$${bash_script}" && r=$$? || echo "Failed - tidying up temporary bash script";\
	rm -f $${bash_script}} ;\
	exit $$r
    endif
else
## being submitted. So generate a slurm script with the usual slurm header, followed
## by the make command. $(make-args) will contain the command-line args, as otherwise
## they'll get lost (it's not a recursive make.) Add a container prefix as required.

    ifeq ($(CONTAINERED),true)
slurm-make-prefix=$(CONTAINER) $(CONTAINER_FLAGS) $(CONTAINER_IMAGE)
%: $(CONTAINER_IMAGE)
    else
slurm-make-prefix=""
    endif
#JFLAG= -j $(SLURM--cpus-per-task)# Haven't got parallel make working with quarto. race condition?
%:
	slurm_script=$$(mktemp -u $(staging_dir)/slurm_script_XXXXX) ;\
	echo "$${slurm}" > $${slurm_script} ;\
	echo "$(slurm-make-prefix) make $(JFLAG) $* $(make-args) EXECUTOR=make SUBMIT=false" >> $${slurm_script} ;\
	echo 'r=$$?' >>  $${slurm_script} ;\
	echo '$(notification)' >> $${slurm_script} ;\
	sbatch $${slurm_script} 

endif


## Back outside the executor/submission 

geo: geo/md5.txt  ## Gather everything into the 'geo' folder. Specify `geo_version=`, `geo_alignment=` and `geo_spec=` to customise. Remember to `make clean-geo` when the files have been upload.
geo/md5.txt:
	mkdir -p $(geo_dir)
	ln -s $(geo_dir) geo
	ln -f $(my_counts_dir)/$(alignment)/*.genes.results geo/
	ln -f $(results)/$(version)/$(alignment)/$(spec)/*.xlsx geo/
	$(SQLITE) $(samples_db) 'select fastq_1 from fastqs  where config_file="$(alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	$(SQLITE) $(samples_db) 'select fastq_2 from fastqs  where config_file="$(alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	pushd geo; md5sum *.* > geo.md5.txt; popd

location=outputs
publish:  ## Copy results to final location. Either 'outputs' folder (default), intranet (`make publish location=intranet`) or internet
ifdef redirect_$(location)
	mkdir -p $(redirect_$(location))
	ln -sfn $(redirect_$(location)) $(publish_$(location))
endif
	mkdir -p $(publish_$(location))/$(VERSION)
	cp --no-preserve=mode -r $(RESULTS_DIR)/$(VERSION)/. $(publish_$(location))/$(VERSION)
	ln -sfn $(VERSION) $(publish_$(location))/latest
	cp --no-preserve=mode -r .htaccess $(publish_$(location))/latest/
	ln -sfn $(PWD)/$(publish_$(location))/$(VERSION) $(RESULTS_DIR)/published_$(location)
	cp -Lr --no-preserve=mode $(patsubst %,$(RESULTS_DIR)/multiqc-%,$(alignments)) $(publish_$(location))
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

build: $(samplesheets_ext) $(specfiles_ext) $(genes_results)  $(multiqc_results) | $(source_dir) $(staging_dir) ##  Copy the required nfcore count files into the `inst/extdata` area, and get the spec files.


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
	ln -f $(nfcore_dir)/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/

$(multiqc_results) : $(RESULTS_DIR)/multiqc-% : $(nfcore_dir)/% | $(RESULTS_DIR)
	ln -sfn ../$</multiqc/star_rsem $@

$(log_dir) $(source_dir) $(staging_dir) $(dir $(my_metadata)) data $(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR) $(staging_dir)/$(RESULTS_DIR)/$(VERSION):
	mkdir -p $@

rocker.Renviron: 
	echo "RENV_PATHS_PREFIX=$(RENV_PATHS_PREFIX)" > $@
	echo "RENV_PATHS_ROOT=$(RENV_PATHS_ROOT)" >> $@
	echo "RENV_PATHS_LIBRARY=renv/library" >> $@

R-local: R-$(RVERSION) ## Create a local shell script that will run R (optional, but helpful for interactive analyses)
R-$(RVERSION): $(CONTAINER_IMAGE)
	echo "#!/bin/bash" > $@
	echo 'function R { $(CONTAINER) $(CONTAINER_FLAGS_INTERACTIVE) $(CONTAINER_IMAGE) R' \$$@  " ; }" >> $@
	echo 'function Rscript { $(CONTAINER) $(CONTAINER_FLAGS_INTERACTIVE) $(CONTAINER_IMAGE) Rscript' \$$@  " ; }" >> $@
	echo 'function conshell { $(CONTAINER_SHELL) ; }' >> $@
	echo "[[ "'$$BASH_SOURCE'" == "'$$0'" ]] && R " \$$@ >> $@
	setfacl -m u::rwx $@
	$(call git-ignore,$@)

clean:
clean-geo:  ## Remove the GEO files from scratch
	rm -rf $(geo_dir)
	rm geo


MAKEFLAGS += --no-builtin-rules
