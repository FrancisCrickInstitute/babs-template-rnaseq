include ../config/global.mk
include ../config/*.config

samplesheets:= $(patsubst ../config/%.config,samplesheet_%.csv,$(wildcard ../config/*.config))
samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: ../config/%.config samples.db
	if [ "$($*.ended)" == "single" ]; then \
	sqlite3 -header -csv  samples.db 'SELECT $(label_column) AS sample, file AS fastq_1, NULL AS fastq_2, "$($*.stranded)" AS strandedness FROM fastqs WHERE species="$($*.species)" AND type="$($*.type)";' > $@ ;\
	sqlite3 samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE species="$($*.species)" AND type="$($*.type)";' ;\
	fi

samples.db: ../docs/asf_samplesheet.csv
	rm -f $@
	rm -f *.config
	sqlite3 $@ -csv ".import $< fastqs"
	sqlite3 $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"


bootstrap.sh:
	make -n -s > $@
