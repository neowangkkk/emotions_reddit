# =============================================================================
# 00_setup.R — install/load packages, record the environment
# -----------------------------------------------------------------------------
# Run once on a fresh machine:  Rscript scripts/00_setup.R
# Idempotent: only installs what's missing. Writes outputs/sessioninfo.txt so the
# exact package versions used for a run are part of the reproduction record.
# =============================================================================

setwd_to_repo_root <- function() {
  # Allow running from either reproduction/ or reproduction/scripts/.
  if (file.exists("config.R")) return(invisible())
  if (file.exists("../config.R")) setwd("..")
}
setwd_to_repo_root()
source("config.R")

# --- packages ----------------------------------------------------------------
# Grouped by role so it is obvious what each is for.
pkgs <- c(
  # data wrangling
  "dplyr", "readr", "tidyr", "stringr", "lubridate",
  # modelling
  "MASS",            # polr() proportional-odds ordinal logit (H3b)
  "sampleSelection", # heckit()/invMillsRatio() (Heckman selection -> IMR1)
  # inference / robustness
  "sandwich", "lmtest",  # cluster-robust SEs (revision program)
  # tidy output
  "broom", "tibble",
  # optional / exploratory
  "logistf"          # Firth logistic (legacy Logit2025.R; not the main models)
)

installed <- rownames(installed.packages())
to_install <- setdiff(pkgs, installed)
if (length(to_install)) {
  message("Installing: ", paste(to_install, collapse = ", "))
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("All required packages already installed.")
}

# Load (and fail loudly if a core one is unavailable).
core <- c("dplyr", "readr", "tidyr", "MASS", "sandwich", "lmtest")
invisible(lapply(core, function(p)
  if (!requireNamespace(p, quietly = TRUE))
    stop("Core package not available: ", p)))

# --- record environment ------------------------------------------------------
si_path <- file.path(OUTPUT_DIR, "sessioninfo.txt")
writeLines(capture.output(sessionInfo()), si_path)
message("Wrote ", si_path)
message("Setup complete.")
