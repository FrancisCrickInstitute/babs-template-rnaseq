NEXTFLOW = ml purge; $(call ml,Nextflow/22.10.3); $(call ml,Singularity/3.4.2); $(call ml,CAMP_proxy); nextflow

nf_options = -profile crick -resume -r 3.10.1

