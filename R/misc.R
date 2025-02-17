.onAttach <- function(...) {
  ver <- utils::packageVersion("projpred")
  msg <- paste0("This is projpred version ", ver, ".")
  packageStartupMessage(msg)
}

nms_d_test <- function() {
  c("type", "data", "offset", "weights", "y")
}

weighted.sd <- function(x, w, na.rm = FALSE) {
  if (na.rm) {
    ind <- !is.na(w) & !is.na(x)
    n <- sum(ind)
  } else {
    n <- length(x)
    ind <- rep(TRUE, n)
  }
  w <- w / sum(w[ind])
  m <- sum(x[ind] * w[ind])
  sqrt(n / (n - 1) * sum(w[ind] * (x[ind] - m)^2))
}

log_weighted_mean_exp <- function(x, w) {
  log_sum_exp(x + log(w))
}

log_sum_exp <- function(x) {
  max_x <- max(x)
  max_x + log(sum(exp(x - max_x)))
}

auc <- function(x) {
  resp <- x[, 1]
  pred <- x[, 2]
  wcv <- x[, 3]
  n <- nrow(x)
  ord <- order(pred, decreasing = TRUE)
  resp <- resp[ord]
  pred <- pred[ord]
  wcv <- wcv[ord]
  w0 <- w1 <- wcv
  stopifnot(all(resp %in% c(0, 1)))
  w0[resp == 1] <- 0 # for calculating the false positive rate (fpr)
  w1[resp == 0] <- 0 # for calculating the true positive rate (tpr)
  cum_w0 <- cumsum(w0)
  cum_w1 <- cumsum(w1)

  ## ignore tied predicted probabilities, keeping only the rightmost one
  rightmost.prob <- c(diff(pred) != 0, TRUE)
  fpr <- c(0, cum_w0[rightmost.prob]) / cum_w0[n]
  tpr <- c(0, cum_w1[rightmost.prob]) / cum_w1[n]
  delta_fpr <- c(diff(fpr), 0)
  delta_tpr <- c(diff(tpr), 0)

  ## sum the area of the rectangles that fall completely below the ROC curve
  ## plus half the area of the rectangles that are cut in two by the curve
  return(sum(delta_fpr * tpr) + sum(delta_fpr * delta_tpr) / 2)
}

# Bootstrap an arbitrary quantity `fun` that takes the sample `x` as the first
# input. Other arguments of `fun` can be passed by `...`. Example:
# `boostrap(x, mean)`.
bootstrap <- function(x, fun = mean, B = 2000,
                      seed = sample.int(.Machine$integer.max, 1), ...) {
  # Set seed, but ensure the old RNG state is restored on exit:
  if (exists(".Random.seed", envir = .GlobalEnv)) {
    rng_state_old <- get(".Random.seed", envir = .GlobalEnv)
    on.exit(assign(".Random.seed", rng_state_old, envir = .GlobalEnv))
  }
  if (!is.na(seed)) set.seed(seed)

  seq_x <- seq_len(NROW(x))
  is_vector <- NCOL(x) == 1
  bsstat <- rep(NA, B)
  for (i in 1:B) {
    bsind <- sample(seq_x, replace = TRUE)
    bsstat[i] <- fun(if (is_vector) x[bsind] else x[bsind, ], ...)
  }
  return(bsstat)
}

# From `?is.integer` (slightly modified):
.is.wholenumber <- function(x) {
  abs(x - round(x)) < .Machine$double.eps^0.5
}

.validate_num_folds <- function(k, n) {
  if (!is.numeric(k) || length(k) != 1 || !.is.wholenumber(k)) {
    stop("Number of folds must be a single integer value.")
  }
  if (k < 2) {
    stop("Number of folds must be at least 2.")
  }
  if (k > n) {
    stop("Number of folds cannot exceed n.")
  }
}

.validate_vsel_object_stats <- function(object, stats) {
  if (!inherits(object, c("vsel"))) {
    stop("The object is not a variable selection object. Run variable ",
         "selection first")
  }

  recognized_stats <- c("elpd", "mlpd", "mse", "rmse", "acc", "pctcorr", "auc")
  binomial_only_stats <- c("acc", "pctcorr", "auc")

  if (is.null(stats)) {
    stop("Statistic specified as NULL.")
  }
  for (stat in stats) {
    if (!(stat %in% recognized_stats)) {
      stop(sprintf("Statistic '%s' not recognized.", stat))
    }
    if (stat %in% binomial_only_stats &&
        object$refmodel$family$family != "binomial") {
      stop("Statistic '", stat, "' available only for the binomial family.")
    }
  }
  return(invisible(TRUE))
}

.validate_baseline <- function(refmodel, baseline, deltas) {
  stopifnot(!is.null(baseline))
  if (!(baseline %in% c("ref", "best"))) {
    stop("Argument 'baseline' must be either 'ref' or 'best'.")
  }
  if (baseline == "ref" && deltas == TRUE && inherits(refmodel, "datafit")) {
    # no reference model (or the results missing for some other reason),
    # so cannot compute differences between the reference model and submodels
    stop("Cannot use deltas = TRUE and baseline = 'ref' when there is no ",
         "reference model.")
  }
  return(baseline)
}

# A function for retrieving `y` and the corresponding observation weights
# `weights` in their "standard" forms:
#   * If `NCOL(y) == 2`: `y` is the first column and `weights` the second.
#   * If `NCOL(y) == 1`: `weights` is basically unchanged (unless of length zero
#     in which case it is replaced by a vector of ones). For a binomial family,
#     if `is.factor(y)`, `y` is transformed into a zero-one vector (i.e., with
#     values in the set {0, 1}).
.get_standard_y <- function(y, weights, fam) {
  if (NCOL(y) == 1) {
    if (length(weights) > 0) {
      weights <- unname(weights)
    } else {
      weights <- rep(1, length(y))
    }
    if (fam$family == "binomial") {
      if (is.factor(y)) {
        if (nlevels(y) > 2) {
          stop("y cannot contain more than two classes if specified as factor.")
        }
        y <- as.vector(y, mode = "integer") - 1L # zero-one vector
      }
    } else {
      if (is.factor(y)) {
        stop("y cannot be a factor for models other than the binomial model.")
      }
    }
  } else if (NCOL(y) == 2) {
    if (fam$family != "binomial") {
      stop("For non-binomial families, a two-column response is not allowed.")
    }
    weights <- unname(y[, 1] + y[, 2])
    y <- unname(y[, 1])
  } else {
    stop("The response is not allowed to have more than two columns.")
  }
  return(nlist(y, weights))
}

# Create the "reference distribution", i.e., reduce the number of posterior
# draws from the reference model by clustering, thinning, or subsampling them
#
# @param refmodel An object of class `refmodel`.
# @param nclusters The desired number of clusters of draws. If
#   `!is.null(nclusters)`, then clustering is used and `ndraws` is ignored.
# @param ndraws The desired number of draws. If `!is.null(nclusters)`, then
#   clustering is used and `ndraws` is ignored.
# @param thinning A single logical value indicating whether in the case where
#   `ndraws` is used, the reference model's draws should be thinned or
#   subsampled (without replacement).
#
# @return Let \eqn{y} denote the response (vector), \eqn{N} the number of
#   observations, and \eqn{S_{\mathrm{prj}}}{S_prj} the number of projected
#   draws (= either `nclusters` or `ndraws`, depending on which one is used).
#   Then the return value is a list with elements:
#
#   * `mu`: An \eqn{N \times S_{\mathrm{prj}}}{N x S_prj} matrix of expected
#   values for \eqn{y} for each draw/cluster.
#   * `var`: An \eqn{N \times S_{\mathrm{prj}}}{N x S_prj} matrix of predictive
#   variances for \eqn{y} for each draw/cluster which are needed for projecting
#   the dispersion parameter (the predictive variances are NA for those families
#   that do not have a dispersion parameter).
#   * `dis`: A vector of length \eqn{S_{\mathrm{prj}}}{S_prj} containing the
#   reference model's dispersion parameter value for each draw/cluster (NA for
#   those families that do not have a dispersion parameter).
#   * `weights`: A vector of length \eqn{S_{\mathrm{prj}}}{S_prj} containing the
#   weights for the draws/clusters.
#   * `cl`: Cluster assignment for each posterior draw, that is, a vector that
#   has length equal to the number of posterior draws and each value is an
#   integer between 1 and \eqn{S_{\mathrm{prj}}}{S_prj}.
.get_refdist <- function(refmodel, ndraws = NULL, nclusters = NULL,
                         thinning = TRUE,
                         throw_mssg_ndraws = getOption("projpred.mssg_ndraws",
                                                       TRUE)) {
  # Number of draws in the reference model:
  S <- NCOL(refmodel$mu)

  if (!is.null(nclusters)) {
    # use clustering (ignore ndraws argument)
    nclusters <- min(S, nclusters)
    if (nclusters == S) {
      # number of clusters equal to the number of samples, so return the samples
      return(.get_refdist(refmodel, ndraws = nclusters,
                          throw_mssg_ndraws = FALSE))
    } else if (nclusters == 1) {
      # special case, only one cluster
      p_ref <- .get_p_clust(family = refmodel$family, mu = refmodel$mu,
                            eta = refmodel$eta, dis = refmodel$dis,
                            wobs = refmodel$wobs, cl = rep(1, S),
                            offs = refmodel$offset)
    } else {
      # several clusters
      p_ref <- .get_p_clust(family = refmodel$family, mu = refmodel$mu,
                            eta = refmodel$eta, dis = refmodel$dis,
                            wobs = refmodel$wobs, nclusters = nclusters,
                            offs = refmodel$offset)
    }
  } else {
    ndraws <- min(S, ndraws)
    if (ndraws <= 20 && isTRUE(throw_mssg_ndraws)) {
      message("The number of draws to project is quite small (<= 20). In such ",
              "cases, it is usually better to use clustering.")
    }
    if (thinning) {
      s_ind <- round(seq(from = 1, to = S, length.out = ndraws))
    } else {
      s_ind <- draws_subsample(S = S, ndraws = ndraws)
    }
    cl <- rep(NA, S)
    cl[s_ind] <- 1:ndraws
    mu_offs <- refmodel$mu
    if (!all(refmodel$offset == 0)) {
      mu_offs <- refmodel$family$linkinv(
        refmodel$family$linkfun(mu_offs) + refmodel$offset
      )
    }
    predvar <- do.call(cbind, lapply(s_ind, function(j) {
      refmodel$family$predvar(mu_offs[, j, drop = FALSE], refmodel$dis[j])
    }))
    p_ref <- list(
      mu = refmodel$mu[, s_ind, drop = FALSE], var = predvar,
      dis = refmodel$dis[s_ind], weights = rep(1 / ndraws, ndraws), cl = cl,
      clust_used = FALSE
    )
  }

  return(p_ref)
}

