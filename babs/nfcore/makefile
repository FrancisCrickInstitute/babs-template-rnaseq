include ../config/global.mk
include local.mk
-include ../ingress/*.config

.PHONY: run build clean

run: alignments ## Generate NF-CORE alignments, one folder for each config-specific samplesheet from the `build` process.

.PHONY: alignments
alignments:= $(patsubst samplesheet_%.csv,%,$(wildcard samplesheet_*.csv))
alignments: results/$(alignments)


results/$(alignments) : results/% : samplesheet_%.csv
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

build: samplesheets ## Build all necessary inputs: samplesheets for each matching alignment '.config' from 'docs'.
	mkdir -p ${nf_work}
	ln -sf ${nf_work} nf_work
	make -n -s run > run.sh



.PHONY: samplesheets
samplesheets:= $(patsubst ../ingress/%.config,samplesheet_%.csv,$(wildcard ../ingress/*.config))
samplesheets: $(samplesheets)


field=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/" TEXT/' "../ingress/$*.config" | paste -sd ',')
insfield=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/"/' "../ingress/$*.config" | paste -sd ',')
vals=$(shell sed -r '/^$$/d; s/.*=(.*)/"\1"/' "../ingress/$*.config" | paste -sd ',')
$(samplesheets): samplesheet_%.csv: ../ingress/%.config | samples.db
	$(SQLITE) samples.db "DROP TABLE IF EXISTS 'config_$*';"
	$(SQLITE) samples.db 'CREATE TABLE "config_$*" ($(field));' 
	$(SQLITE) samples.db 'INSERT INTO "config_$*" ($(insfield)) VALUES ($(vals));' 
	$(SQLITE) -header -csv  samples.db 'SELECT * FROM fastqs NATURAL JOIN "config_$*" ;' > $@ 
	$(SQLITE) samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE fastqs.$(samplesheet_id_column) IN (SELECT $(samplesheet_id_column) FROM fastqs NATURAL JOIN "config_$*") ;'

samples.db: ../ingress/samples.db
	cp $< $@

clean: ## Remove working files from scratch
	rm -rf ${nf_work}
	rm -f nf_work

clean-build: clean ## Remove files only needed for re-`run`ning. Downstream steps will still work if `run` has already completed.
	rm -f $(samplesheets)
	rm -f samples.db

clean-complete: clean-build ## Complete reset. Donwstream steps will no `build` (and perhaps might not even run even if they've already been built.)
	rm -rf results/$(alignments)
