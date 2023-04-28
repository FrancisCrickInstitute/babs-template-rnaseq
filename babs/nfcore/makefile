global.mk: $(wildcard ../system.mk)
	[[ -f ../system.mk ]] && cp ../system.mk $@ || touch $@

secrets: $(wildcard ../secrets)
	[[ -f ../secrets ]] && cp ../secrets $@ || touch $@
include secrets
include global.mk
include local.mk
-include *.config

.PHONY: run build copy publish clean

alignments = $(patsubst samplesheet_%.csv, results/%/star_rsem/rsem.merged.gene_counts.tsv, $(wildcard samplesheet_*.csv))

run: $(alignments) ## Generate NF-CORE alignments, one folder for each config-specific samplesheet from the `build` process.

$(alignments) : results/%/star_rsem/rsem.merged.gene_counts.tsv : samplesheet_%.csv | log
	mkdir -p results/$*
	export NXF_VERSION=`echo "$($*.nfcore)" | sed 's/.*-r \([0-9]\+\.[0-9]\+\).*/\1/'` ;\
	export NXF_SINGULARITY_CACHEDIR="$(NXF_SINGULARITY_CACHEDIR)" ;\
	export NXF_HOME=$$PWD ;\
	$(NEXTFLOW) run nf-core/rnaseq \
	--input $< \
	--outdir results/$*/ \
	--aligner star_rsem \
	--fasta "$($*.genome_fasta)" \
	--gtf "$($*.gtf)" \
	-w "nf_work/" \
	$($*.nfcore) $(call log,nfcore)


################################################################
#### Bootrap all relevant data from outside
################################################################
configs = $(patsubst ../ingress/%.config,%.config,$(wildcard ../ingress/*.config))
samplesheets = $(patsubst %.config,samplesheet_%.csv,$(configs))

build: $(samplesheets) ## Build all necessary inputs: samplesheets for each matching alignment '.config' from 'docs'.
	mkdir -p $(SCRATCH_DIR)nf_work/
	[ -z "$(SCRATCH_DIR)" ] || ln -sf $(SCRATCH_DIR)nf_work nf_work


field=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/" TEXT/' "$*.config" | paste -sd ',')
insfield=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/"/' "$*.config" | paste -sd ',')
vals=$(shell sed -r '/^$$/d; s/.*=(.*)/"\1"/' "$*.config" | paste -sd ',')

$(samplesheets): samplesheet_%.csv: %.config  samples.db
	$(SQLITE) samples.db 'DROP TABLE IF EXISTS "config_$*";' \
	'CREATE TABLE "config_$*" ($(field));' \
	'INSERT INTO "config_$*" ($(insfield)) VALUES ($(vals));' \
	'CREATE TABLE "fastq_$*" AS SELECT * FROM fastqs NATURAL JOIN "config_$*" ;'; \
	$(SQLITE) -header -csv  samples.db 'SELECT $(samplesheet_id_column) AS sample, fastq_1, fastq_2, strandedness FROM "fastq_$*";' > $@

$(configs) : %.config : ../ingress/%.config
	cp $< $@

samples.db: ../ingress/samples.db
	cp $< $@

log:
	mkdir $@
clean: ## Remove working files from scratch
	rm -rf $(SCRATCH_DIR)nf_work
	rm -f nf_work

run-clean:

build-clean:  ## Remove files only needed for re-`run`ning. Downstream steps will still work if `run` has already completed.
	rm -f $(samplesheets)
	rm -f samples.db


clean-complete: clean-build ## Complete reset. Donwstream steps will no `build` (and perhaps might not even run even if they've already been built.)
	rm -rf results/$(alignments)
