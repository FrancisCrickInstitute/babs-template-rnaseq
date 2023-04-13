################################################################
## GLOBAL PARAMETERS
################################################################
##
## Overall project parameters (shared, or section-specific).  The
## variable name will be used as the field name.
################################################################

res_dir = $(RESULTS_DIR)/$(VERSION)

## Let later processes know which of those to include in every section -
## variable _names_ need to be stored in the `param_names` variable:
param_names = res_dir


################################################################
## SECTIONS AND THEIR PARAMETERS
################################################################
## List of sections
## These will get used to pick up script names, and  yml metadata,
## so name everything in the 'source-dir' (`./building-blocks` by default)
## after one one of these.
sections=00_init 01_analyse 02_enrichment

## Which need to have the script pulled from DESdemonA templates?
template_scripts=$(source_dir)/00_init.qmd $(source_dir)/01_analyse.qmd

## Section-specific variables
## `section`_param_names will determine which parameters get included
## in every page of that section
## Not necessary that each section has params

file_col = $(metadata_id_column)

00_init_param_names = file_col name_col



################################################################
## Section-to-section dependencies
################################################################
## If certain reports need to be written before others.  For 'make
## render' we rely on the linear progression through the sections, but
## for 'make pages' we can specify a `section`_parent variable
################################################################

01_analyse_parent = 00_init_$(ialign)
02_enrichment_parent = 01_analyse_$(ispec)_$(ialign)


################################################################
## GEO settings
################################################################
## For submission to GEO, we need to know the version, spec and
## aligment settings that are to be submitted.
################################################################
geo: version=latest
geo: alignment=$(firstword $(alignments))
geo: spec=$(firstword $(specfiles))
geo_dir=scratch/geo
