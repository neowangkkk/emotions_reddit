# =============================================================================
# 02_build_variables.R — derive EED, transforms, and z-scores on each sample
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/{dyad_analytic,realized,post_level}.rds  (from 01)
#          <DATA_DIR>/df_flesch.rds  (Flesch score, joined on Date)
# OUTPUT : outputs/cache/{dyad_model,realized_model,post_model}.rds
#          (same frames + EED, log-transforms, and *_z standardized columns)
#
# Implements v5 paper §4.3–4.4:
#   EED = anx.x + sad.x ;  log(1+x) on counts/karma/WC ;  z-standardise predictors.
# ExpMatch and Qs_breadth are taken as pre-computed upstream (LDA); R/measures.R
# documents/re-derives their formulas for transparency.
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")
source("R/measures.R")

dyad     <- readRDS(file.path(CACHE_DIR, "dyad_analytic.rds"))
realized <- readRDS(file.path(CACHE_DIR, "realized.rds"))
post     <- readRDS(file.path(CACHE_DIR, "post_level.rds"))

# --- optional Flesch join (control) ------------------------------------------
flesch_path <- file.path(DATA_DIR, F_FLESCH)
if (file.exists(flesch_path)) {
  fl <- readRDS(flesch_path) %>% dplyr::select(Date, Flesch = flesch_score) %>% distinct(Date, .keep_all = TRUE)
  dyad     <- dplyr::left_join(dyad,     fl, by = "Date")
  realized <- dplyr::left_join(realized, fl, by = "Date")
} else {
  message("NOTE: ", flesch_path, " not found; Flesch left as-is / NA.")
}

# --- derive variables on a frame ---------------------------------------------
# A single recipe applied to each sample so definitions never drift between them.
add_model_vars <- function(d, level = c("dyad", "realized", "post")) {
  level <- match.arg(level)

  # EED = LIWC anx + sad on the post (paper §4.3). Same on every level.
  d$EED <- compute_eed(d, anx = "anx.x", sad = "sad.x")

  # log(1 + x) transforms (paper §4.4): word counts, karma, attention counts.
  if ("WC.x" %in% names(d))        d$WC.x_log        <- log1p_safe(d$WC.x)
  if ("WC.y" %in% names(d))        d$WC.y_log        <- log1p_safe(d$WC.y)
  if ("PostKarma.x" %in% names(d)) d$PostKarma.x_log <- log1p_safe(d$PostKarma.x)
  if ("CommKarma.x" %in% names(d)) d$CommKarma.x_log <- log1p_safe(d$CommKarma.x)
  if (level == "post") {
    d$Count_reply_log         <- log1p_safe(d$Count_reply)
    d$total_reply_pts_log     <- log1p_safe(d$total_reply_pts)
    d$n_distinct_repliers_log <- log1p_safe(d$n_distinct_repliers)
  }

  # z-standardise continuous predictors (paper: "continuous variables standardized").
  # Names ending in _z are what the model formulas in 03..07 reference.
  z_targets <- intersect(c(
    "EED", "ExpMatch", "WC.x_log", "Qs_breadth", "politeness",
    "Days_in_reddit", "Days_in_reddit.x", "PostKarma.x_log", "CommKarma.x_log",
    "posemo.x", "negemo.x", "Tone", "Analytic", "Clout", "Flesch", "WC.y_log"
  ), names(d))
  for (v in z_targets) d[[paste0(v, "_z")]] <- zscore(d[[v]])

  # H4 interaction term: product of the two z-scores (built where both exist).
  if (all(c("EED_z", "ExpMatch_z") %in% names(d)))
    d$EED_x_ExpMatch <- d$EED_z * d$ExpMatch_z

  d
}

dyad     <- add_model_vars(dyad,     "dyad")
realized <- add_model_vars(realized, "realized")
post     <- add_model_vars(post,     "post")

# --- quick distributional sanity checks vs the paper -------------------------
# Paper §4.4 carries: EED mean 0.30 (range 0–22.23); EED–negemo r = 0.71.
message(sprintf("EED (post): mean=%.2f  range=[%.2f, %.2f]  (paper mean 0.30, max 22.23)",
                mean(post$EED, na.rm=TRUE), min(post$EED, na.rm=TRUE), max(post$EED, na.rm=TRUE)))
if (all(c("EED","negemo.x") %in% names(dyad)))
  message(sprintf("cor(EED, negemo.x) on dyad = %.2f  (paper r = 0.71)",
                  cor(dyad$EED, dyad$negemo.x, use = "complete.obs")))

saveRDS(dyad,     file.path(CACHE_DIR, "dyad_model.rds"))
saveRDS(realized, file.path(CACHE_DIR, "realized_model.rds"))
saveRDS(post,     file.path(CACHE_DIR, "post_model.rds"))
message("02_build_variables.R done. EED + transforms + z-scores added to all frames.")
