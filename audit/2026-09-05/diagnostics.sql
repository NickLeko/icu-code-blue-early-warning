-- READ-ONLY audit queries. Not executed on BigQuery during this audit.
-- Replace {{PROJECT_ID}} before use; run statements separately as needed.
-- Source-table joins can be expensive: dry-run and set a bytes-billed cap.
-- Results are aggregates; do not export row-level patient records.

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
  FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` m
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

-- Q2: Actual patient/stay/hospital overlap and duplicate prediction keys.
-- Zero overlap is required; SQL structure alone only guarantees hospital/stay
-- separation subject to source-key integrity, not unique-person separation.
WITH ids AS (
  SELECT DISTINCT m.split, m.hospitalid, m.patientunitstayid,
    c.uniquepid, c.patienthealthsystemstayid
  FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` m
  JOIN `{{PROJECT_ID}}.icu_ml.cohort_v1` c USING(patientunitstayid)
), overlap AS (
  SELECT 'hospital' AS id_type, COUNT(DISTINCT split) AS n_splits FROM ids GROUP BY hospitalid
  UNION ALL
  SELECT 'unit_stay', COUNT(DISTINCT split) FROM ids GROUP BY patientunitstayid
  UNION ALL
  SELECT 'hospital_stay', COUNT(DISTINCT split) FROM ids GROUP BY patienthealthsystemstayid
  UNION ALL
  SELECT 'person', COUNT(DISTINCT split) FROM ids WHERE uniquepid IS NOT NULL GROUP BY uniquepid
)
SELECT id_type, COUNT(*) AS distinct_ids, COUNTIF(n_splits > 1) AS ids_crossing_splits
FROM overlap GROUP BY id_type;

-- Q3: Make the denominator in the operating-point export verifiable.
WITH m AS (
  SELECT patientunitstayid, prediction_time_min, COUNT(*) AS n, MIN(y) AS y
  FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` WHERE split='test' GROUP BY 1,2
), p AS (
  SELECT patientunitstayid, prediction_time_min, COUNT(*) AS n, MIN(y) AS y,
    COUNTIF(prob_1 IS NULL OR IS_NAN(prob_1) OR prob_1 < 0 OR prob_1 > 1) AS bad_scores
  FROM `{{PROJECT_ID}}.icu_ml.preds_test_v3` GROUP BY 1,2
)
SELECT COUNTIF(m.n IS NULL) AS prediction_keys_not_in_test,
  COUNTIF(p.n IS NULL) AS test_keys_without_prediction,
  COUNTIF(m.n != 1 OR p.n != 1) AS duplicate_keys,
  COUNTIF(m.y != p.y) AS label_disagreements, SUM(p.bad_scores) AS bad_scores
FROM m FULL OUTER JOIN p USING(patientunitstayid,prediction_time_min);

-- Q4: Label availability, terminal events, and death-without-proxy accounting.
WITH scored AS (
  SELECT patientunitstayid, COUNT(*) AS n_rows, SUM(y) AS n_positive_rows
  FROM `{{PROJECT_ID}}.icu_ml.train_rows_v3` GROUP BY 1
)
SELECT p.unitdischargestatus, p.hospitaldischargestatus,
  COUNT(*) AS cohort_stays,
  COUNTIF(l.patientunitstayid IS NULL) AS excluded_early_proxy_stays,
  COUNTIF(l.patientunitstayid IS NOT NULL AND l.event_offset_min IS NULL) AS retained_no_proxy_stays,
  COUNTIF(l.event_offset_min IS NOT NULL) AS retained_proxy_stays,
  COUNTIF(l.event_offset_min > c.unitdischargeoffset) AS proxy_after_unit_discharge,
  COUNTIF(l.event_offset_min = 360) AS proxy_exactly_at_scoring_start,
  COUNTIF(l.event_offset_min IS NOT NULL AND IFNULL(s.n_positive_rows,0)=0) AS positive_stays_without_positive_windows,
  COUNTIF(l.patientunitstayid IS NOT NULL AND s.patientunitstayid IS NULL) AS labeled_stays_without_rows
FROM `{{PROJECT_ID}}.icu_ml.cohort_v1` c
JOIN `physionet-data.eicu_crd.patient` p USING(patientunitstayid)
LEFT JOIN `{{PROJECT_ID}}.icu_ml.labels_v2` l USING(patientunitstayid)
LEFT JOIN scored s USING(patientunitstayid)
GROUP BY 1,2;

-- Q5: Scope discrepancies: top-coded age and care-unit types.
SELECT COUNT(*) AS stays_meeting_los_rule,
  COUNTIF(TRIM(age) IN ('> 89','>89')) AS top_coded_age_stays_excluded_by_cast,
  COUNTIF(SAFE_CAST(age AS FLOAT64) BETWEEN 18 AND 120) AS numeric_adult_stays
FROM `physionet-data.eicu_crd.patient`
WHERE unitdischargeoffset >= 360;

SELECT unittype, COUNT(*) AS cohort_stays
FROM `{{PROJECT_ID}}.icu_ml.cohort_v1` GROUP BY unittype ORDER BY cohort_stays DESC;

-- Q6: Per-hospital pooled-policy performance and hospital-mix null comparator.
-- observed_tp / expected_tp_given_hospital_mix tests a different question
-- from pooled enrichment; it is descriptive, not a cluster-valid p-value.
WITH ranked AS (
  SELECT *, NTILE(200) OVER(ORDER BY prob_1 DESC,patientunitstayid,prediction_time_min) AS bucket
  FROM `{{PROJECT_ID}}.icu_ml.preds_test_v3`
), hospital AS (
  SELECT c.hospitalid, COUNT(*) AS n, SUM(r.y) AS k,
    COUNTIF(bucket=1) AS a, COUNTIF(bucket=1 AND r.y=1) AS tp,
    COUNT(DISTINCT IF(r.y=1,r.patientunitstayid,NULL)) AS event_stays_with_positive_rows,
    COUNT(DISTINCT IF(bucket=1 AND r.y=1,r.patientunitstayid,NULL)) AS detected_event_stays
  FROM ranked r JOIN `{{PROJECT_ID}}.icu_ml.cohort_v1` c USING(patientunitstayid)
  GROUP BY 1
)
SELECT *, SAFE_DIVIDE(k,n) AS prevalence, SAFE_DIVIDE(a,n) AS alert_rate,
  SAFE_DIVIDE(tp,a) AS ppv, SAFE_DIVIDE(tp,k) AS row_recall,
  SAFE_DIVIDE(detected_event_stays,event_stays_with_positive_rows) AS evaluable_event_stay_recall,
  a*SAFE_DIVIDE(k,n) AS expected_tp_given_hospital_mix,
  SAFE_DIVIDE(SUM(tp) OVER(),SUM(a*SAFE_DIVIDE(k,n)) OVER()) AS pooled_observed_over_hospital_mix_expected
FROM hospital ORDER BY hospitalid;

-- Q7: BQML implicit selection: inspect effective options and iterations.
SELECT * FROM ML.TRAINING_INFO(MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`);
-- Inspect bq show --model --format=prettyjson PROJECT:icu_ml.bqml_lr_v3
-- for trainingRuns[].trainingOptions and trainingRuns[].dataSplitResult.
-- https://docs.cloud.google.com/bigquery/docs/reference/rest/v2/models
-- If the temporary evaluation table still
-- exists, aggregate its label counts; do not assume it contains 2.84 positives.

