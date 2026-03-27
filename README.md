# ICU Code Blue Early Warning System

An interpretable ICU early warning project that estimates whether a patient-hour is entering elevated risk of documented cardiac arrest / CPR in the next 2 hours.

The repository is intentionally presented as a scientific and product artifact, not just a modeling notebook. The emphasis is on temporal correctness, conservative evaluation, operational realism, and honest boundaries.

## Two-Minute Overview

- **Clinical task:** rank ICU patient-hours by short-term code-blue risk
- **Data:** eICU-CRD v2.0 via BigQuery; no patient-level data are redistributed
- **Model:** BigQuery ML logistic regression with vitals + labs
- **Prediction cadence:** hourly
- **Lookback / horizon:** previous 6 hours to predict the next 2 hours
- **Validation:** hospital-level holdout split
- **Primary metric:** precision at a fixed 0.5% alert rate
- **Key operational insight:** debounced first-crossing alerts were more usable than naive repeated hourly alerts

## Why This Repo Exists

This project is meant to signal:

- practical ML fluency
- healthcare-aware evaluation design
- interpretable modeling discipline
- reproducibility and scientific restraint
- honest discussion of limitations and deployment risk

It is intentionally not a model-complexity demo. The main claim is that in this setting, evaluation design and alert policy matter as much as, or more than, squeezing out marginal AUC gains.

## Problem Definition

Each row is a patient-hour.

- Outcome: first documented in-ICU cardiac arrest / CPR event
- Prediction horizon: next 2 hours
- Lookback window: prior 6 hours
- Minimum lead time: stays with events in the first 6 ICU hours are excluded from positive labeling

This framing turns the problem into short-term temporal risk ranking rather than one-time stay-level classification.

## Final Model

- Logistic regression in BigQuery ML
- L2 regularization
- Final feature set: vitals + labs
- Trained on approximately 170k ICU stays
- Evaluated on held-out hospitals rather than random row splits

The model output is used as a continuous ranking score. Alerting policy is treated separately from the model itself.

## Main Results

| Model | Features | ROC-AUC | Precision @ 0.5% |
|---|---|---:|---:|
| LR v1 | Vitals | ~0.70 | 0.33% |
| LR v3 | Vitals + Labs | 0.73 | 0.44% |
| LR v4 | + Trends | 0.73 | 0.41% |

Baseline event prevalence is approximately **0.025%** per patient-hour, so the final model achieves about **18x enrichment** at a clinically constrained alert budget.

## Alerting Insight

Naively alerting on every hour in the top 0.5% creates repeated alerts on the same patient. This repo therefore also evaluates post-model alerting logic:

- persistence tiers for diagnostic analysis
- first-crossing alerts with optional cooldown windows for deployment-oriented alert suppression

Observed result: debounced first-crossing alerts reduced alert volume substantially while improving precision per alert.

## Reviewer Guide

If you only have a few minutes:

1. Read this file for the project summary.
2. Read [`docs/methodology.md`](docs/methodology.md) for the pipeline design.
3. Read [`docs/results.md`](docs/results.md) for the performance summary.
4. Read [`RUN.md`](RUN.md) for reproducibility and execution order.
5. Read [`MODEL_CARD.md`](MODEL_CARD.md) and [`INTENDED_USE.md`](INTENDED_USE.md) for boundaries, limitations, and deployment posture.

For a portfolio or product-style walkthrough, [`CASE_STUDY.md`](CASE_STUDY.md) is the fastest narrative artifact.
For a time-boxed hiring-manager path, see [`docs/reviewer_guide.md`](docs/reviewer_guide.md).

## Repository Map

