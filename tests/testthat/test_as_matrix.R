context("as.matrix.projection()")

test_that("as.matrix.projection() works", {
  skip_if_not(run_prj)
  for (tstsetup in names(prjs)) {
    if (args_prj[[tstsetup]]$mod_nm == "gam") {
      # Skipping GAMs because of issue #150 and issue #151. Note that for GAMs,
      # the current expectations in `test_as_matrix.R` refer to a mixture of
      # brms's and rstanarm's naming scheme; as soon as issue #152 is solved,
      # these expectations need to be adapted.
      # TODO (GAMs): Fix this.
      next
    }
    if (args_prj[[tstsetup]]$mod_nm == "gamm") {
      # Skipping GAMMs because of issue #131.
      # TODO (GAMMs): Fix this.
      next
    }
    tstsetup_ref <- args_prj[[tstsetup]]$tstsetup_ref
    mod_crr <- args_prj[[tstsetup]]$mod_nm
    fam_crr <- args_prj[[tstsetup]]$fam_nm
    pkg_crr <- args_prj[[tstsetup]]$pkg_nm
    solterms <- args_prj[[tstsetup]]$solution_terms
    ndr_ncl <- ndr_ncl_dtls(args_prj[[tstsetup]])

    # Expected warning (more precisely: regexp which is matched against the
    # warning; NA means no warning) for as.matrix.projection():
    if (ndr_ncl$clust_used) {
      # Clustered projection, so we expect a warning:
      warn_prjmat_expect <- "the clusters might have different weights"
    } else {
      warn_prjmat_expect <- NA
    }
    expect_warning(m <- as.matrix(prjs[[tstsetup]]),
                   warn_prjmat_expect, info = tstsetup)

    if (fam_crr == "gauss") {
      npars_fam <- "sigma"
    } else {
      npars_fam <- character()
    }

    icpt_nm <- "Intercept"
    if (pkg_crr == "rstanarm") {
      icpt_nm <- paste0("(", icpt_nm, ")")
    }
    colnms_prjmat_expect <- c(
      icpt_nm,
      grep("\\|", grep("x(co|ca)\\.[[:digit:]]", solterms, value = TRUE),
           value = TRUE, invert = TRUE)
    )
    xca_idxs <- as.integer(
      sub("^xca\\.", "", grep("^xca\\.", colnms_prjmat_expect, value = TRUE))
    )
    for (xca_idx in xca_idxs) {
      colnms_prjmat_expect <- grep(paste0("^xca\\.", xca_idx, "$"),
                                   colnms_prjmat_expect,
                                   value = TRUE, invert = TRUE)
      colnms_prjmat_expect <- c(
        colnms_prjmat_expect,
        paste0("xca.", xca_idx, "lvl", seq_len(nlvl_fix[xca_idx])[-1])
      )
    }
    poly_trms <- grep("poly\\(.*\\)", colnms_prjmat_expect, value = TRUE)
    if (length(poly_trms) > 0) {
      poly_degree <- sub(".*(poly\\(.*\\)).*", "\\1", poly_trms)
      if (length(unique(poly_degree)) != 1) {
        stop("This test needs to be adapted. Info: ", tstsetup)
      }
      poly_degree <- unique(poly_degree)
      poly_degree <- sub(".*,[[:blank:]]+(.*)\\)", "\\1", poly_degree)
      poly_degree <- as.integer(poly_degree)
      colnms_prjmat_expect <- c(
        setdiff(colnms_prjmat_expect, poly_trms),
        unlist(lapply(poly_trms, function(poly_trms_i) {
          paste0(poly_trms_i, seq_len(poly_degree))
        }))
      )
    }
    if (pkg_crr == "brms") {
      colnms_prjmat_expect <- paste0("b_", colnms_prjmat_expect)
    }
    if ("(1 | z.1)" %in% solterms) {
      if (pkg_crr == "brms") {
        colnms_prjmat_expect <- c(colnms_prjmat_expect, "sd_z.1__Intercept")
        colnms_prjmat_expect <- c(
          colnms_prjmat_expect,
          paste0("r_z.1[lvl", seq_len(nlvl_ran[1]), ",Intercept]")
        )
      } else if (pkg_crr == "rstanarm") {
        colnms_prjmat_expect <- c(colnms_prjmat_expect,
                                  "Sigma[z.1:(Intercept),(Intercept)]")
        colnms_prjmat_expect <- c(
          colnms_prjmat_expect,
          paste0("b[(Intercept) z.1:lvl", seq_len(nlvl_ran[1]), "]")
        )
      }
    }
    if ("(xco.1 | z.1)" %in% solterms) {
      if (pkg_crr == "brms") {
        colnms_prjmat_expect <- c(colnms_prjmat_expect, "sd_z.1__xco.1")
        colnms_prjmat_expect <- c(
          colnms_prjmat_expect,
          paste0("r_z.1[lvl", seq_len(nlvl_ran[1]), ",xco.1]")
        )
      } else if (pkg_crr == "rstanarm") {
        colnms_prjmat_expect <- c(colnms_prjmat_expect,
                                  "Sigma[z.1:xco.1,xco.1]")
        colnms_prjmat_expect <- c(
          colnms_prjmat_expect,
          paste0("b[xco.1 z.1:lvl", seq_len(nlvl_ran[1]), "]")
        )
      }
    }
    if (all(c("(1 | z.1)", "(xco.1 | z.1)") %in% solterms)) {
      if (pkg_crr == "brms") {
        colnms_prjmat_expect <- c(colnms_prjmat_expect,
                                  "cor_z.1__Intercept__xco.1")
      } else if (pkg_crr == "rstanarm") {
        colnms_prjmat_expect <- c(colnms_prjmat_expect,
                                  "Sigma[z.1:xco.1,(Intercept)]")
      }
    }
    s_nms <- sub("\\)$", "",
                 sub("^s\\(", "",
                     grep("^s\\(.*\\)$", solterms, value = TRUE)))
    if (length(s_nms) > 0) {
      stopifnot(inherits(refmods[[tstsetup_ref]]$fit, "stanreg"))
      # Get the number of basis coefficients:
      s_info <- refmods[[tstsetup_ref]]$fit$jam$smooth
      s_terms <- sapply(s_info, "[[", "term")
      s_dfs <- setNames(sapply(s_info, "[[", "df"), s_terms)
      ### Alternative:
      # par_nms_orig <- colnames(
      #   as.matrix(refmods[[tstsetup_ref]]$fit)
      # )
      # s_dfs <- sapply(s_nms, function(s_nm) {
      #   sum(grepl(paste0("^s\\(", s_nm, "\\)"), par_nms_orig))
      # })
      ###
      # Construct the expected column names for the basis coefficients:
      for (s_nm in s_nms) {
        colnms_prjmat_expect <- c(
          colnms_prjmat_expect,
          paste0("b_s(", s_nm, ").", seq_len(s_dfs[s_nm]))
        )
      }
      # Needed for the names of the `smooth_sd` parameters:
      s_nsds <- setNames(
        lapply(lapply(s_info, "[[", "sp"), names),
        s_terms
      )
      # Construct the expected column names for the SDs of the smoothing
      # terms:
      for (s_nm in s_nms) {
        colnms_prjmat_expect <- c(
          colnms_prjmat_expect,
          paste0("smooth_sd[", s_nsds[[s_nm]], "]")
        )
      }
    }
    colnms_prjmat_expect <- c(colnms_prjmat_expect, npars_fam)

    expect_identical(dim(m), c(ndr_ncl$nprjdraws, length(colnms_prjmat_expect)),
                     info = tstsetup)
    ### expect_setequal() does not have argument `info`:
    # expect_setequal(colnames(m), colnms_prjmat_expect)
    expect_true(setequal(colnames(m), colnms_prjmat_expect),
                info = tstsetup)
    ###
    if (run_snaps) {
      if (testthat_ed_max2) local_edition(3)
      width_orig <- options(width = 145)
      expect_snapshot({
        print(tstsetup)
        print(rlang::hash(m)) # cat(m)
      })
      options(width_orig)
      if (testthat_ed_max2) local_edition(2)
    }
  }
})

