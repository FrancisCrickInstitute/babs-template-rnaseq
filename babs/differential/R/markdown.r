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
    if (!is.null(met$name)) {
      heading <- c(heading, ":", met$name)
    }
    if (!is.null(met$description)) {
      text <- paste0(met$description, "\n\n")
    }
  } else if (!is.null(plot)) {
    ## Doing a plot
    met <- modifyList(list(id=plot), obj$sample_sets[[dataset]]$models[[model]]$profile_plots[[plot]])[c("id","name","description")]
    heading <- c(heading, "Plot config", met$id)
    if (!is.null(met$name)) {
      heading <- c(heading, ":", met$name)
    }
    fml <- profile_to_string(obj$sample_sets[[dataset]]$models[[model]]$profile_plots[[plot]][[1]])
    if (!is.null(met$description)) {
      text <- paste0(met$description, "\n\n",
                    fml, "\n\n")
    } else {
      text <- paste0(fml, "\n\n")
    }
  } else if (!is.null(comparison)) {
    ## Doing a comparison
    comparisons <- obj$sample_sets[[dataset]]$models[[model]]$comparisons
    if (comparison %in% names(comparisons)) { # otherwise an external list
      met <- modifyList(list(id=comparison), comparisons[[comparison]])[c("id","name","description")]
      heading <- c(heading, "Comparison", met$id)
      if (!is.null(met$name)) {
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
    if (!is.null(met$name)) {
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
    tooltip <- text
  }
}
