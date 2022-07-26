include ../global.mk
include local.mk
-include *.config

.PHONY: run build copy publish clean

run: samplesheets run.sh

.PHONY: samplesheets
samplesheets=$(patsubst %,samplesheet_%.csv,$(public))
samplesheets: $(samplesheets)
$(samplesheets): samplesheet_%.csv: results/%/samplesheet/samplesheet.csv
	$(SQLITE) -header -csv  samples.db 'SELECT $(fetchngs_sample_column) AS sample, fastq_1,  fastq_2, "$($*.strandedness)" AS strandedness FROM \'$*\';'



.PHONY: downloads
public=$(patsubst %.public,%,$(wildcard *.public))
downloads=$(patsubst %,results/%/samplesheet/samplesheet.csv, $(public))
sql-union=SELECT * FROM $(firstword $(public)) $(patsubst %,UNION SELECT * FROM '%',$(wordlist 2,$(words $(public)),$(public)))

downloads:$(downloads)
	$(SQLITE) samples.db "CREATE TABLE fastqs AS SELECT * FROM ($(sql-union));"

$(downloads):results/%/samplesheet/samplesheet.csv: %.txt
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	$(NEXTFLOW) run nf-core/fetchngs \
	--input $< \
	--outdir ./results/$*
	-profile crick \
	-w "${nf_work}" \
	-resume \
	-with-tower \
	-r 1.5
	$(SQLITE) samples.db -csv ".import results/$*/samplesheet/samplesheet.csv '$*'"
	$(SQLITE) samples.db 'UPDATE \'$*\' SET fastq_1="../fetch_ngs" || ltrim(fastq_1,".");'
	$(SQLITE) samples.db 'UPDATE \'$*\' SET fastq_2="../fetch_ngs" || ltrim(fastq_1,".");'
	$(SQLITE) samples.db "ALTER TABLE \'$*\' ADD COLUMN _babs_config_file text;"
	$(SQLITE) samples.db 'UPDATE \'$*\' SET _babs_config_file="$*" ;'



################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build
	make -n run > run.sh

build: inputs public_configs samples.db

.PHONY: public_configs
public_configs := $(patsubst ../docs/%.public,%.public,$(wildcard ../docs/*.public))
public_configs: $(public_configs)
$(public_configs): %.public: ../docs/%.public
	cp $< $@
	sed -i 's/^/$*./' $@

.PHONY: inputs
inputs = $(patsubst %.public, %.txt,$(public_configs))
inputs : $(inputs)
$(inputs) : %.txt : ../docs/%.public
	sed -n 's/public_id=*//p' $< > $@


samples.db: 
	rm -f $@
	sqlite3 $@ "VACUUM;"
