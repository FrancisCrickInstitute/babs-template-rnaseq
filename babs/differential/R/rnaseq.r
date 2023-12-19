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
  if (file.exists(file)) {
    e <- as.environment(as.data.frame(colData(context)))
    list_ok <- function(...) rlang::dots_list(..., .ignore_empty="all")
    parent.env(e) <- environment()
    assign("list", list_ok, envir=e)
    assign("sample_set", list_ok, envir=e)
    assign("model", list_ok, envir=e)
    assign("specification", list_ok, envir=e)
    normalise_within <- function(...) {
      norm_within(as.data.frame(colData(context)), ...)}    
    assign("settings",
           function(...) {
             as.list( substitute(alist(...)))[-1]
           },
           envir=e
           )
    assign("mutate",
           function(...) {
             substitute(alist(...))
           },
           envir=e
           )
    specs <- source(file, local=e)$value
    assign("sample_set", expression, envir=e) # avoid evaluating any examples sample_sets.
    pkg_defaults <-default_spec_settings()
    new_settings <- setdiff(names(pkg_defaults), names(specs$settings))
    if (length(new_settings)>0) {
      string_rep <- lapply(pkg_defaults[new_settings], deparse)
      warning("New settings (", paste(new_settings), ") can be set in ", file, ", so please update it. The default values that will be used are:\n", paste(names(string_rep), string_rep, sep=": ", collapse="\n"))
      specs$settings[new_settings] <- pkg_defaults[new_settings]
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
  modelled_terms <- lapply(spec$sample_sets, function(x) lapply(x$models, function(y) if (is_formula(y$design)) all.vars(update(y$design, NULL ~ .))))
  modelled_terms <-  unique(unlist(modelled_terms))
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
  for (i_set in seq_along(spec$sample_sets)) {
    set <- spec$sample_sets[[i_set]]
    mdlList <- spec$models
    obj <- dds
    if ("baseline" %in% names(set)) {
      if (!is.list(set$baseline$ind)) {
        is_numerator <- !is.na(set$baseline$ind)
        norm <- counts(obj[,set$baseline$ind[is_numerator]]) + set$baseline$adj
      } else {
        is_numerator <- sapply(set$baseline$ind, function(x) !all(is.na(x)))!=0
        norm <- sapply(set$baseline$ind[is_numerator], function(x) rowSums(counts(obj[,x]))) + set$baseline$adj
      }
      obj <- obj[,is_numerator]
      normalizationFactors(obj) <- norm
    }
    if (is.list(set)) {
      ind <- set$subset
      mdlList <- c(mdlList, set$models)
    } else {
      ind <- set
    }
    obj <- obj[,ind]
    metadata(obj)$full_model <- spec$full_model
    colData(obj) <- droplevels(colData(obj))
    mdlList <- lapply(mdlList, function(x) modifyList(list(plot_qc=FALSE), x))
    if (!any(sapply(mdlList, "[[", "plot_qc"))) {
      mdlList[[1]]$plot_qc <- TRUE
    }
    metadata(obj)$models <- mdlList
    if ("sample_swap" %in% names(set)) {
      for (x1 in names(set$sample_swap)) {
        i1 <- match(x1, colData(obj)$ID)
        i2 <- match(set$sample_swap[[x1]], colData(obj)$ID)
        tmp <- colData(obj)[i1, -1, drop=FALSE]
        colData(obj)[i1, -1] <- colData(obj)[i2, -1, drop=FALSE]
        colData(obj)[i2, -1] <- tmp
      }
    }
    if ("transform" %in% names(set)) {
      .mu <- purrr::partial(mutate, .data=as.data.frame(colData(obj)))
      tr <- set$transform
      tr[[1]] <- .mu
      cnames <- colnames(obj)
      colData(obj) <- S4Vectors::DataFrame(eval(tr))
      metadata(colData(obj)) <- metadata(colData(dds))
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
                                 if (class(colData(obj)[[x]]) != class(colData(dds)[[x]])) return(TRUE)
                                 if (is.factor(colData(obj)[[x]])) return(!all(levels(colData(obj)[[x]]) %in%  levels(colData(dds)[[x]])))
                                 if (is.character(colData(obj)[[x]])) return(!all(unique(colData(obj)[[x]]) %in%  levels(unique(dds)[[x]])))
                                 return(!all(range(colData(obj)[[x]])==range(colData(obj)[[x]])))
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
    if ("collapse" %in% names(set)) {
      mf <- model.frame(set$collapse, data.frame(colData(obj)))
      ind <- match(do.call(paste, c(mf, sep="\r")),
                   do.call(paste, c(unique(mf), sep="\r")))
      obj <- collapseReplicates(obj, groupby=factor(ind), renameCols=FALSE)
    }
    ddsList[[names(spec$sample_sets)[i_set]]] <- obj
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
add_dim_reduct  <-  function(dds, n=Inf, family="norm", batch=~1) {
  var_stab <- assay(vst(dds, nsub=min(1000, nrow(dds))))
  if (batch != ~1) {
    var_stab <- residuals(limma::lmFit(var_stab, model.matrix(batch, as.data.frame(colData(dds)))), var_stab)
  }
  colnames(var_stab) <- colnames(dds)
  assay(dds, "vst") <- var_stab
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
      mdl$baseline_heuristic <- mdl$baseline_heuristic %||% param$get("baseline_heuristic")
      mdl$LRT_effect <- mdl$LRT_effect %||% param$get("LRT_effect")
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

old_fit_model <- function(mdl, dds, ...) {
  this_dds <- dds
  DESeq2::design(this_dds) <- mdl$design
  metadata(this_dds)$model <- mdl
  this_dds <- check_model(this_dds) 
  out <- list()
  is_lrt <- sapply(mdl$comparisons, is_formula)
  if (any(!is_lrt)) {
    comps <- mdl$comparisons[!is_lrt]
    is_post_hoc <- sapply(comps, class)=="post_hoc"
    if (any(is_post_hoc)) {
      do_lrt <- sapply(comps[is_post_hoc], function(ph) ph$LRT %||% FALSE)
      comps[is_post_hoc] <- lapply(
        comps[is_post_hoc],
        function(ph) {emcontrasts(dds=this_dds, spec=ph$spec, extra=ph[-1])}
      )
      comps[!is_post_hoc] <- lapply(comps[!is_post_hoc], list) # protect existing lists from unlist
      comps <- unlist(comps, recursive=FALSE)
    }
    if (any(metadata(this_dds)$model$dropped)) {
      DESeq2::design(this_dds) <- metadata(this_dds)$model$mat
    }
    this_dds <- DESeq2::DESeq(this_dds, test="Wald", ...)
    metadata(this_dds)$models <- NULL
    metadata(this_dds)$comparisons <- NULL
    out <- lapply(comps, function(cntr) {
      metadata(this_dds)$comparison <- cntr
      this_dds})
  }
  if (any(is_lrt)) {
    lrt <- lapply(mdl$comparisons[is_lrt],
                 function(reduced) {fitLRT(this_dds, mdl=mdl, reduced=reduced, ...)}
                 )
    out <- c(out, lrt)
  }
  out <- imap(out, function(obj, cname) {metadata(obj)$dmc$comparison <- cname; obj})
  out
}


fit_model <- function(mdl, dds, ...) {
  message("Processing model ", mdl$name)
  model_dds <- dds
  DESeq2::design(model_dds) <- mdl$design
  metadata(model_dds)$model <- mdl
  model_dds <- check_model(model_dds)
  if (any(metadata(model_dds)$model$dropped)) {
    DESeq2::design(model_dds) <- metadata(model_dds)$model$mat
  }
  done_wald <- FALSE# mightn't need to run Wald if everything is an LRT
  ## Generate a nested list - single comparisons will be singletons, expanded mult_comps may not be.
  comp_ind <- 1
  out <- lapply(mdl$comparisons, function(comp) {
    message("Processing comparison ", comp_ind)
    comp_ind <<- comp_ind+1
    comparison_dds <- model_dds
    if (is_formula(comp)) { # Do the usual DESeq2 LRT
      return(list(fitLRT(comparison_dds, mdl=mdl, reduced=comp, ...)))
    }
    if (class(comp)=="post_hoc") { #Multiple-comparisons
      contrs <- emcontrasts(dds=comparison_dds, spec=comp$spec, extra=comp[-1])
      if (comp$LRT %||% FALSE) { # Do LRT-equivalents of the multiple ward tests
        mdl_mat <- metadata(comparison_dds)$model$mat %||% model.matrix(mdl$design, as.data.frame(colData(comparison_dds)))
        return(lapply(
          contrs,
          function(contr) {fitContrastLRT(comparison_dds, mdl=mdl_mat, contr=contr, ...)}
        )
        )
      } else {
        if (!done_fit) {
          if ((mdl$approach %||% "DESeq2")=="DESeq2") {
            model_dds <- DESeq2::DESeq(model_dds, test="Wald", ...)
          } else {
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
            fit <- limma::contrasts.fit(fit, do.call(cbind, contrs))
            fit <- limma::eBayes(fit)
            metadata(model_dds)$voom <- fit
            contrs[] <- seq_along(contrs)
          }
          comparison_dds <- model_dds
          done_fit <- TRUE
        }
        return(lapply(
          contrs,
          function(contr) {
            metadata(comparison_dds)$models <- NULL
            metadata(comparison_dds)$comparisons <- NULL
            metadata(comparison_dds)$comparison <- contr
            comparison_dds}
        ))
      }
    }
    # Usual DESeq2 Wald
    if (!done_fit) {
          model_dds <- DESeq2::DESeq(model_dds, test="Wald", ...)
          comparison_dds <- model_dds
      done_fit <- TRUE
    }
    metadata(comparison_dds)$models <- NULL
    metadata(comparison_dds)$comparisons <- NULL
    metadata(comparison_dds)$comparison <- comp
    return(list(comparison_dds))
  })
  ## Flatten the list, but preserve the original comparison name in the dmc metadata.
  out <- unlist(out, recursive=FALSE)
  out <- imap(out, function(obj, cname) {
    metadata(obj)$dmc$comparison <- cname; obj
  })
  return(out)
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
    df$.x <- counts(dds, norm=TRUE)[1,]
    fml <- as.formula(paste0(".x ~ ", as.character(DESeq2::design(dds)[2])))
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
mult_comp <- function(spec, ...) {
  obj <- list(spec=spec,...)
  class(obj) <- "post_hoc"
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
emcontrasts <- function(dds, spec, extra=NULL) {
  if ("keep" %in% names(extra)) {
    keep <- extra$keep
    extra$keep <- NULL
  } else {
    keep <- NA
  }
  if ("LRT" %in% names(extra)) {
    LRT <- extra$keep
    extra$LRT <- NULL
  } else {
    LRT <- FALSE
  }
  
  mdl <- metadata(dds)$model
  emfit <- do.call(emmeans::emmeans, c(list(object=mdl$lm, specs= spec),extra))
  contr_frame <- as.data.frame(summary(emfit$contrasts))
  ind_est <- !is.na(contr_frame$estimate)

  contr_frame <- contr_frame[ind_est,1:(which(names(contr_frame)=="estimate")-1), drop=FALSE]
  contr_frame[] <- lapply(contr_frame, function(x) sub("|", "†", x, fixed=TRUE))
  contr_mat <- emfit$contrast@linfct[ind_est, !mdl$dropped, drop=FALSE]
  colnames(contr_mat) <- .resNames(colnames(contr_mat))
  contr <- lapply(seq_len(nrow(contr_frame)), function(i) contr_mat[i,,drop=TRUE])
  contr <- lapply(contr, function(vect) {attr(vect, "spec") <- spec; vect})
  names(contr) <- do.call(paste, c(contr_frame,sep= "|"))
  if (!is.na(keep[1])) {
    contr  <- contr[keep]
  }
  contr
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
    reduced <- reduced[,colnames(reduced) %in% colnames(full), drop=FALSE]
    metadata(dds)$reduced_mat <- reduced
  } else {
    full <- mdl$design
  }
  DESeq2::design(dds) <- full
  dds <- DESeq2::DESeq(dds, test="LRT", full=full, reduced=reduced, ...)
  metadata(dds)$LRTterms=setdiff(
    colnames(attr(dds, "modelMatrix")),
    colnames(attr(dds, "reducedModelMatrix"))
  )
  metadata(dds)$models <- NULL
  metadata(dds)$comparisons <- NULL
  dds
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
get_result <- function(dds, mcols=c("symbol", "entrez"), filterFun=IHW::ihw, lfcThreshold=0, alpha=0.1, ...) {
  if (is.null(filterFun)) filterFun <- rlang::missing_arg()
  comp <- metadata(dds)$comparison
  if (length(alpha)>1) {
    alpha <- sort(alpha)
    alpha1 <- alpha[1]
  } else {
    alpha1 <- alpha
  }
  if (!is_formula(comp)) {
    if (is.character(comp) && length(comp)==1) { #  it's a name
      r <- DESeq2::results(dds, filterFun=filterFun, lfcThreshold=lfcThreshold, name=metadata(dds)$comparison, alpha=alpha1, ...)
    } else { # it's a contrast
      if (is.list(comp) && "listValues" %in% names(comp)) {
        r <- DESeq2::results(dds, filterFun=filterFun, lfcThreshold=lfcThreshold, contrast=metadata(dds)$comparison[names(comp) != "listValues"], listValues=comp$listValues, alpha=alpha1, ...)
      } else {
        if ("voom" %in% names(metadata(dds))) {
          vm <- metadata(dds)$voom
          r <- limma::topTable(vm, coef=comp,
                        genelist=row.names(vm$genes),
                        number=Inf, sort.by="none")
          r <- with(r, DataFrame(baseMean=2^AveExpr,
                                 log2FoldChange=logFC,
                                 pvalue=P.Value,
                                 padj=adj.P.Val,
                                 lfcSE=vm$stdev.unscaled[,comp] * vm$sigma,
                                 row.names=row.names(dds)))
          metadata(r)$alpha <- alpha1
        } else {
          r <- DESeq2::results(dds, filterFun=filterFun, lfcThreshold=lfcThreshold, contrast=metadata(dds)$comparison, alpha=alpha1, ...)
        }
      }
    }
  } else { # it's LRT
    r <- results(dds, filterFun=filterFun, alpha=alpha1, ...)
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
    if (all(term %in% names(mcols(dds))) && metadata(dds)$model$LRT_effect!="none") {
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
    if ("voom" %in% names(metadata(dds))) {
      fit_sh <- ashr::ash(
        r$log2FoldChange,
        r$lfcSE, mixcompdist = "normal", 
        method = "shrink")
      r$shrunkLFC <- fit_sh$result$PosteriorMean
    } else {
      r$shrunkLFC <- lfcShrink(dds, res=r, type="ashr", quiet=TRUE)$log2FoldChange
    }
    r$class <- ifelse(r$log2FoldChange >0, "Up", "Down")
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


tidy_significant_dds <- function(dds, res, tidy_fn=NULL, weights=NULL) {
  ind <- grepl("\\*$", res$class)
  mat <- assay(dds, "vst")[ind,,drop=FALSE]
  if (!is.null(weights)) {
    if (is.numeric(weights)) {
      offset <- mat %*%  weights
      mat <- mat - as.vector(offset)
    }
  }
  tidy_dat <- tidy_per_gene(mat, as.data.frame(colData(dds)), tidy_fn)
  return(tidy_dat)
}

tidy_per_gene <- function(mat, pdat,  tidy_fn) {
  if (is.null(tidy_fn)) {
    return(list(mat=mat, pdat=pdat))
  }
  if (inherits(tidy_fn, "fseq")) {
    pdat_long <- dplyr::group_by(cbind(pdat,
                               .value=as.vector(t(mat)),
                               .gene=rep(rownames(mat),each=ncol(mat)),
                               .sample=colnames(mat)),
                         .gene, .add=TRUE)
    summ_long <- dplyr::ungroup(tidy_fn(pdat_long), .gene)
    tidy_pdat <- summ_long[summ_long$.gene==summ_long$.gene[1],]
    tidy_mat <- mat[, tidy_pdat$.sample,drop=FALSE]
    tidy_mat[cbind(summ_long$.gene, summ_long$.sample)] <- summ_long$.value
    tidy_pdat  <- as.data.frame(dplyr::select(tidy_pdat, -.gene, -.value, -.sample))
  } else {
    facts <- c(tidy_fn$by, tidy_fn$rhs, setdiff(tidy_fn$all, unlist(tidy_fn[c("by", "rhs")])))
    ord <- do.call(order, as.list(pdat[,facts, drop=FALSE]))
    return(list(mat=mat[,ord, drop=FALSE], pdat=pdat[ord,facts,drop=FALSE]))
  }
  list(mat=tidy_mat, pdat=tidy_pdat)
}

full_model <- function(mdlList) {
  rhs <- lapply(mdlList, function(mdl) deparse(mdl$design[[2]]))
  fml <- stats::update(as.formula(paste("~", paste(rhs, collapse=" + "))), ~ . )
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
    stop(lev, " is not a level of your factor ", deparse(substitute(x)))
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
	filterFun      = IHW::ihw,                 ## NULL for standard DESeq2 results, otherwise  functions
	clustering_distance_rows    = "euclidean", ## for all feature-distances
	clustering_distance_columns = "euclidean",  ## for sample-distances
	baseline_heuristic = "min",  ## For the "white" colour in differential heatmaps
	LRT_effect = "default"  ## For the "white" colour in differential heatmaps
   )
}
