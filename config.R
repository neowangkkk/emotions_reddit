# =============================================================================
# config.R — central configuration for the reproduction pipeline
# -----------------------------------------------------------------------------
# Everything that changes between machines or runs lives here. No analysis logic.
# Sourced at the top of every script via:  source("config.R")  (or ../config.R)
# =============================================================================

# --- Paths -------------------------------------------------------------------
# DATA_DIR: folder holding the large .rds inputs (NOT committed; see DATA.md).
# Edit this to point at wherever MyDataLogit.rds etc. live on your machine.
# Cluster example: "/scratch/w/wangtaow/wangtaow/Data"
# Local example:   "~/Documents/ETM_output"
DATA_DIR    <- Sys.getenv("HAAS_DATA_DIR", unset = "../ETM_output")

# Where this pipeline writes results. Created if missing.
OUTPUT_DIR  <- "outputs"
TABLE_DIR   <- file.path(OUTPUT_DIR, "tables")
FIGURE_DIR  <- file.path(OUTPUT_DIR, "figures")
CACHE_DIR   <- file.path(OUTPUT_DIR, "cache")   # intermediate .rds between steps

for (d in c(OUTPUT_DIR, TABLE_DIR, FIGURE_DIR, CACHE_DIR)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# --- Input file names (relative to DATA_DIR) ---------------------------------
F_DYAD      <- "MyDataLogit.rds"   # 4.4 GB dyad-level frame (primary input)
F_FLESCH    <- "df_flesch.rds"     # per-text Flesch score, joined on Date
F_SELECTION <- "data3.rds"         # Heckman selection frame (-> IMR1)
# SSBC scores + mimicry file names are environment-specific; set when available:
F_SSBC      <- Sys.getenv("HAAS_SSBC_FILE",    unset = "")  # v11 ES/IS scores
F_MIMICRY   <- Sys.getenv("HAAS_MIMICRY_FILE", unset = "")  # Otterbacher mimicry

# --- Analysis flags ----------------------------------------------------------
# CLUSTER_SE: FALSE reproduces the PRINTED tables (conventional SEs).
#             TRUE  runs the revision-program two-way (post x provider)
#             cluster-robust SEs that the paper says are required (README §6).
CLUSTER_SE  <- FALSE

# K: number of LDA topics used upstream (drives topic FE and breadth).
N_TOPICS    <- 23

# Significance display thresholds (matches the paper's note rows).
SIG_LEVELS  <- c(0.001, 0.01, 0.05, 0.10)   # *** ** * +

# Reproducibility: fix the RNG wherever any randomness is used (bootstraps, etc.).
SEED        <- 20240413
set.seed(SEED)

# Print numbers without scientific notation, like the legacy scripts.
options(scipen = 999)

# --- Expected analytic-sample sizes (from the v5 paper; used as run-time checks) ---
EXPECTED_N <- list(
  post_level   = 31046L,
  dyad         = 7476224L,
  realized     = 310375L,
  merged_ssbc  = 199249L,   # NOTE: includes the merge fan-out (DATA.md §4)
  mimicry      = 130138L
)

message("config.R loaded. DATA_DIR = ", normalizePath(DATA_DIR, mustWork = FALSE),
        " | CLUSTER_SE = ", CLUSTER_SE)
