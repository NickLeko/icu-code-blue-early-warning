-- Fixed policies for attribution; no model selection is based on these results.
WITH scores AS (
 SELECT 'original_v3' AS model,* FROM `{{PROJECT_ID}}.icu_ml.preds_test_v3`
 UNION ALL
 SELECT 'pit_autosplit_control',* FROM `{{PROJECT_ID}}.icu_ml.preds_test_v4_pit_autosplit_control`
 UNION ALL
 SELECT 'pit_custom_final',* FROM `{{PROJECT_ID}}.icu_ml.preds_test_v4_pit`
), ranked AS (
 SELECT *,NTILE(200) OVER(PARTITION BY model ORDER BY prob_1 DESC,patientunitstayid,prediction_time_min) AS bucket
 FROM scores
)
SELECT model,COUNT(*) AS n,SUM(y) AS k,COUNTIF(bucket=1) AS alerts,
 COUNTIF(bucket=1 AND y=1) AS tp,
 SAFE_DIVIDE(COUNTIF(bucket=1 AND y=1),COUNTIF(bucket=1)) AS ppv,
 SAFE_DIVIDE(COUNTIF(bucket=1 AND y=1),SUM(y)) AS positive_window_recall,
 SAFE_DIVIDE(SAFE_DIVIDE(COUNTIF(bucket=1 AND y=1),COUNTIF(bucket=1)),AVG(y)) AS pooled_enrichment,
 MIN(IF(bucket=1,prob_1,NULL)) AS observed_lowest_alert_score,
 -- Numerical clipping is explicit; authoritative final log loss is ML.EVALUATE.
 AVG(-IF(y=1,LN(GREATEST(prob_1,1e-15)),LN(GREATEST(1-prob_1,1e-15)))) AS clipped_log_loss
FROM ranked GROUP BY model ORDER BY model;
