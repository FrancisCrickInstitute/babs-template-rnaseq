.DEFAULT_GOAL=help
################################################################
## Things here are typically shared across all phases of the
## analysis. There's originally one gold-reference copy of this file
## that gets copied into each subdirectory (in case the subdirectory
## gets shared by itself some time in the future), so it's recommended
## that any necessary phase-specific changes are put into module.mk,
## which will override things in shared.mk and secret.mk
################################################################
samplesheet_fname=samplesheet
experiment_table = experiment_table
samplesheet_id_column = sample
metadata_id_column = ID
name_col = sample_name
samples_db = samples.db

NEXTFLOW = $(call ml,Nextflow/$(NEXTFLOW_VERSION)); $(call ml,Singularity/$(SINGULARITY_VERSION)); $(call ml,CAMP_proxy); nextflow
SQLITE = $(call ml,SQLite/3.42.0-GCCcore-12.3.0); sqlite3



docs_dir?=$(wildcard ../docs)
ingress_dir?=$(wildcard ../ingress)
nfcore_dir?=$(wildcard ../nfcore)
diff_dir?=$(wildcard ../differential)

# The following can be set to singularity|docker|shell
# and determines the environment in which quarto/R processes
# will be run in.
EXECUTOR = singularity

################################################################
# Conventional directory-, file- and field- names
################################################################

## Location of qmds and multi-yaml files
source_dir=resources
## Place where qmds will be generated
staging_dir=staging
## place within the staging directory where renders will be placed
RESULTS_DIR = results
## Convenient shortcut for immediate quarto output
staged_results=$(staging_dir)/$(RESULTS_DIR)/$(VERSION)
## Where to store scripts necessary to launch rstudio/shiny/jupyter etc
launch_dir=.babs-launchers

# csv file names (excluding ext)
log_dir=logs

SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))


################################################################
# Executables and their versions
################################################################
SINGULARITY_VERSION=3.11.3
NEXTFLOW_VERSION=23.10.0
RVERSION=4.5.0
BIOCONDUCTOR_VERSION=RELEASE_3_21
OUR_VERSION=v0.8.0

################################################################
# Singularity Images
################################################################

IMAGE_NAME=bioconductor_docker
IMAGE_REG=$(if $(OUR_VERSION),ghcr,docker).io/
IMAGE_REPO=$(if $(OUR_VERSION),franciscrickinstitute/babs-template-rnaseq,bioconductor)
IMAGE_TAG=$(BIOCONDUCTOR_VERSION)-R-$(RVERSION)$(and $(OUR_VERSION),-$(OUR_VERSION))
IMAGE=$(IMAGE_REPO)/$(IMAGE_NAME)
export SINGULARITYENV_RENV_PATHS_PREFIX=$(subst /,-,$(IMAGE))

R=R
QUARTO=quarto
GIT=git

## Module loader
ml = module is-loaded $1 || module load $1 || true # ie fall back to true (ie rely on system version if can't load a module)
make_rwx = setfacl -m u::rwx
makeg_rwx = setfacl -m g::rwx

# Environment Variables
NUM_THREADS=$${NUM_THREADS:-2}


