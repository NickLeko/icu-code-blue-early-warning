-- 04_features_labs.sql
-- Vitals + labs feature table (6h lookback, hourly grid).
-- Important correctness note:
--   Vitals and labs must be aggregated separately at the prediction-window level
--   before joining. Joining raw vitalperiodic and lab rows in the same grouped
--   query can multiply rows and corrupt count-based features.
-- Output: `{{PROJECT_ID}}.icu_ml.features_v3`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.features_v3` AS
WITH grid AS (
  SELECT
    patientunitstayid,
    prediction_time_min
  FROM `{{PROJECT_ID}}.icu_ml.features_v2`
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
),
labs_agg AS (
  SELECT
    g.patientunitstayid,
    g.prediction_time_min,

    -- lactate
    AVG(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)) AS lactate_mean_6h,
    MIN(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)) AS lactate_min_6h,
    MAX(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)) AS lactate_max_6h,
    COUNTIF(l.labname_norm IN ('lactate','lactic acid') AND l.lab_value IS NOT NULL) AS lactate_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('lactate','lactic acid'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[SAFE_OFFSET(0)] AS lactate_last_6h,

    -- pH
    AVG(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_mean_6h,
    MIN(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_min_6h,
    MAX(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_max_6h,
    COUNTIF(l.labname_norm = 'ph' AND l.lab_value IS NOT NULL) AS ph_n_6h,
    ARRAY_AGG(IF(l.labname_norm = 'ph', l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[SAFE_OFFSET(0)] AS ph_last_6h,

    -- potassium
    AVG(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_mean_6h,
    MIN(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_min_6h,
    MAX(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_max_6h,
    COUNTIF(l.labname_norm IN ('k','potassium') AND l.lab_value IS NOT NULL) AS k_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[SAFE_OFFSET(0)] AS k_last_6h,

    -- creatinine
    AVG(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_mean_6h,
    MIN(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_min_6h,
    MAX(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_max_6h,
    COUNTIF(l.labname_norm = 'creatinine' AND l.lab_value IS NOT NULL) AS creat_n_6h,
    ARRAY_AGG(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[SAFE_OFFSET(0)] AS creat_last_6h,

    -- hemoglobin
    AVG(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_mean_6h,
    MIN(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_min_6h,
    MAX(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_max_6h,
    COUNTIF(l.labname_norm IN ('hgb','hemoglobin') AND l.lab_value IS NOT NULL) AS hgb_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[SAFE_OFFSET(0)] AS hgb_last_6h,

    -- WBC
    AVG(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_mean_6h,
    MIN(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_min_6h,
    MAX(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_max_6h,
    COUNTIF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count') AND l.lab_value IS NOT NULL) AS wbc_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC LIMIT 1)[SAFE_OFFSET(0)] AS wbc_last_6h

  FROM grid g
  LEFT JOIN labs_clean l
    ON l.patientunitstayid = g.patientunitstayid
   AND l.labresultoffset >= g.prediction_time_min - 360
   AND l.labresultoffset <  g.prediction_time_min
  GROUP BY g.patientunitstayid, g.prediction_time_min
)
SELECT
  v.*,
  l.lactate_mean_6h,
  l.lactate_min_6h,
  l.lactate_max_6h,
  l.lactate_n_6h,
  l.lactate_last_6h,
  l.ph_mean_6h,
  l.ph_min_6h,
  l.ph_max_6h,
  l.ph_n_6h,
  l.ph_last_6h,
  l.k_mean_6h,
  l.k_min_6h,
  l.k_max_6h,
  l.k_n_6h,
  l.k_last_6h,
  l.creat_mean_6h,
  l.creat_min_6h,
  l.creat_max_6h,
  l.creat_n_6h,
  l.creat_last_6h,
  l.hgb_mean_6h,
  l.hgb_min_6h,
  l.hgb_max_6h,
  l.hgb_n_6h,
  l.hgb_last_6h,
  l.wbc_mean_6h,
  l.wbc_min_6h,
  l.wbc_max_6h,
  l.wbc_n_6h,
  l.wbc_last_6h
FROM `{{PROJECT_ID}}.icu_ml.features_v2` v
LEFT JOIN labs_agg l
  USING (patientunitstayid, prediction_time_min);
