
R := module load pandoc/2.2.3.2-foss-2016b;  module load R/4.0.3-foss-2020a; R 

# Staging area to gather all (links to) fastqs from above
fastq_dir    := inst/extdata/fastq

# We'll set up a convenience links to the following folders 

# NF-Core settings
nf_outdir    := results$(spec_suffix)# where to store results
nf_cache_dir := /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.0/

# Where the downstream analysis should put it's results
des_outdir   := ${nf_outdir}

# Where to look for experimental design information
des_metadata := inst/extdata/metadata.xlsx
file_column  := "filename","sample","sample_ID","Sample.limsid"
name_column  := "name","label","sample","filename"

# Produce a self-contained report (false to link images etc)
contained    := FALSE

################################################################

TAG = $(shell git describe --tags --dirty=_altered --always --long)# e.g. v1.0.2-2-ace1729a
VERSION = $(shell git describe --tags --abbrev=0)#e.g. v1.0.2

$(V).SILENT:

.PHONY: analyses
dda := $(patsubst %.spec,data/%_dds.rda,$(wildcard *$(spec_suffix).spec))
analyses: $(dda)

$(dda): data/%_dds.rda: 01_analyse.r %.spec data/dds$(spec_suffix).rda R.bib
	mkdir -p "$(des_outdir)/$(VERSION)"
	$(R) -e "rmarkdown::render('$<',\
	  output_file='$*_$(TAG).html',\
	  output_options = list(self_contained=$(contained)),\
	  params=list(res_dir='$(strip $(des_outdir))/$(VERSION)',spec_file='$*.spec', spec_suffix='$(spec_suffix)'))"
	rm -f "$(des_outdir)/$(VERSION)/$*_$(TAG).html"
	mv "$*_$(TAG).html"  "$(des_outdir)/$(VERSION)"
	rm -rf "$(des_outdir)/$(VERSION)/$*_$(TAG)_files"
	mv "$*_$(TAG)_files" "$(des_outdir)/$(VERSION)"


data/dds$(spec_suffix).rda: 00_init.r $(wildcard inst/extdata/rsem/*.genes.results)
	$(R) -e "source('00_init.r')" --args spec_suffix="$(spec_suffix)"


R.bib: renv.lock
	 $(R) -e 'renv::restore(); knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'


.PHONY: init
init_files = 00_init.r 01_analyse.r DESCRIPTION
init:
	mkdir -p data
	git rev-parse --git-dir > /dev/null 2>&1 || git init
	for file in $(init_files) ; do \
	  [ -f $${file} ] && git add "$${file}" || true;\
	done ;\
	if [ ! -z "$$(git diff --staged)" ] ; then \
	  git status ;\
	  echo "Please commit changes before re-running 'init'" ; exit 1 ;\
	fi ;\
	$(R) -e 'renv::restore(); DESdemonA::get_started(files=commandArgs(trailing=TRUE), nfcore="$(strip ${nf_outdir})", metadata="${des_metadata}", file_col=c($(file_column)), name_col=c($(name_column)), overwrite=TRUE)' --args $(init_files)
	git add $(init_files)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1

