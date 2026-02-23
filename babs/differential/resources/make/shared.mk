docs_dir?=$(wildcard ../docs)
ingress_dir?=$(wildcard ../ingress)
nfcore_dir?=$(wildcard ../nfcore)
diff_dir?=$(wildcard ../differential)

samplesheet_fname=samplesheet
experiment_table = experiment_table
samplesheet_id_column = sample
metadata_id_column = ID
name_col = sample_name

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
## Things here are typically shared across all phases of the
## analysis. There's originally one gold-reference copy of this file
## that gets copied into each subdirectory (in case the subdirectory
## gets shared by itself some time in the future), so it's recommended
## that any necessary phase-specific changes are put into module.mk,
## which will override things in shared.mk
################################################################
.DEFAULT_GOAL=help

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

# csv file names (excluding ext)
log_dir=logs

################################################################
# Executables and their versions
################################################################

R=R
QUARTO=quarto
GIT=git

## Module loader
ml = [ -z "$1" ] || module is-loaded $1 || module load $1 || true # ie fall back to true (ie rely on system version if can't load a module)
chmod = setfacl -m $2:$3 $1 >/dev/null 2>&1 || chmod $2=$3 $1

################################################################
## Environment Variables
################################################################
# Scan all our .env files
ifneq ($(wildcard ./resources/shell/direnv.sh),)
ENV_FILES := $(shell \
    dir=$(realpath .); \
    while :; do \
        [ -f "$$dir/.env.local.$(USER)" ] && echo "$$dir/.env.local.$(USER)"; \
        [ -f "$$dir/.env.$(USER)" ] && echo "$$dir/.env.$(USER)"; \
	[ -f "$$dir/.env.local" ] && echo "$$dir/.env.local"; \
        [ -f "$$dir/.env" ] && echo "$$dir/.env"; \
        [ "$$dir" = "$$PROJECT_HOME" ] || [ "$$dir" = "/" ] && break; \
        dir=$$(dirname "$$dir"); \
    done | tac\
)

.env.mk: $(ENV_FILES)
	@if [ -f .env.mk ]; then \
	echo "🧹 .env.mk was generated with stale exports."; \
	echo "It has been removed. Please simply re-run make."; \
	rm -f .env.mk; \
	exit 1; \
	fi
	@bash ./resources/shell/direnv.sh $(ENV_FILES) > $@
include .env.mk
endif

NUM_THREADS:=$(or ${SLURM_CPUS_PER_TASK},$(NUM_THREADS),2)
data_transfer_filename?=.data-transfer-rules
export MAKEFLAGS
export SINGULARITYENV_GITHUB_PAT=${GITHUB_PAT}

