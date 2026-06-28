# Data Analysis Pipeline — "Attention Without Reply"

## 1. What the study does

Using ~31k threads from r/Entrepreneur (2012–2017), the paper asks how
**expressed emotional distress (EED)** in a help-seeking post relates to the help
it receives, at two levels: **post-level attention** (does the thread draw
engagement?) and **dyad-level reply commitment** (does a given community member
reply?). The headline pattern is an *attention–reply divergence*: emotional cues
are associated with **more** aggregate attention (H1) but **lower** per-candidate
reply probability (H2), and the deterrence is **strongest among the best-matched
experts** (H4). It then looks at the form (H3a reply length; H3b SSBC emotional vs.
instrumental support) and quality (H5 mediation) of realized replies.

## 2. The five hypotheses → five tables

| Hypothesis | Table | Sample (N)              | Model                                   | Script |
|-----------|-------|-------------------------|-----------------------------------------|--------|
| **H1** post-level attention | I   | post-level (31,046)        | OLS, 3 log attention DVs + topic FE     | `03_h1_post_attention.R` |
| **H2** reply likelihood     | II  | dyad-level (7,476,224)     | binary logit of `answer_or_not`         | `04_h2_h4_reply_likelihood.R` |
| **H4** expertise × EED      | II (M4) | dyad-level (7,476,224) | logit + `EED × ExpMatch` interaction    | `04_h2_h4_reply_likelihood.R` |
| **H3a** reply length        | III | realized replies (310,375) | OLS of `log(1+WC.y)`                     | `05_h3a_reply_length.R` |
| **H3b** SSBC support        | IV  | merged SSBC (199,249)      | proportional-odds ordinal logit (×2)    | `06_h3b_ssbc_ordinal.R` |
| **H5** quality mediation    | V   | merged SSBC (199,249)      | Baron–Kenny 3-step OLS                   | `07_h5_mediation.R` |
| Robustness (mimicry, negemo, similarity) | A | 130,138 / dyad | mediation + alt-measure re-estimation | `08_robustness.R` |

## 3. Pipeline at a glance

```
raw corpus (not distributed; Reddit ToS)
      │   [measurement done upstream: LIWC, 23-topic LDA, politeness, Flesch, SSBC-LLM]
      ▼
01_prepare_data.R     load MyDataLogit.rds → build the 4 analytic frames (listwise)
      ▼
02_build_variables.R  EED = anx+sad; ExpMatch & Qs_breadth from LDA; logs; z-scores; IMR
      ▼
03..07  estimate H1–H5  →  outputs/tables/table_I … table_V.csv
08      robustness       →  outputs/tables/appendix_A_*.csv
09      descriptives      →  outputs/tables/descriptives_*.csv
```

Run everything with:

```bash
cd reproduction
Rscript run_all.R            # runs 00 → 09 in order
# or a subset:
Rscript run_all.R 03 04      # just H1 and H2/H4
```

Each script can also be run on its own (`Rscript scripts/04_h2_h4_reply_likelihood.R`);
they read/write intermediate `.rds` files under `outputs/` so steps are cached.

## 4. Setup

- **R ≥ 4.2.** Install dependencies once with `Rscript scripts/00_setup.R`
  (it lists and installs every package and prints `sessionInfo()` to
  `outputs/sessioninfo.txt`).
- Core packages: `dplyr`, `readr`, `tidyr`, `MASS` (ordinal `polr`),
  `sandwich` + `lmtest` (clustered SEs), `sampleSelection` (Heckman/IMR),
  `broom`, `stringr`. Firth logistic (`logistf`) is optional (exploratory only).
- Set the data path in `config.R` (`DATA_DIR`) to wherever the `.rds` files live.

## 5. Variables (full definitions in `DATA.md`)

- **EED** (expressed emotional distress) = LIWC `anx.x` + `sad.x` on the **post** text.
- **ExpMatch** = cosine similarity between the provider's prior-history topic profile
  and the focal post's 23-topic LDA distribution.
- **Qs_breadth** = Shannon entropy of the post's topic distribution.
- **Controls**: `WC.x` (post length, log1p), `Qs_breadth`, `politeness`,
  `Days_in_reddit(.x)` (tenure), `PostKarma.x`/`CommKarma.x` (log1p), `posemo.x`,
  `negemo.x`, and (post-level only) `Tone`, `Analytic`, `Clout`, plus topic FE.
  `IMR1` = inverse Mills ratio from the Heckman selection step.
- All continuous predictors are **standardized (z)** before entering the models.

## 6. Outputs

Every script writes a CSV (and, where relevant, a formatted text table) under
`outputs/tables/`, named for the table it reproduces (`table_I.csv`, …). Figures
go to `outputs/figures/`. Nothing under `outputs/` except `.gitkeep` is committed.

## 7. Data availability & ethics

Public r/Entrepreneur content (2012–2017). Raw text is **not** redistributed
(Reddit's post-2023 access terms; user emotional disclosures). The committed
artifact is **code only**; derived identifiers and SSBC scores are released on
publication per the paper's data-availability statement (§4.6). No usernames are
stored in this repo. See `DATA.md` for exactly which files each script needs and
where they are expected to live.

## 8. File map

```
reproduction/
├── README.md                 ← this file
├── DATA.md                   ← data inventory + full variable dictionary
├── config.R                  ← paths, flags (CLUSTER_SE, …), package list
├── run_all.R                 ← orchestrator (00→09, or a subset)
├── R/
│   ├── utils.R               ← log1p_safe, zscore, coef-table + significance stars
│   └── measures.R            ← EED, ExpMatch, breadth, Flesch helper functions
├── scripts/
│   ├── 00_setup.R            ← install/load packages, sessionInfo
│   ├── 01_prepare_data.R     ← build the 4 analytic frames from MyDataLogit.rds
│   ├── 02_build_variables.R  ← EED, LDA→ExpMatch/breadth, logs, z-scores, IMR
│   ├── 03_h1_post_attention.R     ← Table I
│   ├── 04_h2_h4_reply_likelihood.R← Table II (Models 1–4)
│   ├── 05_h3a_reply_length.R      ← Table III
│   ├── 06_h3b_ssbc_ordinal.R      ← Table IV
│   ├── 07_h5_mediation.R          ← Table V
│   ├── 08_robustness.R            ← Appendix A + alt-measure checks
│   └── 09_descriptives.R          ← descriptive + correlation tables
└── outputs/{tables,figures}/  ← generated; git-ignored
```

---

