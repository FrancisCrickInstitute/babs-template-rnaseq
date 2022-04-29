samplesheet_id_column := sample # which column from the ASF csv to use in nf-core.  Maybe sample_name
metadata_id_column := sample_name

babsid=$(shell sed -n  "s/ *Hash: *//p" ../../.babs)
babsproject=$(shell sed -n  "s/ *Project: *//p" ../../.babs)

#Executibles (can be overridden in local.mk's)
NEXTFLOW := ml purge; ml Nextflow/21.10.3; ml Singularity/3.4.2; ml CAMP_proxy; nextflow
R := module load pandoc/2.2.3.2-foss-2016b;  module load R/4.0.3-foss-2020a; command R 
SQLITE := ml SQLite/3.36-GCCcore-11.2.0; sqlite3

#Debugging tool - `make print-varname` will show variable's value
print-%: ; @echo $*=$($*)

#Set V=true to suppress silent mode
$(V).SILENT:

#Standard makefile hacks
comma:= ,
empty:=
space:= $(empty) $(empty)
