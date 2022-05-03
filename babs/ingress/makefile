include ../config/global.mk
include local.mk
-include *.config

.PHONY: run build copy publish clean

run: samples.db | run.sh ## Generate a database of samples for downstream convenience

samples.db: $(samplesheet_fname).csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs"
	$(SQLITE) $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"



################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build

build: configs $(samplesheet_fname).csv ## Prepare for `run` by gathering configs and samplesheet into current directory
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
