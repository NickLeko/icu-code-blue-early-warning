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
- Confirm numeric age 18–120; top-coded `> 89` is excluded, not converted
- Confirm the documentation does not claim an SQL `unittype` restriction
- Spot-check that the minimum ICU stay filter is reflected in `unitdischargeoffset >= 360`

### After `sql/02_labels.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.labels_v2`
- Inspect positive prevalence at the stay level
- Inspect event-time plausibility for a small sample
- Confirm stays with qualifying events inside the first 6 ICU hours are absent
  from the final label table, meaning they are excluded from downstream datasets
  rather than merely relabeled negative

### After `sql/03_features_vitals.sql` and `sql/04_features_labs.sql`

- Verify `features_v2` and `features_v4_pit` were created
- Confirm the feature tables are keyed by `patientunitstayid` and `prediction_time_min`
- Confirm specimen draw lookback `[t-360,t)` AND `GREATEST(draw, revised-entry) < t`; NULL revision timestamps must not fall back to draw time
- Execute the boundary fixture and reconcile removed lab-window pairs against Q1
- Confirm at least eight hours of stay are needed to produce a modeled row
- Confirm the prediction grid remains bounded by `unitdischargeoffset - 120`;
  this is a documented retrospective limitation, not a deployment-valid scoring
  policy
- Confirm `features_v4_pit` has the same row count as `features_v2` (lab enrichment should not multiply windows)
- Spot-check that vital count features in `features_v4_pit` still match the corresponding values in `features_v2`
- Spot-check that lab parsing produced non-null values for the intended labs

### After `sql/05_train_rows.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.train_rows_v4_pit`
- Inspect row-level prevalence of `y = 1`
- Confirm rows at or after the event time are excluded
- Confirm the positive-label window still corresponds to the next 2 hours

### After `sql/06_splits.sql`

- Verify the split table exists: `{{PROJECT_ID}}.icu_ml.split_hospital_v1`
- Confirm hospitals are assigned to train, val, and test
- Confirm the split is hospital-level rather than row-level
- Confirm CUSTOM split routes every `val` row to evaluation and every `train` row to fitting; no test row enters model creation
- Inspect effective model options and the temporary evaluation split before it expires

### After `sql/07_model_table.sql`

- Verify the output table exists: `{{PROJECT_ID}}.icu_ml.model_table_v4_pit`
- Inspect row counts by split
- Inspect positive counts by split
- Confirm the expected join keys are populated

### After `sql/08_bqml_models.sql`

- Verify the model exists: `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit`
- Confirm the final model is the vitals + labs logistic regression
- Confirm you trained on `split = 'train'` only

### After `sql/09_eval_alert_rate.sql`

- Verify the predictions table exists: `{{PROJECT_ID}}.icu_ml.preds_test_v4_pit`
- Confirm evaluation is restricted to the held-out test split
- Confirm the top-0.5% alert rule is still implemented via `NTILE(200)`
- Record alert volume and precision with `artifacts/queries/02_reference_run_operating_point.sql`

### After `sql/10_eval_temporal_alert_tiers.sql`

- Confirm the persistence tiers are computed from the same `preds_test_v4_pit` predictions
- Confirm the inline regression assertion passes for new, repeat, and persistent alerts
- Inspect whether repeated alerts dominate volume more than new alerts
- Confirm this file is being used as a diagnostic analysis, not as a change to the model itself; historical defective tier results remain withdrawn; new tier outputs are versioned separately

### After `sql/11_eval_first_crossing_cooldown.sql`

- Confirm first-crossing logic is applied before quiet-period suppression
- Confirm the chosen quiet-period value is the one you intended to analyze and
  remember that suppressed crossings reset the window
- Confirm this analysis is treated as post-model alert policy evaluation

## Final Result Cross-Check

- README summary remains consistent with `docs/results.md`
- The final reported model remains `bqml_lr_v4_pit`
- The final held-out prediction artifact remains `preds_test_v4_pit`
- Reviewer-facing aggregate exports can be regenerated from `artifacts/queries/`
- Any unexpected differences between reruns or exported aggregates are treated as something to investigate, not silently normalize

## If Something Looks Off

- Do not edit canonical SQL casually to “fix” a mismatch
- First identify whether the difference comes from data access, project-id substitution, execution order, or an intentional scientific change
- Document any intentional scientific change separately from maintenance work
