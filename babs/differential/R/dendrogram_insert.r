#' Insert new samples into an existing dendrogram
#'
#' @param dend A dendrogram object (or hclust object, which will be converted)
#' @param D_new A distance matrix where rows are new samples to insert and 
#'   columns are the existing samples in the dendrogram. Column names must
#'   match the dendrogram labels exactly.
#' @param D_among_new A distance matrix among the new samples (square, with
#'   rownames/colnames matching rownames of D_new). If NULL, new samples are
#'   inserted independently.
#' @param linkage Linkage method used to create the dendrogram. One of:
#'   "average", "complete", "single", "wardD2", "ward.D2"
#'
#' @return A dendrogram object with the new samples inserted at appropriate
#'   positions based on their distances to existing clusters
insert_samples_into_dendrogram <- function(dend, D_new, D_among_new=NULL, linkage = "average", column_names = NULL) {
  
  # Convert hclust to dendrogram if needed
  if (inherits(dend, "hclust")) {
    hc <- dend
    dend <- as.dendrogram(hc)
  } else if (inherits(dend, "dendrogram")) {
    hc <- list(
      merge = attr(dend, "merge"),
      height = attr(dend, "height"),
      labels = labels(dend),
      method = linkage
    )
    if (is.null(hc$merge) || is.null(hc$height)) {
      stop("Dendrogram must be created from hclust or have merge/height attributes")
    }
  } else {
    stop("dend must be an hclust or dendrogram object")
  }
  
  # Validate inputs
  if (!is.matrix(D_new)) {
    stop("D_new must be a matrix")
  }
  
  if (is.null(rownames(D_new)) || is.null(colnames(D_new))) {
    stop("D_new must have row and column names")
  }
  
  base_labels <- labels(dend)
  if (!all(colnames(D_new) %in% base_labels)) {
    stop("All column names of D_new must match dendrogram labels")
  }
  
  # Check that rows (new samples) are NOT already in the dendrogram
  if (any(rownames(D_new) %in% base_labels)) {
    duplicates <- rownames(D_new)[rownames(D_new) %in% base_labels]
    stop("New samples already exist in dendrogram: ", paste(duplicates, collapse = ", "))
  }
  
  # Reorder D_new columns to match dendrogram label order
  D_new <- D_new[, base_labels, drop = FALSE]
  
  # Define linkage functions
  linkage_fns <- list(
    average = function(dists, size) mean(dists),
    complete = function(dists, size) max(dists),
    single = function(dists, size) min(dists),
    wardD2 = function(dists, size) mean(dists^2),
    ward.D2 = function(dists, size) mean(dists^2)
  )
  
  if (!linkage %in% names(linkage_fns)) {
    stop("Unsupported linkage method: ", linkage)
  }
  
  # Find insertion points individually first
  attach_results <- find_insertion_points(hc, D_new, linkage_fns[[linkage]])
  
  # Group new samples that should merge with each other before the tree
  attach_results <- group_new_samples(attach_results, D_among_new, D_new, hc, linkage_fns[[linkage]], linkage)

  # Insert samples
  dend_expanded <- insert_into_dendrogram(dend, attach_results)
  
  # Validate the result
  expected_labels <- c(base_labels, rownames(D_new))
  actual_labels <- labels(dend_expanded)
  
  if (!setequal(expected_labels, actual_labels)) {
    stop("Dendrogram labels don't match expected after insertion")
  }
  
  # Ensure proper dendrogram attributes for ComplexHeatmap
  dend_expanded <- dendrapply(dend_expanded, function(node) {
    if (is.leaf(node)) {
      if (is.null(attr(node, "label"))) {
        stop("Leaf without label found")
      }
      if (is.null(attr(node, "members"))) {
        attr(node, "members") <- 1L
      }
      if (is.null(attr(node, "height"))) {
        attr(node, "height") <- 0
      }
    }
    node
  })

  # Reindex leaf values
  all_labels <- get_dend_labels(dend_expanded)
  if (is.null(column_names)) {
    column_names <- all_labels
  }
  dend_expanded <- dendrapply(dend_expanded, function(node) {
    if (is.leaf(node)) {
      lbl <- attr(node, "label")
      attrs <- attributes(node)
      node <- match(lbl, column_names)
      attributes(node) <- attrs
    }
    node
  })
  
  dend_expanded <- push_new_samples_right(dend_expanded, base_labels)  
  return(dend_expanded)
}

