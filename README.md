# ICU Code Blue Early Warning

Clinical prediction tools do not fail only because the model is weak. They fail when alert policy, workflow fit, validation design, and deployment constraints are treated as afterthoughts.

This project is a retrospective ICU risk-modeling artifact using eICU data with hospital-level holdout validation and fixed alert-budget evaluation. The focus is not just whether a model can rank risk, but whether the evaluation design makes the output interpretable for real clinical workflow discussions.

It is a self-directed research prototype, not a clinically validated alerting system or bedside deployment. The goal is to show calibrated risk-modeling judgment, explicit limitations, and separation between predictive signal and deployable clinical product.

## What This Evaluates

- Hospital-level generalization
- Fixed alert-budget performance
- Risk enrichment over baseline
- Alert-policy implications
- Model limitations and label caveats
- Clinical deployment boundaries

## Main Result

The held-out test split contained 31 hospitals, 2,078,011 patient-hours, and 310
positive labeled windows. A fixed alert budget covering the top 0.5% of scored
patient-hours selected 10,391 rows containing 21 positive windows: 0.2021%
precision versus 0.0149% prevalence across the test split, or **13.55x risk
enrichment over baseline**. Held-out `ML.EVALUATE` results were ROC-AUC 0.6377
and log loss 0.002723.

Post-model policy analysis shows the operational tradeoff behind that result.
Restricting alerts to first crossings reduced volume to 3,350 alerts with 8
positive windows; adding a 12-hour cooldown reduced it to 2,650 alerts with 7
positive windows. These are row-level results for a chart-derived proxy label,
not deduplicated clinical events or evidence of improved patient outcomes. The
supporting aggregate export is checked in under
[`artifacts/reference_run/`](artifacts/reference_run/).

## Scope Boundary

This repository is a retrospective evaluation artifact, not a deployable
clinical alerting system. It has no real-time data pipeline, bedside workflow
integration, prospective validation, external-dataset validation, local
calibration study, or clinical impact evaluation. The outcome is derived from
documentation strings rather than adjudicated cardiac-arrest events, and the
retrospective scoring grid uses a future discharge timestamp as its endpoint.
See the [`MODEL_CARD.md`](MODEL_CARD.md) for intended use and limitations.

## Evaluation Snapshot

- **Clinical task:** rank ICU patient-hours by short-term documented code-event / resuscitation proxy risk
- **Data:** eICU-CRD v2.0 via BigQuery; no patient-level data are redistributed
- **Model:** BigQuery ML logistic regression with vitals + labs
- **Prediction cadence:** hourly
- **Lookback / horizon:** previous 6 hours to predict the next 2 hours
- **Validation:** hospital-level train/val/test split; the published path trains on `train` and reports held-out `test`
- **Primary metric:** precision at a fixed 0.5% alert rate
- **Evidence:** aggregate-only queries in `artifacts/queries/` and a checked-in reference export in `artifacts/reference_run/`

The model is intentionally simple and interpretable. Evaluation design and
alert policy are treated as first-class parts of the artifact rather than as
afterthoughts to model discrimination.

## Problem Definition

Each row is a patient-hour.

- Outcome: earliest qualifying documented code-event / resuscitation proxy built from diagnosis and treatment string matches
- Prediction horizon: next 2 hours
- Lookback window: prior 6 hours
- Minimum lead time: stays with events in the first 6 ICU hours are excluded from positive labeling

This framing turns the problem into short-term temporal risk ranking rather than one-time stay-level classification.

Revision notes (June 2026):

- The "next 2 hours" horizon is measured against diagnosis/treatment chart-entry
  offsets, not adjudicated bedside event timestamps. Actual clinical lead time
  may be shorter by the amount of documentation lag, which is not characterized
  in this repo.
- The prediction grid in `sql/03_features_vitals.sql` uses
  `unitdischargeoffset` as its endpoint and requires at least 120 minutes before
  ICU discharge. That conditions retrospective scoring on a future discharge
  timestamp and means the final 2 hours of each stay are not scored.
- The minimum lead-time implementation is stronger than "excluded from positive
  labeling": stays with qualifying events in the first 6 ICU hours are excluded
  from `labels_v2` and therefore from the downstream dataset entirely.
- The diagnosis string match includes broad ventricular tachycardia terms
  without distinguishing pulseless VT from stable/monitored VT, so the proxy
  positive class can include non-arrest events.

## Final Model

- Logistic regression in BigQuery ML
- L2 regularization
- Final feature set: vitals + labs
- Published as one prespecified final-model path
- Evaluated on held-out hospitals

