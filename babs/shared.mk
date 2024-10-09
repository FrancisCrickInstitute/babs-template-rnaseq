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


# csv file names (excluding ext)
log_dir=logs

.DEFAULT_GOAL=help
SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))


################################################################
# Executables and their versions
################################################################
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
make_rwx = setfacl -m u::rwx

# Environment Variables
BIOCPARALLEL_WORKER_NUMBER=2

################################################################
# Git-derived variables
################################################################
PROJECT_HOME:=$(shell $(GIT) rev-parse --show-toplevel 2>/dev/null || echo $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TAG = _$(shell $(GIT) describe --tags --dirty=_altered --always --long 2>/dev/null || echo "uncontrolled")# e.g. v1.0.2-2-ace1729a
VERSION := $(shell $(GIT) describe --tags --abbrev=0 2>/dev/null || echo "vX.Y.Z")#e.g. v1.0.2
git-ignore=touch .gitignore && grep -qxF '$(1)' .gitignore || echo '$(1)' >> .gitignore


include $(SELF_DIR)secret.mk

################################################################
# Recipes for functionality 
################################################################
excluded-targets += $(pubdir)/$(VERSION)

publish_results=results
publish_intranet=www_internal
publish_internet=www_external
publish_outputs=outputs
location=outputs

shortcut=$(empty)
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
	mkdir -p $<
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

CONTAIN=false#An internal flag
BIND_DIR = $(shell $(GIT) rev-parse --show-toplevel || echo $(CURDIR))

EXECUTOR?=singularity

ifeq ($(EXECUTOR),singularity)
#Sometimes we want to do e.g. env SINGULARITYENV_APPEND_PATH=/stuff - that's what CONTAINER_VARS is for
CONTAINER= $(call ml,Singularity/$(SINGULARITY_VERSION)); $(CONTAINER_VARS) singularity
CONTAINER_IMAGE=$(SINGULARITY_ROOT)/$(IMAGE)_$(IMAGE_TAG).sif
CONTAINER_BIND=--bind $(BIND_DIR),/tmp,$(RENV_PATHS_ROOT),$(CURDIR)/Renviron.site:/usr/local/lib/R/etc/Renviron.site
CONTAINER_ENV=--env SQLITE_TMPDIR=/tmp,BIOCPARALLEL_WORKER_NUMBER=$(BIOCPARALLEL_WORKER_NUMBER),GITHUB_PAT=$${GITHUB_PAT}
CONTAINER_OPTIONS= exec $(CONTAINER_BIND) --pwd $(CURDIR) --containall --cleanenv $(and $(CONTAINER_OVERLAY),--overlay $(CONTAINER_OVERLAY)) $(CONTAINER_ENV)
CONTAINER_SHELL_OPTIONS = $(patsubst exec,shell,$(CONTAINER_OPTIONS))
$(CONTAINER_IMAGE): 
	cd $(dir $(CONTAINER_IMAGE)) ;\
	$(CONTAINER) pull docker://$(IMAGE):$(IMAGE_TAG)
CONTAIN=true

# Persistent overlays - can put include a union filesystem with the underlying image, for e.g extra binaries.
ifdef CONTAINER_OVERLAY
CONTAINER_VARS=env SINGULARITYENV_PREPEND_PATH=/singularity-bin:/singularity-bin/bin
$(CONTAINER_OVERLAY): resources/shell/overlay_$(basename $(notdir $(CONTAINER_OVERLAY))).sh Renviron.site
	$(CONTAINER) overlay create --sparse --size $(or $(CONTAINER_OVERLAY_SIZE),1024) --create-dir /singularity-bin $(CONTAINER_OVERLAY)
	[ ! -f "$<" ] || $(CONTAINER) $(CONTAINER_OPTIONS) $(CONTAINER_IMAGE) /bin/bash $<
endif

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
optionalRenviron=Renviron.site $(CONTAINER_OVERLAY)
containerPrefix=$(CONTAINER) $(CONTAINER_OPTIONS) --env MAKEFLAGS="$(MAKEFLAGS)" $(CONTAINER_IMAGE)
else
optionalRenviron=
containerPrefix=
endif


################################################################
#Standard makefile hacks
################################################################
# These targets will skip any computationally intensive 'include's
excluded-targets += help clean maintainer-clean print-%

comma:= ,
space:= $() $()
empty:= $()
define newline

$(empty)
endef

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

################################################################
## Recipes for calling R/Rstudio
##
################################################################
excluded-targets += R R-local R-$(RVERSION) rstudio rstudio-slurm

.PHONY: R R-local R-$(RVERSION) rstudio rstudio-slurm

R R-$(RVERSION) rstudio rstudio-slurm: $(optionalRenviron)

Renviron.site:  $(CONTAINER_IMAGE)
	echo "RENV_PATHS_PREFIX=$(RENV_PATHS_PREFIX)" > $@
	echo "RENV_PATHS_ROOT=$(RENV_PATHS_ROOT)" >> $@
	echo "RENV_PATHS_LIBRARY=renv/library" >> $@

R-local: R-$(RVERSION) ## Create a local shell script that will run R (optional, but helpful for interactive analyses)
R-$(RVERSION): 
	@echo "#!/bin/bash" > $@
	@echo 'function babs-R { $(CONTAINER) $(CONTAINER_OPTIONS) '$${BABS_SINGULARITY_INTERACTIVE_EXTRAS}' $(CONTAINER_IMAGE) R' \$$@  " ; }" >> $@
	@echo 'function babs-Rscript { $(CONTAINER) $(CONTAINER_OPTIONS) '$${BABS_SINGULARITY_INTERACTIVE_EXTRAS}' $(CONTAINER_IMAGE) Rscript' \$$@  " ; }" >> $@
	@echo 'function babs-conshell {  $(CONTAINER) $(CONTAINER_SHELL_OPTIONS) '$${BABS_SINGULARITY_INTERACTIVE_EXTRAS}' $(CONTAINER_IMAGE) ; }' >> $@
	@echo "[[ "'$$BASH_SOURCE'" == "'$$0'" ]] && babs-R " \$$@ >> $@
	@$(make_rwx) $@
	@echo 'Using the following extra Singularity options: BABS_SINGULARITY_INTERACTIVE_EXTRAS='$${BABS_SINGULARITY_INTERACTIVE_EXTRAS}
	@echo 'You may want to customise this (in your bashrc?) to things you need for an interactive environment (e.g. --bind /nemo, --env $$DISPLAY)'


R:
	@echo "Starting R $(RVERSION) in container $(CONTAINER_IMAGE) with extra options $${BABS_SINGULARITY_INTERACTIVE_EXTRAS} ..."
	@$(CONTAINER) $(CONTAINER_OPTIONS) $(shell echo $${BABS_SINGULARITY_INTERACTIVE_EXTRAS}) $(CONTAINER_IMAGE) R

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

.Rprofile: $(wildcard resources/renv/Rprofile)
	mkdir -p renv
	[ ! -f "$<" ] || $(GIT) mv $< $@ || mv $< $@

renv/activate.R: $(wildcard resources/renv/activate.R)
	mkdir -p renv
	[ ! -f "$<" ] || $(GIT) mv $< $@ || mv $< $@

################################################################
## Generate secrets
################################################################
# Originally, secret.mk should come from the babs directory.  If
# it's still there, make sure it's up-to-date and then copy it
# here. If a secret.mk file can't be found anywhere, create a dummy
# one out of a template.

$(SELF_DIR)secret.mk: preexisting=$(firstword $(wildcard $(PROJECT_HOME)/secret.mk $(PROJECT_HOME)/babs/secret.mk $(SELF_DIR)not-secret.mk))
$(SELF_DIR)secret.mk: babsfile=$(wildcard $(PROJECT_HOME)/.babs)

$(SELF_DIR)secret.mk: $(preexisting) $(babsfile)
	@if [ -n "$(preexisting)" ]; then \
	  cp $(preexisting) $@ ;\
	  if [ -n "$(babsfile)" ]; then \
	    sed  -i '/^setting_/d' $@ ;\
	    sed -r -n 's/^(\s*)(.*)\s*:\s*(.*$$)/setting_\2=\3/p' $(babsfile) >> $@ ;\
	  fi ;\
	else \
	  echo "Unable to find a 'secret.mk' file" ;\
	  exit ;\
	fi
	@if [ "$(preexisting)" = "$(SELF_DIR)not-secret.mk" ]; then \
	    echo "Created a blank '$@' file - please customise it so that the pipeline will run on your system" ;\
	    exit ;\
	fi
