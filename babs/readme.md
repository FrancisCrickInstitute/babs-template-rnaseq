# Components

 - Docs 
 - Data ingress
 - Nextflow submission
 - Differential analysis
 
# Introduction

Whatever directory you are in, typing `make` at the command line is
equivalent to `make help` and will give a reminder of the subcommands
that are available to you.

The above modules are stages of the analysis. Most of the interesting
ones would be fixed for a specific pipeline (rnaseq, chipseq...) and
their corresponding directory should need no changes by an analyst:
the vast majority of the time an analysis will be entirely determined
by what is in `docs`.
 
`docs` should (start to) be populated during the proposal stage, and
contain reference material about what analysis is to be done, on what
data, and how. All the other modules flow from that. There is a
[readme](babs/docs/readme.md) giving further details of the required
inputs.

`ingress` is where the files from `docs` are coralled to, to be useful
to downstream modules.  For instance, an nfcore samplesheet could be
generated in here based on a query to LIMS and contents of `docs`, or
a public dataset could be downloaded and prepared for analysis.

The downstream modules should be obvious: `nfcore` to run the nfcore
RNASeq pipeline, `differential` to build the DESeq2 objects and a
static report.


# Recommended structure of individual modules

So far [differential](babs/differential) is the most feature-rich
module, so I'll focus on using that as an illustrative example.  The
initial state of the module contains: an empty skeleton of an R
project (split into an `R` folder which contains function definitions,
and a `resources` folder which contains template markdown
documents) and environment; a settings file `module.mk` that contains
e.g. what the R executable is; and a `makefile` which serves two
purposes.

The first time this makefile is activated with `make run` in the
differential folder for a project, the differential folder will
'realise' that it needs a spec-file from the docs folder (in the
terminology of make, it has a _prerequisite_ on a file in the docs
folder), and so copy it. It also realises it needs a counts file from
the nfcore folder, so it will attempt to copy it. But the nfcore
folder will postpone that copying because the counts don't exist yet!
So it will itself detect that it needs information from the ingress
folder, which in turn consults the docs folder...

On subsequent `make run`s, it should realise it has everything it
needs, but will scan back up the dependencies, so if a spec file in
the docs folder has changed (and is more recent than the one in the
differential folder) that will propogate into the differential
folder. An important aspect is that after everything had run through
successfully, it should be possible to share just, say, the
differential folder and for everything to work. Initially I thought
that meant we had to go with the two stage 'build + run' approach, but
I've figured a work-around: if the folder that ought to contain the
original source material (e.g. docs) no longer exists, then no
dependencies should be taken on it. This work-around means that as
long as things run through once, we are subsequently free to either
analyse with all the component directories in place (in case we make a
change that e.g. means nfcore needs to be re-run), or we can chop off
the final stage of the analysis as an entirely self-contained
directory (the only criterion being that the directory is not located
alongside other directories that share a name of one of the original
siblings, such as `docs` as that will confuse things!)
  
This illustrates the general flow: there's a linear progression of
modules, each of which will bootstrap itself so it gathers all its
pre-requisites into its own scope, and then generate all its output in
a controlled manner so that other modules downstream of it can gather
them for their own needs.

[nfcore](babs/nfcore) follows the same flow, but is much
simpler. `make run` here will first gather the samplesheet and
alignment configuration files from `docs` (via `ingress`) and make
them nfcore-compliant. It will then proceed to run the nfcore RNASeq
pipeline based on the information it has gathered.

# Orchestration of modules

At the top 'babs' level of the hierarchy, there is another makefile.
When a `make all` is executed at that level, it will descend into the
ultimate (ie `differential`) folder and do a `make run`. In this way,
the whole pre-specified analysis should be carried out. But if you
only want the results of the nfcore, then `make nfcore` in the `babs`
folder will suffice (so `make all` at this top level is directly
equivalent to `make differential`).

A `*.err` file at this top level will store the commentary of what
happened - and on successful completion of a module it will get turned
into a corresponding `module.log` file.  Within each module, there is
likely to be a `logs` subdirectory which contains individual log
files.

Also in this top-level are two makefiles that will be loaded into
every module automatically. `shared.mk` will be under version control,
and includes generic recipes and variables that are likely to be used
by more than one module. It also loads `secret.mk` which contains
site-specific settings that you don't want to put in a public
repository as it may contain file-paths etc.  Both of these files get
automatically duplicated into each module that uses them, to maintain
the ability to cleave a folder away from the whole pipeline once it
has been run.
