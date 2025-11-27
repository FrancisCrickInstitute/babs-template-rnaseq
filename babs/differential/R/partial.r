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
partialise.matrix <- function(obj, cdata, fml) {
  assign("tmat", t(obj), envir=environment(fml))
  fml <- stats::update(fml, tmat ~ .)
  fit <- lm(fml, data=cdata)
  fit1 <- fit
  class(fit1) <- "lm"
  newdata <- cdata
  if ("xlevels" %in% names(fit)) {
    for (i in names(fit$xlevels)) {
      levels(newdata[[i]])[!(levels(newdata[[i]]) %in% fit$xlevels[[i]])] <- NA
    }
  }
  ind <- c("coefficients","residuals","effects","fitted.values")
  for (i in 1:nrow(obj)) {
    if (nrow(obj)==1) {
      fit1 <- fit
    } else {
      fit1[ind] <- lapply(fit[ind], function(x) x[,i])
    }
    pred <- predict(fit1, type="terms", newdata=newdata)
    if (i==1) {
      out <- array(0, c(rev(dim(obj)), ncol(pred)), dimnames=c(rev(dimnames(obj)), list(colnames(pred))))
      const <- numeric(dim(out)[2])
    }
    out[,i,] <- pred
    const[i] <- attr(pred, "constant")
  }
  ret <- list(terms=out, const=const, resid=fit$residuals, data=list(mat=obj, cdata=cdata, fml=fml))
  pred <- apply(out, 1:2, sum, na.rm=TRUE)
  ret$resid <- t(obj - const - t(pred))
  class(ret) <- "partialised"
  ret
}

#' @rdname partialise
#' @param obj A DESeqDataSet object, where the design formula and colData will be used
#' @family partial
#' @export
partialise.DESeqDataSet <- function(obj, assay="vst") {
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

partialise.SummarizedExperiment <- function(obj, assay=1) {
  mat <- assay(obj, assay)
  partialise.matrix(
    obj=mat,
    cdata=as.data.frame(colData(obj)),
    fml=design(obj)
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
      (if(resids) obj$resid else 0))
}
