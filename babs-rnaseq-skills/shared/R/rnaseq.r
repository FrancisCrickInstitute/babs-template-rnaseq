#' @export
load_specs <- function(params, context) {
  file <- paste0(params$spec, ".spec")
  if (file.exists(file.path("extdata",file))) {
    df <- as.data.frame(colData(context))
    e <- as.environment(df)
    isVarying <- which((sapply(df, function(v) length(unique(v))) %% nrow(df)) > 1)
    assign("Guess", names(df)[isVarying][1], envir=e)
    # Alias several spec-file functions to be list-constructors that can have dangling commas
    aliased_list <- character()

    # single objects that have a "constructor" attribute, so they can be wrapped in a list container
    list_obj <- function(my_alias, envir, post=NULL) {
      aliased_list <<- c(aliased_list, my_alias)
      assign(my_alias, function(...) {
        out <- structure(list(...), constructor=my_alias)
        if (is.null(post)) {
          out
        } else {
          post(out)
        }
      }, envir=envir)
    }
    parent.env(e) <- environment()
    list_obj("list", envir=e)
    list_obj("sample_set", envir=e)
    list_obj("model", envir=e)
    list_obj("specification", envir=e)
    list_obj("extra_assay", envir=e)
    list_obj("profile_plot", envir=e, post=function(x) {if (!inherits(x, "gg")) x else list(x)} )
    list_obj("comparison", envir=e, post=function(x) {if (is_formula(x[[1]]) && length(x[[1]])==3) do.call(mult_comp, x) else x})

    # List wrappers - either evaluating or not
    shortcut <- function(my_alias, envir = parent.frame(), quote = TRUE, child=NULL) {
      aliased_list <<- c(aliased_list, my_alias)
      fn_name <- deparse(substitute(child))
      assign(my_alias,
        function(...) {
          if (quote) {
            dots <- as.list(substitute(list(...)))[-1]
            nm <- names(match.call(expand.dots = FALSE)$...)
            if (is.null(nm)) nm <- rep("", length(dots))
            names(dots) <- nm
            out <- dots
          } else {
            out <- list(...)
            if (fn_name != "NULL") {
              wrong <- sapply(out, function(x) attr(x, "constructor", exact=TRUE) %||% "") != fn_name
              child_fn <- get(fn_name, envir = envir, mode = "function", inherits = TRUE)
              out[wrong] <- lapply(out[wrong], child_fn)
            }
          }
          structure(out, alias = my_alias)
        },
        envir = envir
      )
    }
    shortcut("missingness", e)
    shortcut("feature_filters", e)
    shortcut("settings", e)
    shortcut("strata", e)
    shortcut("sample_sets", e, quote=FALSE)
    shortcut("models", e, quote=FALSE)
    shortcut("comparisons", e, quote=FALSE, child=comparison)
    shortcut("profile_plots", e, quote=FALSE, child=profile_plot)
    shortcut("extra_assays", e, quote=FALSE)

    # Other convenience functions
    assign("constrain", expression, envir=e)
    assign("mutate",
           function(...) {
             substitute(alist(...))
           },
           envir=e
           )
    specs <- source(file.path("extdata",file), local=e)$value
    # Which parents have enforce some post-processing on their children
    # We'll need to do that manually if we're in the old "profile_plots=list(..." idiom
    post_fns <- Filter(
      function(x) x!= "NULL",
      sapply(
        setNames(aliased_list, aliased_list),
        function(x) environment(e[[x]])$fn_name %||% "NULL"))
    specs <- resolve_alias(specs, lapply(post_fns, function(x) environment(e[[x]])$post))
    srcs <- expr_to_list(parse(file.path("extdata",file))[[1]], aliased_list)
    specs <- attach_src(specs, srcs)
    for (singleton in c("sample_set", "model", "comparison", "profile_plot", "extra_assay")) {
      specs <- wrap_exposed(specs, singleton)
    }
    assign("sample_set", expression, envir=e) # avoid evaluating any examples sample_sets.
    pkg_defaults <-default_settings()
    new_settings <- setdiff(names(pkg_defaults), names(specs$settings))
    if (length(new_settings)>0) {
      string_rep <- lapply(pkg_defaults[new_settings], deparse1)
      warning("New settings (", paste(new_settings), ") can be set in ", file, ", so please update it. The default values that will be used are:\n", paste(names(string_rep), string_rep, sep=": ", collapse="\n"))
      specs$settings[new_settings] <-  pkg_defaults[new_settings]
    }
    rm(list=ls(envir=e), envir=e)
  } else {
    fml <- paste("~", names(colData(context))[ncol(colData(context))])
    specs <- list(
      sample_sets = list(all=TRUE),
      models=list(
        "Naive" = list(
          design = as.formula(fml),
          comparisons = list(pairwise = mult_comp(as.formula(paste("pairwise", fml))))
        )
      ),
      plot_scale = function(y) {
        y/mean(y)
      }
    )
  }
  specs$params <- params
  specs
}



resolve_alias <- function(l, post_fns) {
  # Base case: if l is not a list, just return it
  if (!is.list(l)) return(l)
  already_parent_list <- names(l) %in% names(post_fns)
  #e.g. for profile_plots=list(aes() ~ .)
  #if specified by profile_plot(aes() ~ .) each would get wrapped in a list and its post
  # function would be executed, so
  for (i in which(already_parent_list)) {
    l[[i]] <- lapply(l[[i]], function(x) if (is.list(x)) x else list(x))
    l[[i]] <- lapply(l[[i]], post_fns[[names(l)[i]]])
  }
  alias <- sapply(l, function(e) {val <- attr(e, "alias"); if (is.null(val)) NA else val})
  names(l)[!is.na(alias)] <- alias[!is.na(alias)]
  islist <- sapply(l, is.list)
  if (any(islist)) l[islist] <- lapply(l[islist], resolve_alias, post_fns)
  l
}

#' Recode nested factors to avoid matrix-rank problems
#'
#' Following the suggestion in the DESeq2 vignette, recode nested factors so that
#' they take common values in different clusters to avoid rank problems
#' @title Recode nested factors
#' @param inner A factor representing the variable to be recoded, e.g. the cell-line
#' @param ... The parent factors that 'inner' is inside, e.g. the genotype of the cell-line
#' @return A factor with recoded levels
#' @author Gavin Kelly
#' @export
recode_within <- function(inner, ...) {
  within <- do.call(interaction, alist(...))
  tab <- table(inner, within)!=0 # which batches are in which nest
  if (any(rowSums(tab)>1)) {
    stop("Some inner levels appear in multiple outer groups.")
  }
  f <- factor(apply(tab, 2, cumsum)[cbind(as.character(inner),as.character(within))]) # cumsum to get incrementing index within group.
  contrasts(f) <- "contr.sum"
  f
}


default_namer <- function() {
  offsets <- list() 
  function(obj, prefix = "") {
    if (!prefix %in% names(offsets)) offsets[[prefix]] <- 0
    new_names <- names(obj) %||% rep("", length(obj))
    unnamed <- which(new_names == "") # Identify unnamed elements
    names(obj)[unnamed] <- paste0(
      prefix,
      seq_along(unnamed) + offsets[[prefix]] # Only use counter for unnamed
    )
    offsets[[prefix]] <<- offsets[[prefix]] + length(unnamed) # Increment for unnamed elements only
    for (i in names(obj)) obj[[i]]$name <- obj[[i]]$name %||% i
    obj
  }
}

