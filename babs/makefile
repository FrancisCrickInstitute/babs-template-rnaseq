.DEFAULT_GOAL:=help
all: differential
.PHONY: all clean
include global.mk
include secrets

stages := ingress nfcore differential biologic 
.PHONY: $(stages)
$(stages): % : %.log

differential.log: nfcore.log
nfcore.log: ingress.log
ingress.log: docs.log
biologic.log: differential.log

simulate: simulation.log

%.log : 
	$(MAKE) -C $* build > $*.err 2>&1
	$(MAKE) -C $* run  >> $*.err 2>&1
	mv $*.err $@

all: ## Attempt to make and build all modules in turn: docs, ingress, nfcore, differential. Produces a `.err` file if a module doesn't complete (look at this and perhaps at `./module-name/logs/*.err` to help debugging.) Making any of the following targets will also run any prior modules that as necessary.
docs: ## Basic check that the prerequisite files (spec, configs, samplesheet and experiment table) are in place in this folder
ingress: ## Basic curating of the prerequisites, to allow for future API changes
nfcore: ## Run the nfcore pipeline according to all the `.config` files
differential: ## Analyse the outcome of the nfcore run in the context of the `*.spec` files

cleaners := $(stages:%=clean-%)
clean: $(cleaners)
.PHONY: $(cleaners)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean
