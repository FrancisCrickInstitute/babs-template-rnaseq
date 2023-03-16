nf_work = /camp/stp/babs/scratch/bioinformatics/projects/${babsid}/nfcore/

nf_cache_dir = /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.10/

NEXTFLOW = ml purge; $(call ml,Nextflow/22.10.3); $(call ml,Singularity/3.4.2); $(call ml,CAMP_proxy); nextflow

nf_options = -profile crick -resume -r 3.10.1

