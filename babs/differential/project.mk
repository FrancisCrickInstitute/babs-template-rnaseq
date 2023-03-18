################################################################
## PARAMETERS
################################################################
##
## Overall project parameters (shared, or section-specific).  The
## variable name will be used as the field name - make sure you add
## them to the relevant `(section)?_param_names` 'index' of
## parameters, otherwise the pre-processor won't know to inject them.
################################################################

res_dir = $(RESULTS_DIR)/$(VERSION)

## Let later processes know which of those to include in every section -
## needs to be stored in the `_param_names` variable:
_param_names = res_dir

################################################################
## SECTION PARAMETERS
################################################################
## List of sections
## These will get used to pick up script names, and  yml metadata,
## so name everything in the 'source-dir' (`./building-blocks` by default)
## after one one of these
sections=00_init 01_analyse

## which need to have the script pulled from DESdemonA templates
template_scripts=$(source_dir)/00_init.qmd $(source_dir)/01_analyse.qmd

## Can use the following, but it will be in glob order
#sections = $(filter-out index,$(patsubst $(source_dir)/%.qmd,%,$(wildcard $(source_dir)/*.qmd)))

## section specific variables
## `section`_param_names will determine which parameters get included
## every page of that section
## Not necessary that each section has params

00_init_param_names = file_col name_col
file_col = $(metadata_id_column)


################################################################
## SECTIONS (ignore)
################################################################
##
## Section handling pre-amble
## Need to put this here so that any section-to-section
## dependencies can be put here also, but oughtn't need
## to change any of the underlying logic - so perhaps skip
## to the 'Section-to-section dependencies' 
################################################################
makefiles=$(patsubst %,$(staging_dir)/%.mk,$(sections))

## These makefiles will create a variable for each section, that lists the pages in
## that section.
include $(makefiles)

all_params=$(call params-of-section,) -P qmd_name:$(script)
## Set up dependencies and variables for each section
## The variables will contain the section_qmds and section_htmls
## The dependencies will contain the original qmd script and the
## target-specific params variable
## (`section-dependency-template` from makefile)
$(foreach section,$(sections),$(eval $(call section-dependency-template,$(section))))
## Collate all the section files together
qmds=$(strip $(foreach section,$(sections),$($(section)_qmds)))
html_reports=$(strip $(foreach section,$(sections),$($(section)_htmls)))

################################################################
## Section-to-section dependencies
################################################################
## If certain reports need to be written before others.
## For 'make render' we rely on the linear progression through the sections,
## but for 'make pages' we can specify e.g.
################################################################

$(01_analyse_htmls): $(00_init_htmls)

