# Columns of a comparison's `results` table

Every comparison in `data/<spec>_x_<ds>.rds` stores a `results` DataFrame at
`ddsList$sample_sets[[set]]$models[[model]]$comparisons[[comparison]]$results`,
written by `get_result()` in `R/rnaseq.r`. The same columns appear in the
`.xlsx` workbooks.

| Column | Meaning (as computed by `get_result()`) |
|---|---|
| `baseMean` | Mean of normalised counts across the model's samples. For limma/voom fits it is `2^AveExpr`. |
| `log2FoldChange` | Unshrunk effect: the Wald contrast, or for limma the `logFC`. For an LRT/omnibus test it is the DESeq2 value for the last coefficient, which is not meaningful on its own. Use `maxLog2FoldChange` instead. |
| `lfcSE`, `stat` | Standard error and test statistic from DESeq2 (or limma). |
| `pvalue` | Raw p-value. `NA` means a Cook's-distance outlier was flagged. |
| `padj` | Adjusted p-value. With `filterFun = NULL` (the shipped default) this is DESeq2's independent filtering plus Benjamini-Hochberg. With `filterFun = ihw` it is IHW, and a `weight` column is added. `NA` means the gene was removed by independent filtering. |
| `symbol`, `entrez` | Annotation copied from the org.db mapping made in `00_init`. |
| `sig` | `"<= alpha"` when `padj <= alpha`, otherwise `"NS"`. If several `alpha` values are given, there are extra bands such as `"0.05-0.1"`. |
| `class` | For Wald/limma tests: `Up` or `Down` by the sign of `log2FoldChange`, with `*` appended when `padj < alpha` (so `Up*` / `Down*` are the significant genes). For LRT tests: `"A V B"`, the groups with the largest and smallest fitted effect, again with `*` when significant. These override it: `Low Count` (padj NA), `Outlier` (pvalue NA), `Zero Count` (baseMean 0). |
| `maxLog2FoldChange` | LRT only: the largest pairwise difference between the fitted group effects. It is the "effect size" reported for omnibus tests. |
| `shrunkLFC` | Effect size shrunk with ashr: `lfcShrink(type="ashr")` for DESeq2 Wald tests, and `ashr::ash` on `maxLog2FoldChange` (LRT) or on `log2FoldChange` (limma). The enrichment page uses this for GSEA. |
| `shrunkSE` | LRT only: posterior SD from ashr. |

Approach labels printed by `summarise-differential.R` follow `fit_comparison()`:
`Wald` (single DESeq2 coefficient/contrast), `LRT` (comparison given as a
reduced formula), `multiWald (emmeans)` (a `mult_comp()` expanded with emmeans into
several Wald contrasts on a DESeq2 fit), `limma` (the same on a limma fit),
`wald2LRT`, or whatever `approach` the model sets.

The 02 report's methods text always says "IHW". Report the `filterFun` that
was actually in force, which `summarise-differential.R` prints.

## From the report: summary tables and naming


Here we summarise the results of the differential testing. Each
sample-set gets its own table (flick between tabs to choose which),
within which the different models, and their null hypotheses, are
enumerated.

In the 'Significant' column we tally the number of significant
genes (for pairwise comparisons, separated into up or down, where
A-B being labelled up means expression is higher in A; for omnibus
comparisons, a broad categorisation of the most extreme groups, as
described above.) We also tally the total number of genes
exhibiting that behaviour (ie not necessarily statistically
signficant) - these might not always add up to the same value, as
there is an independent filter of low-signal genes whose effect
varies from comparison to comparison.

Our naming convention for a comparison often looks like `A-B|M` -
again, because this is an semi-automated report, this mightn't be
optimal, but the rationale is `A-B` refers to the two experimental
conditions being compared (a 'upward' fold change will be reported
if the expression is higher in `A` than it is in `B`). The `|M` part
refers to the fact that we may have looked at that `A-B` comparison
conditional upon some other variable (which in this example takes the
value `M`):  anything before the `|` symbol identifies the
experimental conditions that are being contrasted, and the part after
the `|` identifies any stratification/conditioning of the data.

