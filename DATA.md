# Data Inventory & Variable Dictionary

This pipeline reads large pre-built `.rds` files produced by the upstream
measurement pipeline (LIWC, LDA, politeness, Flesch, SSBC-LLM scoring). **None of
these are committed** (`.gitignore` excludes `*.rds`, `*.csv`, `data/`, `raw/`).
Set `DATA_DIR` in `config.R` to the folder that holds them.

## 1. Input files the scripts expect

| File | Size | Used by | Role |
|------|------|---------|------|
| `MyDataLogit.rds` | ~4.4 GB | `01_prepare_data.R` | **Dyad-level frame.** One row per (focal post × candidate provider). Source of the dyad, realized-reply, and post-level (after aggregation) samples. |
| `df_flesch.rds`   | ~35 MB  | `02_build_variables.R` | Per-text Flesch Reading Ease score, joined on `Date`. Built by the legacy `Flesh.R`. |
| `Reg_cleaned.rds` | ~208 MB | `01` (optional) | A pre-cleaned regression frame kept as a cross-check / fallback. |
| `data3.rds`       | ~2 MB   | `08_robustness.R` (Heckman) | Selection-model frame used to build the inverse Mills ratio (`IMR1`). |
| SSBC scores file  | —       | `06`, `07` | Per-dyad SSBC ordinal scores from Claude Sonnet 4.6: `v11_emotional_support` (0–2), `v11_instrumental_support` (0–3). Merged on `(timestamp, replier)` — see merge caveat below. |
| mimicry scores    | —       | `08_robustness.R` | Otterbacher et al. (2017) linguistic-mimicry empathy score (Appendix A). |

> The exact in-memory column names should be confirmed against `MyDataLogit.rds` at
> runtime (`01_prepare_data.R` prints `names(df)` and `nrow(df)`); the names below are
> taken from the project's `MyDataLogit_first_1000.csv` header and the v5 manuscript.

## 2. Analytic samples built in `01_prepare_data.R`

| Frame | N (paper) | Definition |
|-------|-----------|------------|
| `post_level`      | **31,046**    | Unique threads; dyads aggregated to the post. |
| `dyad_analytic`   | **7,476,224** | All constructed dyads with non-missing key covariates (realized rate 4.15%). |
| `realized`        | **310,375**   | Realized post–reply pairs with non-missing reply length (`WC.y`). |
| `merged_ssbc`     | **199,249**   | Realized dyads joined to SSBC scores (note the fan-out, §4 below). |

## 3. Variable dictionary (as used in the models)

### Dependent variables
| Name | Where | Definition | Transform |
|------|-------|-----------|-----------|
| `Count_reply`          | post  | # realized replies on the thread | `log(1+x)` |
| `total_reply_pts`      | post  | aggregate upvotes across the thread's replies | `log(1+x)` |
| `n_distinct_repliers`  | post  | # distinct members who replied | `log(1+x)` |
| `answer_or_not`        | dyad  | 1 if the focal provider replied, else 0 | — |
| `WC.y`                 | reply | reply word count (LIWC) | `log(1+x)` |
| `v11_emotional_support`| dyad  | SSBC Emotional Support, ordinal {0,1,2} | — |
| `v11_instrumental_support`| dyad | SSBC Instrumental Support, ordinal {0,1,2,3} | — |
| `points_thisqs`        | dyad  | upvotes the reply received (reply quality) | raw in Table V |

### Explanatory variables
| Name | Definition | Transform |
|------|-----------|-----------|
| `EED` | **anx.x + sad.x** (LIWC anxiety + sadness % of the *post*). Computed in `02_build_variables.R`. Theory: vulnerability-signaling affect. | z |
| `ExpMatch` | cosine(provider prior-history topic profile, focal-post topic distribution), 23-topic LDA | z |
| `EED:ExpMatch` | interaction term (H4) | product of z-scores |

### Control variables
| Name | Definition | Transform |
|------|-----------|-----------|
| `WC.x` | post word count (LIWC) | `log(1+x)`, then z |
| `Qs_breadth` | Shannon entropy of post topic distribution | z |
| `politeness` | Danescu-Niculescu-Mizil et al. (2013) politeness probability | z |
| `Days_in_reddit`, `Days_in_reddit.x` | provider tenure (days), seeker/provider variants | z |
| `PostKarma.x`, `CommKarma.x` | seeker reputation | `log(1+x)`, then z |
| `posemo.x`, `negemo.x` | LIWC positive / general-negative emotion (post) | z |
| `Tone`, `Analytic`, `Clout` | LIWC summary dims (post) — **post-level models only** | z |
| `Flesch` | Flesch Reading Ease of post (from `df_flesch.rds`) | z |
| `IMR1` | inverse Mills ratio from the Heckman selection step (`08`/Heckman) | — |
| topic FE | 23 LDA topic dummies — **post-level models only** | — |

### Legacy-name notes (so old scripts line up with the v5 paper)
- The exploratory script `ETM_output/Logit2025.R` builds `suffer.x = AI_anxiety + AI_sadness`.
  The **v5 paper supersedes this** with `EED = anx.x + sad.x` (LIWC, not LLM). The
  reproduction uses the v5 (LIWC) definition; `suffer.x` is retained only as a
  commented alternative.
- `EC` / `EC1` in the data are earlier empathic-concern scores; the v5 analysis does
  **not** use them in the main tables.
- SSBC labels `ER_label` / `IP_label` / `EX_label` in some merged CSVs are the
  Sharma et al. EPITOME mechanisms (Emotional Reactions / Interpretations /
  Explorations); the v5 SSBC outcomes are the `v11_emotional_support` /
  `v11_instrumental_support` ordinals, not these labels.

## 4. Known data caveats reproduced (not fixed)

1. **SSBC merge fan-out.** Join key `(timestamp, replier)` has no thread id and is
   not unique: 197,060 scored dyads → **199,249** rows. Tables IV–V are computed on
   the 199,249-row frame *as reported*. Corrected thread-key merge = revision-program TODO.
2. **Exposure unobserved.** No impression/view data; risk-set membership is proxied by
   activity elsewhere in the 48-h window. Dyad-level estimates are ITT-style.
3. **Unclustered SEs** in Tables II–V (see README §6).

## 5. Reproducing the upstream measurement (pointers, not re-run here)

The text-derived measures are produced *before* this pipeline and are taken as inputs:
- **LIWC 2015**: anx/sad/posemo/negemo/Tone/Analytic/Clout/WC — external software.
- **23-topic LDA**: `ETM_output/` topic scripts → `ExpMatch`, `Qs_breadth`, topic FE.
- **Politeness**: Danescu et al. (2013) classifier (`for_politeness.csv` → `politeness`).
- **Flesch**: `ETM_output/Flesh.R` (custom syllable counter) → `df_flesch.rds`.
- **SSBC**: Claude Sonnet 4.6 with the v11 ordinal rubric (prompt in the Online
  Supplement); reliability subsample scored by 4 LLMs (Appendix B).
- **Mimicry**: Otterbacher et al. (2017) (Appendix A).
- **Heckman selection / IMR1**: `ETM_output/Heckman Test.R`.
