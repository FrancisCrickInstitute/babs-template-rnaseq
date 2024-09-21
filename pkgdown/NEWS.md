# Version 0.14.0
## Major Changes
 - Refactor the container/submission so that it doesn't rely on intermediate shell scripts.
## Minor Changes
 - Fix how `BABS_SINGULARITY_INTERACTIVE_EXTRAS` is sent to IDEs.
 - Fix a regression that put nfcore in the differential container.
 - Make the scratch path more traceable
# Version 0.13.0
## Major Changes
 - Add Salmon as an aligner option.  In any config, we can now have an additional `aligner=star_salmon` line (on its own, _not_ as part of the nfcore line)
## Minor Changes
 - Rename the test-fast-forwarders
# Version 0.12.2
## Major Changes
## Minor Changes
Tighten up the documentation on how to work with pre-existing
alignments. Split the documentation so that the intro to specfiles is
separate from the installation/usage docs.

# Version 0.12.1
## Major Changes
## Minor Changes
- Improve the heading layout in the exploratory plots
- Fix problem of not picking up babs file
# Version 0.12.0
## Major Changes
- Fix a bug in the "partial" plots of the exploratory analyses, where the design wasn't set so nothing being was removed. Impact was only in lack of visualisations, rather than anything incorrect being produced.
## Minor Changes

# Version 0.11.4
## Major Changes
## Minor Changes
- Minor fix to pkgdown build process
- Add easy version bumping to the factory
- Fix where update-module files get stored

# Version 0.11.1
## Major Changes
* `make R-local` now produces a file e.g. R-4.3.2 that by doesn't include any additional bindings or environment variables within the container - people are increasingly putting settings in the `HOME` area that broke containment when running interactively. Instead, if you want to include extra access, set the variable `INTERACTIVE_SINGULARITY` in your `~/.bashrc` e.g. `export INTERACTIVE_SINGULARITY='--bind $$HOME/.Xauthority,$$HOME/.Xdefaults,$$HOME/.Xresources,$$HOME/.emacs.d,$$HOME/.ssh --env DISPLAY=$$DISPLAY'`. The double `$` means that those variables will get expanded at runtime, rather than at the point you generate `R-4.3.2` (which would mean that `DISPLAY` would be out of date).


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

## Major Changes

## Minor Changes
* Fig recent bug in the partial PCA

# Version 0.7.0

## Major Changes
* New `qc_formulae` option in the spec-file which allows a more flexible way of removing partial effects in the exploratory visualisation
