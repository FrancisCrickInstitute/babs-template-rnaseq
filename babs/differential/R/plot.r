##' Heatmap colour-scheme generator
##'
##' For each column in a dataframe, generate a sensible colour palette
##' for each column
##' @param df data.frame containing the covariates to be colour-encoded
##' @param palette The baseline palette
##' @return
##' @author Gavin Kelly
df2colorspace <- function(df, palette) {
  pal <- RColorBrewer::brewer.pal(RColorBrewer::brewer.pal.info[palette, "maxcolors"], palette)
  if (ncol(df)==0) return(list(Heatmap=list(), ggplot=list()))
  df <- dplyr::mutate_if(as.data.frame(df), is.character, as.factor)
  seq_cols <-c("Blues", "Greens", "Oranges", "Purples", "Reds")
  df <- df[,order(sapply(df, is.numeric)),drop=FALSE] # move factors to the front
  # for factors, zero-based starting index for colours
  start_levels <- cumsum(c(0,sapply(df, nlevels)))[1:length(df)] 
  is_num <- sapply(df, is.numeric)
  # for numerics, which seq palette shall we use for this factor
  start_levels[is_num] <- (cumsum(is_num[is_num])-1) %% length(seq_cols) + 1
  res <- list()
  res$Heatmap <- purrr::map2(df, start_levels,
              function(column, start_level) {
                if (is.factor(column)) {
                  setNames(pal[(seq(start_level, length=nlevels(column)) %% length(pal)) + 1],
                                     levels(column))
                } else {
                  my_cols <- RColorBrewer::brewer.pal(3, seq_cols[start_level])[-2]
                  circlize::colorRamp2(range(column), my_cols)
                }
              }
              )
  res$ggplot <- purrr::map2(df, start_levels,
              function(column, start_level) {
                if (is.factor(column)) {
                  setNames(pal[(seq(start_level, length=nlevels(column)) %% length(pal)) + 1],
                                     levels(column))
                } else {
                  RColorBrewer::brewer.pal(3, seq_cols[start_level])[-2]
                }
              }
              )
  res
}
  

sym_colour <- function(dat, lo="blue",zero="white", hi="red") {
  mx <- quantile(abs(dat), 0.9)
  circlize::colorRamp2(c(-mx, 0, mx), colors=c(lo, zero, hi))
}


get_terms <- function(dds) {
  ret <- list(fixed=NULL, groups=NULL)
  if ("full_model" %in% names(metadata(dds))) {
    ret <- classify_terms(metadata(dds)$full_model)
    return(ret)
  }
  if ("model" %in% names(metadata(dds))) {
    ret$fixed <- all.vars(metadata(dds)$model$design)
    return(ret)
  } else {
    term_list <- lapply(metadata(dds)$models, function(mdl) {all.vars(mdl$design)})
    ret$fixed <- unique(unlist(term_list))
  }
  return(ret)
}

part.resid <- function(fit) {
  pterms <- predict(fit, type="terms")
  apply(pterms,2,function(x)x+resid(fit))
}
  
  
##' Generate captioned plot
##'
##' quarto-compatible plot wrapper
##'
##' Either produce a child chunk (labelled so that it can be cross-references),
##' or open the default graphics device, depending on whether the document is being
##' rendered or run interactively.
##' @param pl A plot object, from ggplot, plot or ComplexHeatmap
##' @param label The candidate chunk label, which will get sanitised
##' @param caption The caption text
##' @param cap_fn The function that will be called on the caption text
##' @return 
##' @author Gavin Kelly
do_plot <- function(pl, label, caption, cap_fn=fig_caption, height_mult=NA, min_height=0, max_height=Inf) {
  if ("Heatmap" %in% class(pl)) {
    fn <- function() {
      draw(pl, heatmap_legend_side = "top")
      cap_fn(caption)
    }
  } else if ("gtable" %in% class(pl)){
    fn <- function() {
      grid.draw(pl)
      cap_fn(caption)
    }
  } else {
    fn <- function() {
      print(pl)
      cap_fn(caption)
    }
  }
  if (isTRUE(getOption('knitr.in.progress'))) {
    height_opt <- ""
    if (!is.na(height_mult)) {
      height_opt <- paste0("#| fig.height: ", max(min(knitr::opts_chunk$get("fig.height") * height_mult,max_height), min_height))
    }
    fig_child <- knitr::knit_expand(
      text=r"(```{r}
#| label: fig-{{lbl}}
{{height}}
fn()
```)",
lbl=gsub("[^[:alnum:]]+", "-",label),
height=height_opt
)
    cat(knitr::knit_child(
      text=fig_child,
      quiet=TRUE,
      envir=environment())
      )
  } else {
    fn()
  }
}
      
residual_heatmap_transform <- function(mat, cdata, fml) {
  assign("tmat", t(mat), envir=environment(fml))
  fml <- stats::update(fml, tmat ~ .)
  fit <- lm(fml, data=cdata)
  fit1 <- fit
  class(fit1) <- "lm"
  ind <- c("coefficients","residuals","effects","fitted.values")
  for (i in 1:nrow(mat)) {
    if (nrow(mat)==1) {
      fit1 <- fit
    } else {
      fit1[ind] <- lapply(fit[ind], function(x) x[,i])
    }
    pred <- predict(fit1, type="terms")
    if (i==1) {
      out <- array(0, c(rev(dim(mat)), ncol(pred)), dimnames=c(rev(dimnames(mat)), list(colnames(pred))))
      const <- numeric(dim(out)[2])
    }
    out[,i,] <- pred
    const[i] <- attr(pred, "constant")
  }
  list(terms=out, const=const, resid=fit$residuals)
}


separate_legend <- function(dds) {
  in_this_dataset <- unique(unlist(lapply(metadata(dds)$models, function(x) all.vars(x$design))))
  lapply(
    in_this_dataset,
    function(md_name) {
      md <- metadata(colData(dds))$palette$Heatmap[[md_name]]
      if (is.function(md)) {
        Legend(col_fun=md, title=md_name)@grob
      } else{
        Legend(legend_gp=gpar(fill=md),labels=names(md),
               title=md_name, nrow=ifelse(length(md)>8, ceiling(sqrt(length(md))), length(md)))@grob
      }
    }
  )
}
