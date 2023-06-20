.DEFAULT_GOAL=help

# csv file names (excluding ext)
samplesheet_fname=samplesheet
experiment_table = experiment_table
# Column names
samplesheet_id_column := sample
metadata_id_column := ID
name_col = sample_name
V:=1#switches _off_ SILENT mode - delete for SILENT to be default
log_dir=logs

#Executibles (can be overridden in local.mk's)
ml = module is-loaded $1 || module load $1
SINGULARITY_VERSION=3.6.4
NEXTFLOW_VERSION=22.10.3
RVERSION=4.2.2

R=R
NEXTFLOW = $(call ml,Nextflow/$(NEXTFLOW_VERSION)); $(call ml,Singularity/$(SINGULARITY_VERSION)); $(call ml,CAMP_proxy); nextflow
SQLITE = $(call ml,SQLite/3.36-GCCcore-11.2.0); sqlite3
GIT=git

# allow FORCE=true to override 'git' with a message
ifeq ($(FORCE)-$(shell $(GIT) rev-parse --is-inside-work-tree > /dev/null 2>&1),true-)
GIT_OK = echo "Skipping:"
else
GIT_OK = $(GIT)
endif


make_rwx = setfacl -m u::rwx

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

# Git variables
PROJECT_HOME:=$(shell $(GIT) rev-parse --show-toplevel 2>/dev/null || echo $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TAG := _$(shell $(GIT) describe --tags --dirty=_altered --always --long 2>/dev/null || echo "uncontrolled")# e.g. v1.0.2-2-ace1729a
VERSION := $(shell $(GIT) describe --tags --abbrev=0 2>/dev/null || echo "vX.Y.Z")#e.g. v1.0.2
git-ignore=touch .gitignore && grep -qxF '$(1)' .gitignore || echo '$(1)' >> .gitignore


#Standard makefile hacks
comma:= ,
space:= $() $()
empty:= $()
define newline

$(empty)
endef

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
## Standard Goals
################################################################
.PHONY: print-%
print-%: ## `make print-varname` will show varname's value
	@echo "$*"="$($*)"

$(V).SILENT: 

.PHONY: help
help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: `make command` where command is one of: \n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

