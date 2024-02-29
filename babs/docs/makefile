secrets : $(wildcard ../secrets)
	if [ -f ../secrets ]; then cp $< $@; else touch $@; fi

global.mk: $(wildcard ../global.mk)
	if [ -f ../global.mk ]; then cp $< $@; else touch $@; fi

include secrets
include global.mk

.SILENT:

specfiles = $(wildcard *.spec)
samplesheet=$(wildcard samplesheet.csv)
configs = $(wildcard *.config)
experiment_table = $(wildcard experiment_table.csv)

.PHONY: build run clean 

run:  ## Empty target just to conform to general pattern

# Logic is to use existence of non-empty report.err as a flag for
# problem.  On any build, put any problems in tmp.err, and at the end
# we reflect anything generated into the report.err _and_ make sure
# tmp.err is no longer present to allow future builds a clean state.

# Any 'build' prerequisites that can potentially be constructed, leave
# as literal strings rather than macros. But also have a wildcard
# macro (e.g. 'samplesheet' above) so that the behaviour can be
# conditional upon existence or not of a pre-written one.

build: $(specfiles) samplesheet.csv $(configs) $(experiment_table) ## Basic check that the contents of the docs folder conforms to requirements
	$(GIT) add ../.pipeline-version ../.gitignore ../makefile ../global.mk ../readme.md global.mk
	$(GIT) commit -m "Add top-level pipeline files" || true
	[ -n "$(specfiles)" ] || echo "No *.spec files in the docs directory" | tee -a tmp.err
	[ -n "$(configs)" ] || echo "No *.config files in the docs directory" | tee -a tmp.err
	[ -n "$(experiment_table)" ] || echo "No experiment_table.csv in the docs directory" | tee -a tmp.err
	[ -f tmp.err ] && mv tmp.err report.err || rm -f report.err
	[ -f tmp.log ] && mv tmp.log report.log || touch report.log
	[ ! -s report.err ]

ifneq ($(specfiles),)
$(specfiles) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err }
endif

ifneq ($(samplesheet),)
samplesheet.csv:
	head -1 $@ | grep -q "^sample,fastq_1,fastq_2" || { echo "$@ has incorrect header" | tee -a tmp.err }
	[ $(word 1,$(shell wc -l $@)) -ge 2 ] || { echo "@ has only one line" | tee -a tmp.err }
else
limsid=$(subst asf-,,$(subst lims-,,$(setting_Lims)))
lab-sci=$(word 2,$(subst /projects/, ,$(dir $(setting_Path))))
fqfiles=/nemo/stp/babs/inputs/sequencing/released/$(lab-sci)$(limsid)/primary_data/*/fastq/*_R1_001.fastq.gz
samplesheet.csv : $(wildcard ${fqfiles})
	if [ "$(words $(wildcard ${fqfiles}))" == "0" ] ;\
	  then echo "Couldn't find fastq files in " ${fqfiles} | tee -a tmp.err;\
	else echo "sample,fastq_1,fastq_2" > $@;\
	  for r1 in ${fqfiles}; do \
	    echo -n $$(basename $$r1) | sed 's/_.*/,/' >> $@ ;\
	    echo -n "$$r1," >> $@ ;\
	    r2=`echo $$r1 | sed 's/_R1_/_R2_/'` ;\
	    if [ -f "$$r2" ];\
	      then echo $$r2 >> $@ ;\
	      else echo "" >> $@ ;\
	    fi ;\
	  done ;\
	fi	
endif


ifneq ($(configs),)
$(configs) : 
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err }
endif


ifneq ($(experiment_table),)
$(experiment_table) :
	[[ -s "$@" ]] || { echo "$@ is empty" | tee -a tmp.err }
	head -1 $@ | grep -q "^ID" || { echo "experiment_table.csv does not start with an ID column" | tee -a tmp.err}
	head -1 $@ | grep -q "ID,sample_label" || { echo "experiment_table.csv does not have sample_label column after ID - the first unduplicated column after ID, or the ID itself will be used as a label" | tee -a tmp.log }
endif


clean:
	rm -f report.err report.log
