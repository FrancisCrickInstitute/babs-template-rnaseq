# Components

 - Directory bootstrapping
 - Nextflow submission
 - Differential analysis
 - Static reporting
 - Interactive reporting
 
# Directory Bootstrapping
 
 This could be done with e.g. [CookieCutter](https://github.com/cookiecutter/cookiecutter)
 
```
makefile
.babs
.git/
docs/
docs/proposal.md
docs/metadata.txt
docs/genomeID.config
docs/analysis.spec
nf_core/
differential/
results/
```

`docs` should be populated during the proposal stage. The `makefile`
or other build tool should be able to run on this state, and populate the
directories with the necessary scripts to analyse the data and also
run those scripts to generate the output (both the scientist-viewable
reports, and the bioinformatician-consumable data objects). 

The idea would be that we could build with e.g. `make simulate` to
test a design before data is in; `make preprocess` to just run
nextflow, `make all` to do everything. We could have a `run=FALSE`
flag to just build the scripts without executing them.

`genomeID.config` can be a set of files that provide variable that
link info that's retrieved from LIMS to information that enables
nextflow and other components to run. For instance, where the genome
files are.


# Nextflow submission
`make nfcore` should generate an nf-core samplesheet and a shell script
to run nfcore with the relevant library parameters, and then run that
script.

The state after running this part of the build would be:

```
sequencing/links_to_the_relevant_files
nf_core/
nf_core/samplesheet.txt
nf_core/run.sh
results/genomeID/*.genes.counts etc
 
```

# Differential analysis
`make desdemona` should generate R scripts, install a `renv`:

```
differential/
differential/00_init.r
differential/01_analyse.r
differential/R-4.0.3
differential/R.bib
differential/renv
differential/renv.lock
differential/.Rprofile
differential/inst/extdata/analysis.spec
differential/inst/extdata/metadata.txt
```

and then run the scripts to produce the outputs:

```
differential/data/dds{{genomeID}}.(rds|rda)
differential/data/{{analysis}}_x_{{genomID}}.(rds|rda)
differential/#other stuff to make this a package
results/{{genomID}}/versionID/{{analysis}}.html
results/{{genomeID}}versionID/{{genelist}}.xlsx
```

# Static Reporting

# Dynamic Reporting
