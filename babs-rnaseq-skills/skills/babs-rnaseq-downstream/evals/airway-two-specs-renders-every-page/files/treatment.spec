## Dexamethasone response, adapted from the single-factor example in
## babs/docs/example_docs/analyse.spec. Untreated is made the reference level,
## and cell line is added to the model as a blocking term (the example's Note 3).

specification(
    sample_sets = list(
        treatment = sample_set(
            subset = TRUE,
            transform = mutate( treatment = relevel( factor(treatment), ref = "Untreated" ) ),
            models = list(
                line_plus_treatment = model(
                    design = ~ cellLine + treatment,
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
