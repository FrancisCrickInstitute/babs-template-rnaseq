R := module load pandoc/2.2.3.2-foss-2016b;  module load R/4.0.3-foss-2020a; R 

# NF-Core settings
nf_outdir    := ../results
nf_cache_dir := /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.0/
label_column := sample # which column from the ASF csv to use in nf-core.  Maybe sample_name
meta2asf := ASF_lims_id # which metadata column will match ASF's 'sample' column.

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
nfcore_sheets := $(wildcard ../nfcore/samplesheet_*.csv)
dds := $(patsubst ../nfcore/samplesheet_%.csv,data/dds%.rda,$(nfcore_sheets))
dda := $(patsubst %.spec,data/%_dds.rda,$(wildcard *.spec))

.PHONY: analyses
analyses: $(dda)

$(dda): data/%_dds.rda: 01_analyse.r %.spec $(dds) R.bib
	mkdir -p "$(des_outdir)/$(VERSION)"
	$(R) -e "rmarkdown::render('$<', output_file='$*_$(TAG).html', output_options = list(self_contained=$(contained)), params=list(res_dir='$(strip $(des_outdir))/$(VERSION)',spec_file='$*.spec', spec_suffix='$(spec_suffix)'))"
	rm -f "$(des_outdir)/$(VERSION)/$*_$(TAG).html"
	mv "$*_$(TAG).html"  "$(des_outdir)/$(VERSION)"
	rm -rf "$(des_outdir)/$(VERSION)/$*_$(TAG)_files"
	mv "$*_$(TAG)_files" "$(des_outdir)/$(VERSION)"
	ln -sfn "$(des_outdir)/$(VERSION)" ../results/latest


.PHONY: generate_count_objects
generate_count_objects: $(dds)

$(dds) : data/dds%.rda : 00_init.r $(wildcard ../results/nfcore/%/rsem/*.genes.results)
	$(R) -e "source('00_init.r')" --args spec_suffix="$*" nfcore=../results/nfcore/$* metadata=inst/extdata/metadata_$*.csv


R.bib: renv.lock
	 $(R) -e 'renv::restore(); knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'


.PHONY: prepare_scripts
desdemona_files = 00_init.r 01_analyse.r DESCRIPTION
prepare_scripts: $(desdemona_files)

$(desdemona_files): renv.lock 
	git rev-parse --git-dir > /dev/null 2>&1 || git init
	for file in $(desdemona_files) ; do \
	  [ -f $${file} ] && git add "$${file}" || true;\
	done ;\
	if [ ! -z "$$(git diff --staged)" ] ; then \
	  git status ;\
	  echo "Please commit changes before re-running 'prepare_scripts'" ; exit 1 ;\
	fi ;\
	$(R) -e 'renv::restore(); DESdemonA::get_started(files=commandArgs(trailing=TRUE),nfcore="$(strip ${nf_outdir})",metadata="${des_metadata}",file_col=c($(file_column)),name_col=c($(name_column)),overwrite=TRUE)' --args $(desdemona_files)
	git add $(desdemona_files)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1



samplesheets := $(patsubst ../nfcore/samplesheet_%.csv,inst/extdata/metadata_%.csv,$(nfcore_sheets))
samplesheets: $(samplesheets)

$(samplesheets) : inst/extdata/metadata_%.csv : samples.db
	sqlite3 -header -csv  samples.db 'SELECT asf.$(label_column) AS _babs_nfcore, metadata.* FROM metadata LEFT JOIN (SELECT * FROM fastqs GROUP BY sample) AS asf on metadata.$(meta2asf)=asf.sample WHERE asf._babs_config_file="$*";' > $@

samples.db: ../nfcore/samples.db ../docs/metadata.csv
	cp $< $@
	sqlite3 $@ -csv "DROP TABLE IF EXISTS metadata;"
	sqlite3 $@ -csv ".import $(word 2, $^) metadata"


