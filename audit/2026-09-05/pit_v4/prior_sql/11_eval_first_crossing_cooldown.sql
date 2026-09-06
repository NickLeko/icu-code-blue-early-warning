-- 11_eval_first_crossing_cooldown.sql
-- First-crossing + 12-hour quiet-period debounce.
-- Suppressed crossings reset the quiet-period window; this is not a cooldown
-- measured from the last emitted alert.

WITH params AS (
  SELECT 12 AS quiet_period_hours
),
ranked AS (
  SELECT
    patientunitstayid,
    prediction_time_min,
    DIV(prediction_time_min, 60) AS prediction_hour,
    y,
    prob_1,
    NTILE(200) OVER (
      ORDER BY prob_1 DESC, patientunitstayid, prediction_time_min
    ) AS bucket
  FROM `{{PROJECT_ID}}.icu_ml.preds_test_v3`
),

alerts AS (
  SELECT
    *,
    CASE WHEN bucket = 1 THEN 1 ELSE 0 END AS is_alert
  FROM ranked
),

lagged AS (
  SELECT
    *,
    LAG(is_alert) OVER (
      PARTITION BY patientunitstayid
      ORDER BY prediction_hour
    ) AS prev_is_alert
  FROM alerts
),

first_crossing AS (
  SELECT
    *,
    CASE
      WHEN is_alert = 1 AND IFNULL(prev_is_alert, 0) = 0 THEN 1
      ELSE 0
    END AS is_first_crossing
  FROM lagged
),

-- get time of PREVIOUS first crossing (not including current row)
prev_crossing_time AS (
  SELECT
    *,
    MAX(IF(is_first_crossing = 1, prediction_hour, NULL)) OVER (
      PARTITION BY patientunitstayid
      ORDER BY prediction_hour
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS prev_first_crossing_hour
  FROM first_crossing
),

final AS (
  SELECT
    *,
    CASE
      WHEN is_first_crossing = 1
           AND (
             prev_first_crossing_hour IS NULL
             OR prediction_hour - prev_first_crossing_hour >= params.quiet_period_hours
           )
      THEN 1
      ELSE 0
    END AS alert_debounced
  FROM prev_crossing_time
  CROSS JOIN params
)

SELECT
  MAX(quiet_period_hours) AS quiet_period_hours,
  COUNTIF(alert_debounced = 1) AS alerts,
  COUNTIF(alert_debounced = 1 AND y = 1) AS positive_windows,
  SAFE_DIVIDE(
    COUNTIF(alert_debounced = 1 AND y = 1),
    NULLIF(COUNTIF(alert_debounced = 1), 0)
  ) AS precision
FROM final;