# Function for clustering the parameter draws:
.get_p_clust <- function(family, mu, eta, dis, nclusters = 10,
                         wobs = rep(1, dim(mu)[1]),
                         wsample = rep(1, dim(mu)[2]), cl = NULL,
                         offs = rep(0, dim(mu)[1])) {
  # cluster the samples in the latent space if no clustering provided
  if (is.null(cl)) {
    # Note: A seed is not set here because this function is not exported and has
    # a calling stack at the beginning of which a seed is set.

    out <- kmeans(t(eta), nclusters, iter.max = 50)
    cl <- out$cluster # cluster indices for each sample
  } else if (typeof(cl) == "list") {
    # old clustering solution provided, so fetch the cluster indices
    if (is.null(cl$cluster)) {
      stop("argument cl must be a vector of cluster indices or a clustering ",
           "object returned by k-means.")
    }
    cl <- cl$cluster
  }

  # (re)compute the cluster centers, because they may be different from the ones
  # returned by kmeans if the samples have differing weights
  # Number of clusters (assumes labeling "1, ..., nclusters"):
  nclusters <- max(cl, na.rm = TRUE)
  # Cluster centers:
  centers <- matrix(0, nrow = nclusters, ncol = dim(mu)[1])
  # Cluster weights:
  wcluster <- rep(0, nclusters)
  # Dispersion parameter draws aggregated within each cluster:
  dis_agg <- rep(NA_real_, nclusters)
  # Predictive variances:
  predvar <- matrix(nrow = dim(mu)[1], ncol = nclusters)
  eps <- 1e-10
  # Predictions incorporating offsets (needed for `predvar`):
  mu_offs <- mu
  if (!all(offs == 0)) {
    mu_offs <- family$linkinv(family$linkfun(mu_offs) + offs)
  }
  for (j in 1:nclusters) {
    ind <- which(cl == j)
    # Compute normalized weights within the j-th cluster; `1 - eps` is for
    # numerical stability:
    ws <- wsample[ind] / sum(wsample[ind]) * (1 - eps)

    # Center of the j-th cluster:
    centers[j, ] <- mu[, ind, drop = FALSE] %*% ws
    # Unnormalized weight for the j-th cluster:
    wcluster[j] <- sum(wsample[ind])
    # Aggregated dispersion parameter for the j-th cluster:
    dis_agg[j] <- crossprod(dis[ind], ws)
    # Predictive variance for the j-th cluster:
    predvar[, j] <- family$predvar(mu_offs[, ind, drop = FALSE], dis[ind], ws)
  }
  wcluster <- wcluster / sum(wcluster)

  # combine the results
  p <- list(
    mu = unname(t(centers)),
    var = predvar,
    dis = dis_agg,
    weights = wcluster,
    cl = cl,
    clust_used = TRUE
  )
  return(p)
}

