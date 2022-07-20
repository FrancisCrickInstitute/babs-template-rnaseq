###################################################################################
# To run just the differential module in isolation, you can uncomment
# the lines marked CUSTOMISED below (by removing the initial '#' symbol)
# Ideally read the MANUAL INSTRUCTIONS that precede such lines.
# Then type `make build` and then `make run`.  This is only necessary if you've
# run nfcore outside of the BABS RNASeq pipeline.
#
# If you're just making changes to, say, the spec files (or adding new ones),
# then you should only ever need to type `make run`, without any changes to this
# file.
###################################################################################

Rversion = 4.0.3-foss-2020b
R = module load pandoc/2.2.3.2-foss-2016b  R/$(Rversion) NLopt/2.7.0-GCCcore-11.2.0 OpenBLAS/0.3.18-GCC-11.2.0 zstd/1.4.5-GCCcore-10.2.0; command R

docs_dir=../docs
confs_dir=../ingress
nfcore_dir=../nfcore/results
# MANUAL INSTRUCTIONS:
# There must be another directory between `nfcore_dir` and star_rsem
# so the above will work in the case of e.g.
# ../nfcore/results/GRCh38/star_rsem/abc123.genes.results
# which is the pipeline standard.
# But if you've run nfcore without that intermediate directory such that
# `/path/to/xxx/yyy/results/star_rsem/abc23.genes.results` is a file then
# uncomment the line at the end of this, and ensure you have a file
# called `./results.config` that contains the line
# `results.org.db=org.Hs.eg.db` or whatever organism you have.
#
#nfcore_dir=/path/to/xxx/yyy#CUSTOMISED


my_counts_dir=inst/extdata/genes.results
geo_dir=nf_work = /camp/stp/babs/scratch/bioinformatics/projects/${babsid}/geo/
my_metadata=inst/extdata/metadata
# MANUAL INSTRUCTIONS:
# I need a file in `my_metadata`_%.csv that is formatted
# according to the 'experiment_table.csv' guidelines (ie ID and sample_label
# as first two columns). That '%' placeholder is the 'zzz' of the
# folder intermediate between `nfcore_dir` and `nfcoredir/zzz/star_rsem`
# and so for the case described in the nfcore_dir instructions above, that
# 'zzz' will be "results", so you might want to rename your experiment_table.csv to
# be `./experiment_table_results.csv`, and uncomment the following line:
#
#my_metadata=experiment_table_results.csv#CUSTOMISED


# Produce a self-contained report (false to link images etc)
contained    = FALSE

# Git variables
TAG = $(shell git describe --tags --dirty=_altered --always --long)# e.g. v1.0.2-2-ace1729a
VERSION = $(shell git describe --tags --abbrev=0)#e.g. v1.0.2

define slurm
#! /usr/bin/bash
#SBATCH --partition=cpu
#SBATCH --time='0-02:00:00'
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --job-name=$(notdir $(CURDIR))
#SBATCH --output=slurm-%x-%A_%a.out
endef
export slurm
