.PHONY: makefile resources/make/module.mk resources/make/shared.mk resources/make/project.mk
.PHONY: clean maintainer-clean geo R-local
.DEFAULT_GOAL=help

include resources/make/shared.mk
include resources/make/module.mk   ## Anything we need to over-ride from shared
include resources/make/project.mk  ## Describe analysis structure of the qmds etc


# Dynamically created makefiles might trigger computationally
# intensive operations, so don't do them for targets specified in
# `excluded-targets`
ifneq (,$(filter-out $(excluded-targets),$(MAKECMDGOALS)))
include $(patsubst %,$(staging_dir)/.make-%,$(sections))
endif


## Create a makefile per section. It will set up target-specific
## variables to inform subsequent targets of the data_source, spec-file,
## and section for each data_source:spec combo. It will also set up the
## global variables 'section'_(pages|qmds|htmls) which
## enumerate the individual combos.  Because these makefiles are
## 'included' they will automatically get remade as necessary, and if
## changed will cause the whole 'make' process to be repeated.

mk0 = $(patsubst %,$(staging_dir)/.make-%,$(filter 00_%,$(sections)))
mk = $(patsubst %,$(staging_dir)/.make-%,$(filter-out 00_%,$(sections)))
qmd_path=$(staging_dir)/$*_$(ispec)_$(idata).qmd
qmd0_path=$(staging_dir)/$*_$(idata).qmd

spec_of_data_source=$(filter-out $($(1).nospec),$(if $($(1).spec),$(filter $($(1).spec),$(specs)),$(specs)))
$(mk): $(staging_dir)/.make-% : $(specfiles) $(covariate_files) | $(staging_dir)
	printf "%s\n" $(foreach ispec,$(specs),\
	   $(foreach idata,$(datasets),\
	   '$(qmd_path): data_source=$(idata)'\
	   '$(qmd_path): spec=$(ispec)'\
	   '$(qmd_path): script=$*_$(ispec)_$(idata)'\
	   '$(qmd_path): section=$*'\
	   '$(qmd_path): cat1=$(or $(shell sed -n "s/^#$(squote)[[:space:]]*@categories[[:space:]]\+\(.*\)/\1/p" extdata/$(ispec).spec | head -n1),$(ispec))'\
	   '$(qmd_path): cat2=$(or $($(idata).categories), $(idata))'\
	   '$(qmd_path): specname=$(or $(shell sed -n "s/^#$(squote)[[:space:]]*@specname[[:space:]]\+\(.*\)/\1/p" extdata/$(ispec).spec | head -n1),$(ispec))'\
	   '$(qmd_path): $(source_dir)/$*.qmd'\
	   '$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$*_$(ispec)_$(idata).html: $(my_counts_dir)/$(idata) $(ispec).spec $(my_metadata)_$(idata).csv $(qmd_path) $(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$($*_parent).html'\
	)) > $@
	echo '$*_pages=$(foreach idata,$(datasets),$(foreach ispec,$(call spec_of_data_source,$(idata)),$*_$(ispec)_$(idata)))' >> $@
	echo '$*_qmds = $$(patsubst %,$(staging_dir)/%.qmd,$$($*_pages))'>> $@
	echo '$*_htmls = $$(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/%.html,$$($*_pages))'>> $@
	echo '$*_htmls: $$($*_htmls)'>> $@


