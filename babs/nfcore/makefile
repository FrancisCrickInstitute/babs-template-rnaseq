include ../config/global.mk
include local.mk
-include ../ingress/*.config

.PHONY: run build copy publish clean

run: alignments

.PHONY: alignments
alignments:= $(patsubst samplesheet_%.csv,%,$(wildcard samplesheet_*.csv))
alignments: results/$(alignments)


results/$(alignments) : results/% : samplesheet_%.csv
	mkdir -p $@
	ml purge ;\
	ml Nextflow/21.10.3 ;\
	ml Singularity/3.4.2 ;\
	ml CAMP_proxy ;\
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	nextflow run nf-core/rnaseq \
	--input $< \
	--outdir $@/ \
	--aligner star_rsem \
	--genome "$($*.genome)" \
	-w "${nf_work}" \
	-profile crick \
	-resume \
	-with-tower \
	-r 3.4

################################################################
#### Bootrap all relevant data from outside
################################################################

build: samplesheets
	make -n -s run > run.sh

.PHONY: samplesheets
samplesheets = $(patsubst ../ingress/samplesheet_%.csv,samplesheet_%.csv,$(wildcard ../ingress/samplesheet_*.csv))
samplesheets: $(samplesheets)
$(samplesheets): samplesheet_%.csv: ../ingress/samplesheet_%.csv
	cp $< $@