In the p-value diagnostic figure (fig-summaryp-1) we present some diagnostic plots of the observed
p-values. Theoretically we want the pink part of the plot to have a
solid peak on the left, and then make a reasonable plateau across
higher p-values: gross deviations from this can indicate an absence of
differential behaviour (lack of left-peak) or a model
mis-specification that might need investigating. The blue tracks
indicate p-values corresponding to genes with very low expression, which
would typically struggle to provide evidence of differential
behaviour, and so show an example of what a 'bad' pink trace might
look like.


## From the spec vignette: caveats and rank deficiency (verbatim)

#### Caveat

With the ease of testing so many hypotheses comes a risk of fishing
the data, resulting in spurious statistical associations. Strictly
speaking, anything beyond one comparison on the data requires a more
conservative approach than is achieved even with the traditional
control for FDR to account for the multiplicity of genes.

The ideal situation is the tests are prespecified. If that is the
case, then we should really run an anova to confirm that a change
exists somewhere, and then do at most n-1 comparisons
(where n is the number of levels in the factor of interest, so at most
three comparisons for our four-treatment example) and choose
transcripts where both the anova and contrast are significant. There's
a further technical constraint that the comparisons should be
independent but that is often ignored. If there are more comparisons
of interest, then the p-values won't be controlled at the correct
rate.

Often, the ideal situation is not achieved, and an exploratory
approach is requested. Being strict one should immediately correct for
the abundance of hypotheses in this situation. Pragmatically and
traditionally we neither adjust in this situation nor consider
possible adjusting in the pre-specificied case - this means that the
p-values aren't correctly calibrated, and one of the reasons why I
discourage presenting them in any quantitative form as part of the
results.

Also remember the "Table Two Fallacy" - any inference made about
non-randomly-allocated groups is an observational finding, and doesn't
carry the same rigour as inferences where treatment was randomly
allocated. Observations of associations can easily be spurious and
non-causal.

### Rank deficiency 

One of the most common hurdles in complex designs is the
rank-deficiency problem. The way the experiment has been described can
result in the analysis struggling to identify an estimate for a
particular experimental condition. This happens for one of three
reasons:

- The design has a fatal flaw. If all your treated samples are in one
  batch, and all your control samples in another batch, you cannot
  estimate the extent on how these individually influence expression.
  
- Some conditions have no samples. For example, in our genotype x
  treatment experiment, we might not have a 'vehicle' treatment in one
  of our genotypes.
  
- There is a nesting indicative of repeated measurements. Individuals
  might have submitted multiple samples (perhaps a time-course), and
  also be members of larger groups (their disease status, which is
  assumed constant throughout the time-course).
  
The latter two are remediable through some tweaks to the inputs of
DESeq2, the first will need the advice of a statistician to see if
anything is recoverable and at what compromise.

The 'missing condition' case is easily remedied by supplying the
option `drop_unsupported_combinations=TRUE` to any _model_ you want
this to apply to. The 'nesting' case normally requires a tweak to the
way factors are coded, and we have made it easy to achieve this
through a `transform` option to any _sample\_set_.  Both options are
illustrated below. Note, it is important that there be only **one**
`transform=mutate` component per sample_set (if you want to
introduce/transform multiple derived covariates, then separate them by
commas _within_ the `mutate` expression:

```{r, eval = FALSE}
specification(
  sample_sets =list( 
    all = sample_set(
      subset = TRUE,
      transform = mutate(unit = recode_within(unit, genotype),
                         time = as.numeric(sub("^t", "", timepoint))),
      models = list(
        nested = model(
          design = ~timepoint *  genotype + person:genotype,
          comparisons = list(
            mult_comp(revpairwise ~ timepoint + genotype, interaction=TRUE)
          ),
          drop_unsupported_combinations=TRUE
        )
      )
    )
  )
)
```

The 'missing condition' case is achieved by just the one line; the
nesting is more complex - we firstly have to have a 'unit' column in
our `colData` that identifies which biological unit (person, animal,
plate) a sample belongs to. Then the `transform` line calls a `recode_
within` function that tells us that unit is nested within genotype
here. And we alter the `design` in accordance with the DESeq2 vignette
on within- and between- group comparisons.

The `transform` statement can be used to adjust any of the `colData`
columns in-line. It's a question of personal preference whether
'mistakes' in the original experiment table should be fixed at source
(which allows the scientist to review changes manually), or via a
transformation specified in the spec file (which keeps an entirely
faithful record of what is done).

