include ../config/global.mk
-include *.config

.PHONY: all bootstrap

all: samplesheets

.PHONY: samplesheets
samplesheets:= $(patsubst %.config,samplesheet_%.csv,$(wildcard *.config))
samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: %.config samples.db
	if [ "$($*.ended)" == "single" ]; then \
	sqlite3 -header -csv  samples.db 'SELECT $(label_column) AS sample, file AS fastq_1, NULL AS fastq_2, "$($*.stranded)" AS strandedness FROM fastqs WHERE species="$($*.species)" AND type="$($*.type)";' > $@ ;\
	sqlite3 samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE species="$($*.species)" AND type="$($*.type)";' ;\
	fi

################################################################
#### Bootrap all relevant data from outside
################################################################

bootstrap: configs samples.db
	make -n -s > bootstrap.sh

samples.db: ../docs/asf_samplesheet.csv
	rm -f $@
	sqlite3 $@ -csv ".import $< fastqs"
	sqlite3 $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"


configs:= $(patsubst ../docs/%.config,%.config,$(wildcard ../docs/*.config))
configs: $(configs)

$(configs): %.config: ../docs/%.config
	cp $< $@
	sed -i 's/^/$*./' $@