#' Expand an analysis specification into its corresponding subset list
#'
#' Generate a list of DESeq2 objects corresponding to the different
#' subsets specified
#' @title Generate subsets of DESeq2 object
#' @param dds The original DESeq2 object containing all samples
#' @param spec The analysis specificiation
#' @return A list of DESeq2 objects
#' @author Gavin Kelly
#' @export
build_dds_list <- function(dds, spec) {
  # Function to recurse down the spec > sample_sets > models > comparisons hierarchy, and cascade down values of a given field as it encounters them.
  trickle_down <- function(field, to="comparisons", default=NULL, merge_fn=function(x,y) {if (is.null(x)) y else x}, obj=spec, current_level="spec", levels=c("spec", "sample_sets", "models", "comparisons")) {
    if (field %in% names(obj)) {
      default_src <- attr(default, "src")
      default <- merge_fn(obj[[field]], default)
      attr(default, "src") <- default_src
      if ("src" %in% names(attributes(obj[[field]]))) {
        attr(default, "src") <- c(attr(default, "src"), attr(obj[[field]], "src"))
      }
    }
    if (current_level==to) {
      obj[[field]] <- default
      return(obj)
    }
    next_level <- levels[match(current_level, levels) + 1] 
    obj[[next_level]] <- mapply(
      function(x) trickle_down(field=field, to=to, default=default, merge_fn=merge_fn, obj=x, current_level=next_level, levels=levels),
      obj[[next_level]],
      SIMPLIFY=FALSE
    )
    obj
  }
  merge_default <- function(x, y) modifyList(y,x)
  # Share any top-level models down to each sample-set
  spec <- trickle_down(field="models", to="sample_sets", merge_fn=c)
  spec <- trickle_down(field="profile_plots", to="models")
  spec <- trickle_down(field="comparisons", to="models", merge_fn=c)
  # Conjunct or cascade any top-level subsetting - if missing, use all samples
  spec <- trickle_down(field="subset", to="sample_sets", default=rep(TRUE, ncol(dds)), merge_fn=`&`)
  spec <- trickle_down(field="influential_samples", to="sample_sets", default=rep(TRUE, ncol(dds)), merge_fn=`&`)
  # Cascade any spec-wide transforms
  spec <- trickle_down(field="transform", to="sample_sets")
  spec <- trickle_down(field="strata", to="sample_sets")
  # various model parameters that might be shared across datasets/everything
  spec <- trickle_down(field="drop_unsupported_combinations", to="models")
  spec <- trickle_down(field="drop_incomplete", to="models")
  spec <- trickle_down(field="varNames", to="sample_sets", merge_fn=modifyList, default=list())
  spec <- trickle_down(field="varDescriptions", to="sample_sets", merge_fn=modifyList, default=list())
  spec <- trickle_down(field="filterFeatures", to="sample_sets", default=spec$settings$filterFeatures)
  spec <- trickle_down(field="filterQC", to="sample_sets", default=spec$settings$filterQC)
  spec <- trickle_down(field="baseMeanMin", to="sample_sets", default=spec$settings$baseMeanMin)
  spec <- trickle_down(field="feature_filters", to="sample_sets", default=alist(universal=TRUE))
  spec <- trickle_down(field="impute", to="sample_sets", default=spec$settings$impute)
  spec <- trickle_down(field="normalise", to="sample_sets", default=spec$settings$normalise)
  spec <- trickle_down(field="external_list", to="models", default=NULL)
  spec <- trickle_down(field="extra_assays", to="sample_sets", default=NULL)
  ## Comparison-specific stuff
  spec <- trickle_down(field="alpha", to="comparisons", default=spec$settings$alpha)
  spec <- trickle_down(field="lfcThreshold", to="comparisons", default=spec$settings$lfcThreshold)
  spec <- trickle_down(field="LRT_effect", to="comparisons", default=spec$settings$LRT_effect)
  spec <- trickle_down(field="filterFun", to="comparisons", default=spec$settings$filterFun)
  
  ## Cascade down any plot-specific stuff
  spec <- trickle_down(field="extra", to="profile_plots", levels=c("spec", "sample_sets", "models", "profile_plots"), merge_fn=merge_default, default=default_plot_extra())
  
  modelled_terms <- lapply(
    spec$sample_sets,
    function(x) {lapply(
      x$models,
      function(y) {
        d <- c()
        if (is_formula(y$design))
          d <- all.vars(update(y$design, NULL ~ .))
        if ("profile_plots" %in% names(y))
          d <- c(d, unlist(lapply(y$profile_plots, function(x) c(
            unlist(lapply(x[[1]], all.vars)),
            unlist(lapply(x$extra, all.vars))) )))
        d
      })
    })
  modelled_terms <-  setdiff(unique(unlist(modelled_terms)), ".")
  if (is.list(spec$settings$palette)) {
    default_palette <- spec$settings$palette
  } else {
    default_palette<- df2colorspace(
      data.frame(colData(dds))[, intersect(modelled_terms, colnames(data.frame(colData(dds)))),drop=FALSE],
      spec$settings$palette
    )
  }
  metadata(colData(dds))$palette <- default_palette
  ddsList <- list()
  default_names <- default_namer()
  spec$sample_sets <- default_names(spec$sample_sets, prefix="D")
  multi_dataset <- rev(which(sapply(spec$sample_sets, function(x) is_formula(x$split))))
  for (di in multi_dataset) {
    inject <- subsets_from_formula(spec$sample_sets[[di]], colDF(dds))
    inject <- inject[sapply(inject, sum)>1]
    inject <- lapply(inject, function(insplit) modifyList(spec$sample_sets[[di]], list(subset = insplit)))
    spec$sample_sets <- append(spec$sample_sets, inject, di )
    spec$sample_sets[[di]] <- NULL
  }

  for (dataset_i in seq_along(spec$sample_sets)) {
    spec$sample_sets[[dataset_i]]$models <- default_names(spec$sample_sets[[dataset_i]]$models, prefix="M")
    for (model_i in seq_along(spec$sample_sets[[dataset_i]]$models)) {
      if ("comparisons" %in% names(spec$sample_sets[[dataset_i]]$models[[model_i]])) {
        spec$sample_sets[[dataset_i]]$models[[model_i]]$comparisons <- default_names(spec$sample_sets[[dataset_i]]$models[[model_i]]$comparisons, prefix="C")
      }
      if ("profile_plots" %in% names(spec$sample_sets[[dataset_i]]$models[[model_i]])) {
        spec$sample_sets[[dataset_i]]$models[[model_i]]$profile_plots <- default_names(spec$sample_sets[[dataset_i]]$models[[model_i]]$profile_plots, prefix="P")
      }
    }
    dds$.influential <- spec$sample_sets[[dataset_i]]$influential_samples
    dds$.influential_in_assay <- data.frame(.all = spec$sample_sets[[dataset_i]]$influential_samples)
    for (ea in names(spec$sample_sets[[dataset_i]]$extra_assays)) {
      dds$.influential_in_assay[[ea]] <- spec$sample_sets[[dataset_i]]$extra_assays[[ea]]$influential_samples %||% TRUE
    }
    obj <- dds
    # Potentially handle case where we want to handle ratio data by putting denominator samples into the normalisation
    if ("baseline" %in% names(spec$sample_sets[[dataset_i]])) {
# TODO: Properly implement this and consider the impact on sample ordering/indexing      
      warning("Ratio-handling via baseline is untested")
      if (!is.list(spec$sample_sets[[dataset_i]]$baseline$ind)) {
        is_numerator <- !is.na(spec$sample_sets[[dataset_i]]$baseline$ind)
        norm <- counts(obj[,spec$sample_sets[[dataset_i]]$baseline$ind[is_numerator]]) + spec$sample_sets[[dataset_i]]$baseline$adj
      } else {
        is_numerator <- sapply(spec$sample_sets[[dataset_i]]$baseline$ind, function(x) !all(is.na(x)))!=0
        norm <- sapply(spec$sample_sets[[dataset_i]]$baseline$ind[is_numerator], function(x) rowSums(counts(obj[,x]))) + spec$sample_sets[[dataset_i]]$baseline$adj
      }
      obj <- obj[,is_numerator]
      normalizationFactors(obj) <- norm
    }
    
    obj <- obj[, spec$sample_sets[[dataset_i]]$subset]
    # TODO: check we can spec$sample_sets[[dataset_i]]$subset <- NULL
    colData(obj) <- droplevels(colData(obj))
    ff <- spec$sample_sets[[dataset_i]]$feature_filters
    deps <- list(post_norm="universal", exploratory=c("post_norm", "universal"), differential=c("post_norm", "universal"))
    if (is.list(ff)) {
      mcols(obj)$filter <- as.data.frame(
        accumulate_predicates(
          lapply(ff, function(f) eval_dds(obj, f, assays=c(assayNames(obj), "norm", "missing"))),
          deps=deps)
      )
    } else {
      mcols(obj)$filter <- data.frame(universal=eval_dds(obj, ff, assays=c(assayNames(obj), "norm", "missing")))
    }
    
    for (f in names(mcols(obj)$filter)) {
      # Separate 'and' clauses of an individual filter
      conjuncts <- split_conjuncts(ff[[f]])
      if (length(conjuncts)>1) {
        # get the predicates corresponding to those clauses
        pass <- lapply(conjuncts, function(conjunct) eval_dds(obj, conjunct, assays=c(assayNames(obj), "norm", "missing")))
        # Apply adjustment for  predecessor predicates
        pass <- lapply(pass, function(p)  accumulate_predicates(mcols(obj)$filter, deps=deps, target=f, pred=p))
        percent <- 100 * sapply(Reduce(`&`, pass, accumulate=TRUE), mean)
        attr(mcols(obj)$filter[[f]], "subpreds") <-paste0("(", paste(sprintf("%0.0f%%", percent), collapse=","), ")")
      }
    }
    if (!is.null(spec$sample_sets[[dataset_i]]$filterQC)) {#DEPRECATED
      mcols(obj)$filter$exploratory <- eval_dds(obj, spec$sample_sets[[dataset_i]]$filterQC, assays=c(assayNames(obj), "norm", "missing"))
    }    
    if (!is.null(spec$sample_sets[[dataset_i]]$filterFeatures)) {
      mcols(obj)$filter$universal <- eval_dds(obj, spec$sample_sets[[dataset_i]]$filterFeatures, assays=c(assayNames(obj), "norm", "missing"))
    }

    varNames <- sapply(names(colData(obj)), identity)
    varNames[names(spec$sample_sets[[dataset_i]]$varNames)] <- unlist(spec$sample_sets[[dataset_i]]$varNames)
    mcols(colData(obj))$name <- varNames
    varDescriptions <- sapply(names(colData(obj)), identity)
    varDescriptions[names(spec$sample_sets[[dataset_i]]$varDescriptions)] <- unlist(spec$sample_sets[[dataset_i]]$varDescriptions)
    mcols(colData(obj))$description <- varDescriptions

    for (i in seq_along(spec$sample_sets[[dataset_i]]$models)) {
      if (! "profile_plots" %in% names(spec$sample_sets[[dataset_i]]$models[[i]])) {
        # default to the set of models removing any terms that will preserve marginality
        pp <- find_simpler_models(spec$sample_sets[[dataset_i]]$models[[i]]$design, do_aes=TRUE, type="design")
        spec$sample_sets[[dataset_i]]$models[[i]]$profile_plots <- structure(pp, src="Auto-generated")
      } 
    }
# TODO: metadata(obj)$models no longer exists, swap all references to spec$sample_sets[[dataset_i]]$models instead
    if ("sample_swap" %in% names(spec$sample_sets[[dataset_i]])) {
      for (x1 in names(spec$sample_sets[[dataset_i]]$sample_swap)) {
        i1 <- match(x1, colData(obj)$ID)
        i2 <- match(spec$sample_sets[[dataset_i]]$sample_swap[[x1]], colData(obj)$ID)
        tmp <- colData(obj)[i1, -1, drop=FALSE]
        colData(obj)[i1, -1] <- colData(obj)[i2, -1, drop=FALSE]
        colData(obj)[i2, -1] <- tmp
      }
    }
    tr <- spec$sample_sets[[dataset_i]]$transform
    mc <- mcols(colData(obj))
    if ("stringsAsFactors" %in% names(spec$settings) && spec$settings$stringsAsFactors) {
      for (i in names(colData(obj))) {
        x <- colData(obj)[[i]]
        if (is.character(x) && length(unique(x)) %% length(x) > 1) {
          colData(obj)[[i]] <- as.factor(x)
        } 
      }
    }
    if (!is.null(tr)) {
      ind <- names(colData(obj))!=".influential_in_assay"
      infl <- obj$.influential_in_assay
      .mu <- purrr::partial(mutate, .data=as.data.frame(colData(obj)[ind]))
      tr[[1]] <- .mu
      cnames <- colnames(obj)
      md <- metadata(colData(obj))
      colData(obj) <- S4Vectors::DataFrame(eval(tr))
      obj$.influential_in_assay <- infl
      metadata(colData(obj)) <- md
      colnames(obj) <- cnames
      if (".include" %in% names(colData(obj))) {
        obj <- obj[,colData(obj)[[".include"]]]
        colData(obj) <- droplevels(colData(obj))
      }
      new_cols <- intersect(modelled_terms, setdiff(names(colData(obj)), names(default_palette$Heatmap)))
      old_cols <- intersect(names(colData(obj)),setdiff(modelled_terms, new_cols))
      if (length(old_cols)>0) {
        is_modified <- sapply(old_cols,
                               function(x) {
                                 if (class(colData(obj)[[x]]) != class(colData(dds)[[x]])) return(TRUE)
                                 if (is.factor(colData(obj)[[x]])) return(!all(levels(colData(obj)[[x]]) %in%  levels(colData(dds)[[x]])))
                                 if (is.character(colData(obj)[[x]])) return(!all(unique(colData(obj)[[x]]) %in%  unique(dds[[x]])))
                                 return(FALSE)#For numerics - makes sense to keep the original range
                               })
        new_cols <- c(new_cols, old_cols[is_modified])
        for (ir in old_cols[!is_modified]) {
          if (is.factor(colData(obj)[[ir]])) {
            metadata(colData(obj))$palette$Heatmap[[ir]] <- metadata(colData(obj))$palette$Heatmap[[ir]][match(levels(colData(obj)[[ir]]), names(metadata(colData(obj))$palette$Heatmap[[ir]]) )]
            metadata(colData(obj))$palette$ggplot[[ir]] <- metadata(colData(obj))$palette$ggplot[[ir]][match(levels(colData(obj)[[ir]]), names(metadata(colData(obj))$palette$ggplot[[ir]]))]
          }
        }
      }
      if (length(new_cols)>0) {
        new_meta <- df2colorspace(
          colData(obj)[, new_cols, drop=FALSE],
          spec$settings$palette
        )
        metadata(colData(obj))$palette$Heatmap[new_cols] <- new_meta$Heatmap[new_cols]
        metadata(colData(obj))$palette$ggplot[new_cols] <- new_meta$ggplot[new_cols]
      }
    }
    gg <- metadata(colData(obj))$palette$ggplot
    metadata(colData(obj))$varlabels <- setNames(as.list(names(gg)), names(gg))
    needs_labels <- !sapply(gg, is_function)
    needs_labels <- setNames(names(gg)[needs_labels], names(gg)[needs_labels])
    metadata(colData(obj))$labels <- lapply(needs_labels, function(x) setNames(
      names(gg[[x]]),
      names(gg[[x]]))
      )
    if ("collapse" %in% names(spec$sample_sets[[dataset_i]])) {
      mf <- model.frame(spec$sample_sets[[dataset_i]]$collapse, data.frame(colData(obj)))
      ind <- match(do.call(paste, c(mf, sep="\r")),
                   do.call(paste, c(unique(mf), sep="\r")))
      obj <- collapseReplicates(obj, groupby=factor(ind), renameCols=FALSE)
      if (any(rowSums(table(ind, obj$.influential)>0)>1)) warning("Replicate groups contain mixes of influential and non-influential samples!")
    }
    obj$.involved <- TRUE
    spec$sample_sets[[dataset_i]]$influential_samples <- obj$.influential
    spec$sample_sets[[dataset_i]]$object <- obj
  }
  spec <- read_palettes(spec, fname="extdata/colours.json")
  save_palettes(spec)
  spec
}


#' Fit the models of expression
#'
#' Iterate through each model (stored in the 'models' metadata of a
#' DESeqDataSet) and expand the contrasts so each contrast gets a
#' separate nested level.
#' @title Fit the DESeq2 models
#' @param dds The original DESeq2 object containing all samples
#' @param ...
#' @return
#' @author Gavin Kelly
#' @export
fit_models <- function(dmc, inds, ...) {
  di <- inds[[1]]
  sampleset <- dmc$sample_sets[[di]]
  has_comparisons <- sapply(sampleset$models, function(m) length(m$comparisons) > 0)
  sampleset$models <- lapply(
    sampleset$models[has_comparisons],
    function(mdl) {
      fit_model(modifyList(mdl, list(object=sampleset$object, ...)))
    })
  sampleset$models <- sampleset$models[!sapply(sampleset$models, is.null)]
  if (length(sampleset$models)>0) {
    dmc$sample_sets[[di]] <- sampleset
  } else {
    dmc$sample_sets[[di]] <- NULL
  }
  dmc
}

subset_model <- function(model) {
  if (".influential" %in% names(colData(model$object))) {
    model$object <- model$object[, model$object$.influential]
    colData(model$object) <- droplevels(colData(model$object))
  }
  model
}
  

fit_model <- function(model, ...) {
  message("Processing model ", model$name)
  design(model$object) <- model$design
  model <- subset_model(model)
  model <- check_model(model)
  if (!is.null(model$mat) && nrow(model$mat) <= ncol(model$mat)) {
    warning("Model is being dropped as there is no replication")
    return(NULL)
  }
  if (any(model$dropped)) {
    design(model$object) <- model$mat
  }
  for (comp_ind in rev(seq(along=model$comparisons))) {
    message("Processing comparison ", comp_ind)
    model <- fit_comparison(model=model, comparison_ind=comp_ind,  ...)
  }
  return(model)
}


get_design_matrix <- function(dds) {
  if (is_formula(design(dds))) {
    model.matrix(design(dds), colData(dds))
  } else {
    design(dds)
  }
}

fit_comparison <- function(model, comparison_ind, ...) {
  comparison <- model$comparisons[[comparison_ind]]
  approach <- dplyr::case_when(
    comparison[["LRT"]] %||% FALSE             ~ "wald2LRT",
    !is.null(model$approach)                ~  model$approach %||% "",
    inherits(comparison, "post_hoc") && inherits(model$object, "DESeqDataSet") ~ "multiWald",
    inherits(comparison, "post_hoc") ~ "limma",
    is_formula(comparison[[1]])           ~ "LRT",
    .default                              = "Wald"
  )

  if (approach=="LRT") { # Do the usual DESeq2 LRT
    return(fitLRT(mdl=model, comparison_ind=comparison_ind, ...))
  }

  if (approach=="Wald") {
    # Just a single DESeq2 Wald
    ## TODO: We should handle limma here as well, using retrieve_contrasts to cast DESeq's comparisons as limma contasts
    if (!"dispGeneEst" %in% mcols(model$object)) {
      model$object <- DESeq2::DESeq(model$object, test="Wald", ...)
    }
    return(model)
  }

  ## We're now in multi-comparison territory:
  comparisons <- emcontrasts(mdl=model, comparison_ind=comparison_ind)
  if (length(comparisons)==0) {
    model$comparisons[comparison_ind] <- NULL
    return(model)
  }
  
  if (approach == "wald2LRT") { # Do LRT-equivalents of the multiple ward tests
    comparisons <- lapply(comparisons, function(comparison) {
      fitContrastLRT(model, contr=comparison, ...)}
      )
  }
  
  if (approach=="voom"){
    ## TODO: possibly optimise/cache repeated calls to fitVoom, like 'model_fit_done'
    model$lmfit <- fitVoom(model$object, model)
    comparisons <- apply_contrasts_with_estimability(model, comparisons, rowwise = FALSE)
  }
  
  if (approach=="limma"){
    ## TODO: possibly optimise/cache repeated calls to fitVoom, like 'model_fit_done'
    model$lmfit <- limma::lmFit(assay(model$object),get_design_matrix(model$object) )
    comparisons <- apply_contrasts_with_estimability(model, comparisons,  rowwise = TRUE)
  }
  
  if (approach=="multiWald") {
    if (!"dispGeneEst" %in% names(mcols(model$object))) {
      model$object <- DESeq2::DESeq(model$object, test="Wald", ...)
    } # no need for an 'else': the model fit has already been done
  }
  model$comparisons <- append(model$comparisons, comparisons, comparison_ind)[-comparison_ind]
  return(model)
}


apply_contrasts_with_estimability <- function(mdl, comparisons, rowwise = FALSE) {
  contr_mat <- do.call(cbind, lapply(comparisons, "[[", "comparison"))
  fit <- limma::contrasts.fit(mdl$lmfit, contr_mat)

  if (rowwise) {
    design <- fit$design
    obs <- !is.na(assay(mdl$object))
    nb <- lapply(seq_len(nrow(obs)), function(i) {
      idx <- obs[i, ]
      if (all(idx)) return(NULL)
      estimability::nonest.basis(design[idx, , drop = FALSE])
    })
    isEst <- vapply(seq_len(ncol(contr_mat)), function(j) {
      vapply(seq_along(nb), function(i) {
        if (is.null(nb[[i]])) TRUE else estimability::is.estble(contr_mat[, j], nb[[i]])
      }, logical(1))
    }, logical(nrow(obs)))
  } else {
    # global estimability (voom case)
    nb <- estimability::nonest.basis(fit$design)
    isEst <- apply(contr_mat, 2, function(cc) estimability::is.estble(cc, nb))
    # expand to matrix for consistent handling
    isEst <- matrix(isEst, nrow = nrow(fit$coefficients), ncol = ncol(contr_mat), byrow = TRUE)
  }

  # Mask non-estimable entries
  fit$coefficients[!isEst] <- NA
  fit$stdev.unscaled[!isEst] <- NA

  # eBayes AFTER masking
  ebayes <- limma::eBayes(fit)
  lapply(setNames(seq_along(comparisons), names(comparisons)),
         function(ci) modifyList(comparisons[[ci]], list(comparison=ci, ebayes=ebayes)))
}

annihilator <- function(x) diag(nrow = nrow(x)) - x %*% solve(t(x) %*% x) %*% t(x)
reduced_design.fit <- function(fit, reduced_design){
  full_design <- fit$design
  mapping <- lm(reduced_design ~ full_design - 1)
  if(sum(abs(residuals(mapping))) > 1e-8){
    stop("Apparently the reduced design is not nested in the full design")
  }
  coef <- coef(mapping)
  if (is.null(dim(coef))) coef <- t(t(coef))
  cntrst <- annihilator(coef)
  colnames(cntrst) <- colnames(full_design)
  rownames(cntrst) <- colnames(full_design)
  cntrst <- cntrst[, colSums(abs(cntrst)) > 1e-8]
  limma::contrasts.fit(fit, contrast = cntrst)
}

#' Check model
#'
#' Run formula through an lm to check it
#' @title Check model
#' @param mdl 
#' @param coldat 
#' @param dds The original DESeq2 object containing all samples
#' @return 
#' @author Gavin Kelly
#' @export
check_model <- function(mdl) {
  dropped <- FALSE
  constraint <- mdl$constraint
  mat <- NULL
  if (is_formula(mdl$design) ) {
    df <- as.data.frame(colData(mdl$object))
    na_covars <- apply(is.na(df[all.vars(mdl$design)]), 1, any)
    if ("drop_incomplete" %in% names(mdl) && mdl$drop_incomplete && any(na_covars)) {
      warning("Dropping samples ", paste0(row.names(df)[na_covars], collapse=", "), " as they have incomplete metadata")
      mdl$object <- mdl$object[, !na_covars]
      colData(mdl$object) <- droplevels(colData(mdl$object))
      df <- as.data.frame(colData(mdl$object))
    }
    if (inherits(mdl$object, "DESeqDataSet")) {
      df$.x <- counts(mdl$object, norm=FALSE)[1,]
    } else {
      df$.x <- rnorm(ncol(mdl$object))
    }
    fml <- update(mdl$design, .x ~ .)
    fit <- lm(fml, data=df)
    if (is.expression(mdl$constraint)) {
      constraint <- em_constraint(fit, mdl$constraint)
    }
    if ("drop_unsupported_combinations" %in% names(mdl) && mdl$drop_unsupported_combinations) {
      dropped <- is.na(coef(fit))
    } else {
      if (any(is.na(coef(fit)))) {
        warning("Can't estimate some coefficients in ", mdl$design, ".\n In unbalanced nested designs, use the option 'drop_unsupported_combinations=TRUE,' in the problematic model. Other causes are complete confounding or conditions with no observations.")
      }
    }
  }
  
  if (any(dropped)) {
    X <- model.matrix(mdl$design, as.data.frame(colData(mdl$object)))[,!dropped, drop=FALSE]
    if (inherits(mdl$object, "DESeqDataSet"))  colnames(X) <- .resNames(colnames(X))
    if (!is.null(constraint)) {
      X <- X %*% MASS::Null(constraint)
    }
    mat <- X
  } else if  (!is.null(constraint)) {
    X <- model.matrix(mdl$design, as.data.frame(colData(mdl$object)))
    if (inherits(mdl$object, "DESeqDataSet"))  colnames(X) <- .resNames(colnames(X))
    mat <- X %*% MASS::Null(constraint)
  }
  c(mdl, list(dropped=dropped, mat=mat, lm=fit))
}


#' Post-hoc generator
#'
#' Wrap a formula so that emmeans can auto-expand it
#' @title Mark a formula as a multiple comparison
#' @param spec 
#' @param ... 
#' @param dds The original DESeq2 object containing all samples
#' @return 
#' @author Gavin Kelly
#' @export
mult_comp <- function(spec, name=NULL, description=NULL, omnibus=FALSE, keep=TRUE, trend=FALSE, ...) {
  obj <- structure(list(spec=spec, omni=omnibus, keep=keep, trend=trend, ...), constructor="comparison")
  class(obj) <- "post_hoc"
#  attributes(obj) <- c(attributes(obj), list(name=name, description=description))
  obj
}

#' Expand post-hoc comparisons
#'
#' Use emmeans to expand keywords
#' @title Expand multiple comparisons into their contrasts
#' @param dds The original DESeq2 object containing all samples
#' @param spec 
#' @return 
#' @author Gavin Kelly
emcontrasts <- function(mdl, comparison_ind, prefix="my") {
  comparison <- mdl$comparisons[[comparison_ind]]
  em_extra <- comparison[setdiff(names(comparison), c("spec", "keep", "LRT", "omni", "trend", "name", "description"))]
  if (comparison$trend) {
    em_fn <- emmeans::emtrends
  } else {
    em_fn <- emmeans::emmeans
  }
  #TODO - add the constraint handling (and make sure the $lm that reaches here also does so)
  emc <- do.call(em_fn, c(list(object=mdl$lm, specs= comparison$spec), em_extra))$contrasts
  contr_frame <- as.data.frame(summary(emc))
  ind_est <- !is.na(contr_frame$estimate)
  contr_frame <- contr_frame[ind_est,1:(which(names(contr_frame)=="estimate")-1), drop=FALSE]
  contr_frame[] <- lapply(contr_frame, function(x) sub("|", "†", x, fixed=TRUE))
  contr_mat <- emc@linfct[ind_est, !mdl$dropped, drop=FALSE]
  if (inherits(mdl$object, "DESeqDataSet")) {
    colnames(contr_mat) <- .resNames(colnames(contr_mat))
  }
  new_emmc <- sub("\\.emmc$", "", ls("package:emmeans", pattern="*.emmc"))
  embaseline <- do.call(em_fn, c(list(object=mdl$lm, specs= replace_emmc(comparison$spec, new_emmc)), em_extra))
  baseline_mat <- embaseline$contrast@linfct[ind_est, !mdl$dropped, drop=FALSE]
  byvars <- names(contr_frame) %in% (attr(emc, "misc")$by.vars %||% character())
  if (comparison$omni) {
    ## TODO: Check if/where I use this - looks like a way of getting revpairwise(~a | b) to give an LRT per value of b
    split_idx <- split(which(ind_est), interaction(emc@grid[ind_est, emc@misc$by.vars], drop = TRUE))
    tooltip <- list()
  } else {
    split_idx <-  paste(
      if(sum(!byvars)>1) {
        do.call(paste,  c(lapply(contr_frame[!byvars], function(column) sub("(.*) - (.*)", "(\\1-\\2)", column)),sep= "×"))
      } else {
        sub("(.*) - (.*)", "\\1-\\2", contr_frame[[which(!byvars)]])
      },
      do.call(paste,  c(contr_frame[ byvars] ,sep= ",")),
      sep=ifelse(any(byvars), "|", "")
    )
    if (nrow(contr_frame)>1) {
      names(split_idx) <- paste(names(mdl$comparisons)[comparison_ind], seq_len(nrow(contr_frame)), sep=".")
    } else {
      names(split_idx) <- names(mdl$comparisons)[comparison_ind]
    }
    tooltip <- do.call(paste, c(mapply(function(a, b) paste0(a," = ", b), names(contr_frame), contr_frame, SIMPLIFY=FALSE), sep="<br/>"))
  }
  if (!is.null(mdl$mat)) {
    X <- mdl$mat
  } else {
    X <- model.matrix(mdl$lm)
  }
  comparisons <- lapply(
    setNames(seq_along(split_idx), names(split_idx)),
    function(i)  {
      cont <- t(contr_mat[i,,drop=FALSE])
      modifyList(comparison, c(
        list(
          comparison=cont,
          name=split_idx[i]),
        if (comparison$omni) {list()} else {
          sample_weights <-  X %*% MASS::ginv(t(X) %*% X) %*% cont #X %*% solve(t(X) %*% X) %*% cont
          list(
            baseline_contrast=t(baseline_mat[i,,drop=FALSE]),
            tooltip=tooltip[i],
            involved = abs(sample_weights) > 1e-8
          )
        }
      ))
    })
  comparisons[comparison$keep]
}

fitVoom <- function(model_dds, mdl) {
  tmp <- rowData(model_dds)
  tmp$PCA <- NULL
  dge <- edgeR::DGEList(
    counts=assay(model_dds, "counts"),
    samples=as.data.frame(colData(model_dds)),
    genes=as.data.frame(tmp)
  )
  dge <- edgeR::calcNormFactors(dge)
  mm <- model.matrix(design(model_dds), dge$samples)
  y <- limma::voom(dge, mm, plot=FALSE)
  if ("block" %in% names(mdl)) {
    block <- dge$samples[[mdl$block]]
    corfit <- duplicateCorrelation(y, mm, block=block)
    y <- limma::voom(dge, mm,  block=block, correlation=corfit)
    fit <- limma::lmFit(y, mm, block=block, correlation=corfit )
  } else {
    fit <- limma::lmFit(y, mm)
  }
  fit
}

