.get_sub_summaries <- function(submodels, refmodel, test_points, newdata = NULL,
                               offset = refmodel$offset[test_points],
                               wobs = refmodel$wobs[test_points],
                               y = refmodel$y[test_points]) {
  lapply(submodels, function(initsubmodl) {
    .weighted_summary_means(
      y_test = list(y = y, weights = wobs),
      family = refmodel$family,
      wsample = initsubmodl$weights,
      mu = refmodel$family$mu_fun(initsubmodl$submodl, obs = test_points,
                                  newdata = newdata, offset = offset),
      dis = initsubmodl$dis
    )
  })
}

# Calculate log predictive density values and average them across parameter
# draws (together with the corresponding expected response values).
#
# @param y_test A `list`, at least with elements `y` (response values) and
#   `weights` (observation weights).
# @param family A `family` object.
# @param wsample A vector of weights for the parameter draws.
# @param mu A matrix of expected values for `y`.
# @param dis A vector of dispersion parameter draws.
#
# @return A `list` with elements `mu` and `lppd` which are both vectors
#   containing the values for the quantities from the description above.
.weighted_summary_means <- function(y_test, family, wsample, mu, dis) {
  if (!is.matrix(mu)) {
    stop("Unexpected structure for `mu`. Do the return values of ",
         "`proj_predfun` and `ref_predfun` have the correct structure?")
  }
  loglik <- family$ll_fun(mu, dis, y_test$y, y_test$weights)
  if (!is.matrix(loglik)) {
    stop("Unexpected structure for `loglik`. Please notify the package ",
         "maintainer.")
  }
  # Average over the draws, taking their weights into account:
  return(list(mu = c(mu %*% wsample),
              lppd = apply(loglik, 1, log_weighted_mean_exp, wsample)))
}

