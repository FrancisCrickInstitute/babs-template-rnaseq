wald2lrt <- function(contr, mdl_mat) {
  in_contr <- contr!=0
  if (sum(in_contr)==1) {
    ret <- mdl_mat[, !in_contr, drop=FALSE]
  } else {
    contr_mat <- diag(sum(in_contr))
    contr_mat[,1] <- contr[in_contr]
    mult_mat <- gram_schmidt(contr_mat)
    ret <- mdl_mat
    ret[,in_contr] <- ret[,in_contr] %*% mult_mat
    ret <- ret[, -which(in_contr)[1], drop=FALSE]
  }
  return(ret)
}

gram_schmidt <- function(a) {
  sf <- sqrt(sum(a[,1]^2))
  e <- diag(1.0, ncol(a))
  for (i in 1:ncol(a)) {
    u <- a[,i]
    for (j in seq_len(i-1)) {
      u <- u - sum(a[,i]*e[,j]) * e[,j]
    }
    e[,i] <- u/sqrt(sum(u*u))
  }
  return(e * sf)
  }