#' Fit an LRT model
#'
#' Insert the 'comparison' formula into the reduced slot
#' @title Fit LRT
#' @param dds The original DESeq2 object containing all samples
#' @param reduced 
#' @param ... 
#' @return 
#' @author Gavin Kelly
fitLRT <- function(mdl, comparison_ind, ...) {
  reduced <- mdl$comparisons[[comparison_ind]][[1]]
 # metadata(dds)$comparison <- reduced
  if (any(mdl$dropped)) {
    full <- mdl$mat
    reduced <- model.matrix(reduced, colData(mdl$object))
    ## unsupported_ind <- apply(reduced==0, 2, all)
    ## reduced <- reduced[, !unsupported_ind]
    ## colnames(reduced) <- .resNames(colnames(reduced))
    reduced <- reduced[,.resNames(colnames(reduced)) %in% colnames(full), drop=FALSE]
    mdl$comparisons[[comparison_ind]]$reduced_mat <- reduced
  } else {
    full <- mdl$design
  }
  if (is_formula(reduced) && grepl("\\|", as.character(reduced)[[2]])) {
    emc <- emmeans(mdl$lm,
                  update.formula(reduced, trt.vs.ctrl ~ .))$contrasts
    split_idx <- split(seq_len(nrow(emc@grid)), interaction(emc@grid[emc@misc$by.vars], drop = TRUE))
    linfct_by_stratum <- lapply(split_idx, function(idx) t(emc@linfct[idx, , drop = FALSE]))
    # TODO: Need to generate n=|stratum| separate reduced model matrices
    if (inherits(mdl$object, "DESeqDataSet")) {
      stop("DEseq2 stratified ANOVA not implemented yet")
    } else {
      mm <- model.matrix(design(mdl$object), colData(mdl$object))
      fit <- limma::lmFit(assay(mdl$object), mm)
      mdl$comparisons[[comparison_ind]]$lmfit <- fit
      comparisons <- lapply(
          linfct_by_stratum,
          function(cntrst) {
             c(
              mdl$comparisons[[comparison_ind]],
              lmfit=fit,
              ebayes=limma::eBayes(limma::contrasts.fit(fit, contrast = cntrst))
             )
          }
      )
      names(comparisons) <- paste(names(mdl$comparisons)[comparison_ind], seq_along(comparisons), sep=".")
      mdl$comparisons <- append(mode$comparisons, comparisons, comparison_ind)[-comparison_ind]
      return(mdl)
    } 
  }
  dds <- mdl$object
  if (inherits(dds, "DESeqDataSet")) {
    DESeq2::design(dds) <- full
    dds <- DESeq2::DESeq(dds, test="LRT", full=full, reduced=reduced, ...)
    mdl$comparisons[[comparison_ind]]$LRTterms=setdiff(
      colnames(attr(dds, "modelMatrix")),
      colnames(attr(dds, "reducedModelMatrix"))
    )
    mdl$comparisons[[comparison_ind]]$object <- dds
  } else {
    design(dds) <- full
    fit <- limma::lmFit(assay(dds), get_design_matrix(dds))
    mdl$comparisons[[comparison_ind]]$lmfit <- fit
    if (is_formula(reduced)) {
      reduced <- model.matrix(reduced, colData(dds))
    }
    fit <- reduced_design.fit(fit, reduced)
    fit <- limma::eBayes(fit)
    mdl$comparisons[[comparison_ind]]$ebayes <- fit
  }
  mdl
}


#fitContrastLRT <- function(dds, mdl_mat, contr, ...) {
fitConstrastLRT <- function(mdl, contr, ...) {
  mdl_mat <- mdl$mat %||% model.matrix(mdl$design, as.data.frame(colData(mdl$object)))  
  ind <- contr!=0
  # Insert a new final column that is the contrast, and remove a column that is now linearly dependent
  # (we chose the right-most column that is involved in the contrast)
  new_column <- apply(mdl_mat[,ind,drop=FALSE], 1, function(x) sum(x*contr))
  old_column_ind <- which(ind)[sum(ind)] # ie last column involved in the contrast
  mdl_mat <- cbind(mdl_mat[,-old_column_ind, drop=FALSE], contrast_column=new_column)
  # The reduced model space is spanned by the constraint that the contrast is zero
  # ie the final column of the new parametrisation
  reduced <- mdl_mat[,-ncol(mdl_mat),drop=FALSE]
  DESeq2::design(dds) <- mdl_mat
  dds <- DESeq2::DESeq(dds, test="LRT", full=mdl_mat, reduced=reduced, ...)
  list(
    object=dds,
    comparison =contr,
    LRTterms = "contrast_column",
    reduced_mat = reduced
  )
}


## apply contrast, and transfer across interesting mcols from the dds
#' Generate results object
#'
#' Insert results columns into mcols
#' @title Generate the results for a model and comparison
#' @param dds The original DESeq2 object containing all samples
#' @param mcols 
#' @param filterFun 
#' @param lfcThreshold 
#' @param ... 
#' @return 
#' @author Gavin Kelly
#' @export
get_result <- function(dmc, inds, mcols=c("symbol", "entrez"), ...) {
  di <- inds[[1]]
  mi <- inds[[2]]
  ci <- inds[[3]]
  dataset <- dmc$sample_sets[[di]]
  model <- dataset$models[[mi]]
  comparison <- model$comparisons[[ci]]
  filterFun <- eval(comparison$filterFun) %||% rlang::missing_arg()
  comp <- comparison$comparison
  alpha <- comparison$alpha
  if (length(alpha)>1) {
    alpha <- sort(alpha)
    alpha1 <- alpha[1]
  } else {
    alpha1 <- alpha
  }
  if (!is.null(comparison$object) || all(c("lmfit", "ebayes") %in% names(comparison))) { # it's LRT (or F test for limma)
    if (inherits(comparison$object, "DESeqDataSet")) {
      fitted_se <- comparison$object
      r <- results(fitted_se, filterFun=filterFun, alpha=alpha1, ...)
    } else {
      fitted_se <- model$object      
      r <- limma::topTable(comparison$ebayes, coef=NULL,
                          genelist=row.names(comparison$lmfit$genes),
                          number=Inf, sort.by="none")
      co_mat <- cbind(as.matrix(r[,1:(which(names(r)=="AveExpr")-1), drop=FALSE]), 0)
      r <- with(r, DataFrame(baseMean=2^AveExpr,
                            log2FoldChange=apply(co_mat, 1, function(x) diff(range(x))),
                            lfcSE=model$lmfit$sigma,
                            class="",#colnames(co_mat)[ind],
                            pvalue=P.Value,
                            padj=adj.P.Val,
                            row.names=row.names(fitted_se)))
      metadata(r)$alpha <- alpha1
    }
  } else {  # Wald
    fitted_se <- model$object
    if (is.character(comp) && length(comp)==1) { #  it's a name
      r <- DESeq2::results(fitted_se, filterFun=filterFun, lfcThreshold=comparison$lfcThreshold, name=comp, alpha=alpha1, ...)
    } else { # it's a contrast
      if (is.list(comp) && "listValues" %in% names(comp)) {
        r <- DESeq2::results(fitted_se, filterFun=filterFun, lfcThreshold=comparison$lfcThreshold, contrast=comp[names(comp) != "listValues"], listValues=comp$listValues, alpha=alpha1, ...)
      } else {
        if ("lmfit" %in% names(model)) {
          r <- limma::topTable(comparison$ebayes, coef=comparison$comparison,
                              genelist=row.names(model$lmfit$genes),
                              number=Inf, sort.by="none")
          if (!"logFC" %in% names(r)) {
            is_coef <- grepl("^Coef[0-9]+$", names(r))
            r$logFC <- apply(abs(as.matrix(r[,is_coef])), 1, max, na.rm=TRUE)
          }
          r <- with(r, DataFrame(baseMean=2^AveExpr,
                                log2FoldChange=logFC,
                                pvalue=P.Value,
                                padj=adj.P.Val,
                                lfcSE=apply(model$lmfit$stdev.unscaled[,comparison$comparison,drop=FALSE], 1, mean) * model$lmfit$sigma,
                                row.names=row.names(fitted_se)))
          metadata(r)$alpha <- alpha1
        } else {
          r <- DESeq2::results(fitted_se, filterFun=filterFun, lfcThreshold=comparison$lfcThreshold, contrast=comp, alpha=alpha1, ...)
        }
      }
    }
  }
  sigs <- rep("NS", nrow(r))
  sigs[r$padj <= alpha1] <- paste("<=", alpha1)
  prev_alpha <- alpha1
  for (a in alpha[-1]) {
    if (missing(filterFun)) {
      res_alpha <- DESeq2:::pvalueAdjustment(r, independentFiltering=TRUE, alpha=a, pAdjustMethod="BH")$padj
    }
    else {
      res_alpha <- filterFun(r, alpha=a)$padj
    }
    ind <- sigs=="NS" & res_alpha <= a
    sigs[ind] <- paste0(prev_alpha, "-", a)
    prev_alpha <- a
  }
  my_mcols <- intersect(mcols, colnames(mcols(fitted_se)))
  if (length(my_mcols)>0) {
    r[my_mcols] <- mcols(fitted_se)[my_mcols]
  }
  r$sig <- sigs
  if ("LRTPvalue" %in% names(mcols(fitted_se))) {
    r$class <- mcols(fitted_se)$class
    r$class[is.na(r$padj) | is.na(r$pvalue) | r$baseMean==0] <- NA
    term <-  comparison$LRTterms
    # take the biggest fold-change vs baseline, for MA and reporting?
    if (all(term %in% names(mcols(fitted_se))) && comparison$LRT_effect!="none") {
      effect_matrix <- cbind(I=rep(0, nrow(fitted_se)),as.matrix(mcols(fitted_se)[,term,drop=FALSE]))
      split_effects <- strsplit(term, "_vs_")
      # if a main effect is dropped, then all the terms are probably named A vs (intercept)
      # we can make the class a bit more interpretable by renaming the case where e.g.
      # B vs A is the largest and C vs A the smallest as B v C. So change effect columns to
      # enable this.
      if (all(sapply(split_effects, length)==2)) {
        if (length(unique(sapply(split_effects, "[", 2)))==1) {
          colnames(effect_matrix) <- c(split_effects[[1]][2], sapply(split_effects, "[", 1))
        }
      }
      maxmin <- cbind(
        apply(effect_matrix, 1, which.max),
        apply(effect_matrix, 1, which.min))
      #imax imin between them locate the max and min. imin is the 'earlier' term, to allow for negative and positive fc's
      imax <- apply(maxmin, 1, max)
      imin <- apply(maxmin, 1, min)
      r$maxLog2FoldChange <- effect_matrix[cbind(1:length(imax), imax)] -
        effect_matrix[cbind(1:length(imin), imin)]
      maxlfcSE <- sqrt(
      (as.matrix(mcols(fitted_se)[,paste0("SE_", c("Intercept", term))])[cbind(1:length(imax), imax)])^2 +
        (as.matrix(mcols(fitted_se)[,paste0("SE_", c("Intercept", term))])[cbind(1:length(imin), imin)])^2
      )
      fit <- ashr::ash(r$maxLog2FoldChange, maxlfcSE, mixcompdist = "normal", 
                       method = "shrink")
      r$shrunkLFC <- fit$result$PosteriorMean
      r$shrunkSE <- fit$result$PosteriorSD
      r$class <- paste(colnames(effect_matrix)[imax], "V", colnames(effect_matrix)[imin])
    } else {
      warning("Couldn't work out relevant group ordering in LRT")
      r$shrunkLFC <- lfcShrink(fitted_se, res=r, type="ashr", quiet=TRUE)$log2FoldChange
      r$class <- ""
    }
  }  else {
    if ("lmfit" %in% names(model)) {
      fit_sh <- ashr::ash(
        r$log2FoldChange,
        r$lfcSE, mixcompdist = "normal", 
        method = "shrink")
      r$shrunkLFC <- fit_sh$result$PosteriorMean
    } else {
      r$shrunkLFC <- lfcShrink(fitted_se, res=r, type="ashr", quiet=TRUE)$log2FoldChange
    }
    if (!"class" %in% names(r)) {
      r$class <- ifelse(r$log2FoldChange >0, "Up", "Down")
    }
  }
  ind <- which(r$padj<metadata(r)$alpha)
  r$class[ind] <- paste0(r$class[ind], "*")
  r$class[is.na(r$padj)] <- "Low Count"
  r$class[is.na(r$pvalue)] <- "Outlier"
  r$class[r$baseMean==0] <- "Zero Count"
  dmc$sample_sets[[di]]$models[[mi]]$comparisons[[ci]]$results <- r
  dmc
}

