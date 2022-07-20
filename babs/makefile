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
	git stash -m "Stashing state prior to pipeline update"
	cp -r --no-preserve=mode /camp/stp/babs/working/bioinformatics/templates/rnaseq/babs/. .

update-pm: ## Update the project management scripts
	git stash -m "Stashing state prior to updating .github"
	cp -r --no-preserve=mode /camp/stp/babs/working/bioinformatics/templates/generic/.github/. ../.github/

help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
