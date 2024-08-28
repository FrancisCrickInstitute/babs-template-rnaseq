##' Make captioning function that generates hyperlinks
##'
##' captioner returns a function that can be used in `fig.cap`.  Call
##' the resulting function with a string containing the caption text,
##' after any plot, to store a link to the pdf version of the
##' plot. Call the function without any arguments (e.g. in the
##' `fig.cap` argument of a chunk) to invoke the captioining mechanism
##' in the markdown.
##' @title Caption hyperlinking
##' @return
##' @author Gavin Kelly
#' @export
captioner <- function(ext="pdf") {
  local({
    captions <- character()
    function(caption) {
      if (missing(caption)) {
        ret <- captions
        if (length(ret)==0) ret <- ""
        captions <<- character()
        return(ret)
      } else {
        if (isTRUE(getOption('knitr.in.progress'))) {
          link_caption <- paste0("[", caption, "](", knitr::fig_path(ext, number=length(captions)+1), ")")
        } else {
          link_caption <- caption
        }
        captions <<- c(captions, link_caption)
      }
    }
  })
}

if (include_from_package <- FALSE) {

##' Link GT tables to a csv file
##'
##' To be used in a `GT` pipeline, it will store the underlying table
##' data in a csv file under the given name, and insert a link in the
##' table's caption that points to the csv file.
##' @title Link GT tables to a csv file
##' @param data The GT object with a caption set
##' @param name The filename of the csv
##' @return Th GT object (invisibly)
##' @author Gavin Kelly
#' @export
tab_link_caption <- function(data,name) {
  if (missing(name)) {
    heading <- gt:::dt_heading_get(data)
    name <- paste(heading$title, heading$subtitle)
  }
  caption <- gt:::dt_options_get_value(data = data, option = "table_caption")
  fname <- knitr::fig_path("csv", number=name)
  if (!file.exists(dirname(fname))) dir.create(dirname(fname), recursive=TRUE)
  write.csv(gt:::dt_data_get(data), file=fname)
  data <- gt:::dt_options_set_value(
    data,
    "table_caption",
    paste0("[", caption, "](", fname, ")")
  )
  invisible(data)
}


##' Generate multiple captions per chunk
##'
##' To be used in a `GT` pipeline. Before the call to `gt` to
##' suffix the chunk label to make the caption unique, and once after
##' to reset the chunk label to its default
##' 
##' @title Multiple GT tables per chunk
##' @param data The GT object
##' @param label The text that uniquely identifies this table amongst others in the chunk
##' @return Th GT object (invisibly)
##' @author Gavin Kelly
#' @export
bookdown_label <- function(data, label="") {
  current <- knitr::opts_current$get('label')
  if ("chunk" %in% names(attributes(data))) {
    knitr::opts_current$set(label=attr(data, "chunk"))
  } else {
    attr(data, "chunk") <- current
    knitr::opts_current$set(label=paste(current, label, sep="-"))
  }
  invisible(data)
}
    
    

}
load_params <- function(prefix) {
    script_params <- knitr::knit_params(readLines(paste0(prefix,".qmd"))) %>%
      {setNames(lapply(., "[[", "value"), sapply(., "[[", "name"))}
  }

##' Produce quarto headings corresponding to the data/model hierarchy
##'
##' Create markdown headings at a given level for either a dataset or
##' a model. Use the short name, long name, and description as appropriate.
##' @param obj Either a list of DESeqDataSet objects, or a Data/Model/Comparison hierarchy
##' @param dataset The name of the dataset to use.
##' @param model If the model is to be used to generate the heading info, give the name.
##' @param depth A string denoting the markdown heading prefix
##' @param numbered Do the headings need to be numbered
##' @param describe Print the description text as the first paragraph of the section?
##' @return A markdown string
##' @author Gavin Kelly
dmc_heading <- function(obj, dataset=1, model=NULL, depth="##", numbered=TRUE, describe=TRUE) {
  heading <- paste0("\n\n", depth)
  text <- ""
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
  cat(paste(heading, "\n\n", text))
}
