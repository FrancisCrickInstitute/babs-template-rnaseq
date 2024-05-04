.DEFAULT_GOAL=help

template_dir := /nemo/stp/babs/working/bioinformatics/templates

type = rnaseq

ifndef version
version = $(shell git describe --tags --abbrev=0)
defaultVersion=true
endif

################################################################
#### Everything below should be kept as-is
################################################################

.PHONY: deploy

deploy: $(template_dir)/archive ## Copy all controlled files, except .git folder and things in .gitattributes, into area where tickets and pipeline can see it. Setting `version=dev` will put it into the archive (where it can be retrieved) but not into the default area
	git archive --format=tar.gz HEAD  > $(type)-$(version).tar.gz
ifeq ($(defaultVersion),true)
	cp $(type)-$(version).tar.gz $(template_dir)/$(type).tar.gz
endif
	mv $(type)-$(version).tar.gz $(template_dir)/archive/$(type)-$(version).tar.gz



$(template_dir)/archive $(template_dir)/$(type):
	mkdir -p $@

ena=005/SRR1039515/SRR1039515_1 006/SRR1039516/SRR1039516_1 004/SRR1039514/SRR1039514_1 003/SRR1039513/SRR1039513_1 009/SRR1039519/SRR1039519_2 007/SRR1039517/SRR1039517_2 006/SRR1039516/SRR1039516_2 000/SRR1039520/SRR1039520_1 001/SRR1039521/SRR1039521_1 002/SRR1039522/SRR1039522_1 000/SRR1039510/SRR1039510_2 008/SRR1039518/SRR1039518_2 005/SRR1039515/SRR1039515_2 001/SRR1039511/SRR1039511_2 008/SRR1039508/SRR1039508_1 009/SRR1039509/SRR1039509_1 004/SRR1039514/SRR1039514_2 003/SRR1039513/SRR1039513_2 002/SRR1039512/SRR1039512_2 003/SRR1039523/SRR1039523_1 000/SRR1039510/SRR1039510_1 001/SRR1039511/SRR1039511_1 009/SRR1039519/SRR1039519_1 008/SRR1039508/SRR1039508_2 002/SRR1039512/SRR1039512_1 009/SRR1039509/SRR1039509_2 007/SRR1039517/SRR1039517_1 003/SRR1039523/SRR1039523_2 000/SRR1039520/SRR1039520_2 002/SRR1039522/SRR1039522_2 001/SRR1039521/SRR1039521_2 008/SRR1039518/SRR1039518_1



airway/fastq:
	mkdir -p $@
	cd @$; for i in ${ena}; do wget -nc ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR103/$$i.fastq.gz ; done

airway/nfcore.tar.gz: | test ## Cache the nfcore results for future speed
	cd test/nfcore &&\
	make run &&\
	tar -czf ../../$@ samplesheet_GRCh38.csv samples.db GRCh38.config results/GRCh38/multiqc results/GRCh38/star_rsem/*.genes.results results/GRCh38/star_rsem/rsem.merged.gene_counts.tsv


test: airway/fastq ## Generate a test folder setup for the airway data
	mkdir -p $@/babs
	rsync -av  babs/. $@/babs/. --exclude '.~' --exclude 'docs'
	cd $@ && git init
	cd $@/babs && \
	ln -s ../../airway/fastq fastq && \
	cp -r ../../airway/docs . 
	git add makefile && \
	git commit -m "Restart git repo for testing" && \
	git tag v9.9.9

.PHONY: test-nfcore
test-nfcore: test/babs/nfcore/results ## Fast-forward to before the differential analysis, by using a cached run of nfcore

test/babs/nfcore/results:  test | airway/nfcore.tar.gz
	cd test/babs/ingress && make run
	cd test/babs/nfcore && tar -xzf ..././../airway/nfcore.tar.gz


help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
MAKEFLAGS += --no-builtin-rules
