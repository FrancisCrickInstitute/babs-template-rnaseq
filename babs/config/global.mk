samplesheet_id_column := sample # which column from the ASF csv to use in nf-core.  Maybe sample_name
metadata_id_column := ID

babsid=$(shell sed -n  "s/ *Hash: *//p" ../../.babs || printf "no-babs-%s-%s" ${USER} `basename ${PWD}`)
babsproject=$(shell sed -n  "s/ *Project: *//p" ../../.babs)

#Executibles (can be overridden in local.mk's)
NEXTFLOW := ml purge; ml Nextflow/21.10.3; ml Singularity/3.4.2; ml CAMP_proxy; nextflow
R := module load pandoc/2.2.3.2-foss-2016b; module load R/4.1.2-foss-2021b; command R
SQLITE := ml SQLite/3.36-GCCcore-11.2.0; sqlite3

#Debugging tool - `make print-varname` will show variable's value
print-%: ; @echo $*=$($*)

#Set V=true to suppress silent mode
$(V).SILENT:

#Standard makefile hacks
comma:= ,
empty:=
space:= $(empty) $(empty)

help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
