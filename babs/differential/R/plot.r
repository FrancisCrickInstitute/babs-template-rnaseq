do_plot <- function(pl, label, caption) {
  if ("Heatmap" %in% class(pl)) {
    fn <- function() {
      draw(pl, heatmap_legend_side = "top")
      fig_caption(caption)
    }
  } else {
    fn <- function() {
      print(pl)
      fig_caption(caption)
    }
  }
  if (isTRUE(getOption('knitr.in.progress'))) {
    fig_child <- knitr::knit_expand(
      text=r"(```{r}
#| label: fig-{{lbl}}

fn()
```)",
      lbl=gsub("[^[:alnum:]]+", "-",label)
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
      
      


    