# A function to calculate the desired performance statistics, their standard
# errors, and confidence intervals with coverage `1 - alpha` based on the
# variable selection output. If `nfeat_baseline` is given, then compute the
# statistics relative to the baseline model of that size (`nfeat_baseline = Inf`
# means that the baseline model is the reference model).
.tabulate_stats <- function(varsel, stats, alpha = 0.05,
                            nfeat_baseline = NULL, ...) {
  stat_tab <- data.frame()
  summ_ref <- varsel$summaries$ref
  summ_sub <- varsel$summaries$sub

  if (varsel$refmodel$family$family == "binomial" &&
      !all(varsel$d_test$weights == 1)) {
    varsel$d_test$y_prop <- varsel$d_test$y / varsel$d_test$weights
  }

  ## fetch the mu and lppd for the baseline model
  if (is.null(nfeat_baseline)) {
    ## no baseline model, i.e, compute the statistics on the actual
    ## (non-relative) scale
    mu.bs <- NULL
    lppd.bs <- NULL
    delta <- FALSE
  } else {
    if (nfeat_baseline == Inf) {
      summ.bs <- summ_ref
    } else {
      summ.bs <- summ_sub[[nfeat_baseline + 1]]
    }
    mu.bs <- summ.bs$mu
    lppd.bs <- summ.bs$lppd
    delta <- TRUE
  }

  for (s in seq_along(stats)) {
    stat <- stats[s]

    ## reference model statistics
    summ <- summ_ref
    res <- get_stat(summ$mu, summ$lppd, varsel$d_test, stat, mu.bs = mu.bs,
                    lppd.bs = lppd.bs, wcv = summ$wcv, alpha = alpha, ...)
    row <- data.frame(
      data = varsel$d_test$type, size = Inf, delta = delta, statistic = stat,
      value = res$value, lq = res$lq, uq = res$uq, se = res$se, diff = NA,
      diff.se = NA
    )
    stat_tab <- rbind(stat_tab, row)

    ## submodel statistics
    for (k in seq_along(summ_sub)) {
      summ <- summ_sub[[k]]
      if (delta == FALSE && sum(!is.na(summ_ref$mu)) > sum(!is.na(summ$mu))) {
        ## special case (subsampling loo): reference model summaries computed
        ## for more points than for the submodel, so utilize the reference model
        ## results to get more accurate statistic fot the submodel on the actual
        ## scale
        res_ref <- get_stat(summ_ref$mu, summ_ref$lppd, varsel$d_test,
                            stat, mu.bs = NULL, lppd.bs = NULL,
                            wcv = summ_ref$wcv, alpha = alpha, ...)
        res_diff <- get_stat(summ$mu, summ$lppd, varsel$d_test, stat,
                             mu.bs = summ_ref$mu, lppd.bs = summ_ref$lppd,
                             wcv = summ$wcv, alpha = alpha, ...)
        val <- res_ref$value + res_diff$value
        val.se <- sqrt(res_ref$se^2 + res_diff$se^2)
        if (stat %in% c("rmse", "auc")) {
          # TODO (subsampling LOO-CV): Use bootstrap for lower and upper
          # confidence interval bounds.
          warning("Lower and upper confidence interval bounds of performance ",
                  "statistic `", stat, "` are based on a normal ",
                  "approximation, not the bootstrap.")
        }
        lq <- qnorm(alpha / 2, mean = val, sd = val.se)
        uq <- qnorm(1 - alpha / 2, mean = val, sd = val.se)
        row <- data.frame(
          data = varsel$d_test$type, size = k - 1, delta = delta,
          statistic = stat, value = val, lq = lq, uq = uq, se = val.se,
          diff = res_diff$value, diff.se = res_diff$se
        )
      } else {
        ## normal case
        res <- get_stat(summ$mu, summ$lppd, varsel$d_test, stat, mu.bs = mu.bs,
                        lppd.bs = lppd.bs, wcv = summ$wcv, alpha = alpha, ...)
        diff <- get_stat(summ$mu, summ$lppd, varsel$d_test, stat,
                         mu.bs = summ_ref$mu, lppd.bs = summ_ref$lppd,
                         wcv = summ$wcv, alpha = alpha, ...)
        row <- data.frame(
          data = varsel$d_test$type, size = k - 1, delta = delta,
          statistic = stat, value = res$value, lq = res$lq, uq = res$uq,
          se = res$se, diff = diff$value, diff.se = diff$se
        )
      }
      stat_tab <- rbind(stat_tab, row)
    }
  }

  return(stat_tab)
}