draws_subsample <- function(S, ndraws) {
  # Note: A seed is not set here because this function is not exported and has a
  # calling stack at the beginning of which a seed is set.

  return(sample.int(S, size = ndraws))
}

.is_proj_list <- function(proj) {
  # Better use a formal class `proj_list`, but for now, use this workaround:
  is.list(proj) && length(proj) && all(sapply(proj, inherits, "projection"))
}

.unlist_proj <- function(p) {
  if (length(p) == 1) p[[1]] else p
}

## create a named list using object names
nlist <- function(...) {
  m <- match.call()
  dots <- list(...)
  no_names <- is.null(names(dots))
  has_name <- if (no_names) FALSE else nzchar(names(dots))
  if (all(has_name)) {
    return(dots)
  }
  nms <- as.character(m)[-1]
  if (no_names) {
    names(dots) <- nms
  } else {
    names(dots)[!has_name] <- nms[!has_name]
  }
  dots
}

# The `%||%` special binary (infix) operator from brms (equivalent to the
# `%ORifNULL%` operator from rstanarm):
`%||%` <- function(x, y) {
  if (is.null(x)) x <- y
  x
}

#' Execute a function call
#'
#' Execute a function call similar to [do.call()], but without deparsing
#' function arguments.
#'
#' @param what Either a function or a non-empty character string naming the
#'   function to be called.
#' @param args A `list` of arguments to the function call. The [`names`]
#'   attribute of `args` gives the argument names.
#' @param pkg Optional name of the package in which to search for the function
#'   if `what` is a character string.
#'
#' @return The result of the (evaluated) function call.
#'
#' @keywords internal
#' @export
do_call <- function(what, args, pkg = NULL) {
  call <- ""
  if (length(args)) {
    if (!is.list(args)) {
      stop2("'args' must be a list.")
    }
    fun_args <- names(args)
    if (is.null(fun_args)) {
      fun_args <- rep("", length(args))
    } else {
      nzc <- nzchar(fun_args)
      fun_args[nzc] <- paste0("`", fun_args[nzc], "` = ")
    }
    names(args) <- paste0(".x", seq_along(args))
    call <- paste0(fun_args, names(args), collapse = ",")
  } else {
    args <- list()
  }
  if (is.function(what)) {
    args$.fun <- what
    what <- ".fun"
  } else {
    what <- paste0("`", as_one_character(what), "`")
    if (!is.null(pkg)) {
      what <- paste0(as_one_character(pkg), "::", what)
    }
  }
  call <- paste0(what, "(", call, ")")
  eval2(call, envir = args, enclos = parent.frame())
}

# like 'eval' but parses characters before evaluation
eval2 <- function(expr, envir = parent.frame(), ...) {
  if (is.character(expr)) {
    expr <- parse(text = expr)
  }
  eval(expr, envir, ...)
}

# coerce `x` to a single character string
as_one_character <- function(x, allow_na = FALSE) {
  s <- substitute(x)
  x <- as.character(x)
  if (length(x) != 1L || anyNA(x) && !allow_na) {
    s <- deparse_combine(s, max_char = 100L)
    stop2("Cannot coerce '", s, "' to a single character value.")
  }
  x
}

stop2 <- function(...) {
  stop(..., call. = FALSE)
}

# combine deparse lines into one string
deparse_combine <- function(x, max_char = NULL) {
  out <- paste0(deparse(x), collapse = "")
  if (isTRUE(max_char > 0)) {
    out <- substr(out, 1L, max_char)
  }
  out
}

#' @importFrom magrittr %>%
#' @export
magrittr::`%>%`

# `R CMD check` throws a note when using <package>:::<function>() (for accessing
# <function> which is not exported by its <package>). Of course, usage of
# non-exported functions should be avoided, but sometimes there's no way around
# that. Thus, with the following helper operator, it is possible to redefine
# such functions here in projpred:
`%:::%` <- function(pkg, fun) {
  # Note: `utils::getFromNamespace(fun, pkg)` could probably be used, too (but
  # its documentation is unclear about the inheritance from parent
  # environments).
  get(fun, envir = asNamespace(pkg), inherits = FALSE)
}

# Helper function to combine separate `list`s into a single `list`:
rbind2list <- function(x) {
  as.list(do.call(rbind, lapply(x, as.data.frame)))
}
