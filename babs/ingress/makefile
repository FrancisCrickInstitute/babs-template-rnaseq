include ../config/global.mk
include local.mk
-include *.config

.PHONY: run build copy publish clean

run: samples.db | run.sh

samples.db: $(samplesheet_fname).csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs"
	$(SQLITE) $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"



################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build

build: configs $(samplesheet_fname).csv
	make -n -s run > run.sh

$(samplesheet_fname).csv: ../docs/$(samplesheet_fname).csv
	cp $< &@

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