.resNames <- function(names) {
 names[names == "(Intercept)"] <- "Intercept"
 make.names(names)
}


#' @export
tidy_significant_se <- function(se, ind = TRUE, weights=NULL, assay= (if (inherits(se, "DESeqDataSet")) "vst" else assayNames(se)[1])) {
  se <- se[ind,,drop=FALSE]
  if (any(is.na(assay(se, assay)))) assay <- "imputed"
  mat <- assay(se, assay)
  if (!is.null(weights) && is.numeric(weights)) {
      offset <- mat %*%  weights
      assays(se) <- setFirstAssay(se, weighted=mat - as.vector(offset))
  } else {
    assays(se) <- setFirstAssay(se, weighted=mat)
  }
  se
}


#' @export
colDF <- function(se) {
  as.data.frame(colData(se))
}


#' @export
reorder_samples <- function(se, columns) {
  if (!any(columns==".influential")) columns <- c(columns, ".influential")
  ind <- which(columns==".influential")[1]
  columns <- append(columns, ".influential_in_assay", ind)
  columns <- columns[columns %in% colnames(colData(se))]
  columns <- lapply(
    as.list(colData(se)[columns]),
    function(x) {
      if (is.character(x)) factor(x) else x
    })
  do.call(order, columns)
}



retrieve_contrast <- function (object, expanded = FALSE, listValues=c(1,-1)) {
  stop("Not Tested")
  comparison <- metadata(object)$comparison
  resNames <- resultsNames(object)
  resReady <- FALSE
  if (is.character(comparison)) {
    if (length(comparison)==1) {
      contrast <- ifelse(resNames==comparison, 1, 0)
      resReady <- TRUE
    } else {
      contrastFactor <- comparison[1]
      contrastNumLevel <- comparison[2]
      contrastDenomLevel <- comparison[3]
      contrastBaseLevel <- levels(colData(object)[, contrastFactor])[1]
      hasIntercept <- attr(terms(DESeq2::design(object)), "intercept") == 1
      firstVar <- contrastFactor == all.vars(DESeq2::design(object))[1]
      noInterceptPullCoef <- !hasIntercept & !firstVar & (contrastBaseLevel %in% 
                                                           c(contrastNumLevel, contrastDenomLevel))
      if (!expanded & (hasIntercept | noInterceptPullCoef)) {
        contrastNumColumn <- make.names(paste0(contrastFactor, "_", contrastNumLevel, "_vs_", contrastBaseLevel))
        contrastDenomColumn <- make.names(paste0(contrastFactor, "_", contrastDenomLevel, "_vs_", contrastBaseLevel))
        if (contrastDenomLevel == contrastBaseLevel) {
          name <- if (!noInterceptPullCoef) {
            make.names(paste0(contrastFactor, "_", contrastNumLevel, "_vs_", contrastDenomLevel))
          }
          else {
            make.names(paste0(contrastFactor, contrastNumLevel))
          }
          contrast <- ifelse(resNames==name, 1,0)
          resReady <- TRUE
        }
        else if (contrastNumLevel == contrastBaseLevel) {
          swapName <- if (!noInterceptPullCoef) {
            make.names(paste0(contrastFactor, "_", contrastDenomLevel, 
                              "_vs_", contrastNumLevel))
          }
          else {
            make.names(paste0(contrastFactor, contrastDenomLevel))
          }
          contrast <- ifelse(resNames==swapName, -1, 0)
          resReady <- TRUE
        }
      }
      else {
        contrastNumColumn <- make.names(paste0(contrastFactor, contrastNumLevel))
        contrastDenomColumn <- make.names(paste0(contrastFactor, contrastDenomLevel))
      }
    }
  }
  if (!resReady) {
    if (is.numeric(comparison)) {
      contrast <- comparison
    }
    else if (is.list(comparison)) {
      contrastNumeric <- rep(0, length(resNames))
      contrastNumeric[resNames %in% comparison[[1]]] <- listValues[1]
      contrastNumeric[resNames %in% comparison[[2]]] <- listValues[2]
      contrast <- contrastNumeric
    }
    else if (is.character(comparison)) {
      contrastNumeric <- rep(0, length(resNames))
      contrastNumeric[resNames == contrastNumColumn] <- 1
      contrastNumeric[resNames == contrastDenomColumn] <- -1
      contrast <- contrastNumeric
    }
  }
  contrast
}

#' Change a factor's reference level
#'
#' Rather than change the order of the levels, this changes the way
#' the factor is parametrised, so that the levels are in the natural order
#' but the coefficients can reflect experimental design considerations
#' @title Rebase a factor's level
#' @param x A factor to be rebased 
#' @param lev The level of the factor that is to be regarded as the 'control' to which all others will be compared
#' @return A factor with a new contrast attribute
#' @author Gavin Kelly
#' @export
rebase <- function(x, lev) {
  i <- which(levels(x)==lev)
  if (length(i)==0) {
    stop(lev, " is not a level of your factor ", deparse1(substitute(x)))
  }
  contrasts(x) <- contr.treatment(nlevels(x), i)
  x
 }



#' @export
add_org_annotation <- function(dds, org, keytype="ENSEMBL", extra_mcols=list(entrez="ENTREZID", symbol="SYMBOL", ensembl="ENSEMBL"), count_source=NA) {
  metadata(dds)$organism <- list(org=org)
  metadata(dds)$count_source <- count_source
  if (is.null(org) || system.file(package=org)=="") {
    if (is.null(row.names(dds))) {
      warning("Couldn't load ", org, ", so using row-numbers for feature annotation")
      row.names(dds) <- paste0("gene", 1:nrow(dds))
    } else {
      warning("Couldn't load ", org, ", so using row-names for feature annotation")
    }
    for (extra in names(extra_mcols)) {
      mcols(dds)[[extra]] <- row.names(dds)
    }
    metadata(dds)$symbol_source <- "row.names"
  } else {
    library(org, character.only=TRUE)
    if (is.null(row.names(dds))) {
      row.names(dds) <- head(keys(eval(parse(text=org)), keytype), nrow(dds))
    }
    o <- eval(parse(text = org))
    if (any(names(extra_mcols) %in% names(mcols(dds)))) {
      warning(paste(intersect(names(extra_mcols), names(mcols(dds))), collapse=","), " are already in the data object.  NOT overwriting them")
    }
    for (extra in setdiff(names(extra_mcols), names(mcols(dds)))) {
      if (extra_mcols[[extra]] %in% columns(o)) {
        mcols(dds)[[extra]] <- mapIds(
          o,
          keys=row.names(dds),
          column=extra_mcols[[extra]],
          keytype=keytype,
          multiVals="first")[row.names(dds)]
      } else {
        warning("Couldn't find ", extra_mcols[[extra]], " in ", org, ".  Using ", keytype, " for '", extra, "' instead.")
        mcols(dds)[[extra]] <- row.names(dds)
      }
    }
  }
  dds
}


find_simpler_models <- function(fml, do_aes=FALSE, type=c("simplest", "drop1", "design", "auto")) {
  type <- match.arg(type)
  if (type=="auto") {
    if (any(attr(terms(fml), "order") > 1)) {
      type <- "design"
    } else {
      type <- "drop1"
    }
  }
  if (do_aes) {
    vars <- all.vars(fml)
    aess <- c("x", "colour", "shape", rep("group", max(length(vars)-3,0)))[seq_along(vars)]
    is_group <- which(aess=="group")
    if (length(is_group)>0) {
      if (length(is_group)>1) {
        group=paste0("interaction(",paste(vars[is_group], collapse=","),")")
      } else {
        group=vars[is_group]
      }
      vars <- c(vars[-is_group], group)
      aess <- c(aess[-is_group], "group")
    }
    lhs <- paste0("aes(", paste0(aess, "=", vars, collapse=","), ")")
  } else {
    lhs <- "."
  }
  if (type=="simplest") {
    new <- add.scope(~1, fml)
    lapply(setNames(new, paste("just", new)),
           function(x) list(structure(update(fml, as.formula(paste(lhs, "~", x))), src=deparse1(update(fml, as.formula(paste(lhs, "~", x))))), section="all")
           )
  } else if (type=="drop1") {
    drop <- drop.scope(fml)
    lapply(setNames(drop, paste("drop", drop)),
           function(x) list(structure(update(fml, as.formula(paste0(lhs, " ~ . -", x))), src=deparse1(update(fml, as.formula(paste0(lhs, " ~ . -", x))))), section="all")
           )
  } else if (type=="design") {
    list(
      design=list(structure(update(fml, as.formula(paste(lhs, " ~ ."))), src=deparse(update(fml, as.formula(paste(lhs, " ~ ."))))), section="all")
    )
  }
}



