include ../config/global.mk
-include *.config

.PHONY: run build copy publish clean

run: samplesheets | run.sh

.PHONY: samplesheets
samplesheets:= $(patsubst %.config,samplesheet_%.csv,$(wildcard *.config))
samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: %.config samples.db
	if [ "$($*.ended)" == "single" ]; then \
	$(SQLITE) -header -csv  samples.db 'SELECT $(label_column) AS sample, file AS fastq_1, NULL AS fastq_2, "$($*.stranded)" AS strandedness FROM fastqs WHERE species="$($*.species)" AND type="$($*.type)";' > $@ ;\
	$(SQLITE) samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE species="$($*.species)" AND type="$($*.type)";' ;\
	vals='$(shell sed '/^$$/d; s/=/","/; s/^$*./("/; s/$$/)"/' "$*".config  | paste -sd ',')' ;\
	$(SQLITE) samples.db "DROP TABLE IF EXISTS '$*';" ;\
	$(SQLITE) samples.db "CREATE TABLE '$*' (id TEXT PRIMARY KEY, value TEXT); INSERT INTO '$*' (id,value) VALUES $${vals};" ;\
	fi

################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build

build: configs samples.db
	make -n -s run > run.sh

samples.db: ../docs/asf_samplesheet.csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs"
	$(SQLITE) $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"


.PHONY: configs 
configs:= $(patsubst ../docs/%.config,%.config,$(wildcard ../docs/*.config))
configs: $(configs)

$(configs): %.config: ../docs/%.config
	cp $< $@
	sed -i 's/^/$*./' $@

copy:

publish:

clean:
	rm -f run.sh samples.db *.config 
