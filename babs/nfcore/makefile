include ../system.mk
include local.mk
-include *.config

.PHONY: run build copy publish clean

alignments = $(patsubst samplesheet_%.csv, results/%/pipeline_info/execution_report.html, $(wildcard samplesheet_*.csv))

run: $(alignments) ## Generate NF-CORE alignments, one folder for each config-specific samplesheet from the `build` process.

$(alignments) : results/%/pipeline_info/execution_report.html : samplesheet_%.csv
	mkdir -p $@
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	$(NEXTFLOW) run nf-core/rnaseq \
	--input $< \
	--outdir $@/ \
	--aligner star_rsem \
	--fasta "$($*.genome_fasta)" \
	--gtf "$($*.gtf)" \
	-w "${nf_work}" \
	$(nf_options)


################################################################
#### Bootrap all relevant data from outside
################################################################
configs = $(patsubst ../ingress/%.config,%.config,$(wildcard ../ingress/*.config))
samplesheets = $(patsubst %.config,samplesheet_%.csv,$(configs))

build: $(samplesheets) ## Build all necessary inputs: samplesheets for each matching alignment '.config' from 'docs'.
	mkdir -p ${nf_work}
	ln -sf ${nf_work} nf_work


field=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/" TEXT/' "$*.config" | paste -sd ',')
insfield=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/"/' "$*.config" | paste -sd ',')
vals=$(shell sed -r '/^$$/d; s/.*=(.*)/"\1"/' "$*.config" | paste -sd ',')

$(samplesheets): samplesheet_%.csv: %.config  samples.db
	$(SQLITE) samples.db 'DROP TABLE IF EXISTS "config_$*";' \
	'CREATE TABLE "config_$*" ($(field));' \
	'INSERT INTO "config_$*" ($(insfield)) VALUES ($(vals));' \
	'UPDATE fastqs SET _babs_config_file="$*" WHERE fastqs.$(samplesheet_id_column) IN (SELECT $(samplesheet_id_column) FROM fastqs NATURAL JOIN "config_$*") ;'
	$(SQLITE) -header -csv  samples.db 'SELECT $(samplesheet_id_column) AS sample, fastq_1, fastq_2, strandedness FROM fastqs NATURAL JOIN "config_$*" ;' > $@

$(configs) : %.config : ../ingress/%.config
	cp $< $@

samples.db: ../ingress/samples.db
	cp $< $@

clean: ## Remove working files from scratch
	rm -rf ${nf_work}
	rm -f nf_work

run-clean:

build-clean:  ## Remove files only needed for re-`run`ning. Downstream steps will still work if `run` has already completed.
	rm -f $(samplesheets)
	rm -f samples.db


clean-complete: clean-build ## Complete reset. Donwstream steps will no `build` (and perhaps might not even run even if they've already been built.)
	rm -rf results/$(alignments)
