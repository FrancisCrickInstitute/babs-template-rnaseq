include ../config/global.mk
nf_cache_dir := /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.4/
include ../config/*.config

alignments:= $(patsubst ../config/%.config,%,$(wildcard ../config/*.config))
alignments: results/nfcore/$(alignments)

../results/$(alignments)/nfcore : ../results/%/nfcore : samplesheet_%.csv
	mkdir -p ../results/$*/nfcore
	cp ../config/$*.config .
	ml purge ;\
	ml Nextflow/21.10.3 ;\
	ml Singularity/3.4.2 ;\
	ml CAMP_proxy ;\
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	nextflow run nf-core/rnaseq \
	--input $< \
	--outdir ../results/$*/nfcore/ \
	--aligner star_rsem \
	--genome "$($*.genome)" \
	-w "${nf_work}" \
	-profile crick \
	-resume \
	-with-tower \
	-r 3.4


samplesheets:= $(patsubst ../config/%.config,samplesheet_%.csv,$(wildcard ../config/*.config))
samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: ../config/%.config samples.db
	if [ "$($*.ended)" == "single" ]; then \
	sqlite3 -header -csv  samples.db 'SELECT $(label_column) AS sample, file AS fastq_1, NULL AS fastq_2, "$($*.stranded)" AS strandedness FROM fastqs WHERE species="$($*.species)" AND type="$($*.type)";' > $@ ;\
	sqlite3 samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE species="$($*.species)" AND type="$($*.type)";' ;\
	fi

samples.db: $(global_docs_dir)/asf_samplesheet.csv
	rm -f $@
	rm -f *.config
	sqlite3 $@ -csv ".import $< fastqs"
	sqlite3 $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"

