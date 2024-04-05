include shared.mk

.PHONY: run build copy publish clean run-clean build-clean

run: ${samples_db} ## Generate a database of samples for downstream convenience

${samples_db}: $(samplesheet_fname).csv
	rm -f $@
	$(SQLITE) $@ -csv ".import $< fastqs" \
	"ALTER TABLE fastqs ADD COLUMN config_file text;" \
	"ALTER TABLE fastqs ADD COLUMN universal text;" \
	"UPDATE fastqs SET universal='yes';"



################################################################
#### Bootrap all relevant data from outside
################################################################

configs = $(patsubst %,%.config,$(alignments))
ifeq (,$(filter $(excluded-targets),$(MAKECMDGOALS)))
ifneq (,$(excluded-targets))
include ${configs}
endif
endif


build: $(configs) $(samplesheet_fname).csv $(experiment_table).csv ## Prepare for `run` by gathering configs and samplesheet into current directory

ifneq (${docs_dir},)
$(docs_dir)/%:
	$(MAKE)  --no-print-directory -C ${docs_dir} $*

$(configs): %.config: $(docs_dir)/%.config
	cp $< $@
	tr -d '\r' < $< > $@
	grep -q "^universal" $@ || sed -i -e '$$auniversal=yes' $@
	grep -q "^strandedness" $@ || sed -i -e '$$astrandedness=auto' $@
	sed -i 's/^/$*./' $@
$(samplesheet_fname).csv: ${docs_dir}/$(samplesheet_fname).csv
	cp $< $@
	tr -d '\r' < $< > $@
$(experiment_table).csv:  $(docs_dir)/$(experiment_table).csv
	cp $< $@
	tr -d '\r' < $< > $@
endif

copy:

publish:

clean:

run-clean:
	rm -f ${samples_db}

build-clean:
	rm -f $(patsubst ../docs/%.config, %.config, $(wildcard ../docs/*.config))
	rm -f $(patsubst ../docs/$(samplesheet_fname).csv, $(samplesheet_fname).csv, $(wildcard ../docs/$(samplesheet_fname).csv))

# Originally, shared.mk comes from the parent directory. Copy it here
# if necessary and applicable:
ifneq ($(wildcard ../shared.mk),)
shared.mk: ../shared.mk
	cp $< $@
endif
