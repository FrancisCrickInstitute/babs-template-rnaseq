nf_cache_dir := /camp/apps/misc/stp/babs/nf-core/singularity/rnaseq/3.0/

{% for genome, details in cookiecutter.genomes.items() %}


align_{{genome}}: nfcore/samplesheet_{{genome}}.csv 
	ml purge ;\
	ml Nextflow/20.12.0-edge ;\
	ml Singularity/3.4.2 ;\
	ml CAMP_proxy ;\
	export NXF_SINGULARITY_CACHEDIR="${nf_cache_dir}" ;\
	nextflow run nf-core/rnaseq \
	--input $< \
	--outdir results/nf-core/{{genome}}/ \
	--aligner star_rsem \
	--fasta "{{details.fasta}}" \
	--gtf "{{details.gtf}}" \
	--rsem_index "{{details.rsem_index}}" \
	-w "${nf_work}" \
	-profile crick \
	-resume \
	-with-tower \
	-r 3.0

{% if details.ended == "single" %}
nfcore/samplesheet_{{genome}}.csv: {{ cookiecutter.sample_sheet}}
	awk 'BEGIN {FS=","; OFS=","}; $$7=="RNA-Seq" && $$6=="{{details.species}}" {print $$2,$$3,"","{{details.stranded}}"}; NR==1 {print "sample", "fastq_1", "fastq_2", "stranded"}' $<  > $@
{% else %}
	awk 'BEGIN {FS=","; OFS=","}; $$7=="RNA-Seq" && $$6=="{{details.species}} && $$3~/_R1_/ " {print $$2,$$3,sub(/_R1_/, "_R2_", $$3),"{{details.stranded}}"}; NR==1 {print "sample", "fastq_1", "fastq_2", "stranded"}' $< > $@
{% endif %}

{% endfor %}
