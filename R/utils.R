# =============================================================================
# R/utils.R — small, dependency-light helpers used across all analysis scripts
# =============================================================================
# These functions exist so the modelling scripts read like the paper: one call
# per conceptual step, no copy-pasted boilerplate. Nothing here is study-specific
# beyond formatting conventions; the statistical choices live in the 03..09 scripts.

suppressWarnings(suppressMessages({
  library(dplyr)
}))

# --- log(1 + x) used throughout the paper ------------------------------------
# Preferred over log(x) because counts/karma/word-counts admit zeros (paper §4.4).
log1p_safe <- function(x) log1p(pmax(x, 0))   # guard against tiny negative noise

# --- z-standardisation (mean 0, sd 1), NA-safe -------------------------------
# The paper standardises all continuous predictors so coefficients are per-1-SD.
zscore <- function(x) {
  mu <- mean(x, na.rm = TRUE); sdv <- sd(x, na.rm = TRUE)
  if (is.na(sdv) || sdv == 0) return(rep(0, length(x)))
  (x - mu) / sdv
}

# --- significance stars matching the paper's note row ------------------------
# + p<0.10, * p<0.05, ** p<0.01, *** p<0.001
sig_stars <- function(p) {
  dplyr::case_when(
    is.na(p)    ~ "",
    p < 0.001   ~ "***",
    p < 0.01    ~ "**",
    p < 0.05    ~ "*",
    p < 0.10    ~ "+",
    TRUE        ~ ""
  )
}

# --- tidy a fitted model into a coefficient table (est, se, p, stars) --------
# Works for lm / glm / polr / heckit via broom where possible, with a manual
# fallback so we never depend on a single tidier. `vcov_override` lets a caller
# pass clustered SEs (sandwich::vcovCL) without re-fitting (README §6 / CLUSTER_SE).
coef_table <- function(model, vcov_override = NULL, digits = 3) {
  est <- tryCatch(stats::coef(model), error = function(e) NULL)
  if (is.null(est)) stop("coef_table: cannot extract coefficients from model")

  # Variance-covariance: clustered if supplied, else model's own.
  V <- if (!is.null(vcov_override)) vcov_override else
       tryCatch(stats::vcov(model), error = function(e) NULL)

  if (is.null(V)) {  # e.g. polr without vcov on some versions -> use summary
    sm <- summary(model)$coefficients
    se <- sm[, 2]; z <- est / se
  } else {
    keep <- intersect(names(est), rownames(V))
    est  <- est[keep]; se <- sqrt(diag(V))[keep]; z <- est / se
  }
  p <- 2 * stats::pnorm(-abs(z))

  data.frame(
    term     = names(est),
    estimate = round(unname(est), digits),
    std_err  = round(unname(se),  digits),
    p_value  = signif(unname(p), 3),
    sig      = sig_stars(unname(p)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

# --- two-way cluster-robust vcov (post x provider) ---------------------------
# The revision-program SE correction (README §6). Returns a vcov matrix to feed
# into coef_table(..., vcov_override = .). Requires sandwich.
cluster_vcov_2way <- function(model, cluster_post, cluster_provider) {
  if (!requireNamespace("sandwich", quietly = TRUE))
    stop("Install 'sandwich' for clustered SEs (CLUSTER_SE = TRUE).")
  sandwich::vcovCL(model, cluster = list(cluster_post, cluster_provider))
}

# --- write a reproduced table to outputs/tables ------------------------------
# Saves the tidy table as CSV and echoes a compact preview to the console so a
# run is self-documenting in the log.
save_table <- function(tbl, name, table_dir = "outputs/tables") {
  if (!dir.exists(table_dir)) dir.create(table_dir, recursive = TRUE)
  path <- file.path(table_dir, paste0(name, ".csv"))
  utils::write.csv(tbl, path, row.names = FALSE)
  message("  wrote ", path, "  (", nrow(tbl), " rows)")
  invisible(path)
}

# --- assert an analytic sample matches the paper's reported N ----------------
# Loud, non-fatal warning if a frame's row count drifts from the manuscript.
check_n <- function(n_actual, n_expected, label) {
  if (length(n_expected) == 0 || is.na(n_expected)) return(invisible())
  if (n_actual != n_expected) {
    warning(sprintf("[N CHECK] %s: got %s, paper reports %s (%+d).",
                    label, format(n_actual, big.mark = ","),
                    format(n_expected, big.mark = ","), n_actual - n_expected))
  } else {
    message(sprintf("  [N CHECK] %s = %s  OK", label,
                    format(n_actual, big.mark = ",")))
  }
}