################################################################
# Git-derived variables
################################################################
PROJECT_HOME:=$(shell $(GIT) rev-parse --show-toplevel 2>/dev/null || echo $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
GIT_BRANCH := $(shell git branch --show-current | sed 's/^main$$//')
VERSION := $(and $(GIT_BRANCH),$(GIT_BRANCH)/)$(shell $(GIT) diff --quiet --ignore-submodules --exit-code	 && \
                     ($(GIT) describe --tags --exact-match 2>/dev/null || printf "unreleased") || \
                     printf "modified") #ie v0.1.2 or unreleased or modified
TAG = _$(VERSION)-$(shell $(GIT) rev-parse --short HEAD 2>/dev/null || echo "uncontrolled")# e.g. v1.0.2-2-ace1729a
git-ignore=touch .gitignore && grep -qxF '$(1)' .gitignore || echo '$(1)' >> .gitignore


################################################################
## Publishing (moving) generated results and providing shortcuts
################################################################

publish_intranet=www_internal
publish_internet=www_external
publish_outputs=outputs
location=outputs

shortcut=$(if redirect_$(location),shortcuts/,)
pubdir = $(shortcut)$(or $(publish_$(location)),published_$(location))

$(pubdir)/$(VERSION):
ifdef redirect_$(location)
	mkdir -p $(redirect_$(location))
	mkdir -p $(shortcut)
	ln -sfn $(redirect_$(location)) $(pubdir)
	[ -z "url_$(location)" ] || echo "<!doctype html><script>window.location.replace('$(url_$(location))/$(VERSION)')</script>" > $(shortcut)$(location).html
endif
	mkdir -p $@
	ln -sfn $(VERSION) $(pubdir)/latest

.PHONY: prepare-rsync
prepare-rsync: ## Prepare for project transfer to another computer, using git and rsync (for files matching patterns in the .data-transfer-rules hidden file)
# 'updateInstead' allows us to push back here
	@git config --local receive.denyCurrentBranch updateInstead
	@echo "Type the following commands on a local terminal (ie NOT a NEMO node)"
	@echo "$$ git clone $(USER)@$(shell hostname -f):$(CURDIR)"
	@echo "You should be able to 'git push' from your local machine back here - but don't make changes in both places!"
	@if [ ! -f "$(data_transfer_filename)" ]; then \
	  echo "No extra files to be transferred - you can set up file $(data_transfer_filename) with contents e.g.";\
	  echo "+ extdata/" ;\
	  echo "+ extdata/**" ;\
	  echo "- *" ;\
	  echo "to selectively transfer extra files with the command (won't work right now - you'll need to 'git add' it!):" ;\
	else \
	  echo "$$ cd $(notdir $(CURDIR)) && make do-sync" ;\
	fi

do-rsync: ## Transfer required non-VC data to your computer from nemo
	@if [ -f "$(data_transfer_filename)" ]; then \
	  rsync -av --filter='merge $(data_transfer_filename)' $$url/ . || echo "Couldn't rsync from $url." ;\
	else \
	 echo $(data_transfer_filename) doesn\'t exist, so no additional transfers have been carried out. ;\
	fi

excluded-targets += prepare-rsync do-rsync

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
BIND_DIR = $(shell git rev-parse --show-toplevel 2>/dev/null || echo $(realpath .))
EXECUTOR?=singularity
renv_root=$(realpath $(or $(SINGULARITYENV_RENV_PATHS_ROOT),$(HOME)/.cache/R/renv))
ifeq ($(EXECUTOR),singularity)
CONTAINER= $(call ml,$(SINGULARITY_MODULE)); singularity
CONTAINER_IMAGE=$(or $(SINGULARITY_IMAGEDIR),$(or $(SINGULARITY_CACHEDIR),$(HOME)/.singularity/cache)/library)/$(sif_file)
CONTAINER_BIND=--bind $(BIND_DIR),/tmp,$(renv_root)
CONTAINER_ENV=--env SQLITE_TMPDIR=/tmp,$\
  OMP_NUM_THREADS=$(NUM_THREADS),OPENBLAS_NUM_THREADS=$(NUM_THREADS),BIOCPARALLEL_WORKER_NUMBER=$(NUM_THREADS),$\
  SLURM_JOB_ID="$${SLURM_JOB_ID}",SLURM_ARRAY_TASK_ID="$${SLURM_ARRAY_TASK_ID}"
CONTAINER_OPTIONS= exec $(CONTAINER_BIND) --pwd $$(realpath .) --containall --cleanenv $(CONTAINER_ENV)
$(CONTAINER_IMAGE):
	env DOCKER_USERNAME="$(or $(DOCKER_USERNAME),$(GITHUB_USERNAME),$(shell git config --get github.user))" \
	DOCKER_PASSWORD=$${DOCKER_PASSWORD-$${GITHUB_PAT}} \
	$(CONTAINER) pull $@ docker://$(docker_image)
	$(call chmod,$(CONTAINER_IMAGE),g,rwx)
	$(call chmod,$(CONTAINER_IMAGE),u,rwx)


else ifeq ($(EXECUTOR),docker)
CONTAINER=docker
CONTAINER_IMAGE=$(IMAGE)$(colon)$(IMAGE_TAG)
CONTAINER_OPTIONS=run \
--mount type=bind,source="$(BIND_DIR)",target="$(BIND_DIR)" \
--mount type=bind,source="/tmp",target="/tmp" \
--mount type=bind,source="$(renv_root)",target="$(renv_root)" --env RENV_PATHS_ROOT=$(renv_root)\
--env SQLITE_TMPDIR=/tmp \
--env BIOCPARALLEL_WORKER_NUMBER=$(NUM_THREADS) \
--env GITHUB_PAT \
--env OMP_NUM_THREADS=${NUM_THREADS} \
--env OPENBLAS_NUM_THREADS=${NUM_THREADS} \
--env MAKEFLAGS="${MAKEFLAGS}" \
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


ifeq ($(CONTAINER),)
optionalContainer=
containerPrefix=
NEED_CONTAINER := false
else
optionalContainer=$(CONTAINER_IMAGE)
containerPrefix=$(CONTAINER) $(CONTAINER_OPTIONS) --env MAKEFLAGS="$(MAKEFLAGS)" $(CONTAINER_IMAGE)
NEED_CONTAINER := true
endif

excluded-targets += docker

################################################################
## SLURM
## 
## Have default but customisable slurm parameters 
################################################################
## By default, run recipes in the usual manner rather than slurm etc.

# Determine if sbatch is needed
ifeq ($(SLURM_JOB_ID),)
  # SLURM_JOB_ID is empty
  ifeq ($(origin sbatch_args),command line)
    NEED_SBATCH := true
  else
    NEED_SBATCH := false
  endif
else
  NEED_SBATCH := false
endif

default_sbatch_args=\
 --time=0-02:00:00\
 --mem=64G\
 --cpus-per-task=8\
 --partition=ncpu\
 --job-name=$(notdir $(CURDIR))-$(firstword $(MAKECMDGOALS))\
 --output=slurm-%x-%A_%a.out

slurm_wrap=$(subst ','\'',$(containerPrefix) make $@ EXECUTOR=make; $(call send_notification,SLURM submission))
squote:='

################################################################
#Standard makefile hacks
################################################################
# These targets will skip any computationally intensive 'include's
excluded-targets += help clean maintainer-clean print-%


# Set up a notifier - If NTFY is an env var, then send a message to the relevant ntfy.sh API endpoint
# else, just echo to terminal

ifeq ($(origin NTFY),environment)
send_notification= [ $$? -eq 0 ] && \
curl -H "Title: $1 complete" -H "Tags: +1" -d "'${MAKECMDGOALS}' in $(CURDIR)" -o /dev/null ntfy.sh/$${NTFY} || \
curl -H "Title: $1 failed"   -H "Tags: warning" -d "'${MAKECMDGOALS}' in $(CURDIR)" -o /dev/null ntfy.sh/$${NTFY}
else
send_notification= [ $$? -eq 0 ] && echo "$1 completed (${MAKECMDGOALS})" || echo "$@ failed (${MAKECMDGOALS})"
endif

comma:= ,
colon:= :
space:= $() $()
empty:= $()

define newline

$(empty)
endef
bslash := \$(empty)


ifeq ($(origin NTFY),environment)
send_notification= [ $$? -eq 0 ] && \
curl -H "Title: $1 complete" -H "Tags: +1" -d "'${MAKECMDGOALS}' in $(CURDIR)" -o /dev/null ntfy.sh/$${NTFY} || \
curl -H "Title: $1 failed"   -H "Tags: warning" -d "'${MAKECMDGOALS}' in $(CURDIR)" -o /dev/null ntfy.sh/$${NTFY}
else
send_notification= [ $$? -eq 0 ] && echo "$1 completed (${MAKECMDGOALS})" || echo "$@ failed (${MAKECMDGOALS})"
endif

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
# $(call envsubst,A B) produces envsubst_A='$(A)' envsubst_B='$(B)' envsubst 'envsubst_$$A envsubst_$$B'
# In shell, this transfers out the values of variables A and B, then calls envsubst on a file provided by stdin which  replaces instances in that file  of '$A' with its value...
envsubst = $(foreach v,$(1),envsubst_$v='$($(v))' )envsubst '$(foreach v,$(1),$${envsubst_$v})'

################################################################
## Recipes for calling R/Rstudio
##
################################################################
excluded-targets += R R-local R-$(RVERSION)

.PHONY: R R-local R-$(RVERSION)
launch-targets=rstudio shiny jupyter http server-info read-envs launch-helper

R-local: R-$(RVERSION) ## Create a local shell script that will run R (optional, but helpful for interactive analyses).

launcher: R-$(RVERSION) ## Create a launcher script that will guide you through the various launcher options
	ln -sfn $< $@

R-$(RVERSION): resources/shell/R-local.sh 
	cp $< $@
	@$(call chmod,$@,u,rwx)
	for i in $(launch-targets); do sed -i -e "\,source $$i.sh,{" -e "r resources/shell/$$i.sh" -e "d" -e "}" $@; done

R:
	@echo "Starting R $(RVERSION) in container $(CONTAINER_IMAGE) ..."
	@$(CONTAINER) $(CONTAINER_OPTIONS) $(CONTAINER_IMAGE) R

launch-%: R-$(RVERSION) ## launch-R launch-rstudio, launch-jupyter, launch-shiny ARGS=Explorer, etc
	BABS_CMD=$* ./R-$(RVERSION) $(ARGS)

admin-launch-%: ##  admin-launch-R, admin-launch-debug  etc will use a temporary workspace. Also passes ARGS
	d=$$(mktemp -d) ;\
	cp  resources/shell/R-local.sh $$d/launcher.sh ;\
	@$(call chmod,$$d/launcher.sh,u,rwx) ;\
	for i in $(launch-targets); do sed -i -e "\,source $$i.sh,{" -e "r resources/shell/$$i.sh" -e "d" -e "}" $$d/launcher.sh; done ;\
	echo "Running in $$d" ;\
	BABS_CMD=$* BABS_LAUNCHER_DIR=$$d $$d/launcher.sh $(ARGS) 2>&1 | tee -a $$d/report.txt

