################################################################
## README
################################################################
##
## The further one goes through this document, the less recommended it
## is to change parts.  Firstly we have version IDs of binaries to be
## used, then some standard directory names that you can change if
## you strongly object to the default choices, but it's not advised!
## Then we have some containerisation code that is easily broken/
##
################################################################
## Stand-alone usage:
## 
## We expect a sibling 'nfcore' directory parallel to this
## 'differential' one, if we are to prepare things with a `make
## build`.  However, if you have pre-aligned data from another source,
## it is possible to omit that `build` stage, and instead arrange this
## directory to have all the prerequisites ready for a `make run`. You
## will need to select an (arbitrary) name to denote the set of
## samples that have been aligned.  We recommend a short mnemonic that
## represents this: for illustrative purposes we'll use the word 'human'.
## Assuming that (or change _every_ instance of it uniformly),
## here is the necessary structure:
##
## ./extdata/metadata_human.csv - experiment table, with the ID's
## filled in
##
## ./extdata/genes.results/human/*.genes.results - rsem quantified
## counts per sample (note the extra directory level 'human' when compared
## to standard nfcore results)
##
## ./human.config - containing at least the line `human.org.db=org.Hs.eg.db`
##
## Given those three requirements, and at least one spec file, `make run` will
## produce the reports


################################################################
## Binaries
################################################################
#R=#Set in shared.mk
QUARTO=quarto
EXECUTOR = singularity
IMAGE=bioconductor/bioconductor_docker
IMAGE_TAG=$(BIOCONDUCTOR_VERSION)-R-$(RVERSION)
BIOCPARALLEL_WORKER_NUMBER=2

################################################################
## Directories
################################################################
## Location of qmds and multi-yaml files
source_dir=resources
## Place where qmds will be generated
staging_dir=staging
## place within the staging directory where renders will be placed
RESULTS_DIR = results
#Probably set in 'secret.mk' file, but if not then:
RENV_PATHS_ROOT ?= ~/.local/share/renv
RENV_PATHS_PREFIX=rocker
#Another 'secret', but in case not:
SINGULARITY_ROOT ?= ./

my_counts_dir=extdata/genes.results
my_metadata=extdata/metadata

## Unlikely that anything below here needs setting by a user.

################################################################
## Reproducible containers
##
## Above, we set a default value of EXECUTOR. This can be over-
## ridden at the command line, e.g.
## `make target EXECUTOR=shell|singularity|docker`
## 'shell' will run using the prevailing system executibles.
################################################################
CONTAINERED=false#An internal flag
BIND_DIR = $(shell $(GIT) rev-parse --show-toplevel || echo $(CURDIR))

ifeq ($(EXECUTOR),singularity)
CONTAINER= $(call ml,Singularity/$(SINGULARITY_VERSION)); singularity
CONTAINER_IMAGE=$(SINGULARITY_ROOT)/$(IMAGE)_$(IMAGE_TAG).sif
CONTAINER_BIND=--bind $(BIND_DIR),/tmp,$(RENV_PATHS_ROOT),$(CURDIR)/rocker.Renviron:/usr/local/lib/R/etc/Renviron.site
CONTAINER_ENV=--env SQLITE_TMPDIR=/tmp,BIOCPARALLEL_WORKER_NUMBER=$(BIOCPARALLEL_WORKER_NUMBER),GITHUB_PAT=$${GITHUB_PAT}
CONTAINER_FLAGS= exec $(CONTAINER_BIND) --pwd $(CURDIR) --containall --cleanenv $(CONTAINER_ENV)
CONTAINER_FLAGS_INTERACTIVE= exec $(CONTAINER_BIND),$${HOME} --pwd $(CURDIR) --containall --cleanenv $(CONTAINER_ENV),DISPLAY=$${DISPLAY}
CONTAINER_SHELL = $(CONTAINER) $(patsubst exec,shell,$(CONTAINER_FLAGS_INTERACTIVE)) $(CONTAINER_IMAGE)
$(CONTAINER_IMAGE): | rocker.Renviron
	cd $(dir $(CONTAINER_IMAGE)) ;\
	$(CONTAINER) pull docker://$(IMAGE):$(IMAGE_TAG)
CONTAINERED=true

else ifeq ($(EXECUTOR),docker)
CONTAINER=docker
CONTAINER_IMAGE=$(IMAGE)_$(IMAGE_TAG)
CONTAINER_FLAGS=run \
--mount type=bind,source="$(BIND_DIR)",target="$(BIND_DIR)" \
--mount type=bind,source="/tmp",target="/tmp" \
--mount type=bind,source="$(CURDIR)/rocker.Renviron",target="/usr/local/lib/R/etc/Renviron.site" \
--workdir="$(CURDIR)" $(IMAGE):$(IMAGE_TAG)
	mkdir -p $(dir $(CONTAINER_IMAGE))
	touch $(CONTAINER_IMAGE)
CONTAINER_SHELL = $(CONTAINER) $(patsubst run,exec -it,$(CONTAINER_FLAGS_INTERACTIVE)) $(CONTAINER_IMAGE) /bin/bash
CONTAINERED=true
$(CONTAINER_IMAGE): | rocker.Renviron
	$(CONTAINER) pull docker://$(IMAGE):$(IMAGE_TAG)
	echo "Proxy for docker image" > $@

else ifeq ($(EXECUTOR),shell)
  $(info " Not using containerisation so results are not necessarily reproducible")
## Maybe setup different values for R, QUARTO, eg
# R=module load R

else ifeq ($(EXECUTOR),make)
# This is what we use as internal option - effectively means we're already in the container,
# so no need for any action here.
else
  $(error "# Don't recognise '$(EXECUTOR)' as an executor")
endif


################################################################
## GEO settings
################################################################
## For submission to GEO, we need to know the version, spec and
## aligment settings that are to be submitted.
################################################################
geo: version=latest
geo: alignment=$(firstword $(alignments))
geo: spec=$(firstword $(specfiles))