The model output is used as a continuous ranking score. Alerting policy is treated separately from the model itself, and the current repo does not reproduce a benchmark sweep across alternative model versions.

## Alerting Insight

Naively alerting on every hour in the top 0.5% can create repeated alerts on the same patient. This repo therefore evaluates post-model alerting logic separately from model training:

- persistence tiers for diagnostic analysis
- first-crossing alerts with optional cooldown windows for analysis of alert suppression tradeoffs

The canonical queries for this work live in `sql/10_eval_temporal_alert_tiers.sql` and `sql/11_eval_first_crossing_cooldown.sql`. Aggregate reviewer exports for those analyses live in `artifacts/queries/`.

## Reviewer Guide

If you only have a few minutes:

1. Read this file for the project summary.
2. Read [`docs/methodology.md`](docs/methodology.md) for the pipeline design.
3. Read [`docs/results.md`](docs/results.md) for the performance summary.
4. Read [`RUN.md`](RUN.md) for reproducibility and execution order.
5. Read [`artifacts/README.md`](artifacts/README.md) for aggregate-only proof exports.
6. Read [`MODEL_CARD.md`](MODEL_CARD.md) and [`docs/supporting/INTENDED_USE.md`](docs/supporting/INTENDED_USE.md) for boundaries and limitations.

For a portfolio or product-style walkthrough, [`CASE_STUDY.md`](CASE_STUDY.md) is the fastest narrative artifact.
For a time-boxed hiring-manager path, see [`docs/reviewer_guide.md`](docs/reviewer_guide.md).

## Repository Map

```text
.
├── README.md                     Project summary and reviewer guide
├── CASE_STUDY.md                 Product/portfolio framing and design tradeoffs
├── MODEL_CARD.md                 Intended use, limitations, and evaluation boundaries
├── RUN.md                        BigQuery execution order and reproducibility notes
├── artifacts/
│   ├── README.md                 Aggregate-only proof export guide
│   ├── queries/                  Reviewer-facing aggregate SQL queries
│   └── reference_run/            Checked-in aggregate outputs from the corrected rerun
├── docs/
│   ├── change_policy.md         Maintenance boundary for sensitive SQL
│   ├── methodology.md            Concise scientific workflow description
│   ├── decision_log.md           Maintenance log and change boundaries
│   ├── hypothetical_deployment/  If-deployed governance notes
│   ├── supporting/               Lower-priority supporting docs
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

No source data are included in this repository. See [`docs/supporting/CITATION.md`](docs/supporting/CITATION.md).

### Reproduce the pipeline

1. Replace `{{PROJECT_ID}}` in the SQL files with your GCP project ID.
2. Run the SQL files in numeric order from [`sql/01_cohort.sql`](sql/01_cohort.sql) through [`sql/11_eval_first_crossing_cooldown.sql`](sql/11_eval_first_crossing_cooldown.sql).
3. Use [`RUN.md`](RUN.md) for expected outputs and manual sanity checks after key steps.
4. Run the aggregate-only proof queries in [`artifacts/queries/`](artifacts/queries/) to capture reviewer-friendly counts, operating-point metrics, and model weights.

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

Any edit to those files should be treated as a scientific change, not routine cleanup.

## Additional Documentation

- [`RUN.md`](RUN.md): exact execution order and output tables
- [`docs/reproducibility.md`](docs/reproducibility.md): assumptions, artifact provenance, and maintenance guidance
- [`docs/decision_log.md`](docs/decision_log.md): maintenance history and explicit non-semantic change log
- [`docs/validation_checklist.md`](docs/validation_checklist.md): manual rerun checks for key pipeline stages
- [`docs/reviewer_guide.md`](docs/reviewer_guide.md): fastest reading path for interview and portfolio review
- [`docs/change_policy.md`](docs/change_policy.md): maintenance boundary for high-sensitivity SQL files
- [`artifacts/README.md`](artifacts/README.md): aggregate-only proof export guide
- [`MODEL_CARD.md`](MODEL_CARD.md): intended use, limitations, and monitoring
- [`docs/supporting/FAILURE_MODES.md`](docs/supporting/FAILURE_MODES.md): failure analysis and safety posture
- [`docs/supporting/PRD.md`](docs/supporting/PRD.md): retrospective product-framing artifact
- [`docs/hypothetical_deployment/PCCP.md`](docs/hypothetical_deployment/PCCP.md): bounded if-deployed change-control notes

## License

MIT