################################################################
# Git-derived variables
################################################################
PROJECT_HOME:=$(shell $(GIT) rev-parse --show-toplevel 2>/dev/null || echo $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TAG = _$(shell $(GIT) describe --tags --dirty=_altered --always --long 2>/dev/null || echo "uncontrolled")# e.g. v1.0.2-2-ace1729a
VERSION := $(shell $(GIT) describe --tags --abbrev=0 2>/dev/null || echo "vX.Y.Z")#e.g. v1.0.2
DELTA-VERSION=$(shell git describe --tags --abbrev=0 $$(git log --format="%H" -n 1 -- $(1)))#For when we want a version that doesn't increment on changes irrelevant to path given by first arg
git-ignore=touch .gitignore && grep -qxF '$(1)' .gitignore || echo '$(1)' >> .gitignore



include $(SELF_DIR)secret.mk

################################################################
## Propagation of docs files
## 'Earliest' presence of a propagated file is taken as definitive.
################################################################
early_spec_dir=$(firstword $(wildcard $(docs_dir) $(diff_dir)/extdata))
specfiles=$(patsubst $(early_spec_dir)/%.spec,%,$(wildcard $(early_spec_dir)/*.spec))

#early_align=$(firstword $(wildcard $(docs_dir) $(ingress_dir) $(nfcore_dir) $(diff_dir)/extdata))

ifneq ($(diff_dir),)
alignments=$(patsubst $(diff_dir)/extdata/%.config,%,$(wildcard $(diff_dir)/extdata/*.config))
endif
ifneq ($(nfcore_dir),)
alignments=$(patsubst $(nfcore_dir)/results/%,%,$(wildcard $(nfcore_dir)/results/*))
endif
ifneq ($(ingress_dir),)
alignments=$(patsubst $(ingress_dir)/%.config,%,$(wildcard $(ingress_dir)/*.config))
endif
ifneq ($(docs_dir),)
alignments=$(patsubst $(docs_dir)/%.config,%,$(wildcard $(docs_dir)/*.config))
endif

################################################################
## Publishing (moving) generated results and providing shortcuts
################################################################

excluded-targets += $(pubdir)/$(VERSION)

publish_intranet=www_internal
publish_internet=www_external
publish_outputs=outputs
location=outputs

shortcut=$()
ifdef redirect_$(location)
shortcut=shortcuts/
endif
pubdir = $(shortcut)$(publish_$(location))
ifeq ($(pubdir),)
pubdir = published
endif

$(pubdir)/$(VERSION):
ifdef redirect_$(location)
	mkdir -p $(redirect_$(location))
	mkdir -p $(shortcut)
ifdef url_$(location)
	echo "<!doctype html>" > $(shortcut)$(location).html
	echo "<script>" >> $(shortcut)$(location).html
	echo "window.location.replace('$(url_$(location))/$(VERSION)')" >> $(shortcut)$(location).html
	echo "</script>"  >> $(shortcut)$(location).html
endif
	ln -sfn $(redirect_$(location)) $(pubdir)
endif
	mkdir -p $@
	ln -sfn $(VERSION) $(pubdir)/latest


################################################################
## SLURM
## 
## Have default but customisable slurm parameters 
################################################################
## By default, run recipes in the usual manner rather than slurm etc.
SUBMIT=false

SLURM--time=0-02:00:00
SLURM--mem=64G
SLURM--cpus-per-task=8
SLURM--partition=ncpu

define slurm
#! /usr/bin/bash
#SBATCH --partition=$(SLURM--partition)
#SBATCH --time='$(SLURM--time)'
#SBATCH --cpus-per-task=$(SLURM--cpus-per-task)
#SBATCH --mem=$(SLURM--mem)
#SBATCH --job-name=$(notdir $(CURDIR))
#SBATCH --output=slurm-%x-%A_%a.out
export MAKEFLAGS="$(MAKEFLAGS)"
NUM_THREADS=$${SLURM_JOB_CPUS_PER_NODE}
$(containerPrefix) make $@ SUBMIT=false EXECUTOR=make $(send_notification)
endef

export slurm

ifdef NTFY
send_notification=; r=$$?; [ $$r -eq 0 ] && \
curl -H "Title: SLURM submission complete" -H "Tags: +1" -d "Finished $@" ntfy.sh/$(NTFY) || \
curl -H "Title: SLURM submission failed"   -H "Tags: warning" -d "Failed $@: status $$r" ntfy.sh/$(NTFY)
endif

################################################################
## Reproducible containers
##
## We've set a default value of EXECUTOR=singularity. This can be
## over- ridden at the command line, e.g.  `make target
## EXECUTOR=shell|singularity|docker` 'shell' will run using the
## prevailing system executables.
################################################################

excluded-targets += Dockerfile install_all.sh

CONTAIN=false#An internal flag
BIND_DIR = $$(git rev-parse --show-toplevel 2>/dev/null || echo $$(realpath .))
EXECUTOR?=singularity
renv_root=$(or $(SINGULARITYENV_RENV_PATHS_ROOT),~/.cache/R/renv)
ifeq ($(EXECUTOR),singularity)
#Sometimes we want to do e.g. env SINGULARITYENV_APPEND_PATH=/stuff - that's what CONTAINER_VARS is for
CONTAINER= $(call ml,Singularity/$(SINGULARITY_VERSION)); $(CONTAINER_VARS) singularity
CONTAINER_IMAGE=$(or $(SINGULARITY_ROOT),.)/$(IMAGE)_$(IMAGE_TAG).sif
CONTAINER_BIND=--bind $(BIND_DIR),/tmp,$(renv_root)
CONTAINER_ENV=--env SQLITE_TMPDIR=/tmp,BIOCPARALLEL_WORKER_NUMBER=$(NUM_THREADS),GITHUB_PAT=$${GITHUB_PAT},OMP_NUM_THREADS=${NUM_THREADS},OPENBLAS_NUM_THREADS=${NUM_THREADS}
CONTAINER_OPTIONS= exec $(CONTAINER_BIND) --pwd $$(realpath .) --containall --cleanenv $(CONTAINER_ENV)
$(CONTAINER_IMAGE): 
	cd $(dir $(CONTAINER_IMAGE)) ;\
	$(CONTAINER) pull docker://$(IMAGE_REG)$(IMAGE)$(colon)$(IMAGE_TAG)
	$(makeg_rwx) $(CONTAINER_IMAGE)
CONTAIN=true


else ifeq ($(EXECUTOR),docker)
CONTAINER=docker
CONTAINER_IMAGE=$(IMAGE)$(colon)$(IMAGE_TAG)
CONTAINER_OPTIONS=run \
--mount type=bind,source="$(BIND_DIR)",target="$(BIND_DIR)" \
--mount type=bind,source="/tmp",target="/tmp" \
--mount type=bind,source="$(renv_root)",target="$(renv_root)" --env RENV_PATHS_ROOT=$(renv_root)\
--env SQLITE_TMPDIR=/tmp \
--env BIOCPARALLEL_WORKER_NUMBER=$(NUM_THREADS) \
--env GITHUB_PAT=$${GITHUB_PAT} \
--env OMP_NUM_THREADS=${NUM_THREADS} \
--env OPENBLAS_NUM_THREADS=${NUM_THREADS} \
--workdir="$$(realpath .)"
CONTAINER_SHELL = $(CONTAINER) $(patsubst run,exec -it,$(CONTAINER_FLAGS_INTERACTIVE)) $(CONTAINER_IMAGE) /bin/bash
CONTAIN=true
$(CONTAINER_IMAGE): 
	$(CONTAINER) pull docker://$(IMAGE_REG)$(IMAGE):$(IMAGE_TAG) || echo "Couldn't pull docker://$(IMAGE):$(IMAGE_TAG). Continuing, but make sure it's present at run time."
	mkdir -p $(dir $(CONTAINER_IMAGE))
	echo "Proxy for docker image" > $@


else ifeq ($(EXECUTOR),shell)
  $(info " Not using containerisation so results are not necessarily reproducible")

else ifeq ($(EXECUTOR),make)
# This is what we use as internal option - effectively means we're already in the container,
# so no need for any action here.
else
  $(error "# Don't recognise '$(EXECUTOR)' as an executor")
endif

# 
docker/Dockerfile: OUR_VERSION=$(call DELTA-VERSION,resources/docker)
docker/Dockerfile: resources/docker/Dockerfile docker/install_all.sh## Create a Dockerfile corresponding to the image in use.
	< $< $(call envsubst,RVERSION BIOCONDUCTOR_VERSION OUR_VERSION IMAGE_REPO) > $@
docker/install_all.sh: $(wildcard resources/docker/install_*.sh) docker/build.sh
	cat resources/docker/install_*.sh > $@
docker/build.sh:
	mkdir -p docker
	echo "docker build -t $(IMAGE_NAME) ." > $@
	echo "docker tag  $(IMAGE_NAME) $(IMAGE_REG)$(IMAGE):$(IMAGE_TAG)" >> $@
	echo "docker push $(IMAGE_REG)$(IMAGE):$(IMAGE_TAG)" >> $@


ifeq ($(CONTAIN),true)
optionalContainer=$(CONTAINER_IMAGE)
containerPrefix=$(CONTAINER) $(CONTAINER_OPTIONS) --env MAKEFLAGS="$(MAKEFLAGS)" $(CONTAINER_IMAGE)
else
optionalContainer=
containerPrefix=
endif


################################################################
#Standard makefile hacks
################################################################
# These targets will skip any computationally intensive 'include's
excluded-targets += help clean maintainer-clean print-%

comma:= ,
colon:= :
space:= $() $()
empty:= $()
define newline

$(empty)
endef
bslash := \$(empty)

#We don't need any of the c default rules
MAKEFLAGS += --no-builtin-rules

.PHONY: print-%
print-%: ## `make print-varname` will show varname's value
	@echo "$*"="$($*)"

V:=1#switches _off_ SILENT mode - delete for SILENT to be default
$(V).SILENT: 

.PHONY: help
help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: `make command` where command is one of: \n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

log=2>&1 | tee $2 $(log_dir)/$1.log
# $(call log,test) will write stderr+out to log.test and report to stdout
# $(call log,test,-a) will append stderr+out to log.test and report to stdout
# Alternative definition, which supresses stdout
#log=$(subst -a,>)$(log_dir)/$1.log 2>&1

# Templating a text file - replace instances of ${A} with the value of variable A
# $(call envsubst,A B) produces A='$(A)' B='$(B)' envsubst '$$A $$B'
# In shell, this transfers out the values of variables A and B, then calls envsubst on a file provided by stdin which  replaces instances in that file  of '$A' with its value...
envsubst = $(foreach v,$(1),$v='$($(v))' )envsubst '$(foreach v,$(1),$${$v})'

################################################################
## Recipes for calling R/Rstudio
##
################################################################
excluded-targets += R R-local R-$(RVERSION) .Rprofile

.PHONY: R R-local R-$(RVERSION)


R-local: R-$(RVERSION) ## Create a local shell script that will run R (optional, but helpful for interactive analyses).  Also EXECUTOR=docker means the launchers will use docker rather than singularity

R-$(RVERSION): BIND_DIR=$${wd}#Again, pick up local runtime setting
R-$(RVERSION): resources/shell/R-$(EXECUTOR)
	< $< $(call envsubst,CONTAINER_IMAGE CONTAINER CONTAINER_OPTIONS RVERSION SINGULARITYENV_RENV_PATHS_PREFIX) > $@
	@$(make_rwx) $@
	mkdir -p $(launch_dir)/
	for i in rstudio shiny jupyter; do cp resources/shell/$${i}-$(EXECUTOR).sh $(launch_dir)/$${i}.sh || echo "$${i}-$(EXECUTOR).sh doesn't yet exist"; done

R:
	@echo "Starting R $(RVERSION) in container $(CONTAINER_IMAGE) ..."
	@$(CONTAINER) $(CONTAINER_OPTIONS) $(CONTAINER_IMAGE) R


.Rprofile: $(wildcard resources/renv/Rprofile) | renv/activate.R
	mkdir -p renv
	[ ! -f "$<" ] || $(GIT) mv $< $@ 2>/dev/null || mv $< $@

renv/activate.R: $(wildcard resources/renv/activate.R)
	mkdir -p renv
	[ ! -f "$<" ] || $(GIT) mv $< $@ 2>/dev/null || mv $< $@


################################################################
## Generate secrets
################################################################
# If a secret.mk file can't be found anywhere, create a dummy
# one out of a template. If there's a .babs file, ensure changes in that
# are reflected in the secrets file.

$(SELF_DIR)secret.mk: $(wildcard $(PROJECT_HOME)/.babs)
	if [ ! -f "$@" ]; then \
	echo "SINGULARITY_ROOT=.#where .sif's are stored" > $@ ;\
	echo "SCRATCH_DIR=/tmp#Somewhere for transient, possibly large, files" >> $@ ;\
	echo "Created a dummy copy of $@, please edit it" ;\
	fi
	if [ -n "$<" ]; then \
	  sed  -i '/^setting_/d' $@ ;\
	  sed -r -n 's/^(\s*)(.*)\s*:\s*(.*$$)/setting_\2=\3/p' $< >> $@ ;\
	fi

excluded-targets += check-isolated
