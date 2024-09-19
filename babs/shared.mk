.DEFAULT_GOAL=help
SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
################################################################
## Things here are typically shared across all phases of the
## analysis. There's originally one gold-reference copy of this file
## that gets copied into each subdirectory (in case the subdirectory
## gets shared by itself some time in the future), so it's recommended
## that any necessary phase-specific changes are put into module.mk,
## which will override things in shared.mk and secret.mk
################################################################

# The following can be set to singularity|docker|shell
# and determines the environment in which quarto/R processes
# will be run in.
EXECUTOR = singularity

################################################################
# Conventional file- and field- names
################################################################
# csv file names (excluding ext)
samplesheet_fname=samplesheet
experiment_table = experiment_table
# Column names
samplesheet_id_column := sample
metadata_id_column := ID
name_col = sample_name
log_dir=logs
samples_db = samples.db

################################################################
# Executables
################################################################
## Versions
SINGULARITY_VERSION=3.11.3
NEXTFLOW_VERSION=23.10.0
RVERSION=4.3.2
BIOCONDUCTOR_VERSION=3.18
IMAGE=bioconductor/bioconductor_docker
IMAGE_TAG=$(BIOCONDUCTOR_VERSION)-R-$(RVERSION)
R=R
QUARTO=quarto
GIT=git

## Module loader
ml = module is-loaded $1 || module load $1 || true # ie fall back to true (ie rely on system version if can't load a module)
## Define commands invoked by make
NEXTFLOW = $(call ml,Nextflow/$(NEXTFLOW_VERSION)); $(call ml,Singularity/$(SINGULARITY_VERSION)); $(call ml,CAMP_proxy); nextflow
SQLITE = $(call ml,SQLite/3.42.0-GCCcore-12.3.0); sqlite3
make_rwx = setfacl -m u::rwx

# Environment Variables
BIOCPARALLEL_WORKER_NUMBER=2


################################################################
# Standard folder and shortcut names
################################################################
publish_results=results
publish_intranet=www_internal
publish_internet=www_external
publish_outputs=outputs
location=results
docs_dir?=$(wildcard ../docs)
ingress_dir?=$(wildcard ../ingress)
nfcore_dir?=$(wildcard ../nfcore)
diff_dir?=$(wildcard ../differential)


