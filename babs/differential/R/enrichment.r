##' Common interface to enrichment/over-representation
##'
##' Give a unified interface to all the supported functional
##' methods, and all the databases
##' @title Orchestrate functional analyses
##' @param dds a DESeq2 object with thre results stored in the mcols
##' @param method 'or' for over-representation, or 'enrichment' for geneset enrichment
##' @param source 'GO' or 'Reactome'
##' @param ... extra arguments for the analysis
##' @return The clusterProfiler object
##' @author Gavin Kelly
functional_api <- function (dds, method, source,  ...) {
  org <- metadata(dds)$organism$org
  res <- mcols(dds)$results
  ind <- grepl("\\*", res$class)
  if (method!="OR") ind=T
  res <- res[ind & !is.na(res$entrez),]
  res <- res[!duplicated(res$entrez),]
  genes <- setNames(res$shrunkLFC, res$entrez)
  genes <- sort(genes, decreasing=TRUE)
  if (length(genes) < 1) return(NULL)
  reactome_species_list <- c(
    anopheles = "org.Ag.eg.db", arabidopsis = "org.At.tair.db", 
    bovine = "org.Bt.eg.db", canine = "org.Cf.eg.db", celegans = "org.Ce.eg.db", 
    chicken = "org.Gg.eg.db", chimp = "org.Pt.eg.db", coelicolor = "org.Sco.eg.db", 
    ecolik12 = "org.EcK12.eg.db", ecsakai = "org.EcSakai.eg.db", 
    fly = "org.Dm.eg.db", gondii = "org.Tgondii.eg.db", human = "org.Hs.eg.db", 
    malaria = "org.Pf.plasmo.db", mouse = "org.Mm.eg.db", pig = "org.Ss.eg.db", 
    rat = "org.Rn.eg.db", rhesus = "org.Mmu.eg.db", xenopus = "org.Xl.eg.db", 
    yeast = "org.Sc.sgd.db", zebrafish = "org.Dr.eg.db")
  reactome_species <- names(reactome_species_list)[reactome_species_list==org]
  yy <- switch(
    method,
    OR=switch(
      source,
      GO=enrichGO(gene=names(genes), OrgDb = metadata(dds)$organism$org, ...),
      Reactome=enrichPathway(gene=names(genes), organism=reactome_species, ...)
    ),
    enrichment=switch(
      source,
      GO=gseGO(geneList=genes, OrgDb = metadata(dds)$organism$org, ...),
      Reactome=gsePathway(geneList=genes, organism=reactome_species, ...)
    )
  )
}


default_post_process <- function(alpha=0.05, n=100, threshold=-Inf, method=NA) {
  ret <- list(
    OR = function(x) {
      filter(x, p.adjust<alpha) %>%
        mutate(effect=log(DOSE::parse_ratio(GeneRatio)/DOSE::parse_ratio(BgRatio)),
               size=DOSE::parse_ratio(GeneRatio)) %>%
        filter(abs(effect) > threshold) %>%
        slice_max(abs(effect), n=n)
    },
    enrichment =function(x) {
      filter(x, p.adjust<alpha) %>%
        mutate(effect=NES) %>%
        filter(abs(effect)>threshold) %>%
        slice_max(abs(effect), n=n)
    })
  if (is.na(method)) {
    return(ret)
  } else {
    return(ret[[method]])
  }
}

#arrange GO terms so that those that appear in
# the same comparisons are together, 

order_enrichments <- function(df) {
  ord <- df %>%
    group_by(ID) %>%
    dplyr::select(inner, effect, ID) %>%
    summarise(
      ncomp=sum(is.na(effect)),
      comp_pattern=sum(is.na(effect) * 2^match(inner, unique(inner))),
      mean=mean(abs(effect), na.rm=TRUE)) %>%
    mutate(ord=order(ncomp, comp_pattern, mean)) %>%
    pull(ord)
  ord
}


## TODO - flexible recursive report writer
## so e.g.
## struct <- list(method=list(source=list("dataset","model")))
## will produce sections at the 'method' level, subsections at the 'source'
## level and then iterate through datasets and models and produce plots
## across comparisons(omitted)
destruct <- function(df, struct, sub_procedure, n=1) {
  if (is.list(struct[[1]])) { # Still a hierarchy below
    loop_vals <- df[[struct[[1]]]]
    for (i in unique(loop_vals)) {
      cat('\n', strrep("#", n), i, '\n\n')
      destruct(df[loop_vals==i], struct[[1]], n=n+1)
    }
  } else { # At the bottom level
  }
}
      
  
