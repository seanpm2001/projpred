% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/projpred-package.R
\docType{package}
\name{projpred-package}
\alias{projpred}
\alias{projpred-package}
\title{Projection predictive feature selection}
\description{
The \R package \pkg{projpred} performs the projection predictive variable (or
"feature") selection for various regression models. We recommend to read the
\code{README} file (available with enhanced formatting
\href{https://mc-stan.org/projpred/}{online}) and the main vignette (\code{topic = "projpred"}, but also available
\href{https://mc-stan.org/projpred/articles/projpred.html}{online}) before
continuing here.

Throughout the whole package documentation, we use the term "submodel" for
all kinds of candidate models onto which the reference model is projected.
For custom reference models, the candidate models don't need to be actual
\emph{sub}models of the reference model, but in any case (even for custom
reference models), the candidate models are always actual \emph{sub}models of the
full \code{\link{formula}} used by the search procedure. In this regard, it is correct
to speak of \emph{sub}models, even in case of a custom reference model.

The following model type abbreviations will be used at multiple places
throughout the documentation: GLM (generalized linear model), GLMM
(generalized linear multilevel---or "mixed"---model), GAM (generalized
additive model), and GAMM (generalized additive multilevel---or
"mixed"---model). Note that the term "generalized" includes the Gaussian
family as well.

For the projection of the reference model onto a submodel, \pkg{projpred}
currently relies on the following functions (in other words, these are the
workhorse functions used by the default divergence minimizer):
\itemize{
\item Submodel without multilevel or additive terms: An internal C++ function
which basically serves the same purpose as \code{\link[=lm]{lm()}} for the \code{\link[=gaussian]{gaussian()}} family
and \code{\link[=glm]{glm()}} for all other families.
\item Submodel with multilevel but no additive terms: \code{\link[lme4:lmer]{lme4::lmer()}} for the
\code{\link[=gaussian]{gaussian()}} family, \code{\link[lme4:glmer]{lme4::glmer()}} for all other families.
\item Submodel without multilevel but additive terms: \code{\link[mgcv:gam]{mgcv::gam()}}.
\item Submodel with multilevel and additive terms: \code{\link[gamm4:gamm4]{gamm4::gamm4()}}.
}

The projection of the reference model onto a submodel can be run on multiple
CPU cores in parallel (across the projected draws). This is powered by the
\pkg{foreach} package. Thus, any parallel (or sequential) backend compatible
with \pkg{foreach} can be used, e.g., the backends from packages
\pkg{doParallel}, \pkg{doMPI}, or \pkg{doFuture}. Using the global option
\code{projpred.prll_prj_trigger}, the number of projected draws below which no
parallelization is applied (even if a parallel backend is registered) can be
modified. Such a "trigger" threshold exists because of the computational
overhead of a parallelization which makes parallelization only useful for a
sufficiently large number of projected draws. By default, parallelization is
turned off, which can also be achieved by supplying \code{Inf} (or \code{NULL}) to
option \code{projpred.prll_prj_trigger}. Note that we cannot recommend
parallelizing the projection on Windows because in our experience, the
parallelization overhead is larger there, causing a parallel run to take
longer than a sequential run. Also note that the parallelization works well
for GLMs, but for GLMMs, GAMs, and GAMMs, the fitted model objects are quite
big, which---when running in parallel---may lead to an excessive memory usage
which in turn may crash the R session. Thus, we currently cannot recommend
the parallelization for GLMMs, GAMs, and GAMMs.
}
\section{Functions}{
\describe{
\item{\code{\link[=init_refmodel]{init_refmodel()}}, \code{\link[=get_refmodel]{get_refmodel()}}}{For setting up an object
containing information about the reference model, the submodels, and how
the projection should be carried out. Explicit calls to \code{\link[=init_refmodel]{init_refmodel()}}
and \code{\link[=get_refmodel]{get_refmodel()}} are only rarely needed.}
\item{\code{\link[=varsel]{varsel()}}, \code{\link[=cv_varsel]{cv_varsel()}}}{For running the \emph{search} part and the
\emph{evaluation} part for a projection predictive variable selection, possibly
with cross-validation (CV).}
\item{\code{\link[=summary.vsel]{summary.vsel()}}, \code{\link[=print.vsel]{print.vsel()}}, \code{\link[=plot.vsel]{plot.vsel()}},
\code{\link[=suggest_size.vsel]{suggest_size.vsel()}}, \code{\link[=solution_terms.vsel]{solution_terms.vsel()}}}{For post-processing the
results from \code{\link[=varsel]{varsel()}} and \code{\link[=cv_varsel]{cv_varsel()}}.}
\item{\code{\link[=project]{project()}}}{For projecting the reference model onto submodel(s).
Typically, this follows the variable selection, but it can also be applied
directly (without a variable selection).}
\item{\code{\link[=as.matrix.projection]{as.matrix.projection()}}}{For extracting projected parameter draws.}
\item{\code{\link[=proj_linpred]{proj_linpred()}}, \code{\link[=proj_predict]{proj_predict()}}}{For making predictions from a
submodel (after projecting the reference model onto it).}
}
}

\seealso{
Useful links:
\itemize{
  \item \url{https://mc-stan.org/projpred/}
  \item \url{https://discourse.mc-stan.org}
  \item Report bugs at \url{https://github.com/stan-dev/projpred/issues/}
}

}
\author{
\strong{Maintainer}: Frank Weber \email{fweber144@protonmail.com}

Authors:
\itemize{
  \item Juho Piironen \email{juho.t.piironen@gmail.com}
  \item Markus Paasiniemi
  \item Alejandro Catalina \email{alecatfel@gmail.com}
  \item Aki Vehtari
}

Other contributors:
\itemize{
  \item Jonah Gabry [contributor]
  \item Marco Colombo [contributor]
  \item Paul-Christian Bürkner [contributor]
  \item Hamada S. Badr [contributor]
  \item Brian Sullivan [contributor]
  \item Sölvi Rögnvaldsson [contributor]
}

}
