include shared.mk

.PHONY: run copy publish clean run-clean build-clean

configs=$(patsubst $(docs_dir)/%.config,%.config,$(wildcard $(docs_dir)/*.config))
samplesheets=$(patsubst %.config,%.csv,$(configs))

run: $(samplesheets) $(experiment_table).csv $(configs) ## Move relevant 'docs' files here and tidy them up as necessary.

$(samplesheets) : % : $(docs_dir)/%
	cp $< $@
	tr -d '\r' < $< > $@
	$(GIT) add $@ $<

$(experiment_table).csv:  $(docs_dir)/$(experiment_table).csv
	cp $< $@
	tr -d '\r' < $< > $@
	$(GIT) add $@ $< 

$(configs): %.config: $(docs_dir)/%.config
	tr -d '\r' < $<  > $@
	grep -q "^genome_fasta" $@ || echo "WARNING: No genome_fasta set in $*.config"
	grep -q "^gtf" $@ || echo "WARNING: No gtf set in $*.config"
	grep -q "^universal" $@ || echo 'universal=yes'>> $@
	grep -q "^strandedness" $@ || echo 'strandedness=auto' >> $@
	grep -q "^aligner" $@ || echo 'aligner=star_rsem'>> $@
	md5sum $(shell sed -n 's/^genome_fasta=//p' $<) | awk '{print "genome_fasta_md5=" $$1}' >> $@
	md5sum $(shell sed -n 's/^gtf=//p' $<) | awk '{print "gtf_md5=" $$1}' >> $@
	$(GIT) add $@ $<

$(docs_dir)/%:
	$(MAKE) --no-print-directory -C $(docs_dir) $*

copy:

publish:

clean:

run-clean:

build-clean:
	rm -f $(configs) $(samplesheets) $(experiment_table).csv
