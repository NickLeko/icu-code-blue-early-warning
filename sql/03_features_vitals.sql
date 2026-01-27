-- 03_features_vitals.sql
-- Vitals-only feature table (6h lookback, hourly grid).
-- Output: `{{PROJECT_ID}}.icu_ml.features_v2`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.features_v2` AS
WITH grid AS (
  SELECT
    c.patientunitstayid,
    t_hour
  FROM `{{PROJECT_ID}}.icu_ml.cohort_v1` c,
  UNNEST(GENERATE_ARRAY(360, c.unitdischargeoffset - 120, 60)) AS t_hour
  WHERE c.unitdischargeoffset - t_hour >= 120
)
SELECT
  g.patientunitstayid,
  g.t_hour AS prediction_time_min,

  AVG(v.heartrate) AS hr_mean_6h,
  MIN(v.heartrate) AS hr_min_6h,
  MAX(v.heartrate) AS hr_max_6h,
  COUNT(v.heartrate) AS hr_n_6h,

  AVG(v.respiration) AS rr_mean_6h,
  MIN(v.respiration) AS rr_min_6h,
  MAX(v.respiration) AS rr_max_6h,
  COUNT(v.respiration) AS rr_n_6h,

  AVG(v.sao2) AS sao2_mean_6h,
  MIN(v.sao2) AS sao2_min_6h,
  COUNT(v.sao2) AS sao2_n_6h,

  AVG(v.temperature) AS temp_mean_6h,
  COUNT(v.temperature) AS temp_n_6h,

  AVG(v.systemicsystolic) AS sbp_mean_6h,
  MIN(v.systemicsystolic) AS sbp_min_6h,
  COUNT(v.systemicsystolic) AS sbp_n_6h,

  AVG(v.systemicmean) AS map_mean_6h,
  MIN(v.systemicmean) AS map_min_6h,
  COUNT(v.systemicmean) AS map_n_6h

FROM grid g
LEFT JOIN `physionet-data.eicu_crd.vitalperiodic` v
  ON v.patientunitstayid = g.patientunitstayid
 AND v.observationoffset >= g.t_hour - 360
 AND v.observationoffset <  g.t_hour
GROUP BY g.patientunitstayid, prediction_time_min;

