% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cv_varsel.R
\name{cv_varsel}
\alias{cv_varsel}
\alias{cv_varsel.default}
\alias{cv_varsel.refmodel}
\title{Variable selection with cross-validation}
\usage{
cv_varsel(object, ...)

\method{cv_varsel}{default}(object, ...)

\method{cv_varsel}{refmodel}(
  object,
  method = NULL,
  cv_method = if (!inherits(object, "datafit")) "LOO" else "kfold",
  ndraws = NULL,
  nclusters = 20,
  ndraws_pred = 400,
  nclusters_pred = NULL,
  refit_prj = !inherits(object, "datafit"),
  nterms_max = NULL,
  penalty = NULL,
  verbose = TRUE,
  nloo = NULL,
  K = if (!inherits(object, "datafit")) 5 else 10,
  lambda_min_ratio = 1e-05,
  nlambda = 150,
  thresh = 1e-06,
  regul = 1e-04,
  validate_search = TRUE,
  seed = sample.int(.Machine$integer.max, 1),
  search_terms = NULL,
  ...
)
}
\arguments{
\item{object}{An object of class \code{refmodel} (returned by \code{\link[=get_refmodel]{get_refmodel()}} or
\code{\link[=init_refmodel]{init_refmodel()}}) or an object that can be passed to argument \code{object} of
\code{\link[=get_refmodel]{get_refmodel()}}.}

\item{...}{Arguments passed to \code{\link[=get_refmodel]{get_refmodel()}} as well as to the divergence
minimizer (during a forward search and also during the evaluation part, but
the latter only if \code{refit_prj} is \code{TRUE}).}

\item{method}{The method for the search part. Possible options are \code{"L1"} for
L1 search and \code{"forward"} for forward search. If \code{NULL}, then internally,
\code{"L1"} is used, except if the reference model has multilevel or additive
terms or if \code{!is.null(search_terms)}. See also section "Details" below.}

\item{cv_method}{The CV method, either \code{"LOO"} or \code{"kfold"}. In the \code{"LOO"}
case, a Pareto-smoothed importance sampling leave-one-out CV (PSIS-LOO CV)
is performed, which avoids refitting the reference model \code{nloo} times (in
contrast to a standard LOO CV). In the \code{"kfold"} case, a \eqn{K}-fold CV is
performed.}

\item{ndraws}{Number of posterior draws used in the search part. Ignored if
\code{nclusters} is not \code{NULL} or in case of L1 search (because L1 search always
uses a single cluster). If both (\code{nclusters} and \code{ndraws}) are \code{NULL}, the
number of posterior draws from the reference model is used for \code{ndraws}.
See also section "Details" below.}

\item{nclusters}{Number of clusters of posterior draws used in the search
part. Ignored in case of L1 search (because L1 search always uses a single
cluster). For the meaning of \code{NULL}, see argument \code{ndraws}. See also
section "Details" below.}

\item{ndraws_pred}{Only relevant if \code{refit_prj} is \code{TRUE}. Number of
posterior draws used in the evaluation part. Ignored if \code{nclusters_pred} is
not \code{NULL}. If both (\code{nclusters_pred} and \code{ndraws_pred}) are \code{NULL}, the
number of posterior draws from the reference model is used for
\code{ndraws_pred}. See also section "Details" below.}

\item{nclusters_pred}{Only relevant if \code{refit_prj} is \code{TRUE}. Number of
clusters of posterior draws used in the evaluation part. For the meaning of
\code{NULL}, see argument \code{ndraws_pred}. See also section "Details" below.}

\item{refit_prj}{A single logical value indicating whether to fit the
submodels along the solution path again (\code{TRUE}) or to retrieve their fits
from the search part (\code{FALSE}) before using those (re-)fits in the
evaluation part.}

\item{nterms_max}{Maximum number of predictor terms until which the search is
continued. If \code{NULL}, then \code{min(19, D)} is used where \code{D} is the number of
terms in the reference model (or in \code{search_terms}, if supplied). Note that
\code{nterms_max} does not count the intercept, so use \code{nterms_max = 0} for the
intercept-only model. (Correspondingly, \code{D} above does not count the
intercept.)}

\item{penalty}{Only relevant for L1 search. A numeric vector determining the
relative penalties or costs for the predictors. A value of \code{0} means that
those predictors have no cost and will therefore be selected first, whereas
\code{Inf} means those predictors will never be selected. If \code{NULL}, then \code{1} is
used for each predictor.}

\item{verbose}{A single logical value indicating whether to print out
additional information during the computations.}

\item{nloo}{\strong{Caution:} Still experimental. Only relevant if \code{cv_method = "LOO"}. Number of subsampled LOO CV folds, i.e., number of observations
used for the LOO CV (anything between 1 and the original number of
observations). Smaller values lead to faster computation but higher
uncertainty in the evaluation part. If \code{NULL}, all observations are used,
but for faster experimentation, one can set this to a smaller value.}

\item{K}{Only relevant if \code{cv_method = "kfold"} and if the reference model
was created with \code{cvfits} being \code{NULL} (which is the case for
\code{\link[=get_refmodel.stanreg]{get_refmodel.stanreg()}} and \code{\link[brms:get_refmodel.brmsfit]{brms::get_refmodel.brmsfit()}}). Number of
folds in \eqn{K}-fold CV.}

\item{lambda_min_ratio}{Only relevant for L1 search. Ratio between the
smallest and largest lambda in the L1-penalized search. This parameter
essentially determines how long the search is carried out, i.e., how large
submodels are explored. No need to change this unless the program gives a
warning about this.}

\item{nlambda}{Only relevant for L1 search. Number of values in the lambda
grid for L1-penalized search. No need to change this unless the program
gives a warning about this.}

\item{thresh}{Only relevant for L1 search. Convergence threshold when
computing the L1 path. Usually, there is no need to change this.}

\item{regul}{A number giving the amount of ridge regularization when
projecting onto (i.e., fitting) submodels which are GLMs. Usually there is
no need for regularization, but sometimes we need to add some
regularization to avoid numerical problems.}

\item{validate_search}{Only relevant if \code{cv_method = "LOO"}. A single logical
value indicating whether to cross-validate also the search part, i.e.,
whether to run the search separately for each CV fold (\code{TRUE}) or not
(\code{FALSE}). We strongly do not recommend setting this to \code{FALSE}, because
this is known to bias the predictive performance estimates of the selected
submodels. However, setting this to \code{FALSE} can sometimes be useful because
comparing the results to the case where this argument is \code{TRUE} gives an
idea of how strongly the variable selection is (over-)fitted to the data
(the difference corresponds to the search degrees of freedom or the
effective number of parameters introduced by the search).}

\item{seed}{Pseudorandom number generation (PRNG) seed by which the same
results can be obtained again if needed. Passed to argument \code{seed} of
\code{\link[=set.seed]{set.seed()}}, but can also be \code{NA} to not call \code{\link[=set.seed]{set.seed()}} at all. Here,
this seed is used for clustering the reference model's posterior draws (if
\code{!is.null(nclusters)} or \code{!is.null(nclusters_pred)}), for subsampling LOO
CV folds (if \code{nloo} is smaller than the number of observations), for
sampling the folds in K-fold CV, and for drawing new group-level effects
when predicting from a multilevel submodel (however, not yet in case of a
GAMM).}

