# =============================================================================
# run_all.R — orchestrate the reproduction pipeline
# -----------------------------------------------------------------------------
# Usage:
#   Rscript run_all.R            # run the whole pipeline 01 -> 09 (00 setup separate)
#   Rscript run_all.R 03 04      # run only steps 03 and 04 (by number)
#   Rscript run_all.R 06 07      # H3b then H5 (needs 01,02 already cached)
#
# Each step is an independent script that reads/writes outputs/cache/*.rds, so a
# subset can be re-run without redoing the expensive data prep. Step 00 (package
# install) is intentionally NOT part of the default run — run it once by hand:
#   Rscript scripts/00_setup.R
# =============================================================================

# Resolve repo root regardless of where Rscript is invoked from.
if (!file.exists("config.R") && file.exists("reproduction/config.R")) setwd("reproduction")
source("config.R")

# Ordered registry of pipeline steps.
steps <- c(
  "01" = "scripts/01_prepare_data.R",
  "02" = "scripts/02_build_variables.R",
  "03" = "scripts/03_h1_post_attention.R",
  "04" = "scripts/04_h2_h4_reply_likelihood.R",
  "05" = "scripts/05_h3a_reply_length.R",
  "06" = "scripts/06_h3b_ssbc_ordinal.R",
  "07" = "scripts/07_h5_mediation.R",
  "08" = "scripts/08_robustness.R",
  "09" = "scripts/09_descriptives.R"
)

# Select which steps to run from the command line (default: all).
args <- commandArgs(trailingOnly = TRUE)
sel  <- if (length(args)) intersect(names(steps), args) else names(steps)
if (!length(sel)) stop("No valid steps requested. Choose from: ",
                       paste(names(steps), collapse = ", "))

cat("Running steps:", paste(sel, collapse = ", "), "\n")
t0 <- Sys.time()
for (k in sel) {
  cat(sprintf("\n========== STEP %s : %s ==========\n", k, steps[[k]]))
  st <- Sys.time()
  tryCatch(
    source(steps[[k]], local = new.env()),   # isolate each step's namespace
    error = function(e) {
      cat("  !! STEP ", k, " FAILED: ", conditionMessage(e), "\n", sep = "")
      cat("  (continuing; later steps may depend on this one)\n")
    }
  )
  cat(sprintf("  step %s took %s\n", k,
              format(round(difftime(Sys.time(), st), 1))))
}
cat(sprintf("\nPipeline finished in %s. Tables in %s/\n",
            format(round(difftime(Sys.time(), t0), 1)), TABLE_DIR))
