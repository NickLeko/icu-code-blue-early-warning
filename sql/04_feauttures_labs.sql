-- 04_features_labs.sql
-- Vitals + labs feature table (6h lookback, hourly grid).
-- Output: `{{PROJECT_ID}}.icu_ml.features_v3`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.features_v3` AS
WITH grid AS (
  SELECT
    c.patientunitstayid,
    t_hour
  FROM `{{PROJECT_ID}}.icu_ml.cohort_v1` c,
  UNNEST(GENERATE_ARRAY(360, c.unitdischargeoffset - 120, 60)) AS t_hour
  WHERE c.unitdischargeoffset - t_hour >= 120
),
labs_clean AS (
  SELECT
    patientunitstayid,
    labresultoffset,
    LOWER(TRIM(labname)) AS labname_norm,
    COALESCE(
      SAFE_CAST(labresult AS FLOAT64),
      SAFE_CAST(REGEXP_EXTRACT(labresulttext, r'[-+]?\d*\.?\d+') AS FLOAT64)
    ) AS lab_value
  FROM `physionet-data.eicu_crd.lab`
  WHERE labresultoffset IS NOT NULL
    AND labresultoffset >= 0
)
SELECT
  g.patientunitstayid,
  g.t_hour AS prediction_time_min,

  -- ===== vitals =====
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
  COUNT(v.systemicmean) AS map_n_6h,

  -- ===== labs: lactate =====
  AVG(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)) AS lactate_mean_6h,
  MIN(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)) AS lactate_min_6h,
  MAX(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)) AS lactate_max_6h,
  COUNTIF(l.labname_norm IN ('lactate','lactic acid') AND l.lab_value IS NOT NULL) AS lactate_n_6h,
  ARRAY_AGG(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)
            IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[OFFSET(0)] AS lactate_last_6h,

  -- pH
  AVG(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_mean_6h,
  MIN(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_min_6h,
  MAX(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_max_6h,
  COUNTIF(l.labname_norm = 'ph' AND l.lab_value IS NOT NULL) AS ph_n_6h,
  ARRAY_AGG(IF(l.labname_norm = 'ph', l.lab_value, NULL)
            IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[OFFSET(0)] AS ph_last_6h,

  -- potassium
  AVG(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_mean_6h,
  MIN(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_min_6h,
  MAX(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_max_6h,
  COUNTIF(l.labname_norm IN ('k','potassium') AND l.lab_value IS NOT NULL) AS k_n_6h,
  ARRAY_AGG(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)
            IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[OFFSET(0)] AS k_last_6h,

  -- creatinine
  AVG(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_mean_6h,
  MIN(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_min_6h,
  MAX(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_max_6h,
  COUNTIF(l.labname_norm = 'creatinine' AND l.lab_value IS NOT NULL) AS creat_n_6h,
  ARRAY_AGG(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)
            IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[OFFSET(0)] AS creat_last_6h,

  -- hemoglobin
  AVG(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_mean_6h,
  MIN(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_min_6h,
  MAX(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_max_6h,
  COUNTIF(l.labname_norm IN ('hgb','hemoglobin') AND l.lab_value IS NOT NULL) AS hgb_n_6h,
  ARRAY_AGG(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)
            IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[OFFSET(0)] AS hgb_last_6h,

  -- WBC
  AVG(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_mean_6h,
  MIN(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_min_6h,
  MAX(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_max_6h,
  COUNTIF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count') AND l.lab_value IS NOT NULL) AS wbc_n_6h,
  ARRAY_AGG(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)
            IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[OFFSET(0)] AS wbc_last_6h

FROM grid g
LEFT JOIN `physionet-data.eicu_crd.vitalperiodic` v
  ON v.patientunitstayid = g.patientunitstayid
 AND v.observationoffset >= g.t_hour - 360
 AND v.observationoffset <  g.t_hour
LEFT JOIN labs_clean l
  ON l.patientunitstayid = g.patientunitstayid
 AND l.labresultoffset >= g.t_hour - 360
 AND l.labresultoffset <  g.t_hour
GROUP BY g.patientunitstayid, prediction_time_min;

