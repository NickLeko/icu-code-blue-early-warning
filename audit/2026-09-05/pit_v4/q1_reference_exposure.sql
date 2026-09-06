-- Q1: Count modeled windows that use a value entered/revised at or after t.
-- Revised-entry time is an availability warning, not a complete version history.
WITH lab_values AS (
  SELECT *, LOWER(TRIM(labname)) AS labname_norm,
    COALESCE(SAFE_CAST(labresult AS FLOAT64),
      SAFE_CAST(REGEXP_EXTRACT(labresulttext, r'[-+]?\d*\.?\d+') AS FLOAT64)) AS lab_value
  FROM `physionet-data.eicu_crd.lab`
), affected_windows AS (
  SELECT m.split, m.patientunitstayid, m.prediction_time_min, m.y,
    COUNT(*) AS contributing_labs,
    COUNTIF(l.labresultrevisedoffset >= m.prediction_time_min) AS not_yet_entered,
    COUNTIF(l.labresultrevisedoffset IS NULL) AS availability_unknown,
    COUNTIF(l.labresultrevisedoffset >= m.event_offset_min) AS entered_at_or_after_proxy
  FROM `citric-glow-485600-f4.icu_ml.model_table_v3` m
  JOIN lab_values l ON l.patientunitstayid = m.patientunitstayid
    AND l.labresultoffset >= m.prediction_time_min - 360
    AND l.labresultoffset < m.prediction_time_min
  WHERE l.lab_value IS NOT NULL
    AND l.labname_norm IN ('lactate','lactic acid','ph','k','potassium',
      'creatinine','hgb','hemoglobin','wbc','wbc x 1000','white blood cell count')
  GROUP BY 1,2,3,4
)
SELECT split, y, COUNT(*) AS windows_with_contributing_labs,
  COUNTIF(not_yet_entered > 0) AS windows_with_future_entered_value,
  COUNTIF(availability_unknown > 0) AS windows_with_unknown_availability,
  COUNTIF(entered_at_or_after_proxy > 0) AS windows_with_post_proxy_entry,
  SUM(contributing_labs) AS contributing_lab_window_pairs,
  SUM(not_yet_entered) AS future_entered_lab_window_pairs
FROM affected_windows GROUP BY split, y;

