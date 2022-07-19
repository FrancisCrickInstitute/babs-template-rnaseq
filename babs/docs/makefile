include ../config/global.mk

checklist := specfiles experiment_table configs asf_samplesheet

.PHONY: build run $(checklist)

build: $(checklist) ## Basic check that the contents of the docs folder conforms to requirements
run:  ## Empty target just to conform to general pattern


specfiles = $(wildcard *.spec)
specfiles: $(specfiles)
ifeq ($(words $(specfiles)),0)
	echo "No *.spec files in the docs directory"
endif
$(specfiles) : 
	[[ -s "$@" ]] || { echo "$@ is empty" ; exit 1 ;  }


asf_samplesheet = $(wildcard asf_samplesheet.csv)
asf_samplesheet: $(asf_samplesheet)
ifeq ($(words $(asf_samplesheet)),0)
	echo "No asf_samplesheet in the docs directory"
endif
$(asf_samplesheet) : 
	[[ -s "$@" ]] || { echo "$@ is empty" ; exit 1 ;  }
	head -1 $@ | grep -q "sample" || { echo "$@ does not start with a 'sample'  column" ; exit 1 ; }
	head -1 $@ | grep -q "sample,fastq_1" || { echo "$@ does not have fastq_1 column after sample" ; exit 1 ; }


configs = $(wildcard *.config)
configs: $(configs)
ifeq ($(words $(configs)),0)
	echo "No *.config files in the docs directory"
	exit 1
endif
$(configs) : 
	[[ -s "$@" ]] || { echo "$@ is empty" ; exit 1 ;  }


experiment_table = $(wildcard experiment_table.csv)
experiment_table: $(experiment_table)
ifeq ($(words $(experiment_table)),0)
	echo "No experiment_table.csv in the docs directory"
	exit 1
endif
$(experiment_table) :
	[[ -s "$@" ]] || { echo "$@ is empty" ; exit 1 ;  }
	head -1 $@ | grep -q "ID" || { echo "experiment_table.csv does not start with an ID column" ; exit 1 ; }
	head -1 $@ | grep -q "ID,sample_label" || { echo "experiment_table.csv does not have sample_label column after ID" ; exit 1 ; }
