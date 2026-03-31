# RUN.md

This document explains how to reproduce the project in **Google BigQuery** without changing the scientific behavior of the pipeline.

## Prerequisites

1. Obtain credentialed access to **eICU-CRD v2.0** through PhysioNet.
2. Confirm the dataset is queryable in BigQuery as `physionet-data.eicu_crd.*`.
3. Create a GCP project with BigQuery enabled.
4. Create a writable BigQuery dataset for outputs. This repo assumes `icu_ml`.

No source data are bundled in this repository.

## Before You Run Anything

Replace `{{PROJECT_ID}}` in every SQL file with your own GCP project ID.

Example:

- `{{PROJECT_ID}}.icu_ml.cohort_v1`
- `my-gcp-project.icu_ml.cohort_v1`

This repo intentionally leaves the placeholder in version control so the SQL remains portable.

If you do not want to edit the canonical SQL files in place, you can generate runnable copies with:

```bash
make prepare PROJECT_ID=my-gcp-project
```

This creates rendered copies under `out/sql_rendered/` and preserves the canonical files in `sql/`.

## Execution Order

Run the SQL files in numeric order.

| Step | File | Purpose | Output |
|---|---|---|---|
| 1 | `sql/01_cohort.sql` | Build the adult ICU cohort with minimum ICU length of stay | `cohort_v1` |
| 2 | `sql/02_labels.sql` | Construct earliest qualifying documented code-event / resuscitation proxy labels | `labels_v2` |
| 3 | `sql/03_features_vitals.sql` | Build hourly vitals features over a 6-hour lookback | `features_v2` |
| 4 | `sql/04_features_labs.sql` | Add lab features and produce the final feature table | `features_v3` |
| 5 | `sql/05_train_rows.sql` | Create row-level target `y` for each patient-hour | `train_rows_v3` |
| 6 | `sql/06_splits.sql` | Assign hospitals to train/val/test splits | `split_hospital_v1` |
| 7 | `sql/07_model_table.sql` | Join row-level data to cohort and split assignments | `model_table_v3` |
| 8 | `sql/08_bqml_models.sql` | Train the BigQuery ML logistic regression model | `bqml_lr_v3` |
| 9 | `sql/09_eval_alert_rate.sql` | Create test predictions and compute precision at top 0.5% | `preds_test_v3` |
| 10 | `sql/10_eval_temporal_alert_tiers.sql` | Analyze repeated-alert persistence tiers | query result |
| 11 | `sql/11_eval_first_crossing_cooldown.sql` | Analyze first-crossing alerts with cooldown logic | query result |

## Model Selection Boundary

This repo intentionally publishes one **prespecified final-model path**:

- hospital-level splits are materialized as `train`, `val`, and `test`
- the executable path trains the fixed final model on `train` only
- the repo does **not** reproduce a validation-driven benchmark sweep across
  alternative feature sets or random-split baselines

Treat `val` as reserved for future model-selection work rather than evidence of
an implemented tuning pipeline in this version of the repo.

## Expected Core Artifacts

- Cohort: `{{PROJECT_ID}}.icu_ml.cohort_v1`
- Labels: `{{PROJECT_ID}}.icu_ml.labels_v2`
- Vitals features: `{{PROJECT_ID}}.icu_ml.features_v2`
- Final features: `{{PROJECT_ID}}.icu_ml.features_v3`
- Row-level labels: `{{PROJECT_ID}}.icu_ml.train_rows_v3`
- Split table: `{{PROJECT_ID}}.icu_ml.split_hospital_v1`
- Model table: `{{PROJECT_ID}}.icu_ml.model_table_v3`
- Trained model: `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`
- Test predictions: `{{PROJECT_ID}}.icu_ml.preds_test_v3`

## Recommended Sanity Checks

- After `sql/02_labels.sql`, inspect positive prevalence and event timing.
- After `sql/05_train_rows.sql`, inspect row count and prevalence of `y=1`.
- After `sql/06_splits.sql`, confirm hospitals are distributed across train, val, and test.
- After `sql/07_model_table.sql`, confirm split counts and positive counts per split.
- After `sql/09_eval_alert_rate.sql`, record top-0.5% alert volume and precision and export them with `artifacts/queries/02_reference_run_operating_point.sql`.

Several SQL files contain optional commented sanity-check snippets you can run manually.

## Reviewer-Facing Aggregate Exports

After running the pipeline, use the queries in `artifacts/queries/` to export
aggregate-only proof artifacts for reviewers:

- cohort / split / prevalence counts
- held-out operating-point metrics
- naive vs debounced alert-policy counts
- model coefficients via `ML.WEIGHTS`

The current checked-in corrected reference export lives under
`artifacts/reference_run/`. Regenerate that directory only after a fresh rerun
of the current SQL.

## Runtime Notes

Runtime depends on BigQuery quotas and table sizes. Feature creation and prediction steps are usually the most expensive.

## High-Sensitivity Warning

The following files directly define scientific behavior and should not be edited casually during maintenance work:

- `sql/01_cohort.sql`
- `sql/02_labels.sql`
- `sql/03_features_vitals.sql`
- `sql/04_features_labs.sql`
- `sql/05_train_rows.sql`
- `sql/06_splits.sql`
- `sql/08_bqml_models.sql`
- `sql/09_eval_alert_rate.sql`
- `sql/10_eval_temporal_alert_tiers.sql`
- `sql/11_eval_first_crossing_cooldown.sql`

Changing those files can affect cohort definition, labels, feature semantics, leakage boundaries, split logic, model behavior, alerting logic, or reported metrics.

## Local Verification

For a quick repository-level smoke check, run:

```bash
make smoke
```

This does not run BigQuery jobs. It only validates local repository structure and placeholder consistency.
