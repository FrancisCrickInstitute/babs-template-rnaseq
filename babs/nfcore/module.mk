nf_options = -profile crick -resume -r 3.26.0

SINGULARITY_MODULE=Singularity/3.11.3
NEXTFLOW_MODULE=Nextflow/25.10.2
NEXTFLOW = $(call ml,$(NEXTFLOW_MODULE)); $(call ml,$(SINGULARITY_MODULE)); nextflow

SQLITE_MODULE=SQLite/3.42.0-GCCcore-12.3.0
SQLITE = $(call ml,$(SQLITE_MODULE)); sqlite3

NXF_SINGULARITY_CACHEDIR=/flask/apps/containers/all-singularity-images/
SCRATCH_DIR=/flask/scratch/babs/$(or ${USER},$(shell whoami))/projects
