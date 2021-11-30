include ../config/global.mk
R := module load pandoc/2.2.3.2-foss-2016b;  module load R/4.0.3-foss-2020a; R 

# which metadata column will match ASF's 'sample' column.
meta2asf := ASF_lims_id
# Where to look for experimental design information
name_column  := "name","label","sample","filename"
# Produce a self-contained report (false to link images etc)
contained    := FALSE

################################################################

TAG = $(shell git describe --tags --dirty=_altered --always --long)# e.g. v1.0.2-2-ace1729a
VERSION = $(shell git describe --tags --abbrev=0)#e.g. v1.0.2

$(V).SILENT:

alignments := $(patsubst ../nfcore/samplesheet_%.csv,%,$(wildcard ../nfcore/samplesheet_*.csv))
specfiles := $(patsubst %.spec,%,$(wildcard *.spec))

count_objs := $(patsubst %,data/counts_%.rda,$(alignments))
result_objs := $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),data/$(spec)_x_$(alignment).dda))

.PHONY: analyses
analyses: $(result_objs)

.SECONDEXPANSION:
$(result_objs): data/%.dda: 01_analyse.r $$(word 1,$$(subst _x_, ,%)).spec data/counts_$$(word 2,$$(subst _x_, ,%)).rda R.bib
	SPEC=$(word 1,$(subst _x_, ,$*)) ;\
	ALIGN=$(word 2,$(subst _x_, ,$*)) ;\
	OUTDIR=../results/$${ALIGN}/$(VERSION) ;\
	mkdir -p "$${OUTDIR}" ;\
	$(R) -e "rmarkdown::render('$<', output_file='$*_$(TAG).html', output_options = list(self_contained=$(contained)), params=list(res_dir='$${OUTDIR}',spec_file='$${SPEC}.spec', spec_suffix='$${ALIGN}'))" ;\
	rm -f "$${OUTDIR}/$*_$(TAG).html" ;\
	mv "$*_$(TAG).html"  "$${OUTDIR}" ;\
	rm -rf "$${OUTDIR}/$*_$(TAG)_files" ;\
	mv "$*_$(TAG)_files" "$${OUTDIR}" ;\
	ln -sfn "$${OUTDIR}" ../results/latest



.PHONY: generate_count_objects
generate_count_objects: $(count_objs)

$(count_objs) : data/counts_%.rda : 00_init.r $(wildcard ../results/%/nfcore/rsem/*.genes.results)
	$(R) -e "source('00_init.r')" --args spec_suffix="$*" nfcore="../results/$*/nfcore" metadata="inst/extdata/metadata_$*.csv" file_col="_babs_nfcore" name_col="sample_label" counts=../results/$*/nfcore/star_rsem/ nfcore=../results/$*/nfcore/ org_package=org.Mm.eg.db


R.bib: renv.lock
	 $(R) -e 'renv::restore(); knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'


.PHONY: prepare_scripts
desdemona_files = 00_init.r 01_analyse.r DESCRIPTION
prepare_scripts: $(desdemona_files)

$(desdemona_files) &: renv.lock 
	git rev-parse --git-dir > /dev/null 2>&1 || git init
	for file in $(desdemona_files) ; do \
	  [ -f $${file} ] && git add "$${file}" || true;\
	done ;\
	if [ ! -z "$$(git diff --staged)" ] ; then \
	  git status ;\
	  echo "Please commit changes before re-running 'prepare_scripts'" ; exit 1 ;\
	fi ;\
	$(R) -e 'renv::restore(); DESdemonA::get_started(files=commandArgs(trailing=TRUE),nfcore="",metadata="",file_col="_babs_nfcore",name_col=c($(name_column)),overwrite=TRUE)' --args $(desdemona_files)
	git add $(desdemona_files)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1



samplesheets:= $(patsubst %,inst/extdata/metadata_%.csv,$(alignments))
samplesheets: $(samplesheets)

$(samplesheets) : inst/extdata/metadata_%.csv : samples.db
	sqlite3 -header -csv  samples.db 'SELECT asf.$(label_column) AS _babs_nfcore, metadata.* FROM metadata LEFT JOIN (SELECT * FROM fastqs GROUP BY sample) AS asf on metadata.$(meta2asf)=asf.sample WHERE asf._babs_config_file="$*";' > $@

samples.db: ../nfcore/samples.db ../docs/metadata.csv
	cp $< $@
	sqlite3 $@ -csv "DROP TABLE IF EXISTS metadata;"
	sqlite3 $@ -csv ".import $(word 2, $^) metadata"


