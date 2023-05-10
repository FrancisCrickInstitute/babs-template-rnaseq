.DEFAULT_GOAL=help

template_dir := /camp/stp/babs/working/bioinformatics/templates
template_dir := /camp/stp/babs/working/kellyg/test

type = rnaseq
version = $(shell git describe --tags --abbrev=0)

################################################################
#### Everything below should be kept as-is
################################################################

.PHONY: deploy

deploy: $(template_dir)/archive $(template_dir)/$(type) ## Copy all controlled files, except .git folder and things in .gitattributes, into area where tickets and pipeline can see it.
	git archive --format=tar.gz HEAD  > $(type)-$(version).tar.gz
	tar -xzf $(type)-$(version).tar.gz -C $(template_dir)/$(type)
	cp $(type)-$(version).tar.gz $(template_dir)/$(type).tar.gz
	mv $(type)-$(version).tar.gz $(template_dir)/archive/$(type)-$(version).tar.gz


$(template_dir)/archive $(template_dir)/$(type):
	mkdir -p $@



help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
