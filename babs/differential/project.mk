################################################################
## GLOBAL PARAMETERS
################################################################
##
## Overall project parameters (shared, or section-specific).  The
## variable name will be used as the field name.
################################################################

res_dir = $(RESULTS_DIR)/$(VERSION)
file_col = $(metadata_id_column)
metadata = $(my_metadata)_${alignment}.csv
counts =  $(my_counts_dir)/${alignment}/

## Let later processes know which of those to include in every section -
## variable _names_ need to be stored in the `param_names` variable:
param_names = res_dir VERSION TAG staging_dir file_col name_col metadata counts


################################################################
## SECTIONS AND THEIR PARAMETERS
################################################################
## List of sections
## These will get used to pick up script names, and  yml metadata,
## so name everything in the 'source-dir' (`./building-blocks` by default)
## after one one of these.
sections=00_init 01_exploratory 02_differential 03_enrichment




################################################################
## Section-to-section dependencies
################################################################
## If certain reports need to be written before others.  For 'make
## render' we rely on the linear progression through the sections, but
## for 'make pages' we can specify a `section`_parent variable
################################################################

01_exploratory_parent = 00_init_$(ialign)
02_differential_parent = 01_exploratory_$(ispec)_$(ialign)
03_enrichment_parent = 02_differential_$(ispec)_$(ialign)


