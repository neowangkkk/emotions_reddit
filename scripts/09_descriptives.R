# =============================================================================
# 09_descriptives.R — descriptive statistics + correlation tables
# -----------------------------------------------------------------------------
# INPUT  : outputs/cache/{post_model,dyad_model,realized_model,merged_ssbc}.rds
# OUTPUT : outputs/tables/descriptives_<sample>.csv
#          outputs/tables/correlations_dyad.csv
#
# Produces the Table D1-D2 descriptive material the paper flags as required for
# the final version (§4.4). Reports mean/sd/min/max/n-missing for each analysis
# variable on each sample, and the predictor correlation matrix on the dyad frame
# (the paper cites EED-negemo r = 0.71 and EED VIF = 2.11 from here).
# =============================================================================

if (file.exists("config.R")) source("config.R") else source("../config.R")
source("R/utils.R")

describe_frame <- function(d, vars) {
  vars <- intersect(vars, names(d))
  do.call(rbind, lapply(vars, function(v) {
    x <- d[[v]]
    data.frame(variable = v,
               n        = sum(!is.na(x)),
               n_miss   = sum(is.na(x)),
               mean     = round(mean(x, na.rm = TRUE), 4),
               sd       = round(sd(x,   na.rm = TRUE), 4),
               min      = round(min(x,  na.rm = TRUE), 4),
               max      = round(max(x,  na.rm = TRUE), 4),
               stringsAsFactors = FALSE)
  }))
}

# Variables of interest per sample (untransformed where it aids interpretation).
post_vars <- c("Count_reply","total_reply_pts","n_distinct_repliers",
               "EED","Qs_breadth","WC.x","politeness","posemo.x","negemo.x",
               "Tone","Analytic","Clout")
dyad_vars <- c("answer_or_not","EED","ExpMatch","WC.x","Qs_breadth","politeness",
               "Days_in_reddit","PostKarma.x","CommKarma.x","posemo.x","negemo.x")
real_vars <- c("WC.y","EED","ExpMatch","WC.x","politeness","posemo.x","negemo.x")
ssbc_vars <- c("v11_emotional_support","v11_instrumental_support","points_thisqs",
               "EED","ExpMatch","WC.y")

for (s in c("post_model","dyad_model","realized_model","merged_ssbc")) {
  f <- file.path(CACHE_DIR, paste0(s, ".rds"))
  if (!file.exists(f)) { message("skip ", s, " (not built yet)"); next }
  d <- readRDS(f)
  vars <- switch(s, post_model = post_vars, dyad_model = dyad_vars,
                 realized_model = real_vars, merged_ssbc = ssbc_vars)
  save_table(describe_frame(d, vars), paste0("descriptives_", sub("_model","",s)))
}

# Predictor correlation matrix on the dyad frame (for EED-negemo r, VIF context).
dyad <- readRDS(file.path(CACHE_DIR, "dyad_model.rds"))
cor_vars <- intersect(c("EED","ExpMatch","WC.x","Qs_breadth","politeness",
                        "Days_in_reddit","PostKarma.x","CommKarma.x",
                        "posemo.x","negemo.x"), names(dyad))
C <- cor(dyad[, cor_vars], use = "pairwise.complete.obs")
save_table(as.data.frame(round(C, 3)) |> tibble::rownames_to_column("variable"),
           "correlations_dyad")
message(sprintf("  cor(EED, negemo.x) = %.2f  (paper 0.71)", C["EED","negemo.x"]))
message("09_descriptives.R done.")
