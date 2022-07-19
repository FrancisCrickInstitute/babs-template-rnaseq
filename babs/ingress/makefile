include ../config/global.mk
-include *.config

.PHONY: run build clean

run: samples.db  ## Generate a database of samples for downstream convenience

samples.db: $(samplesheet_fname).csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs"
	$(SQLITE) $@ "ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"



################################################################
#### Bootrap all relevant data from outside
################################################################
configs = $(patsubst ../docs/%.config,%.config,$(wildcard ../docs/*.config))

build: $(samplesheet_fname).csv $(configs) ## Prepare for `run` by gathering configs and samplesheet into current directory
	make -n -s run > run.sh

$(samplesheet_fname).csv: ../docs/$(samplesheet_fname).csv
	cp $< $@

$(configs): %.config: ../docs/%.config
	cp $< $@
	sed -i 's/^/$*./' $@


clean:
	rm -f run.sh samples.db *.config 
