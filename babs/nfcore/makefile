include ../config/global.mk
include local.mk
-include ../config/*.config

#alignments:= $(patsubst samplesheet_%.csv,%,$(wildcard samplesheet_*.csv))
alignments:= $(patsubst ../ingress/samplesheet_%.csv,%,$(wildcard ../ingress/samplesheet_*.csv))
alignments: results/$(alignments)


results/$(alignments) : results/% : ../ingress/samplesheet_%.csv
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


bootstrap: 
	make -n -s > bootstrap.sh

samplesheets:= $(patsubst ../ingress/samplesheet_%.csv,%.csv,$(wildcard ../ingress/samplesheet_*.csv))
samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: ../ingress/samplesheet_%.csv
	cp $< $@