# The trick to get e.g. nfcore run outside any differential container
# is for a generated makefile to take a dependency on the
# yet-to-be-run nfcore results.  Here, we ensure that the
# genes_results are made before the makefile that describes the dependencies
# of the 00_init.qmd's:
$(mk0): $(staging_dir)/.make-% : $(covariate_files) $(genes_results) | $(staging_dir)
	printf "%s\n" $(foreach idata,$(datasets),\
	 '$(qmd0_path): data_source=$(idata)'\
	 '$(qmd0_path): script=$*_$(idata)'\
	 '$(qmd0_path): section=$*'\
	 '$(qmd0_path): cat1=$($(idata).categories)'\
	 '$(qmd_path): specname=$(or $(shell sed -n "s/^#$(squote)[[:space:]]*@specname[[:space:]]\+\(.*\)/\1/p" extdata/$(ispec).spec | head -n1),$(ispec))'\
	 '$(qmd0_path): $(source_dir)/$*.qmd $(my_counts_dir)/$(idata)'\
	 '$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/$*_$(idata).html: $(my_metadata)_$(idata).csv $(qmd0_path)'\
	) > $@
	echo '$*_pages=$(foreach idata,$(datasets),$*_$(idata))' >> $@
	echo '$*_qmds = $$(patsubst %,$(staging_dir)/%.qmd,$$($*_pages))'>> $@
	echo '$*_htmls = $$(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$$(VERSION)/%.html,$$($*_pages))'>> $@
	echo '$*_htmls: $$($*_htmls)'>> $@

ifneq (,$(filter-out $(or $(excluded-targets),$(MAKECMDGOALS)),$(MAKECMDGOALS)))
$(foreach c,$(datasets), \
$(eval include extdata/$(c).config) \
$(eval $(c).org.db=$(org.db)) \
$(eval $(c).categories=$(categories)) \
$(eval $(c).spec=$(spec)) \
$(eval $(c).nospec=$(nospec)))
endif

qmds=$(strip $(foreach section,$(sections),$($(section)_qmds)))

html_reports=$(strip $(foreach section,$(sections),$($(section)_htmls)))