## Calculates given statistic stat with standard error and confidence bounds.
## mu.bs and lppd.bs are the pointwise mu and lppd for another model that is
## used as a baseline for computing the difference in the given statistic,
## for example the relative elpd. If these arguments are not given (NULL) then
## the actual (non-relative) value is computed.
## NOTE: Element `wcv[i]` (with i = 1, ..., N and N denoting the number of
## observations) contains the weight of the CV fold that observation i is in. In
## case of varsel() output, this is `NULL`. Currently, these `wcv` are
## nonconstant (and not `NULL`) only in case of subsampled LOO CV. The actual
## observation weights (specified by the user) are contained in
## `d_test$weights`. These are already taken into account by
## `<refmodel_object>$family$ll_fun()` and are thus already taken into account
## in `lppd`. However, `mu` does not take them into account, so some further
## adjustments are necessary below.
get_stat <- function(mu, lppd, d_test, stat, mu.bs = NULL, lppd.bs = NULL,
                     wcv = NULL, alpha = 0.1, ...) {
  n <- length(mu)
  n_notna.bs <- NULL
  if (stat %in% c("mlpd", "elpd")) {
    n_notna <- sum(!is.na(lppd))
    if (!is.null(lppd.bs)) {
      n_notna.bs <- sum(!is.na(lppd.bs))
    }
  } else {
    n_notna <- sum(!is.na(mu) & !is.na(d_test$y_prop %||% d_test$y))
    if (!is.null(mu.bs)) {
      n_notna.bs <- sum(!is.na(mu.bs))
    }
  }
  if (n_notna == 0 || (!is.null(n_notna.bs) && n_notna.bs == 0)) {
    return(list(value = NA, se = NA, lq = NA, uq = NA))
  }

  if (is.null(wcv)) {
    ## set default CV fold weights if not given
    wcv <- rep(1, n)
  }
  ## ensure the CV fold weights sum to n_notna
  wcv <- n_notna * wcv / sum(wcv)

  alpha_half <- alpha / 2
  one_minus_alpha_half <- 1 - alpha_half
  if (stat %in% c("mlpd", "elpd")) {
    if (!is.null(lppd.bs)) {
      value <- sum((lppd - lppd.bs) * wcv, na.rm = TRUE)
      value.se <- weighted.sd(lppd - lppd.bs, wcv, na.rm = TRUE) *
        sqrt(n_notna)
    } else {
      value <- sum(lppd * wcv, na.rm = TRUE)
      value.se <- weighted.sd(lppd, wcv, na.rm = TRUE) *
        sqrt(n_notna)
    }
    if (stat == "mlpd") {
      value <- value / n_notna
      value.se <- value.se / n_notna
    }
  } else if (stat %in% c("mse", "rmse")) {
    if (is.null(d_test$y_prop)) {
      y <- d_test$y
    } else {
      y <- d_test$y_prop
    }
    if (!all(d_test$weights == 1)) {
      wcv <- wcv * d_test$weights
      wcv <- n_notna * wcv / sum(wcv)
    }
    if (stat == "mse") {
      if (!is.null(mu.bs)) {
        value <- mean(wcv * ((mu - y)^2 - (mu.bs - y)^2), na.rm = TRUE)
        value.se <- weighted.sd((mu - y)^2 - (mu.bs - y)^2, wcv,
                                na.rm = TRUE) /
          sqrt(n_notna)
      } else {
        value <- mean(wcv * (mu - y)^2, na.rm = TRUE)
        value.se <- weighted.sd((mu - y)^2, wcv, na.rm = TRUE) /
          sqrt(n_notna)
      }
    } else if (stat == "rmse") {
      if (!is.null(mu.bs)) {
        mu.bs[is.na(mu)] <- NA # compute the RMSEs using only those points
        mu[is.na(mu.bs)] <- NA # for which both mu and mu.bs are non-NA
        value <- sqrt(mean(wcv * (mu - y)^2, na.rm = TRUE)) -
          sqrt(mean(wcv * (mu.bs - y)^2, na.rm = TRUE))
        value.bootstrap1 <- bootstrap(
          (mu - y)^2,
          function(resid2) {
            sqrt(mean(wcv * resid2, na.rm = TRUE))
          },
          ...
        )
        value.bootstrap2 <- bootstrap(
          (mu.bs - y)^2,
          function(resid2) {
            sqrt(mean(wcv * resid2, na.rm = TRUE))
          },
          ...
        )
        value.se <- sd(value.bootstrap1 - value.bootstrap2)
        lq_uq <- quantile(value.bootstrap1 - value.bootstrap2,
                          probs = c(alpha_half, one_minus_alpha_half),
                          names = FALSE, na.rm = TRUE)
      } else {
        value <- sqrt(mean(wcv * (mu - y)^2, na.rm = TRUE))
        value.bootstrap <- bootstrap(
          (mu - y)^2,
          function(resid2) {
            sqrt(mean(wcv * resid2, na.rm = TRUE))
          },
          ...
        )
        value.se <- sd(value.bootstrap)
        lq_uq <- quantile(value.bootstrap,
                          probs = c(alpha_half, one_minus_alpha_half),
                          names = FALSE, na.rm = TRUE)
      }
    }
  } else if (stat %in% c("acc", "pctcorr", "auc")) {
    y <- d_test$y
    if (!is.null(d_test$y_prop)) {
      # In fact, the following stopifnot() checks should not be necessary
      # because this case should only occur for the binomial family (where
      # `d_test$weights` contains the numbers of trials) with more than 1 trial
      # for at least one observation:
      stopifnot(all(.is.wholenumber(d_test$weights)))
      stopifnot(all(.is.wholenumber(y)))
      stopifnot(all(0 <= y & y <= d_test$weights))
      y <- unlist(lapply(seq_along(y), function(i_short) {
        c(rep(0L, d_test$weights[i_short] - y[i_short]),
          rep(1L, y[i_short]))
      }))
      mu <- rep(mu, d_test$weights)
      if (!is.null(mu.bs)) {
        mu.bs <- rep(mu.bs, d_test$weights)
      }
      n_notna <- sum(d_test$weights)
      wcv <- rep(wcv, d_test$weights)
      wcv <- n_notna * wcv / sum(wcv)
    } else {
      stopifnot(all(d_test$weights == 1))
    }
    if (stat %in% c("acc", "pctcorr")) {
      if (!is.null(mu.bs)) {
        value <- mean(wcv * ((round(mu) == y) - (round(mu.bs) == y)),
                      na.rm = TRUE)
        value.se <- weighted.sd((round(mu) == y) - (round(mu.bs) == y), wcv,
                                na.rm = TRUE) /
          sqrt(n_notna)
      } else {
        value <- mean(wcv * (round(mu) == y), na.rm = TRUE)
        value.se <- weighted.sd(round(mu) == y, wcv, na.rm = TRUE) /
          sqrt(n_notna)
      }
    } else if (stat == "auc") {
      auc.data <- cbind(y, mu, wcv)
      if (!is.null(mu.bs)) {
        mu.bs[is.na(mu)] <- NA # compute the AUCs using only those points
        mu[is.na(mu.bs)] <- NA # for which both mu and mu.bs are non-NA
        auc.data.bs <- cbind(y, mu.bs, wcv)
        value <- auc(auc.data) - auc(auc.data.bs)
        value.bootstrap1 <- bootstrap(auc.data, auc, ...)
        value.bootstrap2 <- bootstrap(auc.data.bs, auc, ...)
        value.se <- sd(value.bootstrap1 - value.bootstrap2, na.rm = TRUE)
        lq_uq <- quantile(value.bootstrap1 - value.bootstrap2,
                          probs = c(alpha_half, one_minus_alpha_half),
                          names = FALSE, na.rm = TRUE)
      } else {
        value <- auc(auc.data)
        value.bootstrap <- bootstrap(auc.data, auc, ...)
        value.se <- sd(value.bootstrap, na.rm = TRUE)
        lq_uq <- quantile(value.bootstrap,
                          probs = c(alpha_half, one_minus_alpha_half),
                          names = FALSE, na.rm = TRUE)
      }
    }
  }

  if (!stat %in% c("rmse", "auc")) {
    lq <- qnorm(alpha_half, mean = value, sd = value.se)
    uq <- qnorm(one_minus_alpha_half, mean = value, sd = value.se)
  } else {
    lq <- lq_uq[1]
    uq <- lq_uq[2]
  }

  return(list(value = value, se = value.se, lq = lq, uq = uq))
}

.is_util <- function(stat) {
  ## a simple function to determine whether a given statistic (string) is
  ## a utility (we want to maximize) or loss (we want to minimize)
  ## by the time we get here, stat should have already been validated
  return(!stat %in% c("rmse", "mse"))
}

.get_nfeat_baseline <- function(object, baseline, stat) {
  ## get model size that is used as a baseline in comparisons. baseline is one
  ## of 'best' or 'ref', stat is the statistic according to which the selection
  ## is done
  if (baseline == "best") {
    ## find number of features that maximizes the utility (or minimizes the
    ## loss)
    tab <- .tabulate_stats(object, stat)
    stats_table <- subset(tab, tab$size != Inf)
    ## tab <- .tabulate_stats(object)
    ## stats_table <- subset(tab, tab$delta == FALSE &
    ##   tab$statistic == stat & tab$size != Inf)
    optfun <- ifelse(.is_util(stat), which.max, which.min)
    nfeat_baseline <- stats_table$size[optfun(stats_table$value)]
  } else {
    ## use reference model
    nfeat_baseline <- Inf
  }
  return(nfeat_baseline)
}