#' Find where new samples should attach in the tree  
#' @keywords internal
find_insertion_points <- function(hc, D_new, linkage_fn) {
  
  n_base <- length(hc$labels)
  n_new <- nrow(D_new)
  
  results <- vector("list", n_new)
  names(results) <- rownames(D_new)
  
  for (j in seq_len(n_new)) {
    new_sample_name <- rownames(D_new)[j]
    d_to_base <- D_new[j, ]
    
    # Find closest base sample
    closest_base_idx <- which.min(d_to_base)
    closest_base_name <- names(d_to_base)[closest_base_idx]
    min_dist <- d_to_base[closest_base_idx]
    
    # Track clusters as tree builds
    clusters <- as.list(seq_len(n_base))
    best_attachment <- list(
      sample_name = new_sample_name,
      cluster_members = closest_base_name,
      attach_height = min_dist,
      merge_height = min_dist,
      merge_step = 0
    )
    prev_labels <- closest_base_name
    prev_d <- min_dist

    for (i in seq_len(nrow(hc$merge))) {
      merge_row <- hc$merge[i, ]
      
      get_cluster <- function(idx) {
        if (idx < 0) {
          return(list(
            members = -idx, 
            labels = hc$labels[-idx], 
            size = 1
          ))
        }
        cluster_id <- n_base + idx
        return(list(
          members = clusters[[cluster_id]], 
          labels = hc$labels[clusters[[cluster_id]]], 
          size = length(clusters[[cluster_id]])
        ))
      }
      
      c1 <- get_cluster(merge_row[1])
      c2 <- get_cluster(merge_row[2])
      
      new_members <- c(c1$members, c2$members)
      new_labels <- c(c1$labels, c2$labels)
      new_size <- c1$size + c2$size
      
      clusters[[n_base + i]] <- new_members

      if (closest_base_idx %in% new_members) {
        # This merge step involves our tracked cluster.
        # Would X have merged with the PREVIOUS cluster before this step?
        if (prev_d <= hc$height[i]) {
          best_attachment <- list(
            sample_name = new_sample_name,
            cluster_members = prev_labels,
            attach_height = prev_d,
            merge_height = hc$height[i],
            merge_step = i
          )
          break
        }
        # X didn't merge yet — continue tracking the larger cluster
        prev_labels <- new_labels
        prev_d <- linkage_fn(D_new[j, new_labels], new_size)
      }
    }
    
    results[[j]] <- best_attachment
  }
  
  return(results)
}

