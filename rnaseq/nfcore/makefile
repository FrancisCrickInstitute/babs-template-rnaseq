nf_cache_dir := /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.4/
label_column := sample # which column from the ASF csv to use in nf-core.  Maybe sample_name

include ../docs/*.config

samplesheets := $(patsubst ../docs/%.config,samplesheet_%.csv,$(wildcard ../docs/*.config))
alignments := $(patsubst ../docs/%.config,results/%/nfcore,$(wildcard ../docs/*.config))

alignments: $(alignments)

$(alignments) : results/nfcore/% : samplesheet_%.csv
	mkdir -p results/$*/nfcore
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




samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: ../docs/%.config | samples.db
	if [ "$($*.ended)" == "single" ]; then \
	sqlite3 -header -csv  samples.db 'SELECT $(label_column) AS sample, file AS fastq_1, NULL AS fastq_2, "$($*.stranded)" AS strandedness FROM fastqs WHERE species="$($*.species)" AND type="$($*.type)";' > $@ ;\
	sqlite3 samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE species="$($*.species)" AND type="$($*.type)";' ;\
	fi

samples.db: ../docs/asf_samplesheet.csv
	rm -f $@
	sqlite3 $@ -csv ".import $< fastqs"
	sqlite3 $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"
