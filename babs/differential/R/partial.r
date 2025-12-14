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
  QR <- qr(X)
  X_center <- drop(colMeans(X))
  assign <- attr(X, "assign")
  terms <- attr(terms(fml), "term.labels")
  nterms <- length(terms)
  termcols <- lapply(seq_len(nterms), function(t) which(assign == t))
  cdata_full$tmat <- t(obj)
  mf_full <- model.frame(fml, data = cdata_full)
  X_full <- as.matrix(model.matrix(fml, mf_full))
  storage.mode(X_full) <- "double"
  Xc_full <- sweep(X_full, 2, X_center, FUN = "-")  # center using influence means
  # preallocate outputs
  out <- array(0, c(nobs, nresp, nterms),
               dimnames = list(colnames(obj), rownames(obj), terms))
  resid <- matrix(0, nobs, nresp, dimnames = list(colnames(obj), rownames(obj)))
  const <- numeric(nresp)
  for (i in seq_len(nresp)) {
    beta <- qr.coef(QR, obj_influence[i, ])
    term_mat <- matrix(0, nterms, nobs)
    for (t in seq_len(nterms)) {
      cols <- termcols[[t]]
      term_mat[t, ] <- Xc_full[, cols, drop = FALSE] %*% beta[cols]
    }
    out[, i, ] <- t(term_mat)
    const[i] <- beta[1] + sum(X_center[-1] * beta[-1], na.rm = TRUE)
    resid[, i] <- obj[i, ] - (colSums(term_mat) + const[i])
  }
  ret <- list(
    terms = out,
    const = const,
    resid = resid
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
  partialise.matrix(
    obj=mat,
    cdata=as.data.frame(colData(obj)),
    fml=design(obj)
  )
}

partialise.SummarizedExperiment <- function(obj, assay=1, fml=design(obj), influence=TRUE) {
  mat <- assay(obj, assay)
  partialise.matrix(
    obj=mat,
    cdata=as.data.frame(colData(obj)),
    fml=fml
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
#' @param extra A character vector of any extra terms that the formula didn't contain
#' @return A character vector of terms that will have been 'dropped'
#' @author Gavin Kelly
#' @family partial
#' @export
dropped_terms <- function(obj, reduced, extra=NULL) {
  setdiff(dimnames(obj$terms)[[3]],
          c(labels(terms(reduced)), extra)
          )
}
#' Reconstruct a matrix from (some of) the parts of a partialised object
#'
#' .. content for \details{} ..
#' @param obj The result of a previous 'partialise'
#' @param reduced A formula, the right-hand-side of which contains the terms that will be used to predict the response
#' @param extra A character vector of any extra terms that the formula didn't contain
#' @param resids Boolean indicating whether to include the residuals (default) or not
#' @return A matrix of the same dimensions as the original input to 'partialise'
#' @author Gavin Kelly
#' @family partial
#' @export
assemble_partialised <- function(obj, reduced, extra=NULL, resids=TRUE) {
  terms <-intersect(
    dimnames(obj$terms)[[3]],
    c(labels(terms(reduced)), extra)
  )
  t(
    rowSums(obj$terms[, , terms, drop=FALSE], na.rm=TRUE, dims=2) +
      (if(resids) obj$resid else 0)) + obj$const
}