#' Group new samples that should merge with each other before attaching to the tree
#' @keywords internal
group_new_samples <- function(attach_results, D_among_new, D_new, hc, linkage_fn, linkage) {
  if (is.null(D_among_new) || length(attach_results) <= 1) {
    return(attach_results)
  }
  
  nms <- sapply(attach_results, `[[`, "sample_name")
  attach_heights <- sapply(attach_results, `[[`, "attach_height")
  
  # Build adjacency: two new samples should group if their mutual distance
  # is less than both of their individual attach heights (meaning they'd
  # merge with each other before either merges with the base tree)
  n <- length(nms)
  adj <- matrix(FALSE, n, n, dimnames = list(nms, nms))
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i < j) {
        threshold <- min(attach_heights[i], attach_heights[j])
        if (D_among_new[nms[i], nms[j]] < threshold) {
          adj[i, j] <- adj[j, i] <- TRUE
        }
      }
    }
  }
  
  # Find connected components via simple BFS
  visited <- rep(FALSE, n)
  names(visited) <- nms
  components <- list()
  
  for (i in seq_len(n)) {
    if (visited[nms[i]]) next
    # BFS
    queue <- nms[i]
    component <- character(0)
    while (length(queue) > 0) {
      current <- queue[1]
      queue <- queue[-1]
      if (visited[current]) next
      visited[current] <- TRUE
      component <- c(component, current)
      neighbours <- nms[adj[current, ]]
      queue <- c(queue, neighbours[!visited[neighbours]])
    }
    components <- c(components, list(component))
  }
  
  # Build results: one entry per component
  out <- list()
  for (comp in components) {
    if (length(comp) == 1) {
      # Singleton — keep original result
      out <- c(out, list(attach_results[[comp]]))
      next
    }
    
    # Build mini-dendrogram for the group from D_among_new
    d_sub <- as.dist(D_among_new[comp, comp, drop = FALSE])
    mini_hc <- hclust(d_sub, method = linkage)
    mini_dend <- as.dendrogram(mini_hc)
    
    # Find a single insertion point for the group:
    # Compute the group's linkage distance to each base sample
    # (apply linkage_fn across all group members for each base sample)
    base_labels <- hc$labels
    n_base <- length(base_labels)
    group_d_to_base <- numeric(n_base)
    names(group_d_to_base) <- base_labels
    for (b in seq_len(n_base)) {
      group_d_to_base[b] <- linkage_fn(D_new[comp, base_labels[b]], length(comp))
    }
    
    # Now walk the tree as in find_insertion_points but using group distances
    closest_base_idx <- which.min(group_d_to_base)
    closest_base_name <- names(group_d_to_base)[closest_base_idx]
    min_dist <- group_d_to_base[closest_base_idx]
    
    clusters <- as.list(seq_len(n_base))
    best_attachment <- list(
      sample_name = NULL,
      subtree = mini_dend,
      cluster_members = closest_base_name,
      attach_height = min_dist,
      merge_height = min_dist,
      merge_step = 0
    )
    prev_labels <- closest_base_name
    prev_d <- min_dist
    
    for (i in seq_len(nrow(hc$merge))) {
      merge_row <- hc$merge[i, ]
      
      get_cluster <- function(idx) {
        if (idx < 0) {
          return(list(members = -idx, labels = hc$labels[-idx], size = 1))
        }
        cluster_id <- n_base + idx
        return(list(members = clusters[[cluster_id]], labels = hc$labels[clusters[[cluster_id]]], size = length(clusters[[cluster_id]])))
      }
      
      c1 <- get_cluster(merge_row[1])
      c2 <- get_cluster(merge_row[2])
      
      new_members <- c(c1$members, c2$members)
      new_labels <- c(c1$labels, c2$labels)
      new_size <- c1$size + c2$size
      
      clusters[[n_base + i]] <- new_members
      
      if (closest_base_idx %in% new_members) {
        if (prev_d <= hc$height[i]) {
          best_attachment <- list(
            sample_name = NULL,
            subtree = mini_dend,
            cluster_members = prev_labels,
            attach_height = prev_d,
            merge_height = hc$height[i],
            merge_step = i
          )
          break
        }
        prev_labels <- new_labels
        # Group linkage distance to the merged cluster
        prev_d <- linkage_fn(
          as.vector(D_new[comp, new_labels]),
          new_size
        )
      }
    }
    
    out <- c(out, list(best_attachment))
  }
  
  out
}

