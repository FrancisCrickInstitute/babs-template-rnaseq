.DEFAULT_GOAL:=help
all: differential
.PHONY: all clean
include shared.mk

stages := ingress nfcore differential biologic 
.PHONY: $(stages)
$(stages): % : %.log


%.log : 
	cd $*; $(MAKE) --no-print-directory run  >> $*.err 2>&1
	mv $*/$*.err $@

all: ## Attempt to run the full pipeline (to differential). Produces a `.err` file if a module doesn't complete (look at this and perhaps at `./module-name/logs/*.err` to help debugging.) It's no longer necessary to run modules in succession, as things have been refactored to recursively calculate any necessary prerequisites. An explicit 'make build' is no longer necessary, as 'make run' will carry that out as and when necessary.
docs: ## Basic check that the prerequisite files (spec, configs, samplesheet and experiment table) are in place in this folder
ingress: ## Basic curating of the prerequisites, to allow for future API changes
nfcore: ## Run the nfcore pipeline according to all the `.config` files
differential: ## Analyse the outcome of the nfcore run in the context of the `*.spec` files (same as `make all`)

cleaners := $(stages:%=clean-%)
clean: $(cleaners)
.PHONY: $(cleaners)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean

