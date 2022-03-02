nf_work = /camp/stp/babs/scratch/bioinformatics/projects/${babsid}/nfcore/
nf_cache_dir = /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.4/

NEXTFLOW = ml purge; ml Nextflow/21.10.3; ml Singularity/3.4.2; ml CAMP_proxy; nextflow
