#' @export
load_params <- function(script) {
    script_params <- knitr::knit_params(readLines(paste0(script,".qmd"))) %>%
      {setNames(lapply(., "[[", "value"), sapply(., "[[", "name"))}
  }

#' Produce quarto headings corresponding to the data/model hierarchy
#'
#' Create markdown headings at a given level for either a dataset or
#' a model. Use the short name, long name, and description as appropriate.
#' @param obj Either a list of DESeqDataSet objects, or a Data/Model/Comparison hierarchy
#' @param dataset The name of the dataset to use.
#' @param model If the model is to be used to generate the heading info, give the name.
#' @param depth A string denoting the markdown heading prefix
#' @param numbered Do the headings need to be numbered
#' @param describe Print the description text as the first paragraph of the section?
#' @return A markdown string
#' @author Gavin Kelly
#' @export
dmc_heading <- function(obj, hierarchy,  depth="##", numbered=TRUE, describe=TRUE) {
  heading <- paste0("\n\n", depth)
  text <- ""
  dataset <- hierarchy$dataset
  model <- hierarchy$model
  comparison <- hierarchy$comparison
  plot <- hierarchy$plot_config
  is_dmc <- is.list(obj[[dataset]])
  if (is.null(model)) {
    ## Doing a dataset
    met <- modifyList(list(id=dataset), obj$sample_sets[[dataset]])[c("id","name","description")]
    heading <- c(heading, "Dataset", met$id)
    if (!is.null(met$name) && met$name != met$id) {
      heading <- c(heading, ":", met$name)
    }
    if (!is.null(met$description)) {
      text <- paste0(met$description, "\n\n")
    }
  } else if (!is.null(plot)) {
    ## Doing a plot
    met <- modifyList(list(id=plot), obj$sample_sets[[dataset]]$models[[model]]$profile_plots[[plot]])[c("id","name","description")]
    heading <- c(heading, "Plot", met$id)
    if (!is.null(met$name) && met$name != met$id) {
      heading <- c(heading, ":", met$name)
    }
    if (is.na(describe)) {
      describe <- TRUE
      fml <- desc <- ""
    } else {
      pp <- obj$sample_sets[[dataset]]$models[[model]]$profile_plots[[plot]]
      #pp$extra <- lapply(pp$extra, function(ex) eval(ex, colDF(obj$sample_sets[[dataset]]$object)))
      fml <- profile_to_string(pp)
      desc <- describe_for_dmc(pp$extra)
    }
    if (!is.null(met$description)) {
      text <- paste0(met$description, "\n\n",
                    fml, "\n")
    } else {
      text <- paste0(fml, "\n")
    }
    text <- paste0(text, desc)
    text
  } else if (!is.null(comparison)) {
    ## Doing a comparison
    comparisons <- obj$sample_sets[[dataset]]$models[[model]]$comparisons
    if (comparison %in% names(comparisons)) { # otherwise an external list
      met <- modifyList(list(id=comparison), comparisons[[comparison]])[c("id","name","description")]
      heading <- c(heading, "Comparison", met$id)
      if (!is.null(met$name) && met$name != met$id) {
        heading <- c(heading, ":", met$name)
      }
      if (!is.null(met$description)) {
        text <- paste0(met$description, "\n\n")
      }
      if ("tooltip" %in% names(attributes(comparisons[[comparison]]))) {
        text <- paste(text, attr(comparisons[[comparison]], "tooltip"))
      }
    } else {
      heading <- c(heading, "List", comparison)
    }
  } else {
    ## Doing a model
    met <- modifyList(list(id=model), obj$sample_sets[[dataset]]$models[[model]])[c("id","name","description")]
    heading <- c(heading, "Model", met$id)
    if (!is.null(met$name) && met$name != met$id) {
      heading <- c(heading, ":", met$name)
    }
    if (!is.null(met$description)) {
        text <- paste0(met$description, "\n\n")
    }
  }
  heading <- gsub(" : ", ": ", paste(heading, collapse=" "))
  if (!numbered) {
    heading <- paste0(heading, "{.unnumbered}")
  }
  if (!describe) text <- ""
  cat(paste0(heading, "\n\n", text, "\n\n"))
}


