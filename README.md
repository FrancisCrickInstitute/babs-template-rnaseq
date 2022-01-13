# Components

 - Docs 
 - Config
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
in 'docs', and occasionally extra information in 'config'
 
`docs` should (start to) be populated during the proposal stage, and
contain reference material about what analysis is to be done, on what
data, and how. All the other modules flow from that.

`config` could contain global configuration settings (where things are
in CAMP, base URLs of web servers etc).

`ingress` is where the `docs are coralled to be useful to downstream
modules.  For instance, an nfcore samplesheet could be generated in
here based on a query to LIMS and contents of `docs`, or a public
dataset could be downloaded and prepared for analysis.

The downstream modules should be obvious: `differential` to build the
DESeq2 objects and a very ugly static report; `biologics` for
generating explorable interactive results; and `reporting` for Chris'
more elegant static reports.

So far [differential](babs/differential) is the most integrated
module, so I'll focus on using that as an illustrative example.  The
resting state of the module contains: an empty skeleton of an R
project and environment; a settings file `local.mk` that contains
e.g. what the R executible is; and a `makefile` which serves two
purposes.

 - `make bootstrap` will get everything ready for differential
analysis: copy any metadata so that the folder is self-contained; find
out where all the other information is (ie the `*.genes.results` that
`nfcore` will put in a fixed location); grab latest versions of R
scripts and functions that will be needed.  It will also then build a
shell script bootstrap.sh that contains everything it is about to do.

- `make all` will do the analysis: produce count matrices in the
  `data` subdirectory of the module; produce the results objects;
  generate a rudimentary html report of the analysis including
  exploratory and inferrential findings.
  
This illustrates the general flow: there's a linear progression of
modules, each of which could bootstrap itself so it gathers all its
inputs into its own scope, and then execute itself to generate its
output in a controlled manner so that other modules downstream of it
can gather them for their own needs.

[nfcore](babs/nfcore) contains an example implementation of how that
could work - I think others are making a more considered approach to
this so this is perhaps subject to change.

## Sources of information

Most of the data is obvious, but one novely is the idea of a
`XYZ.config` file, which gives us the change to add missing
information:

```
$ less mouse.config

ended=single
genome=GRCm38
species=Mus musculus
type=RNA-Seq
stranded=reverse
org.db=org.Mm.eg.db
```

This augments the data from LIMS, by getting naturally joined to it
(so if the LIMS data had fields `type` and `species` and some rows
that took values "RNA-Seq" and "Mus musculus", then those rows would
get the extra corresponding annotation).  It might be possible to do
without this if LIMS provides all necessary information, but it is
useful to maintain the option.  Similarly, we will usually need at
most one such config, but there may be cases where different samples
need to be run with different sets of nfcore parameters, and multiple
config files can be used for this. If we set a common optional `group-as=`
value for such configs, then the differential analysis will attempt to
`cbind` the counts; for e.g. different organisms in the same
experiment then they ought to be kept separate (which is the default
if the group-as is not present)
