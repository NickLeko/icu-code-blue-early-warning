-- Aggregate-only held-out operating-point metrics for the published final model.

WITH test_rows AS (
  SELECT
    COUNT(*) AS test_rows,
    COUNTIF(y = 1) AS test_positive_rows,
    SAFE_DIVIDE(COUNTIF(y = 1), COUNT(*)) AS test_prevalence
  FROM `{{PROJECT_ID}}.icu_ml.model_table_v3`
  WHERE split = 'test'
),
ranked AS (
  SELECT
    *,
    NTILE(200) OVER (ORDER BY prob_1 DESC) AS bucket
  FROM `{{PROJECT_ID}}.icu_ml.preds_test_v3`
),
operating_point AS (
  SELECT
    COUNT(*) AS alerts_top_0_5pct,
    COUNTIF(y = 1) AS positive_windows_top_0_5pct,
    SAFE_DIVIDE(COUNTIF(y = 1), COUNT(*)) AS precision_top_0_5pct
  FROM ranked
  WHERE bucket = 1
)
SELECT
  'test_rows' AS metric,
  CAST(tr.test_rows AS FLOAT64) AS value,
  'model_table_v3 test split' AS source
FROM test_rows tr

UNION ALL

SELECT
  'test_positive_rows',
  CAST(tr.test_positive_rows AS FLOAT64),
  'model_table_v3 test split'
FROM test_rows tr

UNION ALL

SELECT
  'test_prevalence',
  tr.test_prevalence,
  'model_table_v3 test split'
FROM test_rows tr

UNION ALL

SELECT
  'alerts_top_0_5pct',
  CAST(op.alerts_top_0_5pct AS FLOAT64),
  'preds_test_v3'
FROM operating_point op

UNION ALL

SELECT
  'positive_windows_top_0_5pct',
  CAST(op.positive_windows_top_0_5pct AS FLOAT64),
  'preds_test_v3'
FROM operating_point op

UNION ALL

SELECT
  'precision_top_0_5pct',
  op.precision_top_0_5pct,
  'preds_test_v3'
FROM operating_point op

UNION ALL

SELECT
  'enrichment_top_0_5pct',
  SAFE_DIVIDE(op.precision_top_0_5pct, tr.test_prevalence),
  'precision_top_0_5pct / test_prevalence'
FROM operating_point op
CROSS JOIN test_rows tr

ORDER BY metric;
