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
  res$Heatmap$.influential <- setNames(c("black", "white"), c(TRUE, FALSE))
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
  res$ggplot$.influential <- setNames(c("black", "white"), c(TRUE, FALSE))
  res
}
  

sym_colour <- function(dat, lo="blue",zero="white", hi="red", single=FALSE, binary=FALSE) {
  mx <- quantile(abs(dat), 0.9)
  if (single) {
    circlize::colorRamp2(c( 0, mx), colors=c(zero, hi))
  } else {
    circlize::colorRamp2(c(-mx, 0, mx), colors=c(lo, zero, hi))
  }
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
plot_tracker <- function(my_params) {
  script <- tools::file_path_sans_ext(basename(my_params$script))
  plot_list <- list()
  get_tally <- counter() # keeps track of individual labels and running tally of all plots
  function(pl, label, caption, height_opt="", preview=FALSE, plot_meta=list(), interactive=TRUE, dpi=NULL) {
    if (nargs()==0) {
      return(plot_list)
    }
    fig_n <- get_tally()
    label_n <- get_tally(label)
    chunk_label <- paste0(gsub("[^[:alnum:]]+", "-", label), "-", label_n)
    chunk_caption <- paste0("[", caption, "](", script, "/","fig-", sprintf("%0.3i",fig_n), "-", chunk_label, my_params$TAG, ".pdf", ")")
    chunk_caption <- paste0(
      caption,
      " [png](", script, "/","fig-", sprintf("%0.3i",fig_n), "-", chunk_label, my_params$TAG, ".png", ")",
      " [pdf](", script, "/","fig-", sprintf("%0.3i",fig_n), "-", chunk_label, my_params$TAG, ".pdf", ")"
    )
    has_interactivity <- interactive &&  inherits(pl, "ggplot") &&
      any(
        sapply(pl$layers, function(layer) {
          any(grepl("^geomInteractive", class(layer$geom), ignore.case = TRUE)) ||
            any(c("tooltip", "data_id", "onclick") %in% names(layer$mapping))
        })
      )
    if ("Heatmap" %in% class(pl)) {
      fn <- function() {
        draw(pl, heatmap_legend_side = "top")
      }
    }  else if (has_interactivity) {
      fn <- function() {print(rasterize_points(pl, dpi=dpi))}
      fn_widget <- function() {
        g <- girafe(ggobj=pl,
                   width_svg = 14,
                   height_svg = 10,
                   options = list(
                     opts_hover_inv(css = "opacity:0.2;"),
                     opts_hover(css = "stroke-width:2;"),
                     opts_tooltip(use_fill = TRUE),
                     opts_sizing(rescale = TRUE)
                   )
                   )
        knitr::knit_print(g)
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
    if (isTRUE(getOption('knitr.in.progress'))) {
      this_plot_meta <- modifyList(
        plot_meta,
        list(
          png=file.path(script, paste0("fig-", sprintf("%0.3i",fig_n), "-", chunk_label, my_params$TAG, ".png")),
          label=label,
          ind=label_n
        )
      )
      plot_list <<- c(plot_list, list(this_plot_meta))     
      widget_chunk <- knitr::knit_expand(
        text=c('```{r}',
               '#| label: widget-{{chunk_label}}',
               'fn_widget()',
               '```')
      )
      fig_chunk <- knitr::knit_expand(
        text=c("```{r}",
               '#| label: fig-{{chunk_label}}',
               '#| fig-path: "{{script}}/{{fprefix}}-"',
               '{{height_opt}}',
               'fn()',
               '```'),
        fprefix=sprintf("%0.3i",fig_n)
      )
      widget_chunk <- knitr::knit_expand(
        text=c('```{r}',
               '#| label: widget-{{chunk_label}}',
               'fn_widget()',
               '```')
      )
      out <- knitr::knit_child(
        options=if (has_interactivity) list(fig.cap=chunk_caption, out.extra='data-interactive="true"') else  list(fig.cap=chunk_caption),
        text=fig_chunk,
        quiet=TRUE,
        envir=environment())
      if (preview) {
        cat(sub("(.*)(}.*)", "\\1 .preview-image\\2", out))
      } else {
        if (has_interactivity) {
          widget_out <- knitr::knit_child(
            text=widget_chunk,
            quiet=TRUE,
            envir=environment())
          cat(widget_out, "\n\n", out)
        } else {
          cat(out)
        }
      }
    } else {
      fn()
    }
  }
}


rasterize_points <- function(p, dpi = 150) {
  if (is_null(dpi)) return(p)
  p2 <- p
  # Find point layers that are NOT interactive
  point_layers <- which(sapply(
    p2$layers, 
    function(l) inherits(l$geom, "GeomPoint") &&
                !inherits(l$geom, "GeomInteractive")
  ))
  for (i in point_layers) {
    p2$layers[[i]] <- ggrastr::rasterise(
      p2$layers[[i]],
      dpi  = dpi
    )
  }  
  p2
}



separate_legend <- function(dds, vars=unique(unlist(lapply(metadata(dds)$models, function(x) all.vars(x$design))))) {
  lapply(
    intersect(vars, names(metadata(colData(dds))$palette$Heatmap)),
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

substitute_x_aes <- function(mapping, excludes=c("", "group", "data_id", "tooltip", "extra")) {
  # x aesthetic about to be used to represent e.g. PC1 so may need to
  # remap what was being represented by x to another
  # aesthetic. Supplement with x swapped to colour if necessary
  need_alt_x <- !(
      all(all.vars(mapping$x) %in% all.vars(mapping$colour)) ||
      all(all.vars(mapping$x) %in% all.vars(mapping$color)) ||
      all(all.vars(mapping$x) %in% all.vars(mapping$shape))
  )
  out <- list(orig=mapping)
  if (need_alt_x) {
    mapping$colour <- mapping$x
    out$x2colour <- mapping
  }
  out
}
  
aes_caption <- function(ae) {
  ae <- ae[intersect(c("colour","shape", "fill"), names(ae))]
  if (length(ae)>0) {
    paste0(names(ae), "\\", as.character(ae), collapse=",")
  } else {
    "nothing"
  }
}


cluster_calc <- function(mat, clusterID, relevel=TRUE) {
  if (relevel) {
    tbl <- table(clusterID)
    levels(clusterID) <- paste0("|", sub("[0-9]+", "", names(tbl)[1]), rank(-tbl, ties="first"), "|=", tbl) # change the labels
    clusterID <- factor(clusterID, levels=levels(clusterID)[rev(order(tbl))])
  }
  if (length(levels(clusterID))==1) {
    setNames(data.frame(apply(mat, 2, mean)), levels(clusterID))
  } else {
    centres <- apply(mat, 2, function(samp) tapply(samp, clusterID, mean))
    as.data.frame(t(centres))
  }
}

my_alpha_scale <- function(pl, decay=0.3) {
  mapping <- pl$mapping$alpha
  if (is.null(mapping)) {
    return(NULL)
  }
  alpha_var <- rlang::as_name(mapping)
  fac_levels <- levels(factor(pl$data[[alpha_var]]))
  scale_alpha_manual(values = setNames(rev((decay)^(seq_along(fac_levels)-1)), fac_levels))
}


sort_vars <- function(x, target) {
  targets <- all.vars(target)
  if (length(targets)!=0) {
    x[order(match(x, targets))]
  } else {
    x
  }
}


modify_mapping <- function(aes_obj) {
  aes_obj <- handle_flag_aes(aes_obj)
  if (!is.null(aes_obj$tooltip)) return(aes_obj)
  vars_used <- unique(unlist(lapply(aes_obj, all.vars)))
  data_id_var <- if (!is.null(aes_obj$data_id)) all.vars(aes_obj$data_id) else character(0)
  vars_ordered <- c(data_id_var, setdiff(vars_used, data_id_var))
  tooltip_expr <- rlang::parse_expr(
    paste0(
      "paste(",
      paste(sprintf('\"%s: \", format(%s, digits=2, scientific=NA)', vars_ordered, vars_ordered), collapse = ', \"\\n\", '),
      ", sep='')"
    )
  )
  aes_obj$tooltip <- tooltip_expr
  return(aes_obj)
}

    
handle_flag_aes <- function(aes_obj) {
  has_flag <- "flag" %in% names(aes_obj)
  if ("fill" %in% names(aes_obj) || !"colour" %in% names(aes_obj)) return(aes_obj)
  aes_obj <- as.list(aes_obj)  # make editable
  colour_expr <- aes_obj$colour
  aes_obj$fill <- colour_expr
  if (has_flag) {
    flag_expr <- aes_obj$flag
    flag_true <- paste(all.vars(eval(plot_fml[[2]])$flag), collapse=",")
    aes_obj$colour <- expr(factor(ifelse(!!flag_expr, !!flag_true, as.character(!!colour_expr)), levels=c(levels(!!colour_expr), !!flag_true)))
    aes_obj$flag   <- NULL
  }
  do.call(aes, aes_obj)
}


get_colour_scales <- function(dds, mapping, flag_vars=character()) {
  colour_by <- setdiff(all.vars(eval(mapping)$colour), flag_vars)
  scale_out <- list()
  if (length(flag_vars)!=0) {
    scale_out$legend <- labs(colour=paste(flag_vars, collapse=","))
  }
  my_palette <- metadata(colData(dds))$palette$ggplot
  if (length(colour_by) == 1 && colour_by %in% names(my_palette)) {
    if (is.numeric(colData(dds)[[colour_by]])) {
      pal_col <- my_palette[[colour_by]]
      scale_out$colour <- scale_colour_gradient(low = pal_col[1], high = pal_col[2])
    } else {
      flag_true <- paste(flag_vars, collapse=",")
      scale_out$colour <- scale_colour_manual(values = c(my_palette[[colour_by]], setNames("#000000", flag_true)))
    }
  }
  fill_by <- all.vars(eval(mapping)$fill)
  if (length(fill_by) == 1 && fill_by %in% names(my_palette)) {
    if (is.numeric(colData(dds)[[fill_by]])) {
      pal_col <- my_palette[[fill_by]]
      scale_out$fill <- scale_fill_gradient(low = pal_col[1], high = pal_col[2])
    } else {
      scale_out$fill <- scale_fill_manual(values = my_palette[[fill_by]])
    }
  }
  scale_out
}

height_scaler <- function(n, small, big, N) {
        h <- small +(big-small)*(n-1)/(N-1)
        min(h, big)
}
