# =============================================================================
# 01_prepare_data.R — build the four analytic samples from the dyad-level frame
# -----------------------------------------------------------------------------
# INPUT  : <DATA_DIR>/MyDataLogit.rds   (~4.4 GB, one row per post x candidate dyad)
# OUTPUT : outputs/cache/{dyad_analytic,realized,post_level}.rds
#          (merged_ssbc is built in 06; it needs the SSBC scores)
#
# Reproduces the "Sample flow" of v5 paper §4.1:
#   constructed dyads (realized + unrealized)  --listwise-->  dyad_analytic (7,476,224)
#   realized dyads w/ non-missing WC.y                       realized       (310,375)
#   aggregate dyads to thread                                post_level      (31,046)
#
# EXPECTED (v5 §4.1):
#   nrow(dyad_analytic) = 7,476,224   (realized rate 4.15%)
#   nrow(realized)      =   310,375
#   nrow(post_level)    =    31,046
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

dyad_path <- file.path(DATA_DIR, F_DYAD)
if (!file.exists(dyad_path))
  stop("Missing input: ", dyad_path, "\nSet DATA_DIR in config.R (see DATA.md).")

message("Reading dyad frame: ", dyad_path, " (this is large; be patient)")
df <- readRDS(dyad_path)

# Print the actual schema so column names can be verified against DATA.md.
message("Dyad frame: ", format(nrow(df), big.mark = ","), " rows x ", ncol(df), " cols")
message("Columns:\n  ", paste(names(df), collapse = ", "))

# --- key covariates that must be non-missing for the dyad-level analytic sample
# (paper §4.1: "non-missing values on all key covariates"). EED is built in 02,
# but its LIWC inputs (anx.x, sad.x) must be present here.
key_covariates <- c(
  "answer_or_not",                         # DV (H2/H4)
  "ExpMatch",                              # explanatory (H4)
  "anx.x", "sad.x",                        # -> EED
  "WC.x", "Qs_breadth", "politeness",      # controls
  "Days_in_reddit", "Days_in_reddit.x",
  "PostKarma.x", "CommKarma.x",
  "posemo.x", "negemo.x"
)
present <- intersect(key_covariates, names(df))
missing_cols <- setdiff(key_covariates, names(df))
if (length(missing_cols))
  warning("Columns named differently / absent (verify vs MyDataLogit): ",
          paste(missing_cols, collapse = ", "))

# --- dyad-level analytic sample: listwise-complete on key covariates ---------
dyad_analytic <- df %>% filter(if_all(all_of(present), ~ !is.na(.)))
check_n(nrow(dyad_analytic), EXPECTED_N$dyad, "dyad_analytic")

base_rate <- mean(dyad_analytic$answer_or_not, na.rm = TRUE)
message(sprintf("  base reply rate = %.4f  (paper: 0.0415)", base_rate))

# --- realized-reply subsample: realized dyads with non-missing reply length --
realized <- dyad_analytic %>% filter(answer_or_not == 1, !is.na(WC.y))
check_n(nrow(realized), EXPECTED_N$realized, "realized")

# --- post-level sample: aggregate dyads to the thread ------------------------
# Thread id column is "Thread" (fallback to "Title"/"id" if absent — verify).
thread_key <- intersect(c("Thread", "Title", "id"), names(df))[1]
message("Aggregating to post level on key: ", thread_key)

post_level <- dyad_analytic %>%
  group_by(.thread = .data[[thread_key]]) %>%
  summarise(
    # three attention DVs (paper §4.2). total_reply_pts uses reply upvotes.
    Count_reply         = sum(answer_or_not == 1, na.rm = TRUE),
    total_reply_pts     = sum(points_thisqs[answer_or_not == 1], na.rm = TRUE),
    n_distinct_repliers = n_distinct(Replier[answer_or_not == 1]),
    # post-constant predictors/controls: take the first (constant within thread)
    anx.x = first(anx.x), sad.x = first(sad.x),
    WC.x = first(WC.x), Qs_breadth = first(Qs_breadth),
    politeness = first(politeness),
    posemo.x = first(posemo.x), negemo.x = first(negemo.x),
    Tone = first(Tone), Analytic = first(if ("Analytic.x" %in% names(df)) Analytic.x else Analytic),
    Clout = first(Clout),
    `Main Topic` = first(.data[["Main Topic"]]),
    .groups = "drop"
  )
check_n(nrow(post_level), EXPECTED_N$post_level, "post_level")

# --- persist intermediates for the modelling scripts -------------------------
saveRDS(dyad_analytic, file.path(CACHE_DIR, "dyad_analytic.rds"))
saveRDS(realized,      file.path(CACHE_DIR, "realized.rds"))
saveRDS(post_level,    file.path(CACHE_DIR, "post_level.rds"))
message("01_prepare_data.R done. Cached dyad_analytic / realized / post_level.")
