# RUN.md

This document explains how to reproduce the project in **Google BigQuery** without changing the scientific behavior of the pipeline.

## Prerequisites

1. Obtain credentialed access to **eICU-CRD v2.0** through PhysioNet.
2. Confirm the dataset is queryable in BigQuery as `physionet-data.eicu_crd.*`.
3. Create a GCP project with BigQuery enabled and billing configured for persistent outputs and model training. The audit project initially had disabled billing; the owner enabled billing before regeneration.
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
| 4 | `sql/04_features_labs.sql` | Add lab features and produce the final feature table | `features_v4_pit` |
| 5 | `sql/05_train_rows.sql` | Create row-level target `y` for each patient-hour | `train_rows_v4_pit` |
| 6 | `sql/06_splits.sql` | Assign hospitals to train/val/test splits | `split_hospital_v1` |
| 7 | `sql/07_model_table.sql` | Join row-level data to cohort and split assignments | `model_table_v4_pit` |
| 8 | `sql/08_bqml_models.sql` | Train the BigQuery ML logistic regression model | `bqml_lr_v4_pit` |
| 9 | `sql/09_eval_alert_rate.sql` | Create test predictions and compute precision in the corpus-wide top 0.5% | `preds_test_v4_pit` |
| 10 | `sql/10_eval_temporal_alert_tiers.sql` | Run corrected repeated-alert persistence tiers and regression assertion; new tier results are saved separately; defective historical results remain withdrawn | query result |
| 11 | `sql/11_eval_first_crossing_cooldown.sql` | Analyze first-crossing alerts with a quiet-period debounce in which suppressed crossings reset the window | query result |

## Model Selection Boundary

This repo intentionally publishes one **prespecified final-model path**:

- hospital-level splits are materialized as `train`, `val`, and `test`
- the executable path uses `CUSTOM`: `train` fits the model; all `val` rows are evaluation rows for early stopping
- `EARLY_STOP=TRUE`, `MIN_REL_PROGRESS=0.01`, maximum 50 iterations, and L2=1 are explicit
- `test` never enters model creation; no hyperparameter or threshold sweep is performed

For the PIT audit, reuse existing `cohort_v1`, `labels_v2`, `features_v2`, and
`split_hospital_v1`. Run only 04, 05, 07, 08, 09, then the evaluation/export
queries. This preserves original v3/v4 objects and split assignments. The
`v4_pit` suffix is intentional: a historical `v4` already exists.

See `audit/2026-09-05/pit_v4/SPECIFICATION.md` for the fixed protocol and
`audit/2026-09-05/pit_v4/REPORT.md` for the actual execution status. A PIT-only
AUTO_SPLIT control is specified solely to isolate the validation-split effect;
it cannot replace the final CUSTOM model based on test results.

## Expected Core Artifacts

- Cohort: `{{PROJECT_ID}}.icu_ml.cohort_v1`
- Labels: `{{PROJECT_ID}}.icu_ml.labels_v2`
- Vitals features: `{{PROJECT_ID}}.icu_ml.features_v2`
- Final features: `{{PROJECT_ID}}.icu_ml.features_v4_pit`
- Row-level labels: `{{PROJECT_ID}}.icu_ml.train_rows_v4_pit`
- Split table: `{{PROJECT_ID}}.icu_ml.split_hospital_v1`
- Model table: `{{PROJECT_ID}}.icu_ml.model_table_v4_pit`
- Trained model: `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit`
- Test predictions: `{{PROJECT_ID}}.icu_ml.preds_test_v4_pit`

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

The historical v3 export remains under `artifacts/reference_run/`. Do not
overwrite it with new outputs. Export completed PIT results to
`artifacts/reference_run_v4_pit/` with SQL hashes and BigQuery job metadata.
PIT performance results are published only after training and evaluation complete.

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
