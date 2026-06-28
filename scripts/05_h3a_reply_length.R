# =============================================================================
# 05_h3a_reply_length.R — TABLE III (H3a): reply length as an effort indicator
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/realized_model.rds   (310,375 realized replies, from 02)
# OUTPUT : outputs/tables/table_III.csv
#
# Spec (v5 paper §4.5 / §5.3): OLS of log(1 + reply word count) on standardized
# EED + standardized controls, on the realized-reply subsample.
#   Model 1: controls only
#   Model 2: + EED
#
# EXPECTED (Table III): EED(z) = +0.008*** (M2); ExpMatch(z) = +0.025***;
#   N = 310,375; R^2 = 0.0123 (both models).
#
# CAVEATS the paper attaches (carried as comments, not silently resolved):
#   - tiny magnitude (<1% of reply length); survival under clustering is open
#     (TODO(revision-program): two-way cluster SEs; small beta could flip).
#   - SELECTION: this is the *realized* (selected) population; H2 implies EED
#     changes who replies, so a positive length coefficient may be composition,
#     not elevated effort. Selection-corrected / within-provider designs are in
#     the revision program.
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

realized <- readRDS(file.path(CACHE_DIR, "realized_model.rds"))
check_n(nrow(realized), EXPECTED_N$realized, "realized (H3a)")

# Dyad-level control set (same family as Table II; reply length DV).
controls <- c("ExpMatch_z", "WC.x_log_z", "Days_in_reddit_z",
              "PostKarma.x_log_z", "CommKarma.x_log_z", "politeness_z",
              "Qs_breadth_z", "posemo.x_z", "negemo.x_z")

f1 <- as.formula(paste("WC.y_log ~", paste(controls, collapse = " + ")))
f2 <- as.formula(paste("WC.y_log ~ EED_z +", paste(controls, collapse = " + ")))

m1 <- lm(f1, data = realized)
m2 <- lm(f2, data = realized)

# Optional clustered SEs (revision program).
v1 <- v2 <- NULL
if (isTRUE(CLUSTER_SE)) {
  cl_post <- realized[[intersect(c("Thread","Title","id"), names(realized))[1]]]
  cl_prov <- realized[["Replier"]]
  v1 <- cluster_vcov_2way(m1, cl_post, cl_prov)
  v2 <- cluster_vcov_2way(m2, cl_post, cl_prov)
}

tt <- function(m, v, label) {
  ct <- coef_table(m, vcov_override = v); ct$model <- label
  ct$r2 <- summary(m)$r.squared; ct$N <- length(m$residuals); ct
}
table_III <- dplyr::bind_rows(tt(m1, v1, "M1 controls"),
                              tt(m2, v2, "M2 +EED"))
save_table(table_III, "table_III")

message(sprintf("  EED(z) = %+.3f  R2 = %.4f  (paper +0.008, R2 0.0123)",
                coef(m2)["EED_z"], summary(m2)$r.squared))
message("05_h3a_reply_length.R done -> table_III.csv")
