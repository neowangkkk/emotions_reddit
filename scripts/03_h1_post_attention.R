# =============================================================================
# 03_h1_post_attention.R — TABLE I (H1): emotional cues & post-level attention
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/post_model.rds      (31,046 threads, from 02)
# OUTPUT : outputs/tables/table_I.csv
#
# Spec (v5 paper §4.5 / §5.1): OLS of each log-transformed attention DV on
# standardized EED + standardized controls + topic fixed effects.
#   Model 1: log(1+replies)        ~ controls            (baseline, no EED)
#   Model 2: log(1+replies)        ~ EED + controls       (the H1 test)
#   Model 3: log(1+reply upvotes)  ~ EED + controls
#   Model 4: log(1+distinct repliers) ~ EED + controls
#
# EXPECTED (Table I): EED(z) = +0.029*** (M2), +0.010* (M3), +0.027*** (M4);
#   N = 31,046 each; R^2 = .0386 / .0394 / .0035 / .0413.
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

post <- readRDS(file.path(CACHE_DIR, "post_model.rds"))
check_n(nrow(post), EXPECTED_N$post_level, "post_level (H1)")

# Controls common to all four models (post-text style + topic FE).
# Tone/Analytic/Clout enter ONLY the post-level models (paper §4.4).
controls_post <- c("WC.x_log_z", "Tone_z", "Analytic_z", "Clout_z",
                   "posemo.x_z", "politeness_z", "Qs_breadth_z")
topic_fe <- if ("Main Topic" %in% names(post)) "factor(`Main Topic`)" else NULL

rhs <- function(with_eed = TRUE) {
  terms <- c(if (with_eed) "EED_z", controls_post, topic_fe)
  paste(terms, collapse = " + ")
}

fit_ols <- function(dv, with_eed = TRUE) {
  f <- as.formula(paste0("`", dv, "` ~ ", rhs(with_eed)))
  lm(f, data = post)
}

# --- estimate the four models ------------------------------------------------
m1 <- fit_ols("Count_reply_log",         with_eed = FALSE)  # baseline
m2 <- fit_ols("Count_reply_log",         with_eed = TRUE)   # + EED (H1)
m3 <- fit_ols("total_reply_pts_log",     with_eed = TRUE)
m4 <- fit_ols("n_distinct_repliers_log", with_eed = TRUE)

# --- assemble Table I (drop the many topic-FE dummy rows from the printout) ---
tidy_drop_fe <- function(m, label) {
  ct <- coef_table(m)
  ct <- ct[!grepl("Main Topic", ct$term), ]
  ct$model <- label
  ct$r2    <- summary(m)$r.squared
  ct$N     <- length(m$residuals)
  ct
}

table_I <- dplyr::bind_rows(
  tidy_drop_fe(m1, "M1 replies (baseline)"),
  tidy_drop_fe(m2, "M2 replies (+EED)"),
  tidy_drop_fe(m3, "M3 total upvotes"),
  tidy_drop_fe(m4, "M4 distinct repliers")
)

save_table(table_I, "table_I")

# Console echo of the headline coefficient for a quick eyeball vs EXPECTED.
for (m in list(`M2`=m2, `M3`=m3, `M4`=m4)) {
  b <- coef(m)["EED_z"]
  message(sprintf("  EED(z) = %+.3f", b))
}
message("03_h1_post_attention.R done -> table_I.csv")
