# ICU Code Blue Early Warning

**Version 2.0.0-pit — point-in-time correction and held-out rerun completed.** Lab features now require the later of draw and revised-entry time to precede prediction. The model uses the explicit hospital-validation set for early stopping. See [the full old/new audit](audit/2026-09-05/pit_v4/REPORT.md).

Clinical prediction tools do not fail only because the model is weak. They fail when alert policy, workflow fit, validation design, and deployment constraints are treated as afterthoughts.

This project is a retrospective ICU risk-modeling artifact using eICU data with
hospital-level holdout validation and a corpus-wide top-0.5% percentile
evaluation. That retrospective percentile is not a per-shift or per-census
operational alert budget.

It is a self-directed research prototype, not a clinically validated alerting system or bedside deployment. The goal is to show careful risk-modeling judgment, explicit limitations, and separation between predictive signal and deployable clinical product.

## What This Evaluates

- Hospital-level generalization
- Retrospective corpus-wide top-0.5% performance
- Risk enrichment over baseline
- Alert-policy implications
- Model limitations and label caveats
- Clinical deployment boundaries

## Main Result — Point-in-Time Corrected Run

Across **2,078,011 patient-hours from 31 held-out hospitals**, the raw global
**top 0.5%** selected **10,391 alerts containing 36 positive documentation-proxy
windows**: **23.22x pooled enrichment (95% hospital-cluster bootstrap CI
11.45–41.53), 0.3465% PPV, and 11.61% positive-window recall**. Test prevalence
was 310/2,078,011 = 0.014918%. Within-hospital AUROC was **0.7348 weighted by
patient-hour volume and 0.7827 median** among the 21 hospitals with both classes.
Positive alerts occurred in **9 of 31 hospitals**, versus 7 in the prior run.
The endpoint remains a **documentation proxy, not adjudicated cardiac arrest**.

The hospital-mix expectation was 1.443 positive alerts versus 36 observed
(24.94x observed/expected), and 19/21 evaluable hospitals had AUROC above 0.5.
Hospital mix alone does not explain the ranking signal. The interval uses
100,000 whole-hospital resamples with fixed observed alert memberships; it does
not refit the model or choose a new percentile in each resample. Clinical
lead time and prospective benefit remain unestablished.

Held-out global ROC-AUC was 0.7292. **Log loss was 0.007776, worse than the
0.001502 constant training-prevalence baseline and the prior model's 0.002723.**
Log loss measures probabilistic prediction quality, not ranking alone. This
comparison contradicts a claim of better absolute probability estimates than
the baseline; it does not erase the separately measured ranking signal.

Before regeneration, Q1 confirmed future-entered lab values in **574,482 modeled
patient-hours**, including **106,328 test rows and 35 positive test windows**.
The prior 13.55x result was exposed to this defect. The correction's higher
point estimate does not make that defect harmless. The rerun also applies an
existing deterministic lab tie rule absent from the historical export; the
[version audit](audit/2026-09-05/pit_v4/REPORT.md) quantifies that separate change.
The final model and raw
0.5% percentile rule were fixed before the new results were examined.

First crossing retained 2,040 alerts/8 positive windows (0.3922% PPV); a 12-hour
quiet-period debounce retained 1,596/8 (0.5013% PPV). Suppressed crossings reset
the quiet period. The 23.22x headline describes the raw policy, and all counts
are patient-hour proxy windows, not deduplicated cardiac arrests.
See [old versus new results](docs/results.md), the
[full version audit](audit/2026-09-05/pit_v4/REPORT.md), and
[new aggregate exports](artifacts/reference_run_v4_pit/).

## Scope Boundary

This repository is a retrospective evaluation artifact, not a deployable
clinical alerting system. It has no real-time data pipeline, bedside workflow
integration, prospective validation, external-dataset validation, local
calibration study, or clinical impact evaluation. The outcome is derived from
documentation strings rather than adjudicated cardiac-arrest events, and the
retrospective scoring grid uses a future discharge timestamp as its endpoint.
See the [`MODEL_CARD.md`](MODEL_CARD.md) for intended use and limitations.

## Evaluation Snapshot

- **Clinical task:** rank ICU patient-hours by risk of falling within 2 hours before the chart-entry offset of a documented code-event / resuscitation proxy; true clinical lead time is not established because charting lag is uncharacterized
- **Data:** eICU-CRD v2.0 via BigQuery; no patient-level data are redistributed
- **Model:** BigQuery ML logistic regression with vitals + labs
- **Prediction cadence:** hourly
- **Lookback / horizon:** previous 6 hours to predict proximity within 2 hours of proxy documentation time, not the clinical event time
- **Validation:** hospital-level train/val/test split; the new specification fits `train`, uses all `val` hospitals for early stopping, and reserves `test` for evaluation
- **Primary metric:** precision in the corpus-wide top 0.5% of held-out test rows
- **Evidence:** aggregate-only queries in `artifacts/queries/`, new exports in `artifacts/reference_run_v4_pit/`, and exact job/query provenance in `audit/2026-09-05/pit_v4/`

The model is intentionally simple and interpretable. Evaluation design and
alert policy are treated as first-class parts of the artifact rather than as
afterthoughts to model discrimination.

## Problem Definition

Each row is a patient-hour.

- Outcome: earliest qualifying documented code-event / resuscitation proxy built from diagnosis and treatment string matches
- Prediction horizon: within 2 hours before the proxy documentation offset;
  charting lag is uncharacterized, so true clinical lead time is not established
- Lookback window: prior 6 hours; labs must also have draw and revised-entry offsets both known and strictly before prediction time
- Early-event exclusion: stays with qualifying proxy events in the first 6 ICU hours are dropped from the downstream dataset entirely
- Population: numeric ages 18–120; top-coded `> 89` and other nonnumeric ages are excluded. No `unittype` filter is applied. The base stay criterion is six hours, but the prediction grid requires at least eight hours to produce a modeled row.

This framing turns the problem into short-term temporal risk ranking rather than one-time stay-level classification.

Revision notes (June 2026):

- The 2-hour horizon is measured against diagnosis/treatment chart-entry
  offsets, not adjudicated bedside event timestamps. Charting lag is not
  characterized, so true clinical lead time may be shorter, absent, or negative
  and is not established by this repo.
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

Naively alerting on every hour in the retrospective corpus-wide top 0.5% can create repeated alerts on the same patient. This repo therefore evaluates post-model alerting logic separately from model training:

- first-crossing alerts
- a 12-hour quiet-period debounce in which suppressed crossings reset the window

The corrected persistence-tier query and its regression assertion were rerun.
Its aggregate results are in `audit/2026-09-05/pit_v4/tier_metrics.csv`; the
defective historical tier results remain withdrawn.

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
│   ├── reference_run/            Historical v3 aggregate outputs (before PIT correction)
│   └── reference_run_v4_pit/     Point-in-time corrected aggregate outputs
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
