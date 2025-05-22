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
                  circlize::colorRamp2(range(column, na.rm=TRUE), my_cols)
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
  
  

rename_with_tag <- function(params) {
  function(path, options) {
    path2 <- file.path(dirname(path), gsub("([0-9]+)-fig-(.*)-1\\.(.*)", paste0("fig-\\1-\\2", params$TAG, ".\\3"), basename(path)))
    file.rename(path, path2)
    path2
  }
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
plot_tracker <- function(p) {
  script <- tools::file_path_sans_ext(basename(p$script))
  get_tally <- counter() # keeps track of individual labels and running tally of all plots
  function(pl, label, caption, height_mult=NA, min_height=0, max_height=Inf, preview=FALSE) {
    if ("Heatmap" %in% class(pl)) {
      fn <- function() {
        draw(pl, heatmap_legend_side = "top")
      }
    } else if ("gtable" %in% class(pl)){
      fn <- function() {
        grid.draw(pl)
      }
    } else {
      fn <- function() {
        print(pl)
      }
    }
    fig_n <- get_tally()
    if (isTRUE(getOption('knitr.in.progress'))) {
      height_opt <- ""
      label <- paste0(gsub("[^[:alnum:]]+", "-", label), "-", get_tally(label))
      if (!is.na(height_mult)) {
        height_opt <- paste0("#| fig.height: ", max(min(knitr::opts_chunk$get("fig.height") * height_mult,max_height), min_height))
      }
      fig_child <- knitr::knit_expand(
        text=r"(```{r}
#| label: fig-{{lbl}}
#| fig.path: "{{script}}/{{fprefix}}-"
{{height}}
fn()
```)",
lbl=label,
height=height_opt,
script=script,
fprefix=sprintf("%0.3i",fig_n)
)
      link <- paste0("fig-", sprintf("%0.3i",fig_n), "-", label, p$TAG, ".pdf")
      out <- knitr::knit_child(
        text=fig_child,
        options=list(fig.cap=paste0("[", caption, "](", script, "/", link,")")),
        quiet=TRUE,
        envir=environment())
      if (preview) {
        cat(sub("(.*)(}.*)", "\\1 .preview-image\\2", out))
      } else {
        cat(out)
      }
    } else {
      fn()
    }
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


separate_legend <- function(dds, vars=unique(unlist(lapply(metadata(dds)$models, function(x) all.vars(x$design))))) {
  lapply(
    vars,
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

substitute_x_aes <- function(mapping, excludes=c("", "group","column_split")) {
  # x aesthetic about to be used to represent e.g. PC1 so may need to
  # remap what was being represented by x to another
  # aesthetic. There's an implicit hierarchy of importance of
  # aesthetics, typically x > colour > shape > size > ...
  # But we'll use whatever lexical order they're in the aes.
  need_alt_x <- !(
    # need to represent x-aesthetic somewhere else if it's not already
    # represented in shape or colour
    all(all.vars(mapping$x) %in% all.vars(mapping$colour)) ||
      all(all.vars(mapping$x) %in% all.vars(mapping$color)) ||
      all(all.vars(mapping$x) %in% all.vars(mapping$shape))
  )
  if (need_alt_x) {
    is_aes <- !names(mapping) %in% excludes # the first component is the function itself, we may also have some pseudo-aesthetics  - the rest are the aesthetics
    is_x <- which(names(mapping)[is_aes]=="x")
    first_not_x <- seq_along(mapping[is_aes])[-is_x][1]
    if (is.na(first_not_x)) { # There's no aes other than x, so use colour for what was x
      new_fml <- mapping
      mapping$colour <- mapping$x
      aes_list <- list(mapping)
    } else {
      new_fml <- mapping
      #      names(new_fml)[c(is_x, first_not_x)] <- names(mapping)[c(first_not_x,is_x)]
      if (is_x == sum(is_aes)) { # x is the last aes, so swap with penultimate - it's a more important aesthetic, but the least bad case
        names(new_fml)[is_aes][c(is_x, is_x-1)] <- names(new_fml)[is_aes][c(is_x-1, is_x)]
      } else { # x is a middling aes: each term moves down an aesthetic level - the final one gets assigned 'x' but that will be overwritten and so lost.
        names(new_fml)[is_aes] <- names(mapping)[is_aes][c(seq(sum(is_aes))[-is_x], is_x)]
      }
      ## Use both the old and new mappings - only way to guarantee everything represented somehow
      aes_list <- list(mapping, new_fml)
    }
  } else {
    aes_list <- list(mapping)
  }
  aes_list
}
  
aes_caption <- function(ae) {
  ae <- ae[intersect(c("colour","shape"), names(ae))]
  paste0(names(ae), "\\", as.character(ae), collapse=",")
}


cluster_calc <- function(mat, clusterID) {
  tbl <- table(clusterID)
  levels(clusterID) <- paste0("|", sub("[0-9]+", "", names(tbl)[1]), rank(-tbl, ties="first"), "|=", tbl) # change the labels
  clusterID <- factor(clusterID, levels=levels(clusterID)[rev(order(tbl))])
  centres <- apply(mat, 2, function(samp) tapply(samp, clusterID, mean))
  as.data.frame(t(centres))
}
