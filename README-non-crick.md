## Introduction

The pipeline was written for internal Crick use, but with portability
as a desirable attribute. There's a lot of convenience functionality
for working on the Crick's system, but a lot of that is optional.
Below I've listed the prerequisites and the known customisation files
below.

## Expected binaries
Version numbers suggested as known to work, but there's probably some
leniency except nextflow
 - nextflow - we're using version 23.10.0, so I'd recommend that is
   the one that is installed
 - rsync (3.13)
 - make (4.4.1)
 - git (2.48.1)
 - sed (4.8)
 - sqlite (3.42.0)
 - docker or singularity

## Necessary Customisations

I'll highlight the files one should look at to configure things for
your site

### `babs/nfcore/module.mk`

```
# We've used release 3.10.1 of the nfcore rnaseq pipeline. Strongly
# recommend sticking with that for the time being
nf_options = -profile -resume -r 3.10.1

# Change if nextflow will be using singularity containers
SINGULARITY_MODULE=Singularity/3.6.4

SQLITE_MODULE=SQLite/3.42.0-GCCcore-12.3.0
# What's the command to call sqlite3 - if installed, just use SQLITE=sqlite3
SQLITE = $(call ml,$(SQLITE_MODULE)); sqlite3

NEXTFLOW_MODULE=Nextflow/23.10.0
# Command to run nextflow - if installed, just use NEXTFLOW=nextflow
NEXTFLOW = $(call ml,$(NEXTFLOW_MODULE)); $(call ml,$(SINGULARITY_MODULE)); nextflow

# Adjust for your system
# Where image caches are stored. e.g. NXF_SINGULARITY_CACHEDIR=./scache
NXF_SINGULARITY_CACHEDIR=/flask/apps/containers/all-singularity-images/
# Where nfcore stores its intermediate files e.g. could be SCRATCH_DIR=./nfcore-intermediate
SCRATCH_DIR=/flask/scratch/babs/$(or ${USER},$(shell whoami))/projects
```

### babs/differential/.env.local

Most of this stays the same, but it's worth customising the following
values/exports. All but the last are cache locations so set them to
initially empty directories on a fast disk.

 - `SINGULARITY_IMAGEDIR`
 - `NXF_SINGULARITY_CACHEDIR`
 - `SINGULARITYENV_RENV_PATHS_ROOT`
 - `SCRATCH_DIR`
 - `SINGULARITY_MODULE` # irrelevant if you're using docker

