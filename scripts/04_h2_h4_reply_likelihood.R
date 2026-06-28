# =============================================================================
# 04_h2_h4_reply_likelihood.R — TABLE II (H2 & H4): individual reply likelihood
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/dyad_model.rds      (7,476,224 dyads, from 02)
# OUTPUT : outputs/tables/table_II.csv
#          outputs/tables/table_II_marginal_eed_by_expmatch.csv  (H4 simple slopes)
#
# Spec (v5 paper §4.5 / §5.2): binary logistic regression of `answer_or_not`.
#   Model 1: controls only
#   Model 2: + ExpMatch
#   Model 3: + EED                         (H2)
#   Model 4: + EED x ExpMatch              (H4)
#
# EXPECTED (Table II):
#   EED(z)        : -0.037*** (M3),  -0.012*** (M4 main effect at mean match)
#   ExpMatch(z)   : +1.025*** (M3)
#   EED x ExpMatch: -0.019***  (M4)   -> H4 cost-aware supported, enabler rejected
#   N = 7,476,224; base reply rate 0.0415; AIC M3=2,176,970  M4=2,176,784
#   Implied EED log-odds by match: low(-1)=+0.007, mean(0)=-0.012, high(+1)=-0.031
#
# INFERENCE CAVEAT (paper §4.5): SEs below are conventional. Post-text regressors
#   are constant within post (~241 dyads/post); two-way (post x provider) clustered
#   SEs are required before precision claims. Set CLUSTER_SE = TRUE in config.R to
#   run them (block at the bottom). The interaction beta = -0.019 is flagged as
#   small enough that clustering could matter.
# TODO(revision-program): add log(risk-set size) + year-month FE to discriminate
#   the two-channel reading from the bystander/audience-size reading (§5.2).
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

dyad <- readRDS(file.path(CACHE_DIR, "dyad_model.rds"))
check_n(nrow(dyad), EXPECTED_N$dyad, "dyad_analytic (H2/H4)")
message(sprintf("  base reply rate = %.4f", mean(dyad$answer_or_not)))

# Controls for the dyad-level models (NOTE: Tone/Analytic/Clout are post-level
# only, per paper §4.4 — deliberately excluded here).
controls_dyad <- c("WC.x_log_z", "Days_in_reddit_z", "PostKarma.x_log_z",
                   "CommKarma.x_log_z", "politeness_z", "Qs_breadth_z",
                   "posemo.x_z", "negemo.x_z")

logit <- function(rhs_terms) {
  f <- as.formula(paste("answer_or_not ~", paste(rhs_terms, collapse = " + ")))
  # glm binomial = the paper's "binary logistic regression" on the full sample.
  # (logistf/Firth in legacy Logit2025.R was an exploratory subsample tool; the
  #  King-Zeng rare-event claim was withdrawn in v5 — see §4.5.)
  glm(f, family = binomial(link = "logit"), data = dyad)
}

m1 <- logit(controls_dyad)
m2 <- logit(c("ExpMatch_z", controls_dyad))
m3 <- logit(c("EED_z", "ExpMatch_z", controls_dyad))                 # H2
m4 <- logit(c("EED_z", "ExpMatch_z", "EED_x_ExpMatch", controls_dyad)) # H4

# --- optional: two-way clustered SEs (revision program) ----------------------
vcovs <- list(M1=NULL, M2=NULL, M3=NULL, M4=NULL)
if (isTRUE(CLUSTER_SE)) {
  message("CLUSTER_SE = TRUE: computing two-way (post x provider) robust SEs ...")
  cl_post <- dyad[[intersect(c("Thread","Title","id"), names(dyad))[1]]]
  cl_prov <- dyad[["Replier"]]
  vcovs <- list(
    M1 = cluster_vcov_2way(m1, cl_post, cl_prov),
    M2 = cluster_vcov_2way(m2, cl_post, cl_prov),
    M3 = cluster_vcov_2way(m3, cl_post, cl_prov),
    M4 = cluster_vcov_2way(m4, cl_post, cl_prov)
  )
}

# --- assemble Table II -------------------------------------------------------
tt <- function(m, v, label) {
  ct <- coef_table(m, vcov_override = v)
  ct$model <- label; ct$AIC <- AIC(m); ct$N <- length(m$fitted.values); ct
}
table_II <- dplyr::bind_rows(
  tt(m1, vcovs$M1, "M1 controls"),
  tt(m2, vcovs$M2, "M2 +ExpMatch"),
  tt(m3, vcovs$M3, "M3 +EED (H2)"),
  tt(m4, vcovs$M4, "M4 +EEDxExpMatch (H4)")
)
save_table(table_II, "table_II")

# --- H4 simple slopes: implied EED log-odds at low/mean/high match -----------
# marginal EED slope = b_EED + b_interaction * ExpMatch_z
b_eed <- coef(m4)["EED_z"]; b_int <- coef(m4)["EED_x_ExpMatch"]
simple <- data.frame(
  ExpMatch_z = c(-1, 0, 1),
  level      = c("Low (-1)", "Mean (0)", "High (+1)"),
  implied_EED_logodds = round(b_eed + b_int * c(-1, 0, 1), 3)
)
save_table(simple, "table_II_marginal_eed_by_expmatch")
print(simple)   # EXPECTED: +0.007 / -0.012 / -0.031

message(sprintf("  AIC: M3=%.0f  M4=%.0f  (paper 2,176,970 / 2,176,784)",
                AIC(m3), AIC(m4)))
# TODO(revision-program): Ai & Norton (2003) probability-scale interaction; the
#   log-odds sign need not match the probability-scale sign given ExpMatch beta ~ +1.
message("04_h2_h4_reply_likelihood.R done -> table_II.csv (+ simple slopes)")
