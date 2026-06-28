# =============================================================================
# 07_h5_mediation.R — TABLE V (H5): Baron-Kenny mediation of reply quality
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/merged_ssbc.rds   (199,249 rows, from 06)
# OUTPUT : outputs/tables/table_V.csv
#
# Spec (v5 paper §4.5 / §5.5): Baron & Kenny (1986) three-step mediation on the
# merged SSBC sample. DV = reply quality = points_thisqs (RAW upvotes, untransformed
# in Table V). Mediators = SSBC Emotional Support (ES) and Instrumental Support (IS).
#   Model 1 : Quality ~ EED + controls                 (total effect, step 1)
#   Model 2a: ES      ~ EED + controls                 (a-path, ES)
#   Model 2b: IS      ~ EED + controls                 (a-path, IS)
#   Model 3 : Quality ~ EED + ES + IS + controls       (direct + b-paths)
#
# EXPECTED (Table V):
#   Step 1 total effect EED -> Quality = +0.014 (p = .67)  => NULL
#   => H5 IS NOT SUPPORTED (Baron-Kenny terminates at step 1).
#   Dominant predictor: Reply Length (+0.806 step1, +0.954 step3).
#   IS -> Quality (conditional on length) = -0.350*** (unexpected; see §5.5).
#
# CAVEATS reproduced: §4.1 merge fan-out applies to every number here.
# TODO(revision-program): bootstrapped indirect-effect CIs (Zhao et al. 2010);
#   jointly-specified multiple-mediator model incl. reply length as a modeled
#   mediator; log(1+x) DV; corrected merge.
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

merged <- readRDS(file.path(CACHE_DIR, "merged_ssbc.rds"))
check_n(nrow(merged), EXPECTED_N$merged_ssbc, "merged_ssbc (H5)")

# Mediators enter as numeric SSBC scores (the ordinal levels treated as scores,
# matching the paper's continuous-mediator Baron-Kenny system).
merged$ES_num <- as.numeric(merged$v11_emotional_support)
merged$IS_num <- as.numeric(merged$v11_instrumental_support)

# Controls used in Table V (note: Reply Length is a control here, NOT a modeled
# mediator — paper §5.5 is explicit that no EED->length->quality path is estimated).
controls <- c("ExpMatch_z", "WC.y_log_z", "WC.x_log_z", "Days_in_reddit_z",
              "PostKarma.x_log_z", "CommKarma.x_log_z", "politeness_z",
              "Qs_breadth_z", "posemo.x_z", "negemo.x_z")

# DV = RAW upvotes (untransformed), per Table V note.
merged$Quality <- merged$points_thisqs

f1  <- as.formula(paste("Quality ~ EED_z +", paste(controls, collapse = " + ")))
f2a <- as.formula(paste("ES_num  ~ EED_z +", paste(controls, collapse = " + ")))
f2b <- as.formula(paste("IS_num  ~ EED_z +", paste(controls, collapse = " + ")))
f3  <- as.formula(paste("Quality ~ EED_z + ES_num + IS_num +",
                        paste(controls, collapse = " + ")))

m1  <- lm(f1,  data = merged)   # step 1: total effect
m2a <- lm(f2a, data = merged)   # a-path ES
m2b <- lm(f2b, data = merged)   # a-path IS
m3  <- lm(f3,  data = merged)   # direct + b-paths

tt <- function(m, label) {
  ct <- coef_table(m); ct$model <- label
  ct$r2 <- summary(m)$r.squared; ct$N <- length(m$residuals); ct
}
table_V <- dplyr::bind_rows(
  tt(m1,  "M1 Quality (total)"),
  tt(m2a, "M2a ES"),
  tt(m2b, "M2b IS"),
  tt(m3,  "M3 Quality (+M)")
)
save_table(table_V, "table_V")

# --- the Baron-Kenny verdict, computed and printed ---------------------------
b_total <- coef(m1)["EED_z"]; p_total <- coef(summary(m1))["EED_z", 4]
message(sprintf("  STEP 1 total effect EED->Quality = %+.3f (p = %.2f)", b_total, p_total))
if (p_total >= 0.05) {
  message("  => H5 NOT SUPPORTED: null total effect; Baron-Kenny stops at step 1 ",
          "(matches paper §5.5).")
}
# Indicative (not inferential) indirect products for the record:
a_es <- coef(m2a)["EED_z"]; b_es <- coef(m3)["ES_num"]
a_is <- coef(m2b)["EED_z"]; b_is <- coef(m3)["IS_num"]
message(sprintf("  indirect (point est, no CI): ES a*b = %.4f ; IS a*b = %.4f",
                a_es*b_es, a_is*b_is))
message("07_h5_mediation.R done -> table_V.csv")