-- Q8: Comparable coefficient scales (still not causal feature importance).
SELECT processed_input, weight
FROM ML.WEIGHTS(MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`, STRUCT(TRUE AS standardize))
ORDER BY ABS(weight) DESC,processed_input;

-- Q9: Counts-only probability baseline, trained without test labels.
WITH base AS (
  SELECT AVG(CAST(y AS FLOAT64)) AS p
  FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` WHERE split='train'
)
SELECT AVG(-IF(y=1,LN(p),LN(1-p))) AS constant_train_prevalence_test_logloss
FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` CROSS JOIN base WHERE split='test';

-- Q10: Raw proxy-string inventory. This exactly follows the match families;
-- inventory is needed before interpreting e.g. negated/device-related strings.
WITH candidates AS (
  SELECT patientunitstayid, diagnosisoffset AS event_offset_min,
    'diagnosis' AS source, diagnosisstring AS matched_string
  FROM `physionet-data.eicu_crd.diagnosis`
  WHERE diagnosisoffset IS NOT NULL AND (
    LOWER(diagnosisstring) LIKE '%cardiac arrest%'
    OR LOWER(diagnosisstring) LIKE '%cardiorespiratory arrest%'
    OR LOWER(diagnosisstring) LIKE '%asystol%'
    OR LOWER(diagnosisstring) LIKE '%ventricular fibrillation%'
    OR LOWER(diagnosisstring) LIKE '%ventricular tachycardia%'
    OR LOWER(diagnosisstring) LIKE '%vfib%'
    OR LOWER(diagnosisstring) LIKE '%vtach%')
  UNION ALL
  SELECT patientunitstayid,treatmentoffset,'treatment',treatmentstring
  FROM `physionet-data.eicu_crd.treatment`
  WHERE treatmentoffset IS NOT NULL AND (
    LOWER(treatmentstring) LIKE '%cpr%'
    OR LOWER(treatmentstring) LIKE '%cardiopulmonary resuscitation%'
    OR LOWER(treatmentstring) LIKE '%defibrillat%'
    OR LOWER(treatmentstring) LIKE '%acls%'
    OR LOWER(treatmentstring) LIKE '%code blue%')
)
SELECT source,matched_string,COUNT(*) AS matched_records,
  COUNT(DISTINCT c.patientunitstayid) AS matched_stays,
  COUNTIF(c.event_offset_min=l.event_offset_min) AS earliest_retained_matches
FROM candidates c
JOIN `{{PROJECT_ID}}.icu_ml.cohort_v1` cohort USING(patientunitstayid)
LEFT JOIN `{{PROJECT_ID}}.icu_ml.labels_v2` l USING(patientunitstayid)
GROUP BY source,matched_string ORDER BY matched_records DESC;
