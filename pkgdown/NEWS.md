# Version 0.11.0
## Major Changes
* Change the way version numbers are propagated to the quarto report - the qmd files don't get tagged now (to allow better cacheing - not yet implemented), but instead the figures get the git information inserted into their filenames.
* Rationalise the directory structure - `resources` now contains the auxilliary makefiles and the renv initialisation files.  And extra files either from other modules (such as the spec files and configs) get put into `extdata` along with things like `R.bib`

# Version 0.10.0

## Major Changes
* Split out the `partialise` functionality to be more re-usable as code
* Implement `pkgdown::` documentation
* Refactor the containerisation code so it is available across modules

# Version 0.9.0

## Major Changes
* New `simulate` option in the `docs` folder that generates random data conforming to a spec file and experiment table, and generates a mock report  prior to sequencing being done
## Minor Changes
* Improve model naming in the exploratory report, and add it to the differential page as well
* Fix the rstudio launcher
# Version 0.8.0

## Minor Changes
* Fig recent bug in the partial PCA

# Version 0.7.0

## Major Changes
* New `qc_formulae` option in the spec-file which allows a more flexible way of removing partial effects in the exploratory visualisation
