nf_options = -profile crick -resume -r 3.10.1

SINGULARITY_MODULE=Singularity/3.6.4

SQLITE_MODULE=SQLite/3.42.0-GCCcore-12.3.0
SQLITE = $(call ml,$(SQLITE_MODULE)); sqlite3

NEXTFLOW_MODULE=Nextflow/23.10.0
NEXTFLOW = $(call ml,$(NEXTFLOW_MODULE)); $(call ml,$(SINGULARITY_MODULE)); nextflow

NXF_SINGULARITY_CACHEDIR=/flask/apps/containers/all-singularity-images/
SCRATCH_DIR=/flask/scratch/babs/$(or ${USER},$(shell whoami))/projects
