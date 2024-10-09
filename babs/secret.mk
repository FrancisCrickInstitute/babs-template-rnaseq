# The following are system paths. Please set them to agree with your
# local system. Watch out for trailing spaces, makefiles are very
# 'literal' so a trailing space can get included value

# where .sif's are stored:
SINGULARITY_ROOT=/flask/apps/containers/all-singularity-images
# local renv cache:
RENV_PATHS_ROOT=/nemo/stp/babs/working/software/renv
# your chosen prefix (e.g.'rocker') to keep the pipeline somewhat isolated:
RENV_PATHS_PREFIX=$(subst /,-,$(IMAGE))
# working space for large disposable files:
# Use either the hash set in the .babs file, or the project part of the path
SCRATCH_DIR=/flask/scratch/babs/$(USER)/projects/$(or $(setting_Hash),$(word 9,$(subst /, ,$(CURDIR))))
# Nextflow cache:
NXF_SINGULARITY_CACHEDIR=/flask/apps/containers/all-singularity-images/

## BABS-specific stuff

TEMPLATE_DIR=/nemo/stp/babs/working/bioinformatics/templates

.bp = $(subst /, ,$(setting_Path))
.myname = $(firstword $(subst @,$(space),$(shell $(GIT) config --global user.email || echo $(USER))))
babs_userpath = $(patsubst /camp%,/nemo%,$(subst /working/bioinformatics/,/working/$(USER)/,$(setting_Path)))

redirect_outputs = /nemo/stp/babs/outputs/$(word 7, $(.bp))/$(word 8,$(.bp))/$(.myname)/$(word 9, $(.bp))
redirect_intranet = $(subst /working/,/www/html/internal/users/,$(babs_userpath))
redirect_internet = $(subst /working/,/www/html/external/users/,$(babs_userpath))
url_intranet = $(patsubst /nemo/stp/babs/www/html/internal%,https://bioinformatics.thecrick.org%,$(redirect_intranet))
url_internet = $(patsubst /nemo/stp/babs/www/html/external%,https://bioinformatics.crick.ac.uk%,$(redirect_internet))
repo=https://github.com/BABS-STP/$(setting_Hash)

.PHONY: update-pipeline get-pipeline update-module
excluded-targets += update-pipeline get-pipeline update-module

ifeq ($(version),)
targz=$(TEMPLATE_DIR)/$(setting_Type).tar.gz
genericgz = $(TEMPLATE_DIR)/generic.tar.gz
else
targz=$(TEMPLATE_DIR)/archive/$(setting_Type)-$(version).tar.gz
genericgz=$(TEMPLATE_DIR)/archive/generic-$(version).tar.gz
endif

get-pipeline: update-pipeline
	true

update-pipeline: ## Update the pipeline
	if [ -f "$(targz)" ]; then \
	  $(GIT) stash -m "Stashing state prior to pipeline update" &&\
	  tar -xzf $(targz) -C $(PROJECT_HOME) && \
	  cat $(PROJECT_HOME)/babs/.pipeline-version && \
	  rm -f $(PROJECT_HOME)/babs/*/.pipeline-version;\
	else \
	  if [ -d "$(subst .tar.gz,,$(targz))" ]; then \
	    $(GIT) stash -m "Stashing state prior to pipeline update" &&\
	    rsync -avzp $(subst .tar.gz,,$(targz))  .. ;\
	  else \
	    echo "$(setting_Type) $(version) does not exist" ;\
	  fi \
	fi

update-module: module=$(notdir $(CURDIR))
update-module: ## Update the specific module you're currently using.
	if [ $(module) != babs ]; then \
	  if [ -f "$(targz)" ]; then \
	    $(GIT) stash -m "Stashing state prior to pipeline update" &&\
	    tar -xzf $(targz) babs/$(module) --strip-components=2  && \
	    tar -xzf $(targz) -C ./$(wildcard resources/make/) babs/shared.mk babs/secret.mk --strip-components=1  && \
	    tar -xzf $(targz) babs/.pipeline-version --strip-components=1  && \
	    cat .pipeline-version; \
	  else \
	    if [ -d "$(subst .tar.gz,,$(targz))" ]; then \
	      $(GIT) stash -m "Stashing state prior to pipeline update" &&\
	      rsync -avzp $(subst .tar.gz,,$(targz))/babs/$(module)  . ;\
	    else \
	      echo "$(setting_Type) $(version) does not exist" ;\
	    fi \
	  fi \
	else \
	  echo "Not in a module, so don't know what to update" ;\
	fi

update-pm: ## Update the project management scripts
	$(GIT) stash -m "Stashing state prior to updating .github"
	if [ -f "$(genericgz)" ]; then \
	  tar -xzf $(generic) -C `echo $(CURDIR) | sed 's|\(.*\)/babs/.*|\1/|'` .github;\
	else \
	  rsync -avzp $(TEMPLATE_DIR)/generic/.github/ `echo $(CURDIR) | sed 's|\(.*\)/babs/.*|\1/|'` ;\
	fi


# The following settings come from the .babs file. If that file still
# exists, change the values there and they will propagate here
# automatically.  If there is no longer a .babs file then make the
# changes to the 'secret.mk' file (ideally the top-level one as changes
# to module-level secret.mk may get overwritten by subsequent changes to
# the top-level one)
setting_Type=rnaseq
