R = module load pandoc/2.2.3.2-foss-2016b;  module load R/4.0.3-foss-2020a; command R 

my_counts_dir=inst/extdata/genes.results
nfcore_dir=../nfcore/results
my_metadata=inst/extdata/metadata

# What's BABS' experiment table (excluding csv file extention)
BABS_TABLE = experiment_table


# Where to look for experimental design information
NAME_COLUMN  = "sample_label","name","label","sample","filename","$(meta2asf)"

# Produce a self-contained report (false to link images etc)
contained    = FALSE

# Git variables
TAG = $(shell git describe --tags --dirty=_altered --always --long)# e.g. v1.0.2-2-ace1729a
VERSION = $(shell git describe --tags --abbrev=0)#e.g. v1.0.2