#' Insert samples into dendrogram structure
#' @keywords internal
insert_into_dendrogram <- function(dend, attach_results) {
  
  # Sort by merge step
  attach_results <- attach_results[order(sapply(attach_results, 
                                                 function(x) x$merge_step))]
  
  
  # Helper: fix all attributes recursively
  fix_attributes <- function(node) {
    if (is.leaf(node)) {
      attr(node, "members") <- 1L
      attr(node, "height") <- 0
      attr(node, "leaf") <- TRUE
      return(node)
    }
    
    # Fix children first
    for (i in seq_along(node)) {
      node[[i]] <- fix_attributes(node[[i]])
    }
    
    # Update this node
    total_members <- sum(sapply(node, function(x) attr(x, "members") %||% 1L))
    attr(node, "members") <- as.integer(total_members)
    
    # Ensure height is above all children
    max_child_height <- max(sapply(node, function(x) attr(x, "height") %||% 0))
    current_height <- attr(node, "height") %||% 0
    if (current_height <= max_child_height) {
      attr(node, "height") <- max_child_height + 1e-6
    }
    
    return(node)
  }
  
  # Insert one sample
  insert_one <- function(tree, res) {
    
    target_labels <- res$cluster_members
    
    recurse <- function(node) {
      
      node_labels <- get_dend_labels(node)
      
      # Check containment
      if (!all(target_labels %in% node_labels)) {
        return(list(node = node, inserted = FALSE))
      }
      
      # Try children (find LCA)
      if (!is.leaf(node) && length(node) > 0) {
        for (i in seq_along(node)) {
          child_labels <- get_dend_labels(node[[i]])
          
          if (all(target_labels %in% child_labels)) {
            result <- recurse(node[[i]])
            node[[i]] <- result$node
            return(list(node = node, inserted = result$inserted))
          }
        }
      }
      
      # This is the LCA - insert here
      if (!is.null(res$subtree)) {
        new_node <- res$subtree
        new_members <- length(labels(new_node))
      } else {
        new_node <- structure(
          0,
          label = res$sample_name,
          height = 0,
          leaf = TRUE,
          members = 1L,
          class = "dendrogram"
        )
        new_members <- 1L
      }
      
      current_height <- attr(node, "height") %||% 0
      current_members <- attr(node, "members") %||% length(get_dend_labels(node))
      
      new_height <- max(current_height, res$attach_height)
      if (new_height == current_height) {
        new_height <- current_height + 1e-6
      }
      
      new_parent <- structure(
        list(node, new_node),
        height = new_height,
        members = as.integer(current_members + new_members),
        class = "dendrogram"
      )
      
      return(list(node = new_parent, inserted = TRUE))
    }
    
    result <- recurse(tree)
    
    if (!result$inserted) {
      stop(sprintf("Failed to insert sample '%s'", 
                    res$sample_name %||% paste(labels(res$subtree), collapse=",")))
    }
    
    result$node
  }
  
  # Insert all samples
  for (res in attach_results) {
    dend <- insert_one(dend, res)
  }
  
  # Final cleanup
  dend <- fix_attributes(dend)
   # Reindex leaf values so order.dendrogram() returns valid indices
  all_labels <- get_dend_labels(dend)
  dend <- dendrapply(dend, function(node) {
    if (is.leaf(node)) {
      lbl <- attr(node, "label")
      attrs <- attributes(node)
      node <- match(lbl, all_labels)
      attributes(node) <- attrs
    }
    node
  })
  return(dend)
}

get_dend_labels <- function(node) {
  if (is.leaf(node)) return(attr(node, "label"))
  unlist(lapply(node, get_dend_labels))
}

#' Reorder dendrogram so branches with more non-original samples go right
#' @keywords internal
push_new_samples_right <- function(dend, original_labels) {
  reorder_node <- function(node) {
    if (is.leaf(node)) return(node)
    
    # Recurse first
    for (i in seq_along(node)) {
      node[[i]] <- reorder_node(node[[i]])
    }
    
    # Count fraction of non-original labels in each child
    new_frac <- sapply(node, function(child) {
      labs <- get_dend_labels(child)
      mean(!labs %in% original_labels)
    })
    
    # Sort children: lowest new-fraction first (= left), highest last (= right)
    ord <- order(new_frac)
    if (!identical(ord, seq_along(node))) {
      node[] <- node[ord]
    }
    
    node
  }
  
  reorder_node(dend)
}
