specification(
    sample_sets = list( 
	all = sample_set(
            subset = TRUE,
	    transform = mutate(
		Genotype=factor(as.character(Genotype,
					     levels=c("Uninfected","WT", "Mut"))),
		Timepoint=factor(as.character(Timepoint,
					      levels=c("30m", "12h")
					     ))
	    ),
	    models = list(
		M1 = model(
		    design = ~ Genotype * Timepoint,
		    comparisons = list(
			mult_comp( revpairwise ~ Genotype | Timepoint),
			mult_comp( revpairwise ~ Timepoint | Genotype),
			mult_comp( revpairwise ~ Timepoint + Genotype, interaction=TRUE),
			overall_TG=~Genotype + Timepoint
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
