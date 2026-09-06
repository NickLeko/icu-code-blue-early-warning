-- Executes the exact new feature SELECT without creating a permanent table.
-- Validates the information-boundary correction while project writes are blocked.
WITH new_features AS (
WITH grid AS (
  SELECT
    patientunitstayid,
    prediction_time_min
  FROM `{{PROJECT_ID}}.icu_ml.features_v2`
),
labs_clean AS (
  SELECT
    labid,
    patientunitstayid,
    labresultoffset,
    GREATEST(labresultoffset, labresultrevisedoffset) AS available_offset_min,
    LOWER(TRIM(labname)) AS labname_norm,
    COALESCE(
      SAFE_CAST(labresult AS FLOAT64),
      SAFE_CAST(REGEXP_EXTRACT(labresulttext, r'[-+]?\d*\.?\d+') AS FLOAT64)
    ) AS lab_value
  FROM `physionet-data.eicu_crd.lab`
  WHERE labresultoffset IS NOT NULL
    AND labresultoffset >= 0
    AND labresultrevisedoffset IS NOT NULL
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
              IGNORE NULLS ORDER BY l.labresultoffset DESC, l.labid DESC LIMIT 1)[SAFE_OFFSET(0)] AS lactate_last_6h,

    -- pH
    AVG(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_mean_6h,
    MIN(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_min_6h,
    MAX(IF(l.labname_norm = 'ph', l.lab_value, NULL)) AS ph_max_6h,
    COUNTIF(l.labname_norm = 'ph' AND l.lab_value IS NOT NULL) AS ph_n_6h,
    ARRAY_AGG(IF(l.labname_norm = 'ph', l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC, l.labid DESC LIMIT 1)[SAFE_OFFSET(0)] AS ph_last_6h,

    -- potassium
    AVG(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_mean_6h,
    MIN(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_min_6h,
    MAX(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)) AS k_max_6h,
    COUNTIF(l.labname_norm IN ('k','potassium') AND l.lab_value IS NOT NULL) AS k_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('k','potassium'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC, l.labid DESC LIMIT 1)[SAFE_OFFSET(0)] AS k_last_6h,

    -- creatinine
    AVG(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_mean_6h,
    MIN(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_min_6h,
    MAX(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)) AS creat_max_6h,
    COUNTIF(l.labname_norm = 'creatinine' AND l.lab_value IS NOT NULL) AS creat_n_6h,
    ARRAY_AGG(IF(l.labname_norm = 'creatinine', l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC, l.labid DESC LIMIT 1)[SAFE_OFFSET(0)] AS creat_last_6h,

    -- hemoglobin
    AVG(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_mean_6h,
    MIN(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_min_6h,
    MAX(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)) AS hgb_max_6h,
    COUNTIF(l.labname_norm IN ('hgb','hemoglobin') AND l.lab_value IS NOT NULL) AS hgb_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('hgb','hemoglobin'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC, l.labid DESC LIMIT 1)[SAFE_OFFSET(0)] AS hgb_last_6h,

    -- WBC
    AVG(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_mean_6h,
    MIN(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_min_6h,
    MAX(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)) AS wbc_max_6h,
    COUNTIF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count') AND l.lab_value IS NOT NULL) AS wbc_n_6h,
    ARRAY_AGG(IF(l.labname_norm IN ('wbc','wbc x 1000','white blood cell count'), l.lab_value, NULL)
              IGNORE NULLS ORDER BY l.labresultoffset DESC, l.labid DESC LIMIT 1)[SAFE_OFFSET(0)] AS wbc_last_6h

  FROM grid g
  LEFT JOIN labs_clean l
    ON l.patientunitstayid = g.patientunitstayid
   AND l.labresultoffset >= g.prediction_time_min - 360
   AND l.labresultoffset <  g.prediction_time_min
   AND l.available_offset_min < g.prediction_time_min
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
  USING (patientunitstayid, prediction_time_min)
)
SELECT o.split,o.y,COUNT(*) AS n_rows,
 COUNTIF(n.patientunitstayid IS NULL) AS missing_feature_rows,
 COUNTIF(o.lactate_n_6h IS DISTINCT FROM n.lactate_n_6h OR o.ph_n_6h IS DISTINCT FROM n.ph_n_6h OR o.k_n_6h IS DISTINCT FROM n.k_n_6h OR o.creat_n_6h IS DISTINCT FROM n.creat_n_6h OR o.hgb_n_6h IS DISTINCT FROM n.hgb_n_6h OR o.wbc_n_6h IS DISTINCT FROM n.wbc_n_6h) AS rows_with_changed_lab_counts,
 COUNTIF(n.lactate_n_6h > o.lactate_n_6h OR n.ph_n_6h > o.ph_n_6h OR n.k_n_6h > o.k_n_6h OR n.creat_n_6h > o.creat_n_6h OR n.hgb_n_6h > o.hgb_n_6h OR n.wbc_n_6h > o.wbc_n_6h) AS rows_with_increased_lab_counts,
 SUM((o.lactate_n_6h-n.lactate_n_6h) + (o.ph_n_6h-n.ph_n_6h) + (o.k_n_6h-n.k_n_6h) + (o.creat_n_6h-n.creat_n_6h) + (o.hgb_n_6h-n.hgb_n_6h) + (o.wbc_n_6h-n.wbc_n_6h)) AS lab_window_pairs_removed
FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` o
LEFT JOIN new_features n USING(patientunitstayid,prediction_time_min)
GROUP BY o.split,o.y ORDER BY o.split,o.y;
