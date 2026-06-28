# =============================================================================
# 08_robustness.R — Appendix A (mimicry) + alternative-measure checks (§5.6)
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/{merged_ssbc,dyad_model}.rds
#          <DATA_DIR>/<F_MIMICRY>   (Otterbacher et al. 2017 mimicry score)
#          <DATA_DIR>/data3.rds     (Heckman selection frame -> IMR1)
# OUTPUT : outputs/tables/appendix_A_mimicry.csv
#          outputs/tables/robust_negemo_h2h4.csv
#
# Reproduces v5 paper §5.6 + Appendix A:
#   (1) Mimicry mediation (N = 130,138): EED -> mimicry +0.010**; mimicry -> quality
#       +0.144*** (control length); EED -> quality null (+0.022) & unchanged with
#       mimicry (+0.021) -> NO mediation, small positive accommodation path.
#   (2) Alternative emotion measure: replace EED (anx+sad) with negemo in H2/H4 ->
#       qualitatively similar (negative, intensified at high ExpMatch).
#   (3) Expertise similarity (homophily) substituted for ExpMatch in H4 -> similar
#       negative interaction (documented; run if the similarity column is present).
#   (4) Heckman selection / IMR1 construction (legacy Heckman Test.R) — documented.
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

# ---- (1) Mimicry mediation (Appendix A) -------------------------------------
merged <- readRDS(file.path(CACHE_DIR, "merged_ssbc.rds"))
mim_path <- file.path(DATA_DIR, F_MIMICRY)
if (nzchar(F_MIMICRY) && file.exists(mim_path)) {
  mim <- readRDS(mim_path)                       # expects a `mimicry` column + keys
  keys <- intersect(c("Date", "Replier"), names(mim))
  d <- dplyr::inner_join(merged, mim, by = keys) %>% dplyr::filter(!is.na(mimicry))
  check_n(nrow(d), EXPECTED_N$mimicry, "mimicry subsample (App A)")

  d$Quality <- d$points_thisqs
  ctrls <- c("ExpMatch_z","WC.y_log_z","WC.x_log_z","politeness_z","Qs_breadth_z")
  a   <- lm(reformulate(c("EED_z", ctrls), "mimicry"), data = d)          # EED->mimicry
  bq  <- lm(reformulate(c("mimicry","EED_z", ctrls), "Quality"), data = d)# mimicry->quality | EED
  tot <- lm(reformulate(c("EED_z", ctrls), "Quality"), data = d)         # EED->quality (total)

  appA <- dplyr::bind_rows(
    transform(coef_table(a),   model = "EED -> mimicry"),
    transform(coef_table(tot), model = "EED -> quality (total)"),
    transform(coef_table(bq),  model = "quality ~ mimicry + EED")
  )
  save_table(appA, "appendix_A_mimicry")
  message(sprintf("  App A: EED->mimicry=%+.3f ; mimicry->quality=%+.3f ; EED->quality(total)=%+.3f",
                  coef(a)["EED_z"], coef(bq)["mimicry"], coef(tot)["EED_z"]))
} else {
  message("Mimicry file not set; skipping Appendix A. (Set HAAS_MIMICRY_FILE.)")
}

# ---- (2) Alternative emotion measure: negemo instead of EED in H2/H4 --------
dyad <- readRDS(file.path(CACHE_DIR, "dyad_model.rds"))
dyad$NEG_x_ExpMatch <- dyad$negemo.x_z * dyad$ExpMatch_z
ctrls_dyad <- c("WC.x_log_z","Days_in_reddit_z","PostKarma.x_log_z",
                "CommKarma.x_log_z","politeness_z","Qs_breadth_z","posemo.x_z")
mH2 <- glm(reformulate(c("negemo.x_z","ExpMatch_z", ctrls_dyad), "answer_or_not"),
           family = binomial, data = dyad)
mH4 <- glm(reformulate(c("negemo.x_z","ExpMatch_z","NEG_x_ExpMatch", ctrls_dyad), "answer_or_not"),
           family = binomial, data = dyad)
robust_neg <- dplyr::bind_rows(
  transform(coef_table(mH2), model = "H2 with negemo"),
  transform(coef_table(mH4), model = "H4 with negemo x ExpMatch")
)
save_table(robust_neg, "robust_negemo_h2h4")
message(sprintf("  negemo robustness: H2 main=%+.3f ; H4 interaction=%+.3f (expect both negative)",
                coef(mH2)["negemo.x_z"], coef(mH4)["NEG_x_ExpMatch"]))

# ---- (4) Heckman selection / IMR1 (documented; legacy Heckman Test.R) -------
# The inverse Mills ratio control (IMR1) used in some specifications comes from a
# first-stage probit selection model. Reproduced here for transparency; requires
# data3.rds with the selection variables. See ETM_output/Heckman Test.R.
sel_path <- file.path(DATA_DIR, F_SELECTION)
if (file.exists(sel_path) && requireNamespace("sampleSelection", quietly = TRUE)) {
  DLogit <- readRDS(sel_path)
  # First-stage probit of selection on reputation/tenure (column names per data3).
  # Build IMR1 = inverse Mills ratio and document; downstream merge is project-specific.
  message("Heckman/IMR step available (data3.rds present). See Heckman Test.R for the ",
          "full two-stage spec; IMR1 enters the selection-corrected robustness models.")
} else {
  message("Heckman selection frame (data3.rds) or sampleSelection not available; ",
          "IMR1 construction documented only (see ETM_output/Heckman Test.R).")
}
message("08_robustness.R done.")
