-- Explain every last-value difference outside measured Q1 exposure.
WITH mismatches AS (
 SELECT o.split,o.y,o.patientunitstayid,o.prediction_time_min,p.*
 FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` o
 JOIN `{{PROJECT_ID}}.icu_ml.model_table_v4_pit` n USING(patientunitstayid,prediction_time_min)
 CROSS JOIN UNNEST([STRUCT('lactate' AS lab_kind,o.lactate_last_6h AS old_value,n.lactate_last_6h AS new_value),
STRUCT('ph' AS lab_kind,o.ph_last_6h AS old_value,n.ph_last_6h AS new_value),
STRUCT('k' AS lab_kind,o.k_last_6h AS old_value,n.k_last_6h AS new_value),
STRUCT('creat' AS lab_kind,o.creat_last_6h AS old_value,n.creat_last_6h AS new_value),
STRUCT('hgb' AS lab_kind,o.hgb_last_6h AS old_value,n.hgb_last_6h AS new_value),
STRUCT('wbc' AS lab_kind,o.wbc_last_6h AS old_value,n.wbc_last_6h AS new_value)]) p
 WHERE (o.lactate_n_6h=n.lactate_n_6h AND o.ph_n_6h=n.ph_n_6h AND o.k_n_6h=n.k_n_6h AND o.creat_n_6h=n.creat_n_6h AND o.hgb_n_6h=n.hgb_n_6h AND o.wbc_n_6h=n.wbc_n_6h) AND p.old_value IS DISTINCT FROM p.new_value
), labs AS (
 SELECT labid,patientunitstayid,labresultoffset,labresultrevisedoffset,
 CASE WHEN LOWER(TRIM(labname)) IN ('lactate','lactic acid') THEN 'lactate'
 WHEN LOWER(TRIM(labname))='ph' THEN 'ph'
 WHEN LOWER(TRIM(labname)) IN ('k','potassium') THEN 'k'
 WHEN LOWER(TRIM(labname))='creatinine' THEN 'creat'
 WHEN LOWER(TRIM(labname)) IN ('hgb','hemoglobin') THEN 'hgb'
 WHEN LOWER(TRIM(labname)) IN ('wbc','wbc x 1000','white blood cell count') THEN 'wbc' END AS lab_kind,
 COALESCE(SAFE_CAST(labresult AS FLOAT64),SAFE_CAST(REGEXP_EXTRACT(labresulttext,r'[-+]?\d*\.?\d+') AS FLOAT64)) AS lab_value
 FROM `physionet-data.eicu_crd.lab`
), latest AS (
 SELECT m.*,l.labid,l.lab_value,l.labresultoffset,
 DENSE_RANK() OVER(PARTITION BY m.patientunitstayid,m.prediction_time_min,m.lab_kind ORDER BY l.labresultoffset DESC) AS draw_rank
 FROM mismatches m LEFT JOIN labs l
 ON m.patientunitstayid=l.patientunitstayid AND m.lab_kind=l.lab_kind
 AND l.lab_value IS NOT NULL
 AND l.labresultoffset>=m.prediction_time_min-360
 AND GREATEST(l.labresultoffset,l.labresultrevisedoffset)<m.prediction_time_min
), explained AS (
 SELECT split,y,patientunitstayid,prediction_time_min,lab_kind,
 COUNT(DISTINCT lab_value)>1 AS different_values_at_latest_draw,
 COUNTIF(lab_value=old_value)>0 AS old_value_in_tie,
 ARRAY_AGG(lab_value IGNORE NULLS ORDER BY labid DESC LIMIT 1)[SAFE_OFFSET(0)]=ANY_VALUE(new_value) AS new_value_matches_max_labid
 FROM latest WHERE draw_rank=1 GROUP BY 1,2,3,4,5
)
SELECT split,y,COUNT(*) AS changed_feature_cells,
 COUNT(DISTINCT FORMAT('%d:%d',patientunitstayid,prediction_time_min)) AS changed_rows,
 COUNTIF(NOT COALESCE(different_values_at_latest_draw AND old_value_in_tie AND new_value_matches_max_labid,FALSE)) AS unexplained_feature_cells
FROM explained GROUP BY split,y ORDER BY split,y;
