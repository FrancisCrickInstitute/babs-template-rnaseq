# Components

 - Docs 
 - Data ingress
 - Nextflow submission
 - Differential analysis
 - Static reporting
 - Interactive reporting
 
# Introduction

The above modules are stages of the analysis. Most of the interesting
ones would be fixed for a specific pipeline (asf-rnaseq,
public-rnaseq, chipseq...) and need no changes by an analyst: the vast
majority of the time an analysis will be entirely determined by what's
in 'docs'.
 
`docs` should (start to) be populated during the proposal stage, and
contain reference material about what analysis is to be done, on what
data, and how. All the other modules flow from that. There is a
[readme](babs/docs/readme.md) giving further details of the required
inputs.

`ingress` is where the `docs` are coralled to be useful to downstream
modules.  For instance, an nfcore samplesheet could be generated in
here based on a query to LIMS and contents of `docs`, or a public
dataset could be downloaded and prepared for analysis.

The downstream modules should be obvious: `differential` to build the
DESeq2 objects and a very ugly static report; `biologics` for
generating explorable interactive results; and `reporting` for Chris'
more elegant static reports.

# Recommended structure of individual modules

So far [differential](babs/differential) is the most feature-rich
module, so I'll focus on using that as an illustrative example.  The
resting state of the module contains: an empty skeleton of an R
project and environment; a settings file `module.mk` that contains
e.g. what the R executible is; and a `makefile` which serves two
purposes.

 - `make build` will get everything ready for differential
analysis: copy any metadata so that the folder is self-contained; find
out where all the other information is (ie the `*.genes.results` that
`nfcore` will put in a fixed location); grab latest versions of R
scripts and functions that will be needed. After the `build` has been
successfully run, the folder is in a self-contained state and won't
notice external changes (e.g. a re-run of nfcore) unless you re-do
another `make build` (a rebuild may not necessary _remove_ everything
from a previous build, so you might end up with multiple spec files if
you rename the one in the `docs` folder between builds, for example.)

- `make run` will do the analysis: produce count matrices in the
  `data` subdirectory of the module; produce the results objects;
  generate a rudimentary html report of the analysis including
  exploratory and inferrential findings.
  
This illustrates the general flow: there's a linear progression of
modules, each of which will bootstrap itself (via a `build`) so it
gathers all its pre-requisites into its own scope, and then execute
itself (via a `run`) to generate its output in a controlled manner so
that other modules downstream of it can gather them for their own
needs.

[nfcore](babs/nfcore) follows the same flow, but is much simpler. The
build process combines information from the samplesheet with the
(possibly multiple) config files to produce nfcore-compliant
samplesheets constrained to the relevant samples; the 'run' process
then coordinates the running of the nfcore pipeline with the
command-line options (gtf, fasta etc) derived from the config files
(which are now local to the nfcore directory.)

# Orchestration of modules
At the top 'babs' level of the hierarchy, there is a makefile.  When a
`make all` is executed at that level, it will descend into each module
in a pre-specified order to carry out a build and run. In this way,
the whole pre-specified analysis should be carried out. A `module.err` file
at this top level will store the commentary of what happened - and on
successful completion of a module it will get turned into a
corresponding `module.log` file.  Within each module, there is likely
to be a `logs` subdirectory which contains individual log files.

Also in this top-level are two makefiles that will be loaded into
every module automatically. `shared.mk` will be under version control,
and includes generic recipes and variables that are likely to be used
by more than one module. It also loads `secret.mk` which contains
site-specific settings that you don't want to put in a public
repository as it may contain file-paths etc.  Both of these files get
automatically duplicated into each module that uses them, if you start
the `makefile` in each directory with an `include shared.mk` at the
start, and have a copy of the recipe for `shared.mk` that is at the
end of, for example, [the `docs` makefile](babs/docs/makefile)
