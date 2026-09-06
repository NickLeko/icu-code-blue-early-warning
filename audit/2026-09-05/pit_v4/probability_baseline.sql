-- Baseline probability is learned from train only, never held-out prevalence.
WITH train AS (
 SELECT AVG(y) AS train_prevalence FROM `{{PROJECT_ID}}.icu_ml.model_table_v4_pit` WHERE split='train'
), test AS (
 SELECT AVG(y) AS test_prevalence FROM `{{PROJECT_ID}}.icu_ml.model_table_v4_pit` WHERE split='test'
)
SELECT train_prevalence,test_prevalence,
 -test_prevalence*LN(train_prevalence)-(1-test_prevalence)*LN(1-train_prevalence) AS constant_train_prevalence_log_loss
FROM train CROSS JOIN test;
