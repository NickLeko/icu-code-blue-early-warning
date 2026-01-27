-- 05_train_rows.sql
-- Create timepoint-level labels for each (stay, prediction_time) row.
-- Horizon: next 2 hours
-- Lookback already handled in feature creation
-- Leakage guardrail: exclude rows at/after event time
-- Output: `{{PROJECT_ID}}.icu_ml.train_rows_v3`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.train_rows_v3` AS
SELECT
  f.*,
  l.event_offset_min,
  CASE
    WHEN l.event_offset_min IS NULL THEN 0
    WHEN l.event_offset_min > f.prediction_time_min
     AND l.event_offset_min <= f.prediction_time_min + 120 THEN 1
    ELSE 0
  END AS y
FROM `{{PROJECT_ID}}.icu_ml.features_v3` f
JOIN `{{PROJECT_ID}}.icu_ml.labels_v2` l
  USING (patientunitstayid)
WHERE
  l.event_offset_min IS NULL
  OR f.prediction_time_min < l.event_offset_min;

-- Optional sanity check (run manually)
-- SELECT COUNT(*) AS n, SUM(y) AS n_pos, SAFE_DIVIDE(SUM(y), COUNT(*)) AS prev
-- FROM `{{PROJECT_ID}}.icu_ml.train_rows_v3`;

