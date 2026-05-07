docs_dir?=$(wildcard ../docs)
ingress_dir?=$(wildcard ../ingress)
nfcore_dir?=$(wildcard ../nfcore)
diff_dir?=$(wildcard ../differential)

experiment_table = experiment_table
samplesheet_id_column = sample
metadata_id_column = ID
name_col = sample_name

ifneq ($(diff_dir),)
alignments=$(patsubst $(diff_dir)/extdata/%.config,%,$(wildcard $(diff_dir)/extdata/*.config))
endif
ifneq ($(nfcore_dir),)
alignments=$(patsubst $(nfcore_dir)/results/%,%,$(wildcard $(nfcore_dir)/results/*))
endif
ifneq ($(ingress_dir),)
alignments=$(patsubst $(ingress_dir)/%.config,%,$(wildcard $(ingress_dir)/*.config))
endif
ifneq ($(docs_dir),)
alignments=$(patsubst $(docs_dir)/%.config,%,$(wildcard $(docs_dir)/*.config))
endif
