## *** Useful Functions

# e.g. set grp=whole_cell, denominator=fraction=="cyt", to implement nuc/cyt
#     or grp=whole_cell, numerator=fraction!="cyt", to implement nuc/(nuc+cyt)
norm_within <- function(df, grp, denominator, numerator, adj=0.01) {
  ret <- NA
  if (!missing(denominator)) {
    ret <- list(
      adj=adj,
      ind=df |>
        mutate(.ind=1:n()) |>
        group_by({{grp}}) |>
        mutate(.ind=ifelse({{denominator}}, NA, .ind[{{denominator}}])) |>
        pull(.ind)
    )
  } else if (!missing(numerator)) {
    ret <- list(
      adj=adj,
      ind=df |>
        mutate(.ind=1:n()) |>
        group_by({{grp}}) |>
        mutate(.ind= ifelse({{numerator}}, NA, list(unique(.ind)))) |>
        pull(.ind)
    )
  }
  ret
}


load_specs <- function(file="", context) {
  if (file.exists(file.path("extdata",file))) {
    df <- as.data.frame(colData(context))
    e <- as.environment(df)
    isVarying <- which((sapply(df, function(v) length(unique(v))) %% nrow(df)) > 1)
    assign("Guess", names(df)[isVarying][1], envir=e)
    list_ok <- function(...) rlang::dots_list(..., .ignore_empty="all")
    parent.env(e) <- environment()
    assign("list", list_ok, envir=e)
    assign("sample_set", list_ok, envir=e)
    assign("model", list_ok, envir=e)
    assign("specification", list_ok, envir=e)
    assign("comparison",
           function(x, name=NULL, description=NULL,...) {
             # Allow for potentially missing mult_comp wrapper around e.g. revpairwise ~ treatment
             if (is_formula(x) && length(x)==3) {
                 out <- list(spec=x,...)
                 class(out) <- "post_hoc"
             } else {
               out <- x
             }
             attributes(out) <- c(attributes(out), list(name=name, description=description))
             out
           },
           envir=e)
    assign("profile_plot",
           function(x, name=NULL, description=NULL) {
             attributes(x) <- list(name=name, description=description)
             x
           },
           envir=e)
    normalise_within <- function(...) {
      norm_within(as.data.frame(colData(context)), ...)}
    deparser <- function(...) {
             unev <- as.list( substitute(alist(...)))[-1]
             ind <- sapply(unev, function(s) !(is.atomic(s) || is.null(s)))
             mapply(function(a, i, u) {
               if (i) {
                 attr(a, "deparse") <- deparse1(u, width.cutoff=500)
               }
               a
             },
             list(...),
             ind,
             unev)
           }
    assign("settings",
           deparser,
           envir=e
           )
    assign("mutate",
           function(...) {
             substitute(alist(...))
           },
           envir=e
           )
    specs <- source(file.path("extdata",file), local=e)$value
    assign("sample_set", expression, envir=e) # avoid evaluating any examples sample_sets.
    pkg_defaults <-default_spec_settings()
    new_settings <- setdiff(names(pkg_defaults), names(specs$settings))
    if (length(new_settings)>0) {
      string_rep <- lapply(pkg_defaults[new_settings], deparse1)
      warning("New settings (", paste(new_settings), ") can be set in ", file, ", so please update it. The default values that will be used are:\n", paste(names(string_rep), string_rep, sep=": ", collapse="\n"))
      specs$settings[new_settings] <- do.call(deparser, pkg_defaults[new_settings])
    }
    rm(list=ls(envir=e), envir=e)
  } else {
    fml <- paste("~", names(colData(dds))[ncol(colData(dds))])
    specs <- list(
      sample_sets = list(all=TRUE),
      models=list(
        "Naive" = list(
          design = as.formula(fml),
          comparisons = mult_comp(as.formula(paste("pairwise", fml)))
        )
      ),
      plot_scale = function(y) {
        y/mean(y)
      }
    )
  }
  specs
}

##' Recode nested factors to avoid matrix-rank problems
##'
##' Following the suggestion in the DESeq2 vignette, recode nested factors so that
##' they take common values in different clusters to avoid rank problems
##' @title Recode nested factors
##' @param inner A factor representing the variable to be recoded, e.g. the cell-line
##' @param ... The parent factors that 'inner' is inside, e.g. the genotype of the cell-line
##' @return A factor with recoded levels
##' @author Gavin Kelly
##' @export
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


## default_names <- function(obj, prefix="", offset=0) {
##   ifelse(names(obj)=="", paste0(prefix, seq_along(obj)+offset), names(obj))
##   }

default_namer <- function() {
  offsets <- list() 
  function(obj, prefix="") {
    if (!prefix %in% names(offsets)) offsets[[prefix]] <- 0
    out <- ifelse(names(obj)=="", paste0(prefix, seq_along(obj)+offsets[[prefix]]), names(obj))
    offsets[[prefix]] <<- offsets[[prefix]] + length(obj)
    out
  }
}

