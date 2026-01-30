-- 10_eval_temporal_alert_tiers.sql
-- Temporal alert persistence + tiering on top of top-0.5% alert rule.
--
-- Uses the same alert definition as 09_eval_alert_rate.sql:
--   NTILE(200) over prob_1 DESC, bucket=1 => top 0.5% alerts.
--
-- Outputs:
--   1) A tier-level summary: alert volume + precision per tier
--   2) (Optional) A compact table of tiered alerts (commented) if you want to materialize

-- (A) Mark alerts using the existing "top 0.5%" bucket rule
WITH ranked AS (
  SELECT
    patientunitstayid,
    prediction_time_min,
    -- Convert to hour index for easy temporal operations (assumes predictions are hourly)
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

-- (B) Compute consecutive alerts per patient-stay
-- We create "reset_group" that increments every time is_alert=0.
-- Then consecutive alerts are row_number within (patient, reset_group) for alert rows.
with_reset_groups AS (
  SELECT
    *,
    SUM(CASE WHEN is_alert = 0 THEN 1 ELSE 0 END)
      OVER (PARTITION BY patientunitstayid ORDER BY prediction_hour) AS reset_group
  FROM alerts
),

temporal AS (
  SELECT
    *,
    CASE
      WHEN is_alert = 1 THEN
        ROW_NUMBER() OVER (
          PARTITION BY patientunitstayid, reset_group
          ORDER BY prediction_hour
        )
      ELSE 0
    END AS consecutive_alerts,

    -- Rolling count of alerts over the last 6 hours (current + 5 prior hours)
    SUM(is_alert) OVER (
      PARTITION BY patientunitstayid
      ORDER BY prediction_hour
      ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ) AS alerts_last_6h
  FROM with_reset_groups
),

-- (C) Tier definition (simple + defensible)
tiered AS (
  SELECT
    *,
    CASE
      WHEN is_alert = 0 THEN 'none'
      WHEN consecutive_alerts >= 3 THEN 'tier_3_persistent'
      WHEN consecutive_alerts = 2 THEN 'tier_2_repeat'
      WHEN consecutive_alerts = 1 THEN 'tier_1_new'
      ELSE 'none'
    END AS alert_tier
  FROM temporal
)

-- (D) Tier-level evaluation
SELECT
  alert_tier,
  COUNTIF(is_alert = 1) AS n_alerts,
  COUNTIF(is_alert = 1 AND y = 1) AS n_true_events,
  SAFE_DIVIDE(COUNTIF(is_alert = 1 AND y = 1), NULLIF(COUNTIF(is_alert = 1), 0)) AS precision_at_tier,
  AVG(CASE WHEN is_alert = 1 THEN prob_1 END) AS avg_prob_on_alerts,
  AVG(CASE WHEN is_alert = 1 THEN consecutive_alerts END) AS avg_consecutive_on_alerts,
  AVG(CASE WHEN is_alert = 1 THEN alerts_last_6h END) AS avg_alerts_last_6h_on_alerts
FROM tiered
GROUP BY alert_tier
ORDER BY
  CASE alert_tier
    WHEN 'tier_3_persistent' THEN 1
    WHEN 'tier_2_repeat' THEN 2
    WHEN 'tier_1_new' THEN 3
    WHEN 'none' THEN 4
    ELSE 5
  END;
