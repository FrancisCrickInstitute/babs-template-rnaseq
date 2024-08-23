SINGULARITY_ROOT = /flask/apps/containers/all-singularity-images/
RENV_PATHS_ROOT = /nemo/stp/babs/working/software/renv
RENV_PATHS_PREFIX=rocker
TEMPLATE_DIR = /nemo/stp/babs/working/bioinformatics/templates
SCRATCH_DIR = /flask/scratch/babs/bioinformatics/projects/$(or $(setting_Hash),$(USER))/
NXF_SINGULARITY_CACHEDIR = /flask/apps/containers/all-singularity-images/

## BABS-specific stuff

.bp = $(subst /, ,$(setting_Path))
.myname = $(firstword $(subst @,$(space),$(shell $(GIT) config --global user.email || echo $(USER))))
babs_userpath = $(patsubst /camp%,/nemo%,$(subst /working/bioinformatics/,/working/$(USER)/,$(setting_Path)))

redirect_outputs = /nemo/stp/babs/outputs/$(word 7, $(.bp))/$(word 8,$(.bp))/$(.myname)/$(word 9, $(.bp))
redirect_intranet = $(subst /working/,/www/html/internal/users/,$(babs_userpath))
redirect_internet = $(subst /working/,/www/html/external/users/,$(babs_userpath))
url_intranet = $(patsubst /nemo/stp/babs/www/html/internal%,https://bioinformatics.thecrick.org%,$(redirect_intranet))
url_internet = $(patsubst /nemo/stp/babs/www/html/external%,https://bioinformatics.crick.ac.uk%,$(redirect_internet))
repo=https://github.com/BABS-STP/$(setting_Hash)

.PHONY: update-pipeline get-pipeline

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
	    tar -xzf $(targz) babs/shared.mk babs/secret.mk babs/.pipeline-version -C .. --strip-components=1 && \
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

babsfile?=../.babs

ifneq ($(wildcard $(babsfile)),)
.PHONY: secret.mk
secret.mk: 
	if [ -f $(babsfile) ]; then \
	  sed  -i '/^setting_/d' $@ ;\
	  sed -r -n 's/^(\s*)(.*)\s*:\s*(.*$$)/setting_\2=\3/p' $(babsfile) >> $@ ;\
	fi
endif


# The following settings come from the .babs file. If that file still
# exists, change the values there and they will propagate here
# automatically.  If there is no longer a .babs file then make the
# changes to the 'secret.mk' file (ideally the top-level one as changes
# to module-level secret.mk may get overwritten by subsequent changes to
# the top-level one)
setting_Type=rnaseq