#' @export
mat_x_terms <- function(mat, fml, fitFrame, weights=rep(1, nrow(mat)), type) {
  if (is.null(weights)) weights <- rep(1, nrow(mat))
  infl <- fitFrame$.influential_in_assay
  fml <- clean_formula(fml, fitFrame[infl,,drop=FALSE])
  yvar <- make.unique(c(colnames(fitFrame), "y", sep = ""))[ncol(fitFrame) + 1]
  fml <- update(fml, paste(yvar, "~ ."))
  if (type=="main") {
    tt <- terms(fml)
    main <- attr(tt, "term.labels")[!grepl(":", attr(tt, "term.labels"))]
    fml <- reformulate(main, response = all.vars(fml)[1])
    type <- "drop1"
  }
  simpler <- find_simpler_models(fml, type=type)
  names(simpler) <- sub("^drop ", "", names(simpler))
  nmat <- ncol(mat)
  covar_x_mat <- expand.grid(
    Covariate = names(simpler),
    column = 1:nmat)
  covar_x_mat$Assoc <- NA
  covar_x_mat$pvalue <- NA
  fit_selected <- list()
  for (imat in 1:nmat) {
    fitFrame[[yvar]] <- mat[, imat]
    fit1 <- lm(fml, data = fitFrame[infl,,drop=FALSE])
    ind_complete <- intersect(row.names(fitFrame), names(residuals(fit1)))
    if (length(ind_complete) < nrow(fitFrame)) {
      fit1 <- lm(fml, data = fitFrame[ind_complete,])
    }
    for (ifml in names(simpler)) {
      fit0 <- lm(simpler[[ifml]][[1]], data=fitFrame[ind_complete,])
      ano <- anova(fit0, fit1)
      ss_effect <- ano$"Sum of Sq"[2]
      ss_error <- sum(resid(fit1)^2)
      eta_Sq <- ss_effect/(ss_effect + ss_error)
      i <- covar_x_mat$column==imat & covar_x_mat$Covariate==ifml
      covar_x_mat$Assoc[i] <- eta_Sq * weights[imat]
      covar_x_mat$pvalue[i] <- anova(fit0, fit1)$'Pr(>F)'[2]
    }
  }
  covar_x_mat$wrap <- (covar_x_mat$column - 1)%/%20
  covar_x_mat$wrap <- paste0(covar_x_mat$wrap * 20 +  1,
                            "-",
                            pmin((covar_x_mat$wrap + 1) * 20, nmat))
  covar_x_mat$column <- sprintf("%02d", covar_x_mat$column)
  covar_x_mat$wrap <- paste("PCs",covar_x_mat$wrap)
  if (any(covar_x_mat$pvalue<=0.05, na.rm=TRUE)) {
    covar_x_mat$Assoc[covar_x_mat$pvalue>0.05] <- NA
  } else {
    for (i in unique(covar_x_mat$Covariate)) {
      ind <- covar_x_mat$Covariate==i
      covar_x_mat$Assoc[ind & covar_x_mat$Assoc < max(covar_x_mat$Assoc[ind])] <- NA
    }
  }
  covar_x_mat
}

#' @export
extract_hits <- function(covar_x_pc, pc, coldat) {
  pc_hits <- data.frame(
    covar=unique(covar_x_pc$Covariate),
    strongest=NA_character_,
    first=NA_character_,
    row.names=unique(covar_x_pc$Covariate)
  )
  for (covar in row.names(pc_hits)) {
    this_covar <- subset(covar_x_pc,
                        Covariate == covar & 
                          !is.na(Assoc) & column != column[nrow(covar_x_pc)])
    if (nrow(this_covar) == 0) next
    pc_hits[covar, "first"] <- as.character(this_covar$column[1])
    max_col <- this_covar$column[which.max(this_covar$Assoc)][1]
    pc_hits[covar, "strongest"] <- as.character(max_col)
  }
  hits <- sort(unique(as.integer(c(pc_hits$strongest, pc_hits$first))))
  if (length(hits)==0) hits <- 1
  hits <- paste0("PC", hits)
  wide_dat <- cbind(coldat, pc[,hits,drop=FALSE])
  long_dat <- pivot_longer(wide_dat, cols=all_of(hits), names_to="PC")
  long_dat
}



#' @export
negate_emmc <- function(emc) {
  ememmc <- get(emc, "package:emmeans")
  function(...) {
    base_contr <- ememmc(...)
    #    base_contr[] <- abs(pmin(as.matrix(base_contr), 0))
    base_contr[] <- apply(base_contr, 2, \(x) {ifelse(x==max(x), 1-x, 0-x)})
    base_contr
  }
}

#' @export
replace_emmc <- function(expr, replacements, prefix="my") {
  # expr: a language object (symbol or call)
  # replacements: named character vector, names = old, values = new
  if (is.symbol(expr)) {
    nm <- as.character(expr)
    if (nm %in% replacements) {
      return(as.symbol(paste0(prefix, "_", nm)))
    }
    return(expr)
  }
  if (is.call(expr)) {
    # Recurse into each element of the call
    if (is_formula(expr)) {
      if (length(expr)==3)
        expr[[2]] <- replace_emmc(expr[[2]], replacement=replacements, prefix=prefix)
    } else {
      expr[] <- lapply(expr, replace_emmc, replacements = replacements, prefix=prefix)
    }
    return(expr)
  }
  # leave constants etc alone
  expr
}


#' @export
removeLow <- function(dmc, preserve_across=TRUE) {
  if (preserve_across) {
    per_dataset <- leaf_modify(
      dmc,
      function(leaf, layers) {
        if (inherits(leaf$object, "DESeqDataSet")) apply(counts(leaf$object)==0, 1, all) else TRUE
      }, "sample_sets")$sample_sets
    all_zero <- Reduce(f=`&`, per_dataset, init=TRUE)
    dmc <- leaf_modify(
      dmc,
      function(leaf, layers) {
        if (inherits(leaf$object, "DESeqDataSet")) leaf$object <- leaf$object[!all_zero,]
        leaf}, "sample_sets")
  } else  {
    dmc <- leaf_modify(
      dmc,
      function(leaf, layers) {
        if (inherits(leaf$object, "DESeqDataSet")) leaf$object <- leaf$object[apply(counts(leaf$object)!=0, 1, any),]
        leaf
      }, layers="sample_sets")
  }
  
  dmc <- leaf_modify(
    dmc,
    function(leaf, layers) {
      if (inherits(leaf$object, "DESeqDataSet")) leaf$object <- leaf$object[rowMeans(counts(leaf$object, normalized=TRUE)) >= leaf$baseMeanMin,]
      leaf
    }, layers="sample_sets")
  dmc
}



sample_norm <- function(obj) {
  se <- obj$object
  if (inherits(se, "DESeqDataSet")) {
    if ("controlGenes" %in% names(obj)) {
      controlGenes <- eval(obj$controlGenes, transform(rowData(se), ID=row.names(se)))
      se <- estimateSizeFactors(se, controlGenes=controlGenes)
    } else {
      se <- estimateSizeFactors(se)
    }
    if ("subsetGenes" %in% names(obj)) {
      se <- se[eval(obj$subsetGenes, transform(rowData(se), ID=row.names(se))),]
    }
    assay(se, "vst") <- assay(vst(se, nsub=min(10, nrow(se))))
    
    return(se)
  } else {
    assayNames(se)[1] <- noun_to_readout(rowNoun)
    rowData(se)$nna <- apply(is.na(assay(se)), 1, sum)
    strata <- get_strata(obj$strata, se)
    grp <- lapply(strata, "[[", "samples")
    if ((obj$normalise %||% "none") =="vsn") {
      out <- assay(se)
      scale_factors <- data.frame(a=rep(NA_real_, ncol(out)), b=rep(NA_real_, ncol(out)))
      for (stratum in seq_along(strata)) {
        i <- strata[[stratum]]$samples
        pre <- reduce_by_mcol(se, strata[[stratum]])
        fit <- vsn::vsnMatrix(pre)
        scale_factors$a[i] <- coef(fit)[1,,1]
        scale_factors$b[i] <- coef(fit)[1,,2]
        out[, i] <- vsn::predict(fit, pre)[attr(pre, "ind"),,drop=FALSE]
      }
      assays(se) <- setFirstAssay(se, vst= out)
      colData(se)$.scale_factors <- scale_factors
    }
    imp <- obj$impute
    if (!is.null(imp)) {
      out <- assay(se)
      assay(se, "na") <- is.na(assay(se))
      for (stratum in seq_along(strata)) {
        i <- strata[[stratum]]$samples
        pre <- reduce_by_mcol(se, strata[[stratum]])
        invisible(capture.output({
          out[, i] <- MSnbase::exprs(do.call(
            MSnbase::impute,
            modifyList(imp,
                       list(object=as(SummarizedExperiment(pre), "MSnSet"), differential=NULL))))[attr(pre, "ind"),,drop=FALSE]
        }))
      }
      assays(se) <- setFirstAssay(
        se,
        imputed=out)
    }
    se
  }
}

