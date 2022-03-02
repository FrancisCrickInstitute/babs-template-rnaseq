include ../config/global.mk
include local.mk
-include ../ingress/*.config

.PHONY: run build copy publish clean

run: alignments | run.sh

.PHONY: alignments
alignments:= $(patsubst samplesheet_%.csv,%,$(wildcard samplesheet_*.csv))
alignments: results/$(alignments)


results/$(alignments) : results/% : samplesheet_%.csv
	mkdir -p $@
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	$(NEXTFLOW) run nf-core/rnaseq \
	--input $< \
	--outdir $@/ \
	--aligner star_rsem \
	--fasta "$($*.genome_fasta)" \
	--gtf "$($*.gtf)" \
	-w "${nf_work}" \
	-profile crick \
	-resume \
	-with-tower \
	-r 3.4

################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build

build: samplesheets
	mkdir -p ${nf_work}
	ln -sf ${nf_work} nf_work
	make -n -s run > run.sh

.PHONY: samplesheets
samplesheets = $(patsubst ../ingress/samplesheet_%.csv,samplesheet_%.csv,$(wildcard ../ingress/samplesheet_*.csv))
samplesheets: $(samplesheets)
$(samplesheets): samplesheet_%.csv: ../ingress/samplesheet_%.csv
	cp $< $@


clean:
	rm -rf ${nf_work}
	rm -f nf_work
