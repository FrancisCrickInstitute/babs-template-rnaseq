
nested_modify <- function(obj,  FUN=NULL, layers=c("sample_sets", "models", "comparisons"), cur=obj, level = 1, ...) {
  if (level > length(layers)) {
    return(FUN(obj, layers, ...))  # Pass the full `layers` as positional info
  }
  my_level <- layers[[level]]
  for (i in rev(seq_along(cur[[my_level]]))) {
    layers[[level]] <- names(cur[[my_level]])[i]  # Populate the current index for this level
    obj <- nested_modify(
      obj,
      FUN,
      layers=layers,
      cur=cur[[my_level]][[i]],
      level = level + 1,
      ...
    )
  }
  obj
}

leaf_modify <- function(obj,  FUN=NULL, layers=c("sample_sets", "models", "comparisons"),  level = 1, ...) {
  if (level > length(layers)) {
    return(FUN(obj, layers, ...))  # Pass the full `layers` as positional info
  }
  my_level <- layers[[level]]
  for (i in rev(seq_along(obj[[my_level]]))) {
    layers[[level]] <- names(obj[[my_level]])[i]  # Populate the current index for this level
    obj[[my_level]][[i]] <- leaf_modify(
      obj[[my_level]][[i]],
      FUN,
      layers=layers,
      level = level + 1,
      ...
    )
  }
  obj
}


flatten_nest <- function(obj, FUN=identity, layers=c("sample_sets", "models", "comparisons"),  ...) {
  if (length(layers)==0) {
    return(list(FUN(obj, ...)))
  } else {
    do.call(c, lapply(obj[[layers[1]]], flatten_nest, FUN,  layers[-1]))
  }
}
simplify_nest <- function(obj, FUN=identity, layers=c("sample_sets", "models", "comparisons"),  ...) {
  if (length(layers)==0) {
    return(FUN(obj, ...))
  } else {
    lapply(obj[[layers[1]]], simplify_nest, FUN,  layers[-1])
  }
}

permute_nested <- function(tree, perm)  {
  flatten_paths <- function(x, path = list()) {
    if (!is.list(x)) return(list(list(path = path, value = x)))
    do.call(c, lapply(names(x), function(nm) flatten_paths(x[[nm]], c(path, nm))))
  }  
  assign_path <- function(lst, path, value) {
    if (length(path) == 1) {
      lst[[path[[1]]]] <- value
    } else {
      if (is.null(lst[[path[[1]]]])) lst[[path[[1]]]] <- list()
      lst[[path[[1]]]] <- assign_path(lst[[path[[1]]]], path[-1], value)
    }
    lst
  }
  paths <- flatten_paths(tree)
  result <- list()
  for (p in paths) {
    result <- assign_path(result, p$path[perm], p$value)
  }
  result
}



get_nest <- function(obj, inds, layers=c("sample_sets", "models", "comparisons")[seq_along(inds)]) {
  if (length(inds)==1)
    obj[[layers[1]]][[inds[[1]]]]
  else
    get_nest(obj[[layers[1]]][[inds[[1]]]], inds[-1], layers[-1])
}


#' @export
counter <- function(post_fn=identity) {
  inds <- new.env(parent = emptyenv())
  function(label=".global") {
    if (exists(label, envir=inds, inherits=FALSE)) {
      inds[[label]] <- inds[[label]] + 1
    } else {
      inds[[label]] <- 1
    }
    post_fn(inds[[label]])
  }
}


#' @export
choose_staging <- function(resource, staging="staging") {
  files <- dir(staging, pattern=paste0("^", resource, ".*\\.qmd"))
  if (length(files)==1) {
    print(paste("Using parameters from", files))
    file.path(staging, sub(".qmd$", "", files))
  } else if (length(files)==0) {
    warning("No staging files from which to take parameters.")
  } else {    
    file.path(staging, sub(".qmd$", "", files[menu(files, title="Select which staging file to use for parameters")]))
  }
}


#' @export
get_data_source_params <- function(name) {
  my_config <- readLines(paste0(file.path("extdata", name), ".config"))
  data_source_params <- strsplit(sub(paste0("^", name, "\\."),
                              "",
                              my_config), "=")
  names(data_source_params) <- sapply(data_source_params, "[", 1)
  lapply(data_source_params, function(x) sub("*#.*$", "", x[[2]]))
}

noun_to_readout <- function(noun) {
  readout <- list(
    "protein"="abundance",
    "gene"="expression"
  )
  if (stringr::str_to_lower(noun) == noun)
    default <- "readout"
  else
    default <- "Readout"
  default <- 
    attr(noun, "readout") %||%
    readout[[noun]] %||%
    stringr::str_to_title(readout[[stringr::str_to_lower(noun)]]) %||%
    default
  default
}


#' @export
setFirstAssay <- function(dds, ...) {
  fst <- list(...)[[1]]
  if (is.character(fst)) {
    nm <- fst
  } else {
    nm <- names(list(...))[1]
    assay(dds, nm) <- fst
  }
    assays(dds)[c(nm, setdiff(assayNames(dds), nm))]
}

#' @export
formula_equal <- function(f1, f2) {
  t1 <- attr(terms(f1), "term.labels")
  t2 <- attr(terms(f2), "term.labels")
  setequal(t1, t2)
}


