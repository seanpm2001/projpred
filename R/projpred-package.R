#' Projection predictive feature selection
#'
#' @useDynLib projpred
#' @importFrom Rcpp sourceCpp
#'
#' @import stats
#' @import ggplot2
#' @importFrom rlang .data
#' @importFrom rstantools posterior_linpred
#' @importFrom loo kfold
#'
#' @description
#'
#' The \R package \pkg{projpred} performs the projection predictive variable (or
#' "feature") selection for various regression models. We recommend to read the
#' `README` file (available with enhanced formatting
#' [online](https://mc-stan.org/projpred/)) and the main vignette (`topic =
#' "projpred"`, but also available
#' [online](https://mc-stan.org/projpred/articles/projpred.html)) before
#' continuing here.
#'
#' Throughout the whole package documentation, we use the term "submodel" for
#' all kinds of candidate models onto which the reference model is projected.
#' For custom reference models, the candidate models don't need to be actual
#' *sub*models of the reference model, but in any case (even for custom
#' reference models), the candidate models are always actual *sub*models of the
#' full [`formula`] used by the search procedure. In this regard, it is correct
#' to speak of *sub*models, even in case of a custom reference model.
#'
#' The following model type abbreviations will be used at multiple places
#' throughout the documentation: GLM (generalized linear model), GLMM
#' (generalized linear multilevel---or "mixed"---model), GAM (generalized
#' additive model), and GAMM (generalized additive multilevel---or
#' "mixed"---model). Note that the term "generalized" includes the Gaussian
#' family as well.
#'
#' For the projection of the reference model onto a submodel, \pkg{projpred}
#' currently relies on the following functions (in other words, these are the
#' workhorse functions used by the default divergence minimizer):
#' * Submodel without multilevel or additive terms: An internal C++ function
#' which basically serves the same purpose as [lm()] for the [gaussian()] family
#' and [glm()] for all other families.
#' * Submodel with multilevel but no additive terms: [lme4::lmer()] for the
#' [gaussian()] family, [lme4::glmer()] for all other families.
#' * Submodel without multilevel but additive terms: [mgcv::gam()].
#' * Submodel with multilevel and additive terms: [gamm4::gamm4()].
#'
#' The projection of the reference model onto a submodel can be run on multiple
#' CPU cores in parallel (across the projected draws). This is powered by the
#' \pkg{foreach} package. Thus, any parallel (or sequential) backend compatible
#' with \pkg{foreach} can be used, e.g., the backends from packages
#' \pkg{doParallel}, \pkg{doMPI}, or \pkg{doFuture}. Using the global option
#' `projpred.prll_prj_trigger`, the number of projected draws below which no
#' parallelization is applied (even if a parallel backend is registered) can be
#' modified. Such a "trigger" threshold exists because of the computational
#' overhead of a parallelization which makes parallelization only useful for a
#' sufficiently large number of projected draws. By default, parallelization is
#' turned off, which can also be achieved by supplying `Inf` (or `NULL`) to
#' option `projpred.prll_prj_trigger`. Note that we cannot recommend
#' parallelizing the projection on Windows because in our experience, the
#' parallelization overhead is larger there, causing a parallel run to take
#' longer than a sequential run. Also note that the parallelization works well
#' for GLMs, but for GLMMs, GAMs, and GAMMs, the fitted model objects are quite
#' big, which---when running in parallel---may lead to an excessive memory usage
#' which in turn may crash the R session. Thus, we currently cannot recommend
#' the parallelization for GLMMs, GAMs, and GAMMs.
#'
#' @details
#'
#' # Functions
#'
#' \describe{
#'   \item{[init_refmodel()], [get_refmodel()]}{For setting up an object
#'   containing information about the reference model, the submodels, and how
#'   the projection should be carried out. Explicit calls to [init_refmodel()]
#'   and [get_refmodel()] are only rarely needed.}
#'   \item{[varsel()], [cv_varsel()]}{For running the *search* part and the
#'   *evaluation* part for a projection predictive variable selection, possibly
#'   with cross-validation (CV).}
#'   \item{[summary.vsel()], [print.vsel()], [plot.vsel()],
#'   [suggest_size.vsel()], [solution_terms.vsel()]}{For post-processing the
#'   results from [varsel()] and [cv_varsel()].}
#'   \item{[project()]}{For projecting the reference model onto submodel(s).
#'   Typically, this follows the variable selection, but it can also be applied
#'   directly (without a variable selection).}
#'   \item{[as.matrix.projection()]}{For extracting projected parameter draws.}
#'   \item{[proj_linpred()], [proj_predict()]}{For making predictions from a
#'   submodel (after projecting the reference model onto it).}
#' }
#'
"_PACKAGE"
