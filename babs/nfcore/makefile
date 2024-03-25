include shared.mk
include module.mk

.PHONY: run build copy publish clean
built_samplesheets=$(patsubst samplesheet_%.csv, %,$(wildcard samplesheet_*.csv))
include $(patsubst %,%.config,$(built_samplesheets))

alignments = $(patsubst %,results/%/star_rsem/rsem.merged.gene_counts.tsv,$(built_samplesheets))
refdir = $(realpath $($*.index_dir)/$($*.genome_fasta_md5)/$($*.gtf_md5))
workdir = $(SCRATCH_DIR)nf_work/

run: $(alignments) ## Generate NF-CORE alignments, one folder for each config-specific samplesheet from the `build` process.

$(alignments) : results/%/star_rsem/rsem.merged.gene_counts.tsv : samplesheet_%.csv | $(log_dir) $(workdir)
	mkdir -p results/$*
	export NXF_SINGULARITY_CACHEDIR="$(NXF_SINGULARITY_CACHEDIR)" ;\
	export NXF_SINGULARITY_LIBRARYDIR="$(NXF_SINGULARITY_CACHEDIR)" ;\
	export NXF_HOME=$(CURDIR) ;\
	args=();\
	if [ -n "$($*.index_dir)" ];\
	  then if [ -d "$(refdir)" ];\
	    then args+=(--rsem_index=$(refdir)/rsem/  --salmon_index=$(refdir)/salmon/) ;\
	    else  args+=(--save_reference);\
	  fi ;\
	fi ;\
	set -o pipefail ;\
	$(NEXTFLOW) run nf-core/rnaseq \
	--input $< \
	--outdir results/$*/ \
	--aligner star_rsem \
	--fasta $(realpath $($*.genome_fasta)) \
	--gtf $(realpath $($*.gtf)) \
	-w $(workdir) \
	-ansi-log false \
	"$${args[@]}" \
	$(or $($*.nfcore),$(nf_options)) $(call log,nfcore)
	if [ -n "$($*.index_dir)" ] && [ ! -d "$(refdir)" ];\
	    then mkdir -p "$(refdir)" && mv results/$*/genome/index/* "$(refdir)"/;\
	fi
	$(NEXTFLOW) clean -f

$(workdir):
	mkdir -p $(workdir)




################################################################
#### Bootrap all relevant data from outside
################################################################
configs = $(patsubst $(ingress_dir)/%.config,%.config,$(wildcard $(ingress_dir)/*.config))
samplesheets = $(patsubst %.config,samplesheet_%.csv,$(configs))

build: $(samplesheets) ## Build all necessary inputs: samplesheets for each matching alignment '.config' from 'docs'.
	$(GIT) add module.mk shared.mk makefile .gitignore $(samplesheets) $(configs)
	$(GIT) commit -m "Add nfcore build-files" || true


field=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/" TEXT/' "$*.config" | paste -sd ',')
insfield=$(shell sed '/^$$/d; s/^$*./"/;s/=.*/"/' "$*.config" | paste -sd ',')
vals=$(shell sed -r '/^$$/d; s/.*=(.*)/"\1"/' "$*.config" | paste -sd ',')

$(samplesheets): samplesheet_%.csv: %.config  ${samples_db}
	$(SQLITE) ${samples_db} 'DROP TABLE IF EXISTS "config_$*";' \
	'CREATE TABLE "config_$*" ($(field));' \
	'INSERT INTO "config_$*" ($(insfield)) VALUES ($(vals));' \
	'CREATE TABLE "fastq_$*" AS SELECT * FROM fastqs NATURAL JOIN "config_$*" ;'; \
	$(SQLITE) -header -csv  ${samples_db} 'SELECT $(samplesheet_id_column) AS sample, fastq_1, fastq_2, strandedness FROM "fastq_$*";' > $@

$(configs) : %.config : $(ingress_dir)/%.config
	cp $< $@
	md5sum $(shell sed -n 's/^$*.genome_fasta=//p' $<) | awk '{print "$*.genome_fasta_md5=" $$1}' >> $@
	md5sum $(shell sed -n 's/^$*.gtf=//p' $<) | awk '{print "$*.gtf_md5=" $$1}' >> $@

${samples_db}: $(ingress_dir)/${samples_db}
	cp $< $@

$(log_dir):
	mkdir -p $@

location=outputs
shortcut=$(empty)
ifdef redirect_$(location)
shortcut=shortcuts/
endif
pubdir = $(shortcut)$(publish_$(location))
ifeq ($(pubdir),)
pubdir = published
endif
publish:  ## Copy results to final location. Either 'outputs' folder (default), intranet (`make publish location=intranet`) or inte\
rnet
ifdef redirect_$(location)
	mkdir -p $(redirect_$(location))
	mkdir -p $(shortcut)
ifdef url_$(location)
	echo "[InternetShortcut]" > $(shortcut)$(location).url
	echo "URL=$(url_$(location))/latest" >> $(shortcut)$(location).url
endif
	ln -sfn $(redirect_$(location)) $(pubdir)
endif
	for i in $(built_samplesheets); do \
	  mkdir -p "$(pubdir)/$(VERSION)/$$i" ;\
	  cp --no-preserve=mode -r results/"$$i"/star_rsem/*.markdup.sorted.bam "$(pubdir)/$(VERSION)/$$i" ;\
	  cp --no-preserve=mode -r results/"$$i"/star_rsem/*.markdup.sorted.bam.bai "$(pubdir)/$(VERSION)/$$i" ;\
	done
	ln -sfn $(VERSION) $(pubdir)/latest

clean: ## Remove working files from scratch
	rm -rf $(SCRATCH_DIR)nf_work
	rm -f nf_work

run-clean:

build-clean:  ## Remove files only needed for re-`run`ning. Downstream steps will still work if `run` has already completed.
	rm -f $(samplesheets)
	rm -f ${samples_db}


clean-complete: clean-build ## Complete reset. Donwstream steps will no `build` (and perhaps might not even run even if they've already been built.)
	rm -rf results/$(alignments)

# Originally, shared.mk comes from the parent directory. Copy it here
# if necessary and applicable:
ifneq ($(wildcard ../shared.mk),)
shared.mk: ../shared.mk
	cp $< $@
endif
