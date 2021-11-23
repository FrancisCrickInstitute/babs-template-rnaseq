# Components

 - Directory bootstrapping
 - Nextflow submission
 - Differential analysis
 - Static reporting
 - Interactive reporting
 
 * Directory Bootstrapping
 
 This could be done with e.g. [CookieCutter](https://github.com/cookiecutter/cookiecutter)
 
```
makefile
.babs
.git/
docs/
docs/proposal.md
docs/metadata.txt
docs/config.txt
docs/analysis.spec
first_pass/
first_pass/nf_core/
first_pass/differential/
first_pass/results/
first_pass/outputs/
sequencing/
```

`docs` should be populated during the proposal stage. The `makefile`
or other build tool should be able to run on this state, and populate the
directories with the necessary scripts to analyse the data and also
run those scripts to generate the output (both the scientist-viewable
reports, and the bioinformatician-consumable data objects).


# Nextflow submission
`make nfcore` should generate an nf-core samplesheet and a shell script
to run nfcore with the relevant library parameters, and then run that
script.

The state after running this part of the build would be:

```
sequencing/links_to_the_relevant_files
first_pass/nf_core/
first_pass/nf_core/samplesheet.txt
first_pass/nf_core/run.sh
first_pass/results/versionID/*.genes.counts etc
 
```

# Differential analysis
`make desdemona` should generate R scripts, install a `renv`:

```
first_pass/differential/
first_pass/differential/00_init.r
first_pass/differential/01_analyse.r
first_pass/differential/R-4.0.3
first_pass/differential/R.bib
first_pass/differential/renv
first_pass/differential/renv.lock
first_pass/differential/.Rprofile
first_pass/differential/inst/extdata/analysis.spec
first_pass/differential/inst/extdata/metadata.txt
```

and then run the scripts to produce the outputs:

```
first_pass/differential/data/dds.(rds|rda)
first_pass/differential/data/{{analysis}}.(rds|rda)
first_pass/differential/#other stuff to make this a package
first_pass/results/versionID/{{analysis}}.html
first_pass/results/versionID/{{genelist}}.xlsx
```

# Static Reporting

# Dynamic Reporting
