# =============================================================================
# R/measures.R — construction of the study's derived measures
# =============================================================================
# These implement the variable definitions in the v5 paper §4.2–4.4. They take a
# data frame with the upstream-measured columns (LIWC categories, LDA topic
# distribution) and return the analysis variables. Keeping them here means
# 02_build_variables.R reads as a recipe, and each formula sits next to the
# equation it implements.

suppressWarnings(suppressMessages(library(dplyr)))

# --- EED: Expressed Emotional Distress (paper §4.3, eq. for EED_i) ------------
#   EED_i = LIWC_anx(post_i) + LIWC_sad(post_i)
# The ".x" suffix denotes the POST side of the dyad (vs ".y" = reply).
# NOTE (legacy): ETM_output/Logit2025.R used `suffer.x = AI_anxiety + AI_sadness`
#   (LLM-derived). The v5 paper supersedes that with the LIWC sum below.
compute_eed <- function(df, anx = "anx.x", sad = "sad.x") {
  stopifnot(all(c(anx, sad) %in% names(df)))
  df[[anx]] + df[[sad]]
}

# --- Qs_breadth: topical breadth = entropy of the post's topic distribution --
#   Qs_breadth_i = -sum_k theta_{i,k} * ln(theta_{i,k}),  with 0*ln(0) := 0
# `topic_cols` are the K (=23) LDA probability columns for the focal post.
# Returns NA-safe Shannon entropy in nats. If ExpMatch/Qs_breadth are already
# present in the data (pre-computed upstream), 02_build_variables.R uses those
# and this is a documented re-derivation / cross-check.
compute_breadth <- function(df, topic_cols) {
  stopifnot(all(topic_cols %in% names(df)))
  theta <- as.matrix(df[, topic_cols, drop = FALSE])
  theta[theta <= 0] <- NA            # so log() is defined; 0*ln0 -> 0 below
  ent  <- -rowSums(theta * log(theta), na.rm = TRUE)   # na.rm enforces 0*ln0=0
  ent
}

# --- ExpMatch: cosine similarity (paper §4.3, eq. for ExpMatch_ij) ------------
#   ExpMatch_ij = (e_{j,t} . theta_post_i) / (||e_{j,t}|| * ||theta_post_i||)
# `e_mat`     : provider expertise-profile matrix (rows align with df), K columns
# `theta_mat` : focal-post topic-distribution matrix (rows align with df)
# In this corpus ExpMatch is typically pre-computed upstream (column `ExpMatch`);
# this function documents/reproduces the definition and is used when the raw
# topic vectors are available instead of the finished column.
compute_expmatch <- function(e_mat, theta_mat) {
  stopifnot(ncol(e_mat) == ncol(theta_mat), nrow(e_mat) == nrow(theta_mat))
  num   <- rowSums(e_mat * theta_mat)
  denom <- sqrt(rowSums(e_mat^2)) * sqrt(rowSums(theta_mat^2))
  out   <- num / denom
  out[!is.finite(out)] <- NA          # zero-history providers -> undefined
  out
}

# --- Flesch Reading Ease (mirrors ETM_output/Flesh.R) ------------------------
# Provided for completeness/reproducibility of the control. In the pipeline the
# score is read from df_flesch.rds (built once by Flesh.R); recomputing per run
# is expensive, so 02_build_variables.R joins the precomputed score by `Date`.
#   Flesch = 206.835 - 1.015*(words/sentences) - 84.6*(syllables/words)
flesch_reading_ease <- function(text) {
  if (is.na(text) || !nzchar(text)) return(NA_real_)
  sentences <- max(length(unlist(strsplit(text, "[.!?]+"))), 1L)
  words_v   <- unlist(strsplit(tolower(text), "\\s+"))
  words_v   <- words_v[nzchar(words_v)]
  num_words <- length(words_v)
  if (num_words == 0) return(NA_real_)
  syl <- function(w) {                      # crude syllable heuristic (as Flesh.R)
    v <- length(unlist(gregexpr("[aeiouy]+", w))); v <- ifelse(v < 0, 0, v)
    v <- v - ifelse(grepl("e$", w), 1, 0)
    max(v, 1L)
  }
  total_syl <- sum(vapply(words_v, syl, numeric(1)))
  206.835 - 1.015 * (num_words / sentences) - 84.6 * (total_syl / num_words)
}
