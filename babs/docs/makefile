checklist := specfiles experiment_table configs proposal

check:clear := $(shell rm -f error.log)

check: $(checklist) ## Basic check that the contents of the docs folder conforms to requirements
	if [[  -s error.log ]] ; then \
	  echo "Errors produced - check error.log" ;\
	else \
	  echo "All seems fine" ;\
	  touch error.log ;\
	fi

.PHONY: check $(checklist)

################################################################
specfiles = $(wildcard *.spec)
.PHONY: $(specfiles)

specfiles: $(specfiles)
ifeq ($(words $(specfiles)),0)
	echo "No *.spec files in the docs directory" | tee -a error.log
endif

$(specfiles) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a error.log ;  }


################################################################
configs = $(wildcard *.config)
.PHONY: $(configs)

configs: $(configs)
ifeq ($(words $(configs)),0)
	echo "No *.config files in the docs directory" | tee -a error.log
endif

$(configs) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a error.log ;  }

################################################################
experiment_table = $(wildcard experiment_table.csv)
.PHONY: $(experiment_table)

ifeq ($(words $(experiment_table)),0)
experiment_table:
	echo "No experiment_table.csv in the docs directory" | tee -a error.log
else
experiment_table: $(experiment_table)
endif

$(experiment_table) :
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a error.log ;  }
	head -1 $@ | grep -q "ID" || echo "experiment_table.csv does not start with an ID column" | tee -a error.log


################################################################
proposal = $(wildcard proposal.docx)
.PHONY: $(proposal)

ifeq ($(words $(proposal)),0)
proposal:
	echo "No proposal.docx in the docs directory" | tee -a error.log
else
proposal: $(proposal)
endif

$(proposal) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a error.log;  }



$(V).SILENT:

help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
