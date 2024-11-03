ingress_dir=.
include shared.mk

.PHONY: run build copy publish clean run-clean build-clean

run: build ## Move relevant 'docs' files here and tidy them up as necessary.



################################################################
#### Bootrap all relevant data from outside
################################################################

configs = $(patsubst %,%.config,$(alignments))
ifneq (,$(filter-out $(or $(excluded-targets),$(MAKECMDGOALS)),$(MAKECMDGOALS)))
include $(configs)
endif


build: $(samplesheet_fname).csv $(experiment_table).csv


ifneq ($(docs_dir),)
$(docs_dir)/%:
	$(MAKE) --no-print-directory -C $(docs_dir) $*

$(configs): %.config: $(docs_dir)/%.config
	tr -d '\r' < $< | sed  's/^$*\.//' > $@
	grep -q "^genome_fasta" $@ || echo "WARNING: No genome_fasta set in $*.config"
	grep -q "^gtf" $@ || echo "WARNING: No gtf set in $*.config"
	grep -q "^universal" $@ || sed -i -e '$$auniversal=yes' $@
	grep -q "^strandedness" $@ || sed -i -e '$$astrandedness=auto' $@
	grep -q "^aligner" $@ || sed -i -e '$$aaligner=star_rsem' $@
	md5sum $(shell sed -n 's/^genome_fasta=//p' $<) | awk '{print "genome_fasta_md5=" $$1}' >> $@
	md5sum $(shell sed -n 's/^gtf=//p' $<) | awk '{print "gtf_md5=" $$1}' >> $@
	sed -i 's/^/$*./' $@
	$(GIT) add $@ $<

$(samplesheet_fname).csv: $(docs_dir)/$(samplesheet_fname).csv
	cp $< $@
	tr -d '\r' < $< > $@
	$(GIT) add $@ $<

$(experiment_table).csv:  $(docs_dir)/$(experiment_table).csv
	cp $< $@
	tr -d '\r' < $< > $@
	$(GIT) add $@ $< 
endif

copy:

publish:

clean:

run-clean:

build-clean:
	rm -f $(patsubst ../docs/%.config, %.config, $(wildcard ../docs/*.config))
	rm -f $(patsubst ../docs/$(samplesheet_fname).csv, $(samplesheet_fname).csv, $(wildcard ../docs/$(samplesheet_fname).csv))

# Originally, shared.mk comes from the parent directory. Copy it here
# if necessary and applicable:
ifneq ($(wildcard ../shared.mk),)
shared.mk: ../shared.mk
	cp $< $@
endif