if (run_snaps) {
  if (testthat_ed_max2) local_edition(3)
  width_orig <- options(width = 145)

  test_that(paste(
    "as.matrix.projection() works for projections based on varsel() output"
  ), {
    skip_if_not(run_vs)
    for (tstsetup in names(prjs_vs)) {
      if (args_prj_vs[[tstsetup]]$mod_nm == "gam") {
        # Skipping GAMs because of issue #150 and issue #151. Note that for
        # GAMs, the current expectations in `test_as_matrix.R` refer to a
        # mixture of brms's and rstanarm's naming scheme; as soon as issue #152
        # is solved, these expectations need to be adapted.
        # TODO (GAMs): Fix this.
        next
      }
      if (args_prj_vs[[tstsetup]]$mod_nm == "gamm") {
        # Skipping GAMMs because of issue #131.
        # TODO (GAMMs): Fix this.
        next
      }
      ndr_ncl <- ndr_ncl_dtls(args_prj_vs[[tstsetup]])
      nterms_crr <- args_prj_vs[[tstsetup]]$nterms

      # Expected warning (more precisely: regexp which is matched against the
      # warning; NA means no warning) for as.matrix.projection():
      if (ndr_ncl$clust_used) {
        # Clustered projection, so we expect a warning:
        warn_prjmat_expect <- "the clusters might have different weights"
      } else {
        warn_prjmat_expect <- NA
      }
      prjs_vs_l <- prjs_vs[[tstsetup]]
      if (length(nterms_crr) <= 1) {
        prjs_vs_l <- list(prjs_vs_l)
      }
      res_vs <- lapply(prjs_vs_l, function(prjs_vs_i) {
        expect_warning(m <- as.matrix(prjs_vs_i),
                       warn_prjmat_expect, info = tstsetup)
        expect_snapshot({
          print(tstsetup)
          print(prjs_vs_i$solution_terms)
          print(rlang::hash(m)) # cat(m)
        })
        return(invisible(TRUE))
      })
    }
  })

  test_that(paste(
    "as.matrix.projection() works for projections based on cv_varsel() output"
  ), {
    skip_if_not(run_cvvs)
    for (tstsetup in names(prjs_cvvs)) {
      if (args_prj_cvvs[[tstsetup]]$mod_nm == "gam") {
        # Skipping GAMs because of issue #150 and issue #151. Note that for
        # GAMs, the current expectations in `test_as_matrix.R` refer to a
        # mixture of brms's and rstanarm's naming scheme; as soon as issue #152
        # is solved, these expectations need to be adapted.
        # TODO (GAMs): Fix this.
        next
      }
      if (args_prj_cvvs[[tstsetup]]$mod_nm == "gamm") {
        # Skipping GAMMs because of issue #131.
        # TODO (GAMMs): Fix this.
        next
      }
      ndr_ncl <- ndr_ncl_dtls(args_prj_cvvs[[tstsetup]])
      nterms_crr <- args_prj_cvvs[[tstsetup]]$nterms

      # Expected warning (more precisely: regexp which is matched against the
      # warning; NA means no warning) for as.matrix.projection():
      if (ndr_ncl$clust_used) {
        # Clustered projection, so we expect a warning:
        warn_prjmat_expect <- "the clusters might have different weights"
      } else {
        warn_prjmat_expect <- NA
      }
      prjs_cvvs_l <- prjs_cvvs[[tstsetup]]
      if (length(nterms_crr) <= 1) {
        prjs_cvvs_l <- list(prjs_cvvs_l)
      }
      res_cvvs <- lapply(prjs_cvvs_l, function(prjs_cvvs_i) {
        expect_warning(m <- as.matrix(prjs_cvvs_i),
                       warn_prjmat_expect, info = tstsetup)
        expect_snapshot({
          print(tstsetup)
          print(prjs_cvvs_i$solution_terms)
          print(rlang::hash(m)) # cat(m)
        })
        return(invisible(TRUE))
      })
    }
  })

  options(width_orig)
  if (testthat_ed_max2) local_edition(2)
}
