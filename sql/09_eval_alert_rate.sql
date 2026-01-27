-- 09_eval_alert_rate.sql
-- Evaluate model actionability via precision at a fixed alert rate (top 0.5% risk).
-- Outputs:
--   1) `{{PROJECT_ID}}.icu_ml.preds_test_v3` (test predictions with prob for class 1)
--   2) A query to compute precision@0.5% alerts on the test set

-- (A) Create predictions table for the test set
CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.preds_test_v3` AS
WITH raw AS (
  SELECT
    patientunitstayid,
    prediction_time_min,
    y,
    predicted_y_probs
  FROM ML.PREDICT(
    MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`,
    (
      SELECT
        patientunitstayid,
        prediction_time_min,
        y,

        -- vitals
        hr_mean_6h, hr_min_6h, hr_max_6h, hr_n_6h,
        rr_mean_6h, rr_min_6h, rr_max_6h, rr_n_6h,
        sao2_mean_6h, sao2_min_6h, sao2_n_6h,
        temp_mean_6h, temp_n_6h,
        sbp_mean_6h, sbp_min_6h, sbp_n_6h,
        map_mean_6h, map_min_6h, map_n_6h,

        -- labs
        lactate_mean_6h, lactate_min_6h, lactate_max_6h, lactate_n_6h, lactate_last_6h,
        ph_mean_6h, ph_min_6h, ph_max_6h, ph_n_6h, ph_last_6h,
        k_mean_6h, k_min_6h, k_max_6h, k_n_6h, k_last_6h,
        creat_mean_6h, creat_min_6h, creat_max_6h, creat_n_6h, creat_last_6h,
        hgb_mean_6h, hgb_min_6h, hgb_max_6h, hgb_n_6h, hgb_last_6h,
        wbc_mean_6h, wbc_min_6h, wbc_max_6h, wbc_n_6h, wbc_last_6h

      FROM `{{PROJECT_ID}}.icu_ml.model_table_v3`
      WHERE split = 'test'
    )
  )
)
SELECT
  patientunitstayid,
  prediction_time_min,
  y,
  (SELECT p.prob
   FROM UNNEST(predicted_y_probs) p
   WHERE CAST(p.label AS STRING) = '1'
   LIMIT 1) AS prob_1
FROM raw;

-- (B) Precision at top 0.5% alert rate
WITH ranked AS (
  SELECT
    *,
    NTILE(200) OVER (ORDER BY prob_1 DESC) AS bucket
  FROM `{{PROJECT_ID}}.icu_ml.preds_test_v3`
)
SELECT
  COUNT(*) AS alerts,
  SUM(y) AS true_events,
  SAFE_DIVIDE(SUM(y), COUNT(*)) AS precision_at_0_5pct
FROM ranked
WHERE bucket = 1;