css=$(patsubst $(source_dir)/css/%,$(staging_dir)/%,$(wildcard $(source_dir)/css/*.css))
$(css): $(staging_dir)/% : $(source_dir)/css/%
	cp $< $@
includes=$(patsubst $(source_dir)/html/%,$(staging_dir)/%,$(wildcard $(source_dir)/html/*.html))
$(includes): $(staging_dir)/% : $(source_dir)/html/%
	cp $< $@

ifeq ($(WRAP),none)
##     To be executed directly, so can expose targets without need for wrapping (in sbatch/container)

.PHONY: run pages scripts


quarto_opts=--output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR) -M repo:$(repo)

## Render the qmds to html in one quarto call
run: $(qmds) $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(covariate_files)| $(log_dir) data $(RESULTS_DIR)/$(VERSION)  $(genes_results)  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`.
	$(GIT) commit -m "Adding files generated by a differential run" || echo "No additional differential files needed adding"
	$(init_checkpoint)
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	rm -rf $(staging_dir)/$(RESULTS_DIR)/$(VERSION)
	rm -rf $(RESULTS_DIR)/$(VERSION).previous
	[ ! -d "$(RESULTS_DIR)/$(VERSION)" ] ||  mv $(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION).previous
	$(QUARTO) render '$(staging_dir)' $(quarto_opts) $(call log,render)
	rm -rf $(RESULTS_DIR)/$(VERSION).previous
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest
	$(save_checkpoint)


## Alternative is to render pages individually
## Possibly parallelisable, but seems to have a race condition
pages: $(html_reports) ## Generate the renders individually
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)/index.qmd' $(quarto_opts) 
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest

## Render an individual page
$(html_reports) : $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%.html : $(staging_dir)/%.qmd $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(covariate_files)| $(log_dir) $(RESULTS_DIR)/$(VERSION) $(staging_dir)/$(RESULTS_DIR)/$(VERSION)
	$(QUARTO) render '$<' $(quarto_opts) $(call log,html-$*)

html-%: $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%.html ## Create a single html file to be placed in the staging directory, '%' is a simplified filename e.g. `make html-01_exploratory_per-plan_GRCh38`.
	echo "$(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%.html"

.PHONY: notes
notes: $(staging_dir)/notes.md
	$(QUARTO) render $< $(quarto_opts)
	cp  $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/notes.html $(RESULTS_DIR)/$(VERSION)/

$(staging_dir)/notes.md: $(notesfile)
	:> $@
	[ "$(suffix $(notesfile))" = md ] || pandoc -s -o $@ $<  
	[ "$(notesfile)" = CHANGELOG.md ] || cat CHANGELOG.md >> $@

CHANGELOG.md:
	git log --pretty=format:"- %s (%h)" > $@

scripts: $(qmds) ## Generate all the parametrised scripts, into the staging directory. But don't render

$(qmds) : $(staging_dir)/%.qmd : $(staging_dir)/%.yml $(staging_dir)/$(VERSION).params.yml $(source_dir)/params.yml
	$(QUARTO) run $(source_dir)/typescript/merge_yml.ts\
	 --script=$(source_dir)/$(section).qmd\
	 --fixed=$(source_dir)/params.yml\
	 --subsection=$(staging_dir)/$*.yml\
	 --generated=$(staging_dir)/$(VERSION).params.yml > $@
	sed -i -e 's#choose_staging("$(section)")#"$(staging_dir)/$*"#' $@

$(qmds:qmd=yml):
	echo "title: $(data_source) $(or $(specname),$(spec))" > $@
	echo "description: $(data_source)-aligned data$(if $(spec), according to plan '$(spec)')" >> $@
	echo "categories: [$(if $(cat1),$(if $(cat2),$(cat1)$(comma)$(cat2),$(cat1)),$(cat2))]" >> $@
	echo "params:" >> $@
	echo "  data_source: $(data_source)" >> $@
	echo "  spec: $(or $(spec),'')" >> $@
	echo "  specname: $(or $(specname),'')" >> $@
	echo "  script: $(@:yml=qmd)" >> $@


$(staging_dir)/_quarto.yml: $(source_dir)/_quarto.yml $(qmds) $(css) $(includes)
	echo 'data_source: [$(subst $(space),$(comma)$(space),$(datasets))]' > ${staging_dir}/_sidebar.yml
	echo 'spec: [null,$(subst $(space),$(comma)$(space),$(specs))]' >> ${staging_dir}/_sidebar.yml
	echo 'section: [$(subst $(space),$(comma)$(space),$(sections))]' >> ${staging_dir}/_sidebar.yml
	$(QUARTO) run $(source_dir)/typescript/sidebar.ts\
	 --template=$< \
	 --staging=$(staging_dir)\
	 --repo="$(repo)" > $@
	echo 'multiqc: "$(if $(wildcard $(RESULTS_DIR)/multiqc-*),MultiQC and ,)"' >> $@
	[ -z "$(shortTitle)" ] || sed -i 's/title: Analysis results/title: $(shortTitle) analysis results/' $@
	cp $(source_dir)/_quarto-*.yml $(staging_dir)/
	rm -f ${staging_dir}/_sidebar.yml
	mkdir -p ${staging_dir}/_extensions
	cp -r  ${source_dir}/_extensions/. ${staging_dir}/_extensions/

$(staging_dir)/$(VERSION).params.yml:  resources/make/project.mk $(staging_dir)/R.bib
	mkdir -p $(dir $@)
	echo 'author: [{name: "$(or $(FULLNAME),$(shell whoami))", id: $(shell whoami), roles: Analyst, affiliation: $(or $(MY_AFFILIATION),{ref: [fci]})}]' > $@
	echo 'params: {$(foreach p,$(param_names),$p: "$($p)"$(comma))}' >> $@

$(staging_dir)/index.qmd : $(source_dir)/index.qmd $(qmds) $(staging_dir)/notes.md
	sed  's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $< > $@

$(staging_dir)/R.bib: extdata/R.bib
	cp $< $@

extdata/R.bib: | renv
	$(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")' $(call log,bib)

renv: | $(log_dir)
	sed -i '/\#DO NOT EDIT AFTER THIS LINE/q' resources/_dependencies.R
	for i in "$(orgs)"; do echo "library($$i)" >> resources/_dependencies.R; done
	if [ -f renv.lock ] ; then \
	  $(R) -e 'library(renv); activate()' ;\
	  $(R) -e 'library(renv); restore(); install(strsplit("$(orgs)", " +")[[1]], lock=TRUE)' ;\
	else \
	  $(GIT) stash push -m "Pipeline stashed. Use 'git stash pop' to retrieve it" -- $@ $(call log,renv) ;\
	  $(R) -e 'library(renv); init(bioconductor=TRUE)' ;\
	  $(R) -e 'library(renv); snapshot(type="all")' ;\
	fi
	$(GIT) add renv.lock renv .Rprofile $(source_dir)
	$(GIT) add $(wildcard ../makefile ../.gitignore ../readme.md ../.gitignore .pipeline-version)
	$(GIT) add $(wildcard makefile R .Rbuildignore .gitignore resources/_dependencies.R)
	$(GIT) commit -m 'Renv initialised by pipeline' || echo "No initialisation files need commiting" $(call log,renv,-a) 

endif

ifeq ($(WRAP),container)
##   To be executed by container so prefix the original call to make with the container
%: $(optionalContainer)
	$(containerPrefix) make $@ EXECUTOR=make
endif

ifeq ($(WRAP),sbatch)
## To be submitted. slurm_wrap contains an instruction to do the 'make' on a node.
%: $(optionalContainer)
	sbatch $(default_sbatch_args) $(sbatch_args) --wrap='$(slurm_wrap)'
endif



.PHONY: publish
publish: $(pubdir)/$(VERSION) ## Copy results to final location. Either 'outputs' folder (default), intranet (`make publish location=intranet`) or internet
	cp --no-preserve=mode -r $(RESULTS_DIR)/$(VERSION)/. $(extra_files) $(pubdir)/$(VERSION)
	cp --no-preserve=mode --recursive --dereference --no-clobber $(RESULTS_DIR)/multiqc-* $(pubdir)/ 2> /dev/null || true
	ln -sfn $(VERSION) $(pubdir)/latest
	[ "$(location)" = "outputs" ] || cp --no-preserve=mode -r .htaccess $(pubdir)/ || echo "Warning: no .htaccess files, so unauthorised people may be able to view these results"
	ln -sfn $$(realpath $(pubdir)/$(VERSION)) $(RESULTS_DIR)/published_$(location)
# Remove unpublished links in the notes file
	> $(pubdir)/$(VERSION)/notes.html
	while IFS= read -r line; do \
	  V=$$(echo "$$line" | sed -n 's|.*<a href="\.\./\(v[0-9]\+\.[0-9]\+\.[0-9]\+\)/index\.html">\1</a>.*|\1|p') ;\
	  [ -z "$$V" ] || [ -f "$(pubdir)/$$V/index.html" ] || line=$$(echo "$$line" | sed "s|<a href=\"\.\./$$V/index\.html\">$$V</a>|$$V|") ;\
	  echo "$$line" >> $(pubdir)/$(VERSION)/notes.html ;\
	done < $(RESULTS_DIR)/$(VERSION)/notes.html

include .latest
.latest:
	$(init_checkpoint)

retag: ## If you've changed the git tag for the source code but sourcecode is the same, reflect the changed tagging in the results without re-running
	$(call test_checkpoint)
	for f in $(RESULTS_DIR)/latest/*/*$(asrun.GIT_REF).*; do \
	  [ -e "$$f" ] || continue ;\
	  newf=$$(echo "$$f" | sed "s|$(asrun.GIT_REF)|$(GIT_REF)|") ;\
	  mv "$$f" "$$newf" ;\
	done
	find $(RESULTS_DIR)/latest/ -name '*.html' -exec sed -i "s|$(asrun.GIT_REF)|$(GIT_REF)|g" {} +
	find $(RESULTS_DIR)/latest/ -name '*.html' -exec sed -i "s|>$$(readlink $(RESULTS_DIR)/latest)</td>|>$(VERSION)</td>|g" {} +
	find $(RESULTS_DIR)/latest/ -name '*.html' -exec sed -i "s|>$(RESULTS_DIR)/$$(readlink $(RESULTS_DIR)/latest)</td>|>$(RESULTS_DIR)/$(VERSION)</td>|g" {} +
	mv $(RESULTS_DIR)/$$(readlink $(RESULTS_DIR)/latest)  $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest
	$(init_checkpoint)


################################################################
#### Bootstrap all relevant data from outside
################################################################

# Prevent non-specific upstream stuff invoking the generic container response
$(docs_dir)/% $(ingress_dir)/% $(nfcore_dir)/%:

#' Get external spec files
$(specfiles_dep): extdata/% : $(docs_dir)/% | extdata
	cp $< $@
	$(GIT) add $@ $<

#' Get external experiment table
$(my_metadata).csv: $(wildcard $(docs_dir)/$(experiment_table).csv) | $(dir $(my_metadata))
ifeq ($(wildcard $(docs_dir)/$(experiment_table).csv),)
	@echo "You must create $@, which assigns covariates' values to your samples"
	@exit 1
else
	$(MAKE) --no-print-directory -C $(ingress_dir) $(experiment_table).csv
	cp $(ingress_dir)/$(experiment_table).csv $@
	$(GIT) add $@ $<
endif

#' Get external configs
$(patsubst %,extdata/%.config,$(datasets_dep)): extdata/%.config: $(docs_dir)/%.config | extdata
	$(MAKE) --no-print-directory -C $(ingress_dir) $*.config
	cp $(ingress_dir)/$*.config $@
	$(GIT) add $@ $<

#' Get subtables of experiment table for external samplesheets
$(covariate_files_dep) : $(my_metadata)_%.csv : $(nfcore_dir)/samplesheet_%.csv $(my_metadata).csv extdata/%.config
	rm -f '$*.db'
	$(SQLITE) '$*.db' '.import --csv  $< $*'  ;\
	$(SQLITE) '$*.db' '.import --csv  $(my_metadata).csv metadata'  ;\
	$(SQLITE) -header -csv '$*.db' 'SELECT metadata.* FROM metadata INNER JOIN (SELECT * FROM "$*" GROUP BY $(samplesheet_id_column)) AS nfcore on metadata.$(metadata_id_column)=nfcore.$(samplesheet_id_column);' > $@
	rm -f '$*.db'
	$(GIT) add $@

$(nfcore_dir)/samplesheet_%.csv: $(docs_dir)/%.config $(docs_dir)/%.csv
	$(MAKE) --no-print-directory -C $(nfcore_dir) $*


#' nfcore-specific genes-results folder
$(genes_results): $(my_counts_dir)/%: $(nfcore_dir)/results/%/merged.gene_counts.tsv 
	dir=$(if $($*.group-as),$($*.group-as),$*);\
	mkdir -p $(my_counts_dir)/$${dir} ;\
	if [ "$($*.aligner)" = star_salmon ]; then \
	  for s in $(nfcore_dir)/results/$${dir}/star_salmon/*/quant.sf; do d=$(my_counts_dir)/$${dir}/star_salmon/$$(basename $$(dirname $$s)); mkdir -p $$d; cp -l $$s $$d/; done ;\
	  cp $(nfcore_dir)/results/$${dir}/star_salmon/salmon_tx2gene.tsv $(my_counts_dir)/$${dir}/star_salmon/ ;\
	else \
	  cp -l $(nfcore_dir)/results/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/ || cp  $(nfcore_dir)/results/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/ ;\
	fi
	mkdir -p $(RESULTS_DIR)/multiqc-$*
	cp -lr $(nfcore_dir)/results/$*/multi-qc/. $(RESULTS_DIR)/multiqc-$* || cp -r $(nfcore_dir)/results/$*/multi-qc/. $(RESULTS_DIR)/multiqc-$*

$(nfcore_dir)/results/%/merged.gene_counts.tsv : $(docs_dir)/%.config $(docs_dir)/%.csv
	$(MAKE) --no-print-directory -C $(nfcore_dir) $*


################################################################
#### Helper goals
################################################################

$(log_dir) $(dir $(my_metadata)) data $(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR) $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(staging_dir) extdata:
	mkdir -p $@

clean: ## Remove the staging folder and the log directory - these should never contain anything of lasting interest that can't be recreated
	rm -rf $(staging_dir) $(log_dir)
maintainer-clean: clean ## Remove the results and data directories, in addition to staging and logs. The former contain end-results, so only do this if you really want to discard them (e.g. the analysis had a bug in it, and you want to do some housekeeping)
	rm -rf $(RESULTS_DIR) data 



MAKEFLAGS += --no-builtin-rules
