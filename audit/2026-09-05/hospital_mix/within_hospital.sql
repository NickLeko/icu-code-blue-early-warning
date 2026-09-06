-- Exact empirical AUROC (half credit for score ties) and average precision
-- (stepwise precision-recall, processing all equal scores together).
-- Uses existing stored predictions only. No model fitting or rescoring.
WITH score_groups AS (
  SELECT c.hospitalid, p.prob_1,
    COUNT(*) AS n, COUNTIF(p.y=1) AS k, COUNTIF(p.y=0) AS negatives
  FROM `citric-glow-485600-f4.icu_ml.preds_test_v3` p
  JOIN `citric-glow-485600-f4.icu_ml.cohort_v1` c USING(patientunitstayid)
  GROUP BY c.hospitalid,p.prob_1
), cumulative AS (
  SELECT *,
    SUM(n) OVER(PARTITION BY hospitalid) AS total_n,
    SUM(k) OVER(PARTITION BY hospitalid) AS total_k,
    SUM(negatives) OVER(PARTITION BY hospitalid) AS total_negatives,
    SUM(n) OVER(PARTITION BY hospitalid ORDER BY prob_1 DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_n,
    SUM(k) OVER(PARTITION BY hospitalid ORDER BY prob_1 DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_k,
    SUM(negatives) OVER(PARTITION BY hospitalid ORDER BY prob_1 DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_negatives
  FROM score_groups
)
SELECT hospitalid, MAX(total_n) AS n, MAX(total_k) AS k,
  COUNT(*) AS distinct_scores,
  SAFE_DIVIDE(MAX(total_k),MAX(total_n)) AS prevalence,
  SAFE_DIVIDE(SUM(k*(total_negatives-cumulative_negatives+0.5*negatives)),
    MAX(total_k)*MAX(total_negatives)) AS auroc,
  SAFE_DIVIDE(SUM(k*SAFE_DIVIDE(cumulative_k,cumulative_n)),MAX(total_k)) AS average_precision
FROM cumulative GROUP BY hospitalid ORDER BY hospitalid;
