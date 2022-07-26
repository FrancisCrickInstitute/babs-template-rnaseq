include ../global.mk
-include ../ingress/*.config

.PHONY: run build

run: run_stefan_script


$(V).SILENT:




################################################################
#### Bootrap all relevant data from outside
################################################################

build: result_txt tpms
	make -n -s all > run.sh

alignments := $(patsubst ../differential/data/counts_%.rda,%,$(wildcard ../differential/data/counts_*.rda))
specfiles := $(patsubst ../differential/%.spec,%,$(wildcard ../differential/*.spec))
result_objs := $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),../differential/data/$(spec)_x_$(alignment).dda))

result_txt := $(patsubst ../differential/data/%.dda,inputs/%,$(result_objs))
.PHONY:result_txt $(result_txt)
result_txt: $(result_txt)
$(result_txt): inputs/%: ../differential/data/%.rds
	mkdir -p $@
	$(R) -e 'library(DESeq2); library(DESdemonA); DESdemonA::export_biologics(result_object="$<", path="$@")'


.PHONY:tpms
tpms: $(patsubst %,inputs/%.gene_tpm.tsv,$(alignments)) $(patsubst %,inputs/%.transcript_tpm.tsv,$(alignments))

inputs/%.gene_tpm.tsv:../nfcore/results/%/star_rsem/rsem.merged.gene_tpm.tsv
	cp $< $@

inputs/%.transcript_tpm.tsv:../nfcore/results/%/star_rsem/rsem.merged.transcript_tpm.tsv
	cp $< $@

print-%: ; @echo $*=$($*)
