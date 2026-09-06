-- Runs the existing canonical persistence-tier fixture.
ASSERT (
  WITH fixture AS (
    SELECT *
    FROM UNNEST([
      STRUCT(1 AS patientunitstayid, 1 AS prediction_hour, 0 AS is_alert),
      STRUCT(1 AS patientunitstayid, 2 AS prediction_hour, 1 AS is_alert),
      STRUCT(1 AS patientunitstayid, 3 AS prediction_hour, 1 AS is_alert),
      STRUCT(1 AS patientunitstayid, 4 AS prediction_hour, 1 AS is_alert),
      STRUCT(1 AS patientunitstayid, 5 AS prediction_hour, 0 AS is_alert),
      STRUCT(1 AS patientunitstayid, 6 AS prediction_hour, 1 AS is_alert)
    ])
  ),
  fixture_reset_groups AS (
    SELECT
      *,
      SUM(CASE WHEN is_alert = 0 THEN 1 ELSE 0 END) OVER (
        PARTITION BY patientunitstayid
        ORDER BY prediction_hour
      ) AS reset_group
    FROM fixture
  ),
  fixture_temporal AS (
    SELECT
      *,
      CASE
        WHEN is_alert = 1 THEN
          COUNTIF(is_alert = 1) OVER (
            PARTITION BY patientunitstayid, reset_group
            ORDER BY prediction_hour
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          )
        ELSE 0
      END AS consecutive_alerts
    FROM fixture_reset_groups
  ),
  fixture_tiered AS (
    SELECT
      prediction_hour,
      CASE
        WHEN is_alert = 0 THEN 'none'
        WHEN consecutive_alerts >= 3 THEN 'tier_3_persistent'
        WHEN consecutive_alerts = 2 THEN 'tier_2_repeat'
        WHEN consecutive_alerts = 1 THEN 'tier_1_new'
        ELSE 'none'
      END AS alert_tier
    FROM fixture_temporal
  ),
  expected AS (
    SELECT *
    FROM UNNEST([
      STRUCT(1 AS prediction_hour, 'none' AS expected_tier),
      STRUCT(2 AS prediction_hour, 'tier_1_new' AS expected_tier),
      STRUCT(3 AS prediction_hour, 'tier_2_repeat' AS expected_tier),
      STRUCT(4 AS prediction_hour, 'tier_3_persistent' AS expected_tier),
      STRUCT(5 AS prediction_hour, 'none' AS expected_tier),
      STRUCT(6 AS prediction_hour, 'tier_1_new' AS expected_tier)
    ])
  )
  SELECT
    COUNT(*) = 6
    AND COUNTIF(t.alert_tier != e.expected_tier) = 0
  FROM fixture_tiered t
  JOIN expected e USING (prediction_hour)
) AS 'Temporal alert tier regression fixture failed';
