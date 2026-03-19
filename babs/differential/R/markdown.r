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
    if (is_dmc) {
      met <- metadata(obj[[dataset]][[1]][[1]])$dmc
    } else { 
      met <- metadata(obj[[dataset]])$dmc
    }
    heading <- c(heading, "Dataset", met$dataset)
    if (!is.null(met$dataset_name)) {
      heading <- c(heading, "-", met$dataset_name)
    }
    if (!is.null(met$dataset_description)) {
      text <- paste0(met$dataset_description, "\n\n")
    }
  } else if (!is.null(plot)) {
    ## Doing a plot
    if (is_dmc) {
      met <- metadata(obj[[dataset]][[model]][[1]])$model$profile_plots[[plot]]
    } else { 
      met <- metadata(obj[[dataset]])$models[[model]]$profile_plots[[plot]]
    }
    heading <- c(heading, "Plot config", plot)
    if (!is.null(met$name)) {
      heading <- c(heading, "-", met$name)
    }
    if (!is.null(met$description)) {
      text <- paste0(met$description, "\n\n",
                    profile_to_string(met[[1]]), "\n\n")
    } else {
      text <- paste0(profile_to_string(met[[1]]), "\n\n")
    }
  } else if (!is.null(comparison)) {
    ## Doing a comparison
    if (comparison %in% names(obj[[dataset]][[model]])) { # otherwise an external list
      met <- metadata(obj[[dataset]][[model]][[comparison]])$dmc
      heading <- c(heading, "Comparison", comparison)
      if (!is.null(met$comparison_name)) {
        heading <- c(heading, "-", met$comparison_name)
      }
      if (!is.null(met$comparison_description)) {
        text <- paste0(met$comparison_description, "\n\n")
      }
      if (comparison %in% names(obj[[dataset]][[model]]) && "tooltip" %in% names(attributes(metadata(obj[[dataset]][[model]][[comparison]])$comparison))) {
        text <- paste(text, attr(metadata(obj[[dataset]][[model]][[comparison]])$comparison, "tooltip"))
      }
    } else {
      heading <- c(heading, "List", comparison)
    }
  } else {
    ## Doing a model
    heading <- c(heading, "Model")
    if (is_dmc) {
      met <- metadata(obj[[dataset]][[model]][[1]])$dmc
      heading <- c(heading, met$model)
      if (!is.null(met$model_name)) {
        heading <- c(heading, "-", met$model_name)
      }
      if (!is.null(met$model_description)) {
        text <- paste0(met$model_description, "\n\n")
      }
    }
    else {
      heading <- c(heading, model)
      met <- metadata(obj[[dataset]])$models[[model]]
      if (!is.null(met$name)) {
        heading <- c(heading, "-", met$name)
      }
      if (!is.null(met$description)) {
        text <- paste0(met$description, "\n\n")
      }
    }
  }
  heading <- paste(heading, collapse=" ")
  if (!numbered) {
    heading <- paste0(heading, "{.unnumbered}")
  }
  if (!describe) text=""
  cat(paste0(heading, "\n\n", text, "\n\n"))

}

