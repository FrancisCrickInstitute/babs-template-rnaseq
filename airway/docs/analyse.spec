specification(
    sample_sets = list(
        D1 = sample_set(
	    name="All",
	    description="All samples included",
            subset = TRUE,
            models = list(
                M1 = model(
		    name="Simple",
		    description="Including treatment and line, so that we can look at either one of those effects
 while accounting for any systematic changes in the other.  But no interaction, so when there is a
modifying effect (of treatment type on the response to line, or vice versa) will be unaccounted for and genes exhibiting
this behaviour will tend not to be selected.  There is no replication (ie no line x treatment combination has more than one sample,
so we have to restrict our model to at most this complexity.",
                    design = ~ treatment + cellLine,
		    profile_plots=list(
			aes(x=cellLine, colour=treatment, group=treatment) ~ .,
			aes(x=cellLine, colour=treatment, group=treatment) ~ . - treatment,
			aes(x=cellLine, colour=treatment, group=treatment) ~ . - cellLine,			
		    ),
                    comparisons = list(
                        mult_comp( revpairwise ~ treatment ),
                        mult_comp( revpairwise ~ cellLine )
                    )
                ),
                M2 = model(
		    name="Line-only",
		    description="Just including a line effect, and totally ignoring treatment.  So any systematic treatment effect
will not be accounted for, and genes exhibiting a change due to treatment will tend not to be selected",
                    design = ~  cellLine,
                    comparisons = list(
                        mult_comp( revpairwise ~ cellLine )
                    )
                ),
                M3 = model(
		    name="Treatment-only",
		    description="Just including a treatment effect, and totally ignoring treatment.  So any systematic differences between lines
will not be accounted for, and genes exhibiting a dependencey on line will tend not to be selected",
                    design = ~ treatment,
                    comparisons = list(
                        mult_comp( revpairwise ~ treatment )
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