#' @export
top_true <- function(is_in, stat, n, sym=TRUE) {
      ind <- which(is_in)[order(stat[is_in])]
      top_ind <- 1:min(n,length(ind))
      if (sym) {
        ind[unique(c(top_ind, sum(is_in)+1-top_ind))]
      } else {
        ind[top_ind]
      }
}

attach_src <- function(spec, src) {
  if (!"list" %in% class(spec)) {
    try(attr(spec, "src") <- src, silent=TRUE)
    return(spec)
  }
  out <- Map(attach_src, spec, src)
  attributes(out) <- attributes(spec)
  out
}


default_settings <- function() {
  ex <- alist(         ## analysis parameters
    seed           = 1,       ## random seed gets set at start of script, just in case.
    palette = "Set1",

    ## Sample-sets
    baseMeanMin    = 0,       ## discard transcripts with average normalised counts lower than this
    stringsAsFactors = FALSE,
    normalise=NULL,
    impute=NULL,

    ## Comparison
    alpha          = 0.01,    ## p-value cutoff
    filterFun      = IHW::ihw,                 ## NULL for standard DESeq2 results, otherwise  functions
    lfcThreshold   = 0,       ## abs lfc threshold
    showCategory   = 25,      ## For enrichment analyses
    LRT_effect = "default"  ## Method for subdividing LRT results into groups
  )
  
  lapply(
    attach_src(lapply(ex, eval), lapply(ex, function(x) paste(deparse(x), collapse=""))), function(x) {
      if (!(is.null(x)))  structure(x, default=TRUE) else x
    })
}




default_plot_extra <- function() {
  ex <- alist(         ## analysis parameters
    section = "all", 
    top_n_variable = 500,     ## For PCA
    gene_clust     = bluster::HclustParam(cut.params = list(k = 12)),   ## When we need to chose clusters of genes, how many?
    sample_clust   = bluster::HclustParam(metric="pearson"),
    pc_weight = "equal weight", ## equal_weight/eigen (latter favours early PCs)
    reduce_heuristic="drop1",
    pc_x = 1,
    pc_y=2,
    cluster_unused_samples="inject" ## or include or ignore
  )
  lapply(attach_src(lapply(ex, eval), lapply(ex, function(x) paste(deparse(x), collapse=""))), structure, default=TRUE)
}

describe_for_dmc <- function(lst) {
  descriptions=list(
    alpha="The threshold of statistical significance is {}",
    lfcThreshold="The threshold for absolute effect size is {}",
    title="The name of the project is '{}'",
    top_n_variable="Only use {} features for unsupervised clustering",
    script="The project was generated by '{}'",
    showCategory= "Only show top {} enriched categories in plots",
    seed="A random seed of {} is used to ensure reproduciblity",
    filterFun="{Default} independent filtering",
    gene_clust="Feature clustering {}",
    sample_clust="Sample clustering {}",
    impute="Imputation method: {Not applicable}",
    normalise="Normalisation: {Standard DESeq2 approach}",
    showStringsAsFactors="Convert strings to factors in the experiment table? - {}",
    baseMeanMin="Discard transcripts with few average counts per sample than {}",
    baseline_heuristic="Use the '{}' heuristic to centre the colour-scale",
    reduce_heuristic="Use the '{}' terms heuristic to test covariate-PC associations",
    cluster_unused_samples="{} the non-influential samples in dendrograms",
    pc_weight="Use the '{}' heuristic to choose strength of PC-covariate association",
    LRT_effect="Use the '{}' summary of an LRT 'effect size'"
  )
  paste(
    sapply(intersect(names(lst), names(descriptions)), function(a) {
      if (is.null(lst[[a]])) {
        paste("-", gsub("\\{([^}]*)\\}", "\\1", descriptions[[a]]))
      } else {
        paste("-", gsub("\\{\\}", attr(lst[[a]], "src"), descriptions[[a]]))
      }
    }),
    collapse="\n\n")
}
  
      
  



#' @export
design <- function(x) {
  if (methods::is(x, "DESeqDataSet")) {
    DESeq2::design(x)
  } else if (inherits(x, "SummarizedExperiment")) {
    metadata(x)$design
  } else {
    stop("design() not defined for this object")
  }
}

#' @export
`design<-` <- function(x, value) {
  if (methods::is(x, "DESeqDataSet")) {
    # call DESeq2 S4 setter
   DESeq2::`design<-`(x, value=value)
  } else if (inherits(x, "SummarizedExperiment")) {
    metadata(x)$design <- value
    x
  } else {
    stop("design<- not defined for this object")
  }
}

split_conjuncts <- function(expr) {
  if (is.call(expr) && identical(expr[[1]], as.name("&"))) {
    c(
      split_conjuncts(expr[[2]]),
      split_conjuncts(expr[[3]])
    )
  } else {
    list(expr)
  }
}

accumulate_predicates <- function(preds, deps, target=NULL, pred=TRUE) {
  if (!is.null(target) && !target %in% names(deps)) return(pred)
  for (i in names(preds)) {
    if (!is.null(target) && i==target) {
      return( pred  & Reduce(`&`, preds[intersect(names(preds), deps[[i]])]) )
    }
    if (i %in% names(deps)) {
      preds[[i]] <- preds[[i]] & Reduce(`&`, preds[intersect(names(preds), deps[[i]])])
    }
  }
  preds
}