\item{search_terms}{Only relevant for forward search. A custom character
vector of predictor term blocks to consider for the search. Section
"Details" below describes more precisely what "predictor term block" means.
The intercept (\code{"1"}) is always included internally via \code{union()}, so
there's no difference between including it explicitly or omitting it. The
default \code{search_terms} considers all the terms in the reference model's
formula.}
}
\value{
An object of class \code{vsel}. The elements of this object are not meant
to be accessed directly but instead via helper functions (see the main
vignette and \link{projpred-package}).
}
\description{
Run the \emph{search} part and the \emph{evaluation} part for a projection predictive
variable selection. The search part determines the solution path, i.e., the
best submodel for each submodel size (number of predictor terms). The
evaluation part determines the predictive performance of the submodels along
the solution path. In contrast to \code{\link[=varsel]{varsel()}}, \code{\link[=cv_varsel]{cv_varsel()}} performs a
cross-validation (CV) by running the search part with the training data of
each CV fold separately (an exception is explained in section "Note" below)
and running the evaluation part on the corresponding test set of each CV
fold.
}
\details{
Arguments \code{ndraws}, \code{nclusters}, \code{nclusters_pred}, and \code{ndraws_pred}
are automatically truncated at the number of posterior draws in the
reference model (which is \code{1} for \code{datafit}s). Using less draws or clusters
in \code{ndraws}, \code{nclusters}, \code{nclusters_pred}, or \code{ndraws_pred} than posterior
draws in the reference model may result in slightly inaccurate projection
performance. Increasing these arguments affects the computation time
linearly.

For argument \code{method}, there are some restrictions: For a reference model
with multilevel or additive formula terms, only the forward search is
available. Furthermore, argument \code{search_terms} requires a forward search
to take effect.

L1 search is faster than forward search, but forward search may be more
accurate. Furthermore, forward search may find a sparser model with
comparable performance to that found by L1 search, but it may also start
overfitting when more predictors are added.

An L1 search may select interaction terms before the corresponding main
terms are selected. If this is undesired, choose the forward search
instead.

The elements of the \code{search_terms} character vector don't need to be
individual predictor terms. Instead, they can be building blocks consisting
of several predictor terms connected by the \code{+} symbol. To understand how
these building blocks work, it is important to know how \pkg{projpred}'s
forward search works: It starts with an empty vector \code{chosen} which will
later contain already selected predictor terms. Then, the search iterates
over model sizes \eqn{j \in \{1, ..., J\}}{j = 1, ..., J}. The candidate
models at model size \eqn{j} are constructed from those elements from
\code{search_terms} which yield model size \eqn{j} when combined with the
\code{chosen} predictor terms. Note that sometimes, there may be no candidate
models for model size \eqn{j}. Also note that internally, \code{search_terms} is
expanded to include the intercept (\code{"1"}), so the first step of the search
(model size 1) always consists of the intercept-only model as the only
candidate.

As a \code{search_terms} example, consider a reference model with formula \code{y ~ x1 + x2 + x3}. Then, to ensure that \code{x1} is always included in the
candidate models, specify \code{search_terms = c("x1", "x1 + x2", "x1 + x3", "x1 + x2 + x3")}. This search would start with \code{y ~ 1} as the only
candidate at model size 1. At model size 2, \code{y ~ x1} would be the only
candidate. At model size 3, \code{y ~ x1 + x2} and \code{y ~ x1 + x3} would be the
two candidates. At the last model size of 4, \code{y ~ x1 + x2 + x3} would be
the only candidate. As another example, to exclude \code{x1} from the search,
specify \code{search_terms = c("x2", "x3", "x2 + x3")}.
}
\note{
The case \code{cv_method == "LOO" && !validate_search} constitutes an
exception where the search part is not cross-validated. In that case, the
evaluation part is based on a PSIS-LOO CV also for the submodels.

For all PSIS-LOO CVs, \pkg{projpred} calls \code{\link[loo:psis]{loo::psis()}} with \code{r_eff = NA}.
This is only a problem if there was extreme autocorrelation between the
MCMC iterations when the reference model was built. In those cases however,
the reference model should not have been used anyway, so we don't expect
\pkg{projpred}'s \code{r_eff = NA} to be a problem.
}
\examples{
\dontshow{if (identical(Sys.getenv("RUN_EX"), "true")) (if (getRversion() >= "3.4") withAutoprint else force)(\{ # examplesIf}
# Note: The code from this example is not executed when called via example().
# To execute it, you have to copy and paste it manually to the console.
if (requireNamespace("rstanarm", quietly = TRUE)) {
  # Data:
  dat_gauss <- data.frame(y = df_gaussian$y, df_gaussian$x)

  # The "stanreg" fit which will be used as the reference model (with small
  # values for `chains` and `iter`, but only for technical reasons in this
  # example; this is not recommended in general):
  fit <- rstanarm::stan_glm(
    y ~ X1 + X2 + X3 + X4 + X5, family = gaussian(), data = dat_gauss,
    QR = TRUE, chains = 2, iter = 500, refresh = 0, seed = 9876
  )

  # Variable selection with cross-validation (with small values
  # for `nterms_max`, `nclusters`, and `nclusters_pred`, but only for the
  # sake of speed in this example; this is not recommended in general):
  cvvs <- cv_varsel(fit, nterms_max = 3, nclusters = 5, nclusters_pred = 10,
                    seed = 5555)
  # Now see, for example, `?print.vsel`, `?plot.vsel`, `?suggest_size.vsel`,
  # and `?solution_terms.vsel` for possible post-processing functions.
}
\dontshow{\}) # examplesIf}
}
\references{
Magnusson, Måns, Michael Andersen, Johan Jonasson, and Aki Vehtari. 2019.
"Bayesian Leave-One-Out Cross-Validation for Large Data." In \emph{Proceedings of
the 36th International Conference on Machine Learning}, edited by Kamalika
Chaudhuri and Ruslan Salakhutdinov, 97:4244--53. Proceedings of Machine
Learning Research. PMLR.
\url{https://proceedings.mlr.press/v97/magnusson19a.html}.

Vehtari, Aki, Andrew Gelman, and Jonah Gabry. 2017. "Practical Bayesian Model
Evaluation Using Leave-One-Out Cross-Validation and WAIC." \emph{Statistics and
Computing} 27 (5): 1413--32. \doi{10.1007/s11222-016-9696-4}.

Vehtari, Aki, Daniel Simpson, Andrew Gelman, Yuling Yao, and Jonah Gabry.
2022. "Pareto Smoothed Importance Sampling." arXiv.
\doi{10.48550/arXiv.1507.02646}.
}
\seealso{
\code{\link[=varsel]{varsel()}}
}