get_strata <- function(e, se) {
  if (is.null(e)) {
    return(list(list(samples=1:ncol(se), fn=identity, mcol_group=NULL)))
  }
  if (length(e)==1 && length(e[[1]])==2) {
    fml <- eval(e[[1]])
    strata <- interaction(model.frame(fml, colData(se)))
    grps <- split(seq_along(strata), strata)
    return(lapply(grps, function(g) list(samples=g, fn=identity, mcol_group=NULL)))
  } 
  strata <- lapply(e, parse_stratum, se)
  remainder <- !Reduce(`|`, lapply(strata, "[[", "samples"))
  if (any(remainder)) strata$.remainder <- list(samples=remainder, fn=identity, mcol_group=NULL)
  strata
}

reduce_by_mcol <- function(se, stratum) {
  if (!is.null(stratum$mcol_group)) {
    mcol <- mcols(se)[[as.character(stratum$mcol_group)]]
    out <- apply(assay(se)[, stratum$samples, drop = FALSE], 2, tapply,  mcol, stratum$fn)
    structure(out, ind=match(mcol, row.names(out)))
  } else {
    structure(assay(se)[, stratum$samples, drop=FALSE], ind=TRUE)
  }
}
  

parse_stratum <- function(q, se) {
  if (length(q)==3) { ## column= value ~ summary(group)
    sample_ind <- eval(q[[2]], colData(se))
    vars <- all.vars(q[[3]])
    # TODO: document that we use measure == "global" ~ mean(group, na.rm = TRUE) or even  ~(function(a,b) ba(b,a))(gene, usual_first_arg)
    fn <- eval(call("function", as.pairlist(setNames(vector("list", length(vars)), vars)), q[[3]]))
    grp <- if (length(q[[3]])>1) q[[3]][[2]] else NULL  
  }
  list(samples=sample_ind, fn=fn, mcol_group=grp)
}


#' @export
add_extra_assays <- function(dds, extras) {
  for (i in names(extras)) {
    assay(dds,i) <-  generate_assay(extras[[i]], dds)
  }
  dds
}


interpolate <- function(x) {
  splines::ns(x, knots=sort(unique(x))[-c(1, length(unique(x)))], Boundary.knots=range(x, na.rm=TRUE))
}

#' @export
generate_assay <- function(args, dds) {
  curAssay <- assay(dds, args$from)
  if (args$method=="normalise") {
    curFrame <- as.data.frame(colData(dds))
    margs <- modifyList(args, list(from=NULL, method=NULL, design=NULL, hint=NULL, influential_samples=NULL))
    baseFrame <-do.call(
      transform,
      modifyList(margs, list(`_data`=curFrame))
    )
    baseline_ind <- apply(curFrame[names(margs)]==baseFrame[names(margs)], 1, all)
    X <- model.matrix(args$design, curFrame)[baseline_ind, , drop=FALSE]
    QR <- qr(X)
    coefs <- t(qr.coef(QR, t(curAssay[,baseline_ind,drop=FALSE])))
    coefs[is.na(coefs)] <- 0
    X_ref <- model.matrix(args$design, baseFrame)
    stopifnot(identical(colnames(X), colnames(X_ref)))
    out <- curAssay - coefs %*% t(X_ref)
  } else if (args$method=="denoise") {
    clear_infl <- dds
    clear_infl$.influential <- clear_infl$.influential_in_assay <- NULL
    design(clear_infl) <- args$design
    out <- assay(
      partial_reconstruct(clear_infl, args$design, resids=FALSE, assay=args$from),
      args$from)
  } else if (args$method=="partial") {
    design(dds) <- args$design
    out <- assay(
      partial_reconstruct(dds, args$reduced, resids=args$resids %||% TRUE, assay=args$from),
      args$from)
  } else if (args$method == "identity") {
    out <- curAssay
  }
  out
}


#' @export
expr_to_list <- function(x, aliases = c("list")) {
  if (is.call(x) && deparse(x[[1]]) %in% aliases) {
    # It's a list-like call → recursively process elements
    out <- lapply(as.list(x[-1]), expr_to_list, aliases = aliases)
    names(out) <- names(x)[-1]
    out
  } else {
    # Leaf: deparse to string
    paste(deparse(x), collapse = "")
  }
}

eval_dds <- function(dds, expr, assays = assayNames(dds)) {
  e <- new.env(parent = baseenv())
  df <- as.data.frame(colData(dds))

  assays <- intersect(assays, all.vars(expr))
  mnames <- intersect(names(mcols(dds)), all.vars(expr))
    
  # If no dependency on assay, can just use mcols vectorised
  if (length(assays)==0) {
    for (j in mnames) {
      assign(j, mcols(dds)[[j]], envir=e)
    }
    out <- eval(expr, env = e)
    if (length(out) ==1) out <- rep(out, nrow(dds))
    return(out)
  }
  
  # Cache each assay matrix mentioned in expr in a list
  assay_mats <- lapply(setNames(assays, assays),function(a) assayPlus(dds, a))


  mc <- mcols(dds)
  mc_list <- lapply(mnames, function(j) mc[[j]])
  names(mc_list) <- mnames

  if (as.character(expr[[1]]) == "%>%") {
    pipeline_fn <- eval(expr, e)#function closure is now dynamically updatable
    is_fn <- TRUE
  } else {
    is_fn <- FALSE
  }
  
  # Preallocate result vector
  res <- logical(nrow(dds))
  for (i in seq_len(nrow(dds))) {
    # Set each assay vector directly from the cached matrix
    for (a in assays) {
      df[[a]] <- assay_mats[[a]][i, ]
    }
    for (j in mnames) {
      e[[j]] <- mc_list[[j]][i]
    }
    if (is_fn) {
      out <- pipeline_fn(df)
      } else {
        out <- rlang::eval_tidy(expr, data=df, env=e)
      }
    if (is.data.frame(out) && ncol(out) == 1)
      out <- out[[1]]
    if (length(out) == 1)
      res[i] <- out
    else
      stop("Expression must return a single logical value.")
  }
  res
}


em_constraint <- function(fit, constraint) {
  rg <- emmeans::ref_grid(fit)
  em <- emmeans::emmeans(subset(rg, eval(constraint[[2]])), update(eval(constraint[[1]]), revpairwise ~ .))
  em$contrasts@linfct
}


summarise_filters <- function(obj) {
 dfs <- mapply(
    function(ds, id) {
      passes <- sapply(
        mcols(ds$object)$filter,
        function(pass) sprintf("%0.1f%%", 100 * mean(pass))
      )
      df <- data.frame(
        dataset=id,
        filter=names(passes),
        success=passes,
        condition=sapply(ds$feature_filters, deparse1)
      )
      subs <- sapply(mcols(ds$object)$filter, attr, "subpreds")
      if (is.character(subs) && length(subs)==nrow(df)) df$stages <- subs
      df
    },
    obj$sample_sets,
    names(obj$sample_sets),
    SIMPLIFY=FALSE
 )
 df <- bind_rows(dfs)
 if ("stages" %in% names(df)) df$stages[is.na(df$stages)] <- ""
 df
}

get_in_section <- function(lst, sections) {
  ind <- sapply(
    lst,
    function(item)  item$extra$section %in% sections %||% TRUE
  )
  lst[ind]
}

wrap_exposed <- function(x, me, parent = paste0(me, "s"), parent_name = NULL) {
  nms <- if (!is.null(names(x))) names(x) else rep("", length(x))
  need_wrap <-sapply(x,function(child) identical(attr(child, "constructor", exact = TRUE), me)) &
    nms != parent
  # Recurse into potential elements first
  # exclude if it needs wrapping, or isn't a list, or is zero length or it's a parenttype
  for (i in which(!( need_wrap |
        sapply(x, function(x) !is.list(x) || length(x)==0) |
        sapply(nms, identical, parent)))) {
    x[[i]] <- wrap_exposed(x[[i]], me = me, parent = parent, parent_name = nms[[i]])
  }
  if (any(need_wrap)) {
    singleton_items <- setNames(
      x[need_wrap],
      sapply(x[need_wrap], function(y) (attr(y, "ID", exact=TRUE) %||% ""))
    )
    x[[parent]] <- c(x[[parent]], singleton_items)  # append in case parent already exists
    x[need_wrap] <- NULL
  }
  x
}

clean_formula <- function(formula, data) {
  # Identify factors with one level
  single_level_factors <- names(which(sapply(data, function(x) is.factor(x) && length(unique(x)) <= 1)))

  # Remove single-level factors from the formula
  formula_terms <- all.vars(formula)
  formula_terms <- formula_terms[!(formula_terms %in% single_level_factors)]

  if (length(formula_terms) == 0) {
    return(as.formula("~ 1"))  # No predictors, only intercept
  }

  # Rebuild formula without the single-level factors
  formula <- as.formula(paste("~", paste(formula_terms, collapse = " + ")))

  # Now simplify the formula as before
  mm <- model.matrix(formula, data)
  keep_cols <- colSums(abs(mm)) > 0
  keep_cols[which(colSums(mm == 1) == nrow(mm))[-1]] <- FALSE
  terms_obj <- terms(formula)
  term_labels <- attr(terms_obj, "term.labels")
  assign <- attr(mm, "assign")
  keep_terms <- unique(assign[keep_cols])
  if (length(setdiff(assign, keep_terms)) == 0) return(formula)
  keep_terms <- keep_terms[keep_terms != 0]
  new_terms <- term_labels[keep_terms]
  if (length(new_terms) == 0) {
    as.formula("~ 1")
  } else {
    as.formula(paste("~", paste(new_terms, collapse = " + ")))
  }
}

subsets_from_formula <- function(ss, df) {
  vars <- all.vars(ss$split)
  combos <- unique(df[vars])
  lapply(setNames(seq_len(nrow(combos)), do.call(interaction, combos)), function(i) {
    row <- combos[i, ]
    apply(df[vars], 1, function(x) all(x == row)) & ss$subset
  })
}
