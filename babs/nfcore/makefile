include ../config/global.mk
include ../config/*.config

alignments:= $(patsubst ../ingress/samplesheet_%.csv,%,$(wildcard ../ingress/samplesheet_*.csv))
alignments: results/nfcore/$(alignments)

results/$(alignments)/nfcore : ../results/%/nfcore : samplesheet_%.csv
	mkdir -p results/$*
	cp ../config/$*.config .
	ml purge ;\
	ml Nextflow/21.10.3 ;\
	ml Singularity/3.4.2 ;\
	ml CAMP_proxy ;\
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	nextflow run nf-core/rnaseq \
	--input $< \
	--outdir results/$*/ \
	--aligner star_rsem \
	--genome "$($*.genome)" \
	-w "${nf_work}" \
	-profile crick \
	-resume \
	-with-tower \
	-r 3.4
