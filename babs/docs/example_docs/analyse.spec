## An analysis spec file defines the statistical contrasts used in the BABS RNA-seq analysis pipeline.
## Full documentation can be found here https://bioinformatics.thecrick.org/babs/working-in-babs/analysis/desdemona/
## Below are examples of standard specs. Please delete and edit as appropriate.

## Single factor pairwise analysis.
## Note 1. In the subset element of the list, we select all samples. A different conditional statement can be added here to select specific samples. 
## Note 2. In the transform element of the list we can mutate meta data columns using the tidyverse syntax.
##         Here we relevel the treatment factor to set the appropriate control group
## Note 3. The model. Here we modle the treatment effect. Batch effect terms can be added here e.g. ~ batch + treatment
## Note 4. Run all pairwise comparisons within the treatment factor.
#

specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,										## Note 1.
	    transform=mutate( treatment = relevel( treatment, ref = "control" ) ), 			## Note 2.
            models = list(
                pairwise = model(
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
        baseMeanMin = 5,
        top_n_variable = 500,
        showCategory = 25,
        seed = 1,
        filterFun = NULL
    )
)

## Two-factor analysis.
## Here we run pairwise comparisons across each of the factors within the context of the other.
## e.g. In the case of a treatment factor containing treatment and control conditions and a genotype factor containing
##      knockout and wt conditions, treatment vs control comparisons will be run within each of the genotype:wildtype
##      and genotype:knockout groups, and the same for the genotype group comparisons. 
##      (treatment - control|wildtype and treatment - control|knockout.
##
## We also run an interaction analysis to determine changes that are different in one factor when compared to the other.
## e.g. genes that are differential in (treatment - control|wildtype) but not in (treatment - control|knockout).
##   	Here we can say the changes observed between treatment and control in the wildtype group are dependent on the knocked out gene.

## Note 1. We relevel the treatment and genotype factors to set appropriate control groups
## Note 2. The model. Here we define an interaction term between treatment and genotype. Batch effect terms can be added here e.g. ~ batch + treatment * genotype
## Note 3. Run all pairwise treatment comparisons within each genotype group.
## Note 4. Run all pairwise genotype comparisons within each treatment group.
## Note 5. Interaction comparison between treatment and genotype factors.

specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,
            transform=mutate( 	treatment = relevel( treatment, ref = "control" ),			## Note 1.
				genotype = relevel(  genotype, ref = "wildtype" ) ),
            models = list(
                pairwise = model(
                    design = ~ treatment * genotype                                                  	## Note 2.
                    comparisons = list(
                        mult_comp( revpairwise ~ treatment | genotype ),                                ## Note 3.
			mult_comp( revpairwise ~ genotype | treatment ),                                ## Note 4.
			mult_comp( revpairwise+revpairwise ~ treatment + genotype, interaction = TRUE ) ## Note 5.
			
                    )
                )
            )
        )
    ),
    settings = settings(
        alpha = 0.05,
        lfcThreshold = 0,
        baseMeanMin = 5,
        top_n_variable = 500,
        showCategory = 25,
        seed = 1,
        filterFun = NULL
    )
)

## Time-course (single factor)
## Here we run an LRT across the time-point groups as well as pairwise comparisons against t0
## and each consecutive time-point pair across the time-course.

## Note 1. We relevel the time factor to capture the temporal order of the groups.
##         This step is not necessary if the temporal order is the same as the sort order.
## Note 2. The model. Batch effect terms can be added here e.g. ~ batch + time
## Note 3. Run all pairwise comparisons against time-point group t0
## Note 4. Run all consecutive pairwise comparisons across the time-course e.g. t1 - t0, t2 - t1, t3 - t2 ect.
## Note 5. You could imagine comparing the model to a reduced model that includes a batch effect
##         (e.g. design = ~ batch + time,
##               lrt = ~ batch )

specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,
            transform=mutate( time = factor( time, levels = c( "t0", "t1", "t2", "t3" ) ) ),  ## Note 1.  
            models = list(
                pairwise = model(
                    design = ~ time                                                           ## Note 2.
                    comparisons = list(
                        mult_comp(trt.vs.ctrl ~ time, ref="t0") ,                             ## Note 3.
			mult_comp(consec ~ time ),                                            ## Note 4.
			lrt = ~1                                                              ## Note 5.
	            )
                )
            )
        )
    ),
    settings = settings(
        alpha = 0.05,
        lfcThreshold = 0,
        baseMeanMin = 5,
        top_n_variable = 500,
        showCategory = 25,
        seed = 1,
        filterFun = NULL
    )
)

## LRT with interaction and a batch term
## A two-factor multi-condition analysis. This may be a time course with two or more treatment groups as an additional factor.

## Note 1. We relevel the time factor to capture the temporal order of the groups.
##         This step is not necessary if the temporal order is the same as the sort order.
## Note 2. Relevel the factor to set the control group.
## Note 3. The model.
## Note 4. Pairwise time point comparisons against t0 within each treatment group.
## Note 5. Consecutive time point pairwise comparisons within each treatment group.
## Note 6. The LRT reduced model to test the interaction between time and treatment.


specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,
            transform=mutate( time = factor( time, levels = c( "t0", "t1", "t2", "t3" ) ),    ## Note 1.
			      treatment = relevel( treatment, ref = "none", "drug" ) ),       ## Note 2.
            models = list(
                pairwise = model( 
                    design = ~ batch + time + treatment + time * treatment,                   ## Note 3.
                    comparisons = list(
                        mult_comp(trt.vs.ctrl ~ time | treatment, ref="t0"),                  ## Note 4.
			mult_comp(consec ~ time | treatment ),                                ## Note 5.
			mult_comp(revpairwise ~ treatment | time ),
			lrt = ~batch + time + treatment                                       ## Note 6.
	            )
                )
            )
        )
    ),
    settings = settings(
        alpha = 0.05,
        lfcThreshold = 0,
        baseMeanMin = 5,
        top_n_variable = 500,
        showCategory = 25,
        seed = 1,
        filterFun = NULL
    )
)

## Nested designs and missing terms.
## This is where we have different patients or animals associated with different treatment or sample groups. 
## e.g.
##   1. Multiple tumours from the same patient or mouse.
##   2. Multiple blood samples taken from a patient over time.
##   3. Different patients assocaited with different treatment groups.
##
## To account for this design structure in the statistical model fitted by DESeq2 we recode the nested terms
## and then fit the recoded term in the model.
##
## We use the recode_witin() function where the first parameter is the nested term and the second term is the factor the first term is nested in
### e.g. recode_witin( mouse, genotype ) ## mouse is nested within genotype, e.g. there are a set of mice within the the wildtype groupd and a set of mice within the KO group.
#
## We must tell DESDemonA to drop comparisons if there are groups missing in the design. If we dio not do this DESeq2 will give a "Not Full Rank Error"

## Note 1. recode treatment and patient since patient is nested by treatment in this design
## Note 2. Set drop_unsupported_combinations = TRUE to account for the design not being full rank.
## Note 3. Pairwise treatment comparisons.

specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,
            transform = mutate( patient_in = recode_within( patient, treatment ) ),     ## Note 1.
            models = list(
                pairwise = model(
                    drop_unsupported_combinations = TRUE,                               ## Note 2.
                    design = ~ patient_in:treatment + drug,
                    comparisons = list(
                        mult_comp( revpairwise ~ treatment )                             ## Note 3.
                    )
                )
            )
        )
    ),
    settings = settings(
        alpha = 0.05,
        lfcThreshold = 0,
        baseMeanMin = 5,
        top_n_variable = 500,
        showCategory = 25,
        seed = 1,
        filterFun = NULL
    )
)
