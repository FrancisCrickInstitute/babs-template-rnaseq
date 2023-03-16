include ../system.mk
include local.mk

.PHONY: run build copy publish clean run-clean build-clean

run: samples.db ## Generate a database of samples for downstream convenience

samples.db: $(samplesheet_fname).csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs" \
	"ALTER TABLE fastqs ADD COLUMN _babs_config_file text;"



################################################################
#### Bootrap all relevant data from outside
################################################################

configs:= $(patsubst ../docs/%.config,%.config,$(wildcard ../docs/*.config))

build: $(configs) $(samplesheet_fname).csv ## Prepare for `run` by gathering configs and samplesheet into current directory


$(samplesheet_fname).csv: ../docs/$(samplesheet_fname).csv
	cp $< $@

$(configs): %.config: ../docs/%.config
	cp $< $@
	sed -i 's/^/$*./' $@

copy:

publish:

clean:

run-clean:
	rm -f samples.db

build-clean:
	rm -f $(patsubst ../docs/%.config, %.config, $(wildcard ../docs/*.config))
	rm -f $(patsubst ../docs/$(samplesheet_fname).csv, $(samplesheet_fname).csv, $(wildcard ../docs/$(samplesheet_fname).csv))
