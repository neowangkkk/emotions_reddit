# =============================================================================
# 06_h3b_ssbc_ordinal.R — TABLE IV (H3b): SSBC emotional & instrumental support
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/realized_model.rds      (realized dyads, from 02)
#          <DATA_DIR>/<F_SSBC>   (v11_emotional_support 0-2, v11_instrumental_support 0-3)
# OUTPUT : outputs/cache/merged_ssbc.rds          (the 199,249-row merged frame)
#          outputs/tables/table_IV.csv
#
# Spec (v5 paper §4.5 / §5.4): proportional-odds ordinal logistic regression of
# v11 Emotional Support (0-2) and Instrumental Support (0-3) on standardized EED,
# ExpMatch, and standardized controls + the reply's own length, on the merged
# SSBC sample.
#
# EXPECTED (Table IV): EED(z) on ES = +0.029***, on IS = -0.044***;
#   ExpMatch(z) on ES = +0.088***, on IS = -0.042***; N = 199,249.
#
# *** MERGE CAVEAT (paper §4.1) — reproduced, not fixed ***
#   The score<->dyad join key is (timestamp, replier) with NO thread id, and is
#   not unique: 197,060 scored dyads fan out to 199,249 rows. These estimates are
#   PROVISIONAL. TODO(revision-program): corrected merge on a thread-level key,
#   then re-estimate. We reproduce the 199,249-row number exactly as published.
# TODO(revision-program): Brant test of the proportional-odds assumption;
#   partial-proportional-odds comparison; post-blind rescoring (scoring circularity).
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")
suppressWarnings(suppressMessages(library(MASS)))   # polr()

realized <- readRDS(file.path(CACHE_DIR, "realized_model.rds"))

# --- merge SSBC scores onto realized dyads -----------------------------------
if (!nzchar(F_SSBC) || !file.exists(file.path(DATA_DIR, F_SSBC))) {
  stop("SSBC score file not set/found. Set HAAS_SSBC_FILE env var or F_SSBC in ",
       "config.R to the file with v11_emotional_support / v11_instrumental_support.\n",
       "Expected merged N = ", format(EXPECTED_N$merged_ssbc, big.mark=","),
       " (includes the documented fan-out; see DATA.md §4).")
}
ssbc <- readRDS(file.path(DATA_DIR, F_SSBC))

# The published merge key is (timestamp, replier) and lacks a thread id; we
# reproduce it AS-IS so the row count and any fan-out match the paper. Adapt the
# key column names to the actual SSBC file at runtime.
join_keys <- intersect(c("Date", "timestamp", "Replier"), names(ssbc))
message("Merging SSBC on keys: ", paste(join_keys, collapse = ", "),
        "  (reproducing the published non-unique join; see §4.1 caveat)")
merged_ssbc <- dplyr::inner_join(realized, ssbc, by = join_keys)

check_n(nrow(merged_ssbc), EXPECTED_N$merged_ssbc, "merged_ssbc (H3b/H5)")
saveRDS(merged_ssbc, file.path(CACHE_DIR, "merged_ssbc.rds"))

# --- proportional-odds ordinal logit -----------------------------------------
# DV must be an ordered factor for polr().
merged_ssbc$ES <- factor(merged_ssbc$v11_emotional_support,    ordered = TRUE)
merged_ssbc$IS <- factor(merged_ssbc$v11_instrumental_support, ordered = TRUE)

# Controls: dyad-level set + the realized reply's own length (paper §4.4).
controls <- c("EED_z", "ExpMatch_z", "WC.x_log_z", "Days_in_reddit_z",
              "PostKarma.x_log_z", "CommKarma.x_log_z", "politeness_z",
              "Qs_breadth_z", "posemo.x_z", "negemo.x_z", "WC.y_log_z")

f_es <- as.formula(paste("ES ~", paste(controls, collapse = " + ")))
f_is <- as.formula(paste("IS ~", paste(controls, collapse = " + ")))

m_es <- polr(f_es, data = merged_ssbc, Hess = TRUE, method = "logistic")
m_is <- polr(f_is, data = merged_ssbc, Hess = TRUE, method = "logistic")

# polr() gives no p-values by default; coef_table() derives z = est/se from vcov.
table_IV <- dplyr::bind_rows(
  transform(coef_table(m_es), model = "Emotional Support (0-2)"),
  transform(coef_table(m_is), model = "Instrumental Support (0-3)")
)
# Drop the ordinal intercept (cutpoint) rows from the printed coefficient block.
table_IV <- table_IV[!grepl("\\|", table_IV$term), ]
table_IV$N <- nrow(merged_ssbc)
save_table(table_IV, "table_IV")

message(sprintf("  EED(z): ES=%+.3f  IS=%+.3f  (paper +0.029 / -0.044)",
                coef(m_es)["EED_z"], coef(m_is)["EED_z"]))
message("06_h3b_ssbc_ordinal.R done -> table_IV.csv  (merged_ssbc cached)")
