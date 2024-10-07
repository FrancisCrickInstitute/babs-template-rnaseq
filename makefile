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


airway/fastq: airway/ena.txt
	mkdir -p $@
	while read i; do wget -P $@ -nc ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR103/$$i.fastq.gz ; done < $<

airway/nfcore.tar.gz: | test ## Cache the nfcore results for future speed
	cd test/nfcore &&\
	make run &&\
	tar -czf ../../$@ samplesheet_GRCh38.csv samples.db GRCh38.config results/GRCh38/multiqc results/GRCh38/star_rsem/*.genes.results results/GRCh38/star_rsem/rsem.merged.gene_counts.tsv


test: airway/fastq ## Generate a test folder setup for the airway data
	mkdir -p $@/babs
	touch $@/.babs
	rsync -av  babs/. $@/babs/. --exclude '.~' --exclude 'docs'
	( cd $@ && git init )
	( cd $@/babs && \
	ln -s ../../airway/fastq fastq && \
	cp -r ../../airway/docs . && \
	if [ -n "$(aligner)" ]; then echo "aligner=$(aligner)" >> docs/GRCh38.config; fi && \
	cp    ../../babs/docs/makefile ../../babs/docs/readme.md ../../babs/docs/.gitignore docs/ && \
	git add makefile &&  \
	git commit -m "Restart git repo for testing" && \
	git tag v9.9.9 )

.PHONY: test-ff-nfcore test-differential
test-ff-nfcore: test/babs/nfcore/results ## Fast-forward to before the differential analysis, by using a cached run of nfcore

test-differential: test/babs/nfcore/results
	( cd test/babs/differential; make run )

test/babs/nfcore/results:  test | airway/nfcore.tar.gz
	( cd test/babs/ingress; make run )
	( cd test/babs/nfcore && tar -xzf ../../../airway/nfcore.tar.gz )

.PHONY: pkgdown
pkgdown: 
	( cd $@; make site )

major minor patch: lastNews=$(shell sed -n '1s/# Version //p' pkgdown/NEWS.md)
major minor patch: lastTag:=$(subst ., ,$(patsubst v%,%,$(shell git describe --tags --abbrev=0 --match 'v*')))
major minor patch: major=$(word 1,$(lastTag))
major minor patch: minor=$(word 2,$(lastTag))
major minor patch: patch=$(word 3,$(lastTag))
major: new=$(shell echo $$(($(major)+1))).0.0
minor: new=$(major).$(shell echo $$(($(minor)+1))).0
patch: new=$(major).$(minor).$(shell echo $$(($(patch)+1)))

major minor patch:## Edit files to bump the version
	sed -i 's/Version: .*/Version: $(new)/' pkgdown/DESCRIPTION
	echo "# Version $(new)" > pkgdown/tmp.md
	echo "## Major Changes" >>  pkgdown/tmp.md
	echo "## Minor Changes" >>  pkgdown/tmp.md
	git log v$(lastNews)...HEAD --pretty=format:' - %s' --reverse >> pkgdown/tmp.md
	printf '\n' >> pkgdown/tmp.md
	cat pkgdown/NEWS.md >> pkgdown/tmp.md
	mv pkgdown/tmp.md pkgdown/NEWS.md
	echo "Please check pkgdown/NEWS.md and pkgdown/DESCRIPTION are correct. Then commit and tag v"$(new)

help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
MAKEFLAGS += --no-builtin-rules
