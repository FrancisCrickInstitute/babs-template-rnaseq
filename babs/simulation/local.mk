Rversion = 4.0.3-foss-2020b
R = module load pandoc/2.2.3.2-foss-2016b  R/$(Rversion) NLopt/2.7.0-GCCcore-11.2.0 OpenBLAS/0.3.18-GCC-11.2.0 zstd/1.4.5-GCCcore-10.2.0; command R


my_counts_dir=inst/extdata/genes.results
nfcore_dir=../nfcore/results
my_metadata=inst/extdata/metadata
geo_dir=nf_work = /nemo/stp/babs/scratch/bioinformatics/projects/${babsid}/geo/


# Where to look for experimental design information
NAME_COLUMN  = "sample_label","name","label","sample","filename","$(meta2asf)"

# Produce a self-contained report (false to link images etc)
contained    = FALSE

# Git variables
TAG = $(shell $(GIT) describe --tags --dirty=_altered --always --long)# e.g. v1.0.2-2-ace1729a
VERSION = $(shell $(GIT) describe --tags --abbrev=0)#e.g. v1.0.2

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
