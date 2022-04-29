include ../config/global.mk
include local.mk
-include *.config

.PHONY: run build copy publish clean

run: samplesheets | run.sh

.PHONY: samplesheets
samplesheets:= $(patsubst %.config,samplesheet_%.csv,$(wildcard *.config))
samplesheets: $(samplesheets)

$(samplesheets): samplesheet_%.csv: %.config samples.db
	$(SQLITE) samples.db "DROP TABLE IF EXISTS 'config_$*';"
	field='$(shell sed '/^$$/d; s/^$*./"/;s/=.*/" TEXT/' "$*.config" | paste -sd ',')' ;\
	insfield='$(shell sed '/^$$/d; s/^$*./"/;s/=.*/"/' "$*.config" | paste -sd ',')' ;\
	vals='$(shell sed -r '/^$$/d; s/.*=(.*)/"\1"/' "$*.config" | paste -sd ',')' ;\
	$(SQLITE) samples.db 'CREATE TABLE "config_$*" ($${field}); INSERT INTO "$*" ($${insfield}) VALUES $${vals}'
	$(SQLITE) -header -csv  samples.db 'SELECT fastqs.$(samplesheet_id_column) AS sample, fastqs.*, "config_$*".* FROM fastqs NATURAL JOIN "config_$*" ;' > $@ 
	$(SQLITE) samples.db 'UPDATE fastqs SET _babs_config_file="$*" WHERE fastqs.$(samplesheet_id_column) IN (SELECT $(samplesheet_id_column) FROM fastqs NATURAL JOIN "config_$*" ;'


################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build

build: configs samples.db
	make -n -s run > run.sh

samples.db: ../docs/$(samplesheet_fname).csv
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
