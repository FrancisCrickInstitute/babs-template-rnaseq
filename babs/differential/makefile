.PHONY: makefile project.mk system.mk ../system.mk
.PHONY: build clean
-include secrets
include ../system.mk
include system.mk

## Macros to turn section heading into qmd/html filenames
## $(1)_pages is a variable that will get set by the `section`.mk file
## and will contain the page names derived from the multi-stanza
## yml source file for that section.
qmds-of-section = $(patsubst %,$(staging_dir)/%$(TAG).qmd,$($(1)_pages))
htmls-of-section = $(patsubst %,$(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%$(TAG).html,$($(1)_pages))
params-of-section = $(foreach p,$($(1)_param_names),$(patsubst %,-P %:$($(p)),$(p)))
ymls = $(foreach section,$(sections),$(patsubst %,$(staging_dir)/%.yml,$($(section)_pages)))

define section-dependency-template = 
$(1)_htmls=$(call htmls-of-section,$(1))
$(1)_qmds=$(call qmds-of-section,$(1))
$$($(1)_qmds): $(source_dir)/$(1).qmd
$(source_dir)/$1.yml: params=$(call params-of-section,$(1))
endef

include project.mk  ## Provides analysis parametrisation

# Create a makefile per section, that contains a variable derived from the
# source-file yaml stanzas.  The variable, named after the section, will
# contain a list of all the yaml files in that section. And a rule that
# ensures the above rule will be invoked to generate the separate ymls
#

with-ymls=$(filter $(sections),$(patsubst $(source_dir)/%.yml,%,$(wildcard $(source_dir)/*.yml)))
mk-with-yml = $(patsubst %,$(staging_dir)/%.mk,$(with-ymls))
without-ymls= $(filter-out $(with-ymls),$(sections))
mk-no-yml = $(patsubst %,$(staging_dir)/%.mk,$(without-ymls))

$(mk-with-yml): $(staging_dir)/%.mk : $(source_dir)/%.yml
	mkdir -p $(staging_dir)
	if [ $$(grep -c "^- title:" $<) == no ] ;\
	 then awk -F': ' 'BEGIN {ORS=" "; print "$*_pages="}; /^- title/{print "$*"}' $<  > $@ ;\
	 else awk -F': ' 'BEGIN {ORS=" "; print "$*_pages="}; /^- title/{x=$$2;j=sprintf("%02d",i++); gsub(/[^[:alnum:]]/,"_",x); print "$*_"j"_"x;}' $< > $@ ;\
	fi
	echo -e '\n$*_yamls = $$(patsubst %,$(staging_dir)/%.yml,$${$*_pages})'>> $@
	echo -e '\n$${$*_yamls} : $<' >> $@

$(mk-no-yml):  $(staging_dir)/%.mk :
	mkdir -p $(staging_dir)
	echo "$*_pages = $*" >> $@

alignments = $(patsubst ${my_counts_dir}/%,%,$(wildcard ${my_counts_dir}/*))
samplesheets = $(patsubst %,$(my_metadata)_%.csv,$(alignments))
include $(patsubst %,%.config,$(alignments))

ifeq ($(SUBMIT),false)
    ifeq ($(CONTAINERED),false)
##     Being executed directly - no submission or containerisation

.PHONY: run
run: render  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`.  Requires 'make build' be done first.




## Render the qmds to html in one quarto call
.PHONY: render
render: $(qmds)  $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(samplesheets)| $(log_dir) data $(RESULTS_DIR)/$(VERSION) ## Render the whole directory of generated qmds
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)' --output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR) >$(log_dir)/render.log 2>&1
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest


## Alternative is to render pages individually
## Possibly parallelisable, but seems to have a race condition
.PHONY: pages
pages: $(html_reports) ## Generate the renders individually
	sed  -i 's#^  contents: .*#  contents: [$(subst $(space),$(comma),$(patsubst $(staging_dir)/%,%,$(qmds)))]#' $(staging_dir)/index.qmd
	$(QUARTO) render '$(staging_dir)/index.qmd' --output-dir $(RESULTS_DIR)/$(VERSION) --execute-dir $(CURDIR)
	cp -rT $(staging_dir)/$(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR)/$(VERSION)
	ln -sfn  $(VERSION) $(RESULTS_DIR)/latest

## Render an individual page
$(html_reports) : $(staging_dir)/$(RESULTS_DIR)/$(VERSION)/%$(TAG).html : $(staging_dir)/%$(TAG).qmd $(staging_dir)/_quarto.yml $(staging_dir)/index.qmd $(samplesheets)| $(log_dir) $(RESULTS_DIR)/$(VERSION)
	$(QUARTO) render '$<' \
	  --output-dir $(RESULTS_DIR)/$(VERSION)/ \
	  --execute-dir $(CURDIR) >$(log_dir)/html-$*.log 2>&1


.PHONY: scripts
scripts: $(qmds) ## Generate all the parametrised scripts, into the staging directory. But don't render

$(qmds) : $(staging_dir)/%$(TAG).qmd : $(staging_dir)/%.yml
	$(QUARTO) run $(source_dir)/typescript/merge_yml.ts --script=$(filter %.qmd,$^) --yml=$(staging_dir)/$*.yml >> $@
	sed -i -e 's#$(yaml-filename-placeholder) <- .*$$#$(yaml-filename-placeholder) <- "$(staging_dir)/$*.yml"#' $@



${staging_dir}/_quarto.yml: $(source_dir)/_quarto.yml $(qmds)
	$(QUARTO) run $(source_dir)/typescript/sidebar.ts --template=$< --tag=$(TAG) --staging=$(staging_dir) > $@

${staging_dir}/index.qmd : $(source_dir)/index.qmd
	cp $< $@


## Separate a section-wide yml with a chunk per page into separate yml
## files. Chunks delimited by a title field. The '$<' prerequisite
## will have been set in the autogenerated section-specific makefile,
## pointing at the multi-stanza yml (so if none, for singleton qmds,
## initialise and empty file)


$(ymls):$(staging_dir)/%.yml:
	if [ -n "$<" ] ;\
	 then awk -F': ' '/^- title/{x=$$2;j=sprintf("%02d",i++)}{gsub(/[^[:alnum:]]/,"_",x);  if ("${staging_dir}/$(patsubst $(source_dir)/%.yml,%,$(filter %.yml,$^))_"j"_"x".yml" == "$@") print;}' $<  >$@ ;\
	 else touch $@ ;\
	fi

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
	$(CONTAINER) $(CONTAINER_FLAGS) $(CONTAINER_IMAGE) bash "$${bash_script}" ;\
	r=$$? ;\
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

.PHONY: geo
geo: geo/md5.txt  ## Gather everything into the 'geo' folder. Specify `geo_version=`, `geo_alignment=` and `geo_spec=` to customise. Remember to `make clean-geo` when the files have been upload.


geo_version=latest
geo_alignment=$(firstword $(aligments))
geo_spec=$(firstword $(specs))
geo/md5.txt:
	mkdir -p $(geo_dir)
	ln -s $(geo_dir) geo
	ln -f $(my_counts_dir)/$(geo_alignment)/*.genes.results geo/
	ln -f $(results)/$(geo_version)/$(geo_alignment)/$(geo_spec)/*.xlsx geo/
	$(SQLITE) $(samples_db) 'select fastq_1 from fastqs  where _babs_config_file="$(geo_alignment)";' | \
	while read -r fq ; do cp ${fq} geo/ ; done
	$(SQLITE) $(samples_db) 'select fastq_2 from fastqs  where _babs_config_file="$(geo_alignment)";' | \
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
## TODO - won't work when we do a group-by of alignments

################################################################
#### Bootrap all relevant data from outside
################################################################
nf_alignments = $(patsubst $(nfcore_dir)/%,%,$(wildcard $(nfcore_dir)/*))

# external specfiles union (local specfiles that aren't also external)
specfiles = $(patsubst $(docs_dir)/%,%,$(wildcard $(docs_dir)/*.spec))

samples_db = samples.db
genes_results = $(patsubst %,$(my_counts_dir)/%,$(nf_alignments))
source_ymls=$(patsubst %,$(source_dir)/%.yml,$(sections))
multiqc_results = $(patsubst %,$(RESULTS_DIR)/multiqc-%,$(nf_alignments))

build: $(samplesheets) $(specfiles) $(genes_results) $(source_ymls) $(multiqc_results) | $(source_dir) $(staging_dir) ##  Copy the required nfcore count files into the `inst/extdata` area, and get the spec files.


$(samplesheets) : $(my_metadata)_%.csv : $(samples_db) 
	$(SQLITE) -header -csv  $(samples_db) 'SELECT metadata.* FROM metadata INNER JOIN (SELECT * FROM fastqs GROUP BY $(samplesheet_id_column)) AS asf on metadata.$(metadata_id_column)=asf.$(samplesheet_id_column) WHERE asf._babs_config_file="$*";' > $@

$(samples_db): $(my_metadata).csv $(nfcore_dir)/../$(samples_db)
	cp $(nfcore_dir)/../$(samples_db) $@ || echo "No samples database in nfcore directory"
	$(SQLITE) $@ -csv "DROP TABLE IF EXISTS metadata;"  ".import $< metadata"

$(my_metadata).csv: $(docs_dir)/$(experiment_table).csv | $(dir $(my_metadata))
	cp $< $@

$(specfiles): % : $(docs_dir)/%
	cp $< $@

$(patsubst %,%.config,$(nf_alignments)): %.config: ../nfcore/%.config
	cp $< $@

include $(patsubst %,%.config,$(filter-out $(alignments),$(nf_alignments)))

$(genes_results): $(my_counts_dir)/%: $(nfcore_dir)/% %.config
	dir=$(if $($*.group-as),$($*.group-as),$*);\
	mkdir -p $(my_counts_dir)/$${dir} ;\
	ln -f $(nfcore_dir)/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/

$(multiqc_results) : $(RESULTS_DIR)/multiqc-% : $(nfcore_dir)/% | $(RESULTS_DIR)
	ln -sfn ../$</multiqc/star_rsem $@

$(source_ymls) : %.yml : %.qmd
$(patsubst %.yml,%.qmd,$(source_ymls)) :
	touch $@

sed-p2yml = 's/^ *-P */    /; s/: */: /g; s/ *-P */\n    /g;'
$(source_dir)/00_init.yml: orgs=$(foreach align,$(nf_alignments),$($(align).org.db))
$(source_dir)/00_init.yml: $(nf_alignments:=.config) | $(source_dir)
	rm -f $@
	orgs=($(orgs)) ;\
	oi=0;\
	for i in $(nf_alignments); do \
	echo "- title: $$i" >> $@ ;\
	echo "  description: of $${i}-aligned data" >> $@ ;\
	echo "  categories: [$${i}]" >> $@ ;\
	echo "  params:" >> $@ ;\
	echo "    alignment: $${i}" >> $@ ;\
	echo "    metadata: $(my_metadata)_$${i}.csv" >> $@ ;\
	echo "    counts: $(my_counts_dir)/$${i}/" >> $@ ;\
	echo "    org_package: $${orgs[oi]}" >> $@ ;\
	echo "${all_params}" | sed $(sed-p2yml) >> $@ ;\
	echo "${params}" | sed $(sed-p2yml) >> $@ ;\
	echo "" >> $@ ;\
	let oi=oi+1;\
	done

$(source_dir)/01_analyse.yml: $(specfiles) $(nf_alignments:=.config) | $(source_dir)
	rm -f $@
	for i in $(nf_alignments) ; do \
	for j in $(patsubst $(docs_dir)/%,%,$(specfiles:.spec=)) ; do \
	echo "- title: $$i $$j" >> $@ ;\
	echo "  description: of $${i}-aligned data according to '$${j}'" >> $@ ;\
	echo "  categories: [$${i}, $${j}]" >> $@ ;\
	echo "  params:" >> $@ ;\
	echo "    alignment: $${i}" >> $@ ;\
	echo "    spec: $${j}" >> $@ ;\
	echo "${all_params}" | sed $(sed-p2yml) >> $@ ;\
	echo "${params}" | sed $(sed-p2yml) >> $@ ;\
	echo "" >> $@ ;\
	done; done 

$(patsubst %,$(source_dir)/%.yml,$(filter-out 00_init 01_analyse,$(sections))) : $(source_dir)/%.yml : $(specfiles) $(alignments:=.config) | $(source_dir)
	rm -f $@
	for i in $(alignments) ; do \
	for j in $(patsubst $(docs_dir)/%,%,$(specfiles:.spec=)) ; do \
	echo "title: $$i $$j" >> $@ ;\
	echo "description: $${i}-aligned data according to '$${j}'" >> $@ ;\
	echo "categories: [$${i}, $${j}]" >> $@ ;\
	echo "params:" >> $@ ;\
	echo "  alignment: $${i}" >> $@ ;\
	echo "  spec: $${j}" >> $@ ;\
	echo "${all_params}" | sed $(sed-p2yml) >> $@ ;\
	echo "${params}" | sed $(sed-p2yml) >> $@ ;\
	echo "" >> $@ ;\
	done; done

#l=$(foreach looper,$1,for $(looper) in $($(looper)) ; do )
#s=$(call l,alignments specfiles)

$(log_dir) $(source_dir) $(staging_dir) $(dir $(my_metadata)) data $(RESULTS_DIR)/$(VERSION) $(RESULTS_DIR):
	mkdir -p $@


rocker.Renviron: 
	echo "RENV_PATHS_PREFIX=$(RENV_PATHS_PREFIX)" > $@
	echo "RENV_PATHS_ROOT=$(RENV_PATHS_ROOT)" >> $@
	echo "RENV_PATHS_LIBRARY=renv/library" >> $@


.PHONY: R-local
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
