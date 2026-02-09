# RUN.md — Reproducibility (BigQuery)

This repo is designed to be reproducible end-to-end in **Google BigQuery** using **eICU-CRD v2.0** (PhysioNet credentialed access required).

## Prerequisites
1. Obtain credentialed access to **eICU-CRD v2.0** on PhysioNet.
2. Ensure the dataset is accessible in BigQuery as `physionet-data.eicu_crd.*`.
3. Create a GCP project and enable BigQuery.
4. Choose a dataset in your project for outputs (this repo assumes `icu_ml`).

## One-time setup
Replace `{{PROJECT_ID}}` in all SQL files with your GCP project id (e.g., `my-gcp-project`).

Example:
- `{{PROJECT_ID}}.icu_ml.cohort_v1` → `my-gcp-project.icu_ml.cohort_v1`

## Execution order (run in sequence)
Run these files in order:

1. `sql/01_cohort.sql`  
   Builds the base adult ICU cohort with minimum LOS.

2. `sql/02_labels.sql`  
   Constructs the earliest “code blue / CPR” event label per ICU stay (with lead-time filter).

3. `sql/03_features_vitals.sql`  
   Creates hourly feature grid with 6h lookback vitals features.

4. `sql/04_features_labs.sql`  
   Adds lab features (lactate, pH, K, creatinine, Hgb, WBC) with numeric parsing.

5. `sql/05_train_rows.sql`  
   Creates timepoint labels (`y`) for each (stay, prediction_time) with horizon = next 2 hours.
   Excludes rows at/after the event time to reduce leakage.

6. `sql/06_splits.sql`  
   Creates a **hospital-level** split table (train/val/test).

7. `sql/07_model_table.sql`  
   Joins features + labels + hospital split into a model-ready table.

8. `sql/08_bqml_models.sql`  
   Trains the BigQuery ML logistic regression model on the training split.

9. `sql/09_eval_alert_rate.sql`  
   Produces test-set predictions and computes **precision @ 0.5% alert rate** (top 0.5% risk).

10. `sql/10_eval_temporal_alert_tiers.sql`  
   Evaluates **persistence tiers** (new vs repeat vs persistent) for the naive hourly alerting policy.

11. `sql/11_eval_first_crossing_cooldown.sql`  
   Evaluates **first-crossing alerts** with a configurable cooldown window (e.g., 6h/12h) to reduce alert spam.

## Notes on runtime
Runtime varies by quota and table sizes. Most steps complete in minutes; feature creation and prediction tables may take longer.

## Outputs (where to look)
- Cohort: `{{PROJECT_ID}}.icu_ml.cohort_v1`
- Labels: `{{PROJECT_ID}}.icu_ml.labels_v2`
- Features: `{{PROJECT_ID}}.icu_ml.features_v3`
- Model table: `{{PROJECT_ID}}.icu_ml.model_table_v3`
- Trained model: `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`
- Test predictions: `{{PROJECT_ID}}.icu_ml.preds_test_v3`

## Sanity checks (recommended)
- After `02_labels.sql`: verify event prevalence looks plausible.
- After `07_model_table.sql`: verify split counts and positive counts per split.
- After `09_eval_alert_rate.sql`: verify precision@0.5% and alert count are stable across reruns.
