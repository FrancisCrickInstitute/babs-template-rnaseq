## An analysis spec file defines the statistical contrasts used in the BABS RNA-seq analysis pipeline.
## Full documentation can be found here https://bioinformatics.thecrick.org/babs/working-in-babs/analysis/desdemona/
## Below are examples of standard specs. Please delete and edit as appropriate.

## Single factor pairwise analysis.
## Note 1. In the subset element of the list, we select all samples. A different conditional statement can be added here to select specific samples. 
## Note 2. In the transform element of the list we can mutate meta data columns using the tidyverse syntax.
##         Here we relevel the treatment factor to set the appropriate control group.
##         If it is necessary to change multiple columns, use the syntax `transform=mutate(x=..., y=...)` - it is
##         _not_ possible to have multiple separate `transform`s.
## Note 3. The model. Here we model the treatment effect. Batch effect terms can be added here e.g. ~ batch + treatment.
##         The name (here 'simple') is arbitrary - you could chose 'M1', or some transliteration of the terms in the formula
## Note 4. Run all pairwise comparisons within the treatment factor.
#

specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,										## Note 1.
	    transform=mutate( treatment = relevel( treatment, ref = "naive" ) ), 			## Note 2.
            models = list(
                simple = model(
                    design = ~ treatment,                                                              	## Note 3.
                    comparisons = list(
                        mult_comp( revpairwise ~ treatment )                                           	## Note 4.
                    )
                )
            )
        )
    ),
    settings = settings(
        alpha = 0.05,
        lfcThreshold = 0,
        baseMeanMin = 0,
        top_n_variable = 500,
        showCategory = 25,
        seed = 1,
        filterFun = NULL
    )
)

