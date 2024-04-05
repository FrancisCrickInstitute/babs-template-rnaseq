specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,
            models = list(
                simple = model(
                    design = ~ treatment + cellLine,
                    comparisons = list(
                        mult_comp( revpairwise ~ treatment ),
                        mult_comp( revpairwise ~ cellLine )
                    )
                ),
                line = model(
                    design = ~  cellLine,
                    comparisons = list(
                        mult_comp( revpairwise ~ cellLine )
                    )
                ),
                treatment = model(
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
