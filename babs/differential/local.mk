## Binaries
QUARTO=quarto
R=R
RVERSION=4.2.2

EXECUTOR = singularity

DOCKER = gavinpaulkelly/verse-boost
BIND_DIR = $(shell ${GIT} rev-parse --show-toplevel || echo ${CURDIR})

################################################################
## Directories
################################################################
## Location of qmds and multi-yaml files
source_dir=resources
## Place where qmds will be generated
staging_dir=staging
## place within the staging directory where renders will be placed
RESULTS_DIR = results
#Probably set in 'secrets' file, but if not then:
RENV_PATHS_ROOT ?= ~/.local/share/renv
RENV_PATHS_PREFIX=rocker
#Another 'secret', but in case not:
SINGULARITY_ROOT ?= ./
publish_results=results
publish_intranet=www_internal
publish_internet=www_external
publish_outputs=outputs
location=results

docs_dir=$(strip ../docs)
nfcore_dir=$(strip ../nfcore/results)

my_counts_dir=inst/extdata/genes.results
my_metadata=inst/extdata/metadata
samples_db = samples.db

################################################################
## Placeholders
##
## We need to insert lines into scripts at various places.
## Here, we let 'make' know where we want those injections
## to happen
################################################################
## If we need the filename of the yml file that contains the
## parameters. File won't have the initial `params:`, nor will
## the individual lines be indented
yaml-filename-placeholder=my_params_yml



## Marker in the _quarto above which the sidebar info will be placed
sections-before-line=\#sections get inserted above

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

ifeq (${EXECUTOR},singularity)
CONTAINER= $(call ml,Singularity/3.6.4); singularity
CONTAINER_IMAGE=$(SINGULARITY_ROOT)/$(notdir $(DOCKER))_$(RVERSION).sif
CONTAINER_BIND=--bind $(BIND_DIR),/tmp,$(RENV_PATHS_ROOT),$(CURDIR)/rocker.Renviron:/usr/local/lib/R/etc/Renviron.site
CONTAINER_ENV=--env SQLITE_TMPDIR=/tmp
CONTAINER_FLAGS= exec $(CONTAINER_BIND) --pwd $(CURDIR) --containall --cleanenv $(CONTAINER_ENV)
CONTAINER_FLAGS_INTERACTIVE= exec $(CONTAINER_BIND),$${HOME}/.emacs.d,$${HOME}/.Xauthority --pwd $(CURDIR) --containall --cleanenv $(CONTAINER_ENV),DISPLAY=$${DISPLAY}
CONTAINER_SHELL = $(CONTAINER) $(patsubst exec,shell,$(CONTAINER_FLAGS_INTERACTIVE)) $(CONTAINER_IMAGE)
$(CONTAINER_IMAGE): | rocker.Renviron
	cd $(dir $(CONTAINER_IMAGE)) ;\
	$(CONTAINER) pull docker://$(DOCKER):$(RVERSION)
CONTAINERED=true

else ifeq (${EXECUTOR},docker)
CONTAINER=docker
CONTAINER_IMAGE=$(DOCKER):$(RVERSION)
CONTAINER_FLAGS=run \
--mount type=bind,source="$(BIND_DIR)",target="$(BIND_DIR)" \
--mount type=bind,source="/tmp",target="/tmp" \
--mount type=bind,source="$(CURDIR)/rocker.Renviron",target="/usr/local/lib/R/etc/Renviron.site" \
--workdir="$(CURDIR)" $(CONTAINER_IMAGE)
	mkdir -p $(dir $(CONTAINER_IMAGE))
	touch $(CONTAINER_IMAGE)
CONTAINER_SHELL = $(CONTAINER) $(patsubst run,exec -it,$(CONTAINER_FLAGS_INTERACTIVE)) $(CONTAINER_IMAGE) /bin/bash
CONTAINERED=true
$(CONTAINER_IMAGE): | rocker.Renviron
	$(CONTAINER) pull docker://$(DOCKER):$(RVERSION)
	echo "Proxy for docker image" > $(DOCKER):$(RVERSION)

else ifeq (${EXECUTOR},shell)
  $(info " Not using containerisation so results are not necessarily reproducible")
## Maybe setup different values for R, QUARTO, eg
# R=module load R

else ifeq (${EXECUTOR},make)
# This is what we use as internal option - effectively means we're already in the container,
# so no need for any action here.
else
  $(error "# Don't recognise '${EXECUTOR}' as an executor")
endif




###################################################################################
## To run just the differential module in isolation, you can uncomment
## the lines marked CUSTOMISED below (by removing the initial '##' symbol)
## Ideally read the MANUAL INSTRUCTIONS that precede such lines.
## Then type `make build` and then `make run`.  This is only necessary if you've
## run nfcore outside of the BABS RNASeq pipeline.
##
## If you're just making changes to, say, the spec files (or adding new ones),
## then you should only ever need to type `make run`, without any changes to this
## file.
###################################################################################

## MANUAL INSTRUCTIONS:
## There must be another directory between `nfcore_dir` and star_rsem
## so the above will work in the case of e.g.
## ../nfcore/results/GRCh38/star_rsem/abc123.genes.results
## which is the pipeline standard.
## But if you've run nfcore without that intermediate directory such that
## `/path/to/xxx/yyy/results/star_rsem/abc23.genes.results` is a file then
## uncomment the line at the end of this, and ensure you have a file
## called `./results.config` that contains the line
## `results.org.db=org.Hs.eg.db` or whatever organism you have.
##
#nfcore_dir=/path/to/xxx/yyy#CUSTOMISED


## I need a file in `my_metadata`_%.csv that is formatted
## according to the 'experiment_table.csv' guidelines (ie ID and sample_label
## as first two columns). That '%' placeholder is the 'zzz' of the
## folder intermediate between `nfcore_dir` and `nfcoredir/zzz/star_rsem`
## and so for the case described in the nfcore_dir instructions above, that
## 'zzz' will be "results", so you might want to rename your experiment_table.csv to
## be `./experiment_table_results.csv`, and uncomment the following line:
##
#my_metadata=experiment_table_results.csv#CUSTOMISED
