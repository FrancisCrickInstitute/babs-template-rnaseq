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
  library(DEP)
  library(gt)
  library(limma)
})
my_theme <- bs_theme()

source("R/plot.r")
source("R/markdown.r")
source("R/rnaseq.r")
source("R/partial.r")
source("R/output.r")
source("R/helpers.r")
param <- ParamList$new()
param$set("RowNoun","Measure")

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
    selectInput("dmc_m", "Model", choices=names(dmc()[[input$dmc_d]]))
  })

  output$comparisonInput <- renderUI({
    req(dmc(), input$dmc_d, input$dmc_m)
    selectInput("dmc_c", "Comparison", choices=names(dmc()[[input$dmc_d]][[input$dmc_m]]$comps))
  })

  output$profileInput <- renderUI({
    req(dmc(), input$dmc_d, input$dmc_m)
    profile <- metadata(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[1]])$model$differential_profile_plots
    selectInput("dmc_profile", "Plot Arrangement",
                setNames(
                  seq_along(profile),
                  ifelse(names(profile)=="", paste0("P", seq_along(profile)), names(profile))
                )
                )
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
    out
  })

  ddsList <- reactive({
    fname <- file.path("data", paste0("ddsList_",  config_spec()$config, "_", config_spec()$spec, ".rda"))
    req(file.exists(fname))
    load(fname)
    ddsList
  })

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
    df <- as.data.frame(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[input$dmc_c]])
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
    req(dmc(), input$dmc_d, input$dmc_m, inds(), ddsList())
    dds <- ddsList()[[input$dmc_d]]
    design(dds) <-  design(dmc()[[input$dmc_d]][[input$dmc_m]]$dds)
    plot_fml <- metadata(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[1]])$model$differential_profile_plots[[as.numeric(input$dmc_profile)]]
    model_meta <- metadata(dds)$models[[input$dmc_m]]
    model_vars <- sort_vars(
      unique(c(all.vars(model_meta$design),
               unique(unlist(lapply(plot_fml, all.vars)))
               )),
      model_meta$variables)
    model_vars <- intersect(model_vars, names(colDF(dds)))
    mat <- cached_partial()(dds, plot_fml, influence=dds$.influential)
    pls <- hmap_fn(
      dds=dds[inds(),, drop=FALSE],
      mat=mat[inds(),, drop=FALSE],
      param=param,
      cluster_transform=identity,
      model_vars = model_vars,
      plot_fml = plot_fml,
      measure_name ="Assay",
      gene_clust = NULL)
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
    req(dmc(), input$dmc_d, input$dmc_m, selected_row(), ddsList())
    dds <- ddsList()[[input$dmc_d]]
    design(dds) <-  design(dmc()[[input$dmc_d]][[input$dmc_m]]$dds)
    plot_fml <- metadata(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[1]])$model$differential_profile_plots[[as.numeric(input$dmc_profile)]]
    mapping <- eval(plot_fml[[2]])
    plotFrame <- as.data.frame(colData(dds))
    this_assay <- cached_partial()(dds, plot_fml, influence=dds$.influential)
    plotFrame$.derived.value <- this_assay[selected_row(),]
    flag_vars <- all.vars(mapping$flag)
    mapping <- modify_mapping(modifyList(mapping, aes(y=.derived.value, mask=NULL, cluster=NULL, rows=NULL)))
    if ("visible" %in% names(plot_fml[[2]])) {
      plotFrame <- plotFrame[eval(plot_fml[[2]]$visible, colData(dds)), , drop=FALSE]
    }
    pl <- ggplot(plotFrame, mapping) +
      facet_wrapper(mapping, scales="free_y") + 
      geom_point(size = 3, shape = 21) +
      theme_bw() +
      labs(x="Time", y="Log Abundance", title=selected_row()) +
      get_colour_scales(dds, mapping, flag_vars) +
      theme(text=element_text(size=20), #change font size of all text
            axis.text=element_text(size=20), #change font size of axis text
            axis.title=element_text(size=20), #change font size of axis titles
            plot.title=element_text(size=20), #change font size of plot title
            legend.text=element_text(size=20), #change font size of legend text
            legend.title=element_text(size=20)) #change font size of legend title
    if ("group" %in% names(mapping)) {
      pl <- pl +
        geom_line(linewidth=0.25, alpha=0.2,
                  stat="summary",
                  fun=mean)
    }
    pl
  })
  
  output$modelText <- renderText({
    req(input$dmc_d, input$dmc_m, dmc())
    mm <- metadata(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[1]])$model
    paste0("Model ", input$dmc_m, "(", mm$name, ") - ", mm$description, ": ", format(mm$design))
  })
  
  output$comparisonText <- renderText({
    req(input$dmc_d, input$dmc_m, input$dmc_c, dmc())
    mc <- metadata(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[input$dmc_c]])$comparison
    if ("spec" %in% names(attributes(mc))) {
      mc <- format(attr(mc, "spec"))
    } else {
      mc <- deparse(mc)
    }
    paste0("Comparison ", input$dmc_c, ": ", mc)
  })
  
  output$profileText <- renderText({
    req(input$dmc_d, input$dmc_m, input$dmc_c, input$dmc_profile, dmc())
    mapping <- metadata(dmc()[[input$dmc_d]][[input$dmc_m]]$comps[[1]])$model$differential_profile_plots[[as.numeric(input$dmc_profile)]][[2]]
    paste0("Profile ", input$dmc_profile, ": ", deparse(mapping))
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
