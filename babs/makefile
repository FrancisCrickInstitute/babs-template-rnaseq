include global.mk
.PHONY: all simulate clean update-pipeline help

all: differential.log ## Run the whole pipeline 

differential.log: nfcore.log
nfcore.log: ingress.log
ingress.log: docs.log
biologic.log: differential.log

simulate: simulation.log


%.log : %
	$(MAKE) -C $* build > $*.err 2>&1
	$(MAKE) -C $* run  >> $*.err 2>&1
	mv $*.err $@


cleaners := $(patsubst %/,clean-%,$(wildcard */))
.PHONY: $(cleaners)
clean: $(cleaners) ## 'clean' each module, then remove the log files
	rm -f *.log
$(cleaners): clean-%:
	$(MAKE) -C $* clean || echo "Couldn't clean $*"


################################################################

update-pipeline: ## Update the pipeline
	$(GIT) stash -m "Stashing state prior to pipeline update"
	cp -r --no-preserve=mode /camp/stp/babs/working/bioinformatics/templates/rnaseq/babs/. .

update-pm: ## Update the project management scripts
	$(GIT) stash -m "Stashing state prior to updating .github"
	cp -r --no-preserve=mode /camp/stp/babs/working/bioinformatics/templates/generic/.github/. ../.github/

