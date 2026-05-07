.DEFAULT_GOAL=help

template_dir=/nemo/stp/babs/working/bioinformatics/templates
type = rnaseq

ifndef version
version = $(shell git describe --tags --abbrev=0)
defaultVersion=true
endif


################################################################
#### Deployment of the current commit to central templates area,
#### as a tarball 
################################################################

.PHONY: deploy

deploy: | $(template_dir)/archive ## Copy all controlled files, except .git folder and things in .gitattributes, into area where tickets and pipeline can see it. Setting `version=dev` will put it into the archive (where it can be retrieved) but not into the default area
	git archive --format=tar.gz HEAD  > $(type)-$(version).tar.gz
ifeq ($(defaultVersion),true)
	cp $(type)-$(version).tar.gz $(template_dir)/$(type).tar.gz
endif
	mv $(type)-$(version).tar.gz $(template_dir)/archive/$(type)-$(version).tar.gz

gh-deploy:
	gh release create $(version) '$(template_dir)/archive/$(type)-$(version).tar.gz#Pipeline'


$(template_dir)/archive:
	mkdir -p $@

.PHONY: export
export: ## Create an 'export' branch that can be squash-merged into projects, to update them
	git checkout --orphan export
	git read-tree --empty
	git checkout $(version) -- babs
	echo "message: Update to template $(version)" > babs/.template-provenance
	echo "template_tag: $(version)" >> babs/.template-provenance
	echo "template_commit: $(shell git rev-parse $(version))" >> babs/.template-provenance
	echo "template_repo: $(shell git remote get-url origin)" >> babs/.template-provenance
	git add babs
	git commit -m "Release $(version)"
	git switch -f -


################################################################
#### Pull in any cross-template logic
################################################################

.PHONY: infrastructure

infrastructure: ## Transfer differential code from template
infrastructure: $(template_dir)/environment.tar.gz
	tar -xzf $< -C babs/differential/
	patch -p1 -d babs/differential < rnaseq.patch
	for i in docs ingress nfcore; do cp babs/differential/resources/make/shared.mk babs/$$i/; done

rnaseq.patch: $(template_dir)/environment.tar.gz
	rm -rf infra-tmp && mkdir infra-tmp
	tar -xzf $< -C infra-tmp
	diff -ur infra-tmp babs/differential | grep -v "^Only in " | sed -E 's/^([+-]{3} [^\t]+)\t[0-9]{4}.*/\1/'> $@ || true
	rm -rf infra-tmp	

################################################################
#### Testing the pipeline
################################################################

airway/fastq: airway/ena.txt
	mkdir -p $@
	while read i; do wget -P $@ -nc ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR103/$$i.fastq.gz ; done < $<

airway/nfcore.tar.gz: | test ## Cache the nfcore results for future speed
	cd test/babs/nfcore &&\
	make run &&\
	tar -czf  ../../../$@ samplesheet_GRCh38.csv GRCh38.csv GRCh38.config results/GRCh38/multiqc results/GRCh38/star_rsem/*.genes.results results/GRCh38/multi-qc results/GRCh38/star_rsem/rsem.merged.gene_counts.tsv results/GRCh38/merged.gene_counts.tsv

test: airway/fastq ## Generate a test folder setup for the airway data
	mkdir -p $@/babs
	touch $@/.babs
	rsync -av  babs/. $@/babs/. --exclude '.~'
	( cd $@ && git init )
	( cd $@/babs && \
	ln -sfn ../../airway/fastq fastq && \
	cp -r ../../airway/docs . && \
	if [ -n "$(aligner)" ]; then echo "aligner=$(aligner)" >> docs/GRCh38.config; fi && \
	git commit --allow-empty -m "Restart git repo for testing" && \
	git tag v9.9.9 )
	cd $@/babs/ingress && make run

.PHONY: test-ff-nfcore test-differential
test-ff-nfcore: test/babs/nfcore/results ## Fast-forward to before the differential analysis, by using a cached run of nfcore
	echo "[env]" > test/babs/differential/.mise.toml
	echo "source_dir = '$(CURDIR)/babs/differential'" >> test/babs/differential/.mise.toml
	echo "sync_src = 'resources/ R/ makefile'" >> test/babs/differential/.mise.toml

test-differential: test/babs/nfcore/results airway/preprocessed.rda
airway/preprocessed.rda:
	cd test/babs/differential; make run
	cp test/babs/differential/data/counts_GRCh38.rda airway/preprocessed.rda

test/babs/nfcore/results:  test | airway/nfcore.tar.gz
	cd test/babs/nfcore && tar  -xzf ../../../airway/nfcore.tar.gz && make -t run && find results -exec touch {} \;

test/isolated-analysis: airway/preprocessed.rda ## Provide an example of what an isolated differential analysis folder looks like.
	rm -rf $@
	mkdir -p $@/extdata
	cp -r babs/differential/. $@
	cp airway/docs/analyse.spec $@/extdata
	cp airway/preprocessed.rda $@/extdata/
	sed 's/^/preprocessed./' airway/docs/GRCh38.config | grep org.db > $@/extdata/preprocessed.config
	(cd $@ && make check-isolated)

################################################################
#### Documentation
################################################################

.PHONY: pkgdown
pkgdown: ## Make the pkgdown site
	( cd $@; make site )

major minor patch: lastNews=$(shell sed -n '1s/# Version //p' pkgdown/NEWS.md)
major minor patch: lastTag:=$(subst ., ,$(patsubst v%,%,$(shell git describe --tags --abbrev=0 --match 'v*')))
major minor patch: major=$(word 1,$(lastTag))
major minor patch: minor=$(word 2,$(lastTag))
major minor patch: patch=$(word 3,$(lastTag))
major: new=$(shell echo $$(($(major)+1))).0.0
minor: new=$(major).$(shell echo $$(($(minor)+1))).0
patch: new=$(major).$(minor).$(shell echo $$(($(patch)+1)))

major minor patch: ## Edit files to bump the version
	sed -i 's/Version: .*/Version: $(new)/' pkgdown/DESCRIPTION
	echo "# Version $(new)" > pkgdown/tmp.md
	echo "## Major Changes" >>  pkgdown/tmp.md
	echo "## Minor Changes" >>  pkgdown/tmp.md
	git log v$(lastNews)...HEAD --pretty=format:' - %s' --reverse >> pkgdown/tmp.md
	printf '\n' >> pkgdown/tmp.md
	cat pkgdown/NEWS.md >> pkgdown/tmp.md
	mv pkgdown/tmp.md pkgdown/NEWS.md
	echo "Please check pkgdown/NEWS.md and pkgdown/DESCRIPTION are correct. Then commit and tag v"$(new)

.PHONY: clean
clean:
	rm -rf test

help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nRNASeq template management/deployment - `make` subcommands: \033[36m\033[0m\n"}\
/^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }\
/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

MAKEFLAGS += --no-builtin-rules