################################################################
## Propagation of docs files
## 'Earliest' presence of a propagated file is taken as definitive.
################################################################
early_spec_dir=$(firstword $(wildcard $(docs_dir) $(ingress_dir) $(diff_dir)/extdata))
specfiles=$(patsubst $(early_spec_dir)/%.spec,%,$(wildcard $(early_spec_dir)/*.spec))

#early_align=$(firstword $(wildcard $(docs_dir) $(ingress_dir) $(nfcore_dir) $(diff_dir)/extdata))

ifneq ($(diff_dir),)
alignments=$(patsubst $(diff_dir)/$(my_counts_dir)/%,%,$(wildcard $(diff_dir)/$(my_counts_dir)/*))
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
endef

export slurm

include $(SELF_DIR)secret.mk

################################################################
## Reproducible containers
##
## Above, we set a default value of EXECUTOR. This can be over-
## ridden at the command line, e.g.
## `make target EXECUTOR=shell|singularity|docker`
## 'shell' will run using the prevailing system executables.
################################################################
CONTAIN=false#An internal flag
BIND_DIR = $(shell $(GIT) rev-parse --show-toplevel || echo $(CURDIR))

ifeq ($(EXECUTOR),singularity)
CONTAINER= $(call ml,Singularity/$(SINGULARITY_VERSION)); singularity
CONTAINER_IMAGE=$(SINGULARITY_ROOT)/$(IMAGE)_$(IMAGE_TAG).sif
CONTAINER_BIND=--bind $(BIND_DIR),/tmp,$(RENV_PATHS_ROOT),$(CURDIR)/Renviron.site:/usr/local/lib/R/etc/Renviron.site
CONTAINER_ENV=--env SQLITE_TMPDIR=/tmp,BIOCPARALLEL_WORKER_NUMBER=$(BIOCPARALLEL_WORKER_NUMBER),GITHUB_PAT=$${GITHUB_PAT}
CONTAINER_OPTIONS= exec $(CONTAINER_BIND) --pwd $(CURDIR) --containall --cleanenv $(CONTAINER_ENV)
CONTAINER_SHELL_OPTIONS = $(patsubst exec,shell,$(CONTAINER_OPTIONS))
$(CONTAINER_IMAGE): 
	cd $(dir $(CONTAINER_IMAGE)) ;\
	$(CONTAINER) pull docker://$(IMAGE):$(IMAGE_TAG)
CONTAIN=true

else ifeq ($(EXECUTOR),docker)
CONTAINER=docker
CONTAINER_IMAGE=$(IMAGE)_$(IMAGE_TAG)
CONTAINER_FLAGS=run \
--mount type=bind,source="$(BIND_DIR)",target="$(BIND_DIR)" \
--mount type=bind,source="/tmp",target="/tmp" \
--mount type=bind,source="$(CURDIR)/Renviron.site",target="/usr/local/lib/R/etc/Renviron.site" \
--workdir="$(CURDIR)" $(IMAGE):$(IMAGE_TAG)
	mkdir -p $(dir $(CONTAINER_IMAGE))
	touch $(CONTAINER_IMAGE)
CONTAINER_SHELL = $(CONTAINER) $(patsubst run,exec -it,$(CONTAINER_FLAGS_INTERACTIVE)) $(CONTAINER_IMAGE) /bin/bash
CONTAIN=true
$(CONTAINER_IMAGE): 
	$(CONTAINER) pull docker://$(IMAGE):$(IMAGE_TAG)
	echo "Proxy for docker image" > $@

else ifeq ($(EXECUTOR),shell)
  $(info " Not using containerisation so results are not necessarily reproducible")

else ifeq ($(EXECUTOR),make)
# This is what we use as internal option - effectively means we're already in the container,
# so no need for any action here.
else
  $(error "# Don't recognise '$(EXECUTOR)' as an executor")
endif

ifeq ($(CONTAIN),true)
Renviron.site: | $(CONTAINER_IMAGE)
optionalRenviron=Renviron.site
containerPrefix=$(CONTAINER) $(CONTAINER_OPTIONS) $(CONTAINER_IMAGE)
else
optionalRenviron=
containerPrefix=
endif

################################################################
# Git-derived variables
################################################################
PROJECT_HOME:=$(shell $(GIT) rev-parse --show-toplevel 2>/dev/null || echo $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TAG := _$(shell $(GIT) describe --tags --dirty=_altered --always --long 2>/dev/null || echo "uncontrolled")# e.g. v1.0.2-2-ace1729a
VERSION := $(shell $(GIT) describe --tags --abbrev=0 2>/dev/null || echo "vX.Y.Z")#e.g. v1.0.2
git-ignore=touch .gitignore && grep -qxF '$(1)' .gitignore || echo '$(1)' >> .gitignore

################################################################
#### Publication 
################################################################
location=outputs

################################################################
#Standard makefile hacks
################################################################
comma:= ,
space:= $() $()
empty:= $()
define newline

$(empty)
endef

# These targets will skip any computationally intensive 'include's
excluded-targets=help clean maintainer-clean R-local R

## Deferred simple expansion - TMPSCRIPT won't exist when first called, then constant thereafter
TMPSCRIPT = $(eval TMPSCRIPT := $$(shell mktemp -u $(staging_dir)/XXXXX))$(TMPSCRIPT)

ifdef NTFY
notification= [[ $$r = 0 ]] && \
curl -H "Title: SLURM submission complete" -H "Tags: +1" -d "Finished $*" ntfy.sh/$(NTFY) || \
curl -H "Title: SLURM submission failed"   -H "Tags: warning" -d "Failed $*: status $$r" ntfy.sh/$(NTFY)
endif

log=2>&1 | tee $2 $(log_dir)/$1.log
# $(call log,test,-a) will append stderr+out to log.test and report to stdout
#log=>$(subst -a,>)$(log_dir)/$1.log 2>&1
# as above, but suppress stdout

################################################################
## R IDE
################################################################
Renviron.site: 
	echo "RENV_PATHS_PREFIX=$(RENV_PATHS_PREFIX)" > $@
	echo "RENV_PATHS_ROOT=$(RENV_PATHS_ROOT)" >> $@
	echo "RENV_PATHS_LIBRARY=renv/library" >> $@

R-local: R-$(RVERSION) ## Create a local shell script that will run R (optional, but helpful for interactive analyses)
R-$(RVERSION): $(CONTAINER_IMAGE)
	@echo "#!/bin/bash" > $@
	@echo 'function babs-R { $(CONTAINER) $(CONTAINER_OPTIONS) $${BABS_SINGULARITY_INTERACTIVE_EXTRAS} $(CONTAINER_IMAGE) R' \$$@  " ; }" >> $@
	@echo 'function babs-Rscript { $(CONTAINER) $(CONTAINER_OPTIONS) $${BABS_SINGULARITY_INTERACTIVE_EXTRAS} $(CONTAINER_IMAGE) Rscript' \$$@  " ; }" >> $@
	@echo 'function babs-conshell {  $(CONTAINER) $(CONTAINER_SHELL_OPTIONS) $${BABS_SINGULARITY_INTERACTIVE_EXTRAS} $(CONTAINER_IMAGE) ; }' >> $@
	@echo "[[ "'$$BASH_SOURCE'" == "'$$0'" ]] && babs-R " \$$@ >> $@
	@$(make_rwx) $@
	@echo 'Using the following extra Singularity options: BABS_SINGULARITY_INTERACTIVE_EXTRAS=$(BABS_SINGULARITY_INTERACTIVE_EXTRAS)'
	@echo 'You may want to customise this (in your bashrc?) to things you need for an interactive environment (e.g. --bind /nemo, --env $$DISPLAY)'

.PHONY: R  rstudio rstudio-slurm
R rstudio rstudio-slurm: Renviron.site

R:
	$(CONTAINER) $(CONTAINER_OPTIONS) $${BABS_SINGULARITY_INTERACTIVE_EXTRAS} $(CONTAINER_IMAGE) R

rstudio-slurm: ## Start RStudio on a node for this project. Can use variables SLURM--*, where *=(partition|cpus-per-task/time/mem). Look for an 'rstudio-server.log' file to appear, with instructions.
	@res=$$(sbatch  \
--partition=$(SLURM--partition) \
--cpus-per-task=$(SLURM--cpus-per-task) \
--time='$(SLURM--time)' \
--mem=$(SLURM--mem) \
$(source_dir)/shell/rstudio-rocker.sh $(CONTAINER_IMAGE) ${SINGULARITY_VERSION} $$(hostname)) ;\
	echo $$res "- please wait until job is allocated, at which point ./rstudio-server.log will appear, explaining how to access the session."

rstudio: ## Start RStudio on this machine for this project.
	. ./$(source_dir)/shell/rstudio-rocker.sh $(CONTAINER_IMAGE) ${SINGULARITY_VERSION}



################################################################
## Standard Goals
################################################################

# Load secrets
##############
# Originally, secret.mk should come from the babs directory.  If
# it's still there, make sure it's up-to-date and then copy it
# here. If a secret.mk file can't be found anywhere, create a dummy
# one out of a template.

$(SELF_DIR)secret.mk: preexisting=$(firstword $(wildcard ../secret.mk ../babs/secret.mk .not-secret.mk))
$(SELF_DIR)secret.mk: babsfile=$(firstword $(wildcard ../../.babs ../.babs .babs))

$(SELF_DIR)secret.mk: $(preexisting) $(babsfile)
	@if [ -n "$(preexisting)" ]; then \
	  sed  's/=.*/=/; /## BABS/,$$d' $(preexisting) > .not-secret.mk ;\
	  cp $(preexisting) $@ ;\
	  if [ -n "$(babsfile)" ]; then \
	    sed  -i '/^setting_/d' $@ ;\
	    sed -r -n 's/^(\s*)(.*)\s*:\s*(.*$$)/setting_\2=\3/p' $(babsfile) >> $@ ;\
	  fi ;\
	else \
	  echo "Unable to find a 'secret.mk' file" ;\
	  exit ;\
	fi
	@if [ "$(preexisting)" = ".not-secret.mk" ]; then \
	    echo "Created a blank '$@' file - please customise it so that the pipeline will run on your system" ;\
	    exit ;\
	fi

.PHONY: print-%
print-%: ## `make print-varname` will show varname's value
	@echo "$*"="$($*)"

V:=1#switches _off_ SILENT mode - delete for SILENT to be default
$(V).SILENT: 

.PHONY: help
help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: `make command` where command is one of: \n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)



shortcut=$(empty)
ifdef redirect_$(location)
shortcut=shortcuts/
endif
pubdir = $(shortcut)$(publish_$(location))
ifeq ($(pubdir),)
pubdir = published
endif

$(pubdir):
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
	mkdir -p $(pubdir)/$(VERSION)