#' @export
report_span <- function(id, type, name="", description="" ) {
  if (name!="") {
    sprintf("%s '%s' (%s)", type, id, name)
  } else {
    sprintf("%s '%s'", type, id)
  }
}

#' @export
dmc_factory <- function(obj, type, report=report_span) {
  if (type=="dataset") {
    ids <- names(obj$sample_sets)
    objs <- lapply(obj$sample_sets, function(ss) ss[c("name", "description")])
  } else if (type=="model") {
    ids <- unlist(lapply(obj$sample_sets, function(ss) names(ss$models)))
    objs <- setNames(
      unlist(lapply(obj$sample_sets, function(ss) lapply(ss$models, function(m) m[c("name", "description")])), recursive=FALSE),
      ids)
  } else if (type=="comparison") {
    ids <- unlist(lapply(obj$sample_sets, function(ss) lapply(ss$models, function(m) names(m$comparisons))))
    objs <-setNames(
      unlist(lapply(obj$sample_sets, function(ss) unlist(lapply(ss$models, function(m) lapply(m$comparisons, function(co) co[c("name", "description")])), recursive=FALSE)), recursive=FALSE),
      ids)
  } else {
    objs <- list()
  }
  function(id) report(id, type=type,
               name=objs[[id]]$name %||% "",
               description=objs[[id]]$description %||% "")
}



profile_to_string <- function(plot_config) {
  mapping <- plot_config[[1]]
  
  parts <- lapply(names(mapping), function(nm) {
    paste0(toupper(substr(nm, 1, 1)), substr(nm, 2, nchar(nm)), " = ", rlang::as_label(mapping[[nm]]))
  })
  out <- paste0("Aesthetics:\n\n", paste0("- ", parts, collapse="\n"), "\n\n")

  extras <- list(
    "sort_by" = structure("Sort samples by ", hide=is.null),
    "visible" = structure("Visibility criterion ", hide=all),
    "flag" =  structure("Highlight samples by ", hide=is.null),
    "mask" = structure("Mask assay on ", hide=is.null),
    "sample_clustering_assay" = structure("Base clusters on assay ", hide=function(x) x==1),
    "extra" = structure("Extra variables added to annotation: ", hide=is.null),
    "expand_rows" = structure("Expand top variable genes to include rows match on ", hide=is.null),
    "tooltip" = structure("Hover over dotplots using ", hide=is.null),
    "data_id" = structure("Hover grouping by ", hide=is.null),
    "sort" = structure("Sort dendrogram rows by ", hide=is.null),
    "cols" = structure("Facet columns on ", hide=is.null),
    "rows" = structure("Facet rows on ", hide=is.null),
    "facets" = structure("Facet on ", hide=is.null)
  )
  hide <- sapply(names(extras), function(e) is.call(plot_config$extra[[e]]) || attr(extras[[e]], "hide")(plot_config$extra[[e]]))
  parts <- lapply(
    intersect(names(plot_config$extra), names(extras)[!hide]),
    function(v) paste0(extras[[v]],  ifelse(is.name(plot_config$extra[[v]]), rlang::as_label(plot_config$extra[[v]]), paste(plot_config$qextra[[v]], collape=",")))
  )
                
  paste0(out, "\n\nOptions:\n\n", paste0("- ", parts, collapse="\n"))

}

  
#' @export
tooltip <- function(md, text="") {
  if ("tooltip" %in% names(attributes(md$comparison))) {
    if (text=="") {
      tooltip <- paste0(" {{< tooltips tooltip=\"", attributes(md$comparison)$tooltip, "\" >}} ")
    } else {
      tooltip <- paste0(" {{< tooltips tooltip=\"", attributes(md$comparison)$tooltip, "\" text=\"", text, "\" >}} ")
    }
  } else {
    tooltip <- text
  }
}
