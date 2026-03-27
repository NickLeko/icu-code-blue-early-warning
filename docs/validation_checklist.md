# Validation Checklist

This checklist is for manual verification after running the BigQuery pipeline. It is intentionally lightweight and does not change or automate the scientific workflow.

## Purpose

Use this checklist to confirm that a rerun still matches the intended project design before trusting any outputs or discussing results.

## Before Running

- Confirm you are using credentialed access to eICU-CRD v2.0
- Confirm the source tables are available as `physionet-data.eicu_crd.*`
- Confirm `{{PROJECT_ID}}` has been replaced in the runnable SQL you plan to execute
- Confirm you are not editing canonical SQL in `sql/` unless you intend a scientific change

## Step-Level Checks

### After `sql/01_cohort.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.cohort_v1`
- Spot-check that the cohort contains adult ICU stays only
- Spot-check that the minimum ICU stay filter is reflected in `unitdischargeoffset >= 360`

### After `sql/02_labels.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.labels_v2`
- Inspect positive prevalence at the stay level
- Inspect event-time plausibility for a small sample
- Confirm labeled events inside the first 6 ICU hours are excluded from the final label table

### After `sql/03_features_vitals.sql` and `sql/04_features_labs.sql`

- Verify `features_v2` and `features_v3` were created
- Confirm the feature tables are keyed by `patientunitstayid` and `prediction_time_min`
- Confirm the lookback logic remains `[t-6h, t)` rather than including future information
- Spot-check that lab parsing produced non-null values for the intended labs

### After `sql/05_train_rows.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.train_rows_v3`
- Inspect row-level prevalence of `y = 1`
- Confirm rows at or after the event time are excluded
- Confirm the positive-label window still corresponds to the next 2 hours

### After `sql/06_splits.sql`

- Verify the split table exists: `{{PROJECT_ID}}.icu_ml.split_hospital_v1`
- Confirm hospitals are assigned to train, val, and test
- Confirm the split is hospital-level rather than row-level

### After `sql/07_model_table.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.model_table_v3`
- Inspect row counts by split
- Inspect positive counts by split
- Confirm the expected join keys are populated

### After `sql/08_bqml_models.sql`

- Verify the model exists: `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`
- Confirm the final model is the vitals + labs logistic regression
- Confirm you trained on `split = 'train'` only

### After `sql/09_eval_alert_rate.sql`

- Verify the predictions table exists: `{{PROJECT_ID}}.icu_ml.preds_test_v3`
- Confirm evaluation is restricted to the held-out test split
- Confirm the top-0.5% alert rule is still implemented via `NTILE(200)`
- Compare alert volume and precision to the documented expected range

### After `sql/10_eval_temporal_alert_tiers.sql`

- Confirm the persistence tiers are computed from the same `preds_test_v3` predictions
- Confirm repeated alerts dominate volume more than new alerts
- Confirm this file is being used as a diagnostic analysis, not as a change to the model itself

### After `sql/11_eval_first_crossing_cooldown.sql`

- Confirm first-crossing logic is applied before cooldown suppression
- Confirm the chosen cooldown value is the one you intended to analyze
- Confirm this analysis is treated as post-model alert policy evaluation

## Final Result Cross-Check

- README summary remains consistent with `docs/results.md`
- The final reported model remains `bqml_lr_v3`
- The final held-out prediction artifact remains `preds_test_v3`
- Any deviations from documented metrics are treated as something to investigate, not silently normalize

## If Something Looks Off

- Do not edit canonical SQL casually to “fix” a mismatch
- First identify whether the difference comes from data access, project-id substitution, execution order, or an intentional scientific change
- Document any intentional scientific change separately from maintenance work
