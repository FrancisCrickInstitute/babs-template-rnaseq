secrets global.mk: % : $(wildcard ../%)
	cp ../$* $@ 2>/dev/null || touch $@

include secrets
include global.mk
include local.mk
.SILENT:

checklist := specfiles experiment_table configs samplesheet

$(checklist): tmp.err tmp.log

tmp.log tmp.err:
	touch $@

.PHONY: build run clean $(checklist)

build: $(checklist) ## Basic check that the contents of the docs folder conforms to requirements
	mv tmp.err report.err
	mv tmp.log report.log
	[ ! -s report.err ]

run:  ## Empty target just to conform to general pattern


specfiles = $(wildcard *.spec)
specfiles: $(specfiles)
ifeq ($(words $(specfiles)),0)
	echo "No *.spec files in the docs directory" | tee -a tmp.err
endif
$(specfiles) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err }


samplesheet = $(wildcard samplesheet.csv)
samplesheet: $(samplesheet)
ifeq ($(words $(samplesheet)),0)
	echo "No samplesheet in the docs directory"
endif
$(samplesheet) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err  }
	head -1 $@ | grep -q "sample" || { echo "$@ does not start with a 'sample'  column" | tee -a tmp.err }
	head -1 $@ | grep -q "sample,fastq_1" || { echo "$@ does not have fastq_1 column after sample" | tee -a tmp.err }


configs = $(wildcard *.config)
configs: $(configs)
ifeq ($(words $(configs)),0)
	echo "No *.config files in the docs directory" | tee -a tmp.err
endif
$(configs) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err }


experiment_table = $(wildcard experiment_table.csv)
experiment_table: $(experiment_table)
ifeq ($(words $(experiment_table)),0)
	echo "No experiment_table.csv in the docs directory" | tee -a tmp.err
endif
$(experiment_table) :
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err }
	head -1 $@ | grep -q "ID" || { echo "experiment_table.csv does not start with an ID column" | tee -a tmp.err}
	head -1 $@ | grep -q "ID,sample_label" || { echo "experiment_table.csv does not have sample_label column after ID - the first unduplicated column after ID, or the ID itself will be used as a label" | tee -a tmp.log }

clean:
	rm -f report.err report.log