```text
.
├── README.md                     Project summary and reviewer guide
├── RUN.md                        BigQuery execution order and reproducibility notes
├── MODEL_CARD.md                 Intended use, limitations, monitoring, governance
├── INTENDED_USE.md               Explicit safe-use and non-goal boundaries
├── CASE_STUDY.md                 Product/portfolio framing and design tradeoffs
├── FAILURE_MODES.md              Safety and workflow failure analysis
├── PCCP.md                       Predetermined change control plan
├── CITATION.md                   Dataset citation and access notes
├── docs/
│   ├── change_policy.md         Maintenance boundary for sensitive SQL
│   ├── methodology.md            Concise scientific workflow description
│   ├── decision_log.md           Maintenance log and change boundaries
│   ├── reviewer_guide.md         Fast path for hiring managers and interviewers
│   ├── reproducibility.md        Low-risk maintenance and sensitivity guide
│   ├── validation_checklist.md   Manual rerun and sanity-check checklist
│   └── results.md                Compact result summary
├── sql/
│   ├── 01_cohort.sql             Cohort definition
│   ├── 02_labels.sql             Event labeling
│   ├── 03_features_vitals.sql    Vitals feature engineering
│   ├── 04_features_labs.sql      Final feature engineering
│   ├── 05_train_rows.sql         Timepoint-level label construction
│   ├── 06_splits.sql             Hospital-level split logic
│   ├── 07_model_table.sql        Model-ready join table
│   ├── 08_bqml_models.sql        BQML training
│   ├── 09_eval_alert_rate.sql    Test predictions and precision@0.5%
│   ├── 10_eval_temporal_alert_tiers.sql
│   └── 11_eval_first_crossing_cooldown.sql
├── scripts/
│   ├── prepare_sql.sh            Render non-canonical runnable SQL copies
│   └── smoke_check.sh            Dependency-free repo integrity checks
└── Makefile                      Convenience target for local smoke checks
```

## Quick Start

### Data access

- Obtain credentialed access to **eICU Collaborative Research Database v2.0**
- Ensure it is queryable in BigQuery as `physionet-data.eicu_crd.*`
- Create a target dataset in your own GCP project, assumed here to be `icu_ml`

No source data are included in this repository. See [`CITATION.md`](CITATION.md).

### Reproduce the pipeline

1. Replace `{{PROJECT_ID}}` in the SQL files with your GCP project ID.
2. Run the SQL files in numeric order from [`sql/01_cohort.sql`](sql/01_cohort.sql) through [`sql/11_eval_first_crossing_cooldown.sql`](sql/11_eval_first_crossing_cooldown.sql).
3. Use [`RUN.md`](RUN.md) for expected outputs and manual sanity checks after key steps.

If you prefer not to edit the canonical SQL files, you can render runnable copies with:

```bash
make prepare PROJECT_ID=my-gcp-project
```

This writes substituted copies to `out/sql_rendered/` and leaves `sql/` unchanged.

### Local smoke check

Run:

```bash
make smoke
```

This only validates repository structure and SQL placeholder hygiene. It does not execute the model pipeline or touch BigQuery.

## High-Sensitivity Files

These files define scientific behavior and should not be edited casually:

- `sql/01_cohort.sql`: cohort inclusion semantics
- `sql/02_labels.sql`: label definition and event-source logic
- `sql/03_features_vitals.sql` and `sql/04_features_labs.sql`: feature meaning and temporal windows
- `sql/05_train_rows.sql`: outcome horizon and leakage boundary
- `sql/06_splits.sql`: train/validation/test split semantics
- `sql/08_bqml_models.sql`: model specification
- `sql/09_eval_alert_rate.sql`, `sql/10_eval_temporal_alert_tiers.sql`, `sql/11_eval_first_crossing_cooldown.sql`: evaluation and alert-policy analysis

This maintenance pass intentionally leaves those behaviors unchanged.

## Additional Documentation

- [`RUN.md`](RUN.md): exact execution order and output tables
- [`docs/reproducibility.md`](docs/reproducibility.md): assumptions, artifact provenance, and maintenance guidance
- [`docs/decision_log.md`](docs/decision_log.md): maintenance history and explicit non-semantic change log
- [`docs/validation_checklist.md`](docs/validation_checklist.md): manual rerun checks for key pipeline stages
- [`docs/reviewer_guide.md`](docs/reviewer_guide.md): fastest reading path for interview and portfolio review
- [`docs/change_policy.md`](docs/change_policy.md): maintenance boundary for high-sensitivity SQL files
- [`MODEL_CARD.md`](MODEL_CARD.md): intended use, limitations, and monitoring
- [`FAILURE_MODES.md`](FAILURE_MODES.md): failure analysis and safety posture
- [`PCCP.md`](PCCP.md): bounded post-deployment changes

## License

MIT
