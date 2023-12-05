secrets : $(wildcard ../secrets)
	if [ -f ../secrets ]; then cp $< $@; else touch $@; fi

global.mk: $(wildcard ../global.mk)
	if [ -f ../global.mk ]; then cp $< $@; else touch $@; fi

include secrets
include global.mk
include local.mk

.PHONY: run build copy publish clean run-clean build-clean

run: samples.db ## Generate a database of samples for downstream convenience

samples.db: $(samplesheet_fname).csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs" \
	"ALTER TABLE fastqs ADD COLUMN config_file text;" \
	"ALTER TABLE fastqs ADD COLUMN universal text;" \
	"UPDATE fastqs SET universal='yes';"



################################################################
#### Bootrap all relevant data from outside
################################################################

configs:= $(patsubst ../docs/%.config,%.config,$(wildcard ../docs/*.config))

build: $(configs) $(samplesheet_fname).csv $(experiment_table).csv ## Prepare for `run` by gathering configs and samplesheet into current directory

$(experiment_table).csv: ../docs/$(experiment_table).csv
	tr -d '\r' < $< > $@

$(samplesheet_fname).csv: ../docs/$(samplesheet_fname).csv
	tr -d '\r' < $< > $@

$(configs): %.config: ../docs/%.config
	tr -d '\r' < $< > $@
	grep -q "^universal" $@ || sed -i -e '$$auniversal=yes' $@
	grep -q "^strandedness" $@ || sed -i -e '$$astrandedness=auto' $@
	sed -i 's/^/$*./' $@

copy:

publish:

clean:

run-clean:
	rm -f samples.db

build-clean:
	rm -f $(patsubst ../docs/%.config, %.config, $(wildcard ../docs/*.config))
	rm -f $(patsubst ../docs/$(samplesheet_fname).csv, $(samplesheet_fname).csv, $(wildcard ../docs/$(samplesheet_fname).csv))
