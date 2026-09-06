-- Q6: Per-hospital pooled-policy performance and hospital-mix null comparator.
-- observed_tp / expected_tp_given_hospital_mix tests a different question
-- from pooled enrichment; it is descriptive, not a cluster-valid p-value.
WITH ranked AS (
  SELECT *, NTILE(200) OVER(ORDER BY prob_1 DESC,patientunitstayid,prediction_time_min) AS bucket
  FROM `citric-glow-485600-f4.icu_ml.preds_test_v4_pit`
), hospital AS (
  SELECT c.hospitalid, COUNT(*) AS n, SUM(r.y) AS k,
    COUNTIF(bucket=1) AS a, COUNTIF(bucket=1 AND r.y=1) AS tp,
    COUNT(DISTINCT IF(r.y=1,r.patientunitstayid,NULL)) AS event_stays_with_positive_rows,
    COUNT(DISTINCT IF(bucket=1 AND r.y=1,r.patientunitstayid,NULL)) AS detected_event_stays
  FROM ranked r JOIN `citric-glow-485600-f4.icu_ml.cohort_v1` c USING(patientunitstayid)
  GROUP BY 1
)
SELECT *, SAFE_DIVIDE(k,n) AS prevalence, SAFE_DIVIDE(a,n) AS alert_rate,
  SAFE_DIVIDE(tp,a) AS ppv, SAFE_DIVIDE(tp,k) AS row_recall,
  SAFE_DIVIDE(detected_event_stays,event_stays_with_positive_rows) AS evaluable_event_stay_recall,
  a*SAFE_DIVIDE(k,n) AS expected_tp_given_hospital_mix,
  SAFE_DIVIDE(SUM(tp) OVER(),SUM(a*SAFE_DIVIDE(k,n)) OVER()) AS pooled_observed_over_hospital_mix_expected
FROM hospital ORDER BY hospitalid;

