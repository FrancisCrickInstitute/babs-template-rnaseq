secrets global.mk: % : $(wildcard ../%)
	cp ../$* $@ 2>/dev/null || touch $@

include secrets
include global.mk

.SILENT:

checklist := specfiles experiment_table configs samplesheet.csv

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

samplesheet.csv :
	echo "sample,fastq_1,fastq_2" > $@
	proj=$(dir $(call babsfield,Path));\
	asfdir=$${proj/*\/projects\//\/nemo\/stp\/babs\/inputs\/sequencing\/released\/}$(subst asf-,,$(call babsfield,Lims));\
	for r1 in $${asfdir}/primary_data/*/fastq/*_R1_001.fastq.gz; do \
	  echo -n $$(basename $$r1) | sed 's/_.*/,/' >> $@ ;\
	  echo -n "$$r1," >> $@ ;\
	  r2=`echo $$r1 | sed 's/_R1_/_R2_/'` ;\
	  if [ -f "$$r2" ];\
	    then echo $$r2 >> $@ ;\
	    else echo "" >> $@ ;\
	  fi ;\
	done
	if [ "`wc -l $@`" == "1 $@" ];\
	  then echo "Couldn't find fastq files in " $$asfdir | tee -a tmp.err;\
	  rm -f $@;\
	fi	



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
