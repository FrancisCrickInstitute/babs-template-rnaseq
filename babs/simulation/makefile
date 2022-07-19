include ../config/global.mk
include local.mk
-include ../ingress/*.config
-include *.config

.PHONY: build run copy publish clean

run: analyses  ## Create objects in `data` that store the results of applying each spec file, along with a versioned html report in `results`


alignments = simulated
specfiles = $(patsubst %.spec,%,$(wildcard *.spec))
result_objs = $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),data/$(spec)_x_$(alignment).dda))

.PHONY: analyses
analyses: $(result_objs)

.PHONY: submit
tmp_script:=$(shell mktemp -u)
submit:
	echo "$${slurm}" > $(tmp_script)
	make -n -s analyses >> $(tmp_script)
	sbatch $(tmp_script)
	rm -f $(tmp_script)

define RESULT_RULE
data/$(spec)_x_$(alignment).dda : resdir = results/$(VERSION)/$(alignment)/$(spec)
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


count_objs = $(patsubst %,data/counts_%.rda,$(alignments))
$(count_objs) : data/counts_%.rda : 00_init.r
	mkdir -p data
	$(R) -e "library(DESeq2);\
	 cdat <- read.csv('$(my_metadata)_$*.csv'); \
	 dds <- makeExampleDESeqDataSet(n=10000,m=nrow(cdat)); \
	 dds <- DESeqDataSetFromMatrix(counts(dds),cdat, ~1); \
	 mcols(dds)\$$symbol <- as.character(1:nrow(dds)); \
	 mcols(dds)\$$entrez <- as.character(1:nrow(dds)); \
	 save(dds, file='$@'); \
	 saveRDS(dds, file='$(@:rda=rds)')"


R.bib: renv.lock
	 $(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'



################################################################
#### Bootrap all relevant data from outside
################################################################

build: specfiles samplesheets scripts ## Create experimental tables that reflect the samples actually run. Generate R scripts and environment that will analyse the data. Copy the required nfcore count files into the `inst/extdata` area.
	make -n -s run > run.sh

docs_specfiles = $(patsubst ../docs/%,%,$(wildcard ../docs/*.spec))
specfiles: $(docs_specfiles)
$(docs_specfiles): %: ../docs/%
	cp $< $@

spec1 = $(firstword $(docs_specfiles))

.PHONY: samplesheets
samplesheets = $(my_metadata)_$(alignments).csv
samplesheets: $(samplesheets)
$(samplesheets) : ../docs/$(experiment_table).csv
	mkdir -p $(dir $(my_metadata))
	cp $< $@


.PHONY: scripts
scripts = 00_init.r 01_analyse.r
scripts: $(scripts) ## Generate (or reinstate) the default analysis scripts


$(scripts) &:  | renv.lock
	for file in $(scripts) ; do \
	  [ -f $${file} ] && git add -f "$${file}" || true;\
	done ;\
	if [ ! -z "$$(git diff --staged)" ] ; then \
	  git status ;\
	  echo "Please commit changes before re-running 'prepare_scripts'" ; exit 1 ;\
	fi ;\
	$(R) -e 'DESdemonA::get_started(files=commandArgs(trailing=TRUE),nfcore="", metadata="$(my_metadata)_$(alignments).csv", file_col="$(metadata_id_column)",name_col=c($(NAME_COLUMN)), counts="$(my_counts_dir)/$(alignments)/", org_package="$($(alignments).org.db)", count_source="$(alignments)", specfile="$(spec1)",  project="$(babsproject)", overwrite=TRUE)' --args $(scripts)
	sed -i '376i knitr::knit_exit()' 01_analyse.r
	git add $(scripts)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1

renv.lock:orgs=$(subst $(space),$(comma),$(foreach align,$(nfcore_alignments),$($(align).org.db))),
renv.lock: .renv.lock
	cp $< $@
	module purge ;\
	export RENV_PATHS_LIBRARY=renv/library ;\
	$(R) -e 'library(renv); renv::restore() '
	git add renv.lock
	git commit -m "Pipeline creates renv environment"


.PHONY: R-local
R-local: R-$(Rversion)
R-$(Rversion):
	echo "#!/bin/bash" > $@
	echo "function R {" >> $@
	echo "$(R)" \$$@>> $@
	echo "}" >> $@
	echo "function Rscript {" >> $@
	echo "$(R)script" \$$@ >> $@
	echo "}" >> $@
	echo "[[ "'$$BASH_SOURCE'" == "'$$0'" ]] && R " \$$@ >> $@
	setfacl -m u::rwx $@




copy:

clean:

publish:


MAKEFLAGS += --no-builtin-rules
