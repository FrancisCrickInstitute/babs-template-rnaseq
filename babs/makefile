.DEFAULT_GOAL:=help

all: differential
stages := ingress nfcore differential biologic 
.PHONY: all clean $(stages)

## Chain of dependencies for the stages of analysis enforces the required run-order
differential: nfcore
nfcore: ingress
ingress: docs

## stage-level log files are the sentinel for the stage having been run
$(stages): % : %.log

ifeq ($(origin sbatch_args),command line)
SB=sbatch_args=$(sbatch_args)
else
SB=
endif

## Do 'make run' in the stage's directory.
## Only create the log file if successful, otherwise crash out with the err file
%.log : 
	cd $*; $(MAKE) --no-print-directory run $(SB) >> $*.err 2>&1
	mv $*/$*.err $@

sbatch: nfcore ## Same as 'all', but submit the final differential stage to slurm. Can add multiple --slurm_arg=value flags.
	cd differential && $(MAKE) sbatch run

################################################################
#### Help texts for the various targets
################################################################

all: ## Attempt to run the full pipeline (to differential). Produces a `.err` file in the directory of a stage that doesn't complete (look at this and perhaps at `./stage-name/logs/*.err` to help debugging.) 

docs: ## Basic check that the prerequisite files (spec, configs, samplesheet and experiment table) are in place in this folder

ingress: ## Basic curating of the prerequisites, to allow for future API changes

nfcore: ## Run the nfcore pipeline according to all the `.config` files

differential: ## Analyse the outcome of the nfcore run in the context of the `*.spec` files (same as `make all`)

update: ## Update from the 'export' branch of the original branch of the template repo
	git fetch template-repo export
	git checkout template
	git merge --squash template-repo/export
	sed '1s/^message: //' .template-provenance | git commit -F -


.PHONY: help
help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nRunning the RNASeq pipeline - `make` subcommands: \033[36m\033[0m\n"}\
/^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }\
/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


################################################################
#### Cleaners
################################################################

cleaners := $(stages:%=clean-%)
clean: $(cleaners)
.PHONY: $(cleaners)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean

