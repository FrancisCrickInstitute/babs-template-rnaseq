.DEFAULT_GOAL=help

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
# Executibles (can be overridden in module.mk's)
################################################################
## Versions
SINGULARITY_VERSION=3.11.3
NEXTFLOW_VERSION=23.10.0
RVERSION=4.3.2
BIOCONDUCTOR_VERSION=3.18
## Module loader
ml = module is-loaded $1 || module load $1 || true # ie fall back to true (ie rely on system version if can't load a module)
## Define commands invoked by make
R=R
NEXTFLOW = $(call ml,Nextflow/$(NEXTFLOW_VERSION)); $(call ml,Singularity/$(SINGULARITY_VERSION)); $(call ml,CAMP_proxy); nextflow
SQLITE = $(call ml,SQLite/3.42.0-GCCcore-12.3.0); sqlite3
GIT=git
make_rwx = setfacl -m u::rwx

################################################################
# Standard folder and shortcut names
################################################################
publish_results=results
publish_intranet=www_internal
publish_internet=www_external
publish_outputs=outputs
location=results
docs_dir=../docs
ingress_dir=../ingress
nfcore_dir=../nfcore
diff_dir=../differential


################################################################
## Propagation of docs files
## 'Earliest' presence of a propagated file is taken as definitive.
################################################################
ifneq (${diff_dir},)
alignments=$(patsubst ${diff_dir}/${my_counts_dir}/%,%,$(wildcard ${diff_dir}/${my_counts_dir}/*))
specfiles=$(patsubst $(diff_dir)/%.spec,%,$(wildcard $(diff_dir)/*.spec))
endif
ifneq (${nfcore_dir},)
alignments=$(patsubst $(nfcore_dir)/results/%,%,$(wildcard $(nfcore_dir)/results/*))
endif
ifneq ($(ingress_dir),)
alignments=$(patsubst $(ingress_dir)/%.config,%,$(wildcard $(ingress_dir)/*.config))
specfiles=$(patsubst $(ingress_dir)/%.spec,%,$(wildcard $(ingress_dir)/*.spec))
endif
ifneq (${docs_dir},)
alignments=$(patsubst $(docs_dir)/%.config,%,$(wildcard $(docs_dir)/*.config))
specfiles=$(patsubst $(docs_dir)/%.spec,%,$(wildcard $(docs_dir)/*.spec))
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
SLURM--partition=cpu

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
shortcut=$(empty)
ifdef redirect_$(location)
shortcut=shortcuts/
endif
pubdir = $(shortcut)$(publish_$(location))
ifeq ($(pubdir),)
pubdir = published
endif

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
excluded-targets=help clean maintainer-clean R-local

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

ifndef have-run-shared

################################################################
## Standard Goals
################################################################

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

.PHONY: print-%
print-%: ## `make print-varname` will show varname's value
	@echo "$*"="$($*)"

V:=1#switches _off_ SILENT mode - delete for SILENT to be default
$(V).SILENT: 

.PHONY: help
help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: `make command` where command is one of: \n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

################################################################
# Load secrets
################################################################

# Originally, secret.mk should come from the parent directory.  If
# it's still there, make sure it's up-to-date and then copy it
# here. If a secret.mk file can't be found anywhere, create a dummy
# one out of a template.

secret.mk: $(wildcard ../secret.mk) .not-secret
	@if [ -f ../secret.mk ]; then \
	  $(MAKE) --no-print-directory -C .. secret.mk >/dev/null ;\
	  cp $< $@ ;\
	else \
	  if [ ! -f secret.mk ] ; then \
	    cp .not-secret secret.mk ;\
	    echo "Created a 'secret.mk' file - please customise it so that the pipeline will run on your system" ;\
	    exit ;\
	 fi ;\
	fi
include secret.mk

ifneq ($(wildcard ../.not-secret),)
.not-secret: ../.not-secret
	@cp $< $@
endif

have-run-shared=true
endif
