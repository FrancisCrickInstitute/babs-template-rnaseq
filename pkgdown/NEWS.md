# Version 1.13.0
## Major Changes
## Minor Changes
 - fix: Typo in pc weight functionality
 - fix: make 'involved' samples work in rank-deficient designs
 - fix: Conversion of .babs file to docs settings
 - feat: Allow assay-specific influential-samples
# Version 1.12.0
## Minor Changes
 - infra: Use patching to build on infrastructure template
 - feat: Put spec and alignment icons in the quarto sidebar
 - feat: Add differential PC plots
 
# Version 1.11.0
## Minor Changes
 - Sorted differential plots - can use a 'sort' aes in
   plot-profiles. If it matches a column in results, differential
   heatmaps are sorted accordingly. If it's prefixed with a '+', then
   the tree branches are sorted accordingly. 
 - Better contrast naming
 - Differential heatmaps are feature-clustered based only on the
   'involved' samples (which now falls back to the 'influential'
   samples when auto-involvement isn't calculated.
# Version 1.10.0
## Major Changes
 - Change default fastq.gz location prefix to `inputs/sequencing/data`,
   rather than `inputs/sequencing/released`
 - Allow abbreviated spec files, from verbose
   `sample_set(models=list(model(...), model(...))`
   to `sample_set(model(...), model(...))`
## Minor Changes
 - chore: Bring in the updated environment/docker infrastructure
 - chore: Tidy up the load_specs
 - feat: First stage of switching profile_plot and comparison to standard wrap
 - feat: Add mcols to xl files
 - feat: Add dendrogram row-cluster splits
 - fix: Ensure the spec's evaluated/unevaluated objects stay in sync
 - feat: Allow custom fastq dirs
 - fix: Change where we look for fastq files
 - fix: Ensure children of profile_plots and comparisons are valid
 - docs: Update pkgdown handler
# Version 1.9.0
## Major Changes
## Minor Changes
 - Throw error when no config files found
 - Add ability to distribute shiny apps as resources
 - Refactor heatmap plotter
 - Better shiny-explorer. Update to latest template.
 - feat: Generate release notes
 - fix: Remove single quotes from comparison names
 - fix: Ensure plotting dds is refreshed each model
 - feat: robust retag
 - chore: Cleaner wrapping of make targets in sbatch/container
 - feat: Add table to track impact of feature-filtering
 - style: Trim down excess menu levels from sidebar
 - style: Improve figure legends
 - docs: Document the new specfile additions
# Version 1.6.1

## Major Changes
 - Use `extra_assays` in differential plots
 - Allow stratified normalisation
 - add `make retag` to allow versions to be added post-run
 
## Minor Changes
 - Refactor partials for elegance. Add masks - na assays
 - Fix masks breaking plots that don't know about them
 - Improve clustering
 - Latest infrastructure - late-expanded HOME
 - Fix differential heatmaps
 - Add retagging
 - Add alternative assays to the differential analysis
 - Improve scaling/centring in differential plots
 - Update documentation with recent additions
 
# Version 1.4.0

## Major Changes
 - Allow `extra_assays` so that data can be per-feature normalised and
   rescaling/recentring can be customised for the plots.
 - Upgrade to Bioconductor 3.22

## Minor Changes
 - Update documentation metadata
 - Refactor the way the template files are merged
 - Refactor so that local stuff contained in env, not secrets
 - Update the renv lock file

# Version 1.3.0

## Major Changes
 - Improve plots by z-scoring
 - Improve the merge_yml functionality
 - Reimplement partials for speed

## Minor Changes
 - Improve documentation procedure
 - Bring tabs to the exploratory page
 - Improve the page resize toggle
 - Add lightbox
 - Add env files back in
 - Remove some unneeded functions
 - Tidy up roxygen tags
 - Start the model-constraint handler
 - Better handling of env-vars with spaces, eg fullname
 - Refactor for author roles, and move meta to the _quarto.yml
 - Delegate differential module to separate template
 - Auto-generate the secret and shared mks from the central differential one
 - Partial implementation of model constraints
 - Work-around for an R bug
 - Don't over-write the 'design' function with a variable.
 - Fix typo
 - Add facet wrapper
 - Better handling of org packages
 - Tidy up git inclusion

# Version 1.2.0

## Major Changes
 - Rearrange report sections to put all plots related to a
   mode/comparison in the same section
 - Introduce interactive plots
 - Include the 'influential_samples' functionality
 - Output estimated means in supplementary csv's

## Minor Changes
 - Update launchers (indentation)
 - Use the .env that specifies the R docker/singularity images
 - Update infrastructure to v1.2.0 - more/all settings in .env
 - ssh_auth_sock
 - Fix missing vars in env
 - Sync with launcher 1.2.2
 - Fix SSH_AUTH_SOCK needing to be set
 - Fix singularity missing from nfcore module
 - Prep for big import of changes
 - New data-model-profile=type hierarchy
 - Improve categories - probably broken the sidebar though
 - Bring in new template.  Deloop differential partially

# Version 1.0.1

## Major Changes

## Minor Changes
 - Injecting the demo that got missed
 - Launchers are now single-file scripts

# Version 1.0.0

## Major Changes
 - Add differential_subsets functionality
 - Update to v1.0.1 of generic template
 - Slurm refactor - 'make sbatch run' instead of 'make run SUBMIT=true'

## Minor Changes
 - Ensure percentNA is available where applicable
 - Add custom alpha for profile plots
 - Ensure non-estimable 'fully missing' coefs aren't calculated
 - Minor changes
 - Fix the alpha_scale lack of self-reflection
 - Add omnibus for limma
 - Update to latest launchers
 - remove qc_formulae
 - Update launchers. Fix edge-cases in pipeline
 - Fix renv calling
 - Document the differential_subset setting
 - Update pkgdown generation

# Version 0.24.0

## Major Changes
 - Add external genelists

## Minor Changes
 - Add documentation on external genelists
 - Better handling of impute and normalise.
 - Fix long-standing bug  symbol-labelling of MA plots
 - Tidy up "remove nothing" captions

# Version 0.23.0

## Major Changes
 - Add ability to take on summarizedexperiments
 - Update 'differential heatmap baseline' method so that it uses
   emmeans modifications to work directly with constituent factors and
   their levels
 - Remove site Renviron. Users must now set
   `SINGULARITYENV_RENV_PATHS_{LIBRARY,ROOT,PREFIX_AUTO}` in their
   bashrc file

## Minor Changes

# Version 0.22.0

## Major Changes

## Minor Changes
 - Provide isolation script and example spec file
 - Refresh the launchers
 - Update to R4.5.0 and new launcher

# Version 0.20.0

## Major Changes
 - Rationalise the counter/table/plot tracking system
 - Refactor so shared+secret are in all modules
 - Tidy up unneeded packages from renv.lock
 - Switch to generic launchers

## Minor Changes
 - Make the do_tbl conform to the do_plot approach
 - Fix skipping default profile_plot
 - Fix bug in aesthetic overrides when there's only one aesthetic
 - Fix another edge-case for partials with uni-variable models
 - Move to the generic launcher capability

# Version 0.18.1

## Major Changes
Add the profile plots to the exploratory page
Add termNames functionality

## Minor Changes
 Add name-dodging

# Version 0.18.0

## Major Changes
 - Move to the new launchers
 - Add ability to cascade spec features down the spec > dataset > model > comparison hierarchy
 - Add profile-plots to the differential results
 - Add ability to run 'differential' entirely isolated

## Minor Changes
 - Make sure multi-config/spec runs don't overwrite
 - Move to the autogenerated shared.mk
 - Make nfcore responsible for making filepaths that are aligner-invariant
 - Add universal models
 - Add demo of how to run an isolated differential analysis
 - Add a workaround to the polyfill.io unavailability

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
