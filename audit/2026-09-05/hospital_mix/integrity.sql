WITH m AS (
  SELECT patientunitstayid,prediction_time_min,COUNT(*) AS n,MIN(y) AS y
  FROM `citric-glow-485600-f4.icu_ml.model_table_v3` WHERE split='test' GROUP BY 1,2
), p AS (
  SELECT patientunitstayid,prediction_time_min,COUNT(*) AS n,MIN(y) AS y,
    COUNTIF(prob_1 IS NULL OR IS_NAN(prob_1) OR prob_1 < 0 OR prob_1 > 1) AS bad_scores,
    COUNTIF(y IS NULL OR y NOT IN (0,1)) AS bad_labels
  FROM `citric-glow-485600-f4.icu_ml.preds_test_v3` GROUP BY 1,2
), alignment AS (
  SELECT COUNTIF(m.n IS NULL) AS prediction_keys_not_in_test,
    COUNTIF(p.n IS NULL) AS test_keys_without_prediction,
    COUNTIF(m.n != 1 OR p.n != 1) AS duplicate_prediction_or_test_keys,
    COUNTIF(m.y != p.y) AS label_disagreements,
    SUM(p.bad_scores) AS bad_scores,SUM(p.bad_labels) AS bad_labels
  FROM m FULL OUTER JOIN p USING(patientunitstayid,prediction_time_min)
), cohort AS (
  SELECT COUNT(*)-COUNT(DISTINCT patientunitstayid) AS duplicate_cohort_keys
  FROM `citric-glow-485600-f4.icu_ml.cohort_v1`
), pred_hospitals AS (
  SELECT DISTINCT c.hospitalid
  FROM `citric-glow-485600-f4.icu_ml.preds_test_v3` p
  JOIN `citric-glow-485600-f4.icu_ml.cohort_v1` c USING(patientunitstayid)
), split_map AS (
  SELECT COUNTIF(s.split='test') AS assigned_test_hospitals,
    COUNTIF(s.split='test' AND h.hospitalid IS NOT NULL) AS test_hospitals_with_predictions,
    COUNTIF(h.hospitalid IS NOT NULL AND (s.split IS NULL OR s.split!='test')) AS prediction_hospitals_outside_test
  FROM `citric-glow-485600-f4.icu_ml.split_hospital_v1` s
  FULL OUTER JOIN pred_hospitals h USING(hospitalid)
)
SELECT * FROM alignment CROSS JOIN cohort CROSS JOIN split_map;
