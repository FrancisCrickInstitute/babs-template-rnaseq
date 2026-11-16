# Reading the exploratory report

The text below is the explanatory prose from `01_exploratory.qmd`,
copied verbatim except that the inline R expressions `` `{r} rowNoun` `` and
`` `{r} noun_to_readout(rowNoun)` `` have been replaced by their RNA-seq values,
"gene" and "expression". Use it to interpret the figures the same way the report
does. Do not draw conclusions the report text does not support. In particular,
the PC-covariate association chart is meant to guide which plots to look at,
not to provide evidence on its own.

# All Datasets and Models

We may examine the samples in different combinations, and leave out
certain samples (either entirely ignore them, or visualise them but
not let them influence the analysis in any way.)

In the above table, the columns under the 'In Subset' group indicate
these combinations are listed, and the samples' inclusions are
indicated. Below, we describe the datasets in terms of the predicates
which determine which samples are included in them, and also the
'influential' samples that determine: how the genes are clustered; how
he principal components are calculated; and what samples are used in
subsequent differential analysis.

Usually we will use include all samples and they will all be
'influential', but depending on the analysis question, it might be
useful to completely ignore samples/experimental-groups entirely and
from those select an influential subset that drive the analysis (the
non-influential samples being retained in the visualisations and
analysis for cross-reference, but which won't actively drive the
analysis.)

Each of those datasets may be inferentially analysed in
potentially several ways, as formulated below. In simple 'A vs B'
experiments there may only be one inferential approach, but as soon as
we have a more complex structure different questions may demand a
diversity of approaches, optionally: accounting for various
covariates; stratifying the analysis by experimental factors; looking
for the ways that one factor modifies the effect of another upon
expression;... We use mathematical formulae to
specify these approaches:

# Description of Visualisations

There are different ways of configuring the plots. These roughly
divide into two choices:

 - How to illustrate the covariates (treatments, batches, ...) in the
   visualisations: in multi-factorial experiments, we may want to
   represent one covariate in terms of colouring the point that
   represents a sample. It might be obvious what these 'aesthetic'
   choices should be, but conversely we may produce multiple 'plot
   configurations' to illustrate different experimental factors.

 - What to use as the 'outcome': typically we'll use the normalised
   readout in heatmaps, or to generate principal components, but there
   are situations where we might wish to 'normalise out' the effect
   of, say, batch so that the true biology can come into focus. Or we
   might wish to 'recentre' the data so that one particular
   experimental group is seen as a baseline.

At the beginning of each 'plot config' section we list the respective
choice made for the plots in that section: the 'aesthetic' mapping
describes how each aspect of the plot (colour, x-coordinate, shape,
...)  reflects an aspect of the experimental desgin (e.g. treatment);
and the 'reconstruction' (if present) states which experimental
factors have been normalised out (e.g. `. - batch` indicates that the
batch effect has been regressed out of visualisation).

Now we give a brief introduction to each of the plot-types we show for
each configuration.

## Overall Heatmaps

These visualisations are carried out blind to the experimental
design. For the heatmap @fig-Heatmap-1, we select a subset of
genes removing the (assumed uninformative) genes with flat expression
levels across the whole sample set. We'd expect samples from the same
experimental group to cluster together, in the sense that they are on
the same branch of the tree. But this is a transcriptome-wide picture,
and even if the clustering is not perfect, there will still be genes
that are consistent with the expected expression profiles, and they
will be revealed in the differential analysis.

The values of the covariates relevant to the dataset and model will be
illustrated in the colour-bar above the heatmp. Influential samples
(often defined as all the samples) will be identified similarly in the
colourbar - the choice of "most variable genes" wil be based on their
behaviour in the influential samples.

In case that heatmap doesn't cluster exactly according to the
experimental design, in @fig-HeatmapOrd-1, we provide the
samples ordered according to one particular interpretation of the
experimental design.  In simple (one-way) designs where there is only
one covariate, this is a fairly straightforward way of gathering
samples in a set of columns, but in more complex designs it isn't
obvious whether to sort first by genotype and then treatment, say, or
perhaps the reverse, so for this 'supervised' clustering we chose the
(arbitrary) order the 'model' was specified, above.

## Clustering centroids

Based on the gene's expression in the
influential samples, the dendrogram from the heatmap will be split
into similarly behaving features. We can aggregate the expression
across those features and produce dot
plots for each of the clusters. See, for example @fig-clustProfile-1

## PC-Covariate assocation

Principal Components are a way of finding a number of meta-genes
- proxies that best reconstruct the multi-dimensional expression
signal if we had to choose 1, 2,
... individual numbers to represent a sample. In @fig-covar-1 the
columns explore the lower-order principal components (which although
not providing a universally strong signal transcriptome wide, might
still detect biology that is affecting a smaller subset of genes,
or a reasonably large set of genes to a lesser
extent than happens in the higher-order PCS). The rows represent the
experimental factors we have recorded, and the depth of colour of the
cell records the degree of 'association' that factor has with the give
PC (and grey says there was no statistically significant association.)
This being an automated report, we've had to make various compromises
so please don't read too much into this chart: it primarily guides
which other plots we should generate to look at how samples associate
with each other.

## Principal Component Scatterplots

Then come scatter plots of the first two
Principal Components - a way of summarising all the genes down to just
two 'metagenes' that attempt to encapsulate the variability across the
samples in as faithful way as possible. Each plot
(e.g. @fig-twopc-1) takes the PCs from the unadjusted data,
and colours them according to the plot configuration under
consideration.

There's a slight complexity here in that we may need to
produce two such plots to reveal all the information requested in a
plot configuration: the configuration might requested the use of the
horizontal position to represent an aspect of the experimental design,
but this is needed to represent the first PC, so it may be necessary
to generate a second plot representing the missing aspect as a colour
in the chart.

These plots are interactive - hovering over a point will bring up a
tooltip listing all the experimental factors pertaining to that
sample. Hovering will also select all other samples that share an
attribute with that sample - the nominated attribute will be the first
one listed in the tooltip.

## Principal Component Dot-Plots

We can choose to look closer at certain principal components that
e.g. @fig-covar-1 leads us to believe are relevant to the experimental
design. Just like the cluster dot-plots, we can take a single value as
a representation of the sample and plot it, as in @fig-onepc-1, against the covariates
according to the chosen plot configuration. Whereas in the cluster
dotplot we equally-weighted various subsets of similar genes,
in the PC dotplots we aggregate all the genes
but chose a weighting scheme that captures as much of the
multi-dimensionality as possible.

