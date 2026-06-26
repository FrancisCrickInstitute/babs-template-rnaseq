suppressPackageStartupMessages({
  library(DESeq2)
  library(shiny)
  library(bslib)
  library(tidyverse)
  library(Hmisc)
  library(emmeans)
  library(ragg)
  library(SummarizedExperiment)
  library(ComplexHeatmap)
  library(InteractiveComplexHeatmap)
  library(gt)
  library(nlme)
  library(openxlsx)
  library(factoextra)
  library(gridExtra)
  library(openxlsx)
  library(broom)
  library(brglm2)
  library(rio)
  library(gt)
  library(limma)
})
my_theme <- bs_theme()
source("R/plot.r")
source("R/dendrogram_insert.r")
source("R/markdown.r")
source("R/rnaseq.r")
source("R/partial.r")
source("R/helpers.r")
source("R/output.r")
if (file.exists("R/my-functions.r")) source("R/my-functions.r")
RowNoun <- "Measure"
rowNoun <- "measure"

shiny_profile <- function(dds, plot_fml, row) {
}

files <- list.files("data", pattern = "_x_.*\\.rds$", full.names = FALSE)
    
# parse spec and config parts
parts <- do.call(rbind, strsplit(gsub("\\.rds$", "", files), "_x_"))
specs   <- parts[,1]
configs <- parts[,2]

# group specs by config
grouped <- split(specs, configs)

# build choices with "spec_x_config" as value, spec as label
rds_choices <- lapply(names(grouped), function(cfg) {
  vals <- grouped[[cfg]]
  setNames(paste0(vals, "_x_", cfg), vals)  # value=spec_x_cfg, label=spec
})
names(rds_choices) <- names(grouped)  # group heading


# Define UI for app 
ui <- page_sidebar(
  theme=my_theme,
  # App title ----
  title = if (exists("my_title") && my_title!="") my_title else "BABS Output Explorer",
  # Sidebar panel for inputs ----
  sidebar = sidebar(
    selectInput(
      "rds",
      "Analysis Plan",
      rds_choices
    ),
    uiOutput("datasetInput"),
    uiOutput("modelInput"),
    uiOutput("comparisonInput"),
    uiOutput("profileInput"),
    uiOutput("subsetInput"),
    uiOutput("featuresInput"),
    textInput("regex", "Feature filter:", value = ""),
    downloadButton("downloadData", "Download Table")
  ),
  #TODO: reimplement  uiOutput(outputId="comp_explan"),
  textOutput("modelText"),
  textOutput("comparisonText"),  
  textOutput("profileText"),  
  fluidRow(
     column(
       width = 12,
       InteractiveComplexHeatmapOutput("hmap")
     ),
    column(
      width = 12,
      plotOutput("aesPlot", height = "300px")
    ),
    column(
      width = 12,
      DT::dataTableOutput("table")
    )
  )
)

