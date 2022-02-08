include ../config/global.mk
include local.mk
-include ../ingress/*.config

.PHONY: build run

run: analyses


$(V).SILENT:

alignments := $(patsubst inst/extdata/genes.results/%,%,$(wildcard inst/extdata/genes.results/*))
specfiles := $(patsubst %.spec,%,$(wildcard *.spec))
count_objs := $(patsubst %,data/dds_%.rda,$(alignments))
result_objs := $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),data/$(spec)_x_$(alignment).dda))


.PHONY: analyses
analyses: $(result_objs)

.SECONDEXPANSION:
$(result_objs): data/%.dda: 01_analyse.r $$(word 1,$$(subst _x_, ,%)).spec data/dds_$$(word 2,$$(subst _x_, ,%)).rda R.bib
	SPEC=$(word 2,$^) ;\
	ALIGN=$(patsubst data/dds_%.rda,%,$(word 3,$^)) ;\
	OUTDIR=results/$(VERSION)/$${ALIGN} ;\
	mkdir -p "$${OUTDIR}" ;\
	$(R) -e "rmarkdown::render('$<', output_file='$*_$(TAG).html', output_options = list(self_contained=$(contained)), params=list(res_dir='$${OUTDIR}',spec_file='$${SPEC}', spec_suffix='$${ALIGN}'))" ;\
	rm -f "$${OUTDIR}/$*_$(TAG).html" ;\
	mv "$*_$(TAG).html"  "$${OUTDIR}" ;\
	rm -rf "$${OUTDIR}/$*_$(TAG)_files" ;\
	mv "$*_$(TAG)_files" "$${OUTDIR}" ;\
	ln -sfn "results/$${VERSION}" results/latest



.PHONY: generate_count_objects
generate_count_objects: $(count_objs)

$(count_objs) : data/dds_%.rda : 00_init.r $(wildcard ../nfcore/results/%/star_rsem/*.genes.results)
	$(R) -e "source('00_init.r')" --args spec_suffix="$*" nfcore="../nfcore/results/$*" metadata="inst/extdata/experimental_table$*.csv" file_col="_babs_nfcore" name_col="sample_label" counts="../nfcore/results/$*/star_rsem/" org_package="$($*.org.db)"


R.bib: renv.lock
	 $(R) -e 'renv::restore(); knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'




################################################################
#### Bootrap all relevant data from outside
################################################################

build: genes_results docs_specfiles samplesheets prepare_scripts
	make -n -s all > run.sh

docs_specfiles := $(patsubst ../docs/%,%,$(wildcard ../docs/*.spec))
docs_specfiles: $(docs_specfiles)

$(docs_specfiles): %: ../docs/%
	cp $< $@

samplesheets:= $(patsubst %,inst/extdata/experimental_table%.csv,$(alignments))
samplesheets: $(samplesheets)

$(samplesheets) : inst/extdata/experimental_table%.csv : samples.db
	$(SQLITE) -header -csv  samples.db 'SELECT asf.$(label_column) AS _babs_nfcore, metadata.* FROM metadata LEFT JOIN (SELECT * FROM fastqs GROUP BY sample) AS asf on metadata.$(meta2asf)=asf.sample WHERE asf._babs_config_file="$*";' > $@

samples.db: ../ingress/samples.db ../docs/metadata.csv
	cp $< $@
	$(SQLITE) $@ -csv "DROP TABLE IF EXISTS metadata;"
	$(SQLITE) $@ -csv ".import $(word 2, $^) metadata"


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


genes_results := $(patsubst ../nfcore/results/%,inst/extdata/genes.results/%,$(wildcard ../nfcore/results/*))
genes_results : $(genes_results)
$(genes_results): inst/extdata/genes.results/%: ../nfcore/results/%
	if [ -z "${$*.group-as}" ] ; then \
	  mkdir -p inst/extdata/genes.results/$* ;\
	  cd inst/extdata/genes.results/$* ;\
	else \
	  mkdir -p inst/extdata/genes.results/${$*.group-as} ;\
	  cd  inst/extdata/genes.results/${$*.group-as} ;\
	fi ;\
	ln -f ../../../../../nfcore/results/$*/star_rsem/*.genes.results . ;\

