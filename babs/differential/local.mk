R := module load pandoc/2.2.3.2-foss-2016b;  module load R/4.0.3-foss-2020a; R 

# which metadata column will match ASF's 'sample' column.
	meta2asf := ID
# Where to look for experimental design information
name_column  := "name","label","sample","filename"
# Produce a self-contained report (false to link images etc)
contained    := FALSE


# Git variables
TAG = $(shell git describe --tags --dirty=_altered --always --long)# e.g. v1.0.2-2-ace1729a
VERSION = $(shell git describe --tags --abbrev=0)#e.g. v1.0.2