## dmc_heading <- function(obj, dataset=1, model=NULL, comparison=NULL, plot=NULL, depth="##", numbered=TRUE, describe=TRUE) {
##   heading <- paste0("\n\n", depth)
##   text <- ""
##   is_dmc <- is.list(obj[[dataset]])
##   if (is.null(model)) {
##     ## Doing a dataset
##     if (is_dmc) {
##       met <- metadata(obj[[dataset]][[1]][[1]])$dmc
##     } else { 
##       met <- metadata(obj[[dataset]])$dmc
##     }
##     heading <- c(heading, "Dataset", met$dataset)
##     if (!is.null(met$dataset_name)) {
##       heading <- c(heading, "-", met$dataset_name)
##     }
##     if (!is.null(met$dataset_description)) {
##       text <- paste0(met$dataset_description, "\n\n")
##     }
##   } else {
##     if (!is.null(plot)) {
##       heading <- c(heading, "Plot config")
##       heading <- c(heading, attr(plot, "name"))
##       if (!is.null(attr(plot, "description"))) {
##         text <- paste0(attr(plot, "description"), "\n\n",
##                       profile_to_string(plot), "\n\n")
##       } else {
##         text <- paste0(profile_to_string(plot), "\n\n")
##       }
##     } else if (!is.null(comparison)) {
##       if (comparison %in% names(obj[[dataset]][[model]])) { # otherwise an external list
##         met <- metadata(obj[[dataset]][[model]][[comparison]])$dmc
##         heading <- c(heading, "Comparison", comparison)
##         if (!is.null(met$comparison_name)) {
##           heading <- c(heading, "-", met$comparison_name)
##         }
##         if (!is.null(met$comparison_description)) {
##           text <- paste0(met$comparison_description, "\n\n")
##         }
##         if (comparison %in% names(obj[[dataset]][[model]]) && "tooltip" %in% names(attributes(metadata(obj[[dataset]][[model]][[comparison]])$comparison))) {
##           text <- paste(text, attr(metadata(obj[[dataset]][[model]][[comparison]])$comparison, "tooltip"))
##         }
##       } else {
##         heading <- c(heading, "List", comparison)
##       }
##     } else {
##       ## Doing a model
##       heading <- c(heading, "Model")
##       if (is_dmc) {
##         met <- metadata(obj[[dataset]][[model]][[1]])$dmc
##         heading <- c(heading, met$model)
##         if (!is.null(met$model_name)) {
##           heading <- c(heading, "-", met$model_name)
##         }
##         if (!is.null(met$model_description)) {
##           text <- paste0(met$model_description, "\n\n")
##         }
##       }
##       else {
##         heading <- c(heading, model)
##         met <- metadata(obj[[dataset]])$models[[model]]
##         if (!is.null(met$name)) {
##           heading <- c(heading, "-", met$name)
##         }
##         if (!is.null(met$description)) {
##           text <- paste0(met$description, "\n\n")
##         }
##       }
##     }
##   }
##   heading <- paste(heading, collapse=" ")
##   if (!numbered) {
##     heading <- paste0(heading, "{.unnumbered}")
##   }
##   if (!describe) text=""
##   cat(paste0(heading, "\n\n", text, "\n\n"))
## }

#' @export
report_span <- function(id, type, name="", description="" ) {
  sprintf("%s '%s'", type, id)
  }

#' @export
dmc_factory <- function(obj, type, report=report_span) {
  is_dmc <- is.list(obj[[1]])
  if (is_dmc) {
  } else {
    all_datasets <- lapply(obj, function(x) c(metadata(x)$dmc))
    all_models <- Reduce(c, lapply(obj, function(x) metadata(x)$models))
  }
  if (type=="dataset") {
    function(id) report_span(id, type=type,
                      name=all_datasets[[id]]$name %||% all_datasets[[id]]$dataset,
                      description=all_datasets[[id]]$description)
  } else if (type=="model") {
    function(id)  report_span(id, type=type,
                       name=all_models[[id]]$name %||% all_models[[id]]$model,
                       description=all_models[[id]]$description)
  } else if (type=="comparison") {
    function(id)  report_span(id, type=type,
                       name=all_comparisons[[id]]$name %||% all_comparisons[[id]]$comparison,
                       description=all_comparisons[[id]]$description)
  } else {
    function(id)  report_span(id, type=type, name="", description="")
  }
}



profile_to_string <- function(fml) {
  mapping <- eval(fml[[2]])
  renamer <- as.list(setNames(names(mapping), names(mapping)))
  renamer$data_id <- "hover grouping"
  renamer$group <- "grouping variables"
  renamer$sort_by <- "sort by"
  renamer$flag <- "sample highlighter"
  renamer$cols <- "column splitter"
  renamer$mask <- "assay for masking"
  renamer$cluster <- "assay to base clusters on"
  parts <- vapply(names(mapping), function(nm) {
    expr <- mapping[[nm]]
    rnm <- renamer[[nm]]
    paste0(toupper(substr(rnm, 1, 1)), substr(rnm, 2, nchar(rnm)), " = ", rlang::as_label(expr))
  }, character(1))
  out <- paste0("Aesthetics:\n\n", paste0("- ", parts, collapse="\n"), "\n\n")
  recon <- paste(deparse(as.formula(attr(fml, "src"))[[3]]), collapse="")
  if (recon==".") {
    out
    } else {
      paste(out, "Reconstruction:", recon, "\n\n")
    }
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
    tooltip=text
  }
}
