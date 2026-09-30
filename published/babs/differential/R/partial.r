#' Calculate the partial components predicted by a model
#'
#' Given a matrix-like object, calculate the amount that each term in
#' a design formula contributes to the outcome. This, along with each
#' sample's residual error, allows us to reconstruct the original
#' matrix, in a customised way that includes or removes the
#' contribution of specific variables.
#' @title partialise: calculate partial components
#' @name partialise
#' @family partial
#' @return A 'partialised' object
#' @author Gavin Kelly
#' @seealso [assemble_partialised()] for how to construct a matrix from the parts
#' @export
partialise <- function(obj,...) {
  UseMethod("partialise")
}

#' @rdname partialise
#' @param obj A matrix (rows=features, columns=samples)
#' @param cdata A data.frame of metadata (rows=samples, columns=variables)
#' @param fml A one-sided formula to predict each row of obj given the metadata
#' @family partial
#' @export
partialise.matrix <- function(obj, cdata, fml, influence = TRUE) {
  # obj: response matrix, rows = responses, cols = observations
  # cdata: covariate data frame
  # fml: formula with single response (will be replaced by tmat)
  # influence: optional vector of column indices of obj to use for fitting
  nresp <- nrow(obj)
  nobs <- ncol(obj)
  cdata_full <- cdata
  cdata <- cdata[influence, , drop = FALSE]
  obj_influence <- obj[, influence, drop = FALSE]
  cdata$tmat <- t(obj_influence)
  fml <- update(fml, tmat ~ .)
  mf <- model.frame(fml, data = cdata)
  X <- as.matrix(model.matrix(fml, mf))
  storage.mode(X) <- "double"
  QR     <- qr(X)

  assign   <- attr(X, "assign")
  terms    <- attr(terms(fml), "term.labels")
  nterms   <- length(terms)
  termcols <- lapply(seq_len(nterms), function(t) which(assign == t))
  cdata_full$tmat <- t(obj)
  mf_full <- model.frame(fml, data = cdata_full)
  X_full <- as.matrix(model.matrix(fml, mf_full))
  storage.mode(X_full) <- "double"
  X_full  <- X_full[, colnames(X), drop = FALSE]

  beta <- qr.coef(QR, t(obj_influence))   # p × nresp
  keep <- !is.na(beta)
  beta[!keep] <- 0

  fitted_full <- X_full %*% beta           # nobs × nresp
  const       <- beta[1, ]

  out <- array(0, c(nobs, nresp, nterms),
               dimnames = list(colnames(obj), rownames(obj), terms))

  for (t in seq_len(nterms)) {
    cols <- termcols[[t]]
    if (length(cols) > 0) {
      beta_sub <- beta[cols, , drop = FALSE]
      beta_sub[!keep[cols, , drop = FALSE]] <- 0
      out[, , t] <- X_full[, cols, drop = FALSE] %*% beta_sub
    }
  }

  ret <- list(
    terms = out,
    const = const,
    resid = t(obj) - fitted_full
  )
  class(ret) <- "partialised"
  ret
}

#' @rdname partialise
#' @param obj A DESeqDataSet object, where the design formula and colData will be used
#' @family partial
#' @export
partialise.DESeqDataSet <- function(obj, assay="vst", influence=TRUE) {
  if (assay %in% assayNames(obj)) {
    mat <- assay(obj, assay)
  } else {
    mat <-assay(vst(obj, nsub=min(1000, nrow(obj))))
  }
  influence <- influence & (metadata(obj)$extra_assays$influential_samples %||% TRUE)
  partialise.matrix(
    obj=mat,
    cdata=as.data.frame(colData(obj)),
    fml=design(obj),
    influence=influence
  )
}

partialise.SummarizedExperiment <- function(obj, assay=1, fml=design(obj), influence=TRUE) {
  mat <- assay(obj, assay)
  influence <- influence & (metadata(obj)$extra_assays$influential_samples %||% TRUE)
  partialise.matrix(
    obj=mat,
    cdata=as.data.frame(colData(obj)),
    fml=fml,
    influence=influence
  )
}

#' Compare a partialised object with the terms in a reduced model
#'
#' Report the terms that were in the original model used to
#' partialise the data, but are omitted from the reduced model (and
#' so will their effect will be removed from any reconstruction)
#' @title dropped_terms: Compare terms in full and reduced models
#' @param obj The result of a previous 'partialise'
#' @param reduced A formula, the right-hand-side of which contains the terms that will be used to predict the response
#' @return A character vector of terms that will have been 'dropped'
#' @author Gavin Kelly
#' @family partial
#' @export
dropped_terms <- function(obj, reduced) {
  setdiff(dimnames(obj$terms)[[3]],
          labels(terms(reduced))
          )
}
#' Reconstruct a matrix from (some of) the parts of a partialised object
#'
#' .. content for \details{} ..
#' @param obj The result of a previous 'partialise'
#' @param reduced A formula, the right-hand-side of which contains the terms that will be used to predict the response
#' @param resids Boolean indicating whether to include the residuals (default) or not
#' @return A matrix of the same dimensions as the original input to 'partialise'
#' @author Gavin Kelly
#' @family partial
#' @export
assemble_partialised <- function(obj, reduced, resids = TRUE) {
  terms <- intersect(
    dimnames(obj$terms)[[3]],
    labels(terms(reduced))
  )

#  mat <- apply(obj$terms[, , terms, drop = FALSE], c(1,2), sum)
  mat <- rowSums(obj$terms[, , terms, drop = FALSE], dims = 2)
  if (resids) {
    mat <- mat + obj$resid
  }

  mat <- sweep(mat, 2, obj$const, "+")

  t(mat)
}

cached_partial <- function() {
  cache <- new.env(parent = emptyenv())
  function(obj, plot_fml, resids=TRUE, influence=TRUE, assay=NULL, ...) {

    if (is.null(assay)) {
      if ("y" %in% names(plot_fml[[2]])) {
        assay <- as.character(plot_fml[[2]]$y)
      } else {
        assay <- ifelse(inherits(obj, "DESeqDataSet"), "vst", assayNames(obj)[1])
      }
    }

    # calculate the decomposition and cache if not already
    if (!exists(assay, envir = cache, inherits = FALSE)) {
      cache[[assay]] <- partialise(obj, assay=assay, influence=influence)
    }

    if (formula_equal(design(obj), plot_fml)) {
      removed <- if (resids) "" else " having removed noise"
    } else {
      txt <- dropped_terms(cache[[assay]], update(plot_fml, NULL ~ .))
      tr_list <- modifyList(setNames(as.list(txt), txt),  metadata(obj)$termNames)
      removed <- paste0(" having removed effect of ",
                       if (resids) "" else "noise and ",
                       paste(unlist(tr_list), collapse=", ")
                       )
    }
    structure(
      assemble_partialised(cache[[assay]], reduced=update(plot_fml, NULL ~ .),  resids=resids),
      which_assay=assay,
      removed=removed,
      ind=!duplicated(model.matrix(design(obj), colDF(obj)))
    )
  }
}