server <- function(input, output, session) {
  output$datasetInput <- renderUI({
    req(dmc())
    selectInput("dmc_d", "Dataset", choices=names(dmc()))
  })

  output$modelInput <- renderUI({
    req(dmc(), input$dmc_d)
    selectInput("dmc_m", "Model", choices=names(dmc()[[input$dmc_d]]$models))
  })

  output$comparisonInput <- renderUI({
    req(dmc(), input$dmc_d, input$dmc_m)
    selectInput("dmc_c", "Comparison", choices=names(dmc()[[input$dmc_d]]$models[[input$dmc_m]]$comparisons))
  })

  output$profileInput <- renderUI({
    req(dmc(), input$dmc_d, input$dmc_m)
    profile <- names(dmc()[[input$dmc_d]]$models[[input$dmc_m]]$profile_plots)
    selectInput("dmc_profile", "Plot Arrangement", profile)
  })
  
  output$subsetInput <- renderUI({
    req(dmc(), input$dmc_d, input$dmc_m, input$dmc_c)
    selectInput("subsetID", "Feature Subset", choices=c(
      "All",
      paste0("Exp:", setdiff(names(exploratory_clusters()), "ID")),
      setdiff(names(differential_clusters()), "ID")
    )
    )
  })

  output$featuresInput <- renderUI({
    req(dmc(), input$dmc_d, input$dmc_m, input$dmc_c, input$subsetID)
    if (input$subsetID=="All") {
      choices <- "All"
    } else if (grepl("Exp:", input$subsetID)) {
      subs <- sub("Exp:", "", input$subsetID)
      choices <- unique(exploratory_clusters()[[subs]])
      choices <- c("All", choices[order(as.numeric(sub("\\|[A-Z]+([0-9]+).*", "\\1", choices)))])
    } else {
      choices <- unique(differential_clusters()[[input$subsetID]])
      choices <- c("All", choices[order(as.numeric(sub("\\|[A-Z]+([0-9]+).*", "\\1", choices)))])
    }
    selectInput("inds", "Refinement", choices=choices)
  })

  
  exploratory_clusters <- reactive({
    fname <- file.path("data", paste0("exploratory-clusters_", config_spec()$spec, "_", config_spec()$config, ".rds"))
    readRDS(fname)
  })
  differential_clusters <- reactive({
    fname <- file.path("data", paste0("differential-clusters_", config_spec()$spec, "_", config_spec()$config, ".rds"))
    readRDS(fname)
  })
  
  dmc <- reactive({
    fname <- file.path("data", paste0(input$rds, ".rds"))
    req(file.exists(fname))
    showModal(modalDialog("Loading data...", footer = NULL))
    out <- readRDS(fname)
    removeModal()
    out$sample_sets
  })

  ## ddsList <- reactive({
  ##   fname <- file.path("data", paste0("ddsList_",  config_spec()$config, "_", config_spec()$spec, ".rda"))
  ##   req(file.exists(fname))
  ##   load(fname)
  ##   ddsList
  ## })

  config_spec <- reactive({
    ind <- Filter(function(x) length(x)>0, lapply(rds_choices, function(x) names(x)[x == input$rds]))
    list(config=names(ind), spec=ind[[1]])
  })
  
  inds <- reactive({
    req(dmc(), input$dmc_d, input$dmc_m, input$dmc_c, input$subsetID, input$inds)
    df <- as.data.frame(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[input$dmc_c]])
    if (input$subsetID=="All") {
      ind <- TRUE
    } else if (grepl("Exp:", input$subsetID)) {
      subs <- sub("Exp:", "", input$subsetID)
      if (input$inds=="All") {
        ind <- row.names(df) %in% exploratory_clusters()$ID[!is.na(exploratory_clusters()[[subs]])]
      } else {
        ind <- row.names(df) %in% exploratory_clusters()$ID[exploratory_clusters()[[subs]] == input$inds]
      }
    } else {
      subs <- input$subsetID
      if (input$inds=="All") {
        ind <- row.names(df) %in% differential_clusters()$ID[!is.na(differential_clusters()[[subs]])]
      } else {
        ind <- row.names(df) %in% differential_clusters()$ID[differential_clusters()[[subs]] == input$inds]
      }
    }
    ind
  })    
  
  selected_row <- reactiveVal()

  tbl <- reactive({
    req(dmc(), input$dmc_d, input$dmc_m, input$dmc_c, input$subsetID, inds())
    df <- as.data.frame(dmc()[[input$dmc_d]]$models[[input$dmc_m]]$comparisons[[input$dmc_c]]$results)
    pattern <- input$regex
    if (is.null(pattern)) pattern=""
    hits <- tryCatch({
      grep(pattern, row.names(df)[inds()], ignore.case=TRUE)
    }, error = function(e) {
      TRUE
    })
    out <- df[inds(),,drop=FALSE][hits,,drop=FALSE]
    selected_row(row.names(out)[1])
    out
  })

  observeEvent(input$table_rows_selected, {
    selected_row(row.names(tbl())[input$table_rows_selected])
  })


  observeEvent(input$Comparison,{
    selected_row(row.names(tbl())[1])
  })
  
  hmap_reactive <- reactive({
    req(dmc(), input$dmc_d, input$dmc_m, input$dmc_profile, inds())
    dataset <- dmc()[[input$dmc_d]]
    model <- dataset$models[[input$dmc_m]]
    model_se <- dataset$object
    design(model_se) <- model$design
    plot_formulae <- model$profile_plots
    model_vars <- sort_vars(
      unique(c(all.vars(model$design),
               unique(unlist(lapply(plot_formulae, function(x) c(
                 unique(unlist(lapply(x[[1]], all.vars))),
                 unique(unlist(lapply(x$extra, all.vars)))
                )))))),
      model$variables)
    model_vars <- intersect(model_vars, names(colDF(model_se)))
    plot_config <- plot_formulae[[input$dmc_profile]]
    plot_aes <- plot_config[[1]]
    which_assay <- default_assay_name(plot_aes, model_se)
    plot_se <- model_se
    assays(plot_se) <- setFirstAssay(model_se, which_assay)
    plot_se$.influential_in_assay <- (plot_se$.influential %||% TRUE) & (plot_se$.influential_in_assay[[which_assay]] %||% TRUE)
    plot_se <- plot_se[mcols(plot_se)$filter$exploratory %||% TRUE, , drop=FALSE]
    top <- order(
      rowVars(assay(plot_se, plot_config$extra$sample_clustering_assay %||% 1)[,plot_se$.influential_in_assay,drop=FALSE]),
      decreasing = TRUE)[1:min(nrow(plot_se),plot_config$extra$top_n_variable)]
    expander <- all.vars(plot_config$extra$expand_rows)
    if (length(expander)==1) {
      ## Use a 1:many mcols column to expand out the top rows?
      n_per_top <- sapply(top, function(x) sum(mcols(plot_se)[[expander]] == mcols(plot_se)[[expander]][x]))
      ind <- which(cumsum(n_per_top) >= length(top))[1]
      top <- which(mcols(plot_se)[[expander]] %in% mcols(plot_se)[[expander]][top[1:ind]])
    }
    hmap_data <- assay(plot_se)[top, ]
    colnames(hmap_data) <- rownames(colDF(plot_se))
    do_labels <- nrow(colDF(plot_se)) < 10
    expander <- all.vars(plot_config$extra$expand_rows)
    gene_clust <- bluster::clusterRows(
      hmap_data[,plot_se$.influential_in_assay],
      adapt_hclust_param(plot_config$extra$gene_clust, zero_by=if (length(expander)==1) mcols(plot_se)[[expander]][top] else  NULL),
      full=TRUE)
    this_clust <- "C"
    gene_clust$clusters <- cluster_cardinality(gene_clust$clusters, this_clust)
    cc <- cluster_calc(hmap_data, clusterID=gene_clust$clusters)
    vis_sample <- eval( plot_config$extra$visible, colDF(plot_se))
    do_scale <- eval(plot_config$extra$scale,colDF(plot_se))
    do_centre <- eval(plot_config$extra$centre, colDF(plot_se))
    if (is.logical(do_centre) && length(do_centre)==1 && do_centre) {
      centre_txt <- "Centred "
      hmap_data <- hmap_data - rowMeans(hmap_data[,plot_se$.influential_in_assay, drop=FALSE])
    } else if (is.logical(do_centre) && any(do_centre)) {
      centre_txt <- "Shifted "
      hmap_data <- hmap_data - rowMeans(hmap_data[,plot_se$.influential_in_assay & do_centre, drop=FALSE])
    }  else if (is_formula(do_centre)) {
      grp <- as.integer(interaction(model.frame(do_scale, colData(plot_se)), drop=TRUE))
      m <- do.call(cbind, tapply(seq_along(grp), grp, function(ic) rowMeans(hmap_data[,ic, drop=FALSE])))
      hmap_data <- hmap_data - (m[,grp, drop=FALSE])
      centre_txt <- "Group-centred "
    } else {
      centre_txt <- ""
    }
    if (is.logical(do_scale) && length(do_scale)==1 && do_scale) {
      scale_txt <- "Scaled "
      hmap_data <- hmap_data / sqrt(rowVars(hmap_data[,plot_se$.influential_in_assay, drop=FALSE]))
    } else if (is.logical(do_scale) && any(do_scale)) {
      scale_txt <- "Reference-group-scaled "
      hmap_data <- hmap_data / sqrt(rowVars(hmap_data[,plot_se$.influential_in_assay & do_scale, drop=FALSE]))
    }  else if (is_formula(do_scale)) {
      grp <- as.integer(interaction(model.frame(do_scale, colData(plot_se)), drop=TRUE))
      v <- do.call(cbind, tapply(seq_along(grp), grp, function(ic) rowVars(hmap_data[,ic,drop=FALSE])))
      hmap_data <- hmap_data / sqrt(v[,grp, drop=FALSE])
      scale_txt <- "Group-scaled "
    } else {
      scale_txt <- ""
    }
    if (plot_config$extra$sample_clust@metric %in% c("binary")) {
      measure_name <- paste("Binary", noun_to_readout(RowNoun))
    } else {
      measure_name <- paste0(centre_txt, scale_txt, noun_to_readout(RowNoun))
    }
    if (!is.null(plot_config$extra$sort_by)) {
      sample_order <- reorder_samples(plot_se, all.vars(plot_config$extra$sort_by))
    } else {
      sample_order <- reorder_samples(plot_se, model_vars)
    }
    #
    ## Empirically column-ordered heatmap
    pls <- hmap_fn(
      dds=plot_se[inds(),sample_order, drop=FALSE],
      mat=hmap_data[inds(),sample_order, drop=FALSE],
      row_split = if ("cut.params" %in% slotNames(plot_config$extra$gene_clust) && "k" %in% names(slot(plot_config$extra$gene_clust, "cut.params"))) slot(plot_config$extra$gene_clust, "cut.params")$k  else NULL,
      gene_clust = gene_clust,
      row_title = paste0(RowNoun, "s"),
      model_vars = model_vars,
      plot_config =plot_config,
      measure_name =measure_name,
      colour_saturates=NULL)
    Reduce(`+`, pls)
  })

   observe({
     makeInteractiveComplexHeatmap(
       input,
       output,
       session,
       hmap_reactive(),
       "hmap"
     )
   })
  
  output$aesPlot <- renderPlot({
    req(dmc(), input$dmc_d, input$dmc_m, input$dmc_profile, selected_row())
    dataset <- dmc()[[input$dmc_d]]
    model <- dataset$models[[input$dmc_m]]
    model_se <- dataset$object
    design(model_se) <- model$design
    plot_formulae <- model$profile_plots#get_in_section(model$profile_plots, c("all", "exploratory"))
    model_vars <- sort_vars(
      unique(c(all.vars(model$design),
               unique(unlist(lapply(plot_formulae, function(x) c(
                 unique(unlist(lapply(x[[1]], all.vars))),
                 unique(unlist(lapply(x$extra, all.vars)))
                )))))),
      model$variables)
    model_vars <- intersect(model_vars, names(colDF(model_se)))
    plot_config <- plot_formulae[[input$dmc_profile]]
    plot_aes <- plot_config[[1]]
    which_assay <- default_assay_name(plot_aes, model_se)
    plot_se <- model_se
    assays(plot_se) <- setFirstAssay(model_se, which_assay)
    plot_se$.influential_in_assay <- (plot_se$.influential %||% TRUE) & (plot_se$.influential_in_assay[[which_assay]] %||% TRUE)
    plot_se <- plot_se[mcols(plot_se)$filter$exploratory %||% TRUE, , drop=FALSE]
    mapping <- modify_mapping(plot_config, aes(y=.derived.value))
    flag_vars <- all.vars(plot_config$extra$flag)
    colour_aes <- transform_colour_min(mapping)
    vis_sample <- eval( plot_config$extra$visible, colDF(plot_se))
    centroid_df <- cbind(
      colDF(plot_se),
      data.frame(.derived.value=as.numeric(assay(plot_se[selected_row(),])),
                 .derived="Selected")
    )[vis_sample,,drop=FALSE]
    expander <- all.vars(plot_config$extra$expand_rows)

    pl <- ggplot(centroid_df, mapping) +
      facet_wrapper(mapping, default=aes(facets = .derived), scales="free_y") + 
      geom_point(size = 3, shape = 21) +
      labs(y=noun_to_readout(RowNoun)) 
    if ("group" %in% names(mapping)) {
      pl <- pl +
        geom_line(colour_aes, linewidth=0.25, alpha=0.2,
                  stat="summary",
                    fun=mean) 
      }
      pl <- pl + get_colour_scales(plot_se, mapping, flag_vars)

      if ("ScaleDiscrete" %in% class(layer_scales(pl)$x)) {
        pl <- pl + scale_x_discrete(guide=guide_axis(n.dodge=2))
      }
    pl <- pl +
      theme_bw() +
      theme(text=element_text(size=20), #change font size of all text
            axis.text=element_text(size=20), #change font size of axis text
            axis.title=element_text(size=20), #change font size of axis titles
            plot.title=element_text(size=20), #change font size of plot title
            legend.text=element_text(size=20), #change font size of legend text
            legend.title=element_text(size=20)) #change font size of legend title
    pl
  })
  
  output$modelText <- renderText({
    req(input$dmc_d, input$dmc_m, dmc())
    m <-dmc()[[input$dmc_d]]$models[[input$dmc_m]]
    paste0("Model ", input$dmc_m, "(", m$name, ") - ", m$description, ": ", format(m$design))
  })
  
  output$comparisonText <- renderText({
    req(input$dmc_d, input$dmc_m, input$dmc_c, dmc())
    m <- dmc()[[input$dmc_d]]$models[[input$dmc_m]]$comparisons[[input$dmc_c]]
    paste0("Comparison ", input$dmc_m, "(", m$name, ") - ", m$description)
  })
  
  output$profileText <- renderText({
    req(input$dmc_d, input$dmc_m, input$dmc_c, input$dmc_profile, dmc())
    mc <- dmc()[[input$dmc_d]]$models[[input$dmc_m]]$profile_plots[[input$dmc_profile]]
    paste0("Plot ", input$dmc_m, "(", mc$name, ") - ", mc$description)
  })

  output$table <- DT::renderDataTable(tbl(), server = TRUE, selection="single", rownames=FALSE
                                     )
  output$downloadData <- downloadHandler(
    filename=function() {sub("(.*)\\..*", "results_\\1.csv", infile)},
    content=function(file) write.csv(tbl(), file)
  )
  #TODO: reimplement
  ## output$comp_explan <- renderUI(
  ##   do.call(
  ##     htmltools::tags$ul,
  ##     c(lapply(names(comparisons),
  ##            function(comp) {
  ##              if (input$Comparison == comp) {
  ##                htmltools::tags$li(paste0(comp, " - ", comparisons[[comp]]$description), class=c("list-group-item", "active"))
  ##              } else {
  ##                htmltools::tags$li(paste0(comp, " - ", comparisons[[comp]]$description), class="list-group-item")
  ##              }
  ##            }
  ##            ),
  ##       class="list-group"
  ##       )
  ##   )
  ## )
  
}


app <- shinyApp(ui = ui, server = server)
#runApp(app, host="0.0.0.0")
