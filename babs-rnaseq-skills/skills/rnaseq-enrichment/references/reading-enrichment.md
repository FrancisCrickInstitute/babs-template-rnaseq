# Reading the enrichment report

The "Introduction to Functional Analysis" text from `03_enrichment.qmd`,
copied verbatim. The default approaches, used when the spec has no
`functional_approaches`, are GO molecular function and Reactome, each run as
GSEA ("Enrichment", effect = NES) and as over-representation
("Over-representation", effect = relative effect).

# Introduction to Functional Analysis

In contrast to the differential analysis, functional analyses (which
attempt to associate biological meaning to those differential genelists)
make a lot of subtle assumptions.  We provide a 'default' set of
analyses, to help 'make sense' of the lists we've so far provided, but
please use them as a starting point, and don't read too much into the
presence/absence of pathways in this report.

Functional analysis has three components: a comparison of
expression between experimental states; a database of genesets; and an
algorithm that determines the association between those prior two
components. Let us explore these other two components a
bit more:

## Expression comparisons

The differential report this page is derived from returned a number of
comparisons so those are familiar already. We will analyse each of
them separately in what follows, but combine them into natural groups
for presentation. One subtlety is that in those reports we may have
two classes of test:

 - a _contrast_, which estimates a single effect size such as
   fold-change, and tests whether it is compatible with a null value

 - a "goodness of fit" model comparison which doesn't have a single
   representative "effect size", as it is testing a null of whether
   e.g. expression is flat over multiple time points, or many
   treatments (against an alternative that there exists some
   difference amongst the many possible pairs of contrasts).

This difference will have affect what algorithm we use. We have
traditionally attempted to fake an effect size for the latter (using
the largest pairwise difference as representing the size), but this is
somewhat contentious so check with us on interpreting this.

## Databases of annotated genes

We traditionally look at which [Reactome](https://reactome.org/) and/or [GO
molecular functions](http://geneontology.org/). It is possible for us
to restrict/generalise these to suit the specific question (even if we
don't actually update the text that gets automatically included in
_every_ report) so if there are other sources of gene-sets that you
might want to examine in the context of your expression results, do
let us know.  But essentially, any collection of gene-sets (ie gene
IDs that we can map back to transcripts found in your sequencing) can
be tested for association.

## Enrichment vs Over-representation algorithms

There are two broad approaches. The results of each expression
contrast (e.g. WT vs KO) gives

- a significance flag indicating whether the gene is called as
differentially expressed controlling for false discovery rate, and

- an effect size for each gene (though see the 'goodness of fit'
comment above);

### Over-representation

An over-representation analysis takes the first of these as the
'truth' - a very binary picture that can be very powerful if one
believes the significance calls, that has the advantage of being
easily and compactly interpretable. You have two subsets of the whole
transcriptome: your differential gene list and one particular
pathway's genes, and over-representation tests whether they have more
in common than random subsets of the transcriptome.  For pathways
where this is the case, we report back two useful measures:

 - Relative Effect - how many times larger is the overlap than would
   have been observed by chance - this is exactly the statistic we are
   testing to say whether a pathway:genelist combination are
   over-representative. The 'null' over-representation would be 1,
   when the number of statistically differential genes in a pathway is
   exactly as expected from the sizes of the pathway and differential
   genelist.

 - Proportion of Differential - To give some 'scientific significance'
   context, we also report the fraction of the pathway that is
   actually differential. Theoretically it's possible for a pathway
   with only one differential gene to be flagged as significantly
   associated, so to guide sensible selection of candidates to
   explore, we recommend you also look at this statistic.

### Enrichment analysis (aka GSEA)

If we have an estimate of effect-size (change in expression) for each
gene, we might be interested in this value of this statistic for
genes in our pathway regardless of whether they passed our criterion
for _statistical_ significance: if they're all showing the same degree
of change, then we may assert that the pathway is of interest.

We present the standard statistics for GSEA. The enrichment score
tracks how much the distribution of effect-sizes in the pathway
differs from the distribution of effect-sizes of genes not in the
pathway, and the NES attempts to make this comparable amongst
differently sized pathways. But the interpretation is subtle, so we
recommend looking at plots of the 'Running Enrichment Score' for
individual cases to make sure you're interpreting the summary
statistics correctly (these will take up a lot of space in what is
already a large report, so are best delivered as and when needed.)

This is a somewhat complementary view to over-representation. If they
tell very different pictures, then it's likely that examining what one
means by "pathway regulation" deeply will be worthwhile. The landscape
of "enrichment phenotypes" is a very broad one (are you looking for
pathways whose genes are all up-regulated, or ones whose changes are
broadly similar magnitudes but opposite directions...)

