-- Aggregate-only naive vs first-crossing vs debounced alert-policy counts.

WITH params AS (
  SELECT 12 AS cooldown_hours
),
ranked AS (
  SELECT
    patientunitstayid,
    prediction_time_min,
    DIV(prediction_time_min, 60) AS prediction_hour,
    y,
    prob_1,
    NTILE(200) OVER (ORDER BY prob_1 DESC) AS bucket
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
             OR prediction_hour - prev_first_crossing_hour >= params.cooldown_hours
           )
      THEN 1
      ELSE 0
    END AS alert_debounced
  FROM prev_crossing_time
  CROSS JOIN params
),
policy_counts AS (
  SELECT
    'naive_top_0_5pct' AS policy,
    MAX(cooldown_hours) AS cooldown_hours,
    COUNTIF(is_alert = 1) AS alerts,
    COUNTIF(is_alert = 1 AND y = 1) AS positive_windows,
    SAFE_DIVIDE(COUNTIF(is_alert = 1 AND y = 1), COUNTIF(is_alert = 1)) AS precision
  FROM final

  UNION ALL

  SELECT
    'first_crossing',
    MAX(cooldown_hours),
    COUNTIF(is_first_crossing = 1),
    COUNTIF(is_first_crossing = 1 AND y = 1),
    SAFE_DIVIDE(COUNTIF(is_first_crossing = 1 AND y = 1), COUNTIF(is_first_crossing = 1))
  FROM final

  UNION ALL

  SELECT
    'debounced_first_crossing',
    MAX(cooldown_hours),
    COUNTIF(alert_debounced = 1),
    COUNTIF(alert_debounced = 1 AND y = 1),
    SAFE_DIVIDE(COUNTIF(alert_debounced = 1 AND y = 1), COUNTIF(alert_debounced = 1))
  FROM final
),
naive AS (
  SELECT alerts AS naive_alerts
  FROM policy_counts
  WHERE policy = 'naive_top_0_5pct'
)
SELECT
  p.policy,
  p.cooldown_hours,
  p.alerts,
  p.positive_windows,
  p.precision,
  SAFE_DIVIDE(p.alerts, n.naive_alerts) AS alert_ratio_vs_naive
FROM policy_counts p
CROSS JOIN naive n
ORDER BY
  CASE p.policy
    WHEN 'naive_top_0_5pct' THEN 1
    WHEN 'first_crossing' THEN 2
    WHEN 'debounced_first_crossing' THEN 3
    ELSE 4
  END;