##' Expand an analysis specification into its corresponding subset list
##'
##' Generate a list of DESeq2 objects corresponding to the different
##' subsets specified
##' @title Generate subsets of DESeq2 object
##' @param dds The original DESeq2 object containing all samples
##' @param spec The analysis specificiation
##' @return A list of DESeq2 objects
##' @author Gavin Kelly
##' @export
build_dds_list <- function(dds, spec) {
  # Function to recurse down the spec > sample_sets > models > comparisons hierarchy, and cascade down values of a given field as it encounters them.
  trickle_down <- function(field, to="comparisons", default=NULL, merge_fn=function(x,y) {if (is.null(x)) y else x}, obj=spec, current_level="spec") {
    if (field %in% names(obj)) {
      mine <- merge_fn(obj[[field]], default)
    } else {
      mine <- default
    }
    if (current_level==to) {
      obj[[field]] <- mine
    } else {
      next_level=list(spec="sample_sets", sample_sets="models", models="comparisons")[[current_level]]
      obj[[next_level]] <- lapply(
        obj[[next_level]],
        function(x) trickle_down(field=field, to=to, default=mine, merge_fn=merge_fn, obj=x, current_level=next_level))
    }
    obj
  }
  # Share any top-level models down to each sample-set
  spec <- trickle_down(field="models", to="sample_sets", merge_fn=c)
  # Fill in any missing qc_formulae with values from closest parent if necessary
  spec <- trickle_down(field="qc_formulae", to="models")
  spec <- trickle_down(field="profile_plots", to="models")
  # Conjunct or cascade any top-level subsetting - if missing, use all samples
  spec <- trickle_down(field="subset", to="sample_sets", default=TRUE, merge_fn=`&`)
  # Cascade any spec-wide transforms
  spec <- trickle_down(field="transform", to="sample_sets")
  # various model parameters that might be shared across datasets/everything
  spec <- trickle_down(field="drop_unsupported_combinations", to="models")
  spec <- trickle_down(field="drop_incomplete", to="models")
  spec <- trickle_down(field="varNames", to="sample_sets", merge_fn=modifyList, default=list())
  spec <- trickle_down(field="varDescriptions", to="sample_sets", merge_fn=modifyList, default=list())
  spec <- trickle_down(field="termNames", to="sample_sets", merge_fn=modifyList, default=list())
  spec <- trickle_down(field="filterFeatures", to="sample_sets", default=spec$settings$filterFeatures)
  spec <- trickle_down(field="filterQC", to="sample_sets", default=spec$settings$filterQC)
  spec <- trickle_down(field="impute", to="sample_sets", default=spec$settings$impute)
  spec <- trickle_down(field="normalise", to="sample_sets", default=spec$settings$normalise)
  spec <- trickle_down(field="external_list", to="models", default=NULL)
  modelled_terms <- lapply(
    spec$sample_sets,
    function(x) {lapply(
      x$models,
      function(y) {
        d <- c()
        if (is_formula(y$design))
          d <- all.vars(update(y$design, NULL ~ .))
        if ("profile_plots" %in% names(y))
            d <- c(d, unlist(lapply(y$profile_plots, all.vars)))
        d
      })
    })
  modelled_terms <-  setdiff(unique(unlist(modelled_terms)), ".")
  if (!"palette" %in% names(spec$settings)) {
    spec$settings$palette="Set1"
  }
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
  names(spec$sample_sets) <- default_names(spec$sample_sets, prefix="D")
  for (dataset_i in seq_along(spec$sample_sets)) {
    names(spec$sample_sets[[dataset_i]]$models) <- default_names(spec$sample_sets[[dataset_i]]$models, prefix="M")
    for (model_i in seq_along(spec$sample_sets[[dataset_i]]$models)) {
      if ("comparisons" %in% names(spec$sample_sets[[dataset_i]]$models[[model_i]])) {
        names(spec$sample_sets[[dataset_i]]$models[[model_i]]$comparisons) <- default_names(spec$sample_sets[[dataset_i]]$models[[model_i]]$comparisons, prefix="C")
      }
      if ("profile_plots" %in% names(spec$sample_sets[[dataset_i]]$models[[model_i]])) {
        names(spec$sample_sets[[dataset_i]]$models[[model_i]]$profile_plots) <- default_names(spec$sample_sets[[dataset_i]]$models[[model_i]]$profile_plots, prefix="P")
      }
    }
    dataset_spec <- spec$sample_sets[[dataset_i]]
    obj <- dds
    if ("baseline" %in% names(dataset_spec)) {
      if (!is.list(dataset_spec$baseline$ind)) {
        is_numerator <- !is.na(dataset_spec$baseline$ind)
        norm <- counts(obj[,dataset_spec$baseline$ind[is_numerator]]) + dataset_spec$baseline$adj
      } else {
        is_numerator <- sapply(dataset_spec$baseline$ind, function(x) !all(is.na(x)))!=0
        norm <- sapply(dataset_spec$baseline$ind[is_numerator], function(x) rowSums(counts(obj[,x]))) + dataset_spec$baseline$adj
      }
      obj <- obj[,is_numerator]
      normalizationFactors(obj) <- norm
    }
    mdlList <- dataset_spec$models
    obj <- obj[, dataset_spec$subset]
    colData(obj) <- droplevels(colData(obj))
    if (!is.null(dataset_spec$filterFeatures)) {
      keepFeaturesInd <- eval_dds(obj, dataset_spec$filterFeatures, assays=c(assayNames(obj), "norm", "missing"))
      obj <- obj[keepFeaturesInd,]
    }
    if (!is.null(dataset_spec$filterQC)) {
      mcols(obj)$filterQC <- eval_dds(obj, dataset_spec$filterQC,assays=c(assayNames(obj), "norm", "missing"))
    }    
    if ("termNames" %in% names(dataset_spec)) {
      metadata(obj)$termNames <- dataset_spec$termNames
    } else {
      metadata(obj)$termNames <- list()
    }
    if ("varNames" %in% dataset_spec) {
      varNames <- sapply(names(colData(obj)), identity)
      varNames[names(dataset_spec$varNames)] <- unlist(dataset_spec$varNames)
      mcols(colData(obj))$name <- varNames
    }
    if ("varDescriptions" %in% dataset_spec) {
      varDescriptions <- sapply(names(colData(obj)), identity)
      varDescriptions[names(dataset_spec$varDescriptions)] <- unlist(dataset_spec$varDescriptions)
      mcols(colData(obj))$description <- varDescriptions
    }

    # If no models have qc_formulae, set the first model to have a sensible default based on design
    if (!any(sapply(mdlList, function(x) "qc_formulae" %in% names(x)))) {
      mdlList[[1]]$qc_formulae <- as.formula(
        paste0(
          paste(all.vars(mdlList[[1]]$design), collapse=" + "),
          "~",
          0))
      
    }
    for (i in seq_along(mdlList)) {
      if (!"qc_formulae" %in% names(mdlList[[i]])) {
        # default to the set of models removing any terms that will preserve marginality
        mdlList[[i]]$qc_formulae <- find_simpler_models(mdlList[[i]]$design, do_aes=FALSE, type="simplest")
      } else {
        if (is_formula(mdlList[[i]]$qc_formulae)) {
          # We used to allow a singleton formula - wrap these in a list.
          mdlList[[i]]$qc_formulae <- list(I(mdlList[[i]]$qc_formulae))
        }
      }
      if (is_null(section_chooser(mdlList[[i]], "profile_plots", "exploratory_profile_plots", "differential_profile_plots"))) {      
        # default to the set of models removing any terms that will preserve marginality
        mdlList[[i]]$profile_plots <- find_simpler_models(mdlList[[i]]$design, do_aes=TRUE, type="auto")
      } else {
        for (profiler in c("profile_plots", "exploratory_profile_plots", "differential_profile_plots")) {
          if (!is_null(section_chooser(mdlList[[i]], profiler))) {
            mdlList[[i]][[profiler]] <- lapply(mdlList[[i]][[profiler]], function(p) update(mdlList[[i]]$design, p))
          }
        }
      }
    }
    metadata(obj)$models <- mdlList
    if ("sample_swap" %in% names(dataset_spec)) {
      for (x1 in names(dataset_spec$sample_swap)) {
        i1 <- match(x1, colData(obj)$ID)
        i2 <- match(dataset_spec$sample_swap[[x1]], colData(obj)$ID)
        tmp <- colData(obj)[i1, -1, drop=FALSE]
        colData(obj)[i1, -1] <- colData(obj)[i2, -1, drop=FALSE]
        colData(obj)[i2, -1] <- tmp
      }
    }
    tr <- dataset_spec$transform
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
      .mu <- purrr::partial(mutate, .data=as.data.frame(colData(obj)))
      tr[[1]] <- .mu
      cnames <- colnames(obj)
      md <- metadata(colData(obj))
      colData(obj) <- S4Vectors::DataFrame(eval(tr))
      metadata(colData(obj)) <- md
      colnames(obj) <- cnames
      if (".include" %in% names(colData(obj))) {
        obj <- obj[,colData(obj)[[".include"]]]
        colData(obj) <- droplevels(colData(obj))
      }
      new_cols <- intersect(modelled_terms, setdiff(names(colData(obj)), names(default_palette$Heatmap)))
      old_cols <- setdiff(modelled_terms, new_cols)
      if (length(old_cols)>0) {
        is_modified <- sapply(old_cols,
                               function(x) {
                                 if (class(colData(obj)[[x]]) != class(colData(obj)[[x]])) return(TRUE)
                                 if (is.factor(colData(obj)[[x]])) return(!all(levels(colData(obj)[[x]]) %in%  levels(colData(obj)[[x]])))
                                 if (is.character(colData(obj)[[x]])) return(!all(unique(colData(obj)[[x]]) %in%  levels(unique(obj)[[x]])))
                                 return(!all(range(colData(obj)[[x]], na.rm=TRUE)==range(colData(obj)[[x]], na.rm=TRUE)))
                               })
        new_cols <- c(new_cols, old_cols[is_modified])
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
    if ("collapse" %in% names(dataset_spec)) {
      mf <- model.frame(dataset_spec$collapse, data.frame(colData(obj)))
      ind <- match(do.call(paste, c(mf, sep="\r")),
                   do.call(paste, c(unique(mf), sep="\r")))
      obj <- collapseReplicates(obj, groupby=factor(ind), renameCols=FALSE)
    }
    metadata(obj)$impute <- dataset_spec$impute
    metadata(obj)$normalise <- dataset_spec$normalise
    ddsList[[names(spec$sample_sets)[dataset_i]]] <- obj
  }
  ddsList <- imap(ddsList,
                  function(obj, dname) {
                    metadata(obj)$dmc <- list(
                      dataset=dname,
                      dataset_name=spec$sample_sets[[dname]]$name,
                      dataset_description=spec$sample_sets[[dname]]$description)
                    obj
                  }
                  )
}

##' Calculate dimension reduction 
##'
##' Add a vst transformed assay, and a projection of the samples ont PCA space
##' @title Store dimension-reduction results in DESeq2 object
##' @param dds The original DESeq2 object containing all samples
##' @param n 
##' @param family 
##' @param batch 
##' @param spec The analysis specificiation
##' @return 
##' @author Gavin Kelly
##' @export
add_dim_reduct  <-  function(dds, n=Inf, family="norm", batch=~1, do_vst=inherits(dds, "DESeqDataSet")) {
  if (do_vst) {
    if ("vst" %in% assayNames(dds)) {
      var_stab <- assay(dds, "vst")
    } else {
      var_stab <- assay(vst(dds, nsub=min(1000, nrow(dds))))
      assay(dds, "vst") <- var_stab
    }
  } else {
    var_stab <- assay(dds)
  }
  if (batch != ~1) {
    var_stab <- residuals(limma::lmFit(var_stab, model.matrix(batch, as.data.frame(colData(dds)))), var_stab)
  }
  colnames(var_stab) <- colnames(dds)
  if (family=="norm") {
    pc <- prcomp(t(var_stab), scale=FALSE)
    percentVar <- round(100 * pc$sdev^2 / sum( pc$sdev^2 ))
    colData(dds)$.PCA <- DataFrame(pc$x)
    metadata(colData(dds)$.PCA)$percentVar <- setNames(percentVar, colnames(pc$x))
    mcols(dds)$PCA <-DataFrame(pc$rotation)
  } else {
    co <- counts(dds, norm=FALSE)
    pc_glm <- glmpca::glmpca(Y=co[rowSums(co)!=0,],
                            L=ncol(co),
                            fam=family,
                            X=if(batch == ~1) 
                              NULL
                            else
                              model.matrix(batch, as.data.frame(colData(dds)))
                            )
    colData(dds)$.PCA <- DataFrame(pc_glm$factors)
    metadata(colData(dds)$.PCA)$percentVar <- setNames(rep(0, ncol(co)), colnames(pc$x))
  }
  dds
}

if(!isGeneric("design")) {
  setGeneric("design", function(object,...){standardGeneric("design")})
  setGeneric("design<-", function(object, value, ...){standardGeneric("design")})
}

#' @importFrom DESeq2 design
#' @importFrom DESeq2 "design<-"
setMethod("design", "SummarizedExperiment", function(object) {
  metadata(object)$design
})
setReplaceMethod("design", signature(object="SummarizedExperiment", value="formula"), function(object, value) {
  metadata(object)$design <- value
  object
})
setReplaceMethod("design", signature(object="SummarizedExperiment", value="matrix"), function(object, value) {
  metadata(object)$design <- value
  object
})


##' Fit the models of expression
##'
##' Iterate through each model (stored in the 'models' metadata of a
##' DESeqDataSet) and expand the contrasts so each contrast gets a
##' separate nested level.
##' @title Fit the DESeq2 models
##' @param dds The original DESeq2 object containing all samples
##' @param ...
##' @return
##' @author Gavin Kelly
##' @export
fit_models <- function(dds, param, ...) {
  model_comp <- lapply(
    metadata(dds)$models,
    function(mdl) {
      fit_model(mdl, dds, ...)
    }
  )
  model_comp <- model_comp[sapply(model_comp, length)!=0]
  model_comp <- imap(model_comp, function(obj, mname) {
    lapply(obj, function(y) {
      metadata(y)$dmc$model <- mname
      metadata(y)$dmc$model_name <- metadata(y)$model$name
      metadata(y)$dmc$model_description <- metadata(y)$model$description
      y})
  })
  model_comp
}



fit_model <- function(mdl, dds, ...) {
  message("Processing model ", mdl$name)
  model_dds <- dds
  design(model_dds) <- mdl$design
  metadata(model_dds)$model <- mdl
  model_dds <- check_model(model_dds)
  if (any(metadata(model_dds)$model$dropped)) {
    design(model_dds) <- metadata(model_dds)$model$mat
  }
  ## Generate a nested list - single comparisons will be singletons, expanded mult_comps may not be.
  out <- list()
  metadata(model_dds)$model_fit_done <- FALSE
  for (comp_ind in seq(along=mdl$comparisons)) {
    message("Processing comparison ", comp_ind)
    fit <- fit_comparison(comp=mdl$comparisons[[comp_ind]], model_dds=model_dds, mdl=mdl, ...)
    out[[comp_ind]] <- fit
    if (length(fit)!=0 && metadata(fit[[1]])$model_fit_done && !metadata(model_dds)$model_fit_done) {
      model_dds <- fit[[1]]
    }
  }
  names(out) <- names(mdl$comparisons)
  ## Flatten the list, but preserve the original comparison name in the dmc metadata.
  out <- unlist(out, recursive=FALSE)
  out <- imap(out, function(obj, cname) {
    metadata(obj)$comparison_code <- paste0("res <- results(dds, contrast=",deparse1(metadata(obj)$comparison),")")
    metadata(obj)$dmc$comparison <- cname
    comp <- metadata(obj)$comparison
    if (is.character(comp) && length(comp)==1) {#'name' contrast so baseline is intercept
      #TODO Set baseline_contrast to intercept
    }
    if (is.list(comp)) { # a character contrast
      #TODO - Maybe a way to set baseline_contrast in this situation
    }
    obj
  })
  return(out)
}

fit_comparison <- function(comp, model_dds, mdl, ...) {
  if (is_formula(comp)) { # Do the usual DESeq2 LRT
    return(fitLRT(model_dds, mdl=mdl, reduced=comp, ...))
  } else if (class(comp)=="post_hoc") { #Multiple-comparisons
    strip <- c("spec","name","description")
    contrs <- emcontrasts(dds=model_dds, comp=comp)
    if (length(contrs)==0) return(list())
    if (comp$LRT %||% FALSE) { # Do LRT-equivalents of the multiple ward tests
      mdl_mat <- metadata(model_dds)$model$mat %||% model.matrix(mdl$design, as.data.frame(colData(model_dds)))
      return(lapply(
        contrs,
        function(contr) {fitContrastLRT(model_dds, mdl=mdl_mat, contr=contr, ...)}
      )
      )
    } else if ((mdl$approach %||% "DESeq2")=="voom"){
      ## TODO: possibly optimise/cache repeated calls to fitVoom, like 'model_fit_done'
      fit <- fitVoom(model_dds, mdl)
      fit <- limma::contrasts.fit(fit, do.call(cbind, contrs))
      fit <- limma::eBayes(fit)
      metadata(model_dds)$limma <- fit
    } else if ((mdl$approach %||% "DESeq2")=="limma" || !inherits(model_dds, "DESeqDataSet")){
      ## TODO: possibly optimise/cache repeated calls to fitVoom, like 'model_fit_done'
      if (is_formula(design(model_dds))) {
        mm <- model.matrix(design(model_dds), colData(model_dds))
      } else {
        mm <- design(model_dds)
      }
      fit <- limma::lmFit(assay(model_dds), mm)
      nb <- apply(!is.na(assay(model_dds)), 1, function(x) estimability::nonest.basis(fit$design[x,]))
      isEst <- apply(do.call(cbind,contrs),2, function(x) {sapply(nb,  function(y) estimability::is.estble(x, y))})
      fit <- limma::contrasts.fit(fit, do.call(cbind, contrs))
      fit$coefficients[!isEst] <- NA
      fit <- limma::eBayes(fit)
      metadata(model_dds)$limma <- fit
    } else {
      if (!metadata(model_dds)$model_fit_done) {
        model_dds <- DESeq2::DESeq(model_dds, test="Wald", ...)
        metadata(model_dds)$model_fit_done <- TRUE
      } # no need for an 'else': the model fit has already been done
    }
    # Return a list of DESeq2 objects, with the comparison metadata set.
    return(lapply(
      contrs,
      function(contr) {
        metadata(model_dds)$models <- NULL
        metadata(model_dds)$comparisons <- NULL
        metadata(model_dds)$comparison <- contr
        model_dds}
    ))
  } else {
    # Just a single DESeq2 Wald
    ## TODO: We should handle limma here as well, using retrieve_contrasts to cast DESeq's comparisons as limma contasts
    if (!metadata(model_dds)$model_fit_done) {
      model_dds <- DESeq2::DESeq(model_dds, test="Wald", ...)
      metadata(model_dds)$model_fit_done <- TRUE
    }
    metadata(model_dds)$models <- NULL
    metadata(model_dds)$comparisons <- NULL
    metadata(model_dds)$comparison <- comp
    return(list(model_dds))
  }
}


annihilator <- function(x) diag(nrow = nrow(x)) - x %*% solve(t(x) %*% x) %*% t(x)
reduced_design.fit <- function(fit, reduced_design){
  full_design <- fit$design
  mapping <- lm(reduced_design ~ full_design - 1)
  if(sum(abs(residuals(mapping))) > 1e-8){
    stop("Apparently the reduced design is not nested in the full design")
  }
  cntrst <- annihilator(coef(mapping))
  colnames(cntrst) <- colnames(full_design)
  rownames(cntrst) <- colnames(full_design)
  cntrst <- cntrst[, colSums(abs(cntrst)) > 1e-8]
  limma::contrasts.fit(fit, contrast = cntrst)
}

##' Check model
##'
##' Run formula through an lm to check it
##' @title Check model
##' @param mdl 
##' @param coldat 
##' @param dds The original DESeq2 object containing all samples
##' @return 
##' @author Gavin Kelly
##' @export
check_model <- function(dds) {
  mdl <- metadata(dds)$model
  mdl$dropped <- FALSE
  if (is_formula(mdl$design) ) {
    df <- as.data.frame(colData(dds))
    na_covars <- apply(is.na(df[all.vars(mdl$design)]), 1, any)
    if ("drop_incomplete" %in% names(mdl) && mdl$drop_incomplete==TRUE && any(na_covars)) {
      warning("Dropping samples ", paste0(row.names(df)[na_covars], collapse=", "), " as they have incomplete metadata")
      dds <- dds[, !na_covars]
      colData(dds) <- droplevels(colData(dds))
      df <- as.data.frame(colData(dds))
    }
    if (inherits(dds, "DESeqDataSet")) {
      df$.x <- counts(dds, norm=TRUE)[1,]
    } else {
      df$.x <- rnorm(ncol(dds))
    }
    fml <- update(mdl$design, .x ~ .)
    fit <- lm(fml, data=df)
    mdl$lm <- fit
    if ("drop_unsupported_combinations" %in% names(mdl) && mdl$drop_unsupported_combinations==TRUE) {
      mdl$dropped <- is.na(coef(fit))
    } else {
      if (any(is.na(coef(fit)))) {
        warning("Can't estimate some coefficients in ", mdl$design, ".\n In unbalanced nested designs, use the option 'drop_unsupported_combinations=TRUE,' in the problematic model. Other causes are complete confounding or conditions with no observations.")
      }
    }
  }
  if (any(mdl$dropped)) {
    mm <- model.matrix(mdl$design, as.data.frame(colData(dds)))[,!mdl$dropped]
    colnames(mm) <- .resNames(colnames(mm))
    mdl$mat <- mm
    metadata(dds)$model_code <-c(
      "# Warning - creates long lines.  May be necessary to chunk it into smaller continuation lines in R console",
      paste0("df <- eval(parse(text='", deparse1(as.data.frame(colData(dds)), collapse="\n"),"'))"),
      paste0("mm <- model.matrix(",deparse1(mdl$design),",df)[,-c(",paste(which(mdl$dropped), collapse=", "),")]"),
      "colnames(mm)[colnames(mm)==\"(Intercept)\"] <- \"Intercept\"",
      "colnames(mm) <- make.names(colnames(mm))",
      "colData(dds) <- df",
      "design(dds) <- mm"
    ) 
  } else {
    metadata(dds)$model_code <- c(
      paste0("df <- eval(parse(text='", deparse1(as.data.frame(colData(dds))),"'))"),
      "colData(dds) <- df",
      paste0("design(dds) <- ", deparse1(mdl$design))
    )
  }
  metadata(dds)$model <- mdl
  dds
}


##' Post-hoc generator
##'
##' Wrap a formula so that emmeans can auto-expand it
##' @title Mark a formula as a multiple comparison
##' @param spec 
##' @param ... 
##' @param dds The original DESeq2 object containing all samples
##' @return 
##' @author Gavin Kelly
##' @export
mult_comp <- function(spec, name=NULL, description=NULL, omnibus=FALSE, keep=TRUE, trend=FALSE, ...) {
  obj <- list(spec=spec, omni=omnibus, keep=keep, trend=trend, ...)
  class(obj) <- "post_hoc"
  attributes(obj) <- c(attributes(obj), list(name=name, description=description))
  obj
}

##' Expand post-hoc comparisons
##'
##' Use emmeans to expand keywords
##' @title Expand multiple comparisons into their contrasts
##' @param dds The original DESeq2 object containing all samples
##' @param spec 
##' @return 
##' @author Gavin Kelly
##' @export
emcontrasts <- function(dds, comp, prefix="my") {
  em_extra <- comp[setdiff(names(comp), c("spec", "keep", "LRT", "omni", "trend"))]
  mdl <- metadata(dds)$model
  if (comp$trend) {
    em_fn <- emmeans::emtrends
  } else {
    em_fn <- emmeans::emmeans
  }
  emc <- do.call(em_fn, c(list(object=mdl$lm, specs= comp$spec), em_extra))$contrasts
  contr_frame <- as.data.frame(summary(emc))
  ind_est <- !is.na(contr_frame$estimate)
  contr_frame <- contr_frame[ind_est,1:(which(names(contr_frame)=="estimate")-1), drop=FALSE]
  contr_frame[] <- lapply(contr_frame, function(x) sub("|", "†", x, fixed=TRUE))
  contr_mat <- emc@linfct[ind_est, !mdl$dropped, drop=FALSE]
  if (inherits(dds, "DESeqDataSet")) {
    colnames(contr_mat) <- .resNames(colnames(contr_mat))
  }
  new_emmc <- sub("\\.emmc$", "", ls("package:emmeans", pattern="*.emmc"))
  embaseline <- do.call(em_fn, c(list(object=mdl$lm, specs= replace_emmc(comp$spec, new_emmc)), em_extra))
  baseline_mat <- embaseline$contrast@linfct[ind_est, !mdl$dropped, drop=FALSE]
  if (comp$omni) {
    split_idx <- split(which(ind_est), interaction(emc@grid[ind_est, emc@misc$by.vars], drop = TRUE))
  } else {
    split_idx <- setNames(
      seq_len(nrow(contr_frame)),
      do.call(paste, c(contr_frame,sep= "|"))
    )
  }
  contr <- lapply(split_idx, function(i) t(contr_mat[i,,drop=FALSE]))
  contr <- mapply( function(cont, base) {
    attr(cont, "spec") <- comp$spec
    if (!comp$omni) {
      attr(cont, "baseline_contrast") <- base
    }
    cont},
    contr,
    lapply(split_idx, function(i) t(baseline_mat[i,,drop=FALSE])),
    SIMPLIFY=FALSE)
  contr  <- contr[comp$keep]
  contr
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

##' Fit an LRT model
##'
##' Insert the 'comparison' formula into the reduced slot
##' @title Fit LRT
##' @param dds The original DESeq2 object containing all samples
##' @param reduced 
##' @param ... 
##' @return 
##' @author Gavin Kelly
fitLRT <- function(dds, mdl, reduced, ...) {
  mdl <- metadata(dds)$model
  metadata(dds)$comparison <- reduced
  if (any(mdl$dropped)) {
    full <- mdl$mat
    reduced <- model.matrix(reduced, colData(dds))
    ## unsupported_ind <- apply(reduced==0, 2, all)
    ## reduced <- reduced[, !unsupported_ind]
    ## colnames(reduced) <- .resNames(colnames(reduced))
    reduced <- reduced[,.resNames(colnames(reduced)) %in% colnames(full), drop=FALSE]
    metadata(dds)$reduced_mat <- reduced
  } else {
    full <- mdl$design
  }
  if (is_formula(reduced) && grepl("\\|", as.character(reduced)[[2]])) {
    emc <- emmeans(metadata(dds)$model$lm,
                  update.formula(reduced, trt.vs.ctrl ~ .))$contrasts
    split_idx <- split(seq_len(nrow(emc@grid)), interaction(emc@grid[emc@misc$by.vars], drop = TRUE))
    linfct_by_stratum <- lapply(split_idx, function(idx) t(emc@linfct[idx, , drop = FALSE]))
    # TODO: Need to generate n=|stratum| separate reduced model matrices
    if (inherits(dds, "DESeqDataSet")) {
      stop("DEseq2 stratified ANOVA not implemented yet")
    } else {
      mm <- model.matrix(design(dds), colData(dds))
      fit <- limma::lmFit(assay(dds), mm)
      return(
        lapply(
          linfct_by_stratum,
          function(cntrst) {
            out <- dds
            metadata(out)$limma <- limma::eBayes(limma::contrasts.fit(fit, contrast = cntrst))
            out
          })
      )
    } 
  }
  if (inherits(dds, "DESeqDataSet")) {
    DESeq2::design(dds) <- full
    dds <- DESeq2::DESeq(dds, test="LRT", full=full, reduced=reduced, ...)
    metadata(dds)$LRTterms=setdiff(
      colnames(attr(dds, "modelMatrix")),
      colnames(attr(dds, "reducedModelMatrix"))
    )
  } else {
    design(dds) <- full
    if (is_formula(design(dds))) {
      mm <- model.matrix(design(dds), colData(dds))
    } else {
      mm <- design(dds)
    }
    fit <- limma::lmFit(assay(dds), mm)
    if (is_formula(reduced)) {
      reduced <- model.matrix(reduced, colData(dds))
    }
    fit <- reduced_design.fit(fit, reduced)
    fit <- limma::eBayes(fit)
    metadata(dds)$limma <- fit
  }
  metadata(dds)$models <- NULL
  metadata(dds)$comparisons <- NULL
  list(dds)
}


fitContrastLRT <- function(dds, mdl_mat, contr, ...) {
  ind <- contr!=0
  # Insert a new final column that is the contrast, and remove a column that is now linearly dependent
  # (we chose the right-most column that is involved in the contrast)
  new_column <- apply(mdl_mat[,ind,drop=FALSE], 1, function(x) sum(x*contr))
  old_column_ind <- which(ind)[sum(ind)] # ie last column involved in the contrast
  mdl_mat <- cbind(mdl_mat[,-old_column_ind, drop=FALSE], contrast_column=new_column)
  # The reduced model space is spanned by the constraint that the contrast is zero
  # ie the final column of the new parametrisation
  reduced <- mdl_mat[,-ncol(mdl_mat),drop=FALSE]
  metadata(dds)$comparison <- contr
  metadata(dds)$reduced_mat <- reduced
  DESeq2::design(dds) <- mdl_mat
  dds <- DESeq2::DESeq(dds, test="LRT", full=mdl_mat, reduced=reduced, ...)
  metadata(dds)$LRTterms <- "contrast_column"
  metadata(dds)$models <- NULL
  metadata(dds)$comparisons <- NULL
  dds
}


## apply contrast, and transfer across interesting mcols from the dds
##' Generate results object
##'
##' Insert results columns into mcols
##' @title Generate the results for a model and comparison
##' @param dds The original DESeq2 object containing all samples
##' @param mcols 
##' @param filterFun 
##' @param lfcThreshold 
##' @param ... 
##' @return 
##' @author Gavin Kelly
##' @export
get_result <- function(dds, mcols=c("symbol", "entrez"), filterFun=IHW::ihw, lfcThreshold=0, alpha=0.1, LRT_effect="default", ...) {
  if (is.null(filterFun)) filterFun <- rlang::missing_arg()
  comp <- metadata(dds)$comparison
  if (length(alpha)>1) {
    alpha <- sort(alpha)
    alpha1 <- alpha[1]
  } else {
    alpha1 <- alpha
  }
  if (is_formula(comp)) { # it's LRT (or F test for limma)
    if (inherits(dds, "DESeqDataSet")) {
      r <- results(dds, filterFun=filterFun, alpha=alpha1, ...)
    } else {
      lim <- metadata(dds)$limma
      r <- limma::topTable(lim, coef=NULL,
                          genelist=row.names(lim$genes),
                          number=Inf, sort.by="none")
      co_mat <- cbind(as.matrix(r[,1:(which(names(r)=="AveExpr")-1), drop=FALSE]), 0)
      r <- with(r, DataFrame(baseMean=2^AveExpr,
                            log2FoldChange=apply(co_mat, 1, function(x) diff(range(x))),
                            lfcSE=lim$sigma,
                            class="",#colnames(co_mat)[ind],
                            pvalue=P.Value,
                            padj=adj.P.Val,
                            row.names=row.names(dds)))
      metadata(r)$alpha <- alpha1
    }
  } else {  # Wald
    if (is.character(comp) && length(comp)==1) { #  it's a name
      r <- DESeq2::results(dds, filterFun=filterFun, lfcThreshold=lfcThreshold, name=metadata(dds)$comparison, alpha=alpha1, ...)
    } else { # it's a contrast
      if (is.list(comp) && "listValues" %in% names(comp)) {
        r <- DESeq2::results(dds, filterFun=filterFun, lfcThreshold=lfcThreshold, contrast=metadata(dds)$comparison[names(comp) != "listValues"], listValues=comp$listValues, alpha=alpha1, ...)
      } else {
        if ("limma" %in% names(metadata(dds))) {
          lim <- metadata(dds)$limma
          this_contr <- apply(comp, 2, function(x) which(apply(metadata(dds)$limma$contrasts, 2, function(y) all(x==y))))
          r <- limma::topTable(lim, coef=this_contr,
                              genelist=row.names(lim$genes),
                              number=Inf, sort.by="none")
          if (!"logFC" %in% names(r)) {
            is_coef <- grepl("^Coef[0-9]+$", names(r))
            r$logFC <- apply(abs(as.matrix(r[,is_coef])), 1, max, na.rm=TRUE)
          }
          r <- with(r, DataFrame(baseMean=2^AveExpr,
                                log2FoldChange=logFC,
                                pvalue=P.Value,
                                padj=adj.P.Val,
                                lfcSE=apply(lim$stdev.unscaled[,this_contr,drop=FALSE], 1, mean) * lim$sigma,
                                row.names=row.names(dds)))
          metadata(r)$alpha <- alpha1
        } else {
          r <- DESeq2::results(dds, filterFun=filterFun, lfcThreshold=lfcThreshold, contrast=metadata(dds)$comparison, alpha=alpha1, ...)
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
  my_mcols <- intersect(mcols, colnames(mcols(dds)))
  if (length(my_mcols)>0) {
    r[my_mcols] <- mcols(dds)[my_mcols]
  }
  r$sig <- sigs
  if ("LRTPvalue" %in% names(mcols(dds))) {
    r$class <- mcols(dds)$class
    r$class[is.na(r$padj) | is.na(r$pvalue) | r$baseMean==0] <- NA
    term <-  metadata(dds)$LRTterms
    # take the biggest fold-change vs baseline, for MA and reporting?
    if (all(term %in% names(mcols(dds))) && LRT_effect!="none") {
      effect_matrix <- cbind(I=rep(0, nrow(dds)),as.matrix(mcols(dds)[,term,drop=FALSE]))
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
      (as.matrix(mcols(dds)[,paste0("SE_", c("Intercept", term))])[cbind(1:length(imax), imax)])^2 +
        (as.matrix(mcols(dds)[,paste0("SE_", c("Intercept", term))])[cbind(1:length(imin), imin)])^2
      )
      fit <- ashr::ash(r$maxLog2FoldChange, maxlfcSE, mixcompdist = "normal", 
                       method = "shrink")
      r$shrunkLFC <- fit$result$PosteriorMean
      r$shrunkSE <- fit$result$PosteriorSD
      r$class <- paste(colnames(effect_matrix)[imax], "V", colnames(effect_matrix)[imin])
    } else {
      warning("Couldn't work out relevant group ordering in LRT")
      r$shrunkLFC <- lfcShrink(dds, res=r, type="ashr", quiet=TRUE)$log2FoldChange
      r$class <- ""
    }
  }  else {
    if ("limma" %in% names(metadata(dds))) {
      fit_sh <- ashr::ash(
        r$log2FoldChange,
        r$lfcSE, mixcompdist = "normal", 
        method = "shrink")
      r$shrunkLFC <- fit_sh$result$PosteriorMean
    } else {
      r$shrunkLFC <- lfcShrink(dds, res=r, type="ashr", quiet=TRUE)$log2FoldChange
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
  mcols(dds)$results <- r
  dds
}

.resNames <- function(names) {
 names[names == "(Intercept)"] <- "Intercept"
 make.names(names)
}

##' Tabulate genelists
##'
##' Get genelist sizes - up, down and classed
##' @title Tabulate the size of the differential lists
##' @param dds 
##' @return 
##' @author Gavin Kelly
##' @export
summarise_results <- function(dds) {
  res <- mcols(dds)$results
  as.data.frame(table(
    Group=sub("\\*$","",res$class),
    Significant=factor(ifelse(grepl("\\*$",res$class), "Significant", "not"), levels=c("Significant","not"))
  )) %>%
    tidyr::spread(Significant, Freq) %>%
    dplyr::mutate(Total=not+Significant) %>%
    dplyr::select(-not) %>%
    dplyr::arrange(desc(Significant/Total))
}    


tidy_significant_dds <- function(dds, ind = TRUE, columns=NULL, weights=NULL) {
  if (inherits(dds, "DESeqDataSet")) {
    mat <- assay(dds, "vst")[ind,,drop=FALSE]
  } else {
    mat <- assay(dds)[ind,,drop=FALSE]
  }
  pdat <- as.data.frame(colData(dds))
  if (!is.null(weights) && is.numeric(weights)) {
    if (any(is.na(mat))) {
      offset <- assay(dds, "imputed")[ind,,drop=FALSE] %*%  weights
    } else {
      offset <- mat %*%  weights
    }
    mat <- mat - as.vector(offset)
  }
  if (is.null(columns)) {
    return(list(mat=mat, pdat=pdat))
  } else {
    cols <- intersect(unique(unlist(columns)), colnames(pdat))
    ord <- do.call(order, as.list(pdat[,cols, drop=FALSE]))
    return(list(mat=mat[,ord, drop=FALSE], pdat=pdat[ord, cols, drop=FALSE]))
  }
}



retrieve_contrast <- function (object, expanded = FALSE, listValues=c(1,-1)) {
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

##' Change a factor's reference level
##'
##' Rather than change the order of the levels, this changes the way
##' the factor is parametrised, so that the levels are in the natural order
##' but the coefficients can reflect experimental design considerations
##' @title Rebase a factor's level
##' @param x A factor to be rebased 
##' @param lev The level of the factor that is to be regarded as the 'control' to which all others will be compared
##' @return A factor with a new contrast attribute
##' @author Gavin Kelly
##' @export
rebase <- function(x, lev) {
  i <- which(levels(x)==lev)
  if (length(i)==0) {
    stop(lev, " is not a level of your factor ", deparse1(substitute(x)))
  }
  contrasts(x) <- contr.treatment(nlevels(x), i)
  x
 }

default_spec_settings <- function() {
   list(         ## analysis parameters
	alpha          = 0.01,    ## p-value cutoff
	lfcThreshold   = 0,       ## abs lfc threshold
	baseMeanMin    = 0,       ## discard transcripts with average normalised counts lower than this
	top_n_variable = 500,     ## For PCA
	showCategory   = 25,      ## For enrichment analyses
	seed           = 1,       ## random seed gets set at start of script, just in case.
        gene_clust     = bluster::HclustParam(),   ## When we need to chose clusters of genes, how many?
	filterFun      = IHW::ihw,                 ## NULL for standard DESeq2 results, otherwise  functions
	clustering_distance_rows    = "euclidean", ## for all feature-distances
        stringsAsFactors = FALSE,
        normalise=NULL,
        impute=NULL,
	clustering_distance_columns = "euclidean",  ## for sample-distances
	baseline_heuristic = "min",  ## For the "white" colour in differential heatmaps
	LRT_effect = "default"  ## For the "white" colour in differential heatmaps
   )
}


add_org_annotation <- function(dds, org, keytype="ENSEMBL", extra_mcols=list(entrez="ENTREZID", symbol="SYMBOL")) {
  metadata(dds)$organism <- list(org=org)
  metadata(dds)$count_source <- params$count_source
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
           function(x) update(fml, as.formula(paste(lhs, "~", x))))
  } else if (type=="drop1") {
    drop <- drop.scope(fml)
    lapply(setNames(drop, paste("drop", drop)),
           function(x) update(fml, as.formula(paste0(lhs, " ~ . -", x))))
  } else if (type=="design") {
    list(
      'as designed' = update(fml, as.formula(paste(lhs, " ~ .")))
    )
  }
}

translate_terms <- function(txt, obj) {
  tr_list <- metadata(obj)$termNames
  ind <- txt %in% names(tr_list)
  txt[ind] <- unlist(tr_list[txt[ind]])
  txt
}


mat_x_terms <- function(mat, fml, fitFrame) {
  yvar <- make.unique(c(colnames(fitFrame), "y", sep = ""))[ncol(fitFrame) + 1]
  fml <- update(fml, paste(yvar, "~ ."))
  simpler <- find_simpler_models(fml, type="drop1")
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
    fit1 <- lm(fml, data = fitFrame)
    ind_complete <- intersect(row.names(fitFrame), names(residuals(fit1)))
    if (length(ind_complete) < nrow(fitFrame)) {
      fit1 <- lm(fml, data = fitFrame[ind_complete,])
    }
    for (ifml in names(simpler)) {
      fit0 <- lm(simpler[[ifml]], data=fitFrame[ind_complete,])
      ano <- anova(fit0, fit1)
      ss_effect <- ano$"Sum of Sq"[2]
      ss_error <- sum(resid(fit1)^2)
      eta_Sq <- ss_effect/(ss_effect + ss_error)
      i <- covar_x_mat$column==imat & covar_x_mat$Covariate==ifml
      covar_x_mat$Assoc[i] <- eta_Sq
      covar_x_mat$pvalue[i] <- anova(fit0, fit1)$'Pr(>F)'[2]
      }
    }
  covar_x_mat$wrap <- (covar_x_mat$column - 1)%/%20
  covar_x_mat$wrap <- paste0(covar_x_mat$wrap * 20 +  1,
                            "-",
                            min((covar_x_mat$wrap + 1) * 20, nmat))
  covar_x_mat$column <- sprintf("%02d", covar_x_mat$column)
  covar_x_mat
}

extract_hits <- function(covar_x_pc, fml) {
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
  hits <- paste0("PC", sort(unique(as.integer(c(pc_hits$strongest, pc_hits$first)))))
  wide_dat <- cbind(colDat[model_vars$all], pc[,hits,drop=FALSE])
  long_dat <- pivot_longer(wide_dat, cols=all_of(hits), names_to="PC")
  long_dat
}



negate_emmc <- function(emc) {
  ememmc <- get(emc, "package:emmeans")
  function(...) {
    base_contr <- ememmc(...)
    #    base_contr[] <- abs(pmin(as.matrix(base_contr), 0))
    base_contr[] <- apply(base_contr, 2, \(x) {ifelse(x==max(x), 1-x, 0-x)})
    base_contr
  }
}

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
